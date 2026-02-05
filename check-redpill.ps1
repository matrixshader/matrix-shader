$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

Write-Host "=== Redpill profile ===" -ForegroundColor Cyan
$redpill = $settings.profiles.list | Where-Object { $_.name -eq "Redpill" }
$redpill | ConvertTo-Json -Depth 3
