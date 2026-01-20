$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

Write-Host "Testing transparency toggle..."

try {
    $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
    $settings = $content | ConvertFrom-Json -ErrorAction Stop

    # Toggle off (remove opacity)
    Write-Host "Removing opacity from profiles.defaults..."
    $settings.profiles.defaults.PSObject.Properties.Remove('opacity')

    Write-Host "Removing opacity from Matrix profiles..."
    for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
        $profileName = $settings.profiles.list[$i].name
        if ($profileName -match "^Matrix-\d+$") {
            $settings.profiles.list[$i].PSObject.Properties.Remove('opacity')
            Write-Host "  Removed from $profileName"
        }
    }

    # Save
    $json = $settings | ConvertTo-Json -Depth 10
    $tempPath = "$wtSettingsPath.tmp"
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)
    Move-Item $tempPath $wtSettingsPath -Force -ErrorAction Stop

    Write-Host "Done! Transparency toggled off." -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
}
