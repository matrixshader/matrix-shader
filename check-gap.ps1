# Check and apply gap setting
. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"

$config = Get-MatrixLayoutConfig
Write-Host "Current GapSize: $($config.GapSize)" -ForegroundColor Cyan
Write-Host "Current Mode: $($config.Mode)" -ForegroundColor Cyan

if ($config.GapSize -ne 100) {
    Write-Host "Setting GapSize to 100..." -ForegroundColor Yellow
    $config.GapSize = 100
    Set-MatrixLayoutConfig -Config $config
}

# Re-apply layout with new gap
Write-Host ""
Write-Host "Re-applying layout with gap=$($config.GapSize)..." -ForegroundColor Green

$windows = Get-AllMatrixWindows -IncludeRedpill:$false
if ($windows.Count -gt 0) {
    $windowHandles = @{}
    foreach ($w in $windows) {
        $windowHandles["Matrix-$($w.Slot)"] = @{ Handle = $w.Handle }
    }
    Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode $config.Mode -PreserveMonitors
    Write-Host "Layout applied!" -ForegroundColor Green
} else {
    Write-Host "No Matrix windows found" -ForegroundColor Yellow
}
