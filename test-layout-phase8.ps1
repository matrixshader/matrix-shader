# test-layout-phase8.ps1
# Phase 8: Edge Case Hardening Test Suite
# Tests: zero windows, 10+ windows, screen disconnect, invalid handles, verbose logging

. "$PSScriptRoot\WindowLayoutEngine.ps1"

Write-Host "=== PHASE 8: Edge Case Hardening Test Suite ===" -ForegroundColor Cyan

$testsPassed = 0
$testsFailed = 0

function Test-Assert {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Expected = "",
        [string]$Actual = ""
    )
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

# Mock screens for testing
$singleScreen = @(@{
    Index = 0
    Left = 0
    Top = 0
    Width = 1920
    Height = 1040
    IsPrimary = $true
})

$dualScreens = @(
    @{ Index = 0; Left = 0; Top = 0; Width = 1920; Height = 1040; IsPrimary = $true },
    @{ Index = 1; Left = 1920; Top = 0; Width = 1920; Height = 1080; IsPrimary = $false }
)

$tripleScreens = @(
    @{ Index = 0; Left = 0; Top = 0; Width = 1920; Height = 1040; IsPrimary = $true },
    @{ Index = 1; Left = 1920; Top = 0; Width = 1920; Height = 1080; IsPrimary = $false },
    @{ Index = 2; Left = 3840; Top = 0; Width = 1920; Height = 1080; IsPrimary = $false }
)

# =============================================================================
# TEST SUITE 1: ZERO WINDOWS HANDLING
# =============================================================================
Write-Host "`n--- TEST SUITE 1: Zero Windows Handling ---" -ForegroundColor Yellow

# Test 1.1: Get-PillarsLayout with 0 windows
$result = Get-PillarsLayout -WindowCount 0 -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
Test-Assert "1.1 Get-PillarsLayout returns empty for 0 windows" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 1.2: Get-QuadsLayout with 0 windows
$result = Get-QuadsLayout -WindowCount 0 -Screens $singleScreen -GapSize 60
Test-Assert "1.2 Get-QuadsLayout returns empty for 0 windows" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 1.3: Get-WindowDistribution with 0 windows
$result = Get-WindowDistribution -WindowCount 0 -ScreenCount 2 -MaxPerScreen 4
Test-Assert "1.3 Get-WindowDistribution returns zeros for 0 windows" (($result | Measure-Object -Sum).Sum -eq 0) "0" ($result | Measure-Object -Sum).Sum.ToString()

# Test 1.4: Invoke-MatrixWindowLayout with empty hashtable
$result = Invoke-MatrixWindowLayout -WindowHandles @{} -Mode 'Pillars' -DryRun
Test-Assert "1.4 Invoke-MatrixWindowLayout handles empty hashtable" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 1.5: Get-MatrixWindowLayout with 0 windows
$result = Get-MatrixWindowLayout -WindowCount 0 -Mode 'Pillars' -Screens $singleScreen
Test-Assert "1.5 Get-MatrixWindowLayout handles 0 windows" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 1.6: Negative window count (should be treated as 0)
$result = Get-PillarsLayout -WindowCount -5 -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
Test-Assert "1.6 Negative window count handled gracefully" ($result.Count -eq 0) "0" $result.Count.ToString()

# =============================================================================
# TEST SUITE 2: 10+ WINDOWS HANDLING (OVERFLOW)
# =============================================================================
Write-Host "`n--- TEST SUITE 2: 10+ Windows Handling ---" -ForegroundColor Yellow

# Test 2.1: 10 windows on single screen (Pillars - should create 3 rows)
$result = Get-PillarsLayout -WindowCount 10 -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
Test-Assert "2.1 Pillars handles 10 windows" ($result.Count -eq 10) "10" $result.Count.ToString()

# Verify multi-row layout (3 rows: 4+4+2)
$uniqueYvalues = ($result | ForEach-Object { $_.Y } | Sort-Object -Unique).Count
Test-Assert "2.2 10 windows creates multiple rows" ($uniqueYvalues -ge 2) ">= 2 rows" $uniqueYvalues.ToString()

