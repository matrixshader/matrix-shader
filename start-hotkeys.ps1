# Start Matrix Hotkeys in background and report status
$scriptPath = "$PSScriptRoot\matrix_hotkeys.ps1"

Write-Host "Starting Matrix Global Hotkeys..." -ForegroundColor Cyan

# Create Matrix folder if needed
$matrixDir = "$env:USERPROFILE\Documents\Matrix"
if (-not (Test-Path $matrixDir)) {
    New-Item -ItemType Directory -Path $matrixDir -Force | Out-Null
}

# Start in background
$proc = Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $scriptPath
) -PassThru -WindowStyle Hidden

Write-Host "Started with PID: $($proc.Id)" -ForegroundColor Green
Write-Host ""
Write-Host "Global Hotkeys:" -ForegroundColor Yellow
Write-Host "  Ctrl+Alt+Left   - Swap focused window left" -ForegroundColor Gray
Write-Host "  Ctrl+Alt+Right  - Swap focused window right" -ForegroundColor Gray
Write-Host "  Ctrl+Alt+L      - Cycle layout (Pillars/Quads)" -ForegroundColor Gray
Write-Host "  Ctrl+Alt+B      - Toggle transparency" -ForegroundColor Gray
Write-Host "  Ctrl+Alt+J      - Decrease opacity" -ForegroundColor Gray
Write-Host "  Ctrl+Alt+K      - Increase opacity" -ForegroundColor Gray
Write-Host ""
Write-Host "Check log: $matrixDir\hotkey.log" -ForegroundColor DarkGray
