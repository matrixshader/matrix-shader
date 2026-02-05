# verify-publish.ps1 - Verify all 6 executables exist
$PublishDir = "C:\Users\ehome\documents\matrix\installer\publish"
$required = @('wakeupneo.exe', 'bluepill.exe', 'redpill.exe', 'matrixlite.exe', 'matrix-hotkeys.exe', 'matrix-monitor.exe')

$missing = $required | Where-Object { -not (Test-Path (Join-Path $PublishDir $_)) }
if ($missing) {
    Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "All 6 executables present:" -ForegroundColor Green
$required | ForEach-Object {
    $size = [math]::Round((Get-Item (Join-Path $PublishDir $_)).Length / 1MB, 1)
    Write-Host "  $_`: $size MB" -ForegroundColor Gray
}
