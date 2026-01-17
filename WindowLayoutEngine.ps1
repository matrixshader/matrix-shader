# WindowLayoutEngine.ps1
# Centralized layout engine for Matrix Terminal windows
# Implements Pillars and Quads layout strategies with multi-monitor support

# --- WINDOWS API P/INVOKE DECLARATIONS ---
# Note: These may already be loaded by matrix_control.ps1, but re-declaring is safe (ErrorAction SilentlyContinue)
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class WindowLayoutAPI {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, byte bAlpha, uint dwFlags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    public const int SW_RESTORE = 9;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_LAYERED = 0x80000;
    public const uint LWA_ALPHA = 0x2;
}
"@

# Load System.Windows.Forms for screen detection
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

# --- VERBOSE LOGGING SYSTEM ---

# Global toggle for verbose layout logging (set to $true to enable)
$script:LayoutEngineVerbose = $false
$script:LayoutLogFile = "$env:USERPROFILE\Documents\Matrix\layout_debug.log"

<#
.SYNOPSIS
    Write a log message for layout engine debugging.

.DESCRIPTION
    Writes timestamped messages to both console (when verbose) and optional log file.
    Controlled by $script:LayoutEngineVerbose global variable.
    Integrates with US-009 diagnostic logging pattern.

.PARAMETER Message
    The message to log

.PARAMETER Level
    Log level: INFO, WARN, ERROR, DEBUG (default: INFO)

.PARAMETER Force
    If set, writes message even when verbose mode is disabled (for warnings/errors)

.EXAMPLE
    Write-LayoutLog "Starting layout calculation" -Level "INFO"
    Write-LayoutLog "Invalid handle detected" -Level "WARN" -Force
#>
function Write-LayoutLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [switch]$Force
    )

    # Skip if verbose mode is disabled (unless Force or it's a warning/error)
    if (-not $script:LayoutEngineVerbose -and -not $Force -and $Level -notin @('WARN', 'ERROR')) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output with color coding
    $color = switch ($Level) {
        'INFO'  { 'Gray' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'DarkGray' }
    }

    if ($script:LayoutEngineVerbose -or $Force -or $Level -in @('WARN', 'ERROR')) {
        Write-Host $logEntry -ForegroundColor $color
    }

    # File logging (only when verbose is enabled)
    if ($script:LayoutEngineVerbose) {
        try {
            # Ensure log directory exists
            $logDir = Split-Path $script:LayoutLogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $script:LayoutLogFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail file logging - don't interrupt layout operations
        }
    }
}

<#
.SYNOPSIS
    Enable verbose layout logging.

.DESCRIPTION
    Sets the LayoutEngineVerbose flag and optionally clears the log file.

.PARAMETER ClearLog
    If set, clears the existing log file

.EXAMPLE
    Enable-LayoutVerboseLogging -ClearLog
#>
function Enable-LayoutVerboseLogging {
    param(
        [switch]$ClearLog
    )

    $script:LayoutEngineVerbose = $true
    Write-LayoutLog "Verbose logging ENABLED" -Level "INFO" -Force

    if ($ClearLog -and (Test-Path $script:LayoutLogFile)) {
        Remove-Item $script:LayoutLogFile -Force -ErrorAction SilentlyContinue
        Write-LayoutLog "Log file cleared" -Level "INFO" -Force
    }
}

<#
.SYNOPSIS
    Disable verbose layout logging.

.EXAMPLE
    Disable-LayoutVerboseLogging
#>
function Disable-LayoutVerboseLogging {
    Write-LayoutLog "Verbose logging DISABLED" -Level "INFO" -Force
    $script:LayoutEngineVerbose = $false
}

# --- SCREEN TOPOLOGY DETECTION ---

<#
.SYNOPSIS
    Detect all monitors and return their working areas (excludes taskbar).

.DESCRIPTION
    Returns an array of screen objects with index, position, size, and primary flag.
    Working area excludes the taskbar and other docked windows.

.OUTPUTS
    Array of @{ Index, Left, Top, Width, Height, IsPrimary }

.EXAMPLE
    $screens = Get-ScreenTopology
    # Returns: @(
    #   @{ Index=0; Left=0; Top=0; Width=1920; Height=1040; IsPrimary=$true },
    #   @{ Index=1; Left=1920; Top=0; Width=1920; Height=1080; IsPrimary=$false }
    # )
