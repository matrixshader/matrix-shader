# Testing Patterns

**Analysis Date:** 2026-01-25

## Test Framework

**Runner:**
- Native PowerShell (`ps1` scripts) - no external test runner
- Manual test functions with colored output (Green/Red)
- Optional Pester integration supported but not required

**Assertion Library:**
- No external assertion library
- Manual comparison: `if ($result -eq $expected)` style
- Boolean condition checks: `if (-not $condition)` then fail

**Run Commands:**
```bash
# Run individual test file (manual execution)
.\test-functional.ps1

# Run with Pester (if installed)
Invoke-Pester -Path .\test-identity-service.ps1 -Output Detailed

# Enable debug logging for tests
$env:MATRIX_DEBUG = "1"; .\test-layout-phase1.ps1
```

## Test File Organization

**Location:**
- Co-located with source in project root: `C:\Users\ehome\documents\matrix\test-*.ps1`
- Not organized in separate `tests/` directory
- One test file per feature/module pair

**Naming:**
- Pattern: `test-{feature}.ps1` for feature tests
- Pattern: `test-{module}-{phase}.ps1` for phase-based testing
- Examples: `test-functional.ps1`, `test-identity-service.ps1`, `test-layout-phase1.ps1`

**Structure:**
```
test-{feature}.ps1 (107 test files total)
├── Load/dot-source required modules
├── Helper function definitions (Test-Result, Test-MatrixWindowAPI, etc.)
├── Test suite execution
└── Summary with pass/fail count
```

## Test Structure

**Suite Organization:**
All tests use manual pass/fail tracking with color-coded output:

```powershell
$passed = 0
$failed = 0

function Test-Result($name, $success, $msg = "") {
    if ($success) {
        Write-Host "PASS: $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "FAIL: $name" -ForegroundColor Red
        if ($msg) { Write-Host "      $msg" -ForegroundColor Yellow }
        $script:failed++
    }
}
```

**Patterns:**

1. **Header and Setup:**
```powershell
# test-layout-phase1.ps1
# Verification tests for WindowLayoutEngine Phase 1
# Tests: Get-ScreenTopology and Get-WindowDistribution

. "$PSScriptRoot\WindowLayoutEngine.ps1"

Write-Host "=== PHASE 1 VERIFICATION TESTS ===" -ForegroundColor Cyan
```

2. **Test Case Iteration:**
```powershell
$testCases = @(
    @{ Windows=4; Screens=1; Max=4; Expected=@(4); Name="4 windows, 1 screen, max 4" },
    @{ Windows=5; Screens=1; Max=4; Expected=@(4); Name="5 windows, 1 screen, max 4 (overflow)" }
)

foreach ($tc in $testCases) {
    try {
        $result = Get-WindowDistribution -WindowCount $tc.Windows -ScreenCount $tc.Screens -MaxPerScreen $tc.Max
        $resultStr = ($result -join ',')
        $expectedStr = ($tc.Expected -join ',')

        if ($resultStr -eq $expectedStr) {
            Write-Host "  PASS: $($tc.Name)" -ForegroundColor Green
        } else {
            Write-Host "  FAIL: $($tc.Name)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  FAIL: Exception: $_" -ForegroundColor Red
    }
}
```

3. **Exception Handling:**
```powershell
try {
    $screens = Get-ScreenTopology
    Test-Result "Screen detection works" ($screens.Count -gt 0)
} catch {
    Test-Result "Screen detection works" $false $_.Exception.Message
}
```

## Mocking

**Framework:** No mocking library (Pester mock not in use)

**Patterns:**
- Manual state isolation: save/restore `$script:` variables
- Mock objects created inline: `$mockProc = [PSCustomObject]@{ Id = 99999 }`
- File system mocking: use temp files in `$env:TEMP` directory
- Registry mocking: reset identity registry between tests

**Example from `test-identity-service.ps1`:**
```powershell
function Test-LaunchRegistry {
    try {
        # Save current registry state
        $originalRegistry = $script:LaunchRegistry.Clone()

        # Create a mock process info
        $mockProc = [PSCustomObject]@{ Id = 99999 }

        # Register a launch
        Register-MatrixWindowLaunch -ProfileName "Matrix-Test" -ProcessInfo $mockProc

        # Assertions...

        # Restore state
        $script:LaunchRegistry = $originalRegistry
        return $true
    }
    catch {
        return $false
    }
}
```

**What to Mock:**
- Process info: Create PSCustomObject with `Id` and `ProcessName` properties
- Window handles: Use fake IntPtr values for invalid handle tests (`[IntPtr]::Zero`, `[IntPtr]12345`)
- JSON files: Write temporary test JSON to `$env:TEMP`

**What NOT to Mock:**
- P/Invoke calls: Test with real Windows API when possible (EnumWindows, SetWindowPos)
- Screen detection: Real screen topology (or verify fallback when none available)
- File I/O: Test actual file writes to temp directory

