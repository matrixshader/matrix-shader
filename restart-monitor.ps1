# Restart the matrix monitor with updated code
Write-Host "=== Restarting Matrix Monitor ===" -ForegroundColor Cyan

# Find and kill old monitor
$procs = Get-Process -Name powershell -ErrorAction SilentlyContinue
foreach ($p in $procs) {
    $cmdLine = ""
    try {
        $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($p.Id)").CommandLine
    } catch {}

    if ($cmdLine -like "*matrix_monitor*") {
        Write-Host "Killing old monitor PID $($p.Id)..." -ForegroundColor Yellow
        Stop-Process -Id $p.Id -Force
        Start-Sleep -Milliseconds 500
    }
}

# Start new monitor
Write-Host "Starting new monitor..." -ForegroundColor Green
$monitorPath = "$PSScriptRoot\matrix_monitor.ps1"
Start-Process powershell -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", $monitorPath

Write-Host "Monitor restarted!" -ForegroundColor Green

# Also apply layout immediately to fix current overlaps
Write-Host ""
Write-Host "Applying Pillars layout to fix current positions..." -ForegroundColor Cyan

. "$PSScriptRoot\WindowIdentityService.ps1"
. "$PSScriptRoot\WindowLayoutEngine.ps1"

$windows = Get-AllMatrixWindows -IncludeRedpill:$false
Write-Host "Found $($windows.Count) windows" -ForegroundColor Gray

$handles = @{}
foreach ($w in $windows) {
    $profileName = "Matrix-$($w.Slot)"
    $handles[$profileName] = @{ Handle = $w.Handle }
}

if ($handles.Count -gt 0) {
    Invoke-MatrixWindowLayout -WindowHandles $handles -Mode "Pillars"
    Write-Host "Layout applied!" -ForegroundColor Green
}

# Show new positions
Write-Host ""
Write-Host "=== NEW POSITIONS ===" -ForegroundColor Cyan
foreach ($w in $windows) {
    $rect = New-Object 'MatrixWindowAPI+RECT'
    [MatrixWindowAPI]::GetWindowRect($w.Handle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    Write-Host "Slot $($w.Slot): X=$($rect.Left) Y=$($rect.Top) W=$width H=$height" -ForegroundColor Yellow
}
