# test-dynamic-accommodation.ps1
# Tests for Dynamic Accommodation System (Phase 3)
# Tests the core accommodation logic, drag detection, and monitor capacity functions

$ErrorActionPreference = 'Stop'

# Load the WindowLayoutEngine
$enginePath = Join-Path $PSScriptRoot "WindowLayoutEngine.ps1"
. $enginePath

# Enable verbose logging for tests
Enable-LayoutVerboseLogging

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  DYNAMIC ACCOMMODATION SYSTEM TESTS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$testResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
}

function Test-Assert {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$ExpectedBehavior = ""
    )

    Write-Host "`n--- Test: $Name ---" -ForegroundColor Yellow
    if ($ExpectedBehavior) {
        Write-Host "  Expected: $ExpectedBehavior" -ForegroundColor DarkGray
    }

    try {
        $result = & $Test
        if ($result -eq $true) {
            Write-Host "  PASSED" -ForegroundColor Green
            $script:testResults.Passed++
        }
        else {
            Write-Host "  FAILED: Test returned false" -ForegroundColor Red
            $script:testResults.Failed++
        }
    }
    catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $script:testResults.Failed++
    }
}

function Test-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host "`n--- Test: $Name ---" -ForegroundColor Yellow
    Write-Host "  SKIPPED: $Reason" -ForegroundColor DarkYellow
    $script:testResults.Skipped++
}

# =============================================================================
# TEST GROUP 1: Get-MonitorAtPoint
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 1: Get-MonitorAtPoint Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Get-MonitorAtPoint returns integer for valid point" -Test {
    $screens = Get-ScreenTopology
    if ($screens.Count -eq 0) { return $false }

    $screen = $screens[0]
    $centerX = $screen.Left + ($screen.Width / 2)
    $centerY = $screen.Top + ($screen.Height / 2)

    $result = Get-MonitorAtPoint -X $centerX -Y $centerY
    return ($result -is [int])
} -ExpectedBehavior "Should return integer monitor index"

Test-Assert -Name "Get-MonitorAtPoint returns 0 for primary monitor center" -Test {
    $screens = Get-ScreenTopology
    if ($screens.Count -eq 0) { return $false }

    $primary = $screens | Where-Object { $_.IsPrimary -eq $true } | Select-Object -First 1
    if (-not $primary) { $primary = $screens[0] }

    $centerX = $primary.Left + ($primary.Width / 2)
    $centerY = $primary.Top + ($primary.Height / 2)

    $result = Get-MonitorAtPoint -X $centerX -Y $centerY
    return ($result -eq 0)  # Primary should be index 0
} -ExpectedBehavior "Should return 0 for primary monitor"

Test-Assert -Name "Get-MonitorAtPoint returns 0 for out-of-bounds point" -Test {
    # Point way outside any possible monitor
    $result = Get-MonitorAtPoint -X -99999 -Y -99999
    return ($result -eq 0)
} -ExpectedBehavior "Should default to 0 for points outside all monitors"

# =============================================================================
# TEST GROUP 2: Get-MonitorCapacity
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 2: Get-MonitorCapacity Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Get-MonitorCapacity returns 4 for Quads mode" -Test {
    $capacity = Get-MonitorCapacity -MonitorIndex 0 -Mode 'Quads'
    return ($capacity -eq 4)
} -ExpectedBehavior "Quads mode always has capacity 4"

Test-Assert -Name "Get-MonitorCapacity returns MaxPillarsPerScreen for Pillars" -Test {
    $config = Get-MatrixLayoutConfig
    $expected = if ($config.MaxPillarsPerScreen) { $config.MaxPillarsPerScreen } else { 4 }

    $capacity = Get-MonitorCapacity -MonitorIndex 0 -Mode 'Pillars'
    return ($capacity -eq $expected)
} -ExpectedBehavior "Pillars mode uses MaxPillarsPerScreen setting"

Test-Assert -Name "Get-MonitorCapacity handles Auto mode" -Test {
    $capacity = Get-MonitorCapacity -MonitorIndex 0 -Mode 'Auto'
    return ($capacity -ge 1)  # Should return a valid capacity
} -ExpectedBehavior "Auto mode resolves to Pillars or Quads capacity"

