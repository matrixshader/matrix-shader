Add-Type -AssemblyName UIAutomationClient
$automation = [System.Windows.Automation.AutomationElement]::RootElement
$condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, 'CASCADIA_HOSTING_WINDOW_CLASS')
$windows = $automation.FindAll([System.Windows.Automation.TreeScope]::Children, $condition)
Write-Host "Found $($windows.Count) Windows Terminal windows"
foreach ($w in $windows) {
    $hwnd = $w.Current.NativeWindowHandle
    $name = $w.Current.Name
    Write-Host "HWND: $hwnd - Title: $name"
}