#>
function Get-ScreenTopology {
    try {
        $allScreens = [System.Windows.Forms.Screen]::AllScreens
        $topology = @()

        for ($i = 0; $i -lt $allScreens.Count; $i++) {
            $screen = $allScreens[$i]
            $workingArea = $screen.WorkingArea

            $topology += @{
                Index = $i
                Left = $workingArea.X
                Top = $workingArea.Y
                Width = $workingArea.Width
                Height = $workingArea.Height
                IsPrimary = $screen.Primary
            }
        }

        return $topology
    }
    catch {
        Write-Warning "Failed to detect screen topology: $_"
        # Fallback to primary screen only
        $primary = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        return @(
            @{
                Index = 0
                Left = $primary.X
                Top = $primary.Y
                Width = $primary.Width
                Height = $primary.Height
                IsPrimary = $true
            }
        )
    }
}

# --- WINDOW DISTRIBUTION ALGORITHM ---

<#
.SYNOPSIS
    Distribute N windows across M screens with a maximum per screen.

.DESCRIPTION
    Evenly distributes windows across available screens, respecting MaxPerScreen limit.
    Algorithm: floor division with remainder distributed to first screens.

.PARAMETER WindowCount
    Total number of windows to distribute

.PARAMETER ScreenCount
    Number of available screens

.PARAMETER MaxPerScreen
    Maximum windows allowed per screen (default: 4)

.OUTPUTS
    Array of integers representing window count per screen

.EXAMPLE
    Get-WindowDistribution -WindowCount 4 -ScreenCount 1 -MaxPerScreen 4
    # Returns: @(4)

.EXAMPLE
    Get-WindowDistribution -WindowCount 5 -ScreenCount 1 -MaxPerScreen 4
    # Returns: @(4) - overflow not handled in distribution, handled by layout strategy

.EXAMPLE
    Get-WindowDistribution -WindowCount 8 -ScreenCount 2 -MaxPerScreen 4
    # Returns: @(4, 4)

.EXAMPLE
    Get-WindowDistribution -WindowCount 3 -ScreenCount 2 -MaxPerScreen 4
    # Returns: @(2, 1)
#>
function Get-WindowDistribution {
    param(
        [Parameter(Mandatory)]
        [int]$WindowCount,

        [Parameter(Mandatory)]
        [int]$ScreenCount,

        [int]$MaxPerScreen = 4
    )

    if ($WindowCount -le 0) {
        return @(0) * $ScreenCount
    }

    if ($ScreenCount -le 0) {
        Write-Warning "Invalid ScreenCount: $ScreenCount"
        return @()
    }

    # Initialize distribution array
    $distribution = @(0) * $ScreenCount

    # Special case: single screen - distribute ALL windows to it (allow overflow for multi-row)
    if ($ScreenCount -eq 1) {
        $distribution[0] = $WindowCount
        return $distribution
    }

    # Multi-screen distribution: balance windows across screens
    # Base windows per screen (floor division)
    $windowsPerScreen = [Math]::Floor($WindowCount / $ScreenCount)

    # Cap at MaxPerScreen for balanced distribution
    $windowsPerScreen = [Math]::Min($windowsPerScreen, $MaxPerScreen)

    # Remainder to distribute
    $remainder = $WindowCount % $ScreenCount

    # Distribute base count to all screens
    for ($i = 0; $i -lt $ScreenCount; $i++) {
        $distribution[$i] = $windowsPerScreen
    }

    # Distribute remainder to first screens (round-robin)
    for ($i = 0; $i -lt $remainder; $i++) {
        $screenIndex = $i % $ScreenCount
        if ($distribution[$screenIndex] -lt $MaxPerScreen) {
            $distribution[$screenIndex]++
        }
        else {
            # If first screen is full, find next available screen
            for ($j = 0; $j -lt $ScreenCount; $j++) {
                if ($distribution[$j] -lt $MaxPerScreen) {
                    $distribution[$j]++
                    break
                }
            }
        }
    }

    return $distribution
}

# --- PILLARS LAYOUT STRATEGY ---

