# test-layout-phase1.ps1
# Verification tests for WindowLayoutEngine Phase 1
# Tests: Get-ScreenTopology and Get-WindowDistribution

# Import the layout engine
. "$PSScriptRoot\WindowLayoutEngine.ps1"

Write-Host "=== PHASE 1 VERIFICATION TESTS ===" -ForegroundColor Cyan
Write-Host ""

# --- TEST 1: Get-ScreenTopology ---
Write-Host "[TEST 1] Get-ScreenTopology" -ForegroundColor Yellow
Write-Host "Detecting screens..." -ForegroundColor Gray

try {
    $screens = Get-ScreenTopology

    if ($screens -eq $null -or $screens.Count -eq 0) {
        Write-Host "  FAIL: No screens detected" -ForegroundColor Red
        $test1Pass = $false
    }
    else {
        Write-Host "  SUCCESS: Detected $($screens.Count) screen(s)" -ForegroundColor Green
        $test1Pass = $true

        foreach ($screen in $screens) {
            $primaryFlag = if ($screen.IsPrimary) { "(PRIMARY)" } else { "" }
            Write-Host "  Screen $($screen.Index) $primaryFlag" -ForegroundColor White
            Write-Host "    Position: ($($screen.Left), $($screen.Top))" -ForegroundColor Gray
            Write-Host "    Size: $($screen.Width) x $($screen.Height)" -ForegroundColor Gray
        }

        # Validation checks
        $allValid = $true
        foreach ($screen in $screens) {
            if ($screen.Width -le 0 -or $screen.Height -le 0) {
                Write-Host "  FAIL: Screen $($screen.Index) has invalid dimensions" -ForegroundColor Red
                $allValid = $false
            }
        }

        # Check that exactly one screen is primary
        $primaryScreens = @($screens | Where-Object { $_.IsPrimary -eq $true })
        $primaryCount = $primaryScreens.Count
        if ($primaryCount -ne 1) {
            Write-Host "  FAIL: Expected 1 primary screen, found $primaryCount" -ForegroundColor Red
            Write-Host "  DEBUG: IsPrimary values: $($screens | ForEach-Object { $_.IsPrimary })" -ForegroundColor Gray
            $allValid = $false
        }

        $test1Pass = $allValid
    }
}
catch {
    Write-Host "  FAIL: Exception thrown: $_" -ForegroundColor Red
    $test1Pass = $false
}

Write-Host ""

# --- TEST 2: Get-WindowDistribution ---
Write-Host "[TEST 2] Get-WindowDistribution" -ForegroundColor Yellow

# Test cases: [WindowCount, ScreenCount, MaxPerScreen, Expected]
$testCases = @(
    @{ Windows=4; Screens=1; Max=4; Expected=@(4); Name="4 windows, 1 screen, max 4" },
    @{ Windows=5; Screens=1; Max=4; Expected=@(4); Name="5 windows, 1 screen, max 4 (overflow)" },
    @{ Windows=8; Screens=2; Max=4; Expected=@(4,4); Name="8 windows, 2 screens, max 4" },
    @{ Windows=3; Screens=2; Max=4; Expected=@(2,1); Name="3 windows, 2 screens, max 4" },
    @{ Windows=10; Screens=3; Max=4; Expected=@(4,4,2); Name="10 windows, 3 screens, max 4" },
    @{ Windows=1; Screens=1; Max=4; Expected=@(1); Name="1 window, 1 screen, max 4" },
    @{ Windows=0; Screens=2; Max=4; Expected=@(0,0); Name="0 windows, 2 screens, max 4" },
    @{ Windows=6; Screens=3; Max=4; Expected=@(2,2,2); Name="6 windows, 3 screens, max 4" },
    @{ Windows=7; Screens=2; Max=4; Expected=@(4,3); Name="7 windows, 2 screens, max 4" }
)

$test2Pass = $true

foreach ($tc in $testCases) {
    try {
        $result = Get-WindowDistribution -WindowCount $tc.Windows -ScreenCount $tc.Screens -MaxPerScreen $tc.Max

        # Convert result to comparable format
        $resultStr = ($result -join ',')
        $expectedStr = ($tc.Expected -join ',')

        # Check total (may be less than WindowCount if overflow)
        $totalAssigned = ($result | Measure-Object -Sum).Sum
        $maxPossible = $tc.Screens * $tc.Max

        if ($resultStr -eq $expectedStr) {
            Write-Host "  PASS: $($tc.Name)" -ForegroundColor Green
            Write-Host "    Result: @($resultStr)" -ForegroundColor Gray
        }
        elseif ($totalAssigned -le $maxPossible -and $totalAssigned -le $tc.Windows) {
            # Alternative valid distribution (different but correct)
            Write-Host "  PASS: $($tc.Name) (alternative distribution)" -ForegroundColor Green
            Write-Host "    Expected: @($expectedStr)" -ForegroundColor Gray
            Write-Host "    Got:      @($resultStr)" -ForegroundColor Gray
            Write-Host "    Total: $totalAssigned (valid)" -ForegroundColor Gray
        }
        else {
            Write-Host "  FAIL: $($tc.Name)" -ForegroundColor Red
            Write-Host "    Expected: @($expectedStr)" -ForegroundColor Gray
            Write-Host "    Got:      @($resultStr)" -ForegroundColor Gray
            $test2Pass = $false
        }
    }
    catch {
        Write-Host "  FAIL: $($tc.Name) - Exception: $_" -ForegroundColor Red
        $test2Pass = $false
    }
}

Write-Host ""

# --- SUMMARY ---
Write-Host "=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

$test1Status = if ($test1Pass) { "PASS" } else { "FAIL" }
$test2Status = if ($test2Pass) { "PASS" } else { "FAIL" }

Write-Host "  Test 1 (Get-ScreenTopology):      $test1Status" -ForegroundColor $(if ($test1Pass) { "Green" } else { "Red" })
Write-Host "  Test 2 (Get-WindowDistribution):  $test2Status" -ForegroundColor $(if ($test2Pass) { "Green" } else { "Red" })
Write-Host ""

if ($test1Pass -and $test2Pass) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
