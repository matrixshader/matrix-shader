# Debug: Enumerate all windows to find Matrix ones
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WindowEnumerator {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public static List<Tuple<IntPtr, string>> GetAllWindows() {
        var windows = new List<Tuple<IntPtr, string>>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                var sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                var title = sb.ToString();
                if (!string.IsNullOrEmpty(title)) {
                    windows.Add(Tuple.Create(hWnd, title));
                }
            }
            return true;
        }, IntPtr.Zero);
        return windows;
    }
}
"@

Write-Host "=== All Visible Windows ===" -ForegroundColor Cyan
$allWindows = [WindowEnumerator]::GetAllWindows()
Write-Host "Total visible windows with titles: $($allWindows.Count)"

Write-Host "`n=== Matrix Windows ===" -ForegroundColor Yellow
$matrixWindows = $allWindows | Where-Object { $_.Item2 -match "Matrix" }
Write-Host "Found $($matrixWindows.Count) windows with 'Matrix' in title:"
foreach ($win in $matrixWindows) {
    Write-Host "  Handle: $($win.Item1) | Title: '$($win.Item2)'"
}

Write-Host "`n=== Redpill Windows ===" -ForegroundColor Yellow
$redpillWindows = $allWindows | Where-Object { $_.Item2 -match "Redpill|RED PILL" }
Write-Host "Found $($redpillWindows.Count) windows with 'Redpill' in title:"
foreach ($win in $redpillWindows) {
    Write-Host "  Handle: $($win.Item1) | Title: '$($win.Item2)'"
}
