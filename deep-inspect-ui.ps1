# Deep inspection of ALL Windows Terminal windows' UI Automation trees
# Looking for ANYTHING that could identify the profile

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class DeepInspectAPI {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    private static List<IntPtr> _handles = new List<IntPtr>();

    public static List<IntPtr> FindAllTerminalWindows() {
        _handles.Clear();
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            try {
                var p = Process.GetProcessById((int)pid);
                if (p.ProcessName == "WindowsTerminal") {
                    _handles.Add(hWnd);
                }
            } catch { }
            return true;
        }, IntPtr.Zero);
        return _handles;
    }
}
"@

$handles = [DeepInspectAPI]::FindAllTerminalWindows()
Write-Host "=== FOUND $($handles.Count) WINDOWS TERMINAL WINDOWS ===" -ForegroundColor Cyan
Write-Host ""

foreach ($handle in $handles) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "WINDOW HANDLE: $handle" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

    try {
        $element = [System.Windows.Automation.AutomationElement]::FromHandle($handle)

        Write-Host "ROOT ELEMENT:" -ForegroundColor Yellow
        Write-Host "  Name: '$($element.Current.Name)'"
        Write-Host "  ClassName: '$($element.Current.ClassName)'"
        Write-Host "  AutomationId: '$($element.Current.AutomationId)'"
        Write-Host "  ControlType: $($element.Current.ControlType.ProgrammaticName)"
        Write-Host "  LocalizedControlType: '$($element.Current.LocalizedControlType)'"
        Write-Host "  FrameworkId: '$($element.Current.FrameworkId)'"
        Write-Host "  ItemType: '$($element.Current.ItemType)'"
        Write-Host "  ItemStatus: '$($element.Current.ItemStatus)'"
        Write-Host "  AcceleratorKey: '$($element.Current.AcceleratorKey)'"
        Write-Host "  AccessKey: '$($element.Current.AccessKey)'"
        Write-Host "  HelpText: '$($element.Current.HelpText)'"
        Write-Host ""

        # Get ALL descendants
        $all = $element.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition
        )

        Write-Host "ALL DESCENDANTS ($($all.Count) elements):" -ForegroundColor Yellow

        foreach ($child in $all) {
            $name = $child.Current.Name
            $className = $child.Current.ClassName
            $controlType = $child.Current.ControlType.ProgrammaticName
            $automationId = $child.Current.AutomationId
            $helpText = $child.Current.HelpText
            $itemStatus = $child.Current.ItemStatus

            # Show ALL elements, not just ones with names
            $info = "[$controlType]"
            if ($name) { $info += " Name='$name'" }
            if ($className) { $info += " Class='$className'" }
            if ($automationId) { $info += " AutomationId='$automationId'" }
            if ($helpText) { $info += " HelpText='$helpText'" }
            if ($itemStatus) { $info += " ItemStatus='$itemStatus'" }

            # Highlight anything that might be profile-related
            if ($name -match "Matrix|Redpill|Profile|GUID|Shader" -or
                $automationId -match "Matrix|Profile|Tab|Pane" -or
                $className -match "Terminal|Profile|Tab") {
                Write-Host $info -ForegroundColor Magenta
            } else {
                Write-Host $info -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "Error inspecting window: $_" -ForegroundColor Red
    }

    Write-Host ""
}

Write-Host "=== INSPECTION COMPLETE ===" -ForegroundColor Cyan
