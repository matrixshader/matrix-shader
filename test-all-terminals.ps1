# Show ALL terminal windows
. "$PSScriptRoot\WindowIdentityService-SIMPLE.ps1"

Write-Host ""
Write-Host "=== ALL TERMINAL WINDOWS ===" -ForegroundColor Cyan

$all = Get-AllTerminalWindows

foreach ($w in $all) {
    Write-Host "  Handle=$($w.Handle), Title='$($w.Title)'" -ForegroundColor White
}

Write-Host ""
Write-Host "Total: $($all.Count) terminal windows" -ForegroundColor Yellow
