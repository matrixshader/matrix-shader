# Force reload by toggling a real setting
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Read current settings
$content = Get-Content $settingsPath -Raw -Encoding UTF8

# Toggle copyOnSelect value (harmless setting)
if ($content -match '"copyOnSelect":\s*false') {
    $content = $content -replace '"copyOnSelect":\s*false', '"copyOnSelect": true'
    Write-Host "Toggled copyOnSelect to true"
} else {
    $content = $content -replace '"copyOnSelect":\s*true', '"copyOnSelect": false'
    Write-Host "Toggled copyOnSelect to false"
}

# Write back
[System.IO.File]::WriteAllText($settingsPath, $content, [System.Text.Encoding]::UTF8)
Write-Host "Done - check if Matrix windows reloaded"
