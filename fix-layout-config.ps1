# Fix layout config - restore 4 pillars with minimal gaps
# 4 windows × 478px = 1912px, leaving ~8px for gaps on 1920px screen

. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"

$config = Get-MatrixLayoutConfig

Write-Host "=== Restoring 4-Pillar Layout ===" -ForegroundColor Cyan
Write-Host "4 pillars with minimal gaps (windows nearly touching)" -ForegroundColor Yellow
Write-Host ""

# 4 pillars with gap=1 = windows at 478px with ~2px between each
Write-Host "Setting: MaxPillarsPerScreen=4, GapSize=1" -ForegroundColor Green
$config.MaxPillarsPerScreen = 4
$config.GapSize = 1
Set-MatrixLayoutConfig -Config $config

# Re-apply layout
$windows = Get-AllMatrixWindows -IncludeRedpill:$false
if ($windows.Count -gt 0) {
    $windowHandles = @{}
    foreach ($w in $windows) {
        $windowHandles["Matrix-$($w.Slot)"] = @{ Handle = $w.Handle }
    }

    Write-Host ""
    Write-Host "Applying layout..." -ForegroundColor Cyan
    Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode "Pillars" -PreserveMonitors
}

# Verify
Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan
Start-Sleep -Milliseconds 500
foreach ($w in ($windows | Sort-Object { $_.Slot })) {
    $rect = New-Object 'MatrixWindowAPI+RECT'
    [MatrixWindowAPI]::GetWindowRect($w.Handle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    Write-Host "Slot $($w.Slot): X=$($rect.Left) W=$width" -ForegroundColor $(if ($width -ge 478) { "Green" } else { "Red" })
}
