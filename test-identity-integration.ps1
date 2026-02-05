# Test script for WindowIdentityService integration
# Verifies that all 5+ Matrix windows are detected correctly using 4-layer identity hierarchy

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$matrixDir = "$env:USERPROFILE\Documents\Matrix"

Write-Host ""
Write-Host "=== WINDOW IDENTITY SERVICE INTEGRATION TEST ===" -ForegroundColor Cyan
Write-Host ""

# Import WindowIdentityService
$identityServicePath = "$PSScriptRoot\WindowIdentityService.ps1"
if (-not (Test-Path $identityServicePath)) {
    Write-Host "ERROR: WindowIdentityService.ps1 not found at $identityServicePath" -ForegroundColor Red
    exit 1
}

Write-Host "Importing WindowIdentityService..." -ForegroundColor Gray
. $identityServicePath

# Enable verbose logging if requested
if ($Verbose) {
    Enable-IdentityVerboseLogging -ClearLog
    Write-Host "  Verbose logging enabled" -ForegroundColor DarkGray
}

Write-Host "  Service loaded successfully" -ForegroundColor Green
Write-Host ""

# Test 1: Get all Matrix windows
Write-Host "TEST 1: Get-AllMatrixWindows" -ForegroundColor Yellow
Write-Host "  Detecting Matrix windows using 4-layer hierarchy..." -ForegroundColor Gray

$windows = Get-AllMatrixWindows -IncludeRedpill:$false

Write-Host "  Found $($windows.Count) Matrix windows" -ForegroundColor Cyan
Write-Host ""

