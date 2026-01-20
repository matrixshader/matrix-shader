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

        # Sort screens: Primary first, then left-to-right by position
        # This ensures Windows' actual primary monitor is always index 0
        $sorted = $topology | Sort-Object -Property @(
            @{Expression = {-[int]$_.IsPrimary}; Ascending = $true},  # Primary first (IsPrimary=true sorts before false)
            @{Expression = {$_.Left}; Ascending = $true}               # Then left-to-right
        )

        # Re-index after sorting so Index matches position in array
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $sorted[$i].Index = $i
        }

        Write-LayoutLog "Screen topology: $($sorted.Count) screens, primary at index 0" -Level "DEBUG"
        return $sorted
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

<#
.SYNOPSIS
    Distribute windows with user-controlled primary screen allocation.

.DESCRIPTION
    Distributes windows across screens, respecting the WindowsOnPrimary setting.
    Primary screen (index 0) gets the specified number of windows first,
    then overflow goes to secondary screens.

    Examples:
    - WindowsOnPrimary=3, Total=5: Primary gets 3, Secondary gets 2
    - WindowsOnPrimary=null (Auto): All windows on primary (single-screen behavior)
    - WindowsOnPrimary=0: All windows on secondary screens

.PARAMETER WindowCount
    Total number of windows to distribute

.PARAMETER ScreenCount
    Number of available screens

.PARAMETER WindowsOnPrimary
    Number of windows to place on primary screen (index 0).
    - null or -1: Auto mode - all windows on primary (backward compatible)
    - 0: All windows on secondary screens
    - N: Exactly N windows on primary, rest overflow to secondary

.PARAMETER MaxPerScreen
    Maximum windows allowed per screen (default: 4)

.OUTPUTS
    Array of integers representing window count per screen

.EXAMPLE
    Get-WindowDistributionWithPrimary -WindowCount 5 -ScreenCount 2 -WindowsOnPrimary 3 -MaxPerScreen 4
    # Returns: @(3, 2) - 3 on primary, 2 on secondary

.EXAMPLE
    Get-WindowDistributionWithPrimary -WindowCount 4 -ScreenCount 2 -WindowsOnPrimary $null -MaxPerScreen 4
    # Returns: @(4, 0) - Auto mode, all on primary
