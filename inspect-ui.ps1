# Inspect the UI Automation tree of Windows Terminal
# Run this while a Matrix window is in focus

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

$handle = [WinAPI]::GetForegroundWindow()
$element = [System.Windows.Automation.AutomationElement]::FromHandle($handle)

Write-Host "=== INSPECTING FOREGROUND WINDOW ===" -ForegroundColor Cyan
Write-Host "Window Name: $($element.Current.Name)"
Write-Host "Window ClassName: $($element.Current.ClassName)"
Write-Host ""

$all = $element.FindAll(
    [System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition
)

Write-Host "=== ALL UI ELEMENTS WITH NAMES ===" -ForegroundColor Yellow
foreach ($child in $all) {
    $name = $child.Current.Name
    $className = $child.Current.ClassName
    $controlType = $child.Current.ControlType.ProgrammaticName
    $automationId = $child.Current.AutomationId

    if ($name -or $automationId) {
        Write-Host "[$controlType] Name='$name' Class='$className' AutomationId='$automationId'"
    }
}