# =============================================================================
# TEST GROUP 3: Get-CurrentLayoutMode
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 3: Get-CurrentLayoutMode Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Get-CurrentLayoutMode returns valid mode" -Test {
    $mode = Get-CurrentLayoutMode
    return ($mode -eq 'Pillars' -or $mode -eq 'Quads')
} -ExpectedBehavior "Should return 'Pillars' or 'Quads'"

# =============================================================================
# TEST GROUP 4: Window Monitor Assignments
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 4: Window Monitor Assignments" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Get-WindowsOnMonitor returns array" -Test {
    $windows = Get-WindowsOnMonitor -MonitorIndex 0
    return ($windows -is [array] -or $null -eq $windows)
} -ExpectedBehavior "Should return array (possibly empty)"

Test-Assert -Name "Update-WindowMonitorAssignments handles empty hashtable" -Test {
    $emptyHandles = @{}
    Update-WindowMonitorAssignments -WindowHandles $emptyHandles
    return $true  # No exception means success
} -ExpectedBehavior "Should not throw for empty input"

# =============================================================================
# TEST GROUP 5: Test-DragIntention
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 5: Test-DragIntention Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Test-DragIntention returns correct structure" -Test {
    # Create a mock position
    $currentPos = @{
        X = 100
        Y = 200
        Width = 400
        Height = 600
    }

    $result = Test-DragIntention -WindowHandle ([IntPtr]::Zero) -ProfileName "Test-1" -CurrentPosition $currentPos

    return (
        $result.ContainsKey('IsDrag') -and
        $result.ContainsKey('FromMonitor') -and
        $result.ContainsKey('ToMonitor') -and
        $result.ContainsKey('CrossedMonitor') -and
        $result.ContainsKey('DraggedProfileName') -and
        $result.ContainsKey('Movement')
    )
} -ExpectedBehavior "Should return hashtable with all required keys"

Test-Assert -Name "Test-DragIntention returns false for no movement" -Test {
    $currentPos = @{
        X = 100
        Y = 200
        Width = 400
        Height = 600
    }

    $result = Test-DragIntention -WindowHandle ([IntPtr]::Zero) -ProfileName "Test-1" -CurrentPosition $currentPos

    return ($result.IsDrag -eq $false)
} -ExpectedBehavior "Should return IsDrag=false when no prior position exists"

# =============================================================================
# TEST GROUP 6: Move-WindowToMonitor
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 6: Move-WindowToMonitor Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Move-WindowToMonitor handles non-existent window gracefully" -Test {
    # Should not throw, just warn
    Move-WindowToMonitor -ProfileName "NonExistent-Window" -TargetMonitor 1
    return $true
} -ExpectedBehavior "Should handle missing window without throwing"

Test-Assert -Name "Move-WindowToMonitor updates assignment correctly" -Test {
    # Set up a test assignment
    $script:WindowMonitorAssignments["Test-Window"] = @{
        Handle = [IntPtr]::new(12345)
        MonitorIndex = 0
        X = 100
        Y = 100
        Width = 400
        Height = 600
    }

    # Move to monitor 1
    Move-WindowToMonitor -ProfileName "Test-Window" -TargetMonitor 1

    $result = $script:WindowMonitorAssignments["Test-Window"].MonitorIndex -eq 1

    # Cleanup
    $script:WindowMonitorAssignments.Remove("Test-Window")

    return $result
} -ExpectedBehavior "Should update MonitorIndex to target"

# =============================================================================
# TEST GROUP 7: Invoke-DynamicAccommodation (Unit Tests)
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 7: Invoke-DynamicAccommodation" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Invoke-DynamicAccommodation returns correct structure" -Test {
    # Set up minimal test state
    $script:WindowMonitorAssignments = @{
        "Matrix-1" = @{ Handle = [IntPtr]::new(1); MonitorIndex = 0; X = 0; Y = 0; Width = 400; Height = 600 }
    }

    $handles = @{
        "Matrix-1" = @{ Handle = [IntPtr]::new(1) }
    }

    # This will fail to physically move windows (invalid handles) but should return correct structure
    $result = Invoke-DynamicAccommodation -DraggedWindow @{
        ProfileName = "Matrix-1"
        SourceMonitor = 0
    } -TargetMonitor 0 -WindowHandles $handles

    return (
        $result.ContainsKey('Success') -and
        $result.ContainsKey('Action') -and
        $result.ContainsKey('BumpedWindow') -and
        $result.ContainsKey('AffectedMonitors')
    )
} -ExpectedBehavior "Should return hashtable with Success, Action, BumpedWindow, AffectedMonitors"

