# US-008 Timeout Test
# Verifies timeout works by waiting for non-existent window

$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

Write-Host ""
Write-Host "US-008 TIMEOUT TEST" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Testing 5s timeout by waiting for 'Matrix-FAKE' (doesn't exist)..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
$result = Wait-ForMatrixWindow "Matrix-FAKE" 5000
$elapsed = ((Get-Date) - $startTime).TotalMilliseconds

Write-Host "RESULT: $result" -ForegroundColor $(if ($result) { "Red" } else { "Green" })
Write-Host "Elapsed: $([int]$elapsed)ms" -ForegroundColor DarkGray
Write-Host ""

if (-not $result -and $elapsed -ge 4900 -and $elapsed -le 5500) {
    Write-Host "PASS: Timeout triggered correctly around 5s" -ForegroundColor Green
} elseif ($result) {
    Write-Host "FAIL: Should have returned false (timeout)" -ForegroundColor Red
} else {
    Write-Host "FAIL: Timeout at unexpected time ($([int]$elapsed)ms, expected ~5000ms)" -ForegroundColor Red
}
Write-Host ""
