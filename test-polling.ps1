# Test polling-based window launch
$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

Write-Host "Testing poll-based window launch..." -ForegroundColor Cyan
Write-Host ""

# Check existing slots
$existingSlots = Get-ExistingSlots
$openSlots = Get-OpenMatrixSlots
Write-Host "Existing shader slots: [$($existingSlots -join ', ')]" -ForegroundColor DarkGray
Write-Host "Currently open slots:  [$($openSlots -join ', ')]" -ForegroundColor DarkGray

# Find a slot to launch
$availableSlots = $existingSlots | Where-Object { $_ -notin $openSlots }
if ($availableSlots.Count -eq 0) {
    Write-Host ""
    Write-Host "All slots already open. Close a Matrix window to test launch." -ForegroundColor Yellow
    exit
}

$testSlot = $availableSlots[0]
$pname = "Matrix-$testSlot"

Write-Host ""
Write-Host "Launching $pname with polling (100ms intervals, 5s timeout)..." -ForegroundColor Cyan
Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline

$startTime = Get-Date
Start-Process wt -ArgumentList "-p `"$pname`""

if (Wait-ForMatrixWindow $pname) {
    $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
    Write-Host " OK (detected in ${elapsed}ms)" -ForegroundColor Green
} else {
    Write-Host " TIMEOUT (5000ms)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test complete." -ForegroundColor Cyan
