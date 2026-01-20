# Close test windows (slots 5-8)
$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$windows = Get-MatrixWindows
foreach ($win in $windows.GetEnumerator()) {
    $slot = $null
    # Get slot from UI Automation
    try {
        $auto = [System.Windows.Automation.AutomationElement]
        $winElement = $auto::FromHandle($win.Key)
        if ($winElement) {
            $allCondition = [System.Windows.Automation.Condition]::TrueCondition
            $children = $winElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allCondition)
            foreach ($child in $children) {
                if ($child.Current.Name -match "^Matrix-(\d+)$") {
                    $slot = [int]$Matches[1]
                    break
                }
            }
        }
    } catch { }

    # Close if slot 5-8
    if ($slot -ge 5 -and $slot -le 8) {
        Write-Host "Closing Matrix-$slot (handle $($win.Key))..." -ForegroundColor Yellow
        $process = Get-Process -Id (Get-WindowThreadProcessId $win.Key) -ErrorAction SilentlyContinue

        # Send close message
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowClose {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;
}
"@ -ErrorAction SilentlyContinue
        [WindowClose]::SendMessage($win.Key, [WindowClose]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
        Write-Host "  Sent close message" -ForegroundColor Green
    }
}

Write-Host "Done." -ForegroundColor Cyan
