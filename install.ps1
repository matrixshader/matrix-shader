# MATRIX CLI INSTALLER
# Run once to set up the Matrix terminal system

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$shadersDir = "$matrixDir\shaders"
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

Write-Host ""
Write-Host " MATRIX CLI INSTALLER" -ForegroundColor Green
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host ""

# Create directories
if (-not (Test-Path $shadersDir)) {
    New-Item -ItemType Directory -Path $shadersDir -Force | Out-Null
    Write-Host " [OK] Created shaders directory" -ForegroundColor Cyan
}

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$matrixDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$matrixDir", "User")
    Write-Host " [OK] Added Matrix to PATH" -ForegroundColor Cyan
    Write-Host "      (Restart terminal for PATH to take effect)" -ForegroundColor DarkGray
} else {
    Write-Host " [OK] Matrix already in PATH" -ForegroundColor Cyan
}

# Create hidden profiles in Windows Terminal (1-8 slots)
Write-Host ""
Write-Host " Configuring Windows Terminal profiles..." -ForegroundColor Cyan

$wt = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

# Remove any existing Matrix profiles
$wt.profiles.list = @($wt.profiles.list | Where-Object { $_.name -notlike "Matrix-*" })

# Add hidden Matrix profiles (slots 1-8)
$matrixProfiles = @()
for ($i = 1; $i -le 8; $i++) {
    $guid = "{$($i)7ce5bfe-$($i)7ed-5f3a-ab15-5cd5baafed5b}"
    $matrixProfiles += @{
        name = "Matrix-$i"
        guid = $guid
        commandline = "powershell.exe -NoExit -Command `"Write-Host ' Matrix Terminal $i' -ForegroundColor Green`""
        hidden = $true
        "experimental.pixelShaderPath" = "$shadersDir\Matrix-$i.hlsl"
    }
}

$wt.profiles.list = @($matrixProfiles) + @($wt.profiles.list)

# Write back
$wt | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
Write-Host " [OK] Created 8 hidden Matrix profile slots" -ForegroundColor Cyan

Write-Host ""
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host " INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host ""
Write-Host " Commands available (after restarting terminal):" -ForegroundColor White
Write-Host "   wakeupneo  - Setup wizard (pick colors, launch tabs)" -ForegroundColor Yellow
Write-Host "   redpill    - Control panel (live adjustments)" -ForegroundColor Yellow
Write-Host ""
