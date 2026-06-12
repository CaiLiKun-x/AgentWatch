#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AgentWatch Setup.command — double-click for first-time environment setup.
#
# Creates .venv, installs agentwatch, runs agentwatch init, then doctor.
# Does NOT auto-install Claude Code or Codex hooks.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "  AgentWatch — First-Time Setup"
echo "============================================"
echo ""

# --- .venv ---
if [ ! -d ".venv" ]; then
    echo "[1/4] Creating virtual environment ..."
    python3 -m venv .venv
    echo "      .venv created."
else
    echo "[1/4] Virtual environment already exists — skipping."
fi

# --- pip install ---
echo "[2/4] Installing agentwatch ..."
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q --upgrade pip setuptools 2>/dev/null || true
pip install -q -e .
echo "      Done."

# --- agentwatch init ---
echo "[3/4] Initialising config and logs ..."
agentwatch init
echo ""

# --- agentwatch doctor ---
echo "[4/4] Running health check ..."
agentwatch doctor

# --- next steps ---
echo ""
echo "============================================"
echo "  Next Steps"
echo "============================================"
echo ""
echo "  1. Edit config.json:"
echo "     Open ~/Projects/agentwatch/config.json"
echo "     Fill in your Bark key in: notifier.bark_key"
echo ""
echo "  2. Test notifications:"
echo "     agentwatch test-push"
echo ""
echo "  3. Install hooks for the agent you use (optional but recommended):"
echo "     bash ~/Projects/agentwatch/install_claude_hooks.sh"
echo "     bash ~/Projects/agentwatch/install_codex_hooks.sh"
echo ""
echo "  4. Launch the monitor:"
echo "     Double-click AgentWatch.command"
echo "     or run: agentwatch start"
echo ""

read -r -p "Press Enter to exit..."
