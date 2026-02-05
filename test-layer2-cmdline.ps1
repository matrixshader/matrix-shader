# Test what command lines are actually available for Windows Terminal processes
Write-Host "=== TESTING LAYER 2: COMMAND LINE ANALYSIS ===" -ForegroundColor Cyan
Write-Host ""

# Get all Windows Terminal processes
$wtProcesses = Get-Process WindowsTerminal -ErrorAction SilentlyContinue

if (-not $wtProcesses) {
    Write-Host "No WindowsTerminal processes found" -ForegroundColor Red
    exit
}

Write-Host "Found $($wtProcesses.Count) WindowsTerminal process(es)" -ForegroundColor Yellow
Write-Host ""

foreach ($proc in $wtProcesses) {
    Write-Host "=== Process: $($proc.ProcessName) (PID: $($proc.Id)) ===" -ForegroundColor Green

    # Get command line via WMI
    $wmiProc = Get-CimInstance -Query "SELECT ProcessId, CommandLine, ParentProcessId FROM Win32_Process WHERE ProcessId=$($proc.Id)"

    Write-Host "  Command Line: $($wmiProc.CommandLine)" -ForegroundColor White
    Write-Host "  Parent PID: $($wmiProc.ParentProcessId)" -ForegroundColor Gray

    # Check parent process
    $parentProc = Get-CimInstance -Query "SELECT ProcessId, CommandLine, Name FROM Win32_Process WHERE ProcessId=$($wmiProc.ParentProcessId)" -ErrorAction SilentlyContinue
    if ($parentProc) {
        Write-Host "  Parent Name: $($parentProc.Name)" -ForegroundColor Gray
        Write-Host "  Parent CmdLine: $($parentProc.CommandLine)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Also check for any wt.exe processes (the launcher)
Write-Host "=== Looking for wt.exe launcher processes ===" -ForegroundColor Yellow
$wtLaunchers = Get-CimInstance -Query "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='wt.exe'"
if ($wtLaunchers) {
    foreach ($launcher in $wtLaunchers) {
        Write-Host "  wt.exe PID $($launcher.ProcessId): $($launcher.CommandLine)" -ForegroundColor Magenta
    }
} else {
    Write-Host "  No wt.exe launcher processes found (they exit immediately)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Check all child processes of WindowsTerminal.exe ===" -ForegroundColor Yellow
foreach ($proc in $wtProcesses) {
    $children = Get-CimInstance -Query "SELECT ProcessId, CommandLine, Name FROM Win32_Process WHERE ParentProcessId=$($proc.Id)"
    if ($children) {
        Write-Host "Children of PID $($proc.Id):" -ForegroundColor Green
        foreach ($child in $children) {
            Write-Host "  $($child.Name) (PID $($child.ProcessId)): $($child.CommandLine)" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "=== CONCLUSION ===" -ForegroundColor Cyan
Write-Host "The command line of WindowsTerminal.exe shows what we have to work with." -ForegroundColor White
Write-Host "wt.exe is a launcher that passes commands via COM, then exits immediately." -ForegroundColor White
