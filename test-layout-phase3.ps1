# test-layout-phase3.ps1
# Comprehensive test suite for Get-QuadsLayout function
# Tests Phase 3 of Window Layout Architecture

# Import the layout engine
. "$PSScriptRoot\WindowLayoutEngine.ps1"

# --- TEST UTILITIES ---

function Test-Result {
    param(
        [string]$TestName,
        [bool]$Pass,
        [string]$Message = ""
    )

    $status = if ($Pass) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Pass) { "Green" } else { "Red" }

    Write-Host "$status $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
}

function Assert-Equal {
    param(
        [string]$TestName,
        $Expected,
        $Actual,
        [string]$Message = ""
    )

    $pass = $Expected -eq $Actual
    $msg = if ($Message) { $Message } else { "Expected: $Expected, Actual: $Actual" }
    Test-Result -TestName $TestName -Pass $pass -Message $msg
    return $pass
}

function Assert-InRange {
    param(
        [string]$TestName,
        [int]$Value,
        [int]$Min,
        [int]$Max,
        [string]$Message = ""
    )

    $pass = ($Value -ge $Min) -and ($Value -le $Max)
    $msg = if ($Message) { $Message } else { "Value $Value should be in range [$Min, $Max]" }
    Test-Result -TestName $TestName -Pass $pass -Message $msg
    return $pass
}

function Assert-NoOverlap {
    param(
        [string]$TestName,
        [array]$Rectangles
    )

    # Check all pairs of rectangles for overlap
    $overlaps = @()
    for ($i = 0; $i -lt $Rectangles.Count; $i++) {
        for ($j = $i + 1; $j -lt $Rectangles.Count; $j++) {
            $r1 = $Rectangles[$i]
            $r2 = $Rectangles[$j]

            # Rectangles overlap if:
            # - r1.Left < r2.Right AND r1.Right > r2.Left (horizontal overlap)
            # - r1.Top < r2.Bottom AND r1.Bottom > r2.Top (vertical overlap)
            $r1Right = $r1.X + $r1.Width
            $r1Bottom = $r1.Y + $r1.Height
            $r2Right = $r2.X + $r2.Width
            $r2Bottom = $r2.Y + $r2.Height

            $horizOverlap = ($r1.X -lt $r2Right) -and ($r1Right -gt $r2.X)
            $vertOverlap = ($r1.Y -lt $r2Bottom) -and ($r1Bottom -gt $r2.Y)

            if ($horizOverlap -and $vertOverlap) {
                $overlaps += "Window $($r1.WindowIndex) overlaps Window $($r2.WindowIndex)"
            }
        }
    }

    $pass = $overlaps.Count -eq 0
    $msg = if ($pass) { "No overlaps detected" } else { $overlaps -join "; " }
    Test-Result -TestName $TestName -Pass $pass -Message $msg
    return $pass
}

function Assert-WithinBounds {
    param(
        [string]$TestName,
        [array]$Rectangles,
        [hashtable]$Screen
    )

    $outOfBounds = @()
    foreach ($rect in $Rectangles) {
        $right = $rect.X + $rect.Width
        $bottom = $rect.Y + $rect.Height
        $screenRight = $Screen.Left + $Screen.Width
        $screenBottom = $Screen.Top + $Screen.Height

        if ($rect.X -lt $Screen.Left) {
            $outOfBounds += "Window $($rect.WindowIndex) X ($($rect.X)) < screen left ($($Screen.Left))"
        }
        if ($rect.Y -lt $Screen.Top) {
            $outOfBounds += "Window $($rect.WindowIndex) Y ($($rect.Y)) < screen top ($($Screen.Top))"
        }
        if ($right -gt $screenRight) {
            $outOfBounds += "Window $($rect.WindowIndex) right ($right) > screen right ($screenRight)"
        }
        if ($bottom -gt $screenBottom) {
            $outOfBounds += "Window $($rect.WindowIndex) bottom ($bottom) > screen bottom ($screenBottom)"
        }
    }

    $pass = $outOfBounds.Count -eq 0
    $msg = if ($pass) { "All windows within screen bounds" } else { $outOfBounds -join "; " }
    Test-Result -TestName $TestName -Pass $pass -Message $msg
    return $pass
}

