# Debug positioning
. "$PSScriptRoot\WindowLayoutEngine.ps1"

Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class DebugAPI {
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

Write-Host "=== DEBUG POSITIONING ===" -ForegroundColor Cyan

# Find windows
$windows = [DebugAPI]::FindMatrixWindows()
Write-Host "Found $($windows.Count) windows:" -ForegroundColor Yellow
foreach ($w in $windows) {
    Write-Host "  $($w.Key) = '$($w.Value)'"
}

# Build handles
$windowHandles = @{}
foreach ($w in $windows) {
    if ($w.Value -match "Matrix-(\d+)") {
        $slot = [int]$Matches[1]
        $windowHandles["Matrix-$slot"] = @{ Handle = $w.Key }
        Write-Host "  Mapped: Matrix-$slot -> $($w.Key)"
    }
}

Write-Host ""
Write-Host "=== CONFIG ===" -ForegroundColor Cyan
$config = Get-MatrixLayoutConfig
Write-Host "Mode: $($config.Mode)"
Write-Host "GapSize: $($config.GapSize)"
Write-Host "WindowsOnPrimary: $($config.WindowsOnPrimary)"

Write-Host ""
Write-Host "=== SCREENS ===" -ForegroundColor Cyan
$screens = Get-ScreenTopology
foreach ($s in $screens) {
    Write-Host "  Screen $($s.Index): Left=$($s.Left) W=$($s.Width) Primary=$($s.IsPrimary)"
}

Write-Host ""
Write-Host "=== CALLING Invoke-MatrixWindowLayout ===" -ForegroundColor Cyan
try {
    $result = Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode $config.Mode -Verbose
    Write-Host ""
    Write-Host "=== RESULT ===" -ForegroundColor Green
    foreach ($r in $result) {
        Write-Host "  $($r.Name): X=$($r.X) Y=$($r.Y) W=$($r.Width) H=$($r.Height)"
    }
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
