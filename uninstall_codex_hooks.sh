#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AgentWatch — uninstall Codex hooks
#
# Removes AgentWatch hook entries from ~/.codex/hooks.json.
# Does NOT destroy any other user hooks.
# ---------------------------------------------------------------------------
set -euo pipefail

SETTINGS_FILE="$HOME/.codex/hooks.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PYTHON_BIN=""
if [ -f "$SCRIPT_DIR/.venv/bin/python" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
elif [ -f "$SCRIPT_DIR/.venv/bin/python3" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python3"
else
    PYTHON_BIN="$(which python3 2>/dev/null || which python 2>/dev/null || echo '')"
fi

if [ -z "$PYTHON_BIN" ]; then
    echo "[AgentWatch] ERROR: Could not find python3."
    exit 1
fi

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "[AgentWatch] No Codex hooks.json found. Nothing to uninstall."
    exit 0
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$HOME/.codex/hooks.json.agentwatch.bak.uninstall.$TIMESTAMP"
cp "$SETTINGS_FILE" "$BACKUP_FILE"
echo "[AgentWatch] Backed up current hooks to: $BACKUP_FILE"

$PYTHON_BIN << PYEOF
import json
from pathlib import Path

settings_file = Path("$SETTINGS_FILE")

with open(settings_file, "r", encoding="utf-8") as fh:
    settings = json.load(fh)

hooks = settings.get("hooks", {}) or {}
removed = []

for event_name in list(hooks.keys()):
    entries = hooks[event_name]
    if not isinstance(entries, list):
        continue

    kept = []
    for entry in entries:
        if not isinstance(entry, dict):
            kept.append(entry)
            continue

        inner_hooks = entry.get("hooks", [])
        if isinstance(inner_hooks, list):
            filtered = [
                h for h in inner_hooks
                if not (
                    isinstance(h, dict)
                    and "agentwatch" in f"{h.get('command', '')} {h.get('commandWindows', '')}".lower()
                )
            ]
            if len(filtered) < len(inner_hooks):
                removed.append(event_name)
            if filtered:
                entry["hooks"] = filtered
                kept.append(entry)
            continue

        if "agentwatch" in f"{entry.get('command', '')} {entry.get('commandWindows', '')}".lower():
            removed.append(event_name)
            continue

        kept.append(entry)

    if kept:
        hooks[event_name] = kept
    else:
        del hooks[event_name]

if hooks:
    settings["hooks"] = hooks
else:
    settings.pop("hooks", None)

with open(settings_file, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, ensure_ascii=False, indent=2)

if removed:
    print(f"[AgentWatch] Removed Codex hooks for: {', '.join(sorted(set(removed)))}")
    print(f"[AgentWatch] Updated: {settings_file}")
else:
    print("[AgentWatch] No AgentWatch Codex hooks found — nothing removed.")
PYEOF

echo ""
echo "[AgentWatch] Uninstall complete."
echo "[AgentWatch] To restore from backup: cp <backup_file> $SETTINGS_FILE"
