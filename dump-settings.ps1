$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

Write-Host "=== profiles.defaults ===" -ForegroundColor Cyan
$settings.profiles.defaults | Format-List

Write-Host "`n=== Matrix profiles ===" -ForegroundColor Cyan
$settings.profiles.list | Where-Object { $_.name -match "^Matrix-\d+$" } | ForEach-Object {
    Write-Host "`n$($_.name):" -ForegroundColor Yellow
    $_ | Format-List name, opacity, backgroundImage, backgroundImageOpacity
}
