# US-008 Debug Test
# Tests Wait-ForMatrixWindow with verbose output

$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

Write-Host ""
Write-Host "US-008 DEBUG TEST" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor DarkGray

# Override Wait-ForMatrixWindow with debug version
function Wait-ForMatrixWindow-Debug([string]$profileName, [int]$timeoutMs = 5000) {
    $pollInterval = 100
    $startTime = Get-Date
    $beforeCount = (Get-MatrixWindows).Count
    $iteration = 0

    Write-Host "   DEBUG: Starting poll, beforeCount=$beforeCount" -ForegroundColor Magenta

    while ($true) {
        Start-Sleep -Milliseconds $pollInterval
        $iteration++
        $elapsed = ((Get-Date) - $startTime).TotalMilliseconds

        # Strict timeout check after each sleep
        if ($elapsed -ge $timeoutMs) {
            Write-Host "   DEBUG: TIMEOUT at iteration $iteration, elapsed=${elapsed}ms" -ForegroundColor Red
            return $false
        }

        # Check windows
        $checkStart = Get-Date
        $windows = Get-MatrixWindows
        $checkTime = ((Get-Date) - $checkStart).TotalMilliseconds

        if ($windows.Count -gt $beforeCount) {
            foreach ($win in $windows.GetEnumerator()) {
                if ($win.Value -match $profileName) {
                    Write-Host "   DEBUG: FOUND at iteration $iteration, elapsed=${elapsed}ms, checkTime=${checkTime}ms" -ForegroundColor Green
                    return $true
                }
            }
        }

        if ($iteration % 10 -eq 0) {
            Write-Host "   DEBUG: iteration $iteration, elapsed=${elapsed}ms, count=$($windows.Count), checkTime=${checkTime}ms" -ForegroundColor DarkMagenta
        }
    }
}

# Find available test slot
$testSlots = @(5, 6, 7, 8)
$existingSlots = Get-ExistingSlots
$openSlots = Get-OpenMatrixSlots

$availableTestSlots = $testSlots | Where-Object {
    ($_ -in $existingSlots) -and ($_ -notin $openSlots)
}

if ($availableTestSlots.Count -eq 0) {
    Write-Host "ERROR: No test slots available" -ForegroundColor Red
    exit 1
}

$testSlot = $availableTestSlots[0]
$pname = "Matrix-$testSlot"

Write-Host ""
Write-Host "Launching $pname with DEBUG polling..." -ForegroundColor Cyan
Write-Host ""

Start-Process wt -ArgumentList "-p `"$pname`""
$pollStart = Get-Date
$result = Wait-ForMatrixWindow-Debug $pname
$pollElapsed = ((Get-Date) - $pollStart).TotalMilliseconds

Write-Host ""
Write-Host "RESULT: $result in $([int]$pollElapsed)ms" -ForegroundColor $(if ($result) { "Green" } else { "Yellow" })

# Auto-cleanup: close the test window
Write-Host ""
Write-Host "Cleaning up - closing $pname..." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 500
$windows = Get-MatrixWindows
foreach ($win in $windows.GetEnumerator()) {
    if ($win.Value -match $pname) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinClose {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;
}
"@ -ErrorAction SilentlyContinue
        [WinClose]::SendMessage($win.Key, [WinClose]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        Write-Host "  Closed." -ForegroundColor Green
        break
    }
}
Write-Host ""
