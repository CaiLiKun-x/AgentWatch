#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AgentWatch — install Codex hooks
#
# This script adds AgentWatch hooks to ~/.codex/hooks.json so that Codex calls
# agentwatch on key lifecycle events. It backs up hooks.json before modifying it.
# ---------------------------------------------------------------------------
set -euo pipefail

SETTINGS_FILE="$HOME/.codex/hooks.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$HOME/.codex/hooks.json.agentwatch.bak.$TIMESTAMP"

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
    echo "[AgentWatch] ERROR: Could not find python3. Please install Python 3.10+ and try again."
    exit 1
fi

mkdir -p "$HOME/.codex"

echo "[AgentWatch] Using Python: $PYTHON_BIN"
echo "[AgentWatch] Codex hooks file: $SETTINGS_FILE"

if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    echo "[AgentWatch] Backed up existing hooks to: $BACKUP_FILE"
else
    echo "[AgentWatch] No existing hooks.json — creating a fresh one."
fi

$PYTHON_BIN << PYEOF
import json
import shlex
from pathlib import Path

settings_file = Path("$SETTINGS_FILE")
python_bin = "$PYTHON_BIN"
python_cmd = shlex.quote(python_bin)

if settings_file.exists():
    try:
        with open(settings_file, "r", encoding="utf-8") as fh:
            settings = json.load(fh)
    except json.JSONDecodeError:
        print("[AgentWatch] WARNING: Could not parse existing hooks.json. Starting fresh.")
        settings = {}
else:
    settings = {}

hooks = settings.get("hooks", {}) or {}

aw_hook_groups = {
    "PreToolUse": [
        {
            "matcher": ".*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"{python_cmd} -m agentwatch.cli hook --event PreToolUse --provider codex",
                    "timeout": 15,
                    "statusMessage": "AgentWatch: checking tool use"
                }
            ]
        }
    ],
    "PostToolUse": [
        {
            "matcher": ".*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"{python_cmd} -m agentwatch.cli hook --event PostToolUse --provider codex",
                    "timeout": 15,
                    "statusMessage": "AgentWatch: recording tool result"
                }
            ]
        }
    ],
    "Stop": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": f"{python_cmd} -m agentwatch.cli hook --event Stop --provider codex",
                    "timeout": 15,
                    "statusMessage": "AgentWatch: sending completion notification"
                }
            ]
        }
    ],
    "PermissionRequest": [
        {
            "matcher": ".*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"{python_cmd} -m agentwatch.cli hook --event PermissionRequest --provider codex",
                    "timeout": 15,
                    "statusMessage": "AgentWatch: sending approval notification"
                }
            ]
        }
    ],
}

modified = []
for event_name, new_groups in aw_hook_groups.items():
    existing = hooks.get(event_name, []) or []
    cleaned = []
    for entry in existing:
        if not isinstance(entry, dict):
            cleaned.append(entry)
            continue
        inner_hooks = entry.get("hooks", [])
        if isinstance(inner_hooks, list):
            has_aw = any(
                "agentwatch" in f"{h.get('command', '')} {h.get('commandWindows', '')}".lower()
                for h in inner_hooks
                if isinstance(h, dict)
            )
            if has_aw:
                continue
        if "agentwatch" in f"{entry.get('command', '')} {entry.get('commandWindows', '')}".lower():
            continue
        cleaned.append(entry)
    hooks[event_name] = cleaned + new_groups
    modified.append(event_name)

settings["hooks"] = hooks
with open(settings_file, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, ensure_ascii=False, indent=2)

print(f"[AgentWatch] Codex hooks installed for: {', '.join(modified)}")
print(f"[AgentWatch] Hooks written to: {settings_file}")
PYEOF

echo ""
echo "[AgentWatch] Done! Codex hooks installed successfully."
echo "[AgentWatch] Backup saved at: $BACKUP_FILE"
echo "[AgentWatch]"
echo "[AgentWatch] To verify, run: agentwatch doctor"
echo "[AgentWatch] To uninstall, run: bash $SCRIPT_DIR/uninstall_codex_hooks.sh"
echo "[AgentWatch] If Codex prompts you to trust these hooks, approve them in Codex."
