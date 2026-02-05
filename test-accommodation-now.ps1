# Quick test script for dynamic accommodation
# Run this in a PowerShell window to see what's happening

$ErrorActionPreference = "Stop"
$env:MATRIX_DEBUG = "1"

Write-Host "=== TESTING SMART WINDOW MANAGEMENT ===" -ForegroundColor Cyan
Write-Host ""

# Import modules
Write-Host "Loading modules..." -ForegroundColor Yellow
. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"

# Check for Matrix windows
Write-Host ""
Write-Host "=== DETECTING WINDOWS ===" -ForegroundColor Cyan
$windows = Get-AllMatrixWindows
Write-Host "Found $($windows.Count) Matrix windows:" -ForegroundColor Green

foreach ($w in $windows) {
    Write-Host "  - $($w.ProfileName): Handle=$($w.Handle), Source=$($w.IdentitySource)" -ForegroundColor White
}

if ($windows.Count -eq 0) {
    Write-Host "No Matrix windows found! Open some Matrix windows first." -ForegroundColor Red
    exit 1
}

# Initialize accommodation system
Write-Host ""
Write-Host "=== INITIALIZING ACCOMMODATION ===" -ForegroundColor Cyan
$windowHandles = @{}
foreach ($w in $windows) {
    $windowHandles[$w.ProfileName] = @{ Handle = $w.Handle }
}
Initialize-AccommodationSystem -WindowHandles $windowHandles
Write-Host "Accommodation system initialized" -ForegroundColor Green

# Show current state
Write-Host ""
Write-Host "=== CURRENT STATE ===" -ForegroundColor Cyan
$summary = Get-AccommodationStateSummary
Write-Host $summary

# Monitor for drags
Write-Host ""
Write-Host "=== MONITORING FOR DRAGS ===" -ForegroundColor Cyan
Write-Host "Drag a window to another monitor to test accommodation." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

$pollInterval = 200
while ($true) {
    # Get fresh window list
    $windows = Get-AllMatrixWindows
    if ($windows.Count -eq 0) {
        Write-Host "No windows found - exiting" -ForegroundColor Red
        break
    }

    # Convert to handles format
    $windowHandles = @{}
    foreach ($w in $windows) {
        $windowHandles[$w.ProfileName] = @{ Handle = $w.Handle }
    }

    # Process drag events
    $result = Process-WindowDragEvents -WindowHandles $windowHandles

    if ($result -and $result.DragDetected) {
        Write-Host ""
        Write-Host "DRAG DETECTED!" -ForegroundColor Green
        Write-Host "  Window: $($result.DraggedWindow)" -ForegroundColor White
        Write-Host "  From Monitor: $($result.FromMonitor) -> To Monitor: $($result.ToMonitor)" -ForegroundColor White
        Write-Host "  Accommodation: $($result.AccommodationResult)" -ForegroundColor White
        Write-Host ""
    }

    Start-Sleep -Milliseconds $pollInterval
}
