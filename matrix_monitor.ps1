# MATRIX WINDOW MONITOR
# Background process that monitors Matrix window drags and triggers dynamic accommodation
# Integrates with WindowIdentityService and WindowLayoutEngine for reliable detection
# Runs independently of Redpill - starts with bluepill, runs until all Matrix windows close

param(
    [switch]$Debug,
    [switch]$Verbose
)

$matrixDir = "$env:USERPROFILE\Documents\Matrix"

# --- SINGLE INSTANCE CHECK ---
# Only one monitor should run at a time to avoid conflicts

function Test-AlreadyRunning {
    $currentPid = $PID
    $monitorProcesses = Get-Process powershell -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Id -ne $currentPid -and
            (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine -match 'matrix_monitor\.ps1'
        }

    return ($null -ne $monitorProcesses -and $monitorProcesses.Count -gt 0)
}

# Check for existing instance
if (Test-AlreadyRunning) {
    Write-Host "Matrix Monitor already running. Exiting." -ForegroundColor Yellow
    exit 0
}

# --- IMPORT MODULES ---

# Import WindowLayoutEngine (provides Process-WindowDragEvents, Initialize-AccommodationSystem)
$layoutEnginePath = "$PSScriptRoot\WindowLayoutEngine.ps1"
if (Test-Path $layoutEnginePath) {
    . $layoutEnginePath
} else {
    Write-Host "ERROR: WindowLayoutEngine.ps1 not found at $layoutEnginePath" -ForegroundColor Red
    exit 1
}

# Import WindowIdentityService (provides Get-AllMatrixWindows)
$identityServicePath = "$PSScriptRoot\WindowIdentityService.ps1"
if (Test-Path $identityServicePath) {
    . $identityServicePath
} else {
    Write-Host "ERROR: WindowIdentityService.ps1 not found at $identityServicePath" -ForegroundColor Red
    exit 1
}

# --- LOGGING SYSTEM ---

$script:MonitorLogFile = "$matrixDir\monitor_debug.log"
$script:MonitorVerbose = $Debug -or $Verbose -or ($env:MATRIX_DEBUG -eq "1")

function Write-MonitorLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [switch]$Force
    )

    # Skip if not enabled (unless Force or warning/error)
    if (-not $script:MonitorVerbose -and -not $Force -and $Level -notin @('WARN', 'ERROR')) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [MONITOR] [$Level] $Message"

    # Console output with color
    $color = switch ($Level) {
        'DEBUG' { 'DarkGray' }
        'INFO'  { 'Gray' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
    }

    if ($script:MonitorVerbose -or $Force -or $Level -in @('WARN', 'ERROR')) {
        Write-Host $logEntry -ForegroundColor $color
    }

    # File logging
    if ($script:MonitorVerbose) {
        try {
            $logDir = Split-Path $script:MonitorLogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $script:MonitorLogFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail file logging
        }
    }
}

# --- HELPER FUNCTIONS ---

<#
.SYNOPSIS
    Convert Get-AllMatrixWindows output to WindowHandles hashtable format.

.DESCRIPTION
    The WindowLayoutEngine expects a hashtable keyed by profile name with Handle property.
    This converts the array output from WindowIdentityService to that format.
#>
function ConvertTo-WindowHandles {
    param(
        [Parameter(Mandatory)]
        [array]$MatrixWindows
    )

    $windowHandles = @{}

    foreach ($win in $MatrixWindows) {
        if ($win.ProfileName -and $win.Handle) {
            $windowHandles[$win.ProfileName] = @{
                Handle = $win.Handle
                Slot = $win.Slot
                ProcessId = $win.ProcessId
            }
        }
    }

    return $windowHandles
}

<#
.SYNOPSIS
    Update usage tracking when focus changes.

.DESCRIPTION
    Track which windows are being actively used for future smart-positioning decisions.
#>
function Update-UsageTracking {
    param(
        [hashtable]$WindowHandles
    )

    # Simple usage tracking - could be expanded in future
    # For now, just log active window count
    $activeCount = ($WindowHandles.Keys | Measure-Object).Count
    Write-MonitorLog "Usage tracking: $activeCount Matrix windows active" -Level "DEBUG"
}

# --- MONITOR SETTINGS ---

$pollIntervalMs = 200      # Check every 200ms for drag events
$noWindowsTimeout = 5000   # Exit after 5 seconds with no Matrix windows
$cleanupIntervalMs = 60000 # Clean identity registry every 60 seconds
$lastCleanupTime = Get-Date