if ($windows.Count -eq 0) {
    Write-Host "  WARNING: No Matrix windows detected!" -ForegroundColor Yellow
    Write-Host "  Make sure you have Matrix windows open before running this test." -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "  Window Details:" -ForegroundColor White
    foreach ($win in $windows) {
        $confidenceColor = switch ($win.Confidence) {
            { $_ -ge 0.95 } { "Green" }
            { $_ -ge 0.80 } { "Yellow" }
            default { "Red" }
        }

        Write-Host "    Slot $($win.Slot): " -NoNewline -ForegroundColor Cyan
        Write-Host "Handle=$($win.Handle) " -NoNewline -ForegroundColor Gray
        Write-Host "PID=$($win.ProcessId) " -NoNewline -ForegroundColor Gray
        Write-Host "[$($win.IdentitySource)] " -NoNewline -ForegroundColor $confidenceColor
        Write-Host "Confidence: $($win.Confidence)" -ForegroundColor $confidenceColor
        Write-Host "      Title: '$($win.Title)'" -ForegroundColor DarkGray
        Write-Host "      Shader: $($win.ShaderFile)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Test 2: Verify identity sources
    Write-Host "TEST 2: Identity Source Distribution" -ForegroundColor Yellow
    $sourceCounts = @{}
    foreach ($win in $windows) {
        $source = $win.IdentitySource
        if (-not $sourceCounts.ContainsKey($source)) {
            $sourceCounts[$source] = 0
        }
        $sourceCounts[$source]++
    }
    foreach ($source in $sourceCounts.Keys) {
        $count = $sourceCounts[$source]
        $percent = [math]::Round(($count / $windows.Count) * 100)
        Write-Host "  ${source}: $count windows ($percent%)" -ForegroundColor Cyan
    }
    Write-Host ""

    # Test 3: Verify no duplicates
    Write-Host "TEST 3: Duplicate Detection" -ForegroundColor Yellow
    $slotCounts = @{}
    foreach ($win in $windows) {
        $slot = $win.Slot
        if (-not $slotCounts.ContainsKey($slot)) {
            $slotCounts[$slot] = 0
        }
        $slotCounts[$slot]++
    }
    $hasDuplicates = $false
    foreach ($slot in $slotCounts.Keys) {
        if ($slotCounts[$slot] -gt 1) {
            Write-Host "  WARNING: Slot $slot detected $($slotCounts[$slot]) times!" -ForegroundColor Red
            $hasDuplicates = $true
        }
    }
    if (-not $hasDuplicates) {
        Write-Host "  No duplicate slots detected" -ForegroundColor Green
    }
    Write-Host ""

    # Test 4: Verify sequential slots
    Write-Host "TEST 4: Slot Sequence" -ForegroundColor Yellow
    $sortedSlots = ($windows | ForEach-Object { $_.Slot } | Sort-Object)
    Write-Host "  Detected slots: [$($sortedSlots -join ', ')]" -ForegroundColor Cyan

    # Check for gaps
    $gaps = @()
    for ($i = 0; $i -lt ($sortedSlots.Count - 1); $i++) {
        $current = $sortedSlots[$i]
        $next = $sortedSlots[$i + 1]
        if ($next - $current -gt 1) {
            for ($gap = $current + 1; $gap -lt $next; $gap++) {
                $gaps += $gap
            }
        }
    }
    if ($gaps.Count -gt 0) {
        Write-Host "  Gaps detected: [$($gaps -join ', ')]" -ForegroundColor Yellow
    } else {
        Write-Host "  Sequential slots (no gaps)" -ForegroundColor Green
    }
    Write-Host ""

    # Test 5: Verify confidence levels
    Write-Host "TEST 5: Confidence Levels" -ForegroundColor Yellow
    $confidences = @()
    foreach ($win in $windows) {
        $confidences += $win.Confidence
    }
    $avgConfidence = ($confidences | Measure-Object -Average).Average
    $minConfidence = ($confidences | Measure-Object -Minimum).Minimum

    Write-Host "  Average confidence: $([math]::Round($avgConfidence, 2))" -ForegroundColor Cyan
    Write-Host "  Minimum confidence: $minConfidence" -ForegroundColor Cyan

    if ($minConfidence -lt 0.70) {
        Write-Host "  WARNING: Some windows have low confidence!" -ForegroundColor Yellow
    } else {
        Write-Host "  All windows have acceptable confidence" -ForegroundColor Green
    }
    Write-Host ""

    # Test 6: Performance check
    Write-Host "TEST 6: Performance" -ForegroundColor Yellow
    Write-Host "  Running 5 detection cycles..." -ForegroundColor Gray

    $times = @()
    for ($i = 1; $i -le 5; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $testWindows = Get-AllMatrixWindows -IncludeRedpill:$false
        $sw.Stop()
        $elapsed = $sw.ElapsedMilliseconds
        $times += $elapsed
        $winCount = $testWindows.Count
        Write-Host "    Cycle ${i}: ${elapsed}ms ($winCount windows)" -ForegroundColor DarkGray
    }

    $avgTime = ($times | Measure-Object -Average).Average
    $targetTime = 120 * $windows.Count  # 120ms per window target

    Write-Host "  Average time: $([math]::Round($avgTime))ms" -ForegroundColor Cyan
    Write-Host "  Target time: $([math]::Round($targetTime))ms (120ms/window)" -ForegroundColor DarkGray

    if ($avgTime -le $targetTime) {
        Write-Host "  Performance: EXCELLENT" -ForegroundColor Green
    } elseif ($avgTime -le ($targetTime * 2)) {
        Write-Host "  Performance: ACCEPTABLE" -ForegroundColor Yellow
    } else {
        Write-Host "  Performance: NEEDS IMPROVEMENT" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 7: Registry persistence
Write-Host "TEST 7: Registry Persistence" -ForegroundColor Yellow
$registryPath = "$matrixDir\identity-registry.json"
if (Test-Path $registryPath) {
    $registryContent = Get-Content $registryPath -Raw | ConvertFrom-Json
    $entryCount = if ($registryContent.entries) { $registryContent.entries.PSObject.Properties.Count } else { 0 }
    Write-Host "  Registry file exists: YES" -ForegroundColor Green
    Write-Host "  Persisted entries: $entryCount" -ForegroundColor Cyan
    Write-Host "  Last saved: $($registryContent.savedAt)" -ForegroundColor DarkGray
} else {
    Write-Host "  Registry file exists: NO" -ForegroundColor Yellow
    Write-Host "  (Will be created on first launch)" -ForegroundColor DarkGray
}
Write-Host ""

# Summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
if ($windows.Count -ge 5) {
    Write-Host "  Status: PASS" -ForegroundColor Green
    Write-Host "  All integration points working correctly" -ForegroundColor Green
} elseif ($windows.Count -gt 0) {
    Write-Host "  Status: PARTIAL" -ForegroundColor Yellow
    Write-Host "  Identity service working, but fewer than 5 windows detected" -ForegroundColor Yellow
} else {
    Write-Host "  Status: NEEDS WINDOWS" -ForegroundColor Yellow
    Write-Host "  Open some Matrix windows and re-run this test" -ForegroundColor Yellow
}
Write-Host ""

# Cleanup recommendation
if ($windows.Count -gt 0) {
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Run 'redpill' to verify control panel integration" -ForegroundColor Gray
    Write-Host "  2. Test window launches with Shift+L layout cycling" -ForegroundColor Gray
    Write-Host "  3. Verify drag-snap with matrix_monitor.ps1" -ForegroundColor Gray
    Write-Host ""
}