Test-Assert -Name "Invoke-DynamicAccommodation Action='Added' when room available" -Test {
    # Set up: 1 window on monitor 0, drag to monitor 0 (same monitor, room available)
    $script:WindowMonitorAssignments = @{
        "Matrix-1" = @{ Handle = [IntPtr]::new(1); MonitorIndex = 0; X = 0; Y = 0; Width = 400; Height = 600 }
    }

    $handles = @{
        "Matrix-1" = @{ Handle = [IntPtr]::new(1) }
    }

    $result = Invoke-DynamicAccommodation -DraggedWindow @{
        ProfileName = "Matrix-1"
        SourceMonitor = 1  # Coming from monitor 1
    } -TargetMonitor 0 -WindowHandles $handles

    # Since monitor 0 has capacity 4 and only 1 window (excluding dragged), Action should be 'Added'
    return ($result.Action -eq 'Added')
} -ExpectedBehavior "Should return Action='Added' when target has room"

Test-Assert -Name "Invoke-DynamicAccommodation handles at-capacity scenario" -Test {
    # Set up: 4 windows on monitor 0 (at capacity for Quads mode)
    $script:WindowMonitorAssignments = @{
        "Matrix-1" = @{ Handle = [IntPtr]::new(1); MonitorIndex = 0; X = 0; Y = 0; Width = 400; Height = 600 }
        "Matrix-2" = @{ Handle = [IntPtr]::new(2); MonitorIndex = 0; X = 400; Y = 0; Width = 400; Height = 600 }
        "Matrix-3" = @{ Handle = [IntPtr]::new(3); MonitorIndex = 0; X = 0; Y = 600; Width = 400; Height = 600 }
        "Matrix-4" = @{ Handle = [IntPtr]::new(4); MonitorIndex = 0; X = 400; Y = 600; Width = 400; Height = 600 }
        "Matrix-5" = @{ Handle = [IntPtr]::new(5); MonitorIndex = 1; X = 0; Y = 0; Width = 400; Height = 600 }
    }

    # Initialize usage data (Matrix-3 has lowest score - should be bumped)
    $script:UsageTrackingData = @{
        "Matrix-1" = @{ lastFocusTime = (Get-Date).AddMinutes(-5); focusDurationMs = 10000; focusCount = 5; usageScore = 0.8; isPriorityLocked = $false }
        "Matrix-2" = @{ lastFocusTime = (Get-Date).AddMinutes(-10); focusDurationMs = 8000; focusCount = 4; usageScore = 0.6; isPriorityLocked = $false }
        "Matrix-3" = @{ lastFocusTime = (Get-Date).AddMinutes(-60); focusDurationMs = 1000; focusCount = 1; usageScore = 0.1; isPriorityLocked = $false }
        "Matrix-4" = @{ lastFocusTime = (Get-Date).AddMinutes(-15); focusDurationMs = 5000; focusCount = 3; usageScore = 0.5; isPriorityLocked = $false }
    }

    $handles = @{
        "Matrix-1" = @{ Handle = [IntPtr]::new(1) }
        "Matrix-2" = @{ Handle = [IntPtr]::new(2) }
        "Matrix-3" = @{ Handle = [IntPtr]::new(3) }
        "Matrix-4" = @{ Handle = [IntPtr]::new(4) }
        "Matrix-5" = @{ Handle = [IntPtr]::new(5) }
    }

    $result = Invoke-DynamicAccommodation -DraggedWindow @{
        ProfileName = "Matrix-5"
        SourceMonitor = 1
    } -TargetMonitor 0 -WindowHandles $handles

    # Should have swapped and bumped Matrix-3 (lowest usage)
    return ($result.Action -eq 'Swapped' -and $result.BumpedWindow -eq 'Matrix-3')
} -ExpectedBehavior "Should swap with least-used window (Matrix-3)"

