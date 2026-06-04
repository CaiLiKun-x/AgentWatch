# AgentWatch v0.8.0 — Initial Public Release

## Overview

AgentWatch is a lightweight bridge between Claude Code and your Apple Watch. It notifies you via Apple Watch vibration when your AI agent needs approval, finishes a task, or needs your attention — so you can walk away from your screen without missing anything.

## What's New

### Core
- **PermissionRequest hook support** — reliably captures real "Allow this bash command?" dialogs
- **PermissionDenied hook logging** — tracks when you deny an agent operation
- **Actionable notification mode** — only pushes when you genuinely need to interact
- **PreToolUse timeout log-only** — prevents false alerts from slow commands

### Persona Themes
Six fun notification styles: Off, 总裁版, 少爷版, 大小姐版, 皇上版, 甄嬛版

### macOS Menu Bar App
Native Swift + AppKit app with Bark config, persona switching, recent events, and quick actions — all from your menu bar.

### Windows Tray App
Native C# / .NET 8 WinForms app with full feature parity.

### Bark Configuration
Paste a full Bark URL or bare key from CLI, macOS menu bar, or Windows tray.

## Upgrade Notes

**If upgrading from an older version**, reinstall Claude Code hooks to enable PermissionRequest / PermissionDenied:

macOS:
```bash
bash install_claude_hooks.sh
```

Windows:
```powershell
powershell -ExecutionPolicy Bypass -File windows\install_claude_hooks_windows.ps1
```

Run `agentwatch doctor` to verify — should show `Claude hooks: Installed` (6/6).

## Installation

See [README.md](README.md) for full instructions.

## Links

- GitHub: https://github.com/dongxutang918-afk/agentwatch
- License: MIT
