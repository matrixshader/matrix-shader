$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Read current settings
$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

# Fix profiles.defaults - remove any junk I added
$propsToRemove = @('backgroundImage', 'backgroundImageOpacity', 'backgroundImageStretchMode')
foreach ($prop in $propsToRemove) {
    $settings.profiles.defaults.PSObject.Properties.Remove($prop)
}

# Fix all Matrix profiles - remove background junk but keep shader paths
for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
    $name = $settings.profiles.list[$i].name
    if ($name -match "^Matrix-\d+$") {
        foreach ($prop in $propsToRemove) {
            $settings.profiles.list[$i].PSObject.Properties.Remove($prop)
        }
    }
}

# Write directly (no temp file nonsense)
$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($wtSettingsPath, $json, [System.Text.Encoding]::UTF8)

Write-Host "Fixed settings.json" -ForegroundColor Green
