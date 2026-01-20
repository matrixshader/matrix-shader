$dir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$backup = "$dir\settings.json.bak2-20251128100858"
$target = "$dir\settings.json"

if (Test-Path $backup) {
    Copy-Item $backup $target -Force
    Write-Host "Restored from backup: $backup" -ForegroundColor Green
} else {
    Write-Host "Backup not found: $backup" -ForegroundColor Red
}
