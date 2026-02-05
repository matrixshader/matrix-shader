$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
try {
    $content = Get-Content $wtSettingsPath -Raw
    $settings = $content | ConvertFrom-Json
    Write-Host "settings.json is valid JSON" -ForegroundColor Green
    Write-Host "Number of profiles: $($settings.profiles.list.Count)"
} catch {
    Write-Host "INVALID JSON: $($_.Exception.Message)" -ForegroundColor Red
}
