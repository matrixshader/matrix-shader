# US-009 Test: Diagnostic Logging
# Tests that REAL operations log correctly when MATRIX_DEBUG=1
# Uses slots 5-8 only

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$debugLogPath = "$matrixDir\debug.log"
$shadersDir = "$matrixDir\shaders"

# Load functions from matrix_control.ps1
$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

# Helper to close test windows
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TestCleanup009 {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;
}
"@ -ErrorAction SilentlyContinue

function Close-TestWindow($handle) {
    [TestCleanup009]::SendMessage($handle, [TestCleanup009]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
}

Write-Host ""
Write-Host "US-009 TEST: Diagnostic Logging (Real Operations)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor DarkGray
Write-Host ""

# Clean up any existing log
if (Test-Path $debugLogPath) {
    Remove-Item $debugLogPath -Force
}

$allPassed = $true

# TEST 1: No logging when MATRIX_DEBUG unset
Write-Host "TEST 1: No logging when MATRIX_DEBUG unset" -ForegroundColor Yellow
Write-Host "------------------------------------------" -ForegroundColor DarkGray
$env:MATRIX_DEBUG = $null

# Trigger a real operation - detect windows
$windows = Get-MatrixWindowInfo

if (Test-Path $debugLogPath) {
    Write-Host "FAIL: Log created when MATRIX_DEBUG not set" -ForegroundColor Red
    $allPassed = $false
} else {
    Write-Host "PASS: No log file created" -ForegroundColor Green
}

# TEST 2: Real operations log when MATRIX_DEBUG=1
Write-Host ""
Write-Host "TEST 2: Real operations with MATRIX_DEBUG=1" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor DarkGray
$env:MATRIX_DEBUG = "1"

# Find available test slot
$testSlots = @(5, 6, 7, 8)
$existingSlots = Get-ExistingSlots
$openSlots = Get-OpenMatrixSlots
$availableSlots = $testSlots | Where-Object { ($_ -in $existingSlots) -and ($_ -notin $openSlots) }

if ($availableSlots.Count -eq 0) {
    Write-Host "ERROR: No test slots available" -ForegroundColor Red
    exit 1
}

$testSlot = $availableSlots[0]
$pname = "Matrix-$testSlot"

# Operation 1: Detect windows (triggers DETECT logs)
Write-Host "  Detecting windows..." -ForegroundColor DarkGray
$windowInfo = Get-MatrixWindowInfo

# Operation 2: Save a shader (triggers SAVE logs)
Write-Host "  Saving shader..." -ForegroundColor DarkGray
$testConfig = @{ R="0.5"; G="1.0"; B="0.3"; Speed="1.0"; Glow="1.0"; Width="12"; Trail="8"; Dens="0.5"; L1="1.0"; L2="1.0"; L3="1.0" }
Save-Shader $testSlot $testConfig

# Operation 3: Launch a window (triggers LAUNCH logs)
Write-Host "  Launching $pname..." -ForegroundColor DarkGray
Start-Process wt -ArgumentList "-p `"$pname`""
$detected = Wait-ForMatrixWindow $pname
if ($detected) {
    Write-Host "    Window launched" -ForegroundColor DarkGray
}

# Operation 4: Position windows (triggers POSITION logs)
Write-Host "  Positioning windows..." -ForegroundColor DarkGray
Position-MatrixWindows

# Check log file
Start-Sleep -Milliseconds 500
if (Test-Path $debugLogPath) {
    $logContent = Get-Content $debugLogPath -Raw

    # Check for each operation type
    $hasDetect = $logContent -match '\[DETECT\]'
    $hasSave = $logContent -match '\[SAVE\]'
    $hasPosition = $logContent -match '\[POSITION\]'

    Write-Host ""
    Write-Host "  Log entries found:" -ForegroundColor DarkGray

    if ($hasDetect) {
        Write-Host "    [DETECT] - PASS" -ForegroundColor Green
    } else {
        Write-Host "    [DETECT] - FAIL (missing)" -ForegroundColor Red
        $allPassed = $false
    }

    if ($hasSave) {
        Write-Host "    [SAVE] - PASS" -ForegroundColor Green
    } else {
        Write-Host "    [SAVE] - FAIL (missing)" -ForegroundColor Red
        $allPassed = $false
    }

    if ($hasPosition) {
        Write-Host "    [POSITION] - PASS" -ForegroundColor Green
    } else {
        Write-Host "    [POSITION] - FAIL (missing)" -ForegroundColor Red
        $allPassed = $false
    }

    # Show sample log entries
    $lines = @($logContent -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -First 5)
    Write-Host ""
    Write-Host "  Sample entries:" -ForegroundColor DarkGray
    foreach ($line in $lines) {
        $short = if ($line.Length -gt 70) { $line.Substring(0,70) + "..." } else { $line }
        Write-Host "    $short" -ForegroundColor DarkMagenta
    }
} else {
    Write-Host "FAIL: No log file created" -ForegroundColor Red
    $allPassed = $false
}

# Cleanup - close test window
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 500
$windows = Get-MatrixWindows
foreach ($win in $windows.GetEnumerator()) {
    if ($win.Value -match $pname) {
        Close-TestWindow $win.Key
        Write-Host "  Closed $pname" -ForegroundColor DarkGray
        break
    }
}

# Clear debug mode
$env:MATRIX_DEBUG = $null

# Summary
Write-Host ""
Write-Host "==================================================" -ForegroundColor DarkGray
if ($allPassed) {
    Write-Host "US-009: ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "US-009: SOME TESTS FAILED" -ForegroundColor Red
}
Write-Host ""