function Assert-PlusGapVisible {
    param(
        [string]$TestName,
        [array]$Rectangles,
        [hashtable]$Screen,
        [int]$GapSize
    )

    if ($Rectangles.Count -lt 2) {
        Test-Result -TestName $TestName -Pass $true -Message "Not enough windows to verify plus-gap"
        return $true
    }

    # For a plus-gap to be visible:
    # 1. Horizontal gap: space between TL/BL and TR/BR
    # 2. Vertical gap: space between TL/TR and BL/BR

    # Find TL and TR windows (first two)
    $tl = $Rectangles[0]
    $tr = if ($Rectangles.Count -ge 2) { $Rectangles[1] } else { $null }

    $issues = @()

    if ($tr) {
        # Check horizontal gap between TL and TR
        $tlRight = $tl.X + $tl.Width
        $horizGap = $tr.X - $tlRight

        if ($horizGap -lt $GapSize) {
            $issues += "Horizontal gap ($horizGap px) < expected ($GapSize px)"
        }
    }

    # Check vertical gap if we have bottom row
    if ($Rectangles.Count -ge 3) {
        $bl = $Rectangles[2]
        $tlBottom = $tl.Y + $tl.Height
        $vertGap = $bl.Y - $tlBottom

        if ($vertGap -lt $GapSize) {
            $issues += "Vertical gap ($vertGap px) < expected ($GapSize px)"
        }
    }

    $pass = $issues.Count -eq 0
    $msg = if ($pass) { "Plus-gap visible (>= $GapSize px)" } else { $issues -join "; " }
    Test-Result -TestName $TestName -Pass $pass -Message $msg
    return $pass
}

# --- TEST SETUP ---

Write-Host "`n=== PHASE 3: Get-QuadsLayout Test Suite ===`n" -ForegroundColor Cyan

# Create mock screen (1920x1080 - typical 1080p working area minus taskbar)
$mockScreen = @{
    Index = 0
    Left = 0
    Top = 0
    Width = 1920
    Height = 1040  # 1080 - 40px taskbar
    IsPrimary = $true
}

$testResults = @{
    Passed = 0
    Failed = 0
}

# --- TEST 1: 4 Windows on 1 Screen → 2x2 Grid ---

Write-Host "TEST 1: 4 Windows → Full 2x2 Grid with Plus-Gap" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 4 -Screens @($mockScreen) -GapSize 60

# Expected behavior:
# - 4 rectangles returned
# - All same size (half-width x half-height)
# - Positioned in TL, TR, BL, BR order
# - Plus-gap visible in center (60px horizontal and vertical)

$test1Pass = $true
$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.1 Rectangle count" -Expected 4 -Actual $layout.Count)
$test1Pass = $test1Pass -and (Assert-NoOverlap -TestName "1.2 No overlaps" -Rectangles $layout)
$test1Pass = $test1Pass -and (Assert-WithinBounds -TestName "1.3 Within screen bounds" -Rectangles $layout -Screen $mockScreen)
$test1Pass = $test1Pass -and (Assert-PlusGapVisible -TestName "1.4 Plus-gap visible" -Rectangles $layout -Screen $mockScreen -GapSize 60)

# Check all windows have same dimensions
$expectedWidth = [int](($mockScreen.Width - (3 * 60)) / 2)  # 840
$expectedHeight = [int](($mockScreen.Height - (3 * 60)) / 2)  # 430

$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.5 Window 0 width" -Expected $expectedWidth -Actual $layout[0].Width)
$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.6 Window 0 height" -Expected $expectedHeight -Actual $layout[0].Height)

# Check position order: TL, TR, BL, BR
$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.7 Window 0 X (TL)" -Expected 60 -Actual $layout[0].X)
$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.8 Window 0 Y (TL)" -Expected 60 -Actual $layout[0].Y)

$expectedTRx = 60 + 60 + $expectedWidth  # gap + gap + halfWidth
$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.9 Window 1 X (TR)" -Expected $expectedTRx -Actual $layout[1].X)
$test1Pass = $test1Pass -and (Assert-Equal -TestName "1.10 Window 1 Y (TR)" -Expected 60 -Actual $layout[1].Y)

