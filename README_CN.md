# AgentWatch

面向 Claude Code 和 Codex 的 Apple Watch / 手机提醒工具。

AgentWatch 通过 Claude Code / Codex hooks 监听关键事件，在 Agent 需要授权、任务完成或出现风险时，用 Bark 推送简短通知到 iPhone、Apple Watch、Android 手机或同步通知的手环/手表。

English: [README.md](README.md)

## 功能

- 分别支持 Claude Code hooks 和 Codex hooks。
- 通过 Bark 推送到手机、Apple Watch 和安卓手环/手表。
- `PermissionRequest` 真实权限弹窗提醒。
- `Stop` 任务完成提醒。
- 工具调用风险、跑偏、失败记录。
- 默认 actionable 模式：只推送真正需要处理的事件。
- 可选通知人格包。
- 本地优先：不上传代码，不调用额外 LLM，无遥测。

## 快速开始

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

安装你使用的 Agent hooks：

```bash
# Claude Code
bash install_claude_hooks.sh

# Codex
bash install_codex_hooks.sh
```

检查状态：

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

安装你使用的 Agent hooks：

```powershell
# Claude Code
powershell -ExecutionPolicy Bypass -File windows\install_claude_hooks_windows.ps1

# Codex
powershell -ExecutionPolicy Bypass -File windows\install_codex_hooks_windows.ps1
```

检查状态：

```powershell
.\.venv\Scripts\agentwatch.exe doctor
```

## Hooks

Claude Code 安装脚本写入 `~/.claude/settings.json`，注册：

- `PreToolUse`
- `PostToolUse`
- `Notification`
- `Stop`
- `PermissionRequest`
- `PermissionDenied`

Codex 安装脚本写入 `~/.codex/hooks.json`，注册：

- `PreToolUse`
- `PostToolUse`
- `Stop`
- `PermissionRequest`

安装脚本会先备份原配置。Codex 可能会要求 trust 新 hooks，请在 Codex 中批准 AgentWatch hook 命令。

## 常用命令

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

## 桌面 App

macOS：

```bash
bash macos/build_app.sh
open build/AgentWatch.app
```

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File windows\build_app.ps1
build\windows\AgentWatchTray\AgentWatchTray.exe
```

桌面 App 只是便捷入口：配置 Bark、查看 hooks 状态、测试推送、打开日志。关闭桌面 App 后，已安装的 hooks 仍会继续工作。

## 安全说明

- `config.json` 已被 git 忽略，不要提交 Bark key。
- 日志可能包含命令摘要和路径，分享前请检查。
- AgentWatch 只把通知标题和正文发送到 Bark。
- hooks 安装是手动、选择性操作。

更多说明见 [SECURITY.md](SECURITY.md)。

## 致谢

本仓库基于两个开源项目的思路整理和扩展：

- 感谢 Dongxu Tang 的原始项目 [dongxutang918-afk/agentwatch](https://github.com/dongxutang918-afk/agentwatch)。
- 感谢 MINGOCT 的 [MINGOCT/AgentWatcher](https://github.com/MINGOCT/AgentWatcher)，其中 Codex / Bark hook 实现对本项目很有参考价值。

感谢两位作者的开源工作。

## License

MIT，见 [LICENSE](LICENSE)。
