# US-002 Test: JSON Error Handling
Write-Host "=== US-002 Test: JSON Error Handling ===" -ForegroundColor Cyan
Write-Host ""

$scriptPath = "$PSScriptRoot\matrix_control.ps1"
$code = Get-Content $scriptPath -Raw
$allPassed = $true

Write-Host "Test 1: Load-TerminalEffects has try-catch" -ForegroundColor Yellow
if ($code -match "function Load-TerminalEffects[\s\S]*?try\s*\{[\s\S]*?ConvertFrom-Json[\s\S]*?catch") {
    Write-Host "  PASS: try-catch wraps JSON parsing" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Load-TerminalEffects missing try-catch" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 2: Load-TerminalEffects handles locked file" -ForegroundColor Yellow
if ($code -match "Load-TerminalEffects[\s\S]*?catch.*IOException[\s\S]*?file locked") {
    Write-Host "  PASS: IOException handler with 'file locked' message" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Missing IOException handler" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 3: Load-TerminalEffects handles malformed JSON" -ForegroundColor Yellow
if ($code -match "Load-TerminalEffects[\s\S]*?catch.*ArgumentException[\s\S]*?malformed") {
    Write-Host "  PASS: ArgumentException handler with 'malformed' message" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Missing malformed JSON handler" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 4: Load-TerminalEffects sets defaults before try (degraded mode)" -ForegroundColor Yellow
if ($code -match "function Load-TerminalEffects[\s\S]*?transparency = \`$false[\s\S]*?opacity = 100[\s\S]*?try\s*\{") {
    Write-Host "  PASS: Defaults set before try block" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Defaults not set before try block" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 5: Load-Shader has try-catch" -ForegroundColor Yellow
if ($code -match "function Load-Shader[\s\S]*?try\s*\{[\s\S]*?Get-Content[\s\S]*?catch") {
    Write-Host "  PASS: Load-Shader has error handling" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Load-Shader missing try-catch" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 6: Save-Shader has try-catch" -ForegroundColor Yellow
if ($code -match "function Save-Shader[\s\S]*?try\s*\{[\s\S]*?WriteAllText[\s\S]*?catch") {
    Write-Host "  PASS: Save-Shader has error handling" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Save-Shader missing try-catch" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 7: Save-TerminalEffects has try-catch (from US-001)" -ForegroundColor Yellow
if ($code -match "function Save-TerminalEffects[\s\S]*?try\s*\{[\s\S]*?ConvertFrom-Json[\s\S]*?catch") {
    Write-Host "  PASS: Save-TerminalEffects has error handling" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Save-TerminalEffects missing try-catch" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "Test 8: -ErrorAction Stop on all critical file operations" -ForegroundColor Yellow
$errorActionCount = ([regex]::Matches($code, "-ErrorAction Stop")).Count
if ($errorActionCount -ge 4) {
    Write-Host "  PASS: Found $errorActionCount -ErrorAction Stop usages" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Only $errorActionCount -ErrorAction Stop usages (need 4+)" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
if ($allPassed) {
    Write-Host "=== ALL US-002 TESTS PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== SOME US-002 TESTS FAILED ===" -ForegroundColor Red
    exit 1
}
