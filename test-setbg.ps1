$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$imgPath = "$env:USERPROFILE\Documents\Matrix\BACKGROUND IMAGES\4 Shadow Purple Logo.png"

$content = Get-Content $wtSettingsPath -Raw
$settings = $content | ConvertFrom-Json

for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
    if ($settings.profiles.list[$i].name -eq "Matrix-4") {
        $settings.profiles.list[$i] | Add-Member -NotePropertyName 'backgroundImage' -NotePropertyValue $imgPath -Force
        $settings.profiles.list[$i] | Add-Member -NotePropertyName 'backgroundImageOpacity' -NotePropertyValue 0.3 -Force
        Write-Host "Added purple background to Matrix-4"
        break
    }
}

$json = $settings | ConvertTo-Json -Depth 10
$tempPath = "$wtSettingsPath.tmp"
[System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)
Move-Item $tempPath $wtSettingsPath -Force
Write-Host "Done!" -ForegroundColor Green
