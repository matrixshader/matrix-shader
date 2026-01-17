# Debug transparency detection
Write-Host "=== Transparency Debug ===" -ForegroundColor Cyan

Write-Host "`nLooking for Matrix windows..." -ForegroundColor Yellow
$matrixProcs = Get-Process | Where-Object { $_.MainWindowTitle -match "Matrix" }
Write-Host "Found $($matrixProcs.Count) processes with 'Matrix' in title"

foreach ($proc in $matrixProcs) {
    Write-Host "  PID: $($proc.Id) | Name: $($proc.ProcessName) | Title: '$($proc.MainWindowTitle)' | Handle: $($proc.MainWindowHandle)"
}

Write-Host "`nLooking for WindowsTerminal processes..." -ForegroundColor Yellow
$wtProcs = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
Write-Host "Found $($wtProcs.Count) WindowsTerminal processes"

foreach ($proc in $wtProcs) {
    Write-Host "  PID: $($proc.Id) | Title: '$($proc.MainWindowTitle)' | Handle: $($proc.MainWindowHandle)"
}

Write-Host "`nCurrent PowerShell PID: $PID" -ForegroundColor Yellow