# Test 2.3: 12 windows on single screen (Pillars - 3 rows of 4)
$result = Get-PillarsLayout -WindowCount 12 -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
Test-Assert "2.3 Pillars handles 12 windows" ($result.Count -eq 12) "12" $result.Count.ToString()

$uniqueYvalues = ($result | ForEach-Object { $_.Y } | Sort-Object -Unique).Count
Test-Assert "2.4 12 windows creates 3 rows" ($uniqueYvalues -eq 3) "3 rows" $uniqueYvalues.ToString()

# Test 2.5: 16 windows on single screen (Pillars - 4 rows of 4)
$result = Get-PillarsLayout -WindowCount 16 -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
Test-Assert "2.5 Pillars handles 16 windows" ($result.Count -eq 16) "16" $result.Count.ToString()

$uniqueYvalues = ($result | ForEach-Object { $_.Y } | Sort-Object -Unique).Count
Test-Assert "2.6 16 windows creates 4 rows" ($uniqueYvalues -eq 4) "4 rows" $uniqueYvalues.ToString()

# Test 2.7: 10 windows Quads mode on dual screens (uses extended grid for overflow)
$result = Get-QuadsLayout -WindowCount 10 -Screens $dualScreens -GapSize 60
Test-Assert "2.7 Quads handles 10 windows on dual screens" ($result.Count -eq 10) "10" $result.Count.ToString()

$screen0Count = ($result | Where-Object { $_.ScreenIndex -eq 0 }).Count
$screen1Count = ($result | Where-Object { $_.ScreenIndex -eq 1 }).Count
# Extended grid mode distributes evenly (5+5 or similar)
Test-Assert "2.8 Quads distributes windows evenly (extended grid)" (($screen0Count + $screen1Count) -eq 10 -and $screen0Count -ge 4) "balanced distribution" "$screen0Count + $screen1Count"

# Test 2.9: 8 windows Quads on dual screens (4+4)
$result = Get-QuadsLayout -WindowCount 8 -Screens $dualScreens -GapSize 60
$screen0Count = ($result | Where-Object { $_.ScreenIndex -eq 0 }).Count
$screen1Count = ($result | Where-Object { $_.ScreenIndex -eq 1 }).Count
Test-Assert "2.9 8 windows on dual screens distributed 4+4" ($screen0Count -eq 4 -and $screen1Count -eq 4) "4+4" "$screen0Count+$screen1Count"

# Test 2.10: Verify windows don't overlap within screen
$result = Get-PillarsLayout -WindowCount 12 -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
$overlaps = 0
for ($i = 0; $i -lt $result.Count; $i++) {
    for ($j = $i + 1; $j -lt $result.Count; $j++) {
        $r1 = $result[$i]
        $r2 = $result[$j]
        $r1Right = $r1.X + $r1.Width
        $r1Bottom = $r1.Y + $r1.Height
        $r2Right = $r2.X + $r2.Width
        $r2Bottom = $r2.Y + $r2.Height

        $horizOverlap = ($r1.X -lt $r2Right) -and ($r1Right -gt $r2.X)
        $vertOverlap = ($r1.Y -lt $r2Bottom) -and ($r1Bottom -gt $r2.Y)

        if ($horizOverlap -and $vertOverlap) { $overlaps++ }
    }
}
Test-Assert "2.10 12 windows have no overlaps" ($overlaps -eq 0) "0 overlaps" $overlaps.ToString()

# Test 2.11: Verify all windows fit within screen bounds
$outOfBounds = 0
foreach ($rect in $result) {
    $screenRight = $singleScreen[0].Left + $singleScreen[0].Width
    $screenBottom = $singleScreen[0].Top + $singleScreen[0].Height
    $rectRight = $rect.X + $rect.Width
    $rectBottom = $rect.Y + $rect.Height

    if ($rect.X -lt $singleScreen[0].Left -or $rect.Y -lt $singleScreen[0].Top -or $rectRight -gt $screenRight -or $rectBottom -gt $screenBottom) {
        $outOfBounds++
    }
}
Test-Assert "2.11 All 12 windows within bounds" ($outOfBounds -eq 0) "0 out of bounds" $outOfBounds.ToString()

