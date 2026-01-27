# Verify actual window positions and gaps
. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"

Write-Host "=== Window Gap Verification ===" -ForegroundColor Cyan

$windows = Get-AllMatrixWindows -IncludeRedpill:$false | Sort-Object { $_.Slot }
$config = Get-MatrixLayoutConfig
Write-Host "Mode: $($config.Mode), Gap Setting: $($config.GapSize)px" -ForegroundColor Gray
Write-Host ""

$prevRight = $null
$prevSlot = $null
foreach ($win in $windows) {
    $rect = New-Object 'MatrixWindowAPI+RECT'
    [MatrixWindowAPI]::GetWindowRect($win.Handle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    $gap = if ($prevRight -and $rect.Top -lt ($rect.Bottom - $height + 50)) {
        $rect.Left - $prevRight
    } else { "N/A (new row)" }

    $color = if ($width -ge 480) { "Green" } else { "Red" }
    Write-Host "Slot $($win.Slot): X=$($rect.Left) Y=$($rect.Top) W=$width H=$height | Gap from prev: $gap" -ForegroundColor $color

    $prevRight = $rect.Right
    $prevSlot = $win.Slot
}

Write-Host ""
Write-Host "Windows Terminal minimum width: 478px" -ForegroundColor Yellow
Write-Host "All windows should be GREEN (>= 480px)" -ForegroundColor Yellow
