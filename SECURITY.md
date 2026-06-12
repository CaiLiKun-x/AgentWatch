# Security

## Secrets

- **Never commit `config.json`**. It contains your Bark key. It is listed in `.gitignore`.
- **Do not publish your Bark key** anywhere public. If your key is leaked, regenerate it in the Bark iOS app.
- The `config.example.json` file is safe to share — it contains `"YOUR_BARK_KEY"` as a placeholder.

## Logs

- `logs/agentwatch_events.jsonl` may contain command summaries, file paths, and hook payloads. **Do not share logs publicly** unless you have reviewed and redacted them.
- Bark keys are **automatically redacted** from all log output before writing to disk.

## Claude Code / Codex Hooks

- AgentWatch hooks are installed **only when the user manually runs** an install script:
  `install_claude_hooks.sh`, `install_codex_hooks.sh`, or the matching Windows PowerShell scripts.
- The macOS menu bar app, Windows tray app, and all `agentwatch` CLI commands **never auto-install hooks**.
- Claude Code hooks modify `~/.claude/settings.json` (or `%USERPROFILE%\.claude\settings.json` on Windows).
- Codex hooks modify `~/.codex/hooks.json` (or `%USERPROFILE%\.codex\hooks.json` on Windows).
- A backup is always created before modification.

## Data Flow

- AgentWatch does **not** send code contents, file contents, or project data to any third-party LLM or API.
- Notifications are pushed through **Bark** (https://api.day.app by default). The notification title and body are transmitted to the Bark server. If you self-host Bark, configure `bark_server` in `config.json`.
- AgentWatch runs entirely on your local machine. No telemetry, no analytics, no cloud dependency beyond the Bark push service.

## Reporting

If you discover a security issue, please open a GitHub issue or contact the maintainer directly. Do not post secrets in public issues.
