$dir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$tmp = "$dir\settings.json.tmp"
if (Test-Path $tmp) {
    Write-Host "FOUND stuck temp file: $tmp" -ForegroundColor Red
    Remove-Item $tmp -Force
    Write-Host "Removed it." -ForegroundColor Green
} else {
    Write-Host "No stuck temp file." -ForegroundColor Green
}