<#
.SYNOPSIS
    Calculate Pillars layout: vertical columns arranged side-by-side.

.DESCRIPTION
    Arranges windows as vertical pillars (columns) with configurable gaps.
    Supports multi-row overflow and multi-monitor distribution.

    Layout logic:
    - If windowsOnScreen <= MaxPillarsPerScreen: single row of N columns
    - If windowsOnScreen > MaxPillarsPerScreen: grid with MaxPillarsPerScreen columns, multiple rows
    - Gap spacing: (N+1) gaps for N columns, (M+1) gaps for M rows

.PARAMETER WindowCount
    Total number of windows to layout

.PARAMETER Screens
    Array of screen objects from Get-ScreenTopology

.PARAMETER MaxPillarsPerScreen
    Maximum pillars (columns) per screen in a single row (default: 4)

.PARAMETER GapSize
    Pixel gap between windows and screen edges (default: 60)

.OUTPUTS
    Array of @{ X, Y, Width, Height, ScreenIndex, WindowIndex }

.EXAMPLE
    Get-PillarsLayout -WindowCount 4 -Screens $screens -MaxPillarsPerScreen 4 -GapSize 60
    # Returns 4 rectangles in a single row, evenly distributed with 60px gaps
#>
function Get-PillarsLayout {
    param(
        [Parameter(Mandatory)]
        [int]$WindowCount,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Screens,

        [int]$MaxPillarsPerScreen = 4,

        [int]$GapSize = 60
    )

    Write-LayoutLog "Get-PillarsLayout called: WindowCount=$WindowCount, ScreenCount=$($Screens.Count), MaxPillars=$MaxPillarsPerScreen, GapSize=$GapSize" -Level "DEBUG"

    if ($WindowCount -le 0) {
        Write-LayoutLog "Get-PillarsLayout: Zero or negative window count, returning empty" -Level "DEBUG"
        return @()
    }

    if (-not $Screens -or $Screens.Count -eq 0) {
        Write-LayoutLog "No screens available for Pillars layout" -Level "WARN"
        return @()
    }

    # Step 1: Distribute windows across screens
    $distribution = Get-WindowDistribution -WindowCount $WindowCount `
                                          -ScreenCount $Screens.Count `
                                          -MaxPerScreen $MaxPillarsPerScreen

    $rectangles = @()
    $windowIndex = 0

    # Step 2: For each screen, layout its assigned windows
    for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
        $screen = $Screens[$screenIdx]
        $windowsOnScreen = $distribution[$screenIdx]

        if ($windowsOnScreen -eq 0) {
            continue
        }

        # Step 3: Determine if single row or multi-row
        if ($windowsOnScreen -le $MaxPillarsPerScreen) {
            # Single row layout
            $columns = $windowsOnScreen
            $rows = 1
        } else {
            # Multi-row layout: 4 columns, multiple rows
            $columns = $MaxPillarsPerScreen
            $rows = [Math]::Ceiling($windowsOnScreen / $columns)
        }

        # Step 4: Calculate cell dimensions
        # Formula: (N+1) gaps for N columns/rows
        $totalHGaps = ($columns + 1) * $GapSize
        $totalVGaps = ($rows + 1) * $GapSize
        $cellWidth = [int](($screen.Width - $totalHGaps) / $columns)
        $cellHeight = [int](($screen.Height - $totalVGaps) / $rows)

        # Step 5: Place each window in grid
        for ($i = 0; $i -lt $windowsOnScreen; $i++) {
            # Calculate grid position (column-major order)
            $col = $i % $columns
            $row = [Math]::Floor($i / $columns)

            # Calculate pixel position
            # Formula: edge gap + (cell_index * (cell_size + gap))
            $x = $screen.Left + $GapSize + ($col * ($cellWidth + $GapSize))
            $y = $screen.Top + $GapSize + ($row * ($cellHeight + $GapSize))

            $rectangles += @{
                X = $x
                Y = $y
                Width = $cellWidth
                Height = $cellHeight
                ScreenIndex = $screenIdx
                WindowIndex = $windowIndex++
            }
        }
    }

    # Always return as array to prevent single-item unwrapping
    # Use write-output with -NoEnumerate to preserve array structure
    Write-Output $rectangles -NoEnumerate
}

