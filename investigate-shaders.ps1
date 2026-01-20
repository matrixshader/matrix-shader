# Investigate how we can detect which shader a window is using

Write-Host "=== INVESTIGATING SHADER DETECTION ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check Windows Terminal state.json
$statePath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\state.json"
if (Test-Path $statePath) {
    Write-Host "=== STATE.JSON CONTENTS ===" -ForegroundColor Yellow
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    $state | ConvertTo-Json -Depth 10 | Write-Host
} else {
    Write-Host "state.json not found at: $statePath" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== OPEN FILE HANDLES FOR WINDOWSTERMINAL.EXE ===" -ForegroundColor Yellow
# Check if any shader files are being held open
$wtProcess = Get-Process WindowsTerminal -ErrorAction SilentlyContinue
if ($wtProcess) {
    Write-Host "WindowsTerminal.exe PID: $($wtProcess.Id)"

    # Use handle.exe if available, or check via .NET
    # Try checking which shader files have been recently accessed
    Write-Host ""
    Write-Host "=== SHADER FILE TIMESTAMPS ===" -ForegroundColor Yellow
    $shaderDir = "C:\Users\ehome\Documents\Matrix\shaders"
    Get-ChildItem "$shaderDir\Matrix-*.hlsl" | ForEach-Object {
        Write-Host "$($_.Name): LastWrite=$($_.LastWriteTime), LastAccess=$($_.LastAccessTime)"
    }
} else {
    Write-Host "WindowsTerminal.exe not running" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== SETTINGS.JSON PROFILE->SHADER MAPPING ===" -ForegroundColor Yellow
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
foreach ($profile in $settings.profiles.list) {
    if ($profile.name -match "Matrix" -or $profile.name -match "Redpill") {
        Write-Host "Profile: $($profile.name)"
        Write-Host "  GUID: $($profile.guid)"
        Write-Host "  Shader: $($profile.'experimental.pixelShaderPath')"
        Write-Host ""
    }
}
