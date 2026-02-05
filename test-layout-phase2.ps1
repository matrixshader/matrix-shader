# test-layout-phase2.ps1
# Test suite for Get-PillarsLayout function (Phase 2)

# Import the layout engine
. "$PSScriptRoot\WindowLayoutEngine.ps1"

Write-Host "`n=== PHASE 2: GET-PILLARSLAYOUT TEST SUITE ===`n" -ForegroundColor Cyan

# Helper function to validate rectangles
function Test-LayoutRectangles {
    param(
        [array]$Rectangles,
        [array]$Screens,
        [int]$ExpectedCount,
        [int]$GapSize,
        [string]$TestName
    )

    $passed = $true
    $errors = @()

    # Test 1: Count matches
    if ($Rectangles.Count -ne $ExpectedCount) {
        $errors += "Expected $ExpectedCount rectangles, got $($Rectangles.Count)"
        $passed = $false
    }

    # Test 2: No overlaps
    for ($i = 0; $i -lt $Rectangles.Count; $i++) {
        for ($j = $i + 1; $j -lt $Rectangles.Count; $j++) {
            $r1 = $Rectangles[$i]
            $r2 = $Rectangles[$j]

            # Check if rectangles overlap (only if on same screen)
            if ($r1.ScreenIndex -eq $r2.ScreenIndex) {
                $overlapX = ($r1.X -lt ($r2.X + $r2.Width)) -and (($r1.X + $r1.Width) -gt $r2.X)
                $overlapY = ($r1.Y -lt ($r2.Y + $r2.Height)) -and (($r1.Y + $r1.Height) -gt $r2.Y)

                if ($overlapX -and $overlapY) {
                    $errors += "Windows $i and $j overlap"
                    $passed = $false
                }
            }
        }
    }

    # Test 3: Windows fit within screen bounds
    foreach ($rect in $Rectangles) {
        $screen = $Screens[$rect.ScreenIndex]

        if ($rect.X -lt $screen.Left) {
            $errors += "Window $($rect.WindowIndex) X position $($rect.X) is left of screen left $($screen.Left)"
            $passed = $false
        }

        if ($rect.Y -lt $screen.Top) {
            $errors += "Window $($rect.WindowIndex) Y position $($rect.Y) is above screen top $($screen.Top)"
            $passed = $false
        }

        if (($rect.X + $rect.Width) -gt ($screen.Left + $screen.Width)) {
            $errors += "Window $($rect.WindowIndex) exceeds screen right boundary"
            $passed = $false
        }

        if (($rect.Y + $rect.Height) -gt ($screen.Top + $screen.Height)) {
            $errors += "Window $($rect.WindowIndex) exceeds screen bottom boundary"
            $passed = $false
        }
    }

    # Test 4: Verify gap sizes (edge gaps)
    foreach ($rect in $Rectangles) {
        $screen = $Screens[$rect.ScreenIndex]

        # Left edge gap (for leftmost windows)
        $leftGap = $rect.X - $screen.Left
        if ($leftGap -ge 0 -and $leftGap -lt ($GapSize - 5)) {  # Allow 5px tolerance for rounding
            # This is a leftmost window, should have proper gap
            if ($leftGap -lt ($GapSize - 5)) {
                $errors += "Window $($rect.WindowIndex) left gap $leftGap is less than expected $GapSize (minus tolerance)"
                $passed = $false
            }
        }

        # Top edge gap (for topmost windows)
        $topGap = $rect.Y - $screen.Top
        if ($topGap -ge 0 -and $topGap -lt ($GapSize - 5)) {
            if ($topGap -lt ($GapSize - 5)) {
                $errors += "Window $($rect.WindowIndex) top gap $topGap is less than expected $GapSize (minus tolerance)"
                $passed = $false
            }
        }
    }

    # Test 5: Window indices are sequential
    $indices = $Rectangles | ForEach-Object { $_.WindowIndex } | Sort-Object
    for ($i = 0; $i -lt $indices.Count; $i++) {
        if ($indices[$i] -ne $i) {
            $errors += "Window indices are not sequential: expected $i, got $($indices[$i])"
            $passed = $false
            break
        }
    }

    # Output results
    if ($passed) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  - $error" -ForegroundColor Yellow
        }
        return $false
    }
}

# Mock screen data for testing
$singleScreen1080p = @(
    @{
        Index = 0
        Left = 0
        Top = 0
        Width = 1920
        Height = 1040  # Accounting for taskbar
        IsPrimary = $true
    }
)

$dualScreens1080p = @(
    @{
        Index = 0
        Left = 0
        Top = 0
        Width = 1920
        Height = 1040
        IsPrimary = $true
    },
    @{
        Index = 1
        Left = 1920
        Top = 0
        Width = 1920
        Height = 1080  # Second screen has full height
        IsPrimary = $false
    }
)