# --- QUADS LAYOUT STRATEGY ---

<#
.SYNOPSIS
    Calculate Quads layout: 2x2 grid with plus-shaped gap in center.

.DESCRIPTION
    Arranges windows in a 2x2 grid pattern with a distinctive plus-shaped (+) gap
    in the center where horizontal and vertical gaps intersect.

    Layout pattern (single screen, 4 windows):
    ┌─────┐ GAP ┌─────┐
    │  1  │     │  2  │
    └─────┘     └─────┘
       GAP   +   GAP
    ┌─────┐     ┌─────┘
    │  3  │     │  4  │
    └─────┘     └─────┘

    Window placement order: Top-Left, Top-Right, Bottom-Left, Bottom-Right

    For fewer than 4 windows:
    - 1 window: Top-Left only
    - 2 windows: Top row (TL, TR)
    - 3 windows: Top row + Bottom-Left

    For more than 4 windows:
    - Overflow to additional screens (if available)
    - Each screen gets up to 4 windows in quad pattern

.PARAMETER WindowCount
    Total number of windows to layout

.PARAMETER Screens
    Array of screen objects from Get-ScreenTopology

.PARAMETER GapSize
    Pixel gap between windows and screen edges (default: 60)
    This creates the plus-shaped gap in the center

.OUTPUTS
    Array of @{ X, Y, Width, Height, ScreenIndex, WindowIndex }

.EXAMPLE
    Get-QuadsLayout -WindowCount 4 -Screens $screens -GapSize 60
    # Returns 4 rectangles in 2x2 grid with 60px plus-gap

.EXAMPLE
    Get-QuadsLayout -WindowCount 2 -Screens $screens -GapSize 60
    # Returns 2 rectangles in top row only

.NOTES
    Plus-gap calculation:
    - Each quadrant: (screen_dimension - 3*gap) / 2
    - Three gaps: left edge, center, right edge (or top, center, bottom)
    - Center gap creates the distinctive + pattern