#>
function Get-WindowDistributionWithPrimary {
    param(
        [Parameter(Mandatory)]
        [int]$WindowCount,

        [Parameter(Mandatory)]
        [int]$ScreenCount,

        [object]$WindowsOnPrimary = $null,  # Use [object] to allow $null, or an integer

        [int]$MaxPerScreen = 4
    )

    $typeStr = if ($null -eq $WindowsOnPrimary) { "null" } else { $WindowsOnPrimary.GetType().Name }
    Write-LayoutLog "Get-WindowDistributionWithPrimary: WindowCount=$WindowCount, ScreenCount=$ScreenCount, WindowsOnPrimary=$WindowsOnPrimary (type=$typeStr)" -Level "DEBUG"

    if ($WindowCount -le 0) {
        return @(0) * $ScreenCount
    }

    if ($ScreenCount -le 0) {
        Write-Warning "Invalid ScreenCount: $ScreenCount"
        return @()
    }

    # Initialize distribution array
    $distribution = @(0) * $ScreenCount

    # Single screen - put everything there
    if ($ScreenCount -eq 1) {
        $distribution[0] = $WindowCount
        Write-LayoutLog "Single screen: all $WindowCount windows on screen 0" -Level "DEBUG"
        return $distribution
    }

    # Multi-screen distribution
    # Auto mode (null): Balanced distribution with max 4 per screen
    # User-specified: Put exactly N on primary, rest on secondary

    if ($null -eq $WindowsOnPrimary) {
        # AUTO MODE: Balanced distribution across screens
        # Divide evenly, primary gets remainder (e.g., 5 windows / 2 screens = 3 + 2)
        $base = [Math]::Floor($WindowCount / $ScreenCount)
        $remainder = $WindowCount % $ScreenCount

        for ($i = 0; $i -lt $ScreenCount; $i++) {
            # Each screen gets base count, first screens get +1 for remainder
            $count = $base
            if ($i -lt $remainder) {
                $count++
            }
            # Cap at MaxPerScreen
            $distribution[$i] = [Math]::Min($count, $MaxPerScreen)
        }

        Write-LayoutLog "Auto mode: balanced distribution $($distribution -join ', ') (base=$base, remainder=$remainder)" -Level "DEBUG"
    }
    else {
        # User-specified primary allocation
        $primaryCount = [Math]::Max(0, [Math]::Min([int]$WindowsOnPrimary, $WindowCount))
        $distribution[0] = $primaryCount
        $remaining = $WindowCount - $primaryCount

        Write-LayoutLog "User mode: primary gets $primaryCount (user specified $WindowsOnPrimary), $remaining remaining" -Level "DEBUG"

        # Distribute remaining windows to secondary screens (index 1+)
        if ($remaining -gt 0 -and $ScreenCount -gt 1) {
            $secondaryScreens = $ScreenCount - 1
            $perSecondary = [Math]::Ceiling($remaining / $secondaryScreens)
            $perSecondary = [Math]::Min($perSecondary, $MaxPerScreen)

            for ($i = 1; $i -lt $ScreenCount; $i++) {
                if ($remaining -le 0) { break }
                $windowsForThisScreen = [Math]::Min($remaining, $perSecondary)
                $distribution[$i] = $windowsForThisScreen
                $remaining -= $windowsForThisScreen
            }
        }
    }

    Write-LayoutLog "Final distribution: $($distribution -join ', ')" -Level "DEBUG"
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

        [int]$GapSize = 60,

        [object]$WindowsOnPrimary = $null  # Use [object] to allow $null
    )

    # Enforce minimum gap to ensure visible separation between windows
    $GapSize = [Math]::Max($GapSize, 30)

    Write-LayoutLog "Get-PillarsLayout called: WindowCount=$WindowCount, ScreenCount=$($Screens.Count), MaxPillars=$MaxPillarsPerScreen, GapSize=$GapSize, WindowsOnPrimary=$WindowsOnPrimary" -Level "DEBUG"

    if ($WindowCount -le 0) {
        Write-LayoutLog "Get-PillarsLayout: Zero or negative window count, returning empty" -Level "DEBUG"
        return @()
    }

    if (-not $Screens -or $Screens.Count -eq 0) {
        Write-LayoutLog "No screens available for Pillars layout" -Level "WARN"
        return @()
    }

    # Step 1: Distribute windows across screens (respects WindowsOnPrimary setting)
    $distribution = Get-WindowDistributionWithPrimary -WindowCount $WindowCount `
                                                      -ScreenCount $Screens.Count `
                                                      -WindowsOnPrimary $WindowsOnPrimary `
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

        # Step 3: Calculate pillar dimensions based on ACTUAL window count
        # Pillars fill the available space while maintaining tall aspect ratio
        $columns = [Math]::Min($windowsOnScreen, $MaxPillarsPerScreen)
        $rows = 1

        # If more windows than fit in one row, use multi-row
        if ($windowsOnScreen -gt $MaxPillarsPerScreen) {
            $columns = $MaxPillarsPerScreen
            $rows = [Math]::Ceiling($windowsOnScreen / $columns)
        }

        # Step 4: Calculate cell dimensions to FILL the screen
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

        [int]$GapSize = 60,

        [object]$WindowsOnPrimary = $null  # Use [object] to allow $null
    )

    # Enforce minimum gap to ensure visible separation between windows
    $GapSize = [Math]::Max($GapSize, 30)

    Write-LayoutLog "Get-QuadsLayout called: WindowCount=$WindowCount, ScreenCount=$($Screens.Count), GapSize=$GapSize, WindowsOnPrimary=$WindowsOnPrimary" -Level "DEBUG"

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

    # Get distribution using WindowsOnPrimary setting
    $distribution = Get-WindowDistributionWithPrimary -WindowCount $WindowCount `
                                                      -ScreenCount $Screens.Count `
                                                      -WindowsOnPrimary $WindowsOnPrimary `
                                                      -MaxPerScreen $windowsPerQuad

    # Calculate total capacity (4 windows per screen in standard quad layout)
    $totalCapacity = $Screens.Count * $windowsPerQuad

    # Handle overflow: if more windows than quad capacity, use extended grid layout
    if ($WindowCount -gt $totalCapacity) {
        Write-LayoutLog "Quads overflow: $WindowCount windows > $totalCapacity capacity, using extended grid layout" -Level "INFO"

        # Fall back to a grid layout that can handle all windows
        for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
            $windowsOnThisScreen = $distribution[$screenIdx]
            if ($windowsOnThisScreen -le 0) {
                continue
            }

            $screen = $Screens[$screenIdx]

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
        }

        # Always return as array to prevent single-item unwrapping
        Write-Output $rectangles -NoEnumerate
        return
    }

    # Standard quad layout (4 or fewer windows per screen)
    # Use pre-computed distribution from Get-WindowDistributionWithPrimary
    for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
        $windowsOnThisScreen = $distribution[$screenIdx]
        if ($windowsOnThisScreen -le 0) {
            continue
        }

        $screen = $Screens[$screenIdx]

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
        WindowsOnPrimary = $null  # null = Auto (all windows on primary for single-screen behavior)
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
                    WindowsOnPrimary = if ($null -ne $state.layout.windowsOnPrimary) { $state.layout.windowsOnPrimary } else { $defaultConfig.WindowsOnPrimary }
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
            windowsOnPrimary = $Config.WindowsOnPrimary  # null = Auto (all on primary)
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

    # Get gap size and windowsOnPrimary from config
    $gapSize = if ($config.GapSize) { $config.GapSize } else { 60 }
    $windowsOnPrimary = $config.WindowsOnPrimary  # null = Auto (all on primary)

    # Calculate layout based on mode
    $layout = switch ($effectiveMode) {
        'Pillars' {
            $maxPillars = if ($config.MaxPillarsPerScreen) { $config.MaxPillarsPerScreen } else { 4 }
            Get-PillarsLayout -WindowCount $windowCount -Screens $screens -MaxPillarsPerScreen $maxPillars -GapSize $gapSize -WindowsOnPrimary $windowsOnPrimary
        }
        'Quads' {
            Get-QuadsLayout -WindowCount $windowCount -Screens $screens -GapSize $gapSize -WindowsOnPrimary $windowsOnPrimary
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

# --- POSITION TRACKING FOR DRAG DETECTION ---

# Module-level state for position tracking
$script:LastKnownPositions = @{}
$script:DragThreshold = 50  # Minimum pixels of movement to consider a drag

<#
.SYNOPSIS
    Get current window positions for a set of window handles.

.DESCRIPTION
    Uses GetWindowRect API to retrieve current X, Y, Width, Height for each window.
    Returns a hashtable keyed by handle (as string) with position data.

.PARAMETER WindowHandles
    Array of window handle IntPtrs

.OUTPUTS
    Hashtable @{ "handle" = @{ X, Y, Width, Height } }

.EXAMPLE
    $positions = Get-WindowPositions -WindowHandles @($hwnd1, $hwnd2)
#>
function Get-WindowPositions {
    param(
        [Parameter(Mandatory)]
        [array]$WindowHandles
    )

    $positions = @{}

    foreach ($handle in $WindowHandles) {
        if (-not $handle -or $handle -eq [IntPtr]::Zero) { continue }

        try {
            $rect = New-Object WindowLayoutAPI+RECT
            if ([WindowLayoutAPI]::GetWindowRect($handle, [ref]$rect)) {
                $positions[$handle.ToString()] = @{
                    X = $rect.Left
                    Y = $rect.Top
                    Width = $rect.Right - $rect.Left
                    Height = $rect.Bottom - $rect.Top
                }
            }
        }
        catch {
            Write-LayoutLog "Failed to get position for handle $handle : $_" -Level "DEBUG"
        }
    }

    return $positions
}

<#
.SYNOPSIS
    Initialize position tracking for a set of windows.

.DESCRIPTION
    Captures current window positions and stores them as the baseline
    for drag detection. Should be called when windows are first positioned.

.PARAMETER WindowHandles
    Array of window handle IntPtrs to track

.EXAMPLE
    Initialize-PositionTracking -WindowHandles @($hwnd1, $hwnd2)
#>
function Initialize-PositionTracking {
    param(
        [Parameter(Mandatory)]
        [array]$WindowHandles
    )

    $script:LastKnownPositions = Get-WindowPositions -WindowHandles $WindowHandles
    Write-LayoutLog "Initialized position tracking for $($WindowHandles.Count) windows" -Level "DEBUG"
}

<#
.SYNOPSIS
    Detect if any window has been dragged since last check.

.DESCRIPTION
    Compares current window positions to last known positions.
    Returns $true if any window has moved more than the drag threshold.

.PARAMETER WindowHandles
    Array of window handle IntPtrs to check

.OUTPUTS
    $true if drag detected, $false otherwise

.EXAMPLE
    if (Test-WindowDragDetected -WindowHandles @($hwnd1, $hwnd2)) {
        # Window was dragged, reposition all
    }
#>
function Test-WindowDragDetected {
    param(
        [Parameter(Mandatory)]
        [array]$WindowHandles
    )

    if ($script:LastKnownPositions.Count -eq 0) {
        # No baseline - initialize and return false
        Initialize-PositionTracking -WindowHandles $WindowHandles
        return $false
    }

    $currentPositions = Get-WindowPositions -WindowHandles $WindowHandles

    foreach ($handleKey in $currentPositions.Keys) {
        if (-not $script:LastKnownPositions.ContainsKey($handleKey)) {
            # New window appeared - treat as drag event
            Write-LayoutLog "New window detected: $handleKey" -Level "DEBUG"
            return $true
        }

        $current = $currentPositions[$handleKey]
        $last = $script:LastKnownPositions[$handleKey]

        $deltaX = [Math]::Abs($current.X - $last.X)
        $deltaY = [Math]::Abs($current.Y - $last.Y)

        if ($deltaX -gt $script:DragThreshold -or $deltaY -gt $script:DragThreshold) {
            Write-LayoutLog "Drag detected on $handleKey : delta ($deltaX, $deltaY)" -Level "DEBUG"
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Update the last known positions after repositioning.

.DESCRIPTION
    Should be called after Invoke-MatrixWindowLayout to update the baseline.

.PARAMETER WindowHandles
    Array of window handle IntPtrs

.EXAMPLE
    Update-PositionTracking -WindowHandles @($hwnd1, $hwnd2)
#>
function Update-PositionTracking {
    param(
        [Parameter(Mandatory)]
        [array]$WindowHandles
    )

    $script:LastKnownPositions = Get-WindowPositions -WindowHandles $WindowHandles
    Write-LayoutLog "Updated position tracking for $($WindowHandles.Count) windows" -Level "DEBUG"
}

# --- POSITION PERSISTENCE ---

<#
.SYNOPSIS
    Save window positions to matrix_state.json for later restoration.

.DESCRIPTION
    Persists current window positions (X, Y, Width, Height) keyed by shader name.
    Uses atomic write pattern to prevent corruption.

.PARAMETER WindowInfo
    Array of @{ Handle, Slot } objects from Get-MatrixWindowInfo

.EXAMPLE
    $windowInfo = Get-MatrixWindowInfo
    Save-WindowPositions -WindowInfo $windowInfo
#>
function Save-WindowPositions {
    param(
        [Parameter(Mandatory)]
        [array]$WindowInfo
    )

    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    try {
        # Load existing state
        $state = @{}
        if (Test-Path $stateFilePath) {
            try {
                $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
                $stateObj = $stateJson | ConvertFrom-Json -ErrorAction Stop
                $stateObj.PSObject.Properties | ForEach-Object {
                    $state[$_.Name] = $_.Value
                }
            }
            catch {
                Write-LayoutLog "Failed to load existing state for position save: $_" -Level "WARN"
            }
        }

        # Build window positions
        $positions = @{}
        foreach ($win in $WindowInfo) {
            if (-not $win.Handle -or $win.Handle -eq [IntPtr]::Zero) { continue }

            try {
                $rect = New-Object WindowLayoutAPI+RECT
                if ([WindowLayoutAPI]::GetWindowRect($win.Handle, [ref]$rect)) {
                    $shaderName = "Matrix-$($win.Slot)"
                    $positions[$shaderName] = @{
                        x = $rect.Left
                        y = $rect.Top
                        width = $rect.Right - $rect.Left
                        height = $rect.Bottom - $rect.Top
                    }
                    Write-LayoutLog "Saved position for $shaderName : ($($rect.Left), $($rect.Top)) $($rect.Right - $rect.Left)x$($rect.Bottom - $rect.Top)" -Level "DEBUG"
                }
            }
            catch {
                Write-LayoutLog "Failed to get position for slot $($win.Slot): $_" -Level "DEBUG"
            }
        }

        # Update state
        $state.windowPositions = $positions
        $state.positionsSavedAt = (Get-Date).ToString("o")

        # Atomic write
        $stateJson = $state | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $tempFile = [System.IO.Path]::GetTempFileName()
        $stateJson | Out-File -FilePath $tempFile -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempFile -Destination $stateFilePath -Force -ErrorAction Stop

        Write-LayoutLog "Saved positions for $($positions.Count) windows" -Level "INFO"
        return $true
    }
    catch {
        Write-LayoutLog "Failed to save window positions: $_" -Level "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    Restore window positions from matrix_state.json.

.DESCRIPTION
    Reads saved positions and applies them to windows.
    Returns $true if positions were restored, $false if no saved positions or error.

.PARAMETER WindowInfo
    Array of @{ Handle, Slot } objects from Get-MatrixWindowInfo

.OUTPUTS
    $true if restored, $false otherwise

.EXAMPLE
    $windowInfo = Get-MatrixWindowInfo
    if (Restore-WindowPositions -WindowInfo $windowInfo) {
        Write-Host "Restored saved positions"
    } else {
        # Fall back to layout engine
        Position-MatrixWindows
    }
#>
function Restore-WindowPositions {
    param(
        [Parameter(Mandatory)]
        [array]$WindowInfo
    )

    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    try {
        if (-not (Test-Path $stateFilePath)) {
            Write-LayoutLog "No state file for position restore" -Level "DEBUG"
            return $false
        }

        $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.windowPositions) {
            Write-LayoutLog "No saved positions in state file" -Level "DEBUG"
            return $false
        }

        $restoredCount = 0
        foreach ($win in $WindowInfo) {
            $shaderName = "Matrix-$($win.Slot)"

            # Check if we have saved position for this shader
            $savedPos = $state.windowPositions.$shaderName
            if (-not $savedPos) {
                Write-LayoutLog "No saved position for $shaderName" -Level "DEBUG"
                continue
            }

            try {
                [WindowLayoutAPI]::SetWindowPos(
                    $win.Handle,
                    [IntPtr]::Zero,
                    [int]$savedPos.x,
                    [int]$savedPos.y,
                    [int]$savedPos.width,
                    [int]$savedPos.height,
                    ([WindowLayoutAPI]::SWP_NOZORDER -bor [WindowLayoutAPI]::SWP_SHOWWINDOW)
                ) | Out-Null

                Write-LayoutLog "Restored position for $shaderName : ($($savedPos.x), $($savedPos.y)) $($savedPos.width)x$($savedPos.height)" -Level "DEBUG"
                $restoredCount++
            }
            catch {
                Write-LayoutLog "Failed to restore position for $shaderName : $_" -Level "WARN"
            }
        }

        if ($restoredCount -gt 0) {
            Write-LayoutLog "Restored positions for $restoredCount windows" -Level "INFO"
            return $true
        }
        else {
            Write-LayoutLog "No positions were restored" -Level "DEBUG"
            return $false
        }
    }
    catch {
        Write-LayoutLog "Failed to restore window positions: $_" -Level "ERROR"
        return $false
    }
}

# --- USAGE TRACKING SYSTEM ---
# Phase 2: Track window usage for intelligent bump decisions

# Module-level state for usage tracking
$script:UsageTrackingData = @{}
$script:UsageTrackingStateFile = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"
$script:FocusStartTimes = @{}  # Track when each window gained focus
$script:UsageHalfLifeMinutes = 30  # Recency score half-life

<#
.SYNOPSIS
    Load usage tracking data from matrix_state.json.

.DESCRIPTION
    Reads the usageTracking section from the persistent state file.
    Returns an empty hashtable if no data exists or on error.
    Implements US-002 error handling pattern.

.OUTPUTS
    Hashtable of usage tracking data keyed by profile name

.EXAMPLE
    $usageData = Import-UsageTrackingData
#>
function Import-UsageTrackingData {
    try {
        if (-not (Test-Path $script:UsageTrackingStateFile)) {
            Write-LayoutLog "No state file for usage tracking, starting fresh" -Level "DEBUG"
            return @{}
        }

        $stateJson = Get-Content -Path $script:UsageTrackingStateFile -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.usageTracking) {
            Write-LayoutLog "No usageTracking section in state file" -Level "DEBUG"
            return @{}
        }

        # Convert PSCustomObject to hashtable
        $usageData = @{}
        $state.usageTracking.PSObject.Properties | ForEach-Object {
            $profileName = $_.Name
            $data = $_.Value
            $usageData[$profileName] = @{
                lastFocusTime = if ($data.lastFocusTime) { [DateTime]::Parse($data.lastFocusTime) } else { [DateTime]::MinValue }
                focusDurationMs = if ($null -ne $data.focusDurationMs) { [int]$data.focusDurationMs } else { 0 }
                focusCount = if ($null -ne $data.focusCount) { [int]$data.focusCount } else { 0 }
                usageScore = if ($null -ne $data.usageScore) { [double]$data.usageScore } else { 0.0 }
                isPriorityLocked = if ($null -ne $data.isPriorityLocked) { [bool]$data.isPriorityLocked } else { $false }
            }
        }

        Write-LayoutLog "Loaded usage tracking data for $($usageData.Count) profiles" -Level "DEBUG"
        return $usageData
    }
    catch {
        Write-LayoutLog "Failed to load usage tracking data: $_" -Level "WARN"
        return @{}
    }
}

<#
.SYNOPSIS
    Save usage tracking data to matrix_state.json.

.DESCRIPTION
    Persists usage tracking data to state file. Uses atomic write pattern (US-001)
    to prevent corruption. Merges with existing state to preserve other data.

.PARAMETER UsageData
    Hashtable of usage tracking data keyed by profile name

.EXAMPLE
    Export-UsageTrackingData -UsageData $script:UsageTrackingData

.NOTES
    Implements US-001 pattern: atomic write with Move-Item -Force
    Implements US-002 pattern: try-catch on JSON operations
#>
function Export-UsageTrackingData {
    param(
        [Parameter(Mandatory)]
        [hashtable]$UsageData
    )

    $matrixDir = "$env:USERPROFILE\Documents\Matrix"

    try {
        # Ensure directory exists
        if (-not (Test-Path $matrixDir)) {
            New-Item -Path $matrixDir -ItemType Directory -Force | Out-Null
        }

        # Load existing state or create new (US-002 pattern)
        $state = @{}
        if (Test-Path $script:UsageTrackingStateFile) {
            try {
                $stateJson = Get-Content -Path $script:UsageTrackingStateFile -Raw -ErrorAction Stop
                $stateObj = $stateJson | ConvertFrom-Json -ErrorAction Stop

                # Convert PSCustomObject to hashtable (preserve existing data)
                $stateObj.PSObject.Properties | ForEach-Object {
                    $state[$_.Name] = $_.Value
                }
            }
            catch {
                Write-LayoutLog "Failed to load existing state for usage export, creating new: $_" -Level "WARN"
            }
        }

        # Convert usage data to serializable format
        $usageTracking = @{}
        foreach ($profileName in $UsageData.Keys) {
            $data = $UsageData[$profileName]
            $usageTracking[$profileName] = @{
                lastFocusTime = $data.lastFocusTime.ToString("o")
                focusDurationMs = $data.focusDurationMs
                focusCount = $data.focusCount
                usageScore = [Math]::Round($data.usageScore, 4)
                isPriorityLocked = $data.isPriorityLocked
            }
        }

        $state.usageTracking = $usageTracking

        # Convert to JSON
        $stateJson = $state | ConvertTo-Json -Depth 10 -ErrorAction Stop

        # Atomic write pattern (US-001): write to temp file, then move
        $tempFile = [System.IO.Path]::GetTempFileName()
        $stateJson | Out-File -FilePath $tempFile -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempFile -Destination $script:UsageTrackingStateFile -Force -ErrorAction Stop

        Write-LayoutLog "Saved usage tracking data for $($UsageData.Count) profiles" -Level "DEBUG"
    }
    catch {
        Write-LayoutLog "Failed to save usage tracking data: $_" -Level "ERROR"
        # Clean up temp file if it exists
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Initialize usage tracking system.

.DESCRIPTION
    Loads persisted usage data and sets up module-level state.
    Should be called once when WindowLayoutEngine is loaded.

.EXAMPLE
    Initialize-UsageTracking
#>
function Initialize-UsageTracking {
    $script:UsageTrackingData = Import-UsageTrackingData
    $script:FocusStartTimes = @{}
    Write-LayoutLog "Usage tracking initialized with $($script:UsageTrackingData.Count) profiles" -Level "INFO"
}

<#
.SYNOPSIS
    Update usage tracking when window gains or loses focus.

.DESCRIPTION
    Tracks focus events for windows. On Focus event, records start time.
    On Blur event, calculates duration and updates tracking data.
    Automatically recalculates usage scores after updates.

.PARAMETER ProfileName
    The profile/shader name (e.g., "Matrix-1", "Matrix-3")

.PARAMETER EventType
    The event type: "Focus" (gained focus) or "Blur" (lost focus)

.EXAMPLE
    Update-WindowUsage -ProfileName "Matrix-3" -EventType "Focus"
    # Later when window loses focus:
    Update-WindowUsage -ProfileName "Matrix-3" -EventType "Blur"
#>
function Update-WindowUsage {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [ValidateSet('Focus', 'Blur')]
        [string]$EventType
    )

    $now = Get-Date

    # Ensure profile exists in tracking data
    if (-not $script:UsageTrackingData.ContainsKey($ProfileName)) {
        $script:UsageTrackingData[$ProfileName] = @{
            lastFocusTime = [DateTime]::MinValue
            focusDurationMs = 0
            focusCount = 0
            usageScore = 0.0
            isPriorityLocked = $false
        }
    }

    $profileData = $script:UsageTrackingData[$ProfileName]

    switch ($EventType) {
        'Focus' {
            # Record focus start time
            $script:FocusStartTimes[$ProfileName] = $now
            $profileData.lastFocusTime = $now
            $profileData.focusCount++
            Write-LayoutLog "Focus gained: $ProfileName (count: $($profileData.focusCount))" -Level "DEBUG"
        }
        'Blur' {
            # Calculate focus duration
            if ($script:FocusStartTimes.ContainsKey($ProfileName)) {
                $focusStart = $script:FocusStartTimes[$ProfileName]
                $durationMs = ($now - $focusStart).TotalMilliseconds
                $profileData.focusDurationMs += [int]$durationMs
                $script:FocusStartTimes.Remove($ProfileName)
                Write-LayoutLog "Focus lost: $ProfileName (duration: ${durationMs}ms, total: $($profileData.focusDurationMs)ms)" -Level "DEBUG"
            }
        }
    }

    # Update usage score
    Update-UsageScore -ProfileName $ProfileName

    # Persist to file (debounced - only save if significant time passed)
    # For now, save on every update. In production, consider debouncing.
    Export-UsageTrackingData -UsageData $script:UsageTrackingData
}

<#
.SYNOPSIS
    Calculate the usage score for a specific profile.

.DESCRIPTION
    Computes usage score based on:
    - focusScore (0.4 weight): Normalized duration of time spent focused
    - recencyScore (0.3 weight): Exponential decay from last focus (30-min half-life)
    - frequencyScore (0.3 weight): How often window was focused (normalized)

.PARAMETER ProfileName
    The profile/shader name to calculate score for

.NOTES
    Formula: usageScore = (focusScore * 0.4) + (recencyScore * 0.3) + (frequencyScore * 0.3)
#>
function Update-UsageScore {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    if (-not $script:UsageTrackingData.ContainsKey($ProfileName)) {
        return
    }

    $profileData = $script:UsageTrackingData[$ProfileName]
    $now = Get-Date

    # Calculate focusScore (normalized duration, 0-1)
    # Normalize against 1 hour of focus time as "maximum"
    $maxFocusDurationMs = 3600000  # 1 hour in ms
    $focusScore = [Math]::Min(1.0, $profileData.focusDurationMs / $maxFocusDurationMs)

    # Calculate recencyScore (exponential decay, 0-1)
    # Half-life of 30 minutes: after 30 min, score = 0.5; after 60 min, score = 0.25
    if ($profileData.lastFocusTime -eq [DateTime]::MinValue) {
        $recencyScore = 0.0
    }
    else {
        $minutesSinceLastFocus = ($now - $profileData.lastFocusTime).TotalMinutes
        $recencyScore = [Math]::Pow(0.5, $minutesSinceLastFocus / $script:UsageHalfLifeMinutes)
    }

    # Calculate frequencyScore (normalized focus count, 0-1)
    # Normalize against 20 focus events as "high frequency"
    $maxFocusCount = 20
    $frequencyScore = [Math]::Min(1.0, $profileData.focusCount / $maxFocusCount)

    # Combine scores with weights
    $usageScore = ($focusScore * 0.4) + ($recencyScore * 0.3) + ($frequencyScore * 0.3)

    # Priority locked windows get maximum score (never bumped)
    if ($profileData.isPriorityLocked) {
        $usageScore = 999.0
    }

    $profileData.usageScore = $usageScore

    Write-LayoutLog "Updated score for $ProfileName : focus=$([Math]::Round($focusScore, 3)), recency=$([Math]::Round($recencyScore, 3)), freq=$([Math]::Round($frequencyScore, 3)), total=$([Math]::Round($usageScore, 4))" -Level "DEBUG"
}

<#
.SYNOPSIS
    Get usage data for a specific window/profile.

.DESCRIPTION
    Returns the usage tracking data for a profile, or default values if not tracked.

.PARAMETER ProfileName
    The profile/shader name (e.g., "Matrix-3")

.OUTPUTS
    Hashtable with lastFocusTime, focusDurationMs, focusCount, usageScore, isPriorityLocked

.EXAMPLE
    $usage = Get-WindowUsageData -ProfileName "Matrix-3"
    Write-Host "Usage score: $($usage.usageScore)"
#>
function Get-WindowUsageData {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    if ($script:UsageTrackingData.ContainsKey($ProfileName)) {
        return $script:UsageTrackingData[$ProfileName]
    }

    # Return default values for untracked profile
    return @{
        lastFocusTime = [DateTime]::MinValue
        focusDurationMs = 0
        focusCount = 0
        usageScore = 0.0
        isPriorityLocked = $false
    }
}

<#
.SYNOPSIS
    Get the least-used window on a specific monitor.

.DESCRIPTION
    Returns the profile name of the window with the lowest usage score
    on the specified monitor. Optionally excludes priority-locked windows.

.PARAMETER MonitorIndex
    The monitor index to search on

.PARAMETER ExcludePriorityLocked
    If set, excludes windows marked as priority locked

.PARAMETER WindowsOnMonitor
    Array of profile names currently on the monitor. If not provided,
    returns the least-used window across all tracked windows.

.OUTPUTS
    String - The profile name of the least-used window, or $null if none found

.EXAMPLE
    $leastUsed = Get-LeastUsedWindow -MonitorIndex 0 -ExcludePriorityLocked
    # Returns: "Matrix-3" (the least recently used window on monitor 0)
#>
function Get-LeastUsedWindow {
    param(
        [int]$MonitorIndex = 0,

        [switch]$ExcludePriorityLocked,

        [array]$WindowsOnMonitor = @()
    )

    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    # If specific windows provided, filter to those
    $candidates = @()
    if ($WindowsOnMonitor.Count -gt 0) {
        foreach ($profileName in $WindowsOnMonitor) {
            if ($script:UsageTrackingData.ContainsKey($profileName)) {
                $data = $script:UsageTrackingData[$profileName]

                # Skip priority-locked if requested
                if ($ExcludePriorityLocked -and $data.isPriorityLocked) {
                    continue
                }

                $candidates += @{
                    ProfileName = $profileName
                    UsageScore = $data.usageScore
                }
            }
            else {
                # Untracked window - lowest score (0)
                $candidates += @{
                    ProfileName = $profileName
                    UsageScore = 0.0
                }
            }
        }
    }
    else {
        # Use all tracked windows
        foreach ($profileName in $script:UsageTrackingData.Keys) {
            $data = $script:UsageTrackingData[$profileName]

            # Skip priority-locked if requested
            if ($ExcludePriorityLocked -and $data.isPriorityLocked) {
                continue
            }

            $candidates += @{
                ProfileName = $profileName
                UsageScore = $data.usageScore
            }
        }
    }

    if ($candidates.Count -eq 0) {
        Write-LayoutLog "No candidate windows for least-used selection (ExcludeLocked=$ExcludePriorityLocked)" -Level "DEBUG"
        return $null
    }

    # Sort by usage score (lowest first) and return the least used
    $sorted = $candidates | Sort-Object { $_.UsageScore }
    $leastUsed = $sorted[0].ProfileName

    Write-LayoutLog "Least-used window: $leastUsed (score: $($sorted[0].UsageScore))" -Level "DEBUG"
    return $leastUsed
}

<#
.SYNOPSIS
    Mark a window as priority locked (never bumped).

.DESCRIPTION
    Sets or clears the priority lock flag for a window. Priority-locked
    windows have a usage score of 999.0 and are never selected for bumping.

.PARAMETER ProfileName
    The profile/shader name (e.g., "Matrix-1")

.PARAMETER Locked
    $true to lock (never bump), $false to unlock

.EXAMPLE
    Set-WindowPriority -ProfileName "Matrix-1" -Locked $true
    # Matrix-1 will never be bumped when accommodating other windows
#>
function Set-WindowPriority {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [bool]$Locked
    )

    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    # Ensure profile exists
    if (-not $script:UsageTrackingData.ContainsKey($ProfileName)) {
        $script:UsageTrackingData[$ProfileName] = @{
            lastFocusTime = [DateTime]::MinValue
            focusDurationMs = 0
            focusCount = 0
            usageScore = 0.0
            isPriorityLocked = $false
        }
    }

    $script:UsageTrackingData[$ProfileName].isPriorityLocked = $Locked

    # Recalculate score (priority locked = 999.0)
    Update-UsageScore -ProfileName $ProfileName

    # Persist
    Export-UsageTrackingData -UsageData $script:UsageTrackingData

    $status = if ($Locked) { "LOCKED (never bumped)" } else { "UNLOCKED" }
    Write-LayoutLog "Priority for $ProfileName : $status" -Level "INFO"
}

<#
.SYNOPSIS
    Get all windows sorted by usage score (lowest first).

.DESCRIPTION
    Returns an array of all tracked windows sorted by usage score,
    with the least-used windows first. Useful for bump selection
    or displaying usage statistics.

.PARAMETER ExcludePriorityLocked
    If set, excludes windows marked as priority locked from results

.OUTPUTS
    Array of @{ ProfileName, UsageScore, LastFocusTime, FocusDurationMs, FocusCount, IsPriorityLocked }

.EXAMPLE
    $windows = Get-WindowsByUsage
    $windows | ForEach-Object { Write-Host "$($_.ProfileName): $($_.UsageScore)" }
#>
function Get-WindowsByUsage {
    param(
        [switch]$ExcludePriorityLocked
    )

    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    $results = @()
    foreach ($profileName in $script:UsageTrackingData.Keys) {
        $data = $script:UsageTrackingData[$profileName]

        # Skip priority-locked if requested
        if ($ExcludePriorityLocked -and $data.isPriorityLocked) {
            continue
        }

        $results += @{
            ProfileName = $profileName
            UsageScore = $data.usageScore
            LastFocusTime = $data.lastFocusTime
            FocusDurationMs = $data.focusDurationMs
            FocusCount = $data.focusCount
            IsPriorityLocked = $data.isPriorityLocked
        }
    }

    # Sort by usage score (lowest first)
    return ($results | Sort-Object { $_.UsageScore })
}

<#
.SYNOPSIS
    Recalculate usage scores for all tracked windows.

.DESCRIPTION
    Updates the usage score for every tracked profile. Call this periodically
    to ensure recency scores decay properly over time.

.EXAMPLE
    Update-AllUsageScores
#>
function Update-AllUsageScores {
    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    foreach ($profileName in $script:UsageTrackingData.Keys) {
        Update-UsageScore -ProfileName $profileName
    }

    # Persist updated scores
    Export-UsageTrackingData -UsageData $script:UsageTrackingData

    Write-LayoutLog "Updated usage scores for $($script:UsageTrackingData.Count) profiles" -Level "DEBUG"
}

<#
.SYNOPSIS
    Clear stale usage tracking data older than specified days.

.DESCRIPTION
    Removes tracking data for windows that haven't been focused
    in the specified number of days. Helps keep the state file clean.

.PARAMETER OlderThanDays
    Remove entries where lastFocusTime is older than this many days (default: 7)

.EXAMPLE
    Clear-StaleUsageData -OlderThanDays 7
    # Removes tracking data for windows not focused in the last week
#>
function Clear-StaleUsageData {
    param(
        [int]$OlderThanDays = 7
    )

    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
    $toRemove = @()

    foreach ($profileName in $script:UsageTrackingData.Keys) {
        $data = $script:UsageTrackingData[$profileName]

        # Skip priority-locked windows (never remove)
        if ($data.isPriorityLocked) {
            continue
        }

        # Check if stale
        if ($data.lastFocusTime -lt $cutoffDate) {
            $toRemove += $profileName
        }
    }

    # Remove stale entries
    foreach ($profileName in $toRemove) {
        $script:UsageTrackingData.Remove($profileName)
        Write-LayoutLog "Removed stale usage data: $profileName" -Level "DEBUG"
    }

    if ($toRemove.Count -gt 0) {
        Export-UsageTrackingData -UsageData $script:UsageTrackingData
        Write-LayoutLog "Cleared $($toRemove.Count) stale usage entries (older than $OlderThanDays days)" -Level "INFO"
    }
}

<#
.SYNOPSIS
    Reset all usage tracking data.

.DESCRIPTION
    Clears all usage tracking data and resets to empty state.
    Use with caution - this loses all historical usage information.

.EXAMPLE
    Reset-UsageTracking
#>
function Reset-UsageTracking {
    $script:UsageTrackingData = @{}
    $script:FocusStartTimes = @{}

    # Save empty data
    Export-UsageTrackingData -UsageData $script:UsageTrackingData

    Write-LayoutLog "Usage tracking data has been reset" -Level "INFO"
}

<#
.SYNOPSIS
    Get a summary of current usage tracking state.

.DESCRIPTION
    Returns a formatted string summarizing the usage tracking state,
    useful for debugging and UI display.

.OUTPUTS
    String with formatted usage summary

.EXAMPLE
    $summary = Get-UsageTrackingSummary
    Write-Host $summary
#>
function Get-UsageTrackingSummary {
    # Ensure data is loaded
    if ($script:UsageTrackingData.Count -eq 0) {
        Initialize-UsageTracking
    }

    $windows = Get-WindowsByUsage

    if ($windows.Count -eq 0) {
        return "No windows tracked"
    }

    $lines = @()
    $lines += "Usage Tracking Summary ($($windows.Count) windows)"
    $lines += "=" * 50

    foreach ($win in $windows) {
        $focusDur = [Math]::Round($win.FocusDurationMs / 1000, 1)
        $score = [Math]::Round($win.UsageScore, 3)
        $locked = if ($win.IsPriorityLocked) { " [LOCKED]" } else { "" }
        $lines += "$($win.ProfileName): score=$score, focus=${focusDur}s, count=$($win.FocusCount)$locked"
    }

    return ($lines -join "`n")
}

# Initialize usage tracking when module is loaded
Initialize-UsageTracking
