# Force reload by delete + create (simulating Claude's Write tool)
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Read current settings
$content = Get-Content $settingsPath -Raw

# Delete the file
Remove-Item $settingsPath -Force
Write-Host "Deleted settings.json"

# Small delay
Start-Sleep -Milliseconds 200

# Create new file
Set-Content -Path $settingsPath -Value $content -NoNewline
Write-Host "Created new settings.json"

Write-Host "Check if Matrix windows reloaded!"