# =============================================================================
# TEST SUITE 3: SCREEN DISCONNECT HANDLING
# =============================================================================
Write-Host "`n--- TEST SUITE 3: Screen Disconnect Handling ---" -ForegroundColor Yellow

# Test 3.1: Empty screen array (simulates all screens disconnected)
$emptyScreens = @()
$result = Get-PillarsLayout -WindowCount 4 -Screens $emptyScreens -MaxPillarsPerScreen 4 -GapSize 60
Test-Assert "3.1 Get-PillarsLayout handles empty screens array" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 3.2: Get-QuadsLayout with empty screens
$result = Get-QuadsLayout -WindowCount 4 -Screens $emptyScreens -GapSize 60
Test-Assert "3.2 Get-QuadsLayout handles empty screens array" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 3.3: Get-WindowDistribution with 0 screens
$result = Get-WindowDistribution -WindowCount 4 -ScreenCount 0 -MaxPerScreen 4
Test-Assert "3.3 Get-WindowDistribution handles 0 screens" ($result.Count -eq 0) "empty" $result.Count.ToString()

# Test 3.4: Layout request exceeds available screens (8 windows, 1 screen for Quads)
# Extended grid mode now handles overflow by using larger grid on single screen
$result = Get-QuadsLayout -WindowCount 8 -Screens $singleScreen -GapSize 60
Test-Assert "3.4 Quads handles overflow with extended grid" ($result.Count -eq 8) "8 (extended grid)" $result.Count.ToString()

# Test 3.5: Get-ScreenTopology fallback test (we can't easily test this without mocking)
# Instead, verify it returns at least one screen on a real system
$realScreens = Get-ScreenTopology
Test-Assert "3.5 Get-ScreenTopology returns at least 1 screen" ($realScreens.Count -ge 1) ">= 1" $realScreens.Count.ToString()

# Test 3.6: Screens with unusual dimensions
$tinyScreen = @(@{
    Index = 0
    Left = 0
    Top = 0
    Width = 320
    Height = 240
    IsPrimary = $true
})
$result = Get-PillarsLayout -WindowCount 4 -Screens $tinyScreen -MaxPillarsPerScreen 4 -GapSize 60
# Even with tiny screen, should not crash
Test-Assert "3.6 Handles tiny screen dimensions" ($result.Count -eq 4) "4" $result.Count.ToString()

# =============================================================================
# TEST SUITE 4: INVALID WINDOW HANDLE HANDLING
# =============================================================================
Write-Host "`n--- TEST SUITE 4: Invalid Window Handle Handling ---" -ForegroundColor Yellow

# Test 4.1: Zero handle (IntPtr.Zero)
$invalidHandles = @{
    "Matrix-1" = @{ Handle = [IntPtr]::Zero }
}
$result = Invoke-MatrixWindowLayout -WindowHandles $invalidHandles -Mode 'Pillars' -DryRun
Test-Assert "4.1 IntPtr.Zero filtered out" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 4.2: Random invalid handle
$invalidHandles = @{
    "Matrix-1" = @{ Handle = [IntPtr]1234 }
    "Matrix-2" = @{ Handle = [IntPtr]5678 }
}
$result = Invoke-MatrixWindowLayout -WindowHandles $invalidHandles -Mode 'Pillars' -DryRun
Test-Assert "4.2 Random invalid handles filtered out" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 4.3: Negative handle values
$invalidHandles = @{
    "Matrix-1" = @{ Handle = [IntPtr](-1) }
}
$result = Invoke-MatrixWindowLayout -WindowHandles $invalidHandles -Mode 'Pillars' -DryRun
Test-Assert "4.3 Negative handle filtered out" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 4.4: Mix of valid handle format but with invalid values
$invalidHandles = @{
    "Matrix-1" = @{ Handle = [IntPtr]9999999999; ProcessId = 0 }
}
$result = Invoke-MatrixWindowLayout -WindowHandles $invalidHandles -Mode 'Pillars' -DryRun
Test-Assert "4.4 Invalid handle with ProcessId filtered out" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 4.5: Handle as direct value (not hashtable)
$invalidHandles = @{
    "Matrix-1" = [IntPtr]1234
}
$result = Invoke-MatrixWindowLayout -WindowHandles $invalidHandles -Mode 'Pillars' -DryRun
Test-Assert "4.5 Direct invalid handle filtered out" ($result.Count -eq 0) "0" $result.Count.ToString()

