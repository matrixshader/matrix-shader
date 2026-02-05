# Try to detect which profile each window is using via UI Automation
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$auto = [System.Windows.Automation.AutomationElement]

# Get all top-level windows
$root = $auto::RootElement
$condition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
)

$windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $condition)

Write-Host "Checking Windows Terminal windows for profile info..." -ForegroundColor Cyan
Write-Host ""

foreach ($win in $windows) {
    $name = $win.Current.Name
    $className = $win.Current.ClassName
    $processId = $win.Current.ProcessId

    # Check if it's Windows Terminal
    try {
        $proc = Get-Process -Id $processId -ErrorAction Stop
        if ($proc.ProcessName -ne "WindowsTerminal") { continue }
    } catch { continue }

    if ($name -match "Redpill") { continue }

    Write-Host "Window: '$name'" -ForegroundColor Yellow
    Write-Host "  ClassName: $className"
    Write-Host "  ProcessId: $processId"
    Write-Host "  AutomationId: $($win.Current.AutomationId)"
    Write-Host "  Handle: $($win.Current.NativeWindowHandle)"

    # Try to get more properties
    try {
        $itemStatus = $win.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::ItemStatusProperty)
        if ($itemStatus) { Write-Host "  ItemStatus: $itemStatus" }
    } catch {}

    try {
        $helpText = $win.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::HelpTextProperty)
        if ($helpText) { Write-Host "  HelpText: $helpText" }
    } catch {}

    # Look for child elements that might have profile info
    $allCondition = [System.Windows.Automation.Condition]::TrueCondition
    $children = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allCondition)

    foreach ($child in $children) {
        $childName = $child.Current.Name
        $childClass = $child.Current.ClassName
        $childAutoId = $child.Current.AutomationId

        # Look for anything that might indicate profile
        if ($childAutoId -match "profile|tab|Matrix" -or $childName -match "Matrix-\d") {
            Write-Host "  Found: Name='$childName' Class='$childClass' AutomationId='$childAutoId'" -ForegroundColor Green
        }
    }

    Write-Host ""
}
