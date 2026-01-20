# test-usage-tracking.ps1
# Test suite for the Usage Tracking System (Task 2)
# Tests the functions added to WindowLayoutEngine.ps1

$ErrorActionPreference = 'Continue'
$script:TestsPassed = 0
$script:TestsFailed = 0

# Helper function for test output
function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message = ""
    )

    if ($Condition) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($Message) { Write-Host "       $Message" -ForegroundColor Yellow }
        $script:TestsFailed++
    }
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

# Load the WindowLayoutEngine module
Write-Host "Loading WindowLayoutEngine.ps1..." -ForegroundColor Cyan
try {
    . "$PSScriptRoot\WindowLayoutEngine.ps1"
    Write-Host "Module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "FATAL: Failed to load WindowLayoutEngine.ps1: $_" -ForegroundColor Red
    exit 1
}

# Backup existing state file
$stateFile = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"
$backupFile = "$env:USERPROFILE\Documents\Matrix\matrix_state.json.test_backup"
if (Test-Path $stateFile) {
    Copy-Item -Path $stateFile -Destination $backupFile -Force
    Write-Host "Backed up existing state file" -ForegroundColor Yellow
}

# ============================================================
# TEST 1: Initialize-UsageTracking
# ============================================================
Write-TestHeader "TEST 1: Initialize-UsageTracking"

try {
    # Reset to clean state
    $script:UsageTrackingData = @{}
    Initialize-UsageTracking
    Test-Assert "Initialize-UsageTracking runs without error" $true
}
catch {
    Test-Assert "Initialize-UsageTracking runs without error" $false $_
}

# ============================================================
# TEST 2: Update-WindowUsage - Focus Event
# ============================================================
Write-TestHeader "TEST 2: Update-WindowUsage (Focus Event)"

try {
    Reset-UsageTracking
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"

    $data = Get-WindowUsageData -ProfileName "Matrix-1"
    Test-Assert "Focus event creates profile entry" ($data.focusCount -eq 1)
    Test-Assert "Focus event sets lastFocusTime" ($data.lastFocusTime -ne [DateTime]::MinValue)
}
catch {
    Test-Assert "Update-WindowUsage Focus event" $false $_
}

# ============================================================
# TEST 3: Update-WindowUsage - Blur Event with Duration
# ============================================================
Write-TestHeader "TEST 3: Update-WindowUsage (Blur Event)"

try {
    Reset-UsageTracking

    # Focus then blur with small delay
    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Focus"
    Start-Sleep -Milliseconds 100
    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Blur"

    $data = Get-WindowUsageData -ProfileName "Matrix-2"
    Test-Assert "Blur event records duration" ($data.focusDurationMs -gt 0)
    Test-Assert "Duration is reasonable" ($data.focusDurationMs -ge 50 -and $data.focusDurationMs -lt 1000)
}
catch {
    Test-Assert "Update-WindowUsage Blur event" $false $_
}

# ============================================================
# TEST 4: Usage Score Calculation
# ============================================================
Write-TestHeader "TEST 4: Usage Score Calculation"

try {
    Reset-UsageTracking

    # Create two profiles with different usage patterns
    # Profile 1: More recent, less duration
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Start-Sleep -Milliseconds 50
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    # Profile 2: Older (simulate by not touching it)
    $data1 = Get-WindowUsageData -ProfileName "Matrix-1"
    Test-Assert "Usage score is calculated" ($data1.usageScore -gt 0)
    Test-Assert "Usage score is between 0 and 1" ($data1.usageScore -ge 0 -and $data1.usageScore -le 1)
}
catch {
    Test-Assert "Usage score calculation" $false $_
}

# ============================================================
# TEST 5: Get-WindowUsageData - Untracked Profile
# ============================================================
Write-TestHeader "TEST 5: Get-WindowUsageData (Untracked Profile)"

