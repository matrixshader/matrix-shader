# ROBUST DETECTION: Use shader hot-reload to identify windows
# Change each shader to a unique color, detect which window changes

$shadersDir = "C:\Users\ehome\Documents\Matrix\shaders"
$windowRegistryPath = "C:\Users\ehome\Documents\Matrix\window-registry.json"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;

public delegate bool EnumWinProc(IntPtr hWnd, IntPtr lParam);

public class DetectAPI {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWinProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    public const int SW_RESTORE = 9;
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    private static Dictionary<IntPtr, string> _windows;

    public static Dictionary<IntPtr, string> FindTerminalWindows() {
        _windows = new Dictionary<IntPtr, string>();
        EnumWindows(new EnumWinProc(CB), IntPtr.Zero);
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
            var p = System.Diagnostics.Process.GetProcessById((int)pid);
            if (p.ProcessName != "WindowsTerminal") return true;
        } catch { return true; }
        _windows.Add(hWnd, title);
        return true;
    }
}
"@ -ErrorAction SilentlyContinue

# Get windows
$windows = [DetectAPI]::FindTerminalWindows()
$windowList = @()
foreach ($w in $windows.GetEnumerator()) {
    $windowList += [PSCustomObject]@{ Handle = $w.Key; Title = $w.Value }
}

Write-Host "Found $($windowList.Count) windows to identify." -ForegroundColor Cyan
Write-Host ""
Write-Host "I will flash each shader slot with a UNIQUE COLOR." -ForegroundColor Yellow
Write-Host "Watch your windows and note which one flashes for each slot." -ForegroundColor Yellow
Write-Host ""

# Define test colors for each slot
$testColors = @{
    1 = @{ R = "1.0"; G = "0.0"; B = "0.0" }  # BRIGHT RED
    2 = @{ R = "0.0"; G = "0.0"; B = "1.0" }  # BRIGHT BLUE
    3 = @{ R = "1.0"; G = "1.0"; B = "0.0" }  # BRIGHT YELLOW
}

# Backup original shaders
Write-Host "Backing up original shaders..." -ForegroundColor DarkGray
for ($slot = 1; $slot -le 3; $slot++) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    if (Test-Path $path) {
        Copy-Item $path "$path.bak" -Force
    }
}

# Flash each slot one at a time
for ($slot = 1; $slot -le 3; $slot++) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    if (-not (Test-Path "$path.bak")) { continue }

    $color = $testColors[$slot]
    $colorName = switch ($slot) { 1 { "RED" } 2 { "BLUE" } 3 { "YELLOW" } }

    Write-Host "Slot $slot will flash $colorName in 2 seconds..." -ForegroundColor White
    Start-Sleep -Seconds 2

    # Read shader and change color
    $content = Get-Content "$path.bak" -Raw
    $content = $content -replace '#define RAIN_R\s+[\d.]+', "#define RAIN_R         $($color.R)"
    $content = $content -replace '#define RAIN_G\s+[\d.]+', "#define RAIN_G         $($color.G)"
    $content = $content -replace '#define RAIN_B\s+[\d.]+', "#define RAIN_B         $($color.B)"

    # Write changed shader
    [System.IO.File]::WriteAllText($path, $content)

    Write-Host "  >>> SLOT $slot IS NOW $colorName - WHICH WINDOW CHANGED? <<<" -ForegroundColor $colorName
    Start-Sleep -Seconds 3

    # Restore original
    Copy-Item "$path.bak" $path -Force
    Write-Host "  (restored)" -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "Done flashing. Now tell me which window was which color:" -ForegroundColor Cyan
Write-Host ""

# List windows for user to identify
$i = 1
foreach ($w in $windowList) {
    Write-Host "  Window $i : '$($w.Title)'"
    $i++
}

# Cleanup backups
for ($slot = 1; $slot -le 3; $slot++) {
    Remove-Item "$shadersDir\Matrix-$slot.hlsl.bak" -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Which window was RED (Slot 1)? Which was BLUE (Slot 2)? Which was YELLOW (Slot 3)?" -ForegroundColor Magenta
