# Diagnostic script for window identity issues
cd $PSScriptRoot
. .\WindowIdentityService.ps1
. .\MatrixLogging.ps1

Write-Host ""
Write-Host "=== REGISTERED WINDOWS (State File) ===" -ForegroundColor Cyan
$state = Get-MatrixState
if ($state.RegisteredWindows) {
    $state.RegisteredWindows | Format-Table -AutoSize
} else {
    Write-Host "  (none)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== ACTUAL WINDOWS DETECTED ===" -ForegroundColor Cyan
$windows = Get-AllMatrixWindows -IncludeRedpill:$false
if ($windows) {
    $windows | Select-Object Slot, Handle, Title, ProfileName, DetectionMethod | Format-Table -AutoSize
} else {
    Write-Host "  (none)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
$regCount = if ($state.RegisteredWindows) { $state.RegisteredWindows.Count } else { 0 }
$detCount = if ($windows) { @($windows).Count } else { 0 }
Write-Host "Registered in state: $regCount"
Write-Host "Actually detected:   $detCount"

Write-Host ""
Write-Host "=== SLOT ASSIGNMENT ===" -ForegroundColor Cyan
$slots = @{}
foreach ($w in $windows) {
    $slots[$w.Slot] = $w.Handle
}
for ($i = 1; $i -le 6; $i++) {
    if ($slots[$i]) {
        Write-Host "  Slot $i : $($slots[$i])" -ForegroundColor Green
    } else {
        Write-Host "  Slot $i : (empty)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== RAW TERMINAL WINDOWS ===" -ForegroundColor Cyan
$allTerminals = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue |
    ForEach-Object { $_.MainWindowHandle } |
    Where-Object { $_ -ne 0 }
Write-Host "Total WindowsTerminal processes with windows: $($allTerminals.Count)"