try {
    $data = Get-WindowUsageData -ProfileName "Matrix-999"
    Test-Assert "Returns default for untracked profile" ($data.focusCount -eq 0)
    Test-Assert "Default usageScore is 0" ($data.usageScore -eq 0)
    Test-Assert "Default isPriorityLocked is false" ($data.isPriorityLocked -eq $false)
}
catch {
    Test-Assert "Get-WindowUsageData untracked" $false $_
}

# ============================================================
# TEST 6: Get-LeastUsedWindow
# ============================================================
Write-TestHeader "TEST 6: Get-LeastUsedWindow"

try {
    Reset-UsageTracking

    # Create three profiles with different usage
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Start-Sleep -Milliseconds 100
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Focus"
    Start-Sleep -Milliseconds 50
    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Blur"

    # Matrix-3 never focused - should have lowest score
    $leastUsed = Get-LeastUsedWindow -WindowsOnMonitor @("Matrix-1", "Matrix-2", "Matrix-3")
    Test-Assert "Least used is untracked window" ($leastUsed -eq "Matrix-3")
}
catch {
    Test-Assert "Get-LeastUsedWindow" $false $_
}

# ============================================================
# TEST 7: Set-WindowPriority
# ============================================================
Write-TestHeader "TEST 7: Set-WindowPriority"

try {
    Reset-UsageTracking

    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    # Lock Matrix-1
    Set-WindowPriority -ProfileName "Matrix-1" -Locked $true

    $data = Get-WindowUsageData -ProfileName "Matrix-1"
    Test-Assert "Priority lock is set" ($data.isPriorityLocked -eq $true)
    Test-Assert "Locked window has score 999" ($data.usageScore -eq 999.0)

    # Unlock
    Set-WindowPriority -ProfileName "Matrix-1" -Locked $false
    $data = Get-WindowUsageData -ProfileName "Matrix-1"
    Test-Assert "Priority lock is cleared" ($data.isPriorityLocked -eq $false)
    Test-Assert "Unlocked window has normal score" ($data.usageScore -lt 999.0)
}
catch {
    Test-Assert "Set-WindowPriority" $false $_
}

# ============================================================
# TEST 8: Get-LeastUsedWindow with ExcludePriorityLocked
# ============================================================
Write-TestHeader "TEST 8: Get-LeastUsedWindow (ExcludePriorityLocked)"

try {
    Reset-UsageTracking

    # Matrix-1: never used, but locked
    Set-WindowPriority -ProfileName "Matrix-1" -Locked $true

    # Matrix-2: used
    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Focus"
    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Blur"

    # Matrix-3: never used, not locked

    # Without ExcludePriorityLocked - should still return Matrix-3 (lowest score not 999)
    $leastUsed = Get-LeastUsedWindow -WindowsOnMonitor @("Matrix-1", "Matrix-2", "Matrix-3") -ExcludePriorityLocked
    Test-Assert "Excludes locked window from least-used" ($leastUsed -eq "Matrix-3")
}
catch {
    Test-Assert "Get-LeastUsedWindow ExcludePriorityLocked" $false $_
}

# ============================================================
# TEST 9: Get-WindowsByUsage
# ============================================================
Write-TestHeader "TEST 9: Get-WindowsByUsage"

try {
    Reset-UsageTracking

    # Create some usage data
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Start-Sleep -Milliseconds 50
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Focus"
    Start-Sleep -Milliseconds 100
    Update-WindowUsage -ProfileName "Matrix-2" -EventType "Blur"

    $windows = Get-WindowsByUsage
    Test-Assert "Get-WindowsByUsage returns array" ($windows.Count -ge 2)
    Test-Assert "Results are sorted by usage score" ($windows[0].UsageScore -le $windows[1].UsageScore)
}
catch {
    Test-Assert "Get-WindowsByUsage" $false $_
}

# ============================================================
# TEST 10: Update-AllUsageScores
# ============================================================
Write-TestHeader "TEST 10: Update-AllUsageScores"

