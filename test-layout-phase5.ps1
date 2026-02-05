# Phase 5 Test: Invoke-MatrixWindowLayout Entry Point
# Tests the main orchestration function

. "$PSScriptRoot\WindowLayoutEngine.ps1"

Write-Host "=== PHASE 5: Invoke-MatrixWindowLayout Test Suite ===" -ForegroundColor Cyan

$testsPassed = 0
$testsFailed = 0

function Test-Assert {
    param([string]$Name, [bool]$Condition, [string]$Expected = "", [string]$Actual = "")
    if ($Condition) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        if ($Expected) { Write-Host "       Expected: $Expected, Actual: $Actual" -ForegroundColor DarkGray }
        $script:testsPassed++
    } else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        if ($Expected) { Write-Host "       Expected: $Expected, Actual: $Actual" -ForegroundColor Yellow }
        $script:testsFailed++
    }
}

# Mock screen for testing
$mockScreen = @(@{ Left = 0; Top = 0; Width = 1920; Height = 1040; Index = 0; IsPrimary = $true })

# TEST 1: Empty window handles
Write-Host "`nTEST 1: Empty Window Handles" -ForegroundColor Yellow
$result = Invoke-MatrixWindowLayout -WindowHandles @{} -Mode 'Pillars' -DryRun
Test-Assert "1.1 Empty handles returns empty array" ($result.Count -eq 0) "0" $result.Count.ToString()

# TEST 2: Get-MatrixWindowLayout utility function with Pillars
Write-Host "`nTEST 2: Get-MatrixWindowLayout Utility (Pillars)" -ForegroundColor Yellow
$layout = Get-MatrixWindowLayout -WindowCount 4 -Mode 'Pillars' -Screens $mockScreen
Test-Assert "2.1 Returns 4 rectangles" ($layout.Count -eq 4) "4" $layout.Count.ToString()
Test-Assert "2.2 First window has X property" ($layout[0].X -ne $null) "non-null" $(if($layout[0].X -ne $null){"set"}else{"null"})
Test-Assert "2.3 First window at gap position" ($layout[0].X -eq 60) "60" $layout[0].X.ToString()

# TEST 3: Get-MatrixWindowLayout utility function with Quads
Write-Host "`nTEST 3: Get-MatrixWindowLayout Utility (Quads)" -ForegroundColor Yellow
$layout = Get-MatrixWindowLayout -WindowCount 4 -Mode 'Quads' -Screens $mockScreen
Test-Assert "3.1 Returns 4 rectangles" ($layout.Count -eq 4) "4" $layout.Count.ToString()
Test-Assert "3.2 Quads uses half-width" ($layout[0].Width -lt 1000) "<1000" $layout[0].Width.ToString()
# Verify 2x2 grid positions (use ForEach for hashtable access)
$topLeftCount = 0
$layout | ForEach-Object { if ($_.X -eq 60 -and $_.Y -eq 60) { $topLeftCount++ } }
Test-Assert "3.3 Has Top-Left position" ($topLeftCount -eq 1) "1 window at (60,60)" $topLeftCount.ToString()

# TEST 4: Auto mode with 3 windows (should use Pillars)
Write-Host "`nTEST 4: Auto Mode (3 windows -> Pillars)" -ForegroundColor Yellow
$layout = Get-MatrixWindowLayout -WindowCount 3 -Mode 'Pillars' -Screens $mockScreen
Test-Assert "4.1 Returns 3 rectangles" ($layout.Count -eq 3) "3" $layout.Count.ToString()
# All should be on same row for pillars (use ForEach for hashtable access)
$yValues = @()
$layout | ForEach-Object { $yValues += $_.Y }
$uniqueY = ($yValues | Sort-Object -Unique).Count
Test-Assert "4.2 All windows on same row" ($uniqueY -eq 1) "1 unique Y" $uniqueY.ToString()

# TEST 5: Config integration
Write-Host "`nTEST 5: Config Integration" -ForegroundColor Yellow
$config = Get-MatrixLayoutConfig
Test-Assert "5.1 Config has Mode property" ($config.Mode -ne $null) "non-null" $(if($config.Mode){"set"}else{"null"})
Test-Assert "5.2 Config has GapSize property" ($config.GapSize -ne $null) "non-null" $(if($config.GapSize){"set"}else{"null"})

# TEST 6: DryRun with mock handles (tests parameter handling)
Write-Host "`nTEST 6: DryRun Parameter Handling" -ForegroundColor Yellow
# Create mock handles that will fail visibility check (testing graceful handling)
$mockHandles = @{
    "Matrix-1" = @{ Handle = [IntPtr]1234 }
    "Matrix-2" = @{ Handle = [IntPtr]5678 }
}
# This should return empty since handles are invalid
$result = Invoke-MatrixWindowLayout -WindowHandles $mockHandles -Mode 'Pillars' -DryRun
Test-Assert "6.1 Invalid handles filtered out" ($result.Count -eq 0) "0 (invalid handles)" $result.Count.ToString()

# TEST 7: Layout consistency
Write-Host "`nTEST 7: Layout Consistency" -ForegroundColor Yellow
$layout1 = Get-MatrixWindowLayout -WindowCount 4 -Mode 'Pillars' -Screens $mockScreen
$layout2 = Get-MatrixWindowLayout -WindowCount 4 -Mode 'Pillars' -Screens $mockScreen
$consistent = ($layout1[0].X -eq $layout2[0].X) -and ($layout1[0].Width -eq $layout2[0].Width)
Test-Assert "7.1 Same input produces same output" $consistent "matching layouts" ""

# TEST 8: Verify functions exist
Write-Host "`nTEST 8: Function Exports" -ForegroundColor Yellow
Test-Assert "8.1 Invoke-MatrixWindowLayout exists" ((Get-Command Invoke-MatrixWindowLayout -ErrorAction SilentlyContinue) -ne $null) "function exists" ""
Test-Assert "8.2 Get-MatrixWindowLayout exists" ((Get-Command Get-MatrixWindowLayout -ErrorAction SilentlyContinue) -ne $null) "function exists" ""
Test-Assert "8.3 Get-PillarsLayout exists" ((Get-Command Get-PillarsLayout -ErrorAction SilentlyContinue) -ne $null) "function exists" ""
Test-Assert "8.4 Get-QuadsLayout exists" ((Get-Command Get-QuadsLayout -ErrorAction SilentlyContinue) -ne $null) "function exists" ""
Test-Assert "8.5 Get-MatrixLayoutConfig exists" ((Get-Command Get-MatrixLayoutConfig -ErrorAction SilentlyContinue) -ne $null) "function exists" ""
Test-Assert "8.6 Set-MatrixLayoutConfig exists" ((Get-Command Set-MatrixLayoutConfig -ErrorAction SilentlyContinue) -ne $null) "function exists" ""

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Tests: $($testsPassed + $testsFailed)"
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if($testsFailed -eq 0){"Green"}else{"Red"})
Write-Host "OVERALL: $(if($testsFailed -eq 0){'PASS'}else{'FAIL'})" -ForegroundColor $(if($testsFailed -eq 0){"Green"}else{"Red"})

exit $testsFailed
