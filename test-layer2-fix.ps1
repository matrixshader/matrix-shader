# Test Layer 2 Fix - Command Line Parsing via Child Processes
# This script verifies that Get-CommandLineIdentities now queries child processes

# Enable debug logging
$env:MATRIX_DEBUG = 1

# Dot source the identity service
. "$PSScriptRoot\WindowIdentityService.ps1"

Write-Host "`n=== Layer 2 Fix Test ===" -ForegroundColor Cyan
Write-Host "Testing child process command line parsing`n" -ForegroundColor Cyan

# Find Windows Terminal processes
$wtProcesses = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue

if (-not $wtProcesses) {
    Write-Host "ERROR: No WindowsTerminal processes found" -ForegroundColor Red
    Write-Host "Please launch Matrix windows first using matrix_setup.ps1 or matrix_control.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($wtProcesses.Count) WindowsTerminal process(es)" -ForegroundColor Green

# Get PIDs
$pids = @($wtProcesses | ForEach-Object { $_.Id })
Write-Host "PIDs: $($pids -join ', ')`n" -ForegroundColor Gray

# Show child processes for each WT process
Write-Host "=== Child Processes ===" -ForegroundColor Cyan
foreach ($pid in $pids) {
    $children = Get-CimInstance -Query "SELECT ProcessId, CommandLine, Name FROM Win32_Process WHERE ParentProcessId=$pid"
    Write-Host "Parent PID $pid children:" -ForegroundColor Yellow
    foreach ($child in $children) {
        Write-Host "  - $($child.Name) (PID $($child.ProcessId)): $($child.CommandLine)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Testing Get-CommandLineIdentities ===" -ForegroundColor Cyan

# Call the fixed function
$identities = Get-CommandLineIdentities -ProcessIds $pids

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  Matched: $($identities.Count) out of $($pids.Count) processes`n" -ForegroundColor Green

if ($identities.Count -eq 0) {
    Write-Host "ERROR: No identities found!" -ForegroundColor Red
    Write-Host "Expected to find Matrix-N patterns in child process command lines" -ForegroundColor Yellow
} else {
    foreach ($pid in $identities.Keys) {
        $identity = $identities[$pid]
        Write-Host "PID $pid" -ForegroundColor Cyan
        Write-Host "  Profile: $($identity.ProfileName)" -ForegroundColor White
        Write-Host "  Shader: $($identity.ShaderFile)" -ForegroundColor White
        Write-Host "  Slot: $($identity.Slot)" -ForegroundColor White
        Write-Host "  Source: $($identity.IdentitySource)" -ForegroundColor White
        Write-Host "  Confidence: $($identity.Confidence)" -ForegroundColor White
        Write-Host "  Child PID: $($identity.ChildPid)" -ForegroundColor White
        Write-Host "  Command: $($identity.CommandLine)" -ForegroundColor Gray
        Write-Host ""
    }
}

Write-Host "=== Test Complete ===" -ForegroundColor Cyan

# Check debug log
if (Test-Path "C:\Users\ehome\Documents\MATRIX\debug.log") {
    Write-Host "`nDebug log available at: C:\Users\ehome\Documents\MATRIX\debug.log" -ForegroundColor Yellow
    Write-Host "Last 20 lines:" -ForegroundColor Yellow
    Get-Content "C:\Users\ehome\Documents\MATRIX\debug.log" | Select-Object -Last 20
}
