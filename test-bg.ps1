$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$backgroundsDir = "$matrixDir\BACKGROUND IMAGES"
$backgroundImage = $true

$backgroundImageMap = @{
    1 = "1 Shadow Green Logo.png"
    2 = "2 Shadow Blue Logo.png"
    3 = "3 Shadow Red Logo.png"
    4 = "4 Shadow Purple Logo.png"
    5 = "5 Shadow Gold Logo.png"
    6 = "6 Shadow Teal Logo.png"
}

Write-Host "Testing Apply-BackgroundImage..."
Write-Host "backgroundsDir: $backgroundsDir"
Write-Host "Exists: $(Test-Path $backgroundsDir)"

try {
    $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
    $settings = $content | ConvertFrom-Json -ErrorAction Stop
    Write-Host "Loaded settings.json OK"

    for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
        $profileName = $settings.profiles.list[$i].name
        if ($profileName -match "^Matrix-(\d+)$") {
            $slot = [int]$Matches[1]
            Write-Host "Found profile: $profileName (slot $slot)"
            if ($backgroundImageMap.ContainsKey($slot)) {
                $imgPath = "$backgroundsDir\$($backgroundImageMap[$slot])"
                Write-Host "  Image path: $imgPath"
                Write-Host "  Image exists: $(Test-Path $imgPath)"
            } else {
                Write-Host "  No image mapping for slot $slot"
            }
        }
    }
    Write-Host "Test completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
}
