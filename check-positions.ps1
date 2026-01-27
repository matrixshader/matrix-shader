# Check current window positions
. "$PSScriptRoot\WindowIdentityService.ps1"

$windows = Get-AllMatrixWindows -IncludeRedpill:$false

Write-Host "=== CURRENT WINDOW POSITIONS ===" -ForegroundColor Cyan
foreach ($w in $windows) {
    $rect = New-Object 'MatrixWindowAPI+RECT'
    [MatrixWindowAPI]::GetWindowRect($w.Handle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    Write-Host "Slot $($w.Slot): X=$($rect.Left) Y=$($rect.Top) W=$width H=$height" -ForegroundColor Yellow
}
