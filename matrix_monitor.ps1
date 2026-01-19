# MATRIX WINDOW MONITOR
# Background process that monitors Matrix window positions and snaps them back when dragged
# Runs independently of Redpill - starts with bluepill, runs until all Matrix windows close

$matrixDir = "$env:USERPROFILE\Documents\Matrix"

# Import layout engine
. "$PSScriptRoot\WindowLayoutEngine.ps1"

# Add Window API
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class MonitorAPI {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    private static List<KeyValuePair<IntPtr, string>> foundWindows;

    public static List<KeyValuePair<IntPtr, string>> FindMatrixWindows() {
        foundWindows = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                uint processId;
                GetWindowThreadProcessId(hWnd, out processId);
                try {
                    var process = Process.GetProcessById((int)processId);
                    if (process.ProcessName.Equals("WindowsTerminal", StringComparison.OrdinalIgnoreCase)) {
                        var sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, 256);
                        var title = sb.ToString();
                        if (!string.IsNullOrEmpty(title) && title.Contains("Matrix-") && !title.Contains("Redpill")) {
                            foundWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, title));
                        }
                    }
                } catch { }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }
}
"@

function Get-MatrixWindowHandles {
    $windows = [MonitorAPI]::FindMatrixWindows()
    $result = @()
    foreach ($w in $windows) {
        if ($w.Value -match "Matrix-(\d+)") {
            $result += @{
                Handle = $w.Key
                Slot = [int]$Matches[1]
            }
        }
    }
    return $result
}

function Position-AllMatrixWindows {
    $windowInfo = Get-MatrixWindowHandles
    if ($windowInfo.Count -eq 0) { return }

    $windowHandles = @{}
    foreach ($win in $windowInfo) {
        $windowHandles["Matrix-$($win.Slot)"] = @{ Handle = $win.Handle }
    }

    try {
        $config = Get-MatrixLayoutConfig
        $mode = if ($config.Mode) { $config.Mode } else { 'Pillars' }
        Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode $mode | Out-Null
    }
    catch { }
}

# Settings
$pollIntervalMs = 200   # Check every 200ms
$dragSettleMs = 400     # Wait after drag detected before repositioning
$noWindowsTimeout = 5000  # Exit after 5 seconds with no Matrix windows

Write-Host "Matrix Window Monitor started" -ForegroundColor Cyan
Write-Host "Monitoring for window drags... (Ctrl+C to stop)" -ForegroundColor DarkGray

$noWindowsTime = 0
$initialized = $false

while ($true) {
    $windowInfo = Get-MatrixWindowHandles
    $handles = @($windowInfo | ForEach-Object { $_.Handle })

    # Exit if no Matrix windows for too long
    if ($handles.Count -eq 0) {
        $noWindowsTime += $pollIntervalMs
        if ($noWindowsTime -ge $noWindowsTimeout) {
            Write-Host "No Matrix windows detected for $($noWindowsTimeout/1000)s. Exiting." -ForegroundColor Yellow
            exit 0
        }
        Start-Sleep -Milliseconds $pollIntervalMs
        continue
    }
    $noWindowsTime = 0

    # Initialize tracking if needed
    if (-not $initialized -or $handles.Count -ne $script:LastKnownPositions.Count) {
        Initialize-PositionTracking -WindowHandles $handles
        $initialized = $true
    }

    # Check for drag
    if (Test-WindowDragDetected -WindowHandles $handles) {
        Write-Host "Drag detected - repositioning..." -ForegroundColor Green
        Start-Sleep -Milliseconds $dragSettleMs
        Position-AllMatrixWindows
        Update-PositionTracking -WindowHandles $handles
    }

    Start-Sleep -Milliseconds $pollIntervalMs
}
