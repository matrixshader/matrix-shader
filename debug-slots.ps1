# Debug: What slots does Redpill think exist and where do saves go?

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$shadersDir = "$matrixDir\shaders"

# Replicate the window detection logic from matrix_control.ps1
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class SlotDebug {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    private static List<KeyValuePair<IntPtr, string>> foundWindows;

    public static List<KeyValuePair<IntPtr, string>> FindAllTerminalWindows(string excludePattern) {
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
                        if (!string.IsNullOrEmpty(title)) {
                            if (string.IsNullOrEmpty(excludePattern) ||
                                !System.Text.RegularExpressions.Regex.IsMatch(title, excludePattern)) {
                                foundWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, title));
                            }
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

Write-Host "=== SLOT ASSIGNMENT DEBUG ===" -ForegroundColor Cyan
Write-Host ""

# Get windows (same as Get-MatrixWindows)
$windows = [SlotDebug]::FindAllTerminalWindows("Redpill")

Write-Host "Detected Windows Terminal windows (excluding Redpill):" -ForegroundColor Yellow
$virtualSlot = 100
foreach ($win in $windows) {
    $title = $win.Value
    if ($title -match "Matrix-(\d+)") {
        $slot = [int]$Matches[1]
        Write-Host "  '$title' -> Slot $slot -> saves to Matrix-$slot.hlsl" -ForegroundColor Green
    } else {
        Write-Host "  '$title' -> Slot $virtualSlot (VIRTUAL) -> saves to Matrix-$virtualSlot.hlsl" -ForegroundColor Red
        Write-Host "    ^ THIS IS THE BUG - Matrix-$virtualSlot.hlsl doesn't exist!" -ForegroundColor Red
        $virtualSlot++
    }
}

Write-Host ""
Write-Host "Shader files that actually exist:" -ForegroundColor Yellow
Get-ChildItem "$shadersDir\Matrix-*.hlsl" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }

Write-Host ""
Write-Host "What shader does 'Windows PowerShell' profile use?" -ForegroundColor Yellow
$wtSettings = Get-Content "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Raw | ConvertFrom-Json
$defaultShader = $wtSettings.profiles.defaults.'experimental.pixelShaderPath'
Write-Host "  profiles.defaults shader: $defaultShader" -ForegroundColor Cyan
