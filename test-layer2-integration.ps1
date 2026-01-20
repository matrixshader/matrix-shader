# Integration Test: Layer 2 Fix with Full Identity Resolution
# Tests the child process parsing fix in the context of the full identity service

param(
    [switch]$Verbose
)

if ($Verbose) {
    $env:MATRIX_DEBUG = 1
}

# Dot source the identity service
. "$PSScriptRoot\WindowIdentityService.ps1"

Write-Host "`n=== Layer 2 Integration Test ===" -ForegroundColor Cyan
Write-Host "Testing child process command line parsing in full identity resolution`n"

# Find all Matrix windows
Write-Host "Finding all Matrix windows..." -ForegroundColor Yellow
$allWindows = Get-AllMatrixWindows

if (-not $allWindows -or $allWindows.Count -eq 0) {
    Write-Host "ERROR: No Matrix windows found" -ForegroundColor Red
    Write-Host "Launch Matrix windows first using matrix_setup.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($allWindows.Count) Matrix window(s)`n" -ForegroundColor Green

# Test each window
$layer2Successes = 0
$layer2Failures = 0

foreach ($win in $allWindows) {
    Write-Host "--- Window ---" -ForegroundColor Cyan
    Write-Host "Handle: $($win.Handle)" -ForegroundColor Gray
    Write-Host "Title: $($win.Title)" -ForegroundColor White
    Write-Host "PID: $($win.ProcessId)" -ForegroundColor Gray

    # Get identity
    $identity = $win.Identity

    if (-not $identity) {
        Write-Host "Identity: FAILED" -ForegroundColor Red
        $layer2Failures++
    } else {
        Write-Host "Profile: $($identity.ProfileName)" -ForegroundColor White
        Write-Host "Shader: $($identity.ShaderFile)" -ForegroundColor White
        Write-Host "Slot: $($identity.Slot)" -ForegroundColor White
        Write-Host "Source: $($identity.IdentitySource)" -ForegroundColor $(
            if ($identity.IdentitySource -eq 'CommandLine') { 'Green' } else { 'Yellow' }
        )
        Write-Host "Confidence: $($identity.Confidence)" -ForegroundColor White

        if ($identity.IdentitySource -eq 'CommandLine') {
            Write-Host ">>> Layer 2 SUCCESS <<<" -ForegroundColor Green
            if ($identity.ChildPid) {
                Write-Host "Child PID: $($identity.ChildPid)" -ForegroundColor Gray
            }
            if ($identity.CommandLine) {
                Write-Host "Command: $($identity.CommandLine)" -ForegroundColor Gray
            }
            $layer2Successes++
        } else {
            Write-Host ">>> Layer 2 FAILED (fell back to $($identity.IdentitySource)) <<<" -ForegroundColor Yellow
            $layer2Failures++
        }
    }

    Write-Host ""
}

# Summary
Write-Host "=== Test Results ===" -ForegroundColor Cyan
Write-Host "Total Windows: $($allWindows.Count)" -ForegroundColor White
Write-Host "Layer 2 Successes: $layer2Successes" -ForegroundColor Green
Write-Host "Layer 2 Failures: $layer2Failures" -ForegroundColor $(
    if ($layer2Failures -eq 0) { 'Green' } else { 'Red' }
)

$successRate = if ($allWindows.Count -gt 0) {
    [math]::Round(($layer2Successes / $allWindows.Count) * 100, 1)
} else { 0 }

Write-Host "Success Rate: $successRate%" -ForegroundColor $(
    if ($successRate -ge 100) { 'Green' }
    elseif ($successRate -ge 80) { 'Yellow' }
    else { 'Red' }
)

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
if ($layer2Successes -eq $allWindows.Count) {
    Write-Host "PASS: All windows identified via Layer 2 (child process command line)" -ForegroundColor Green
} elseif ($layer2Successes -gt 0) {
    Write-Host "PARTIAL: Some windows identified via Layer 2, others fell back to Layer 3" -ForegroundColor Yellow
} else {
    Write-Host "FAIL: No windows identified via Layer 2" -ForegroundColor Red
    Write-Host "Check debug.log for details" -ForegroundColor Yellow
}

if ($Verbose -and (Test-Path "C:\Users\ehome\Documents\MATRIX\debug.log")) {
    Write-Host "`n=== Debug Log (Last 30 lines) ===" -ForegroundColor Cyan
    Get-Content "C:\Users\ehome\Documents\MATRIX\debug.log" | Select-Object -Last 30
}

Write-Host "`nTest complete." -ForegroundColor Cyan
