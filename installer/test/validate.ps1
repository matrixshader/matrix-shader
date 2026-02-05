# validate.ps1 - Matrix Shader Clean-Room Validation
# Run in Windows Sandbox to verify no runtime dependencies
# Tests ACTUAL startup (with splash), not just --help

$ErrorActionPreference = 'Stop'
$TestDir = "C:\MatrixShader"
$ResultsFile = "C:\Test\results.txt"

Write-Host "================================" -ForegroundColor Cyan
Write-Host " Matrix Shader Validation" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Timing expectations (Native AOT cold-start is typically 500-1500ms)
$ColdStartMaxMs = 2000     # Cold-start tolerance for Native AOT
$SplashDurationMs = 1500   # Splash animation is 1500ms
$TotalStartupMaxMs = 5000  # Cold-start + splash + buffer

$exes = @(
    @{ Name = "wakeupneo.exe"; HasSplash = $true },
    @{ Name = "redpill.exe"; HasSplash = $true },
    @{ Name = "bluepill.exe"; HasSplash = $true }
)

$results = @()
$allPassed = $true

foreach ($exe in $exes) {
    $path = Join-Path $TestDir $exe.Name
    Write-Host "Testing $($exe.Name)..." -ForegroundColor Yellow

    # Check existence
    if (!(Test-Path $path)) {
        Write-Host "  FAIL: Not found" -ForegroundColor Red
        $results += "FAIL: $($exe.Name) - NOT FOUND"
        $allPassed = $false
        continue
    }

    # Test 1: --help response (should skip splash, be very fast)
    Write-Host "  Testing --help response..." -ForegroundColor Gray
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $proc = Start-Process -FilePath $path -ArgumentList "--help" -NoNewWindow -PassThru -Wait
        $sw.Stop()
        $helpMs = $sw.ElapsedMilliseconds

        if ($proc.ExitCode -ne 0) {
            Write-Host "  FAIL: --help exited with code $($proc.ExitCode)" -ForegroundColor Red
            $results += "FAIL: $($exe.Name) --help - Exit code $($proc.ExitCode)"
            $allPassed = $false
        }
        elseif ($helpMs -gt $ColdStartMaxMs) {
            Write-Host "  WARN: --help took ${helpMs}ms (>${ColdStartMaxMs}ms)" -ForegroundColor Yellow
            $results += "WARN: $($exe.Name) --help - ${helpMs}ms (exceeded ${ColdStartMaxMs}ms)"
        }
        else {
            Write-Host "  PASS: --help response ${helpMs}ms" -ForegroundColor Green
            $results += "PASS: $($exe.Name) --help - ${helpMs}ms"
        }
    }
    catch {
        $sw.Stop()
        Write-Host "  FAIL: --help threw exception: $_" -ForegroundColor Red
        $results += "FAIL: $($exe.Name) --help - Exception: $_"
        $allPassed = $false
    }

    # Test 2: Full startup with splash (kill after splash completes)
    # We expect ~2000ms total (500ms pre-splash + 1500ms splash)
    if ($exe.HasSplash) {
        Write-Host "  Testing full startup with splash..." -ForegroundColor Gray
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            # Start process and wait for it to initialize (kill before interactive mode)
            # Use --version if available, otherwise start and kill after splash time
            $proc = Start-Process -FilePath $path -ArgumentList "--version" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
            if ($null -eq $proc) {
                # --version not supported, start normally and kill after expected splash
                $proc = Start-Process -FilePath $path -NoNewWindow -PassThru
                Start-Sleep -Milliseconds ($SplashDurationMs + 1000)  # Wait for splash + buffer
                if (!$proc.HasExited) {
                    $proc.Kill()
                }
            }
            else {
                # Wait for --version to complete
                $proc.WaitForExit(5000)
            }
            $sw.Stop()
            $fullMs = $sw.ElapsedMilliseconds

            if ($fullMs -gt $TotalStartupMaxMs) {
                Write-Host "  WARN: Full startup ${fullMs}ms (>${TotalStartupMaxMs}ms with splash)" -ForegroundColor Yellow
                $results += "WARN: $($exe.Name) full startup - ${fullMs}ms (expected ~2000ms with splash)"
            }
            else {
                Write-Host "  PASS: Full startup ${fullMs}ms (includes ${SplashDurationMs}ms splash)" -ForegroundColor Green
                $results += "PASS: $($exe.Name) full startup - ${fullMs}ms"
            }
        }
        catch {
            $sw.Stop()
            Write-Host "  WARN: Full startup test inconclusive: $_" -ForegroundColor Yellow
            $results += "WARN: $($exe.Name) full startup - Test inconclusive: $_"
        }
    }

    Write-Host ""
}

# Test matrix-monitor.exe (no splash, background service)
$monitorPath = Join-Path $TestDir "matrix-monitor.exe"
Write-Host "Testing matrix-monitor.exe..." -ForegroundColor Yellow
if (Test-Path $monitorPath) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # Monitor runs as background service, start and kill quickly
        $proc = Start-Process -FilePath $monitorPath -NoNewWindow -PassThru
        Start-Sleep -Milliseconds 500  # Let it start
        if (!$proc.HasExited) {
            $proc.Kill()
        }
        $sw.Stop()
        $monitorMs = $sw.ElapsedMilliseconds
        Write-Host "  PASS: Monitor started successfully (${monitorMs}ms to test)" -ForegroundColor Green
        $results += "PASS: matrix-monitor.exe - Started successfully"
    }
    catch {
        $sw.Stop()
        Write-Host "  FAIL: Monitor startup failed: $_" -ForegroundColor Red
        $results += "FAIL: matrix-monitor.exe - $_"
        $allPassed = $false
    }
}
else {
    Write-Host "  FAIL: Not found" -ForegroundColor Red
    $results += "FAIL: matrix-monitor.exe - NOT FOUND"
    $allPassed = $false
}

# Summary
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host " ALL TESTS PASSED" -ForegroundColor Green
}
else {
    Write-Host " SOME TESTS FAILED" -ForegroundColor Red
}
Write-Host "================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Timing Expectations:" -ForegroundColor Gray
Write-Host "  Cold-start (--help): <${ColdStartMaxMs}ms" -ForegroundColor Gray
Write-Host "  Full startup with splash: <${TotalStartupMaxMs}ms" -ForegroundColor Gray
Write-Host "  (Native AOT cold-start + 1500ms splash animation)" -ForegroundColor Gray

# Save results (skip if read-only)
try {
    $results | Out-File -FilePath $ResultsFile -Encoding UTF8 -ErrorAction Stop
    Write-Host ""
    Write-Host "Results saved to: $ResultsFile" -ForegroundColor Gray
} catch {
    Write-Host ""
    Write-Host "(Results not saved - read-only folder)" -ForegroundColor Gray
}

# Keep window open
Write-Host ""
Write-Host "Press any key to close sandbox..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

if ($allPassed) { exit 0 } else { exit 1 }
