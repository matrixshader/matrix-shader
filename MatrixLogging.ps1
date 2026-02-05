# MatrixLogging.ps1
# Unified diagnostic logging for Matrix Terminal Shader
# All logging controlled by $env:MATRIX_DEBUG = "1"

<#
.SYNOPSIS
    Unified logging function for all Matrix components.

.DESCRIPTION
    Writes timestamped, color-coded log messages to console and file.
    Logging only occurs when $env:MATRIX_DEBUG equals "1".

    This replaces the per-module logging functions:
    - Write-Log (matrix_control.ps1)
    - Write-LayoutLog (WindowLayoutEngine.ps1)
    - Write-IdentityLog (WindowIdentityService.ps1)
    - Write-HotkeyLog (matrix_hotkeys.ps1)

.PARAMETER Message
    The message to log.

.PARAMETER Source
    The component generating the log (CONTROL, LAYOUT, IDENTITY, HOTKEY, SETUP).
    Defaults to GENERAL.

.PARAMETER Level
    Log level: DEBUG, INFO, WARN, ERROR. Defaults to INFO.

.PARAMETER Force
    If set, writes message even when MATRIX_DEBUG is not enabled.
    Useful for warnings/errors that should always be visible.

.EXAMPLE
    Write-MatrixLog "Starting layout calculation" -Source LAYOUT
    Write-MatrixLog "Window not found" -Source IDENTITY -Level WARN -Force
#>
function Write-MatrixLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('CONTROL', 'LAYOUT', 'IDENTITY', 'HOTKEY', 'SETUP', 'GENERAL')]
        [string]$Source = 'GENERAL',

        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [Parameter()]
        [switch]$Force
    )

    # Master switch: MATRIX_DEBUG must be "1" (unless Force or WARN/ERROR)
    $isEnabled = $env:MATRIX_DEBUG -eq "1"

    if (-not $isEnabled -and -not $Force -and $Level -notin @('WARN', 'ERROR')) {
        return
    }

    # Format: [timestamp] [SOURCE] [LEVEL] message
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Source] [$Level] $Message"

    # Console output with color coding (only when enabled or Force/WARN/ERROR)
    if ($isEnabled -or $Force -or $Level -in @('WARN', 'ERROR')) {
        $color = switch ($Level) {
            'DEBUG' { 'DarkGray' }
            'INFO'  { 'Gray' }
            'WARN'  { 'Yellow' }
            'ERROR' { 'Red' }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # File logging (only when MATRIX_DEBUG is enabled)
    if ($isEnabled) {
        try {
            $logDir = "$env:USERPROFILE\Documents\Matrix"
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            $logFile = "$logDir\debug.log"
            Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail file logging - don't interrupt operations
        }
    }
}

<#
.SYNOPSIS
    Clear the Matrix debug log file.

.DESCRIPTION
    Removes the debug.log file if it exists. Useful at session start.

.EXAMPLE
    Clear-MatrixLog
#>
function Clear-MatrixLog {
    [CmdletBinding()]
    param()

    $logFile = "$env:USERPROFILE\Documents\Matrix\debug.log"
    if (Test-Path $logFile) {
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue
        Write-MatrixLog "Log file cleared" -Source GENERAL -Level INFO -Force
    }
}

<#
.SYNOPSIS
    Enable Matrix debug logging for the current session.

.DESCRIPTION
    Sets $env:MATRIX_DEBUG to "1" and optionally clears the log file.

.PARAMETER ClearLog
    If set, clears the existing log file.

.EXAMPLE
    Enable-MatrixDebug -ClearLog
#>
function Enable-MatrixDebug {
    [CmdletBinding()]
    param(
        [switch]$ClearLog
    )

    $env:MATRIX_DEBUG = "1"

    if ($ClearLog) {
        Clear-MatrixLog
    }

    Write-MatrixLog "Debug logging ENABLED" -Source GENERAL -Level INFO -Force
}

<#
.SYNOPSIS
    Disable Matrix debug logging for the current session.

.EXAMPLE
    Disable-MatrixDebug
#>
function Disable-MatrixDebug {
    [CmdletBinding()]
    param()

    Write-MatrixLog "Debug logging DISABLED" -Source GENERAL -Level INFO -Force
    $env:MATRIX_DEBUG = $null
}

# Note: This file is designed to be dot-sourced, not imported as a module
