# Check for hotkey-related apps and settings

Write-Host "=== HOTKEY APPS RUNNING ===" -ForegroundColor Cyan
$hotkeyApps = @('autohotkey', 'powertoys', 'keypirinha', 'launchy', 'listary', 'wox', 'flow', 'ueli', 'executor')
$found = Get-Process | Where-Object { $hotkeyApps -contains $_.ProcessName.ToLower() }
if ($found) {
    $found | ForEach-Object { Write-Host "  $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Yellow }
} else {
    Write-Host "  None detected" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== POWERTOYS ===" -ForegroundColor Cyan
$ptPath = "$env:LOCALAPPDATA\Microsoft\PowerToys"
if (Test-Path $ptPath) {
    Write-Host "  Installed at: $ptPath" -ForegroundColor Green
    $settings = Get-ChildItem $ptPath -Filter "settings.json" -Recurse -ErrorAction SilentlyContinue
    $settings | ForEach-Object { Write-Host "  Config: $($_.FullName)" -ForegroundColor Gray }
} else {
    Write-Host "  Not installed" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== AUTOHOTKEY SCRIPTS ===" -ForegroundColor Cyan
$ahkPaths = @(
    "$env:USERPROFILE\Documents\AutoHotkey",
    "$env:USERPROFILE\AutoHotkey.ahk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
)
$foundAhk = $false
foreach ($p in $ahkPaths) {
    if (Test-Path $p) {
        $items = Get-ChildItem $p -Filter "*.ahk" -ErrorAction SilentlyContinue
        if ($items) {
            $items | ForEach-Object {
                Write-Host "  $($_.FullName)" -ForegroundColor Yellow
                $foundAhk = $true
            }
        }
    }
}
if (-not $foundAhk) {
    Write-Host "  None found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== WINDOWS BUILT-IN SHORTCUTS (common conflicts) ===" -ForegroundColor Cyan
Write-Host "  Win+Arrow        : Snap windows (built-in)" -ForegroundColor DarkGray
Write-Host "  Ctrl+Shift+Esc   : Task Manager" -ForegroundColor DarkGray
Write-Host "  Ctrl+Shift+N     : New folder (Explorer)" -ForegroundColor DarkGray
Write-Host "  Alt+Tab          : Switch windows" -ForegroundColor DarkGray
Write-Host "  Win+Tab          : Task View" -ForegroundColor DarkGray
Write-Host "  Win+Shift+Arrow  : Move window to other monitor" -ForegroundColor DarkGray

Write-Host ""
Write-Host "=== SUGGESTED AVAILABLE COMBOS ===" -ForegroundColor Cyan
Write-Host "  Ctrl+Alt+Arrow   : Usually free" -ForegroundColor Green
Write-Host "  Ctrl+Win+Arrow   : Usually free (unless video drivers)" -ForegroundColor Green
Write-Host "  Win+Ctrl+Shift+Arrow : Very unlikely to conflict" -ForegroundColor Green

Write-Host ""
Write-Host "=== REGISTRY: Shell Hotkeys ===" -ForegroundColor Cyan
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $disabledHotkeys = Get-ItemProperty -Path $regPath -Name "DisabledHotkeys" -ErrorAction SilentlyContinue
    if ($disabledHotkeys) {
        Write-Host "  Disabled hotkeys: $($disabledHotkeys.DisabledHotkeys)" -ForegroundColor Yellow
    } else {
        Write-Host "  No disabled hotkeys in registry" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not read registry" -ForegroundColor Gray
}
