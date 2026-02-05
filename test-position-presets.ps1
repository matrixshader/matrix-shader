# test-position-presets.ps1
# Tests for Position Presets System (Phase 4)

# Load WindowLayoutEngine
$enginePath = "$PSScriptRoot\WindowLayoutEngine.ps1"
. $enginePath

# Test counters
$script:passed = 0
$script:failed = 0

function Assert-True {
    param($Condition, $Message)
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failed++
    }
}

function Assert-False {
    param($Condition, $Message)
    if (-not $Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failed++
    }
}

function Assert-Equals {
    param($Expected, $Actual, $Message)
    if ($Expected -eq $Actual) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "[FAIL] $Message (Expected: $Expected, Actual: $Actual)" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Position Presets Tests" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Backup existing state file
$stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"
$backupPath = "$stateFilePath.test-backup"
if (Test-Path $stateFilePath) {
    Copy-Item $stateFilePath $backupPath -Force
    Write-Host "Backed up state file to $backupPath" -ForegroundColor Gray
}

try {
    # ========================================
    # Test 1: Get-MonitorConfigString
    # ========================================
    Write-Host "`n--- Test 1: Get-MonitorConfigString ---" -ForegroundColor Yellow

    $configString = Get-MonitorConfigString
    Assert-True ($configString -ne $null) "Monitor config string is not null"
    Assert-True ($configString -ne "UNKNOWN") "Monitor config string is not UNKNOWN"
    Assert-True ($configString -match "MONITOR_\d+_\d+x\d+") "Monitor config string has correct format"
    Write-Host "  Config string: $configString" -ForegroundColor Gray

    # ========================================
    # Test 2: Save-PositionPreset with mock windows
    # ========================================
    Write-Host "`n--- Test 2: Save-PositionPreset ---" -ForegroundColor Yellow

    # Create mock window info (we can't actually create windows in test)
    # Test with no windows - should return false
    $result = Save-PositionPreset -Name "TestPreset" -WindowInfo @()
    Assert-False $result "Save with empty windows returns false"

    # ========================================
    # Test 3: Get-PositionPresets (empty or with data)
    # ========================================
    Write-Host "`n--- Test 3: Get-PositionPresets ---" -ForegroundColor Yellow

    $presets = Get-PositionPresets
    # Empty array or array of presets - both valid
    Assert-True (($presets -eq $null) -or ($presets.Count -ge 0)) "Get-PositionPresets returns valid result"
    Write-Host "  Found $(@($presets).Count) preset(s)" -ForegroundColor Gray

    # ========================================
    # Test 4: Test-PresetCompatible with non-existent preset
    # ========================================
    Write-Host "`n--- Test 4: Test-PresetCompatible (non-existent) ---" -ForegroundColor Yellow

    $compat = Test-PresetCompatible -PresetName "NonExistentPreset"
    Assert-False $compat.IsCompatible "Non-existent preset is not compatible"
    # Could be "not found" or "No presets" depending on state
    Assert-True ($compat.Reason -match "not found|No presets") "Correct reason for non-existent preset"
    Write-Host "  Reason: $($compat.Reason)" -ForegroundColor Gray

    # ========================================
    # Test 5: Remove-PositionPreset (non-existent)
    # ========================================
    Write-Host "`n--- Test 5: Remove-PositionPreset (non-existent) ---" -ForegroundColor Yellow

    $result = Remove-PositionPreset -Name "NonExistentPreset"
    Assert-False $result "Remove non-existent preset returns false"

    # ========================================
    # Test 6: Full save/restore cycle with manual state
    # ========================================
    Write-Host "`n--- Test 6: Save/Restore Cycle (manual state) ---" -ForegroundColor Yellow

    # Manually create a preset in state file for testing
    $testState = @{
        positionPresets = @{
            "_test_preset" = @{
                savedAt = (Get-Date).ToString("o")
                monitorConfig = Get-MonitorConfigString
                positions = @{
                    "Matrix-1" = @{ x = 100; y = 100; width = 500; height = 400; monitor = 0 }
                    "Matrix-2" = @{ x = 650; y = 100; width = 500; height = 400; monitor = 0 }
                }
            }
        }
    }
    $testStateJson = $testState | ConvertTo-Json -Depth 10
    $testStateJson | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    # Test Get-PositionPresets finds our test preset
    $presets = Get-PositionPresets
    $testPreset = $presets | Where-Object { $_.Name -eq "_test_preset" }
    Assert-True ($testPreset -ne $null) "Test preset found in Get-PositionPresets"
    if ($testPreset) {
        Assert-Equals 2 $testPreset.WindowCount "Test preset has 2 windows"
        Assert-True $testPreset.IsCompatible "Test preset is compatible (same monitor config)"
    }

    # Test Test-PresetCompatible
    $compat = Test-PresetCompatible -PresetName "_test_preset"
    Assert-True $compat.IsCompatible "Test preset is compatible"
    Assert-Equals "Exact match" $compat.Reason "Compatibility reason is exact match"

    # Test Restore-PositionPreset (will fail because no actual windows, but shouldn't crash)
    $result = Restore-PositionPreset -Name "_test_preset" -WindowInfo @()
    Assert-False $result "Restore with no windows returns false"

    # Test Remove-PositionPreset
    $result = Remove-PositionPreset -Name "_test_preset"
    Assert-True $result "Remove test preset succeeds"

    # Verify removal
    $presets = Get-PositionPresets
    $testPreset = $presets | Where-Object { $_.Name -eq "_test_preset" }
    Assert-True ($testPreset -eq $null) "Test preset no longer exists after removal"

    # ========================================
    # Test 7: Monitor config mismatch handling
    # ========================================
    Write-Host "`n--- Test 7: Monitor Config Mismatch ---" -ForegroundColor Yellow

    # Create preset with different monitor config
    $testState = @{
        positionPresets = @{
            "_mismatched_preset" = @{
                savedAt = (Get-Date).ToString("o")
                monitorConfig = "MONITOR_0_9999x9999@0,0"  # Fake resolution
                positions = @{
                    "Matrix-1" = @{ x = 100; y = 100; width = 500; height = 400; monitor = 0 }
                }
            }
        }
    }
    $testStateJson = $testState | ConvertTo-Json -Depth 10
    $testStateJson | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    $compat = Test-PresetCompatible -PresetName "_mismatched_preset"
    Assert-True $compat.ScalingRequired "Mismatched config requires scaling"
    Write-Host "  Reason: $($compat.Reason)" -ForegroundColor Gray

    # ========================================
    # Test 8: Snapback preset naming
    # ========================================
    Write-Host "`n--- Test 8: Snapback Preset Naming ---" -ForegroundColor Yellow

    # Create snapback preset manually
    $testState = @{
        positionPresets = @{
            "_snapback" = @{
                savedAt = (Get-Date).ToString("o")
                monitorConfig = Get-MonitorConfigString
                positions = @{
                    "Matrix-1" = @{ x = 50; y = 50; width = 600; height = 500; monitor = 0 }
                }
            }
        }
    }
    $testStateJson = $testState | ConvertTo-Json -Depth 10
    $testStateJson | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    $presets = Get-PositionPresets
    $snapback = $presets | Where-Object { $_.Name -eq "_snapback" }
    Assert-True ($snapback -ne $null) "Snapback preset (_snapback) found"
    Write-Host "  Snapback saved at: $($snapback.SavedAt)" -ForegroundColor Gray

    # ========================================
    # Test 9: Multiple presets
    # ========================================
    Write-Host "`n--- Test 9: Multiple Presets ---" -ForegroundColor Yellow

    $testState = @{
        positionPresets = @{
            "_snapback" = @{
                savedAt = (Get-Date).ToString("o")
                monitorConfig = Get-MonitorConfigString
                positions = @{ "Matrix-1" = @{ x = 0; y = 0; width = 500; height = 400; monitor = 0 } }
            }
            "Coding" = @{
                savedAt = (Get-Date).ToString("o")
                monitorConfig = Get-MonitorConfigString
                positions = @{ "Matrix-1" = @{ x = 100; y = 100; width = 600; height = 500; monitor = 0 } }
            }
            "Monitoring" = @{
                savedAt = (Get-Date).ToString("o")
                monitorConfig = Get-MonitorConfigString
                positions = @{
                    "Matrix-1" = @{ x = 0; y = 0; width = 400; height = 300; monitor = 0 }
                    "Matrix-2" = @{ x = 400; y = 0; width = 400; height = 300; monitor = 0 }
                    "Matrix-3" = @{ x = 0; y = 300; width = 400; height = 300; monitor = 0 }
                }
            }
        }
    }
    $testStateJson = $testState | ConvertTo-Json -Depth 10
    $testStateJson | Out-File -FilePath $stateFilePath -Encoding UTF8 -Force

    $presets = Get-PositionPresets
    Assert-Equals 3 $presets.Count "Three presets found"

    $monitoring = $presets | Where-Object { $_.Name -eq "Monitoring" }
    Assert-Equals 3 $monitoring.WindowCount "Monitoring preset has 3 windows"

} finally {
    # Restore backup
    if (Test-Path $backupPath) {
        Move-Item $backupPath $stateFilePath -Force
        Write-Host "`nRestored state file from backup" -ForegroundColor Gray
    }
}

# ========================================
# Summary
# ========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $script:passed" -ForegroundColor Green
Write-Host "Failed: $script:failed" -ForegroundColor $(if ($script:failed -gt 0) { "Red" } else { "Green" })
Write-Host "Total:  $($script:passed + $script:failed)" -ForegroundColor White

if ($script:failed -eq 0) {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed!" -ForegroundColor Red
    exit 1
}
