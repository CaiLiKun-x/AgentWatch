# AgentWatch -- uninstall Codex hooks for Windows
# Usage: powershell -ExecutionPolicy Bypass -File windows\uninstall_codex_hooks_windows.ps1

$ErrorActionPreference = "Stop"
$CodexDir = Join-Path $env:USERPROFILE ".codex"
$SettingsFile = Join-Path $CodexDir "hooks.json"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $CodexDir "hooks.json.agentwatch.bak.uninstall.$Timestamp"

if (-not (Test-Path $SettingsFile)) {
    Write-Host "[AgentWatch] No Codex hooks.json found. Nothing to uninstall."
    exit 0
}

Copy-Item $SettingsFile $BackupFile
Write-Host "[AgentWatch] Backed up to: $BackupFile"

$settings = Get-Content -Raw $SettingsFile | ConvertFrom-Json
$removed = @()

if ($settings.PSObject.Properties["hooks"]) {
    $hooksToRemove = @()
    foreach ($prop in $settings.hooks.PSObject.Properties) {
        $eventName = $prop.Name
        $entries = $prop.Value
        if (-not $entries) { continue }

        $kept = @()
        $hadRemoval = $false
        foreach ($entry in $entries) {
            if (-not $entry.PSObject.Properties["hooks"]) {
                $flatCmd = ""
                if ($entry.PSObject.Properties["command"]) { $flatCmd += " " + $entry.command }
                if ($entry.PSObject.Properties["commandWindows"]) { $flatCmd += " " + $entry.commandWindows }
                if ($flatCmd -match "agentwatch") {
                    $hadRemoval = $true
                } else {
                    $kept += $entry
                }
                continue
            }

            $filtered = @()
            foreach ($h in $entry.hooks) {
                $cmd = ""
                if ($h.PSObject.Properties["command"]) { $cmd += " " + $h.command }
                if ($h.PSObject.Properties["commandWindows"]) { $cmd += " " + $h.commandWindows }
                if ($cmd -match "agentwatch") {
                    $hadRemoval = $true
                } else {
                    $filtered += $h
                }
            }
            if ($filtered.Count -gt 0) {
                $entry.hooks = $filtered
                $kept += $entry
            }
        }

        if ($hadRemoval) {
            $removed += "$eventName"
            if ($kept.Count -gt 0) {
                $settings.hooks.$eventName = $kept
            } else {
                $hooksToRemove += $eventName
            }
        }
    }
    foreach ($name in $hooksToRemove) {
        $settings.hooks.PSObject.Properties.Remove($name)
    }
}

if ($removed.Count -gt 0) {
    $settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "[AgentWatch] Removed Codex hooks for: $($removed -join ', ')"
} else {
    Write-Host "[AgentWatch] No AgentWatch Codex hooks found -- nothing removed."
}

Write-Host ""
Write-Host "[AgentWatch] Uninstall complete."
Write-Host "  Backup: $BackupFile"
