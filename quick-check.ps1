. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"
$w = Get-AllMatrixWindows
Write-Host "=== DETECTED MATRIX WINDOWS ===" -ForegroundColor Cyan
Write-Host "Found $($w.Count) Matrix windows:"
foreach ($x in $w) {
    Write-Host "  - $($x.ProfileName): Handle=$($x.Handle)" -ForegroundColor Green
}
