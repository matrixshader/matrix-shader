# BLUEPILL - Instant Matrix Launch
# Uses saved state from matrix_state.json, detects existing windows

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$stateFile = "$matrixDir\matrix_state.json"
$shadersDir = "$matrixDir\shaders"
$windowRegistryPath = "$matrixDir\window-registry.json"

# Check if state exists
if (-not (Test-Path $stateFile)) {
    Write-Host ""
    Write-Host " ERROR: No saved state found." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' first to set up your Matrix." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Load state
try {
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    $slots = @($state.lastSlots)
    if ($slots.Count -eq 0) {
        Write-Host ""
        Write-Host " ERROR: No slots in saved state." -ForegroundColor Red
        Write-Host " Run 'wakeupneo' to configure." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host " ERROR: Could not read state: $_" -ForegroundColor Red
    Write-Host " Run 'wakeupneo' to reconfigure." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host " BLUEPILL - Instant Launch" -ForegroundColor Blue
Write-Host " =========================" -ForegroundColor DarkGray
Write-Host ""
Write-Host " Saved state: slots [$($slots -join ', ')]" -ForegroundColor DarkGray

# Import shared utilities
. "$PSScriptRoot\MatrixUtils.ps1"

# Import WindowLayoutEngine for centralized positioning
. "$PSScriptRoot\WindowLayoutEngine.ps1"

# Import WindowIdentityService for launch tracking and window detection
. "$PSScriptRoot\WindowIdentityService.ps1"

Add-Type -AssemblyName System.Windows.Forms

function Get-MatrixWindowInfoForBluepill {
    # Returns array of @{Handle, Slot} for Matrix windows
    # Uses WindowIdentityService's 4-layer identity hierarchy

    # Use WindowIdentityService to get all Matrix windows (exclude Redpill)
    $identityWindows = Get-AllMatrixWindows -IncludeRedpill:$false

    $result = @()
    foreach ($win in $identityWindows) {
        if ($win.Slot) {
            $result += @{
                Handle = $win.Handle
                Slot = $win.Slot
                IdentitySource = $win.IdentitySource
            }
        }
    }

    return $result
}

function Position-MatrixWindows {
    Start-Sleep -Milliseconds 500

    $windowInfo = Get-MatrixWindowInfoForBluepill

    if ($windowInfo.Count -eq 0) {
        Write-Host "   No Matrix windows detected" -ForegroundColor Yellow
        return
    }

    # Try to restore saved positions first (like Chrome restoring window positions)
    if (Restore-WindowPositions -WindowInfo $windowInfo) {
        Write-Host "   Restored $($windowInfo.Count) windows to saved positions" -ForegroundColor Green
        return
    }

    # Fall back to layout engine if no saved positions
    $windowHandles = @{}
    foreach ($win in $windowInfo) {
        $windowHandles["Matrix-$($win.Slot)"] = @{ Handle = $win.Handle }
    }

    $result = Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode 'Auto'

    Write-Host "   Positioned $($windowInfo.Count) windows using layout engine" -ForegroundColor Green
}

# Find which slots are already open using WindowIdentityService
Write-Host " Checking for existing windows..." -ForegroundColor Cyan
$identityWindows = Get-AllMatrixWindows -IncludeRedpill:$false
$openSlots = @{}

foreach ($win in $identityWindows) {
    if ($win.Slot) {
        $openSlots[$win.Slot] = $true
        Write-Host "   Slot $($win.Slot) already open (via $($win.IdentitySource))" -ForegroundColor DarkGray
    }
}

# Launch only slots that aren't open
Write-Host " Launching windows..." -ForegroundColor Cyan

$launched = 0
foreach ($slot in $slots) {
    $pname = "Matrix-$slot"

    if ($openSlots.ContainsKey($slot)) {
        Write-Host "   $pname - already open, skipping" -ForegroundColor DarkGray
        continue
    }

    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline

    # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
    $existingHandles = Get-ExistingWindowHandles

    Start-Process wt -ArgumentList "-p `"$pname`""

    # LAYER 1 INTEGRATION: Wait for new handle and register it
    $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

    if ($newHandle -ne [IntPtr]::Zero) {
        Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
    $launched++
}

if ($launched -eq 0 -and $openSlots.Count -gt 0) {
    Write-Host "   All windows already open" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host " Positioning windows..." -ForegroundColor Cyan
Position-MatrixWindows

# Start background monitor for drag-and-drop snap
# Runs silently, auto-exits when Matrix windows close
$monitorScript = "$matrixDir\matrix_monitor.ps1"
if (Test-Path $monitorScript) {
    Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorScript`"" -WindowStyle Hidden
    Write-Host " Window monitor started (drag-snap enabled)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host " THE MATRIX HAS YOU." -ForegroundColor Green
Write-Host " Type 'redpill' to customize." -ForegroundColor DarkGray
Write-Host ""