#>
function Get-QuadsLayout {
    param(
        [Parameter(Mandatory)]
        [int]$WindowCount,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Screens,

        [int]$GapSize = 60
    )

    Write-LayoutLog "Get-QuadsLayout called: WindowCount=$WindowCount, ScreenCount=$($Screens.Count), GapSize=$GapSize" -Level "DEBUG"

    if ($WindowCount -le 0) {
        Write-LayoutLog "Get-QuadsLayout: Zero or negative window count, returning empty" -Level "DEBUG"
        return @()
    }

    if (-not $Screens -or $Screens.Count -eq 0) {
        Write-LayoutLog "No screens available for Quads layout" -Level "WARN"
        return @()
    }

    $rectangles = @()
    $windowIndex = 0
    $windowsPerQuad = 4

    # Calculate total capacity (4 windows per screen in standard quad layout)
    $totalCapacity = $Screens.Count * $windowsPerQuad

    # Handle overflow: if more windows than quad capacity, use extended grid layout
    if ($WindowCount -gt $totalCapacity) {
        Write-LayoutLog "Quads overflow: $WindowCount windows > $totalCapacity capacity, using extended grid layout" -Level "INFO"

        # Fall back to a grid layout that can handle all windows
        # Calculate optimal grid: aim for roughly 2:1 aspect ratio cells
        $windowsRemaining = $WindowCount

        for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
            if ($windowsRemaining -le 0) {
                break
            }

            $screen = $Screens[$screenIdx]

            # Calculate how many windows to place on this screen
            # Distribute evenly, with earlier screens getting any remainder
            $windowsOnThisScreen = [Math]::Ceiling($windowsRemaining / ($Screens.Count - $screenIdx))

            # Calculate grid dimensions to fit all windows
            # Try to maintain roughly square cells
            $cols = [Math]::Ceiling([Math]::Sqrt($windowsOnThisScreen * ($screen.Width / $screen.Height)))
            $cols = [Math]::Max($cols, 2)  # At least 2 columns for quad-like appearance
            $rows = [Math]::Ceiling($windowsOnThisScreen / $cols)

            Write-LayoutLog "Screen ${screenIdx}: $windowsOnThisScreen windows in ${cols}x${rows} grid" -Level "DEBUG"

            # Calculate cell dimensions with gaps
            $totalHGaps = ($cols + 1) * $GapSize
            $totalVGaps = ($rows + 1) * $GapSize
            $cellWidth = [int](($screen.Width - $totalHGaps) / $cols)
            $cellHeight = [int](($screen.Height - $totalVGaps) / $rows)

            # Place windows in grid
            for ($i = 0; $i -lt $windowsOnThisScreen; $i++) {
                $col = $i % $cols
                $row = [Math]::Floor($i / $cols)

                $x = $screen.Left + $GapSize + ($col * ($cellWidth + $GapSize))
                $y = $screen.Top + $GapSize + ($row * ($cellHeight + $GapSize))

                $rectangles += @{
                    X = $x
                    Y = $y
                    Width = $cellWidth
                    Height = $cellHeight
                    ScreenIndex = $screenIdx
                    WindowIndex = $windowIndex++
                }
            }

            $windowsRemaining -= $windowsOnThisScreen
        }

        # Always return as array to prevent single-item unwrapping
        Write-Output $rectangles -NoEnumerate
        return
    }

    # Standard quad layout (4 or fewer windows per screen)
    $windowsRemaining = $WindowCount

    for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
        if ($windowsRemaining -le 0) {
            break
        }

        $screen = $Screens[$screenIdx]

        # Determine how many windows on this screen (max 4 per quad)
        $windowsOnThisScreen = [Math]::Min($windowsRemaining, $windowsPerQuad)

        Write-LayoutLog "Screen ${screenIdx}: $windowsOnThisScreen windows in quad positions" -Level "DEBUG"

        # Plus-gap calculation:
        # Each dimension has 3 gaps: edge + center + edge
        # Two quadrants share the remaining space equally
        # Formula: (total - 3*gap) / 2
        $halfWidth = [int](($screen.Width - (3 * $GapSize)) / 2)
        $halfHeight = [int](($screen.Height - (3 * $GapSize)) / 2)

        # Define quad positions: TL, TR, BL, BR
        $quadPositions = @(
            @{ X = $screen.Left + $GapSize; Y = $screen.Top + $GapSize; Label = "TL" },
            @{ X = $screen.Left + (2 * $GapSize) + $halfWidth; Y = $screen.Top + $GapSize; Label = "TR" },
            @{ X = $screen.Left + $GapSize; Y = $screen.Top + (2 * $GapSize) + $halfHeight; Label = "BL" },
            @{ X = $screen.Left + (2 * $GapSize) + $halfWidth; Y = $screen.Top + (2 * $GapSize) + $halfHeight; Label = "BR" }
        )

        # Place windows in order: TL, TR, BL, BR
        for ($posIdx = 0; $posIdx -lt $windowsOnThisScreen; $posIdx++) {
            $rectangles += @{
                X = $quadPositions[$posIdx].X
                Y = $quadPositions[$posIdx].Y
                Width = $halfWidth
                Height = $halfHeight
                ScreenIndex = $screenIdx
                WindowIndex = $windowIndex++
            }
            Write-LayoutLog "  Placed window $($windowIndex-1) at $($quadPositions[$posIdx].Label): ($($quadPositions[$posIdx].X), $($quadPositions[$posIdx].Y))" -Level "DEBUG"
        }

        $windowsRemaining -= $windowsOnThisScreen
    }

    Write-LayoutLog "Get-QuadsLayout complete: $($rectangles.Count) rectangles calculated" -Level "DEBUG"
    # Always return as array to prevent single-item unwrapping
    Write-Output $rectangles -NoEnumerate
}

# --- CONFIGURATION MANAGEMENT ---

<#
.SYNOPSIS
    Read layout configuration from matrix_state.json.

.DESCRIPTION
    Loads layout preferences from persistent state file. Returns defaults
    if config is missing or invalid. Implements US-002 error handling pattern.

.OUTPUTS
    Hashtable with layout configuration:
    @{ Mode = 'Pillars'; MaxPillarsPerScreen = 4; GapSize = 60; PreferredScreen = 0 }

.EXAMPLE
    $config = Get-MatrixLayoutConfig
    # Returns: @{ Mode = 'Pillars'; MaxPillarsPerScreen = 4; GapSize = 60; PreferredScreen = 0 }

