# Test Script for Phase 4: Configuration Management
# Tests Get-MatrixLayoutConfig and Set-MatrixLayoutConfig functions

$ErrorActionPreference = 'Stop'

# Import the layout engine
. "$PSScriptRoot\WindowLayoutEngine.ps1"

$stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"
$testsPassed = 0
$testsFailed = 0

function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "[FAIL] $TestName - $Message" -ForegroundColor Red
        $script:testsFailed++
    }
}

function Test-Equal {
    param(
        [string]$TestName,
        $Expected,
        $Actual
    )

    if ($Expected -eq $Actual) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "[FAIL] $TestName - Expected: $Expected, Actual: $Actual" -ForegroundColor Red
        $script:testsFailed++
    }
}

Write-Host "`n=== Phase 4 Configuration Management Tests ===" -ForegroundColor Cyan
Write-Host "Testing: Get-MatrixLayoutConfig and Set-MatrixLayoutConfig`n" -ForegroundColor Cyan

# Backup existing state file if present
$backupPath = $null
if (Test-Path $stateFilePath) {
    $backupPath = "$stateFilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $stateFilePath -Destination $backupPath -Force
    Write-Host "Backed up existing state to: $backupPath`n" -ForegroundColor Yellow
    Remove-Item -Path $stateFilePath -Force
}

