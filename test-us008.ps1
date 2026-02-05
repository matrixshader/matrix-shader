# US-008 Test: Poll-Based Window Launch
# Uses slots 5-8 only (preserves existing windows 1-4)
# Auto-cleans up test windows

$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

# Helper to close a window by handle
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TestCleanup {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;
}
"@ -ErrorAction SilentlyContinue

function Close-TestWindow($handle) {
    [TestCleanup]::SendMessage($handle, [TestCleanup]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
}

Write-Host ""
Write-Host "US-008 TEST: Poll-Based Window Launch" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor DarkGray
Write-Host ""

$testSlots = @(5, 6, 7, 8)
$existingSlots = Get-ExistingSlots
$openSlots = Get-OpenMatrixSlots

Write-Host "Test slots: 5-8 | Open: [$($openSlots -join ', ')]" -ForegroundColor DarkGray
Write-Host ""

# Find available test slot
$availableTestSlots = $testSlots | Where-Object {
    ($_ -in $existingSlots) -and ($_ -notin $openSlots)
}

if ($availableTestSlots.Count -eq 0) {
    Write-Host "ERROR: No test slots (5-8) available. Close a test window." -ForegroundColor Red
    exit 1
}

$allPassed = $true

# TEST 1: Multi-Window Detection (launch 3 windows in sequence)
Write-Host "TEST 1: Multi-Window Sequential Launch" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor DarkGray

$launchedWindows = @()
$testCount = [Math]::Min(3, $availableTestSlots.Count)

for ($i = 0; $i -lt $testCount; $i++) {
    $testSlot = $availableTestSlots[$i]
    $pname = "Matrix-$testSlot"

    Write-Host "Launching $pname..." -ForegroundColor Cyan
    Start-Process wt -ArgumentList "-p `"$pname`""
    $pollStart = Get-Date
    $result = Wait-ForMatrixWindow $pname
    $pollElapsed = ((Get-Date) - $pollStart).TotalMilliseconds

    if ($result -and $pollElapsed -lt 5000) {
        Write-Host "  PASS: Detected in $([int]$pollElapsed)ms" -ForegroundColor Green
        $launchedWindows += $pname
    } elseif ($result) {
        Write-Host "  FAIL: Detected in $([int]$pollElapsed)ms (over 5s but returned true)" -ForegroundColor Red
        $allPassed = $false
        $launchedWindows += $pname
    } else {
        Write-Host "  FAIL: TIMEOUT - $pname not detected within 5s" -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host "Launched $($launchedWindows.Count)/$testCount windows successfully" -ForegroundColor $(if ($launchedWindows.Count -eq $testCount) { "Green" } else { "Yellow" })

# Cleanup all launched windows
Start-Sleep -Milliseconds 500
$windows = Get-MatrixWindows
foreach ($win in $windows.GetEnumerator()) {
    foreach ($pname in $launchedWindows) {
        if ($win.Value -match $pname) {
            Close-TestWindow $win.Key
            Write-Host "  (cleaned up $pname)" -ForegroundColor DarkGray
            break
        }
    }
}
Start-Sleep -Milliseconds 500

# TEST 2: Timeout
Write-Host ""
Write-Host "TEST 2: Timeout Behavior" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor DarkGray
Write-Host "Waiting for 'Matrix-FAKE' (5s timeout)..." -ForegroundColor Cyan

$startTime = Get-Date
$result2 = Wait-ForMatrixWindow "Matrix-FAKE" 5000
$elapsed2 = ((Get-Date) - $startTime).TotalMilliseconds

if (-not $result2 -and $elapsed2 -ge 4900 -and $elapsed2 -le 5500) {
    Write-Host "PASS: Timeout at $([int]$elapsed2)ms (returned false)" -ForegroundColor Green
} else {
    Write-Host "FAIL: Unexpected result=$result2 at $([int]$elapsed2)ms" -ForegroundColor Red
    $allPassed = $false
}

# Summary
Write-Host ""
Write-Host "======================================" -ForegroundColor DarkGray
if ($allPassed) {
    Write-Host "US-008: ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "US-008: SOME TESTS FAILED" -ForegroundColor Red
}
Write-Host ""