if ($test1Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 2: 2 Windows → Top Row Only ---

Write-Host "TEST 2: 2 Windows → Top Row (TL, TR)" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 2 -Screens @($mockScreen) -GapSize 60

$test2Pass = $true
$test2Pass = $test2Pass -and (Assert-Equal -TestName "2.1 Rectangle count" -Expected 2 -Actual $layout.Count)
$test2Pass = $test2Pass -and (Assert-NoOverlap -TestName "2.2 No overlaps" -Rectangles $layout)
$test2Pass = $test2Pass -and (Assert-WithinBounds -TestName "2.3 Within screen bounds" -Rectangles $layout -Screen $mockScreen)

# Both should be in top row (same Y coordinate)
$test2Pass = $test2Pass -and (Assert-Equal -TestName "2.4 Both windows at top" -Expected $layout[0].Y -Actual $layout[1].Y)

# Should have horizontal gap between them
$test2Pass = $test2Pass -and (Assert-PlusGapVisible -TestName "2.5 Horizontal gap visible" -Rectangles $layout -Screen $mockScreen -GapSize 60)

if ($test2Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 3: 3 Windows → Top Row + Bottom-Left ---

Write-Host "TEST 3: 3 Windows → Top Row + Bottom-Left" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 3 -Screens @($mockScreen) -GapSize 60

$test3Pass = $true
$test3Pass = $test3Pass -and (Assert-Equal -TestName "3.1 Rectangle count" -Expected 3 -Actual $layout.Count)
$test3Pass = $test3Pass -and (Assert-NoOverlap -TestName "3.2 No overlaps" -Rectangles $layout)
$test3Pass = $test3Pass -and (Assert-WithinBounds -TestName "3.3 Within screen bounds" -Rectangles $layout -Screen $mockScreen)

# First two in top row
$test3Pass = $test3Pass -and (Assert-Equal -TestName "3.4 Windows 0 and 1 at same Y" -Expected $layout[0].Y -Actual $layout[1].Y)

# Third in bottom row, aligned with first (TL)
$test3Pass = $test3Pass -and (Assert-Equal -TestName "3.5 Window 2 X aligned with Window 0" -Expected $layout[0].X -Actual $layout[2].X)

# Vertical gap between rows
$expectedBLy = 60 + 60 + $expectedHeight  # gap + gap + halfHeight
$test3Pass = $test3Pass -and (Assert-Equal -TestName "3.6 Window 2 Y (BL)" -Expected $expectedBLy -Actual $layout[2].Y)

if ($test3Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 4: 1 Window → Top-Left Only ---

Write-Host "TEST 4: 1 Window → Top-Left Only" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 1 -Screens @($mockScreen) -GapSize 60

$test4Pass = $true
$test4Pass = $test4Pass -and (Assert-Equal -TestName "4.1 Rectangle count" -Expected 1 -Actual $layout.Count)
$test4Pass = $test4Pass -and (Assert-WithinBounds -TestName "4.2 Within screen bounds" -Rectangles $layout -Screen $mockScreen)

# Should be in top-left corner
$test4Pass = $test4Pass -and (Assert-Equal -TestName "4.3 Window 0 X (TL)" -Expected 60 -Actual $layout[0].X)
$test4Pass = $test4Pass -and (Assert-Equal -TestName "4.4 Window 0 Y (TL)" -Expected 60 -Actual $layout[0].Y)

if ($test4Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 5: Different Gap Size ---

Write-Host "TEST 5: 4 Windows with 100px Gap" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 4 -Screens @($mockScreen) -GapSize 100

$test5Pass = $true
$test5Pass = $test5Pass -and (Assert-Equal -TestName "5.1 Rectangle count" -Expected 4 -Actual $layout.Count)
$test5Pass = $test5Pass -and (Assert-PlusGapVisible -TestName "5.2 Plus-gap visible (100px)" -Rectangles $layout -Screen $mockScreen -GapSize 100)

# Recalculate expected dimensions with 100px gap
$expectedWidth100 = [int](($mockScreen.Width - (3 * 100)) / 2)  # 760
$expectedHeight100 = [int](($mockScreen.Height - (3 * 100)) / 2)  # 370

$test5Pass = $test5Pass -and (Assert-Equal -TestName "5.3 Window width with 100px gap" -Expected $expectedWidth100 -Actual $layout[0].Width)

if ($test5Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 6: Multi-Screen Overflow (5+ Windows) ---

Write-Host "TEST 6: 6 Windows → 4 on Screen 0, 2 on Screen 1" -ForegroundColor Yellow

$mockScreen2 = @{
    Index = 1
    Left = 1920
    Top = 0
    Width = 1920
    Height = 1040
    IsPrimary = $false
}

$layout = Get-QuadsLayout -WindowCount 6 -Screens @($mockScreen, $mockScreen2) -GapSize 60

$test6Pass = $true
$test6Pass = $test6Pass -and (Assert-Equal -TestName "6.1 Rectangle count" -Expected 6 -Actual $layout.Count)
$test6Pass = $test6Pass -and (Assert-NoOverlap -TestName "6.2 No overlaps" -Rectangles $layout)

# First 4 windows on screen 0
$screen0Windows = $layout | Where-Object { $_.ScreenIndex -eq 0 }
$screen1Windows = $layout | Where-Object { $_.ScreenIndex -eq 1 }

$test6Pass = $test6Pass -and (Assert-Equal -TestName "6.3 Windows on screen 0" -Expected 4 -Actual $screen0Windows.Count)
$test6Pass = $test6Pass -and (Assert-Equal -TestName "6.4 Windows on screen 1" -Expected 2 -Actual $screen1Windows.Count)

# Check screen 0 windows are within bounds
$test6Pass = $test6Pass -and (Assert-WithinBounds -TestName "6.5 Screen 0 within bounds" -Rectangles $screen0Windows -Screen $mockScreen)

# Check screen 1 windows are within bounds
$test6Pass = $test6Pass -and (Assert-WithinBounds -TestName "6.6 Screen 1 within bounds" -Rectangles $screen1Windows -Screen $mockScreen2)

if ($test6Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 7: Edge Case - 0 Windows ---

Write-Host "TEST 7: Edge Case - 0 Windows" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 0 -Screens @($mockScreen) -GapSize 60

$test7Pass = $true
$test7Pass = $test7Pass -and (Assert-Equal -TestName "7.1 Empty array returned" -Expected 0 -Actual $layout.Count)

if ($test7Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

Write-Host ""

# --- TEST 8: Visual Layout Dump (4 Windows) ---

Write-Host "TEST 8: Visual Layout Verification (4 Windows)" -ForegroundColor Yellow

$layout = Get-QuadsLayout -WindowCount 4 -Screens @($mockScreen) -GapSize 60

Write-Host "`nScreen Dimensions: $($mockScreen.Width) x $($mockScreen.Height)" -ForegroundColor Gray
Write-Host "Gap Size: 60px`n" -ForegroundColor Gray

foreach ($rect in $layout) {
    $label = switch ($rect.WindowIndex) {
        0 { "TL" }
        1 { "TR" }
        2 { "BL" }
        3 { "BR" }
    }

    Write-Host ("Window {0} ({1}): X={2,4} Y={3,4} W={4,4} H={5,4}" -f `
        $rect.WindowIndex, $label, $rect.X, $rect.Y, $rect.Width, $rect.Height) -ForegroundColor Cyan
}

# Manual verification of plus-gap
$horizGap = $layout[1].X - ($layout[0].X + $layout[0].Width)
$vertGap = $layout[2].Y - ($layout[0].Y + $layout[0].Height)

Write-Host "`nCalculated Gaps:" -ForegroundColor Gray
Write-Host ("  Horizontal gap (between TL and TR): {0}px" -f $horizGap) -ForegroundColor Cyan
Write-Host ("  Vertical gap (between TL and BL): {0}px" -f $vertGap) -ForegroundColor Cyan

$test8Pass = ($horizGap -eq 60) -and ($vertGap -eq 60)
Test-Result -TestName "8.1 Plus-gap exactly 60px" -Pass $test8Pass

if ($test8Pass) { $testResults.Passed++ } else { $testResults.Failed++ }

# --- TEST SUMMARY ---

Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host ("Total Tests: {0}" -f ($testResults.Passed + $testResults.Failed))
Write-Host ("Passed: {0}" -f $testResults.Passed) -ForegroundColor Green
Write-Host ("Failed: {0}" -f $testResults.Failed) -ForegroundColor $(if ($testResults.Failed -eq 0) { "Green" } else { "Red" })

$overallPass = $testResults.Failed -eq 0
Write-Host ("`nOVERALL: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) `
    -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })

# Return exit code for automation
if ($overallPass) {
    exit 0
} else {
    exit 1
}
