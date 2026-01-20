# Detect actual profile for each window using UI Automation and fix registry
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;

public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

public class FixAPI {
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

$auto = [System.Windows.Automation.AutomationElement]

Write-Host "Detecting ACTUAL profiles via UI Automation..." -ForegroundColor Cyan
Write-Host ""

$windows = [FixAPI]::FindTerminalWindows()
$newRegistry = @{}

foreach ($w in $windows.GetEnumerator()) {
    $handle = $w.Key
    $title = $w.Value

    # Get UI Automation element for this window
    try {
        $winElement = $auto::FromHandle($handle)

        # Find TermControl child - it has the profile name
        $allCondition = [System.Windows.Automation.Condition]::TrueCondition
        $children = $winElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allCondition)

        $profileName = $null
        foreach ($child in $children) {
            $childName = $child.Current.Name
            if ($childName -match "^Matrix-(\d+)$") {
                $profileName = $childName
                break
            }
        }

        if ($profileName) {
            $slot = [int]$Matches[1]
            $shaderFile = "Matrix-$slot.hlsl"
            $newRegistry[$handle.ToString()] = $shaderFile

            $rect = New-Object FixAPI+RECT
            [FixAPI]::GetWindowRect($handle, [ref]$rect) | Out-Null

            Write-Host "Handle $handle -> $profileName (Slot $slot) at X=$($rect.Left)" -ForegroundColor Green
            Write-Host "  Title: '$title'"
        } else {
            Write-Host "Handle $handle -> NO PROFILE DETECTED" -ForegroundColor Red
            Write-Host "  Title: '$title'"
        }
    } catch {
        Write-Host "Handle $handle -> ERROR: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "New Registry:" -ForegroundColor Yellow
$newRegistry | ConvertTo-Json

# Save it
$registryPath = "C:\Users\ehome\Documents\MATRIX\window-registry.json"
$newRegistry | ConvertTo-Json | Set-Content $registryPath -Encoding UTF8
Write-Host ""
Write-Host "Registry FIXED!" -ForegroundColor Green