# TEST 1: Get-MatrixLayoutConfig returns defaults when no config exists
Write-Host "`nTEST 1: Get defaults when no config exists" -ForegroundColor Yellow
try {
    $config = Get-MatrixLayoutConfig

    Test-Equal "Default Mode" "Pillars" $config.Mode
    Test-Equal "Default MaxPillarsPerScreen" 4 $config.MaxPillarsPerScreen
    Test-Equal "Default GapSize" 60 $config.GapSize
    Test-Equal "Default PreferredScreen" 0 $config.PreferredScreen
}
catch {
    Write-Host "[FAIL] TEST 1 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 2: Set-MatrixLayoutConfig writes config to state file
Write-Host "`nTEST 2: Set config writes to state file" -ForegroundColor Yellow
try {
    $newConfig = @{
        Mode = 'Quads'
        MaxPillarsPerScreen = 6
        GapSize = 80
        PreferredScreen = 1
    }

    Set-MatrixLayoutConfig -Config $newConfig

    Test-Assert "State file created" (Test-Path $stateFilePath) "File does not exist"

    if (Test-Path $stateFilePath) {
        $stateJson = Get-Content -Path $stateFilePath -Raw
        $state = $stateJson | ConvertFrom-Json

        Test-Assert "Layout section exists" ($null -ne $state.layout) "Layout section missing"
        Test-Equal "Mode saved correctly" 'Quads' $state.layout.mode
        Test-Equal "MaxPillarsPerScreen saved" 6 $state.layout.maxPillarsPerScreen
        Test-Equal "GapSize saved" 80 $state.layout.gapSize
        Test-Equal "PreferredScreen saved" 1 $state.layout.preferredScreen
    }
}
catch {
    Write-Host "[FAIL] TEST 2 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 3: Get-MatrixLayoutConfig reads back what was set
Write-Host "`nTEST 3: Get reads back what was set" -ForegroundColor Yellow
try {
    $config = Get-MatrixLayoutConfig

    Test-Equal "Mode read correctly" 'Quads' $config.Mode
    Test-Equal "MaxPillarsPerScreen read" 6 $config.MaxPillarsPerScreen
    Test-Equal "GapSize read" 80 $config.GapSize
    Test-Equal "PreferredScreen read" 1 $config.PreferredScreen
}
catch {
    Write-Host "[FAIL] TEST 3 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 4: Config persists after script reload
Write-Host "`nTEST 4: Config persists after reload" -ForegroundColor Yellow
try {
    # Clear module cache to simulate reload
    Remove-Variable -Name config -ErrorAction SilentlyContinue

    # Re-source the script (simulates reload)
    . "$PSScriptRoot\WindowLayoutEngine.ps1"

    $config = Get-MatrixLayoutConfig

    Test-Equal "Mode persisted" 'Quads' $config.Mode
    Test-Equal "MaxPillarsPerScreen persisted" 6 $config.MaxPillarsPerScreen
    Test-Equal "GapSize persisted" 80 $config.GapSize
    Test-Equal "PreferredScreen persisted" 1 $config.PreferredScreen
}
catch {
    Write-Host "[FAIL] TEST 4 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 5: Atomic write doesn't corrupt existing state
Write-Host "`nTEST 5: Atomic write preserves existing state data" -ForegroundColor Yellow
try {
    # Add some existing data to state
    $stateJson = Get-Content -Path $stateFilePath -Raw
    $state = $stateJson | ConvertFrom-Json | ConvertTo-Json | ConvertFrom-Json

    # Add custom data (simulating lastSlots array)
    $existingState = @{
        lastSlots = @(1, 2, 3)
        layout = $state.layout
    }

    $existingStateJson = $existingState | ConvertTo-Json -Depth 10
    $existingStateJson | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    # Now update layout config
    $updatedConfig = @{
        Mode = 'Pillars'
        MaxPillarsPerScreen = 4
        GapSize = 60
        PreferredScreen = 0
    }

    Set-MatrixLayoutConfig -Config $updatedConfig

    # Verify both old and new data exist
    $stateJson = Get-Content -Path $stateFilePath -Raw
    $state = $stateJson | ConvertFrom-Json

    Test-Assert "lastSlots preserved" ($null -ne $state.lastSlots) "lastSlots missing"
    Test-Equal "lastSlots[0] value" 1 $state.lastSlots[0]
    Test-Equal "Layout mode updated" 'Pillars' $state.layout.mode
    Test-Equal "Layout GapSize updated" 60 $state.layout.gapSize
}
catch {
    Write-Host "[FAIL] TEST 5 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 6: Partial config updates (only some fields provided)
Write-Host "`nTEST 6: Partial config updates" -ForegroundColor Yellow
try {
    # Update only Mode and GapSize
    $partialConfig = @{
        Mode = 'Quads'
        GapSize = 100
    }

    Set-MatrixLayoutConfig -Config $partialConfig

    $config = Get-MatrixLayoutConfig

    Test-Equal "Mode updated" 'Quads' $config.Mode
    Test-Equal "GapSize updated" 100 $config.GapSize
    Test-Equal "MaxPillarsPerScreen default applied" 4 $config.MaxPillarsPerScreen
    Test-Equal "PreferredScreen default applied" 0 $config.PreferredScreen
}
catch {
    Write-Host "[FAIL] TEST 6 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 7: Handle corrupted JSON gracefully
Write-Host "`nTEST 7: Handle corrupted JSON gracefully" -ForegroundColor Yellow
try {
    # Write invalid JSON to state file
    "{ invalid json }" | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    # Should return defaults without throwing
    $config = Get-MatrixLayoutConfig

    Test-Equal "Corrupted JSON returns default Mode" 'Pillars' $config.Mode
    Test-Equal "Corrupted JSON returns default GapSize" 60 $config.GapSize
}
catch {
    Write-Host "[FAIL] TEST 7 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# TEST 8: Empty config parameter defaults
Write-Host "`nTEST 8: Empty config uses defaults" -ForegroundColor Yellow
try {
    $emptyConfig = @{}

    Set-MatrixLayoutConfig -Config $emptyConfig

    $config = Get-MatrixLayoutConfig

    Test-Equal "Empty config Mode default" 'Pillars' $config.Mode
    Test-Equal "Empty config MaxPillarsPerScreen default" 4 $config.MaxPillarsPerScreen
    Test-Equal "Empty config GapSize default" 60 $config.GapSize
    Test-Equal "Empty config PreferredScreen default" 0 $config.PreferredScreen
}
catch {
    Write-Host "[FAIL] TEST 8 threw exception: $_" -ForegroundColor Red
    $testsFailed++
}

# Cleanup and restore
Write-Host "`n=== Cleanup ===" -ForegroundColor Cyan
if (Test-Path $stateFilePath) {
    Remove-Item -Path $stateFilePath -Force
    Write-Host "Removed test state file" -ForegroundColor Gray
}

if ($backupPath -and (Test-Path $backupPath)) {
    Move-Item -Path $backupPath -Destination $stateFilePath -Force
    Write-Host "Restored original state file from backup" -ForegroundColor Gray
}

# Test Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { 'Green' } else { 'Red' })

if ($testsFailed -eq 0) {
    Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
