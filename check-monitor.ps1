# Check if matrix_monitor.ps1 is running
$procs = Get-Process -Name powershell -ErrorAction SilentlyContinue
Write-Host "=== PowerShell Processes ===" -ForegroundColor Cyan
foreach ($p in $procs) {
    $cmdLine = ""
    try {
        $cmdLine = (Get-WmiObject Win32_Process -Filter "ProcessId = $($p.Id)").CommandLine
    } catch {}

    if ($cmdLine -like "*matrix_monitor*") {
        Write-Host "FOUND MONITOR: PID=$($p.Id)" -ForegroundColor Green
        Write-Host "  CommandLine: $cmdLine" -ForegroundColor DarkGray
    } elseif ($cmdLine -like "*matrix*" -or $cmdLine -like "*Matrix*") {
        Write-Host "Matrix-related: PID=$($p.Id)" -ForegroundColor Yellow
        Write-Host "  CommandLine: $cmdLine" -ForegroundColor DarkGray
    }
}

# Also check if there's a running hidden job
$jobs = Get-Job -ErrorAction SilentlyContinue
if ($jobs) {
    Write-Host "`n=== Background Jobs ===" -ForegroundColor Cyan
    $jobs | ForEach-Object {
        Write-Host "Job: $($_.Name) State: $($_.State)" -ForegroundColor Yellow
    }
}
