# Apply shader changes by atomic file replacement
param([int]$Slot = 1)

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$tempPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.tmp"

# Read current settings
$content = Get-Content $settingsPath -Raw -Encoding UTF8

# Write to temp file
[System.IO.File]::WriteAllText($tempPath, $content, [System.Text.Encoding]::UTF8)

# Atomic move (replace)
Move-Item -Path $tempPath -Destination $settingsPath -Force

Write-Host "Settings reloaded via atomic replace"