try {
    Reset-UsageTracking

    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    $scoreBefore = (Get-WindowUsageData -ProfileName "Matrix-1").usageScore

    # Wait a bit to allow recency decay
    Start-Sleep -Milliseconds 100
    Update-AllUsageScores

    # Score should recalculate (recency decays slightly)
    Test-Assert "Update-AllUsageScores runs without error" $true
}
catch {
    Test-Assert "Update-AllUsageScores" $false $_
}

# ============================================================
# TEST 11: Clear-StaleUsageData
# ============================================================
Write-TestHeader "TEST 11: Clear-StaleUsageData"

try {
    Reset-UsageTracking

    # Create a profile
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    # Clear with 0 days (should remove everything except locked)
    Clear-StaleUsageData -OlderThanDays 0

    # Check if cleared
    Test-Assert "Clear-StaleUsageData runs without error" $true
}
catch {
    Test-Assert "Clear-StaleUsageData" $false $_
}

# ============================================================
# TEST 12: Get-UsageTrackingSummary
# ============================================================
Write-TestHeader "TEST 12: Get-UsageTrackingSummary"

try {
    Reset-UsageTracking

    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Focus"
    Update-WindowUsage -ProfileName "Matrix-1" -EventType "Blur"

    $summary = Get-UsageTrackingSummary
    Test-Assert "Summary is a string" ($summary -is [string])
    Test-Assert "Summary contains window info" ($summary -match "Matrix-1")
}
catch {
    Test-Assert "Get-UsageTrackingSummary" $false $_
}

# ============================================================
# TEST 13: Persistence (Export/Import)
# ============================================================
Write-TestHeader "TEST 13: Persistence (Export/Import)"

try {
    Reset-UsageTracking

    # Create usage data
    Update-WindowUsage -ProfileName "Matrix-Persist" -EventType "Focus"
    Start-Sleep -Milliseconds 50
    Update-WindowUsage -ProfileName "Matrix-Persist" -EventType "Blur"

    $originalScore = (Get-WindowUsageData -ProfileName "Matrix-Persist").usageScore

    # Clear memory and reload
    $script:UsageTrackingData = @{}
    Initialize-UsageTracking

    $loadedData = Get-WindowUsageData -ProfileName "Matrix-Persist"
    Test-Assert "Persistence: Data reloaded" ($loadedData.focusCount -eq 1)
    Test-Assert "Persistence: Score preserved" ([Math]::Abs($loadedData.usageScore - $originalScore) -lt 0.1)
}
catch {
    Test-Assert "Persistence" $false $_
}

# ============================================================
# TEST 14: Multiple Focus Events
# ============================================================
Write-TestHeader "TEST 14: Multiple Focus Events"

try {
    Reset-UsageTracking

    # Multiple focus/blur cycles
    for ($i = 0; $i -lt 3; $i++) {
        Update-WindowUsage -ProfileName "Matrix-Multi" -EventType "Focus"
        Start-Sleep -Milliseconds 20
        Update-WindowUsage -ProfileName "Matrix-Multi" -EventType "Blur"
    }

    $data = Get-WindowUsageData -ProfileName "Matrix-Multi"
    Test-Assert "Multiple events: Focus count accumulated" ($data.focusCount -eq 3)
    Test-Assert "Multiple events: Duration accumulated" ($data.focusDurationMs -gt 50)
}
catch {
    Test-Assert "Multiple Focus Events" $false $_
}

# ============================================================
# CLEANUP
# ============================================================
Write-TestHeader "CLEANUP"

# Restore backup if exists
if (Test-Path $backupFile) {
    Copy-Item -Path $backupFile -Destination $stateFile -Force
    Remove-Item -Path $backupFile -Force
    Write-Host "Restored original state file" -ForegroundColor Yellow
}

# ============================================================
# FINAL RESULTS
# ============================================================
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Magenta
Write-Host "TEST RESULTS" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Magenta
Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed: $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Total:  $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor Cyan

if ($script:TestsFailed -eq 0) {
    Write-Host ""
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host ""
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
