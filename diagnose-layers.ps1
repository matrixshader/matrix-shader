# Deep layer diagnostics for WindowIdentityService
$env:MATRIX_DEBUG = "1"

cd $PSScriptRoot
. .\MatrixLogging.ps1
. .\WindowIdentityService.ps1

Write-Host ""
Write-Host "=== LAYER 1: LAUNCH REGISTRY ===" -ForegroundColor Cyan
Write-Host "Runtime registry entries:" -ForegroundColor Yellow
if ($script:LaunchRegistry -and $script:LaunchRegistry.Count -gt 0) {
    $script:LaunchRegistry.GetEnumerator() | ForEach-Object {
        Write-Host "  PID $($_.Key): $($_.Value.ProfileName)"
    }
} else {
    Write-Host "  (empty)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Persisted registry file:" -ForegroundColor Yellow
$registryFile = "$env:USERPROFILE\Documents\Matrix\identity-registry.json"
if (Test-Path $registryFile) {
    Get-Content $registryFile | Write-Host
} else {
    Write-Host "  (not found)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== LAYER 2: COMMAND LINE ===" -ForegroundColor Cyan
# Get all wt.exe processes
$wtProcesses = Get-CimInstance Win32_Process -Filter "Name='WindowsTerminal.exe'" -ErrorAction SilentlyContinue
foreach ($proc in $wtProcesses) {
    Write-Host ""
    Write-Host "PID: $($proc.ProcessId)" -ForegroundColor Yellow
    Write-Host "CommandLine: $($proc.CommandLine)" -ForegroundColor White

    # Check if command line contains profile info
    if ($proc.CommandLine -match '--profile\s+"([^"]+)"') {
        Write-Host "  -> Profile found: $($Matches[1])" -ForegroundColor Green
    } elseif ($proc.CommandLine -match '--profile\s+(\S+)') {
        Write-Host "  -> Profile found: $($Matches[1])" -ForegroundColor Green
    } else {
        Write-Host "  -> No --profile in command line" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== LAYER 4: UI AUTOMATION TEST ===" -ForegroundColor Cyan
Write-Host "(Testing first visible terminal window)" -ForegroundColor DarkGray

# Find all terminal windows
$terminals = [MatrixWindowAPI]::FindAllTerminalWindows()
Write-Host "Found $($terminals.Count) terminal windows" -ForegroundColor Yellow

foreach ($term in $terminals) {
    Write-Host ""
    Write-Host "Handle: $($term.Handle)  Title: $($term.Title)" -ForegroundColor White

    # Try UI Automation
    $uiIdentity = Get-UIAutomationIdentity -WindowHandle $term.Handle
    if ($uiIdentity) {
        Write-Host "  -> UI Automation: $($uiIdentity.ProfileName)" -ForegroundColor Green
    } else {
        Write-Host "  -> UI Automation: FAILED" -ForegroundColor Red
    }
}

$env:MATRIX_DEBUG = $null
