$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

Write-Host "Restoring settings.json to clean state..."

# Clean profiles.defaults - remove any background stuff, keep opacity at 100
$settings.profiles.defaults.PSObject.Properties.Remove('backgroundImage')
$settings.profiles.defaults.PSObject.Properties.Remove('backgroundImageOpacity')
$settings.profiles.defaults.PSObject.Properties.Remove('backgroundImageStretchMode')
$settings.profiles.defaults.PSObject.Properties.Remove('opacity')
Write-Host "  Cleaned profiles.defaults"

# Clean all Matrix profiles - remove background images and opacity
for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
    $name = $settings.profiles.list[$i].name
    if ($name -match "^Matrix-\d+$") {
        $settings.profiles.list[$i].PSObject.Properties.Remove('backgroundImage')
        $settings.profiles.list[$i].PSObject.Properties.Remove('backgroundImageOpacity')
        $settings.profiles.list[$i].PSObject.Properties.Remove('backgroundImageStretchMode')
        $settings.profiles.list[$i].PSObject.Properties.Remove('opacity')
        Write-Host "  Cleaned $name"
    }
}

# Save
$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($wtSettingsPath, $json, [System.Text.Encoding]::UTF8)

Write-Host "Done! Settings restored." -ForegroundColor Green
