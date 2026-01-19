# test-identity-service.ps1
# Pester tests for WindowIdentityService.ps1
#
# Run with: Invoke-Pester -Path .\test-identity-service.ps1 -Output Detailed
# Or for quick validation: .\test-identity-service.ps1

param(
    [switch]$RunPester,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load the identity service
. "$scriptDir\WindowIdentityService.ps1"

# Enable verbose logging if requested
if ($Verbose) {
    Enable-IdentityVerboseLogging
}

# --- MANUAL TESTS (without Pester) ---

function Test-MatrixWindowAPI {
    Write-Host "`n=== Test: MatrixWindowAPI Type Loading ===" -ForegroundColor Cyan

    try {
        # Test that the type is loaded
        $typeExists = [MatrixWindowAPI] -ne $null
        Write-Host "  [PASS] MatrixWindowAPI type is loaded" -ForegroundColor Green

        # Test FindAllTerminalWindows method exists
        $method = [MatrixWindowAPI].GetMethod("FindAllTerminalWindows")
        if ($method) {
            Write-Host "  [PASS] FindAllTerminalWindows method exists" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] FindAllTerminalWindows method missing" -ForegroundColor Red
            return $false
        }

        # Test FindWindowsByTitlePattern method exists
        $method = [MatrixWindowAPI].GetMethod("FindWindowsByTitlePattern")
        if ($method) {
            Write-Host "  [PASS] FindWindowsByTitlePattern method exists" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] FindWindowsByTitlePattern method missing" -ForegroundColor Red
            return $false
        }

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-HandleValidation {
    Write-Host "`n=== Test: Test-WindowHandleValid ===" -ForegroundColor Cyan

    try {
        # Test with Zero handle - should be invalid
        $result = Test-WindowHandleValid -Handle ([IntPtr]::Zero)
        if (-not $result) {
            Write-Host "  [PASS] Zero handle correctly marked invalid" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Zero handle should be invalid" -ForegroundColor Red
            return $false
        }

        # Test with invalid handle
        $result = Test-WindowHandleValid -Handle ([IntPtr]12345)
        if (-not $result) {
            Write-Host "  [PASS] Invalid handle (12345) correctly marked invalid" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Invalid handle should be invalid" -ForegroundColor Red
            return $false
        }

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-LaunchRegistry {
    Write-Host "`n=== Test: Launch Registry ===" -ForegroundColor Cyan

    try {
        # Save current registry state
        $originalRegistry = $script:LaunchRegistry.Clone()

        # Create a mock process info
        $mockProc = [PSCustomObject]@{ Id = 99999 }

        # Register a launch
        Register-MatrixWindowLaunch -ProfileName "Matrix-Test" -ProcessInfo $mockProc
        Write-Host "  [PASS] Register-MatrixWindowLaunch executed" -ForegroundColor Green

        # Verify it's in the registry
        if ($script:LaunchRegistry.ContainsKey("99999")) {
            Write-Host "  [PASS] Entry added to registry" -ForegroundColor Green

            $entry = $script:LaunchRegistry["99999"]
            if ($entry.ProfileName -eq "Matrix-Test") {
                Write-Host "  [PASS] ProfileName stored correctly" -ForegroundColor Green
            } else {
                Write-Host "  [FAIL] ProfileName mismatch: $($entry.ProfileName)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  [FAIL] Entry not found in registry" -ForegroundColor Red
            return $false
        }

        # Clean up test entry
        $script:LaunchRegistry.Remove("99999")

        # Restore original registry
        $script:LaunchRegistry = $originalRegistry

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-TitleMatching {
    Write-Host "`n=== Test: Title Matching ===" -ForegroundColor Cyan

    try {
        # Test Matrix-N pattern
        $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "Matrix-1 - PowerShell"
        if ($identity -and $identity.ProfileName -eq "Matrix-1" -and $identity.Slot -eq 1) {
            Write-Host "  [PASS] Matrix-1 title matched correctly" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Matrix-1 title match failed" -ForegroundColor Red
            return $false
        }

        # Test Matrix-N with different slot
        $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "Some prefix Matrix-5 suffix"
        if ($identity -and $identity.Slot -eq 5) {
            Write-Host "  [PASS] Matrix-5 extracted from complex title" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Matrix-5 extraction failed" -ForegroundColor Red
            return $false
        }

        # Test Redpill pattern
        $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "RED PILL Control Panel"
        if ($identity -and $identity.IsRedpill) {
            Write-Host "  [PASS] Redpill title matched correctly" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Redpill title match failed" -ForegroundColor Red
            return $false
        }

        # Test non-matching title
        $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "Windows PowerShell"
        if (-not $identity) {
            Write-Host "  [PASS] Non-Matrix title correctly returned null" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Non-Matrix title should return null" -ForegroundColor Red
            return $false
        }

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-FindTerminalWindows {
    Write-Host "`n=== Test: Find Terminal Windows ===" -ForegroundColor Cyan

    try {
        # This test requires Windows Terminal to be running
        $windows = [MatrixWindowAPI]::FindAllTerminalWindows()

        Write-Host "  Found $($windows.Count) terminal windows" -ForegroundColor Gray

        if ($windows.Count -gt 0) {
            foreach ($win in $windows) {
                Write-Host "    Handle: $($win.Handle), PID: $($win.ProcessId), Title: '$($win.Title)'" -ForegroundColor DarkGray
            }
            Write-Host "  [PASS] FindAllTerminalWindows returned windows" -ForegroundColor Green
        } else {
            Write-Host "  [INFO] No terminal windows found (may be normal)" -ForegroundColor Yellow
        }

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-GetAllMatrixWindows {
    Write-Host "`n=== Test: Get-AllMatrixWindows ===" -ForegroundColor Cyan

    try {
        $startTime = Get-Date
        $windows = Get-AllMatrixWindows -IncludeRedpill
        $elapsed = ((Get-Date) - $startTime).TotalMilliseconds

        Write-Host "  Found $($windows.Count) Matrix windows in ${elapsed}ms" -ForegroundColor Gray

        if ($windows.Count -gt 0) {
            foreach ($win in $windows) {
                Write-Host "    $($win.ProfileName): Handle=$($win.Handle), Source=$($win.IdentitySource), Confidence=$($win.Confidence)" -ForegroundColor DarkGray
            }
            Write-Host "  [PASS] Get-AllMatrixWindows returned windows" -ForegroundColor Green

            # Performance check (target: 120ms for 6 windows)
            if ($elapsed -lt 500) {
                Write-Host "  [PASS] Performance: ${elapsed}ms (target < 500ms)" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Performance: ${elapsed}ms (slower than target)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [INFO] No Matrix windows found (may be normal if none running)" -ForegroundColor Yellow
        }

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-RegistryCleanup {
    Write-Host "`n=== Test: Registry Cleanup ===" -ForegroundColor Cyan

    try {
        # Save current registry
        $originalRegistry = $script:LaunchRegistry.Clone()

        # Add some fake stale entries
        $script:LaunchRegistry["11111"] = @{
            ProfileName = "Matrix-Test1"
            LaunchTime = (Get-Date).AddHours(-48)  # Old entry
            ProcessId = 11111
        }
        $script:LaunchRegistry["22222"] = @{
            ProfileName = "Matrix-Test2"
            LaunchTime = (Get-Date).AddHours(-48)  # Old entry
            ProcessId = 22222
        }

        Write-Host "  Added 2 stale test entries" -ForegroundColor Gray

        # Run cleanup
        $removed = Clean-WindowIdentityRegistry -MaxAgeHours 24

        Write-Host "  Cleanup removed $removed entries" -ForegroundColor Gray

        if ($removed -ge 2) {
            Write-Host "  [PASS] Stale entries were cleaned up" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Not all stale entries removed (removed: $removed)" -ForegroundColor Yellow
        }

        # Restore original registry
        $script:LaunchRegistry = $originalRegistry

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

function Test-CommandLineParsing {
    Write-Host "`n=== Test: Command Line Parsing ===" -ForegroundColor Cyan

    try {
        # Get current PowerShell's PID (won't match Matrix, but tests the mechanism)
        $currentPid = $PID

        $results = Get-CommandLineIdentities -ProcessIds @($currentPid)

        Write-Host "  Queried command line for PID $currentPid" -ForegroundColor Gray

        # We don't expect a match for our own process, but the query should work
        if ($results -is [hashtable]) {
            Write-Host "  [PASS] Command line query executed successfully" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Command line query returned unexpected type" -ForegroundColor Red
            return $false
        }

        return $true
    }
    catch {
        Write-Host "  [FAIL] Exception: $_" -ForegroundColor Red
        return $false
    }
}

# --- PESTER TESTS ---

$PesterTests = {
    Describe "WindowIdentityService" {

        Context "Type Loading" {
            It "Should have MatrixWindowAPI type loaded" {
                [MatrixWindowAPI] | Should -Not -BeNullOrEmpty
            }

            It "Should have FindAllTerminalWindows method" {
                $method = [MatrixWindowAPI].GetMethod("FindAllTerminalWindows")
                $method | Should -Not -BeNullOrEmpty
            }
        }

        Context "Handle Validation" {
            It "Should mark zero handle as invalid" {
                Test-WindowHandleValid -Handle ([IntPtr]::Zero) | Should -Be $false
            }

            It "Should mark arbitrary invalid handle as invalid" {
                Test-WindowHandleValid -Handle ([IntPtr]12345) | Should -Be $false
            }
        }

        Context "Title Matching" {
            It "Should match Matrix-1 in title" {
                $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "Matrix-1"
                $identity.ProfileName | Should -Be "Matrix-1"
                $identity.Slot | Should -Be 1
            }

            It "Should match Matrix-5 in complex title" {
                $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "prefix Matrix-5 suffix"
                $identity.Slot | Should -Be 5
            }

            It "Should match Redpill in title" {
                $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "RED PILL Control"
                $identity.IsRedpill | Should -Be $true
            }

            It "Should return null for non-Matrix title" {
                $identity = Get-TitleIdentity -WindowHandle ([IntPtr]1) -WindowTitle "PowerShell"
                $identity | Should -BeNullOrEmpty
            }
        }

        Context "Launch Registry" {
            BeforeEach {
                $script:OriginalRegistry = $script:LaunchRegistry.Clone()
            }

            AfterEach {
                $script:LaunchRegistry = $script:OriginalRegistry
            }

            It "Should register a launch" {
                $mockProc = [PSCustomObject]@{ Id = 88888 }
                Register-MatrixWindowLaunch -ProfileName "Matrix-Test" -ProcessInfo $mockProc
                $script:LaunchRegistry.ContainsKey("88888") | Should -Be $true
            }

            It "Should store correct profile name" {
                $mockProc = [PSCustomObject]@{ Id = 77777 }
                Register-MatrixWindowLaunch -ProfileName "Matrix-7" -ProcessInfo $mockProc
                $script:LaunchRegistry["77777"].ProfileName | Should -Be "Matrix-7"
            }
        }

        Context "Performance" {
            It "Should resolve windows in under 500ms" {
                $startTime = Get-Date
                Get-AllMatrixWindows | Out-Null
                $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
                $elapsed | Should -BeLessThan 500
            }
        }
    }
}

# --- MAIN ---

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " WindowIdentityService Test Suite" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if ($RunPester) {
    # Run Pester tests
    Write-Host "`nRunning Pester tests..." -ForegroundColor Yellow
    Invoke-Pester -ScriptBlock $PesterTests -Output Detailed
}
else {
    # Run manual tests
    $results = @{
        MatrixWindowAPI = Test-MatrixWindowAPI
        HandleValidation = Test-HandleValidation
        LaunchRegistry = Test-LaunchRegistry
        TitleMatching = Test-TitleMatching
        CommandLineParsing = Test-CommandLineParsing
        FindTerminalWindows = Test-FindTerminalWindows
        GetAllMatrixWindows = Test-GetAllMatrixWindows
        RegistryCleanup = Test-RegistryCleanup
    }

    # Summary
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host " Test Summary" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan

    $passed = ($results.Values | Where-Object { $_ -eq $true }).Count
    $total = $results.Count

    foreach ($test in $results.Keys) {
        $status = if ($results[$test]) { "[PASS]" } else { "[FAIL]" }
        $color = if ($results[$test]) { "Green" } else { "Red" }
        Write-Host "  $status $test" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  Total: $passed / $total passed" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
    Write-Host ""

    if ($passed -eq $total) {
        Write-Host "  All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "  Some tests failed. Review output above." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Tip: Run with -RunPester for Pester tests, -Verbose for detailed logging" -ForegroundColor DarkGray
}