# --- STARTUP ---

Write-Host "Matrix Window Monitor v2.0 started" -ForegroundColor Cyan
Write-Host "  - Using WindowIdentityService for reliable window detection" -ForegroundColor DarkGray
Write-Host "  - Using WindowLayoutEngine for dynamic accommodation" -ForegroundColor DarkGray
Write-Host "  - Poll interval: ${pollIntervalMs}ms" -ForegroundColor DarkGray
Write-Host "  - No-windows timeout: $($noWindowsTimeout / 1000)s" -ForegroundColor DarkGray
if ($script:MonitorVerbose) {
    Write-Host "  - Debug logging: ENABLED" -ForegroundColor Green
}
Write-Host "Monitoring for window drags... (Ctrl+C to stop)" -ForegroundColor DarkGray

Write-MonitorLog "Monitor started (PID: $PID)" -Level "INFO"

# --- MAIN LOOP ---

$noWindowsTime = 0
$initialized = $false
$lastWindowCount = 0

while ($true) {
    try {
        # Get all Matrix windows using the new identity service
        $matrixWindows = Get-AllMatrixWindows -IncludeRedpill:$false

        # Convert to WindowHandles format expected by layout engine
        $windowHandles = ConvertTo-WindowHandles -MatrixWindows $matrixWindows
        $windowCount = $windowHandles.Count

        # Exit if no Matrix windows for too long
        if ($windowCount -eq 0) {
            $noWindowsTime += $pollIntervalMs
            if ($noWindowsTime -ge $noWindowsTimeout) {
                Write-Host "No Matrix windows detected for $($noWindowsTimeout/1000)s. Exiting." -ForegroundColor Yellow
                Write-MonitorLog "Exiting: no Matrix windows for ${noWindowsTimeout}ms" -Level "INFO"
                exit 0
            }
            Start-Sleep -Milliseconds $pollIntervalMs
            continue
        }
        $noWindowsTime = 0

        # Log window count changes
        if ($windowCount -ne $lastWindowCount) {
            Write-MonitorLog "Window count changed: $lastWindowCount -> $windowCount" -Level "INFO"
            $lastWindowCount = $windowCount
        }

        # Initialize accommodation system on first run or if window count changes significantly
        if (-not $initialized -or [Math]::Abs($windowCount - $lastWindowCount) -gt 1) {
            Write-MonitorLog "Initializing accommodation system with $windowCount windows" -Level "INFO"
            Initialize-AccommodationSystem -WindowHandles $windowHandles
            $initialized = $true
        }

        # Process drag events using the new accommodation system
        $dragResult = Process-WindowDragEvents -WindowHandles $windowHandles

        if ($dragResult.DragDetected) {
            $processedWindow = $dragResult.ProcessedWindow
            $accommodationResult = $dragResult.AccommodationResult

            Write-Host "Drag detected: $processedWindow" -ForegroundColor Green

            if ($accommodationResult) {
                if ($accommodationResult.Success) {
                    Write-Host "  Accommodation: $($accommodationResult.Action) ($($accommodationResult.AffectedMonitors.Count) monitors)" -ForegroundColor DarkGreen
                    Write-MonitorLog "Accommodation succeeded: $processedWindow via $($accommodationResult.Action)" -Level "INFO"
                } else {
                    Write-Host "  Accommodation failed: $($accommodationResult.Message)" -ForegroundColor Yellow
                    Write-MonitorLog "Accommodation failed for $processedWindow : $($accommodationResult.Message)" -Level "WARN"
                }
            }
        }

        # Update usage tracking
        Update-UsageTracking -WindowHandles $windowHandles

        # Periodic identity registry cleanup
        $now = Get-Date
        if (($now - $lastCleanupTime).TotalMilliseconds -ge $cleanupIntervalMs) {
            Write-MonitorLog "Running periodic identity registry cleanup" -Level "DEBUG"
            $removedCount = Clean-WindowIdentityRegistry -MaxAgeHours 24
            if ($removedCount -gt 0) {
                Write-MonitorLog "Cleaned $removedCount stale identity entries" -Level "INFO"
            }
            $lastCleanupTime = $now
        }
    }
    catch {
        Write-MonitorLog "Error in monitor loop: $_" -Level "ERROR"
        # Continue running despite errors
    }

    Start-Sleep -Milliseconds $pollIntervalMs
}
