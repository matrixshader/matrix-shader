# Force re-apply layout using WindowLayoutEngine (respects min width constraint)
. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"

Write-Host "=== Fixing Overlapping Windows ===" -ForegroundColor Cyan

$windows = Get-AllMatrixWindows -IncludeRedpill:$false
Write-Host "Found $($windows.Count) windows" -ForegroundColor Gray

$config = Get-MatrixLayoutConfig
Write-Host "Gap: $($config.GapSize), Mode: $($config.Mode)" -ForegroundColor Gray

# Build window handles for layout engine
$windowHandles = @{}
foreach ($w in $windows) {
    $windowHandles["Matrix-$($w.Slot)"] = @{ Handle = $w.Handle }
}

# Apply layout using the proper engine (with min width constraint)
Write-Host ""
Write-Host "Applying layout via WindowLayoutEngine..." -ForegroundColor Yellow
Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode $config.Mode -PreserveMonitors

Write-Host ""
Write-Host "=== Verifying ===" -ForegroundColor Cyan
Start-Sleep -Milliseconds 500

foreach ($win in $sortedWindows) {
    $rect = New-Object 'MatrixWindowAPI+RECT'
    [MatrixWindowAPI]::GetWindowRect($win.Handle, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    Write-Host "Slot $($win.Slot): X=$($rect.Left) Y=$($rect.Top) W=$w H=$h" -ForegroundColor $(if ($w -eq $cellWidth) { "Green" } else { "Red" })
}
