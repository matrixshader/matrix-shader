$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

Write-Host "profiles.defaults:"
$settings.profiles.defaults | ConvertTo-Json -Depth 3

Write-Host "`nTrying to remove opacity from defaults..."
try {
    $settings.profiles.defaults.PSObject.Properties.Remove('opacity')
    Write-Host "Success (or property didn't exist)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
