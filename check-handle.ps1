# Check what window Handle=11862224 is
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class HandleChecker {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
}
"@ -ErrorAction SilentlyContinue

$handle = [IntPtr]11862224

Write-Host "=== Checking Handle $handle ===" -ForegroundColor Cyan

$isValid = [HandleChecker]::IsWindow($handle)
Write-Host "Is Valid Window: $isValid" -ForegroundColor $(if ($isValid) { "Green" } else { "Red" })

if ($isValid) {
    $isVisible = [HandleChecker]::IsWindowVisible($handle)
    Write-Host "Is Visible: $isVisible" -ForegroundColor $(if ($isVisible) { "Green" } else { "Yellow" })

    $titleBuilder = New-Object System.Text.StringBuilder 256
    [HandleChecker]::GetWindowText($handle, $titleBuilder, 256) | Out-Null
    $title = $titleBuilder.ToString()
    Write-Host "Title: '$title'" -ForegroundColor Yellow

    $classBuilder = New-Object System.Text.StringBuilder 256
    [HandleChecker]::GetClassName($handle, $classBuilder, 256) | Out-Null
    $className = $classBuilder.ToString()
    Write-Host "Class: '$className'" -ForegroundColor Yellow

    $pid = 0
    [HandleChecker]::GetWindowThreadProcessId($handle, [ref]$pid) | Out-Null
    Write-Host "PID: $pid" -ForegroundColor Yellow

    if ($pid -gt 0) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            Write-Host "Process: $($proc.ProcessName)" -ForegroundColor Yellow
        } catch {
            Write-Host "Process: (not found)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "Handle is not a valid window - may be stale/closed" -ForegroundColor Gray
}
