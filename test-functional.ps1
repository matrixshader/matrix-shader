# Functional Tests for Matrix Terminal Shader
# Tests that all entry points load correctly with their imports

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$passed = 0
$failed = 0

function Test-Result($name, $success, $msg = "") {
    if ($success) {
        Write-Host "PASS: $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "FAIL: $name" -ForegroundColor Red
        if ($msg) { Write-Host "      $msg" -ForegroundColor Yellow }
        $script:failed++
    }
}

Write-Host "`n=== FUNCTIONAL TESTS ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: MatrixUtils.ps1 loads and exports
Write-Host "[MatrixUtils.ps1]" -ForegroundColor Yellow
try {
    . .\MatrixUtils.ps1
    Test-Result "Dot-source loads" $true
    Test-Result "Swatch alias exists" (Get-Command Swatch -ErrorAction SilentlyContinue)
    Test-Result "Get-ColorSwatch exists" (Get-Command Get-ColorSwatch -ErrorAction SilentlyContinue)
    Test-Result "Get-PrimaryScreenDimensions exists" (Get-Command Get-PrimaryScreenDimensions -ErrorAction SilentlyContinue)

    $swatch = Swatch 1.0 0.5 0.0 3
    Test-Result "Swatch produces output" ($swatch.Length -gt 10)

    $dims = Get-PrimaryScreenDimensions
    Test-Result "Screen dimensions valid" ($dims.Width -gt 0 -and $dims.Height -gt 0)
} catch {
    Test-Result "MatrixUtils.ps1 loads" $false $_.Exception.Message
}

# Test 2: Import chain for bluepill.ps1
Write-Host ""
Write-Host "[bluepill.ps1 imports]" -ForegroundColor Yellow
try {
    # Simulate bluepill imports
    . .\MatrixUtils.ps1
    . .\WindowLayoutEngine.ps1
    . .\WindowIdentityService.ps1

    Test-Result "All imports load" $true
    Test-Result "Get-AllMatrixWindows exists" (Get-Command Get-AllMatrixWindows -ErrorAction SilentlyContinue)
    Test-Result "Invoke-MatrixWindowLayout exists" (Get-Command Invoke-MatrixWindowLayout -ErrorAction SilentlyContinue)
    Test-Result "Get-ExistingWindowHandles exists" (Get-Command Get-ExistingWindowHandles -ErrorAction SilentlyContinue)
} catch {
    Test-Result "Import chain" $false $_.Exception.Message
}

# Test 3: Import chain for matrix_setup.ps1
Write-Host ""
Write-Host "[matrix_setup.ps1 imports]" -ForegroundColor Yellow
try {
    . .\MatrixLogging.ps1
    . .\MatrixUtils.ps1
    . .\WindowLayoutEngine.ps1
    . .\WindowIdentityService.ps1

    Test-Result "All imports load" $true
    Test-Result "Write-MatrixLog exists" (Get-Command Write-MatrixLog -ErrorAction SilentlyContinue)
} catch {
    Test-Result "Import chain" $false $_.Exception.Message
}

# Test 4: Import chain for matrix_control.ps1
Write-Host ""
Write-Host "[matrix_control.ps1 imports]" -ForegroundColor Yellow
try {
    . .\MatrixLogging.ps1
    . .\MatrixUtils.ps1
    . .\WindowLayoutEngine.ps1
    . .\WindowIdentityService.ps1

    Test-Result "All imports load" $true
} catch {
    Test-Result "Import chain" $false $_.Exception.Message
}

# Test 5: No dead references in main scripts
Write-Host ""
Write-Host "[Dead reference check]" -ForegroundColor Yellow
$mainScripts = @('bluepill.ps1', 'matrix_setup.ps1', 'matrix_control.ps1', 'matrix_hotkeys.ps1', 'install.ps1')
$deadRefs = @('BluepillAPI', 'WindowPositioning', 'SHOW_TERMINAL_CONTENT', 'BASE_OPACITY')

foreach ($ref in $deadRefs) {
    $found = $false
    foreach ($script in $mainScripts) {
        $content = Get-Content $script -Raw
        if ($content -match [regex]::Escape($ref)) {
            $found = $true
            Test-Result "No '$ref' in $script" $false
        }
    }
    if (-not $found) {
        Test-Result "No '$ref' in main scripts" $true
    }
}

# Summary
Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) {
    exit 1
}
