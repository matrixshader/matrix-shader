# Edge Case Tests for Matrix Terminal Shader
# Tests boundary conditions and error handling

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

Write-Host "`n=== EDGE CASE TESTS ===" -ForegroundColor Cyan
Write-Host ""

# Load utilities
. .\MatrixUtils.ps1

# Test 1: Swatch RGB clamping
Write-Host "[Swatch bounds]" -ForegroundColor Yellow

# Test negative values clamp to 0
$swatch = Swatch -0.5 -0.5 -0.5 2
Test-Result "Negative RGB clamps to 0" ($swatch -match '\[48;2;0;0;0m')

# Test values > 1.0 clamp to 255
$swatch = Swatch 1.5 2.0 999 2
Test-Result "RGB > 1.0 clamps to 255" ($swatch -match '\[48;2;255;255;255m')

# Test exact boundaries (0.5*255=127.5 rounds to 128)
$swatch = Swatch 0.0 0.5 1.0 2
Test-Result "Boundary values 0/0.5/1.0" ($swatch -match '\[48;2;0;128;255m')

# Test width parameter
$swatch = Swatch 1 1 1 5
Test-Result "Width=5 produces 5 spaces" ($swatch -match '     ')  # 5 spaces

# Test 2: Screen dimensions fallback
Write-Host ""
Write-Host "[Screen dimensions]" -ForegroundColor Yellow

$dims = Get-PrimaryScreenDimensions
Test-Result "Width is positive integer" ($dims.Width -is [int] -and $dims.Width -gt 0)
Test-Result "Height is positive integer" ($dims.Height -is [int] -and $dims.Height -gt 0)
Test-Result "Contains Left property" ($null -ne $dims.Left)
Test-Result "Contains Top property" ($null -ne $dims.Top)

# Test 3: MatrixPaths structure
Write-Host ""
Write-Host "[MatrixPaths structure]" -ForegroundColor Yellow

$paths = Get-MatrixPaths
Test-Result "MatrixDir defined" ($paths.MatrixDir -like "*Matrix*")
Test-Result "ShadersDir defined" ($paths.ShadersDir -like "*shaders*")
Test-Result "WTSettings defined" ($paths.WTSettings -like "*settings.json*")
Test-Result "StateFile defined" ($paths.StateFile -like "*state.json*")

# Test 4: Import redundancy check
Write-Host ""
Write-Host "[Import redundancy]" -ForegroundColor Yellow

# Dot-source all imports twice - should not cause errors
try {
    . .\MatrixUtils.ps1
    . .\MatrixUtils.ps1
    . .\MatrixLogging.ps1
    . .\MatrixLogging.ps1
    Test-Result "Double import MatrixUtils" $true
    Test-Result "Double import MatrixLogging" $true
} catch {
    Test-Result "Double imports" $false $_.Exception.Message
}

# Test 5: Atomic write temp file pattern
Write-Host ""
Write-Host "[Atomic write pattern]" -ForegroundColor Yellow

# Check install.ps1 uses atomic write
$install = Get-Content .\install.ps1 -Raw
Test-Result "install.ps1 uses GetTempFileName" ($install -match 'GetTempFileName')
Test-Result "install.ps1 uses Move-Item" ($install -match 'Move-Item.*-Force')

# Check matrix_setup.ps1 uses atomic write
$setup = Get-Content .\matrix_setup.ps1 -Raw
Test-Result "matrix_setup.ps1 uses GetTempFileName" ($setup -match 'GetTempFileName')
Test-Result "matrix_setup.ps1 has temp cleanup in catch" ($setup -match 'Remove-Item.*tempFile')

# Check matrix_hotkeys.ps1 uses atomic write
$hotkeys = Get-Content .\matrix_hotkeys.ps1 -Raw
Test-Result "matrix_hotkeys.ps1 uses atomic write" ($hotkeys -match 'GetTempFileName')
Test-Result "matrix_hotkeys.ps1 cleans temp on error" ($hotkeys -match 'Remove-Item.*tempFile')

# Test 6: No hardcoded shader parameters that don't exist
Write-Host ""
Write-Host "[Shader parameter references]" -ForegroundColor Yellow

$hotkeys = Get-Content .\matrix_hotkeys.ps1 -Raw
Test-Result "No SHOW_TERMINAL_CONTENT" ($hotkeys -notmatch 'SHOW_TERMINAL_CONTENT')
Test-Result "No BASE_OPACITY" ($hotkeys -notmatch 'BASE_OPACITY')
Test-Result "Uses profile opacity property" ($hotkeys -match "opacity.*80|opacity.*100")

# Summary
Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) {
    exit 1
}