.NOTES
    Default configuration:
    - Mode: Pillars (vertical columns layout)
    - MaxPillarsPerScreen: 4 (max columns per screen)
    - GapSize: 60 (pixels between windows and edges)
    - PreferredScreen: 0 (primary screen)
#>
function Get-MatrixLayoutConfig {
    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    # Default configuration
    $defaultConfig = @{
        Mode = 'Pillars'
        MaxPillarsPerScreen = 4
        GapSize = 60
        PreferredScreen = 0
    }

    # Try to load existing state (US-002 pattern: JSON error handling)
    try {
        if (Test-Path $stateFilePath) {
            $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
            $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

            # Extract layout config if present
            if ($state.layout) {
                $config = @{
                    Mode = if ($state.layout.mode) { $state.layout.mode } else { $defaultConfig.Mode }
                    MaxPillarsPerScreen = if ($state.layout.maxPillarsPerScreen) { $state.layout.maxPillarsPerScreen } else { $defaultConfig.MaxPillarsPerScreen }
                    GapSize = if ($state.layout.gapSize) { $state.layout.gapSize } else { $defaultConfig.GapSize }
                    PreferredScreen = if ($state.layout.preferredScreen -ne $null) { $state.layout.preferredScreen } else { $defaultConfig.PreferredScreen }
                }
                return $config
            }
        }

        # No config found, return defaults
        return $defaultConfig
    }
    catch {
        Write-Warning "Failed to load layout config from matrix_state.json: $_"
        Write-Warning "Using default configuration"
        return $defaultConfig
    }
}

<#
.SYNOPSIS
    Write layout configuration to matrix_state.json.

.DESCRIPTION
    Persists layout preferences to state file. Uses atomic write pattern (US-001)
    to prevent corruption. Merges with existing state to preserve other data.

.PARAMETER Config
    Hashtable with layout configuration (Mode, MaxPillarsPerScreen, GapSize, PreferredScreen)

.EXAMPLE
    Set-MatrixLayoutConfig -Config @{ Mode = 'Quads'; GapSize = 80 }

.NOTES
    Implements US-001 pattern: atomic write with Move-Item -Force
    Implements US-002 pattern: try-catch on JSON operations
    Preserves existing state data (lastSlots, windows array, etc.)
