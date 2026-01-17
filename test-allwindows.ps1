# Debug: Show all visible windows
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinDebug {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    private static List<KeyValuePair<IntPtr, string>> allWindows;

    public static List<KeyValuePair<IntPtr, string>> GetAllWindows() {
        allWindows = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                var sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                var title = sb.ToString();
                if (!string.IsNullOrEmpty(title)) {
                    allWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, title));
                }
            }
            return true;
        }, IntPtr.Zero);
        return allWindows;
    }
}
"@

$all = [WinDebug]::GetAllWindows()
Write-Host "All visible windows:" -ForegroundColor Cyan
$all | Where-Object { $_.Value -match "Matrix|Redpill|Terminal" } | ForEach-Object {
    Write-Host "  $($_.Key): '$($_.Value)'"
}
