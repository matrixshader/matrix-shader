# US-001 Test: Safe Atomic File Writes
Write-Host "=== US-001 Test: Safe Atomic File Writes ===" -ForegroundColor Cyan
Write-Host ""

$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$scriptPath = "$PSScriptRoot\matrix_control.ps1"
$allPassed = $true

Write-Host "Test 1: Verify settings.json exists" -ForegroundColor Yellow
if (Test-Path $wtSettingsPath) {
    Write-Host "  PASS: settings.json found" -ForegroundColor Green
} else {
    Write-Host "  FAIL: settings.json not found" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 2: Verify Move-Item -Force pattern in code" -ForegroundColor Yellow
$code = Get-Content $scriptPath -Raw
if ($code -match "Move-Item.+\`$wtSettingsPath.+-Force") {
    Write-Host "  PASS: Move-Item -Force pattern found" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Move-Item -Force pattern NOT found" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 3: Verify try-catch error handling in Save-TerminalEffects" -ForegroundColor Yellow
if ($code -match "function Save-TerminalEffects[\s\S]*?try\s*\{" -and $code -match "catch\s*\{[\s\S]*?Error saving terminal settings") {
    Write-Host "  PASS: try-catch with error message found" -ForegroundColor Green
} else {
    Write-Host "  FAIL: try-catch error handling incomplete" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 4: Verify -ErrorAction Stop on critical operations" -ForegroundColor Yellow
$errorActionCount = ([regex]::Matches($code, "-ErrorAction Stop")).Count
if ($errorActionCount -ge 3) {
    Write-Host "  PASS: Found $errorActionCount -ErrorAction Stop usages" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Only $errorActionCount -ErrorAction Stop usages (need 3+)" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 5: Verify temp file cleanup on error" -ForegroundColor Yellow
if ($code -match "Remove-Item.+tempPath.+-Force") {
    Write-Host "  PASS: Temp file cleanup code found" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Temp file cleanup code NOT found" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 6: Simulate atomic write (dry run)" -ForegroundColor Yellow
$tempPath = "$wtSettingsPath.test-tmp"
try {
    $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
    $settings = $content | ConvertFrom-Json -ErrorAction Stop
    $json = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)

    if (Test-Path $tempPath) {
        Write-Host "  PASS: Temp file created successfully" -ForegroundColor Green
        Remove-Item $tempPath -Force
    } else {
        Write-Host "  FAIL: Temp file was not created" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "  FAIL: Error during dry run: $($_.Exception.Message)" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 7: Verify no unsafe Remove-Item + Rename-Item pattern" -ForegroundColor Yellow
if ($code -match "Remove-Item.+\`$wtSettingsPath" -and $code -match "Rename-Item.+settings\.json") {
    Write-Host "  FAIL: Unsafe delete+rename pattern still present!" -ForegroundColor Red
    $allPassed = $false
} else {
    Write-Host "  PASS: No unsafe delete+rename pattern" -ForegroundColor Green
}

Write-Host ""
if ($allPassed) {
    Write-Host "=== ALL US-001 TESTS PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== SOME US-001 TESTS FAILED ===" -ForegroundColor Red
    exit 1
}
