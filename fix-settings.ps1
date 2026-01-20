$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

Write-Host "Cleaning up profiles.defaults..."
# Remove null backgroundImage from defaults
if ($null -eq $settings.profiles.defaults.backgroundImage -or $settings.profiles.defaults.backgroundImage -eq "") {
    $settings.profiles.defaults.PSObject.Properties.Remove('backgroundImage')
    Write-Host "  Removed null backgroundImage"
}

# Save
$json = $settings | ConvertTo-Json -Depth 10
$tempPath = "$wtSettingsPath.tmp"
[System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)
Move-Item $tempPath $wtSettingsPath -Force

Write-Host "Done!" -ForegroundColor Green