# Test 4.6: Null entry
$invalidHandles = @{
    "Matrix-1" = $null
}
$result = Invoke-MatrixWindowLayout -WindowHandles $invalidHandles -Mode 'Pillars' -DryRun
Test-Assert "4.6 Null entry filtered out" ($result.Count -eq 0) "0" $result.Count.ToString()

# =============================================================================
# TEST SUITE 5: VERBOSE LOGGING
# =============================================================================
Write-Host "`n--- TEST SUITE 5: Verbose Logging ---" -ForegroundColor Yellow

# Test 5.1: Write-LayoutLog function exists
$logFuncExists = Get-Command Write-LayoutLog -ErrorAction SilentlyContinue
Test-Assert "5.1 Write-LayoutLog function exists" ($logFuncExists -ne $null) "exists" $(if($logFuncExists){"exists"}else{"not found"})

# Test 5.2: Logging can be enabled/disabled
$script:LayoutEngineVerbose = $true
# Test that verbose mode is honored (function should exist and accept messages)
if ($logFuncExists) {
    try {
        Write-LayoutLog "Test message from Phase 8 tests" -Level "INFO"
        Test-Assert "5.2 Write-LayoutLog accepts messages" $true "success" "success"
    } catch {
        Test-Assert "5.2 Write-LayoutLog accepts messages" $false "success" $_.Exception.Message
    }
} else {
    Test-Assert "5.2 Write-LayoutLog accepts messages" $false "function exists" "function not found"
}

$script:LayoutEngineVerbose = $false

# =============================================================================
# TEST SUITE 6: COMPREHENSIVE WINDOW COUNT MATRIX
# =============================================================================
Write-Host "`n--- TEST SUITE 6: Window Count Matrix ---" -ForegroundColor Yellow

# Test various window counts systematically
$windowCounts = @(1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 16)

foreach ($count in $windowCounts) {
    # Test Pillars on single screen
    $result = Get-PillarsLayout -WindowCount $count -Screens $singleScreen -MaxPillarsPerScreen 4 -GapSize 60
    Test-Assert "6.P-$count Pillars layout for $count windows" ($result.Count -eq $count) $count.ToString() $result.Count.ToString()
}

# Quads has limited capacity per screen (4 per quad per screen)
$quadsCounts = @(1, 2, 3, 4)
foreach ($count in $quadsCounts) {
    $result = Get-QuadsLayout -WindowCount $count -Screens $singleScreen -GapSize 60
    Test-Assert "6.Q-$count Quads layout for $count windows (single screen)" ($result.Count -eq $count) $count.ToString() $result.Count.ToString()
}

# Quads with dual screens
$quadsDualCounts = @(5, 6, 7, 8)
foreach ($count in $quadsDualCounts) {
    $result = Get-QuadsLayout -WindowCount $count -Screens $dualScreens -GapSize 60
    Test-Assert "6.QD-$count Quads layout for $count windows (dual screen)" ($result.Count -eq $count) $count.ToString() $result.Count.ToString()
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Tests: $($testsPassed + $testsFailed)"
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if($testsFailed -eq 0){"Green"}else{"Red"})
Write-Host "OVERALL: $(if($testsFailed -eq 0){'PASS'}else{'FAIL'})" -ForegroundColor $(if($testsFailed -eq 0){"Green"}else{"Red"})

exit $testsFailed