## Fixtures and Factories

**Test Data:**
No centralized fixture factory; test data embedded in test files.

**Example from `test-layout-phase1.ps1`:**
```powershell
$testCases = @(
    @{ Windows=8; Screens=2; Max=4; Expected=@(4,4); Name="8 windows, 2 screens, max 4" },
    @{ Windows=3; Screens=2; Max=4; Expected=@(2,1); Name="3 windows, 2 screens, max 4" }
)
```

**Location:**
- Data in test file itself (no separate `fixtures/` directory)
- Reused across test cases in `foreach` loops
- Setup code at top of function when needed

## Coverage

**Requirements:** None enforced

**View Coverage:**
No coverage metrics tracked. Testing is outcome-based (does it work?) rather than coverage-based.

## Test Types

**Unit Tests:**
- Scope: Individual functions with clear inputs/outputs
- Approach: Direct function call, assert return value
- Examples:
  - `Get-ScreenTopology` returns array with valid dimensions
  - `Get-WindowDistribution` balances windows correctly across screens
  - `Get-ColorSwatch` produces ANSI escape codes of correct length

**Integration Tests:**
- Scope: Multiple modules working together
- Approach: Load entry point, verify import chains
- Examples:
  - `test-functional.ps1`: Verifies all modules load in correct order
  - `test-identity-integration.ps1`: Tests WindowIdentityService with WindowLayoutEngine
  - `test-layout-phase8.ps1`: Full end-to-end layout calculation

**E2E Tests:**
- Not automated; manual interactive verification
- Examples: Launch matrix_control.ps1, verify hotkey response, confirm window positioning
- Documented in `CLAUDE.md` testing section

**Phase-based Tests:**
- Organized by 8-phase architecture in `WindowLayoutEngine.ps1`
- `test-layout-phase1.ps1` through `test-layout-phase8.ps1`
- Each phase independently testable
- Edge case tests: `test-edge-cases.ps1` (50 scenarios)

## Common Patterns

**Async Testing:**
No async operations in PowerShell scripts. Polling-based operations use explicit wait loops:

```powershell
# From matrix_setup.ps1 - poll-based window launch verification
$maxWaitTime = 5000  # 5 seconds
$elapsedTime = 0
$pollInterval = 100  # ms

while ($elapsedTime -lt $maxWaitTime) {
    $windows = [MatrixWindowAPI]::FindAllTerminalWindows()
    if ($windows.Count -ge $expectedCount) {
        return $true  # Success
    }
    Start-Sleep -Milliseconds $pollInterval
    $elapsedTime += $pollInterval
}
return $false  # Timeout
```

**Error Testing:**
Test both success and failure paths:

```powershell
# Test valid handle
$result = Test-WindowHandleValid -Handle ([IntPtr]$validHandle)
Test-Result "Valid handle accepted" $result

# Test invalid handle
$result = Test-WindowHandleValid -Handle ([IntPtr]::Zero)
Test-Result "Zero handle rejected" (-not $result)

# Test exception case
try {
    Get-Content "C:\nonexistent.json" | ConvertFrom-Json
    Test-Result "Missing file error" $false
} catch {
    Test-Result "Missing file error" $true
}
```

**State Cleanup:**
Tests that modify state restore original state:

```powershell
# Save original
$original = $script:LaunchRegistry.Clone()
$originalPath = (Get-Item Env:MATRIX_DEBUG).Value

try {
    # Test with modified state
    $env:MATRIX_DEBUG = "1"
    $script:LaunchRegistry = @{}

    # Run tests...
}
finally {
    # Restore
    $script:LaunchRegistry = $original
    $env:MATRIX_DEBUG = $originalPath
}
```

## Test Output Format

**Pass/Fail Indicators:**
- Green checkmarks for passes: `Write-Host "PASS: ..." -ForegroundColor Green`
- Red X marks for failures: `Write-Host "FAIL: ..." -ForegroundColor Red`
- Yellow details for context: `Write-Host "      $msg" -ForegroundColor Yellow`
- Cyan headers: `Write-Host "=== TEST NAME ===" -ForegroundColor Cyan`

**Summary:**
```powershell
Write-Host ""
Write-Host "=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
if ($failed -gt 0) { exit 1 } else { exit 0 }
```

## Test Statistics

**Current Coverage:**
- 107 test files total in repository
- 50 edge case tests in `test-edge-cases.ps1`
- 8 phase-specific tests for `WindowLayoutEngine.ps1`
- Functional tests for all entry points (setup, control, bluepill)
- Identity service tests (launch tracking, handle validation, registry persistence)

**Test Execution:**
- Manual run: `.\test-{feature}.ps1` (5-10 seconds per file)
- Full suite: Run all 107 tests (parallel execution possible)
- Debug mode: `$env:MATRIX_DEBUG = "1"; .\test-functional.ps1` (adds logging output)

---

*Testing analysis: 2026-01-25*
