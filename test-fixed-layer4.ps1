# Test the fixed Layer 4 (TermControl detection)
$env:MATRIX_DEBUG = "1"
. "$PSScriptRoot\WindowIdentityService.ps1"

Write-Host ""
Write-Host "=== TESTING FIXED LAYER 4 ===" -ForegroundColor Cyan
Write-Host ""

$windows = Get-AllMatrixWindows

Write-Host "=== RESULTS ===" -ForegroundColor Yellow
foreach ($w in $windows) {
    Write-Host "  $($w.ProfileName): Handle=$($w.Handle), Source=$($w.IdentitySource)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Total: $($windows.Count) Matrix windows detected" -ForegroundColor Cyan
