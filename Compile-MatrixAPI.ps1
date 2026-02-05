# Compile-MatrixAPI.ps1
# Pre-compiles the P/Invoke declarations into a DLL for instant loading
# Run this ONCE after installation to create MatrixAPI.dll

$ErrorActionPreference = "Stop"
$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$dllPath = "$matrixDir\MatrixAPI.dll"

Write-Host "Compiling MatrixAPI.dll..." -ForegroundColor Cyan

# Combined C# source with all P/Invoke declarations
$source = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

// Combined API for all Matrix window operations
public class WindowAPI {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, byte bAlpha, uint dwFlags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int SW_RESTORE = 9;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const int GWL_EXSTYLE = -20;
    public const int GWL_STYLE = -16;
    public const int WS_EX_LAYERED = 0x80000;
    public const int WS_VISIBLE = 0x10000000;
    public const uint LWA_ALPHA = 0x2;

    // Static storage for EnumWindows callback
    private static List<WindowInfo> foundWindows;

    public struct WindowInfo {
        public IntPtr Handle;
        public string Title;
        public uint ProcessId;
    }

    public static List<WindowInfo> GetAllWindows() {
        foundWindows = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                string title = sb.ToString();
                if (!string.IsNullOrEmpty(title)) {
                    uint pid;
                    GetWindowThreadProcessId(hWnd, out pid);
                    foundWindows.Add(new WindowInfo { Handle = hWnd, Title = title, ProcessId = pid });
                }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }

    public static uint GetProcessId(IntPtr hWnd) {
        uint processId;
        GetWindowThreadProcessId(hWnd, out processId);
        return processId;
    }
}

// Alias classes for backwards compatibility
public class WindowLayoutAPI : WindowAPI { }
public class MatrixWindowAPI : WindowAPI { }
"@

try {
    # Compile to DLL
    Add-Type -TypeDefinition $source -OutputAssembly $dllPath -OutputType Library
    Write-Host "[OK] Created $dllPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "MatrixAPI.dll compiled successfully!" -ForegroundColor Green
    Write-Host "Redpill will now load in under 2 seconds." -ForegroundColor Cyan
} catch {
    Write-Host "[ERROR] Compilation failed: $_" -ForegroundColor Red
    exit 1
}
