# Test window detection and positioning
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;

public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

public class TestAPI {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    private static Dictionary<IntPtr, string> _windows;
    public static Dictionary<IntPtr, string> FindTerminalWindows() {
        _windows = new Dictionary<IntPtr, string>();
        EnumWindows(new EnumWindowsProc(CB), IntPtr.Zero);
        return _windows;
    }
    private static bool CB(IntPtr hWnd, IntPtr lParam) {
        if (!IsWindowVisible(hWnd)) return true;
        int len = GetWindowTextLength(hWnd);
        if (len == 0) return true;
        StringBuilder sb = new StringBuilder(len + 1);
        GetWindowText(hWnd, sb, sb.Capacity);
        string title = sb.ToString();
        if (title.Contains("Redpill")) return true;
        uint pid;
        GetWindowThreadProcessId(hWnd, out pid);
        try {
            var proc = System.Diagnostics.Process.GetProcessById((int)pid);
            if (proc.ProcessName != "WindowsTerminal") return true;
        } catch { return true; }
        _windows.Add(hWnd, title);
        return true;
    }
}
"@

$registryPath = "C:\Users\ehome\Documents\MATRIX\window-registry.json"
$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

Write-Host "Current Matrix Windows:" -ForegroundColor Cyan
Write-Host ""

$windows = [TestAPI]::FindTerminalWindows()
$results = @()

foreach ($w in $windows.GetEnumerator()) {
    $handle = $w.Key.ToString()
    $shaderFile = $registry.$handle
    $slot = if ($shaderFile -match 'Matrix-(\d+)') { [int]$Matches[1] } else { 0 }

    $rect = New-Object TestAPI+RECT
    [TestAPI]::GetWindowRect($w.Key, [ref]$rect) | Out-Null

    $results += [PSCustomObject]@{
        Handle = $handle
        Slot = $slot
        X = $rect.Left
        Title = $w.Value
    }
}

# Sort by X position (leftmost first)
$byPosition = $results | Sort-Object { $_.X }

Write-Host "By SCREEN POSITION (left to right):" -ForegroundColor Yellow
$pos = 1
foreach ($r in $byPosition) {
    Write-Host "  Position $pos : Slot $($r.Slot) at X=$($r.X)"
    Write-Host "              Title: '$($r.Title)'"
    $pos++
}

Write-Host ""
Write-Host "By SLOT NUMBER:" -ForegroundColor Yellow
$bySlot = $results | Sort-Object { $_.Slot }
foreach ($r in $bySlot) {
    Write-Host "  Slot $($r.Slot): at X=$($r.X) - '$($r.Title)'"
}

Write-Host ""
if (($byPosition | ForEach-Object { $_.Slot }) -eq ($bySlot | ForEach-Object { $_.Slot })) {
    Write-Host "CORRECT: Windows are positioned in slot order!" -ForegroundColor Green
} else {
    Write-Host "MISMATCH: Windows are NOT in slot order!" -ForegroundColor Red
    Write-Host "Expected order: $($bySlot.Slot -join ', ')"
    Write-Host "Actual order:   $($byPosition.Slot -join ', ')"
}
