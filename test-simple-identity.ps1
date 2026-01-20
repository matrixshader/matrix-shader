# Quick test of the simple identity service
. "$PSScriptRoot\WindowIdentityService-SIMPLE.ps1"

Write-Host ""
Write-Host "=== TESTING SIMPLE IDENTITY SERVICE ===" -ForegroundColor Cyan

$windows = Get-AllMatrixWindows

Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Yellow
foreach ($w in $windows) {
    Write-Host "  $($w.ProfileName): Handle=$($w.Handle), Source=$($w.IdentitySource)" -ForegroundColor Green
    Write-Host "    Title: '$($w.Title)'" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Total: $($windows.Count) Matrix windows detected" -ForegroundColor Cyan