# Track test results
$testResults = @()
$gapSize = 60

Write-Host "Test 1: 4 windows on 1 screen -> 4 vertical columns" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 4 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 4 -GapSize $gapSize -TestName "4 windows, 1 screen"

Write-Host "`nTest 2: 2 windows on 1 screen -> 2 centered columns" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 2 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 2 -GapSize $gapSize -TestName "2 windows, 1 screen"

# Verify that 2 windows use full height
if ($result.Count -eq 2) {
    $expectedHeight = [int](($singleScreen1080p[0].Height - (2 * $gapSize)) / 1)  # 1 row
    $actualHeight = $result[0].Height
    if ([Math]::Abs($actualHeight - $expectedHeight) -le 1) {
        Write-Host "  [INFO] Windows use full height: $actualHeight px" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] Expected height $expectedHeight, got $actualHeight" -ForegroundColor Yellow
    }
}

Write-Host "`nTest 3: 8 windows on 2 screens -> 4 per screen" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 8 -Screens $dualScreens1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $dualScreens1080p -ExpectedCount 8 -GapSize $gapSize -TestName "8 windows, 2 screens"

# Verify distribution
$screen0Count = ($result | Where-Object { $_.ScreenIndex -eq 0 }).Count
$screen1Count = ($result | Where-Object { $_.ScreenIndex -eq 1 }).Count
Write-Host "  [INFO] Screen 0: $screen0Count windows, Screen 1: $screen1Count windows" -ForegroundColor Gray

Write-Host "`nTest 4: 1 window on 1 screen -> 1 full-screen window" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 1 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 1 -GapSize $gapSize -TestName "1 window, 1 screen"

Write-Host "`nTest 5: 3 windows on 1 screen -> 3 columns" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 3 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 3 -GapSize $gapSize -TestName "3 windows, 1 screen"

Write-Host "`nTest 6: 5 windows on 1 screen -> multi-row (4 columns, 2 rows)" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 5 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 5 -GapSize $gapSize -TestName "5 windows, 1 screen (multi-row)"

# Verify row layout
$row0Count = ($result | Where-Object { $_.Y -eq ($singleScreen1080p[0].Top + $gapSize) }).Count
$row1Windows = $result | Where-Object { $_.Y -ne ($singleScreen1080p[0].Top + $gapSize) }
if ($row1Windows.Count -gt 0) {
    Write-Host "  [INFO] Row 0: $row0Count windows, Row 1: $($row1Windows.Count) windows" -ForegroundColor Gray
}

Write-Host "`nTest 7: 6 windows on 2 screens -> 3 per screen" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 6 -Screens $dualScreens1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $dualScreens1080p -ExpectedCount 6 -GapSize $gapSize -TestName "6 windows, 2 screens"

$screen0Count = ($result | Where-Object { $_.ScreenIndex -eq 0 }).Count
$screen1Count = ($result | Where-Object { $_.ScreenIndex -eq 1 }).Count
Write-Host "  [INFO] Screen 0: $screen0Count windows, Screen 1: $screen1Count windows" -ForegroundColor Gray

Write-Host "`nTest 8: 0 windows -> empty array" -ForegroundColor White
$result = Get-PillarsLayout -WindowCount 0 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $gapSize
if ($result.Count -eq 0) {
    Write-Host "[PASS] 0 windows returns empty array" -ForegroundColor Green
    $testResults += $true
} else {
    Write-Host "[FAIL] Expected empty array, got $($result.Count) rectangles" -ForegroundColor Red
    $testResults += $false
}

Write-Host "`nTest 9: Gap size validation (30px gaps)" -ForegroundColor White
$smallGap = 30
$result = Get-PillarsLayout -WindowCount 4 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $smallGap
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 4 -GapSize $smallGap -TestName "4 windows, 30px gaps"

Write-Host "`nTest 10: Large gap size (100px gaps)" -ForegroundColor White
$largeGap = 100
$result = Get-PillarsLayout -WindowCount 2 -Screens $singleScreen1080p -MaxPillarsPerScreen 4 -GapSize $largeGap
$testResults += Test-LayoutRectangles -Rectangles $result -Screens $singleScreen1080p -ExpectedCount 2 -GapSize $largeGap -TestName "2 windows, 100px gaps"

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
$passCount = ($testResults | Where-Object { $_ -eq $true }).Count
$totalCount = $testResults.Count
$failCount = $totalCount - $passCount

Write-Host "RESULTS: $passCount/$totalCount tests passed" -ForegroundColor White

if ($failCount -eq 0) {
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failCount tests FAILED" -ForegroundColor Red
    exit 1
}