# =============================================================================
# TEST GROUP 8: Test-PositionStable
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 8: Test-PositionStable Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Test-PositionStable returns false for invalid handle" -Test {
    $result = Test-PositionStable -WindowHandle ([IntPtr]::Zero)
    return ($result -eq $false)
} -ExpectedBehavior "Should return false for zero/invalid handle"

# =============================================================================
# TEST GROUP 9: Process-WindowDragEvents
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 9: Process-WindowDragEvents Tests" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Process-WindowDragEvents returns correct structure" -Test {
    # Use a hashtable with at least one (invalid) entry to pass validation
    $handles = @{ "Test-1" = @{ Handle = [IntPtr]::Zero } }
    $result = Process-WindowDragEvents -WindowHandles $handles

    return (
        $result.ContainsKey('DragDetected') -and
        $result.ContainsKey('ProcessedWindow') -and
        $result.ContainsKey('AccommodationResult')
    )
} -ExpectedBehavior "Should return hashtable with DragDetected, ProcessedWindow, AccommodationResult"

Test-Assert -Name "Process-WindowDragEvents handles invalid handles" -Test {
    $handles = @{ "Test-1" = @{ Handle = [IntPtr]::Zero } }
    $result = Process-WindowDragEvents -WindowHandles $handles
    return ($result.DragDetected -eq $false)
} -ExpectedBehavior "Should return DragDetected=false for invalid handles"

# =============================================================================
# TEST GROUP 10: Initialize-AccommodationSystem
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 10: Initialize-AccommodationSystem" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Initialize-AccommodationSystem sets state to IDLE" -Test {
    # Use a hashtable with at least one entry
    $handles = @{ "Test-1" = @{ Handle = [IntPtr]::Zero } }
    Initialize-AccommodationSystem -WindowHandles $handles
    return ($script:AccommodationState -eq 'IDLE')
} -ExpectedBehavior "Should set AccommodationState to 'IDLE'"

Test-Assert -Name "Initialize-AccommodationSystem clears stale assignments" -Test {
    # Add a stale assignment
    $script:WindowMonitorAssignments["Stale-Window"] = @{ MonitorIndex = 99 }

    # Use a different set of handles (not including Stale-Window)
    $handles = @{ "Test-1" = @{ Handle = [IntPtr]::Zero } }
    Initialize-AccommodationSystem -WindowHandles $handles

    # Stale assignment should be gone (reset clears all first)
    return (-not $script:WindowMonitorAssignments.ContainsKey("Stale-Window"))
} -ExpectedBehavior "Should clear stale window assignments"

# =============================================================================
# TEST GROUP 11: Get-AccommodationStateSummary
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 40 -ForegroundColor Magenta
Write-Host "  GROUP 11: Get-AccommodationStateSummary" -ForegroundColor Magenta
Write-Host "=" * 40 -ForegroundColor Magenta

Test-Assert -Name "Get-AccommodationStateSummary returns string" -Test {
    $summary = Get-AccommodationStateSummary
    return ($summary -is [string] -and $summary.Length -gt 0)
} -ExpectedBehavior "Should return non-empty string"

Test-Assert -Name "Get-AccommodationStateSummary includes state" -Test {
    $summary = Get-AccommodationStateSummary
    return ($summary -match "State:")
} -ExpectedBehavior "Should include 'State:' in output"

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "  Passed:  $($testResults.Passed)" -ForegroundColor Green
Write-Host "  Failed:  $($testResults.Failed)" -ForegroundColor Red
Write-Host "  Skipped: $($testResults.Skipped)" -ForegroundColor DarkYellow
Write-Host ""

$totalTests = $testResults.Passed + $testResults.Failed + $testResults.Skipped
$passRate = if ($totalTests -gt 0) { [Math]::Round(($testResults.Passed / $totalTests) * 100, 1) } else { 0 }
Write-Host "  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { 'Green' } elseif ($passRate -ge 60) { 'Yellow' } else { 'Red' })

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan

# Disable verbose logging
Disable-LayoutVerboseLogging

# Return exit code based on test results
if ($testResults.Failed -gt 0) {
    exit 1
}
exit 0
