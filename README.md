# AgentWatch

Apple Watch / phone notifications for Claude Code and Codex.

AgentWatch sends short Bark notifications when your coding agent needs approval,
finishes a task, or hits a risky state. It works locally through Claude Code /
Codex hooks and can be used from the CLI, a macOS menu bar app, or a Windows tray
app.

中文说明见 [README_CN.md](README_CN.md).

## Features

- Claude Code hooks and Codex hooks, installed separately.
- Bark notifications for iPhone, Apple Watch, Android phones, and synced bands.
- `PermissionRequest` alerts for real approval prompts.
- `Stop` task-completion reminders.
- Risk/drift/failure logging from tool-use hooks.
- Actionable mode by default: only important events push to your watch.
- Optional persona themes for notification text.
- Local-first: no telemetry, no extra LLM calls, no code upload.

## Quick Start

### macOS / Linux

```bash
git clone https://github.com/CaiLiKun-x/AgentWatch.git ~/Projects/agentwatch
cd ~/Projects/agentwatch

python3 -m venv .venv
source .venv/bin/activate
pip install -e .

agentwatch init
agentwatch config bark
agentwatch config test
```

Install hooks for the agent you use:

```bash
# Claude Code
bash install_claude_hooks.sh

# Codex
bash install_codex_hooks.sh
```

Verify:

```bash
agentwatch doctor
```

### Windows

```powershell
git clone https://github.com/CaiLiKun-x/AgentWatch.git
cd AgentWatch

powershell -ExecutionPolicy Bypass -File windows\setup_windows.ps1

.\.venv\Scripts\agentwatch.exe config bark
.\.venv\Scripts\agentwatch.exe config test
```

Install hooks for the agent you use:

```powershell
# Claude Code
powershell -ExecutionPolicy Bypass -File windows\install_claude_hooks_windows.ps1

# Codex
powershell -ExecutionPolicy Bypass -File windows\install_codex_hooks_windows.ps1
```

Verify:

```powershell
.\.venv\Scripts\agentwatch.exe doctor
```

## Hooks

Claude Code installer writes `~/.claude/settings.json`.

Registered Claude Code events:

- `PreToolUse`
- `PostToolUse`
- `Notification`
- `Stop`
- `PermissionRequest`
- `PermissionDenied`

Codex installer writes `~/.codex/hooks.json`.

Registered Codex events:

- `PreToolUse`
- `PostToolUse`
- `Stop`
- `PermissionRequest`

Installers always create a backup before modifying hook files. Codex may ask you
to trust the new hook commands; approve the AgentWatch commands in Codex for
them to run.

## Common Commands

```bash
agentwatch doctor
agentwatch monitor
agentwatch config bark
agentwatch config test
agentwatch simulate permission-request
agentwatch simulate done
agentwatch task quick
agentwatch logs --tail 20
```

## Desktop Apps

macOS:

```bash
bash macos/build_app.sh
open build/AgentWatch.app
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File windows\build_app.ps1
build\windows\AgentWatchTray\AgentWatchTray.exe
```

The desktop apps are convenience layers for configuring Bark, checking hook
status, testing notifications, and opening logs. Hooks continue to work after
the desktop app is closed.

## Security

- `config.json` is ignored by git and should not be committed.
- Logs may contain command summaries and file paths; review before sharing.
- AgentWatch only sends notification title/body to Bark.
- Hook installation is manual and opt-in.

More details: [SECURITY.md](SECURITY.md).

## Acknowledgements

This repository builds on and reorganizes ideas from two earlier projects:

- [dongxutang918-afk/agentwatch](https://github.com/dongxutang918-afk/agentwatch) by Dongxu Tang, the original AgentWatch project.
- [MINGOCT/AgentWatcher](https://github.com/MINGOCT/AgentWatcher) by MINGOCT, which provided useful Codex/Bark hook references.

Thanks to both authors for their open-source work.

## License

MIT. See [LICENSE](LICENSE).
