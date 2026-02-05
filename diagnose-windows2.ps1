# Simple window diagnostic
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class WinDiag2 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public static List<IntPtr> Handles = new List<IntPtr>();

    public static bool Callback(IntPtr hWnd, IntPtr lParam) {
        StringBuilder cn = new StringBuilder(256);
        GetClassName(hWnd, cn, 256);
        if (cn.ToString() == "CASCADIA_HOSTING_WINDOW_CLASS" && IsWindowVisible(hWnd)) {
            Handles.Add(hWnd);
        }
        return true;
    }
}
"@

[WinDiag2]::Handles.Clear()
[WinDiag2]::EnumWindows({ param($h,$l) [WinDiag2]::Callback($h,$l) }, [IntPtr]::Zero)

Write-Host ""
Write-Host "=== ALL WINDOWS TERMINAL WINDOWS ===" -ForegroundColor Cyan
foreach ($h in [WinDiag2]::Handles) {
    $title = New-Object System.Text.StringBuilder 256
    [WinDiag2]::GetWindowText($h, $title, 256) | Out-Null
    $pid = [uint32]0
    [WinDiag2]::GetWindowThreadProcessId($h, [ref]$pid) | Out-Null
    $titleStr = $title.ToString()

    # Check if it looks like a Matrix window
    $isMatrix = $titleStr -match "Matrix-\d"
    $color = if ($isMatrix) { "Green" } else { "Yellow" }

    Write-Host "  Handle: $h" -ForegroundColor $color -NoNewline
    Write-Host "  PID: $pid" -NoNewline
    Write-Host "  Title: $titleStr"
}
Write-Host ""
Write-Host "Total Windows Terminal windows: $([WinDiag2]::Handles.Count)" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== STATE FILE ===" -ForegroundColor Cyan
$stateFile = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"
if (Test-Path $stateFile) {
    Get-Content $stateFile
} else {
    Write-Host "  State file not found at: $stateFile" -ForegroundColor Red
}