#>
function Set-MatrixLayoutConfig {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $matrixDir = "$env:USERPROFILE\Documents\Matrix"
    $stateFilePath = "$matrixDir\matrix_state.json"

    try {
        # Ensure directory exists
        if (-not (Test-Path $matrixDir)) {
            New-Item -Path $matrixDir -ItemType Directory -Force | Out-Null
        }

        # Load existing state or create new (US-002 pattern)
        $state = @{}
        if (Test-Path $stateFilePath) {
            try {
                $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
                $stateObj = $stateJson | ConvertFrom-Json -ErrorAction Stop

                # Convert PSCustomObject to hashtable (preserve existing data)
                $state = @{}
                $stateObj.PSObject.Properties | ForEach-Object {
                    $state[$_.Name] = $_.Value
                }
            }
            catch {
                Write-Warning "Failed to load existing state, creating new: $_"
                $state = @{}
            }
        }

        # Update layout section with provided config
        $state.layout = @{
            mode = if ($Config.Mode) { $Config.Mode } else { 'Pillars' }
            maxPillarsPerScreen = if ($Config.MaxPillarsPerScreen) { $Config.MaxPillarsPerScreen } else { 4 }
            gapSize = if ($Config.GapSize) { $Config.GapSize } else { 60 }
            preferredScreen = if ($Config.PreferredScreen -ne $null) { $Config.PreferredScreen } else { 0 }
        }

        # Convert to JSON
        $stateJson = $state | ConvertTo-Json -Depth 10 -ErrorAction Stop

        # Atomic write pattern (US-001): write to temp file, then move
        $tempFile = [System.IO.Path]::GetTempFileName()
        $stateJson | Out-File -FilePath $tempFile -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempFile -Destination $stateFilePath -Force -ErrorAction Stop

        Write-Verbose "Layout configuration saved successfully"
    }
    catch {
        Write-Warning "Failed to save layout config to matrix_state.json: $_"
        # Clean up temp file if it exists
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

# --- MAIN ENTRY POINT ---

<#
.SYNOPSIS
    Calculate and apply window layout to Matrix Terminal windows.

.DESCRIPTION
    Main entry point for the Window Layout Engine. Takes a collection of window handles
    and arranges them using either Pillars or Quads layout strategy.

    Pillars mode: Windows arranged as vertical columns side-by-side
    Quads mode: Windows arranged in 2x2 grid with plus-shaped gap
    Auto mode: Pillars for 1-4 windows, Quads for 5+ windows

.PARAMETER WindowHandles
    Hashtable where keys are shader names (e.g., "Matrix-1") and values are
    hashtables with Handle and optionally ProcessId:
    @{ "Matrix-1" = @{ Handle = 12345; ProcessId = 789 } }

.PARAMETER Mode
    Layout strategy to use: 'Pillars', 'Quads', or 'Auto' (default)
    Auto selects Pillars for 1-4 windows, Quads for 5+ windows

.PARAMETER DryRun
    If specified, calculates and returns layout without moving windows

.OUTPUTS
    When DryRun: Array of @{ Handle, X, Y, Width, Height, ScreenIndex }
    Otherwise: $null (windows are moved as side effect)

.EXAMPLE
    Invoke-MatrixWindowLayout -WindowHandles $global:matrixWindowHandles -Mode 'Pillars'
    # Arranges all tracked windows in pillars layout

.EXAMPLE
    $layout = Invoke-MatrixWindowLayout -WindowHandles $handles -DryRun
    # Returns calculated layout without moving windows

.NOTES
    This function is the primary integration point for matrix_control.ps1,
    matrix_setup.ps1, and bluepill.ps1.

    Uses configuration from Get-MatrixLayoutConfig when Mode is not specified.
    Handles edge cases: zero windows, invalid handles, minimized windows.
#>
function Invoke-MatrixWindowLayout {
    param(
        [Parameter(Mandatory)]
        [hashtable]$WindowHandles,

        [ValidateSet('Pillars', 'Quads', 'Auto')]
        [string]$Mode = 'Auto',

        [switch]$DryRun
    )

    Write-LayoutLog "Invoke-MatrixWindowLayout called: Mode=$Mode, DryRun=$DryRun, InputHandles=$($WindowHandles.Count)" -Level "DEBUG"

    # Get valid window handles (filter out any invalid ones)
    $validWindows = @()
    $invalidCount = 0
    foreach ($name in $WindowHandles.Keys) {
        $entry = $WindowHandles[$name]
        $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }

        if ($handle -and $handle -ne [IntPtr]::Zero) {
            # Check if window still exists and is visible
            if ([WindowLayoutAPI]::IsWindowVisible($handle)) {
                # Restore if minimized
                if ([WindowLayoutAPI]::IsIconic($handle)) {
                    Write-LayoutLog "Restoring minimized window: $name" -Level "DEBUG"
                    [WindowLayoutAPI]::ShowWindow($handle, [WindowLayoutAPI]::SW_RESTORE) | Out-Null
                    Start-Sleep -Milliseconds 100
                }

                $validWindows += @{
                    Name = $name
                    Handle = $handle
                }
            } else {
                Write-LayoutLog "Filtered invalid/invisible window: $name (handle=$handle)" -Level "DEBUG"
                $invalidCount++
            }
        } else {
            Write-LayoutLog "Filtered null/zero handle: $name" -Level "DEBUG"
            $invalidCount++
        }
    }

    if ($invalidCount -gt 0) {
        Write-LayoutLog "Filtered out $invalidCount invalid window handle(s)" -Level "INFO"
    }

    $windowCount = $validWindows.Count

    if ($windowCount -eq 0) {
        Write-LayoutLog "No valid windows to layout - returning empty" -Level "INFO"
        return @()
    }

    # Get configuration
    $config = Get-MatrixLayoutConfig

    # Determine effective mode
    $effectiveMode = $Mode
    if ($effectiveMode -eq 'Auto') {
        # Use config mode, or default to Pillars for 1-4 windows, Quads for 5+
        if ($config.Mode -and $config.Mode -ne 'Auto') {
            $effectiveMode = $config.Mode
        }
        else {
            $effectiveMode = if ($windowCount -le 4) { 'Pillars' } else { 'Quads' }
        }
    }

    # Get screen topology
    $screens = Get-ScreenTopology

    if ($screens.Count -eq 0) {
        Write-Warning "No screens detected"
        return @()
    }

    # Get gap size from config
    $gapSize = if ($config.GapSize) { $config.GapSize } else { 60 }

    # Calculate layout based on mode
    $layout = switch ($effectiveMode) {
        'Pillars' {
            $maxPillars = if ($config.MaxPillarsPerScreen) { $config.MaxPillarsPerScreen } else { 4 }
            Get-PillarsLayout -WindowCount $windowCount -Screens $screens -MaxPillarsPerScreen $maxPillars -GapSize $gapSize
        }
        'Quads' {
            Get-QuadsLayout -WindowCount $windowCount -Screens $screens -GapSize $gapSize
        }
    }

    if (-not $layout -or $layout.Count -eq 0) {
        Write-Warning "Layout calculation returned no positions"
        return @()
    }

    # Sort windows by name to ensure consistent ordering (Matrix-1 before Matrix-2, etc.)
    $sortedWindows = $validWindows | Sort-Object { $_.Name }

    # Build result with handle-to-position mapping
    $result = @()
    for ($i = 0; $i -lt [Math]::Min($sortedWindows.Count, $layout.Count); $i++) {
        $window = $sortedWindows[$i]
        $position = $layout[$i]

        $result += @{
            Name = $window.Name
            Handle = $window.Handle
            X = $position.X
            Y = $position.Y
            Width = $position.Width
            Height = $position.Height
            ScreenIndex = $position.ScreenIndex
        }
    }

    # Apply layout if not dry run
    if (-not $DryRun) {
        foreach ($item in $result) {
            try {
                [WindowLayoutAPI]::SetWindowPos(
                    $item.Handle,
                    [IntPtr]::Zero,
                    $item.X,
                    $item.Y,
                    $item.Width,
                    $item.Height,
                    ([WindowLayoutAPI]::SWP_NOZORDER -bor [WindowLayoutAPI]::SWP_SHOWWINDOW)
                ) | Out-Null

                Write-Verbose "Positioned $($item.Name) at ($($item.X), $($item.Y)) size $($item.Width)x$($item.Height)"
            }
            catch {
                Write-Warning "Failed to position $($item.Name): $_"
            }
        }
    }

    return $result
}

<#
.SYNOPSIS
    Get the calculated layout for a given window count without window handles.

.DESCRIPTION
    Utility function to preview layout calculations. Useful for testing
    and displaying layout information in the UI.

.PARAMETER WindowCount
    Number of windows to calculate layout for

.PARAMETER Mode
    Layout strategy: 'Pillars' or 'Quads'

.PARAMETER Screens
    Optional array of screen objects. If not provided, uses Get-ScreenTopology

.OUTPUTS
    Array of @{ X, Y, Width, Height, ScreenIndex, WindowIndex }

.EXAMPLE
    Get-MatrixWindowLayout -WindowCount 4 -Mode 'Pillars'
    # Returns 4 rectangle positions in pillars layout
#>
function Get-MatrixWindowLayout {
    param(
        [Parameter(Mandatory)]
        [int]$WindowCount,

        [ValidateSet('Pillars', 'Quads')]
        [string]$Mode = 'Pillars',

        [array]$Screens
    )

    if (-not $Screens -or $Screens.Count -eq 0) {
        $Screens = Get-ScreenTopology
    }

    $config = Get-MatrixLayoutConfig
    $gapSize = if ($config.GapSize) { $config.GapSize } else { 60 }

    switch ($Mode) {
        'Pillars' {
            $maxPillars = if ($config.MaxPillarsPerScreen) { $config.MaxPillarsPerScreen } else { 4 }
            Get-PillarsLayout -WindowCount $WindowCount -Screens $Screens -MaxPillarsPerScreen $maxPillars -GapSize $gapSize
        }
        'Quads' {
            Get-QuadsLayout -WindowCount $WindowCount -Screens $Screens -GapSize $gapSize
        }
    }
}
