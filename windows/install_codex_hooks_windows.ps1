# AgentWatch -- install Codex hooks for Windows
# Usage: powershell -ExecutionPolicy Bypass -File windows\install_codex_hooks_windows.ps1

$ErrorActionPreference = "Stop"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$CodexDir = Join-Path $env:USERPROFILE ".codex"
$SettingsFile = Join-Path $CodexDir "hooks.json"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $CodexDir "hooks.json.agentwatch.bak.$Timestamp"
$PythonBin = Join-Path $ProjectDir ".venv\Scripts\python.exe"

if (-not (Test-Path $PythonBin)) {
    Write-Host "[AgentWatch] ERROR: Python not found at $PythonBin"
    Write-Host "[AgentWatch] Run windows\setup_windows.ps1 first."
    exit 1
}

$QuotedPythonBin = "`"$PythonBin`""
$HookCommandPrefix = "$QuotedPythonBin -m agentwatch.cli hook"

if (-not (Test-Path $CodexDir)) {
    New-Item -ItemType Directory -Path $CodexDir | Out-Null
}

Write-Host "[AgentWatch] Project: $ProjectDir"
Write-Host "[AgentWatch] Codex hooks: $SettingsFile"
Write-Host "[AgentWatch] Python: $PythonBin"

if (Test-Path $SettingsFile) {
    Copy-Item $SettingsFile $BackupFile
    Write-Host "[AgentWatch] Backed up to: $BackupFile"
} else {
    Write-Host "[AgentWatch] No existing hooks.json -- creating fresh."
}

$settings = @{}
if (Test-Path $SettingsFile) {
    try {
        $raw = Get-Content -Raw $SettingsFile | ConvertFrom-Json
        $settings = $raw | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    } catch {
        Write-Host "[AgentWatch] WARNING: Could not parse existing hooks.json. Starting fresh."
    }
}

if (-not $settings.PSObject.Properties["hooks"]) {
    $settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value @{}
}

function New-AgentWatchHookGroup {
    param(
        [string]$EventName,
        [string]$StatusMessage,
        [bool]$WithMatcher = $true
    )

    $hook = @{
        type = "command"
        command = "$HookCommandPrefix --event $EventName --provider codex"
        commandWindows = "$HookCommandPrefix --event $EventName --provider codex"
        timeout = 15
        statusMessage = $StatusMessage
    }

    $group = @{
        hooks = @($hook)
    }
    if ($WithMatcher) {
        $group.matcher = ".*"
    }
    return @($group)
}

$hookDefs = @{
    "PreToolUse" = New-AgentWatchHookGroup -EventName "PreToolUse" -StatusMessage "AgentWatch: checking tool use"
    "PostToolUse" = New-AgentWatchHookGroup -EventName "PostToolUse" -StatusMessage "AgentWatch: recording tool result"
    "Stop" = New-AgentWatchHookGroup -EventName "Stop" -StatusMessage "AgentWatch: sending completion notification" -WithMatcher $false
    "PermissionRequest" = New-AgentWatchHookGroup -EventName "PermissionRequest" -StatusMessage "AgentWatch: sending approval notification"
}

$modified = @()
foreach ($eventName in $hookDefs.Keys) {
    $existing = @()
    try { $existing = $settings.hooks.$eventName } catch {}
    if (-not $existing) { $existing = @() }

    $cleaned = @()
    foreach ($entry in $existing) {
        $hasAw = $false
        if ($entry.PSObject.Properties["hooks"]) {
            foreach ($h in $entry.hooks) {
                $cmd = ""
                if ($h.PSObject.Properties["command"]) { $cmd += " " + $h.command }
                if ($h.PSObject.Properties["commandWindows"]) { $cmd += " " + $h.commandWindows }
                if ($cmd -match "agentwatch") { $hasAw = $true }
            }
        }
        $flatCmd = ""
        if ($entry.PSObject.Properties["command"]) { $flatCmd += " " + $entry.command }
        if ($entry.PSObject.Properties["commandWindows"]) { $flatCmd += " " + $entry.commandWindows }
        if ($flatCmd -match "agentwatch") { $hasAw = $true }
        if (-not $hasAw) { $cleaned += $entry }
    }

    $merged = @($cleaned) + @($hookDefs[$eventName])
    $settings.hooks | Add-Member -MemberType NoteProperty -Name $eventName -Value $merged -Force
    $modified += $eventName
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8

Write-Host "[AgentWatch] Codex hooks installed for: $($modified -join ', ')"
Write-Host "[AgentWatch] Hooks written to: $SettingsFile"
Write-Host ""
Write-Host "[AgentWatch] Done!"
Write-Host "  Backup: $BackupFile"
Write-Host "  To test: .\.venv\Scripts\agentwatch.exe simulate permission-request"
Write-Host "  To uninstall: powershell -ExecutionPolicy Bypass -File windows\uninstall_codex_hooks_windows.ps1"
Write-Host "  If Codex asks you to trust these hooks, approve them in Codex."
