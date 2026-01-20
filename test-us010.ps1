# US-010 Test: Consolidate Key Handlers
# Verifies key normalization and no duplicate cases

Write-Host ""
Write-Host "US-010 TEST: Consolidate Key Handlers" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor DarkGray
Write-Host ""

$scriptPath = "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1"
$content = Get-Content $scriptPath -Raw

$allPassed = $true

# TEST 1: Key normalization exists
Write-Host "TEST 1: Key normalization to lowercase" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor DarkGray

if ($content -match '\$key\s*=.*\.ToLower\(\)') {
    Write-Host "PASS: Key normalization with .ToLower() found" -ForegroundColor Green
    # Show the line
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\$key\s*=.*\.ToLower\(\)') {
            Write-Host "  Line $($i+1): $($lines[$i].Trim())" -ForegroundColor DarkGray
            break
        }
    }
} else {
    Write-Host "FAIL: Key normalization not found" -ForegroundColor Red
    $allPassed = $false
}

# TEST 2: No uppercase letter cases in switch
Write-Host ""
Write-Host "TEST 2: No duplicate uppercase letter cases" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor DarkGray

# Find the switch block
$switchMatch = [regex]::Match($content, 'switch\s*\(\$key\)\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($switchMatch.Success) {
    $switchBlock = $switchMatch.Groups[1].Value

    # Look for uppercase letter cases like 'Q' 'A' 'Z' etc (but not as part of a comment)
    $uppercaseCases = [regex]::Matches($switchBlock, "^\s*'([A-Z])'\s*\{", [System.Text.RegularExpressions.RegexOptions]::Multiline)

    if ($uppercaseCases.Count -eq 0) {
        Write-Host "PASS: No uppercase letter cases found in switch" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Found $($uppercaseCases.Count) uppercase cases:" -ForegroundColor Red
        foreach ($match in $uppercaseCases) {
            Write-Host "  '$($match.Groups[1].Value)'" -ForegroundColor Red
        }
        $allPassed = $false
    }

    # Count lowercase letter cases
    $lowercaseCases = [regex]::Matches($switchBlock, "^\s*'([a-z])'\s*\{", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    Write-Host "  Found $($lowercaseCases.Count) lowercase letter cases" -ForegroundColor DarkGray

} else {
    Write-Host "FAIL: Could not find switch block" -ForegroundColor Red
    $allPassed = $false
}

# TEST 3: Verify specific keys work (code path check)
Write-Host ""
Write-Host "TEST 3: Key handler coverage" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor DarkGray

$expectedKeys = @('q','w','a','s','z','x','e','r','d','f','c','v','t','y','g','h','b','k','l','p')
$missingKeys = @()

foreach ($key in $expectedKeys) {
    if ($content -notmatch "'$key'\s*\{") {
        $missingKeys += $key
    }
}

if ($missingKeys.Count -eq 0) {
    Write-Host "PASS: All expected key handlers present ($($expectedKeys.Count) keys)" -ForegroundColor Green
} else {
    Write-Host "FAIL: Missing handlers for: $($missingKeys -join ', ')" -ForegroundColor Red
    $allPassed = $false
}

# Summary
Write-Host ""
Write-Host "=====================================" -ForegroundColor DarkGray
if ($allPassed) {
    Write-Host "US-010: ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "US-010: SOME TESTS FAILED" -ForegroundColor Red
}
Write-Host ""
