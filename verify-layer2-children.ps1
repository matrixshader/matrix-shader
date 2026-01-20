# Quick verification: Show child processes and their command lines
# This demonstrates WHY Layer 2 needs to query children, not parents

Write-Host "`n=== WindowsTerminal Process Tree ===" -ForegroundColor Cyan

$wtProcesses = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue

if (-not $wtProcesses) {
    Write-Host "ERROR: No WindowsTerminal processes found" -ForegroundColor Red
    Write-Host "Launch Matrix windows first" -ForegroundColor Yellow
    exit 1
}

foreach ($wt in $wtProcesses) {
    $pid = $wt.Id

    Write-Host "`nParent: WindowsTerminal.exe (PID $pid)" -ForegroundColor Yellow

    # Show parent command line (will be empty or generic)
    $parentProc = Get-CimInstance -Query "SELECT CommandLine FROM Win32_Process WHERE ProcessId=$pid"
    Write-Host "  Command Line: $($parentProc.CommandLine)" -ForegroundColor Gray
    if (-not $parentProc.CommandLine) {
        Write-Host "  (No command line - this is why Layer 2 failed!)" -ForegroundColor Red
    }

    # Show children
    $children = Get-CimInstance -Query "SELECT ProcessId, Name, CommandLine FROM Win32_Process WHERE ParentProcessId=$pid"

    if ($children.Count -eq 0) {
        Write-Host "  No children found" -ForegroundColor Gray
    } else {
        Write-Host "`n  Children:" -ForegroundColor Cyan
        foreach ($child in $children) {
            Write-Host "    - $($child.Name) (PID $($child.ProcessId))" -ForegroundColor White
            Write-Host "      Command: $($child.CommandLine)" -ForegroundColor Gray

            # Check for Matrix pattern
            if ($child.CommandLine -match 'title\s+Matrix-(\d+)') {
                Write-Host "      >>> FOUND MATRIX-$($Matches[1]) PATTERN <<<" -ForegroundColor Green
            }
            elseif ($child.CommandLine -match '(?i)redpill') {
                Write-Host "      >>> FOUND REDPILL PATTERN <<<" -ForegroundColor Magenta
            }
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Parent processes (WindowsTerminal.exe): Have NO profile info" -ForegroundColor Red
Write-Host "Child processes (cmd.exe, etc.): Have 'title Matrix-N' in command line" -ForegroundColor Green
Write-Host "Layer 2 must query children, not parents!" -ForegroundColor Yellow
