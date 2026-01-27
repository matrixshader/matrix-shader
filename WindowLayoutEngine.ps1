# WindowLayoutEngine.ps1
# Centralized layout engine for Matrix Terminal windows
# Implements Pillars and Quads layout strategies with multi-monitor support

# --- WINDOWS API P/INVOKE DECLARATIONS ---
# Load pre-compiled DLL if available (instant), otherwise compile (slow)
$matrixDllPath = "$PSScriptRoot\MatrixAPI.dll"
if (Test-Path $matrixDllPath) {
    Add-Type -Path $matrixDllPath -ErrorAction SilentlyContinue
} elseif (-not ([System.Management.Automation.PSTypeName]'WindowLayoutAPI').Type) {
Add-Type -TypeDefinition @"
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
}

# Load System.Windows.Forms for screen detection (fast - just loads existing assembly)
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

# --- UNIFIED LOGGING ---
# Import unified logging module (respects $env:MATRIX_DEBUG)
. "$PSScriptRoot\MatrixLogging.ps1"

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

        Write-MatrixLog "Screen topology: $($sorted.Count) screens, primary at index 0" -Source LAYOUT -Level DEBUG
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
    Write-MatrixLog "Get-WindowDistributionWithPrimary: WindowCount=$WindowCount, ScreenCount=$ScreenCount, WindowsOnPrimary=$WindowsOnPrimary (type=$typeStr)" -Source LAYOUT -Level DEBUG

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
        Write-MatrixLog "Single screen: all $WindowCount windows on screen 0" -Source LAYOUT -Level DEBUG
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

        Write-MatrixLog "Auto mode: balanced distribution $($distribution -join ', ') (base=$base, remainder=$remainder)" -Source LAYOUT -Level DEBUG
    }
    else {
        # User-specified primary allocation
        $primaryCount = [Math]::Max(0, [Math]::Min([int]$WindowsOnPrimary, $WindowCount))
        $distribution[0] = $primaryCount
        $remaining = $WindowCount - $primaryCount

        Write-MatrixLog "User mode: primary gets $primaryCount (user specified $WindowsOnPrimary), $remaining remaining" -Source LAYOUT -Level DEBUG

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

    Write-MatrixLog "Final distribution: $($distribution -join ', ')" -Source LAYOUT -Level DEBUG
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

    # Allow zero gap for tight pillar layouts on constrained screens
    $GapSize = [Math]::Max($GapSize, 0)

    Write-MatrixLog "Get-PillarsLayout called: WindowCount=$WindowCount, ScreenCount=$($Screens.Count), MaxPillars=$MaxPillarsPerScreen, GapSize=$GapSize, WindowsOnPrimary=$WindowsOnPrimary" -Source LAYOUT -Level DEBUG

    if ($WindowCount -le 0) {
        Write-MatrixLog "Get-PillarsLayout: Zero or negative window count, returning empty" -Source LAYOUT -Level DEBUG
        return @()
    }

    if (-not $Screens -or $Screens.Count -eq 0) {
        Write-MatrixLog "No screens available for Pillars layout" -Source LAYOUT -Level WARN
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
        # Windows Terminal minimum width constraint (~478px)
        # Set threshold at 475 to allow tight 4-pillar layouts on 1920px screens
        $minWindowWidth = 475

        # Auto-reduce columns if calculated width would be below minimum
        $originalColumns = $columns
        do {
            $totalHGaps = ($columns + 1) * $GapSize
            $totalVGaps = ($rows + 1) * $GapSize
            $cellWidth = [int](($screen.Width - $totalHGaps) / $columns)

            if ($cellWidth -lt $minWindowWidth -and $columns -gt 1) {
                $columns--
                $rows = [Math]::Ceiling($windowsOnScreen / $columns)
                Write-MatrixLog "Auto-reduced columns from $($columns+1) to $columns (width $cellWidth < min $minWindowWidth)" -Source LAYOUT -Level WARN -Force
            } else {
                break
            }
        } while ($columns -ge 1)

        # Recalculate after column adjustment
        $totalHGaps = ($columns + 1) * $GapSize
        $totalVGaps = ($rows + 1) * $GapSize
        $cellWidth = [int](($screen.Width - $totalHGaps) / $columns)
        $cellHeight = [int](($screen.Height - $totalVGaps) / $rows)

        if ($columns -ne $originalColumns) {
            Write-MatrixLog "Layout adjusted: $windowsOnScreen windows in ${columns}x${rows} grid (was ${originalColumns}x1)" -Source LAYOUT -Force
        }

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

    # Allow zero gap for tight pillar layouts on constrained screens
    $GapSize = [Math]::Max($GapSize, 0)

    Write-MatrixLog "Get-QuadsLayout called: WindowCount=$WindowCount, ScreenCount=$($Screens.Count), GapSize=$GapSize, WindowsOnPrimary=$WindowsOnPrimary" -Source LAYOUT -Level DEBUG

    if ($WindowCount -le 0) {
        Write-MatrixLog "Get-QuadsLayout: Zero or negative window count, returning empty" -Source LAYOUT -Level DEBUG
        return @()
    }

    if (-not $Screens -or $Screens.Count -eq 0) {
        Write-MatrixLog "No screens available for Quads layout" -Source LAYOUT -Level WARN
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
        Write-MatrixLog "Quads overflow: $WindowCount windows > $totalCapacity capacity, using extended grid layout" -Source LAYOUT

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

            Write-MatrixLog "Screen ${screenIdx}: $windowsOnThisScreen windows in ${cols}x${rows} grid" -Source LAYOUT -Level DEBUG

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

        Write-MatrixLog "Screen ${screenIdx}: $windowsOnThisScreen windows in quad positions" -Source LAYOUT -Level DEBUG

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
            Write-MatrixLog "  Placed window $($windowIndex-1) at $($quadPositions[$posIdx].Label): ($($quadPositions[$posIdx].X), $($quadPositions[$posIdx].Y))" -Source LAYOUT -Level DEBUG
        }
    }

    Write-MatrixLog "Get-QuadsLayout complete: $($rectangles.Count) rectangles calculated" -Source LAYOUT -Level DEBUG
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
        GapSize = 30
        PreferredScreen = 0
        WindowsOnPrimary = $null  # null = Auto (evenly distribute, remainders to primary)
        GlitchEnabled = $true     # Glitch = auto-snap windows to layout grid (default ON)
        MonitorCount = 1          # User-configured monitor count (set by installer)
        OverlapPercent = 5        # Overlap percentage for 5-8 window layouts
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
                    GlitchEnabled = if ($null -ne $state.layout.glitchEnabled) { $state.layout.glitchEnabled } else { $defaultConfig.GlitchEnabled }
                    MonitorCount = if ($state.layout.monitorCount) { $state.layout.monitorCount } else { $defaultConfig.MonitorCount }
                    OverlapPercent = if ($state.layout.overlapPercent) { $state.layout.overlapPercent } else { $defaultConfig.OverlapPercent }
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
            gapSize = if ($Config.GapSize) { $Config.GapSize } else { 30 }
            preferredScreen = if ($Config.PreferredScreen -ne $null) { $Config.PreferredScreen } else { 0 }
            windowsOnPrimary = $Config.WindowsOnPrimary  # null = Auto (evenly distribute)
            glitchEnabled = if ($null -ne $Config.GlitchEnabled) { $Config.GlitchEnabled } else { $true }
            monitorCount = if ($Config.MonitorCount) { $Config.MonitorCount } else { 1 }
            overlapPercent = if ($Config.OverlapPercent) { $Config.OverlapPercent } else { 5 }
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

        [switch]$DryRun,

        [switch]$PreserveMonitors,

        [switch]$Force  # Bypass Glitch check (for manual layout triggers)
    )

    Write-MatrixLog "Invoke-MatrixWindowLayout called: Mode=$Mode, DryRun=$DryRun, PreserveMonitors=$PreserveMonitors, Force=$Force, InputHandles=$($WindowHandles.Count)" -Source LAYOUT -Level DEBUG

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
                    Write-MatrixLog "Restoring minimized window: $name" -Source LAYOUT -Level DEBUG
                    [WindowLayoutAPI]::ShowWindow($handle, [WindowLayoutAPI]::SW_RESTORE) | Out-Null
                    Start-Sleep -Milliseconds 100
                }

                $validWindows += @{
                    Name = $name
                    Handle = $handle
                }
            } else {
                Write-MatrixLog "Filtered invalid/invisible window: $name (handle=$handle)" -Source LAYOUT -Level DEBUG
                $invalidCount++
            }
        } else {
            Write-MatrixLog "Filtered null/zero handle: $name" -Source LAYOUT -Level DEBUG
            $invalidCount++
        }
    }

    if ($invalidCount -gt 0) {
        Write-MatrixLog "Filtered out $invalidCount invalid window handle(s)" -Source LAYOUT
    }

    $windowCount = $validWindows.Count

    if ($windowCount -eq 0) {
        Write-MatrixLog "No valid windows to layout - returning empty" -Source LAYOUT
        return @()
    }

    # Get configuration
    $config = Get-MatrixLayoutConfig

    # Check Glitch setting - if disabled and not forced, skip auto-layout
    if (-not $config.GlitchEnabled -and -not $Force) {
        Write-MatrixLog "Glitch is OFF - skipping auto-layout (use -Force to override)" -Source LAYOUT
        return @()
    }

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

    # If PreserveMonitors is set, keep windows on their current monitors
    if ($PreserveMonitors) {
        Write-MatrixLog "PreserveMonitors mode: keeping windows on current monitors" -Source LAYOUT

        # Group windows by their current monitor
        $windowsByMonitor = @{}
        foreach ($window in $validWindows) {
            $rect = New-Object WindowLayoutAPI+RECT
            if ([WindowLayoutAPI]::GetWindowRect($window.Handle, [ref]$rect)) {
                $centerX = ($rect.Left + $rect.Right) / 2
                $centerY = ($rect.Top + $rect.Bottom) / 2

                # Find which monitor this window is on
                $monitorIndex = 0
                for ($i = 0; $i -lt $screens.Count; $i++) {
                    $scr = $screens[$i]
                    if ($centerX -ge $scr.Left -and $centerX -lt ($scr.Left + $scr.Width) -and
                        $centerY -ge $scr.Top -and $centerY -lt ($scr.Top + $scr.Height)) {
                        $monitorIndex = $i
                        break
                    }
                }

                if (-not $windowsByMonitor.ContainsKey($monitorIndex)) {
                    $windowsByMonitor[$monitorIndex] = @()
                }
                $windowsByMonitor[$monitorIndex] += $window
            }
        }

        Write-MatrixLog "Windows by monitor: $($windowsByMonitor.Keys | ForEach-Object { "Mon$_=$($windowsByMonitor[$_].Count)" })" -Source LAYOUT -Level DEBUG

        # Calculate layout for each monitor's windows separately
        $result = @()
        foreach ($monitorIndex in $windowsByMonitor.Keys) {
            $monitorWindows = $windowsByMonitor[$monitorIndex]
            $monitorScreen = $screens[$monitorIndex]
            $windowCountOnMonitor = $monitorWindows.Count

            if ($windowCountOnMonitor -eq 0) { continue }

            # Create single-screen layout for this monitor
            $singleScreen = @($monitorScreen)
            $monitorLayout = switch ($effectiveMode) {
                'Pillars' {
                    $maxPillars = if ($config.MaxPillarsPerScreen) { $config.MaxPillarsPerScreen } else { 4 }
                    Get-PillarsLayout -WindowCount $windowCountOnMonitor -Screens $singleScreen -MaxPillarsPerScreen $maxPillars -GapSize $gapSize -WindowsOnPrimary $windowCountOnMonitor
                }
                'Quads' {
                    Get-QuadsLayout -WindowCount $windowCountOnMonitor -Screens $singleScreen -GapSize $gapSize -WindowsOnPrimary $windowCountOnMonitor
                }
            }

            # Sort windows on this monitor by name
            $sortedMonitorWindows = $monitorWindows | Sort-Object { $_.Name }

            # Apply positions
            for ($i = 0; $i -lt [Math]::Min($sortedMonitorWindows.Count, $monitorLayout.Count); $i++) {
                $window = $sortedMonitorWindows[$i]
                $position = $monitorLayout[$i]

                $result += @{
                    Name = $window.Name
                    Handle = $window.Handle
                    X = $position.X
                    Y = $position.Y
                    Width = $position.Width
                    Height = $position.Height
                    ScreenIndex = $monitorIndex
                }
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
                    Write-MatrixLog "Positioned $($item.Name) at ($($item.X), $($item.Y)) on monitor $($item.ScreenIndex)" -Source LAYOUT -Level DEBUG
                }
                catch {
                    Write-Warning "Failed to position $($item.Name): $_"
                }
            }
        }

        return $result
    }

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
        [AllowEmptyCollection()]
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
            Write-MatrixLog "Failed to get position for handle $handle : $_" -Source LAYOUT -Level DEBUG
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
        [AllowEmptyCollection()]
        [array]$WindowHandles
    )

    $script:LastKnownPositions = Get-WindowPositions -WindowHandles $WindowHandles
    Write-MatrixLog "Initialized position tracking for $($WindowHandles.Count) windows" -Source LAYOUT -Level DEBUG
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
            Write-MatrixLog "New window detected: $handleKey" -Source LAYOUT -Level DEBUG
            return $true
        }

        $current = $currentPositions[$handleKey]
        $last = $script:LastKnownPositions[$handleKey]

        $deltaX = [Math]::Abs($current.X - $last.X)
        $deltaY = [Math]::Abs($current.Y - $last.Y)

        if ($deltaX -gt $script:DragThreshold -or $deltaY -gt $script:DragThreshold) {
            Write-MatrixLog "Drag detected on $handleKey : delta ($deltaX, $deltaY)" -Source LAYOUT -Level DEBUG
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
        [AllowEmptyCollection()]
        [array]$WindowHandles
    )

    $script:LastKnownPositions = Get-WindowPositions -WindowHandles $WindowHandles
    Write-MatrixLog "Updated position tracking for $($WindowHandles.Count) windows" -Source LAYOUT -Level DEBUG
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
                Write-MatrixLog "Failed to load existing state for position save: $_" -Source LAYOUT -Level WARN
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
                    Write-MatrixLog "Saved position for $shaderName : ($($rect.Left), $($rect.Top)) $($rect.Right - $rect.Left)x$($rect.Bottom - $rect.Top)" -Source LAYOUT -Level DEBUG
                }
            }
            catch {
                Write-MatrixLog "Failed to get position for slot $($win.Slot): $_" -Source LAYOUT -Level DEBUG
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

        Write-MatrixLog "Saved positions for $($positions.Count) windows" -Source LAYOUT
        return $true
    }
    catch {
        Write-MatrixLog "Failed to save window positions: $_" -Source LAYOUT -Level ERROR
        # Clean up temp file if it exists (US-001 pattern)
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
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
            Write-MatrixLog "No state file for position restore" -Source LAYOUT -Level DEBUG
            return $false
        }

        $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.windowPositions) {
            Write-MatrixLog "No saved positions in state file" -Source LAYOUT -Level DEBUG
            return $false
        }

        $restoredCount = 0
        foreach ($win in $WindowInfo) {
            $shaderName = "Matrix-$($win.Slot)"

            # Check if we have saved position for this shader
            $savedPos = $state.windowPositions.$shaderName
            if (-not $savedPos) {
                Write-MatrixLog "No saved position for $shaderName" -Source LAYOUT -Level DEBUG
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

                Write-MatrixLog "Restored position for $shaderName : ($($savedPos.x), $($savedPos.y)) $($savedPos.width)x$($savedPos.height)" -Source LAYOUT -Level DEBUG
                $restoredCount++
            }
            catch {
                Write-MatrixLog "Failed to restore position for $shaderName : $_" -Source LAYOUT -Level WARN
            }
        }

        if ($restoredCount -gt 0) {
            Write-MatrixLog "Restored positions for $restoredCount windows" -Source LAYOUT
            return $true
        }
        else {
            Write-MatrixLog "No positions were restored" -Source LAYOUT -Level DEBUG
            return $false
        }
    }
    catch {
        Write-MatrixLog "Failed to restore window positions: $_" -Source LAYOUT -Level ERROR
        return $false
    }
}

# --- POSITION PRESETS SYSTEM ---
# Phase 4: Save and restore custom window positions

<#
.SYNOPSIS
    Generate a unique monitor configuration string for the current display setup.

.DESCRIPTION
    Creates a hash-like string that uniquely identifies the current monitor configuration.
    Used to detect when presets were saved with a different display setup.
    Format: "MONITOR_<hash>_<width>x<height>+MONITOR_<hash>_<width>x<height>"

.OUTPUTS
    String representing the current monitor configuration

.EXAMPLE
    $config = Get-MonitorConfigString
    # Returns: "MONITOR_0_1920x1040+MONITOR_1_2560x1400"
#>
function Get-MonitorConfigString {
    try {
        $screens = Get-ScreenTopology
        $configParts = @()

        foreach ($screen in $screens) {
            # Include index, dimensions, and position for uniqueness
            $part = "MONITOR_$($screen.Index)_$($screen.Width)x$($screen.Height)@$($screen.Left),$($screen.Top)"
            $configParts += $part
        }

        $configString = $configParts -join "+"
        Write-MatrixLog "Monitor config string: $configString" -Source LAYOUT -Level DEBUG
        return $configString
    }
    catch {
        Write-MatrixLog "Failed to generate monitor config string: $_" -Source LAYOUT -Level ERROR
        return "UNKNOWN"
    }
}

<#
.SYNOPSIS
    Save current window positions as a named preset.

.DESCRIPTION
    Captures current positions of all Matrix windows and saves them to matrix_state.json
    under the positionPresets key. The special name "_snapback" is used for quick save/restore.
    Uses atomic write pattern (US-001) to prevent corruption.

.PARAMETER Name
    Name of the preset (e.g., "_snapback", "Coding", "Monitoring")

.PARAMETER WindowInfo
    Optional array of @{ Handle, Slot } objects. If not provided, uses Get-MatrixWindowInfo.

.OUTPUTS
    $true if save succeeded, $false otherwise

.EXAMPLE
    Save-PositionPreset -Name "_snapback"

.EXAMPLE
    Save-PositionPreset -Name "Coding"
#>
function Save-PositionPreset {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [array]$WindowInfo
    )

    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    try {
        # Get window info if not provided
        if (-not $WindowInfo -or $WindowInfo.Count -eq 0) {
            # Try to get windows from global handles if available
            if ($global:matrixWindowHandles) {
                $WindowInfo = @()
                foreach ($key in $global:matrixWindowHandles.Keys) {
                    $entry = $global:matrixWindowHandles[$key]
                    $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }
                    if ($handle -and $handle -ne [IntPtr]::Zero) {
                        # Extract slot number from key (e.g., "Matrix-1" -> 1)
                        if ($key -match 'Matrix-(\d+)') {
                            $WindowInfo += @{
                                Handle = $handle
                                Slot = [int]$Matches[1]
                            }
                        }
                    }
                }
            }
        }

        if (-not $WindowInfo -or $WindowInfo.Count -eq 0) {
            Write-MatrixLog "No windows to save for preset '$Name'" -Source LAYOUT -Level WARN
            return $false
        }

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
                Write-MatrixLog "Failed to load existing state for preset save: $_" -Source LAYOUT -Level WARN
            }
        }

        # Ensure positionPresets exists
        if (-not $state.positionPresets) {
            $state.positionPresets = @{}
        }
        # Convert PSCustomObject to hashtable if needed
        elseif ($state.positionPresets -is [PSCustomObject]) {
            $presetsHash = @{}
            $state.positionPresets.PSObject.Properties | ForEach-Object {
                $presetsHash[$_.Name] = $_.Value
            }
            $state.positionPresets = $presetsHash
        }

        # Get current monitor configuration
        $monitorConfig = Get-MonitorConfigString

        # Build window positions with monitor info
        $positions = @{}
        $screens = Get-ScreenTopology

        foreach ($win in $WindowInfo) {
            if (-not $win.Handle -or $win.Handle -eq [IntPtr]::Zero) { continue }

            try {
                $rect = New-Object WindowLayoutAPI+RECT
                if ([WindowLayoutAPI]::GetWindowRect($win.Handle, [ref]$rect)) {
                    $shaderName = "Matrix-$($win.Slot)"

                    # Determine which monitor this window is on
                    $centerX = ($rect.Left + $rect.Right) / 2
                    $centerY = ($rect.Top + $rect.Bottom) / 2
                    $monitorIndex = Get-MonitorAtPoint -X $centerX -Y $centerY

                    $positions[$shaderName] = @{
                        x = $rect.Left
                        y = $rect.Top
                        width = $rect.Right - $rect.Left
                        height = $rect.Bottom - $rect.Top
                        monitor = $monitorIndex
                    }
                    Write-MatrixLog "Preset '$Name': Captured $shaderName at ($($rect.Left), $($rect.Top)) $($rect.Right - $rect.Left)x$($rect.Bottom - $rect.Top) on monitor $monitorIndex" -Source LAYOUT -Level DEBUG
                }
            }
            catch {
                Write-MatrixLog "Failed to get position for slot $($win.Slot) in preset: $_" -Source LAYOUT -Level DEBUG
            }
        }

        if ($positions.Count -eq 0) {
            Write-MatrixLog "No positions captured for preset '$Name'" -Source LAYOUT -Level WARN
            return $false
        }

        # Create preset entry
        $preset = @{
            savedAt = (Get-Date).ToString("o")
            monitorConfig = $monitorConfig
            positions = $positions
        }

        # Save preset
        $state.positionPresets[$Name] = $preset

        # Atomic write
        $stateJson = $state | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $tempFile = [System.IO.Path]::GetTempFileName()
        $stateJson | Out-File -FilePath $tempFile -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempFile -Destination $stateFilePath -Force -ErrorAction Stop

        Write-MatrixLog "Saved preset '$Name' with $($positions.Count) window positions" -Source LAYOUT
        return $true
    }
    catch {
        Write-MatrixLog "Failed to save position preset '$Name': $_" -Source LAYOUT -Level ERROR
        # Clean up temp file if it exists (US-001 pattern)
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

<#
.SYNOPSIS
    Restore window positions from a saved preset.

.DESCRIPTION
    Reads a preset from matrix_state.json and applies positions to matching windows.
    Handles monitor configuration mismatches by scaling positions proportionally.

.PARAMETER Name
    Name of the preset to restore (e.g., "_snapback", "Coding")

.PARAMETER WindowInfo
    Optional array of @{ Handle, Slot } objects. If not provided, uses global handles.

.PARAMETER Force
    If $true, restore even if monitor configuration doesn't match (with scaling)

.OUTPUTS
    $true if restore succeeded, $false otherwise

.EXAMPLE
    Restore-PositionPreset -Name "_snapback"

.EXAMPLE
    Restore-PositionPreset -Name "Coding" -Force
#>
function Restore-PositionPreset {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [array]$WindowInfo,

        [switch]$Force
    )

    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    try {
        # Load state
        if (-not (Test-Path $stateFilePath)) {
            Write-MatrixLog "No state file found for preset restore" -Source LAYOUT -Level WARN
            return $false
        }

        $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.positionPresets) {
            Write-MatrixLog "No presets found in state file" -Source LAYOUT -Level WARN
            return $false
        }

        # Get preset
        $preset = $state.positionPresets.$Name
        if (-not $preset) {
            Write-MatrixLog "Preset '$Name' not found" -Source LAYOUT -Level WARN
            return $false
        }

        # Check monitor compatibility
        $currentConfig = Get-MonitorConfigString
        $savedConfig = $preset.monitorConfig
        $configMatches = ($currentConfig -eq $savedConfig)

        if (-not $configMatches -and -not $Force) {
            Write-MatrixLog "Monitor configuration changed since preset was saved. Use -Force to restore anyway." -Source LAYOUT -Level WARN
            Write-MatrixLog "  Saved: $savedConfig" -Source LAYOUT -Level DEBUG
            Write-MatrixLog "  Current: $currentConfig" -Source LAYOUT -Level DEBUG
            # Still proceed but log warning - auto-scale positions
        }

        # Get window info if not provided
        if (-not $WindowInfo -or $WindowInfo.Count -eq 0) {
            if ($global:matrixWindowHandles) {
                $WindowInfo = @()
                foreach ($key in $global:matrixWindowHandles.Keys) {
                    $entry = $global:matrixWindowHandles[$key]
                    $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }
                    if ($handle -and $handle -ne [IntPtr]::Zero) {
                        if ($key -match 'Matrix-(\d+)') {
                            $WindowInfo += @{
                                Handle = $handle
                                Slot = [int]$Matches[1]
                            }
                        }
                    }
                }
            }
        }

        if (-not $WindowInfo -or $WindowInfo.Count -eq 0) {
            Write-MatrixLog "No windows available to restore preset '$Name'" -Source LAYOUT -Level WARN
            return $false
        }

        # Get current screens for scaling
        $screens = Get-ScreenTopology

        # Calculate scaling factors if config doesn't match
        $scaleFactors = @{}
        if (-not $configMatches) {
            # Parse saved config to extract monitor dimensions
            # Format: MONITOR_0_1920x1040@0,0+MONITOR_1_2560x1400@1920,0
            $savedParts = $savedConfig -split '\+'
            foreach ($part in $savedParts) {
                if ($part -match 'MONITOR_(\d+)_(\d+)x(\d+)@(-?\d+),(-?\d+)') {
                    $monIdx = [int]$Matches[1]
                    $savedWidth = [int]$Matches[2]
                    $savedHeight = [int]$Matches[3]
                    $savedLeft = [int]$Matches[4]
                    $savedTop = [int]$Matches[5]

                    # Find corresponding current screen
                    $currentScreen = $screens | Where-Object { $_.Index -eq $monIdx } | Select-Object -First 1
                    if ($currentScreen) {
                        $scaleFactors[$monIdx] = @{
                            ScaleX = $currentScreen.Width / $savedWidth
                            ScaleY = $currentScreen.Height / $savedHeight
                            OffsetX = $currentScreen.Left - $savedLeft
                            OffsetY = $currentScreen.Top - $savedTop
                            CurrentScreen = $currentScreen
                        }
                    }
                }
            }
        }

        # Restore positions
        $restoredCount = 0
        foreach ($win in $WindowInfo) {
            $shaderName = "Matrix-$($win.Slot)"

            # Get saved position
            $savedPos = $preset.positions.$shaderName
            if (-not $savedPos) {
                Write-MatrixLog "No saved position for $shaderName in preset '$Name'" -Source LAYOUT -Level DEBUG
                continue
            }

            # Calculate final position (with scaling if needed)
            $finalX = [int]$savedPos.x
            $finalY = [int]$savedPos.y
            $finalWidth = [int]$savedPos.width
            $finalHeight = [int]$savedPos.height

            if (-not $configMatches -and $scaleFactors.Count -gt 0) {
                $monitorIdx = if ($null -ne $savedPos.monitor) { [int]$savedPos.monitor } else { 0 }

                if ($scaleFactors.ContainsKey($monitorIdx)) {
                    $sf = $scaleFactors[$monitorIdx]
                    $currentScreen = $sf.CurrentScreen

                    # Scale position relative to monitor origin
                    $relX = $savedPos.x - ($currentScreen.Left - $sf.OffsetX)
                    $relY = $savedPos.y - ($currentScreen.Top - $sf.OffsetY)

                    $scaledRelX = [int]($relX * $sf.ScaleX)
                    $scaledRelY = [int]($relY * $sf.ScaleY)
                    $scaledWidth = [int]($savedPos.width * $sf.ScaleX)
                    $scaledHeight = [int]($savedPos.height * $sf.ScaleY)

                    $finalX = $currentScreen.Left + $scaledRelX
                    $finalY = $currentScreen.Top + $scaledRelY
                    $finalWidth = $scaledWidth
                    $finalHeight = $scaledHeight

                    Write-MatrixLog "Scaled $shaderName from ($($savedPos.x),$($savedPos.y)) to ($finalX,$finalY)" -Source LAYOUT -Level DEBUG
                }
            }

            try {
                [WindowLayoutAPI]::SetWindowPos(
                    $win.Handle,
                    [IntPtr]::Zero,
                    $finalX,
                    $finalY,
                    $finalWidth,
                    $finalHeight,
                    ([WindowLayoutAPI]::SWP_NOZORDER -bor [WindowLayoutAPI]::SWP_SHOWWINDOW)
                ) | Out-Null

                Write-MatrixLog "Restored $shaderName to ($finalX, $finalY) $($finalWidth)x$($finalHeight)" -Source LAYOUT -Level DEBUG
                $restoredCount++
            }
            catch {
                Write-MatrixLog "Failed to restore position for $shaderName : $_" -Source LAYOUT -Level WARN
            }
        }

        if ($restoredCount -gt 0) {
            Write-MatrixLog "Restored $restoredCount windows from preset '$Name'" -Source LAYOUT
            return $true
        }
        else {
            Write-MatrixLog "No positions were restored from preset '$Name'" -Source LAYOUT -Level WARN
            return $false
        }
    }
    catch {
        Write-MatrixLog "Failed to restore position preset '$Name': $_" -Source LAYOUT -Level ERROR
        return $false
    }
}

<#
.SYNOPSIS
    List all available position presets.

.DESCRIPTION
    Returns an array of preset information including name, save time, and window count.

.OUTPUTS
    Array of @{ Name, SavedAt, WindowCount, MonitorConfig, IsCompatible }

.EXAMPLE
    $presets = Get-PositionPresets
    $presets | Format-Table -AutoSize
#>
function Get-PositionPresets {
    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    try {
        if (-not (Test-Path $stateFilePath)) {
            Write-MatrixLog "No state file found" -Source LAYOUT -Level DEBUG
            return @()
        }

        $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.positionPresets) {
            Write-MatrixLog "No presets in state file" -Source LAYOUT -Level DEBUG
            return @()
        }

        $currentConfig = Get-MonitorConfigString
        $presets = @()

        $state.positionPresets.PSObject.Properties | ForEach-Object {
            $presetName = $_.Name
            $presetData = $_.Value

            # Count positions
            $windowCount = 0
            if ($presetData.positions) {
                $windowCount = ($presetData.positions.PSObject.Properties | Measure-Object).Count
            }

            $presets += @{
                Name = $presetName
                SavedAt = if ($presetData.savedAt) { $presetData.savedAt } else { "Unknown" }
                WindowCount = $windowCount
                MonitorConfig = if ($presetData.monitorConfig) { $presetData.monitorConfig } else { "Unknown" }
                IsCompatible = ($presetData.monitorConfig -eq $currentConfig)
            }
        }

        return $presets
    }
    catch {
        Write-MatrixLog "Failed to get position presets: $_" -Source LAYOUT -Level ERROR
        return @()
    }
}

<#
.SYNOPSIS
    Remove a position preset.

.DESCRIPTION
    Deletes a named preset from matrix_state.json. Uses atomic write pattern.

.PARAMETER Name
    Name of the preset to remove

.OUTPUTS
    $true if removed, $false if not found or error

.EXAMPLE
    Remove-PositionPreset -Name "OldPreset"
#>
function Remove-PositionPreset {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    try {
        if (-not (Test-Path $stateFilePath)) {
            Write-MatrixLog "No state file found" -Source LAYOUT -Level WARN
            return $false
        }

        $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
        $stateObj = $stateJson | ConvertFrom-Json -ErrorAction Stop

        # Convert to hashtable for manipulation
        $state = @{}
        $stateObj.PSObject.Properties | ForEach-Object {
            $state[$_.Name] = $_.Value
        }

        if (-not $state.positionPresets) {
            Write-MatrixLog "No presets section in state file" -Source LAYOUT -Level WARN
            return $false
        }

        # Convert presets to hashtable
        $presetsHash = @{}
        $state.positionPresets.PSObject.Properties | ForEach-Object {
            $presetsHash[$_.Name] = $_.Value
        }

        if (-not $presetsHash.ContainsKey($Name)) {
            Write-MatrixLog "Preset '$Name' not found" -Source LAYOUT -Level WARN
            return $false
        }

        # Remove preset
        $presetsHash.Remove($Name)
        $state.positionPresets = $presetsHash

        # Atomic write
        $stateJson = $state | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $tempFile = [System.IO.Path]::GetTempFileName()
        $stateJson | Out-File -FilePath $tempFile -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempFile -Destination $stateFilePath -Force -ErrorAction Stop

        Write-MatrixLog "Removed preset '$Name'" -Source LAYOUT
        return $true
    }
    catch {
        Write-MatrixLog "Failed to remove preset '$Name': $_" -Source LAYOUT -Level ERROR
        # Clean up temp file if it exists (US-001 pattern)
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

<#
.SYNOPSIS
    Test if a preset is compatible with current monitor configuration.

.DESCRIPTION
    Checks if a preset's monitor configuration matches the current setup.
    Returns detailed compatibility information.

.PARAMETER PresetName
    Name of the preset to check

.OUTPUTS
    Hashtable with compatibility details: @{ IsCompatible, Reason, ScalingRequired, MissingMonitors }

.EXAMPLE
    $compat = Test-PresetCompatible -PresetName "_snapback"
    if ($compat.IsCompatible) { Restore-PositionPreset -Name "_snapback" }
#>
function Test-PresetCompatible {
    param(
        [Parameter(Mandatory)]
        [string]$PresetName
    )

    $stateFilePath = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"

    $result = @{
        IsCompatible = $false
        Reason = "Unknown"
        ScalingRequired = $false
        MissingMonitors = @()
    }

    try {
        if (-not (Test-Path $stateFilePath)) {
            $result.Reason = "No state file found"
            return $result
        }

        $stateJson = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.positionPresets) {
            $result.Reason = "No presets in state file"
            return $result
        }

        $preset = $state.positionPresets.$PresetName
        if (-not $preset) {
            $result.Reason = "Preset '$PresetName' not found"
            return $result
        }

        $currentConfig = Get-MonitorConfigString
        $savedConfig = $preset.monitorConfig

        if ($currentConfig -eq $savedConfig) {
            $result.IsCompatible = $true
            $result.Reason = "Exact match"
            return $result
        }

        # Parse configs to check compatibility
        $currentScreens = Get-ScreenTopology
        $savedMonitorCount = ($savedConfig -split '\+').Count
        $currentMonitorCount = $currentScreens.Count

        if ($currentMonitorCount -lt $savedMonitorCount) {
            $result.Reason = "Fewer monitors ($currentMonitorCount) than preset ($savedMonitorCount)"
            $result.MissingMonitors = @($savedMonitorCount - $currentMonitorCount)
        }
        elseif ($currentMonitorCount -gt $savedMonitorCount) {
            $result.IsCompatible = $true
            $result.Reason = "More monitors available ($currentMonitorCount vs $savedMonitorCount preset)"
            $result.ScalingRequired = $true
        }
        else {
            # Same monitor count but different config - likely resolution change
            $result.IsCompatible = $true
            $result.Reason = "Same monitor count, different resolution/position"
            $result.ScalingRequired = $true
        }

        return $result
    }
    catch {
        $result.Reason = "Error checking compatibility: $_"
        return $result
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
            Write-MatrixLog "No state file for usage tracking, starting fresh" -Source LAYOUT -Level DEBUG
            return @{}
        }

        $stateJson = Get-Content -Path $script:UsageTrackingStateFile -Raw -ErrorAction Stop
        $state = $stateJson | ConvertFrom-Json -ErrorAction Stop

        if (-not $state.usageTracking) {
            Write-MatrixLog "No usageTracking section in state file" -Source LAYOUT -Level DEBUG
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

        Write-MatrixLog "Loaded usage tracking data for $($usageData.Count) profiles" -Source LAYOUT -Level DEBUG
        return $usageData
    }
    catch {
        Write-MatrixLog "Failed to load usage tracking data: $_" -Source LAYOUT -Level WARN
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
                Write-MatrixLog "Failed to load existing state for usage export, creating new: $_" -Source LAYOUT -Level WARN
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

        Write-MatrixLog "Saved usage tracking data for $($UsageData.Count) profiles" -Source LAYOUT -Level DEBUG
    }
    catch {
        Write-MatrixLog "Failed to save usage tracking data: $_" -Source LAYOUT -Level ERROR
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
    Write-MatrixLog "Usage tracking initialized with $($script:UsageTrackingData.Count) profiles" -Source LAYOUT
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
            Write-MatrixLog "Focus gained: $ProfileName (count: $($profileData.focusCount))" -Source LAYOUT -Level DEBUG
        }
        'Blur' {
            # Calculate focus duration
            if ($script:FocusStartTimes.ContainsKey($ProfileName)) {
                $focusStart = $script:FocusStartTimes[$ProfileName]
                $durationMs = ($now - $focusStart).TotalMilliseconds
                $profileData.focusDurationMs += [int]$durationMs
                $script:FocusStartTimes.Remove($ProfileName)
                Write-MatrixLog "Focus lost: $ProfileName (duration: ${durationMs}ms, total: $($profileData.focusDurationMs)ms)" -Source LAYOUT -Level DEBUG
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

    Write-MatrixLog "Updated score for $ProfileName : focus=$([Math]::Round($focusScore, 3)), recency=$([Math]::Round($recencyScore, 3)), freq=$([Math]::Round($frequencyScore, 3)), total=$([Math]::Round($usageScore, 4))" -Source LAYOUT -Level DEBUG
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
        Write-MatrixLog "No candidate windows for least-used selection (ExcludeLocked=$ExcludePriorityLocked)" -Source LAYOUT -Level DEBUG
        return $null
    }

    # Sort by usage score (lowest first) and return the least used
    $sorted = $candidates | Sort-Object { $_.UsageScore }
    $leastUsed = $sorted[0].ProfileName

    Write-MatrixLog "Least-used window: $leastUsed (score: $($sorted[0].UsageScore))" -Source LAYOUT -Level DEBUG
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
    Write-MatrixLog "Priority for $ProfileName : $status" -Source LAYOUT
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

    Write-MatrixLog "Updated usage scores for $($script:UsageTrackingData.Count) profiles" -Source LAYOUT -Level DEBUG
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
        Write-MatrixLog "Removed stale usage data: $profileName" -Source LAYOUT -Level DEBUG
    }

    if ($toRemove.Count -gt 0) {
        Export-UsageTrackingData -UsageData $script:UsageTrackingData
        Write-MatrixLog "Cleared $($toRemove.Count) stale usage entries (older than $OlderThanDays days)" -Source LAYOUT
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

    Write-MatrixLog "Usage tracking data has been reset" -Source LAYOUT
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

# --- DYNAMIC ACCOMMODATION SYSTEM (Phase 3) ---
# Implements intelligent window accommodation when dragging across monitors

# Module-level state for accommodation state machine
$script:AccommodationState = 'IDLE'
$script:DragStartTime = $null
$script:DraggedWindowInfo = $null
$script:WindowMonitorAssignments = @{}  # Track which monitor each window is on
$script:DragThresholdMs = 300  # Minimum drag duration to confirm intent
$script:CrossMonitorDragThreshold = 50  # Pixels of movement to detect drag

# Accommodation State Machine States:
# IDLE - No drag in progress
# DRAG_DETECTING - Movement detected, waiting to confirm intent
# DRAG_CONFIRMED - User has dragged window significantly
# CALCULATING - Determining target monitor and capacity
# ACCOMMODATING - Making room (if needed) or adding directly
# BUMP_SELECTING - Choosing which window to bump
# ANIMATING - Moving windows to new positions
# FINALIZING - Updating tracking and completing

<#
.SYNOPSIS
    Get which monitor a point is located on.

.DESCRIPTION
    Determines which screen contains the given point by checking against
    all screen boundaries. Returns the screen index (0-based).

.PARAMETER X
    X coordinate in screen pixels

.PARAMETER Y
    Y coordinate in screen pixels

.OUTPUTS
    Integer - Monitor index (0-based), or 0 if point outside all monitors

.EXAMPLE
    $monitorIdx = Get-MonitorAtPoint -X 1000 -Y 500
    # Returns: 0 (if point is on primary monitor)
#>
function Get-MonitorAtPoint {
    param(
        [Parameter(Mandatory)]
        [int]$X,

        [Parameter(Mandatory)]
        [int]$Y
    )

    $screens = Get-ScreenTopology

    for ($i = 0; $i -lt $screens.Count; $i++) {
        $screen = $screens[$i]
        if ($X -ge $screen.Left -and $X -lt ($screen.Left + $screen.Width) -and
            $Y -ge $screen.Top -and $Y -lt ($screen.Top + $screen.Height)) {
            return $i
        }
    }

    # Point outside all monitors - return primary (0)
    Write-MatrixLog "Point ($X, $Y) outside all monitors, defaulting to 0" -Source LAYOUT -Level DEBUG
    return 0
}

<#
.SYNOPSIS
    Get the maximum capacity for a monitor based on layout mode.

.DESCRIPTION
    Returns the maximum number of windows that can fit on a monitor
    based on the current layout mode (Pillars or Quads).

.PARAMETER MonitorIndex
    The monitor index (0-based)

.PARAMETER Mode
    Layout mode: 'Pillars', 'Quads', or 'Auto'

.OUTPUTS
    Integer - Maximum window capacity for the monitor

.EXAMPLE
    $capacity = Get-MonitorCapacity -MonitorIndex 0 -Mode 'Quads'
    # Returns: 4
#>
function Get-MonitorCapacity {
    param(
        [int]$MonitorIndex = 0,

        [ValidateSet('Pillars', 'Quads', 'Auto')]
        [string]$Mode = 'Auto'
    )

    $config = Get-MatrixLayoutConfig
    $effectiveMode = $Mode

    if ($effectiveMode -eq 'Auto') {
        $effectiveMode = if ($config.Mode) { $config.Mode } else { 'Pillars' }
    }

    switch ($effectiveMode) {
        'Pillars' {
            # Pillars mode uses MaxPillarsPerScreen
            if ($config.MaxPillarsPerScreen) { return $config.MaxPillarsPerScreen } else { return 4 }
        }
        'Quads' {
            # Quads mode is always 4 per monitor
            return 4
        }
        default {
            return 4
        }
    }
}

<#
.SYNOPSIS
    Get the current layout mode from configuration.

.DESCRIPTION
    Returns the effective layout mode, resolving 'Auto' to the actual mode.

.OUTPUTS
    String - 'Pillars' or 'Quads'

.EXAMPLE
    $mode = Get-CurrentLayoutMode
    # Returns: "Pillars"
#>
function Get-CurrentLayoutMode {
    $config = Get-MatrixLayoutConfig
    $mode = if ($config.Mode) { $config.Mode } else { 'Pillars' }

    if ($mode -eq 'Auto') {
        # For Auto, count current windows and decide
        $totalWindows = 0
        foreach ($key in $script:WindowMonitorAssignments.Keys) {
            $totalWindows++
        }
        if ($totalWindows -le 4) { return 'Pillars' } else { return 'Quads' }
    }

    return $mode
}

<#
.SYNOPSIS
    Get all windows currently assigned to a specific monitor.

.DESCRIPTION
    Returns an array of profile names (e.g., "Matrix-1", "Matrix-2") for
    windows that are currently on the specified monitor.

.PARAMETER MonitorIndex
    The monitor index (0-based)

.OUTPUTS
    Array of profile name strings

.EXAMPLE
    $windowsOnMon0 = Get-WindowsOnMonitor -MonitorIndex 0
    # Returns: @("Matrix-1", "Matrix-2", "Matrix-3")
#>
function Get-WindowsOnMonitor {
    param(
        [Parameter(Mandatory)]
        [int]$MonitorIndex
    )

    $windows = @()

    foreach ($profileName in $script:WindowMonitorAssignments.Keys) {
        $assignment = $script:WindowMonitorAssignments[$profileName]
        if ($assignment.MonitorIndex -eq $MonitorIndex) {
            $windows += $profileName
        }
    }

    Write-MatrixLog "Get-WindowsOnMonitor($MonitorIndex): Found $($windows.Count) windows - $($windows -join ', ')" -Source LAYOUT -Level DEBUG
    return $windows
}

<#
.SYNOPSIS
    Update the window-to-monitor assignment tracking.

.DESCRIPTION
    Scans all tracked windows and updates which monitor they are currently on
    based on their window center position. This keeps the assignment cache
    in sync with actual window positions.

.PARAMETER WindowHandles
    Hashtable where keys are profile names (e.g., "Matrix-1") and values
    contain Handle property

.EXAMPLE
    Update-WindowMonitorAssignments -WindowHandles $global:matrixWindowHandles
#>
function Update-WindowMonitorAssignments {
    param(
        [Parameter(Mandatory)]
        [hashtable]$WindowHandles
    )

    foreach ($profileName in $WindowHandles.Keys) {
        $entry = $WindowHandles[$profileName]
        $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }

        if (-not $handle -or $handle -eq [IntPtr]::Zero) { continue }

        try {
            $rect = New-Object WindowLayoutAPI+RECT
            if ([WindowLayoutAPI]::GetWindowRect($handle, [ref]$rect)) {
                # Calculate window center
                $centerX = $rect.Left + (($rect.Right - $rect.Left) / 2)
                $centerY = $rect.Top + (($rect.Bottom - $rect.Top) / 2)

                # Determine which monitor the center is on
                $monitorIdx = Get-MonitorAtPoint -X $centerX -Y $centerY

                # Update assignment
                $script:WindowMonitorAssignments[$profileName] = @{
                    Handle = $handle
                    MonitorIndex = $monitorIdx
                    X = $rect.Left
                    Y = $rect.Top
                    Width = $rect.Right - $rect.Left
                    Height = $rect.Bottom - $rect.Top
                    CenterX = $centerX
                    CenterY = $centerY
                }
            }
        }
        catch {
            Write-MatrixLog "Failed to update assignment for $profileName : $_" -Source LAYOUT -Level DEBUG
        }
    }

    Write-MatrixLog "Updated monitor assignments for $($WindowHandles.Count) windows" -Source LAYOUT -Level DEBUG
}

<#
.SYNOPSIS
    Enhanced drag detection with cross-monitor awareness.

.DESCRIPTION
    Detects if a window is being dragged and whether it has crossed
    from one monitor to another. Returns detailed information about
    the drag state including source and target monitors.

.PARAMETER WindowHandle
    The window handle to check

.PARAMETER ProfileName
    The profile name (e.g., "Matrix-3") of the window

.PARAMETER CurrentPosition
    Hashtable with current X, Y, Width, Height

.OUTPUTS
    Hashtable with:
    - IsDrag: $true if window was dragged significantly
    - FromMonitor: Source monitor index
    - ToMonitor: Target monitor index
    - CrossedMonitor: $true if monitors are different
    - DraggedProfileName: The profile name of the dragged window
    - Movement: Total pixels moved (Euclidean distance)

.EXAMPLE
    $dragInfo = Test-DragIntention -WindowHandle $hwnd -ProfileName "Matrix-3" -CurrentPosition @{X=100; Y=200; Width=400; Height=600}
    if ($dragInfo.IsDrag -and $dragInfo.CrossedMonitor) {
        # Handle cross-monitor drag
    }
#>
function Test-DragIntention {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [hashtable]$CurrentPosition
    )

    $result = @{
        IsDrag = $false
        FromMonitor = 0
        ToMonitor = 0
        CrossedMonitor = $false
        DraggedProfileName = $ProfileName
        Movement = 0
    }

    # Get last known position for this window
    $handleKey = $WindowHandle.ToString()
    if (-not $script:LastKnownPositions.ContainsKey($handleKey)) {
        Write-MatrixLog "No last known position for $ProfileName, initializing" -Source LAYOUT -Level DEBUG
        return $result
    }

    $lastKnown = $script:LastKnownPositions[$handleKey]

    # Calculate movement (Euclidean distance)
    $movement = [Math]::Sqrt(
        [Math]::Pow($CurrentPosition.X - $lastKnown.X, 2) +
        [Math]::Pow($CurrentPosition.Y - $lastKnown.Y, 2)
    )
    $result.Movement = $movement

    # Must move more than threshold
    if ($movement -lt $script:CrossMonitorDragThreshold) {
        return $result
    }

    $result.IsDrag = $true

    # Calculate window center for both positions
    $lastCenterX = $lastKnown.X + ($lastKnown.Width / 2)
    $lastCenterY = $lastKnown.Y + ($lastKnown.Height / 2)
    $currentCenterX = $CurrentPosition.X + ($CurrentPosition.Width / 2)
    $currentCenterY = $CurrentPosition.Y + ($CurrentPosition.Height / 2)

    # Determine monitors
    $result.FromMonitor = Get-MonitorAtPoint -X $lastCenterX -Y $lastCenterY
    $result.ToMonitor = Get-MonitorAtPoint -X $currentCenterX -Y $currentCenterY
    $result.CrossedMonitor = ($result.FromMonitor -ne $result.ToMonitor)

    Write-MatrixLog "Drag detected for $ProfileName : movement=$([int]$movement)px, from monitor $($result.FromMonitor) to $($result.ToMonitor), crossed=$($result.CrossedMonitor)" -Source LAYOUT -Level DEBUG

    return $result
}

<#
.SYNOPSIS
    Move a window to a specific monitor (update tracking only).

.DESCRIPTION
    Updates the internal tracking to associate a window with a new monitor.
    Does NOT physically move the window - that is done by Recalculate-AffectedLayouts.

.PARAMETER ProfileName
    The profile name (e.g., "Matrix-3")

.PARAMETER TargetMonitor
    The target monitor index

.EXAMPLE
    Move-WindowToMonitor -ProfileName "Matrix-2" -TargetMonitor 1
#>
function Move-WindowToMonitor {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [int]$TargetMonitor
    )

    if ($script:WindowMonitorAssignments.ContainsKey($ProfileName)) {
        $oldMonitor = $script:WindowMonitorAssignments[$ProfileName].MonitorIndex
        $script:WindowMonitorAssignments[$ProfileName].MonitorIndex = $TargetMonitor
        Write-MatrixLog "Moved $ProfileName from monitor $oldMonitor to $TargetMonitor (tracking only)" -Source LAYOUT
    }
    else {
        Write-MatrixLog "Cannot move $ProfileName - not in assignments" -Source LAYOUT -Level WARN
    }
}

<#
.SYNOPSIS
    Recalculate and apply layouts for affected monitors.

.DESCRIPTION
    Takes the current window-to-monitor assignments and recalculates
    the layout for each affected monitor, then physically positions
    the windows using SetWindowPos.

.PARAMETER MonitorIndices
    Array of monitor indices that need recalculation.
    If not specified, recalculates all monitors that have windows.

.PARAMETER WindowHandles
    Hashtable of window handles keyed by profile name.
    Required for physically positioning windows.

.EXAMPLE
    Recalculate-AffectedLayouts -MonitorIndices @(0, 1) -WindowHandles $global:matrixWindowHandles
#>
function Recalculate-AffectedLayouts {
    param(
        [array]$MonitorIndices = @(),

        [Parameter(Mandatory)]
        [hashtable]$WindowHandles
    )

    $config = Get-MatrixLayoutConfig
    $mode = Get-CurrentLayoutMode
    $gapSize = if ($config.GapSize) { $config.GapSize } else { 60 }
    $screens = Get-ScreenTopology

    # If no specific monitors specified, find all monitors with windows
    if ($MonitorIndices.Count -eq 0) {
        $affectedMonitors = @{}
        foreach ($profileName in $script:WindowMonitorAssignments.Keys) {
            $monIdx = $script:WindowMonitorAssignments[$profileName].MonitorIndex
            $affectedMonitors[$monIdx] = $true
        }
        $MonitorIndices = @($affectedMonitors.Keys)
    }

    Write-MatrixLog "Recalculating layouts for monitors: $($MonitorIndices -join ', ') (mode: $mode)" -Source LAYOUT

    # Process each monitor
    foreach ($monitorIdx in $MonitorIndices) {
        if ($monitorIdx -ge $screens.Count) {
            Write-MatrixLog "Monitor index $monitorIdx out of range (only $($screens.Count) screens)" -Source LAYOUT -Level WARN
            continue
        }

        $screen = $screens[$monitorIdx]
        $windowsOnMonitor = Get-WindowsOnMonitor -MonitorIndex $monitorIdx

        if ($windowsOnMonitor.Count -eq 0) {
            Write-MatrixLog "No windows on monitor $monitorIdx, skipping" -Source LAYOUT -Level DEBUG
            continue
        }

        # Sort windows by name for consistent ordering
        $sortedWindows = $windowsOnMonitor | Sort-Object

        # Calculate positions based on layout mode
        $positions = @()
        $windowCount = $sortedWindows.Count

        switch ($mode) {
            'Pillars' {
                $overlapPercent = if ($config.OverlapPercent) { $config.OverlapPercent } else { 5 }

                if ($windowCount -le 4) {
                    # 1-4 windows: Full height pillars side by side
                    $columns = $windowCount
                    $totalHGaps = ($columns + 1) * $gapSize
                    $cellWidth = [int](($screen.Width - $totalHGaps) / $columns)
                    $cellHeight = $screen.Height - (2 * $gapSize)

                    for ($i = 0; $i -lt $windowCount; $i++) {
                        $positions += @{
                            X = $screen.Left + $gapSize + ($i * ($cellWidth + $gapSize))
                            Y = $screen.Top + $gapSize
                            Width = $cellWidth
                            Height = $cellHeight
                        }
                    }
                }
                else {
                    # 5-8 windows: Grid layout with overlap between rows
                    # 5: 3+2, 6: 3+3, 7: 4+3, 8: 4+4
                    $topCount = [Math]::Ceiling($windowCount / 2)
                    $bottomCount = $windowCount - $topCount

                    # Calculate cell sizes
                    $topCols = $topCount
                    $bottomCols = $bottomCount

                    $totalHGapsTop = ($topCols + 1) * $gapSize
                    $totalHGapsBottom = ($bottomCols + 1) * $gapSize

                    $topCellWidth = [int](($screen.Width - $totalHGapsTop) / $topCols)
                    $bottomCellWidth = [int](($screen.Width - $totalHGapsBottom) / $bottomCols)

                    # Height calculation with overlap
                    $availableHeight = $screen.Height - (2 * $gapSize)
                    $cellHeight = [int]($availableHeight * 0.55)  # Slightly more than half for overlap
                    $overlapAmount = [int]($cellHeight * ($overlapPercent / 100))

                    $topY = $screen.Top + $gapSize
                    $bottomY = $screen.Top + $gapSize + $cellHeight - $overlapAmount

                    # Top row windows
                    for ($i = 0; $i -lt $topCount; $i++) {
                        $positions += @{
                            X = $screen.Left + $gapSize + ($i * ($topCellWidth + $gapSize))
                            Y = $topY
                            Width = $topCellWidth
                            Height = $cellHeight
                        }
                    }

                    # Bottom row windows
                    for ($i = 0; $i -lt $bottomCount; $i++) {
                        $positions += @{
                            X = $screen.Left + $gapSize + ($i * ($bottomCellWidth + $gapSize))
                            Y = $bottomY
                            Width = $bottomCellWidth
                            Height = $cellHeight
                        }
                    }
                }
            }
            'Quads' {
                # Quads: 2x2 grid with plus-shaped gap
                $halfWidth = [int](($screen.Width - (3 * $gapSize)) / 2)
                $halfHeight = [int](($screen.Height - (3 * $gapSize)) / 2)
                $cascadeOffset = 40  # Offset for cascaded windows 5-8

                $quadPositions = @(
                    @{ X = $screen.Left + $gapSize; Y = $screen.Top + $gapSize },
                    @{ X = $screen.Left + (2 * $gapSize) + $halfWidth; Y = $screen.Top + $gapSize },
                    @{ X = $screen.Left + $gapSize; Y = $screen.Top + (2 * $gapSize) + $halfHeight },
                    @{ X = $screen.Left + (2 * $gapSize) + $halfWidth; Y = $screen.Top + (2 * $gapSize) + $halfHeight }
                )

                # Windows 1-4: Base quad positions
                for ($i = 0; $i -lt [Math]::Min($windowCount, 4); $i++) {
                    $positions += @{
                        X = $quadPositions[$i].X
                        Y = $quadPositions[$i].Y
                        Width = $halfWidth
                        Height = $halfHeight
                    }
                }

                # Windows 5-8: Cascade on top of 1-4 respectively
                if ($windowCount -gt 4) {
                    for ($i = 4; $i -lt $windowCount; $i++) {
                        $baseIdx = $i - 4  # 5->0, 6->1, 7->2, 8->3
                        $positions += @{
                            X = $quadPositions[$baseIdx].X + $cascadeOffset
                            Y = $quadPositions[$baseIdx].Y + $cascadeOffset
                            Width = $halfWidth
                            Height = $halfHeight
                        }
                    }
                }
            }
        }

        # Apply positions to windows
        for ($i = 0; $i -lt $sortedWindows.Count; $i++) {
            $profileName = $sortedWindows[$i]
            $position = $positions[$i]

            if (-not $WindowHandles.ContainsKey($profileName)) {
                Write-MatrixLog "No handle found for $profileName" -Source LAYOUT -Level WARN
                continue
            }

            $entry = $WindowHandles[$profileName]
            $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }

            if (-not $handle -or $handle -eq [IntPtr]::Zero) {
                Write-MatrixLog "Invalid handle for $profileName" -Source LAYOUT -Level WARN
                continue
            }

            try {
                [WindowLayoutAPI]::SetWindowPos(
                    $handle,
                    [IntPtr]::Zero,
                    $position.X,
                    $position.Y,
                    $position.Width,
                    $position.Height,
                    ([WindowLayoutAPI]::SWP_NOZORDER -bor [WindowLayoutAPI]::SWP_SHOWWINDOW)
                ) | Out-Null

                Write-MatrixLog "Positioned $profileName on monitor $monitorIdx at ($($position.X), $($position.Y)) size $($position.Width)x$($position.Height)" -Source LAYOUT -Level DEBUG

                # Update the assignment with new position
                $script:WindowMonitorAssignments[$profileName].X = $position.X
                $script:WindowMonitorAssignments[$profileName].Y = $position.Y
                $script:WindowMonitorAssignments[$profileName].Width = $position.Width
                $script:WindowMonitorAssignments[$profileName].Height = $position.Height
            }
            catch {
                Write-MatrixLog "Failed to position $profileName : $_" -Source LAYOUT -Level ERROR
            }
        }
    }

    # Update position tracking after layout changes
    $handles = @()
    foreach ($profileName in $WindowHandles.Keys) {
        $entry = $WindowHandles[$profileName]
        $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }
        if ($handle -and $handle -ne [IntPtr]::Zero) {
            $handles += $handle
        }
    }
    Update-PositionTracking -WindowHandles $handles
}

<#
.SYNOPSIS
    The core dynamic accommodation function.

.DESCRIPTION
    Handles the logic when a window is dragged to a new monitor:
    1. If target monitor has room: just add the window
    2. If target monitor is at capacity: bump the least-used window to source monitor
    3. Recalculate layouts for all affected monitors

    This implements the "Accommodate, Don't Deport" principle - user intent is honored.

.PARAMETER DraggedWindow
    Hashtable with ProfileName and SourceMonitor of the dragged window

.PARAMETER TargetMonitor
    The monitor index where the window was dropped

.PARAMETER WindowHandles
    Hashtable of all window handles keyed by profile name

.OUTPUTS
    Hashtable with:
    - Success: $true if accommodation succeeded
    - Action: 'Added' | 'Swapped' | 'Expanded' | 'Failed'
    - BumpedWindow: Profile name of bumped window (if any)
    - AffectedMonitors: Array of monitor indices that were recalculated

.EXAMPLE
    $result = Invoke-DynamicAccommodation -DraggedWindow @{ProfileName="Matrix-3"; SourceMonitor=0} -TargetMonitor 1 -WindowHandles $handles
    if ($result.Success) {
        Write-Host "Window accommodated via $($result.Action)"
    }
#>
function Invoke-DynamicAccommodation {
    param(
        [Parameter(Mandatory)]
        [hashtable]$DraggedWindow,

        [Parameter(Mandatory)]
        [int]$TargetMonitor,

        [Parameter(Mandatory)]
        [hashtable]$WindowHandles
    )

    $result = @{
        Success = $false
        Action = 'Failed'
        BumpedWindow = $null
        AffectedMonitors = @()
    }

    $profileName = $DraggedWindow.ProfileName
    $sourceMonitor = $DraggedWindow.SourceMonitor

    Write-MatrixLog "=== Dynamic Accommodation ===" -Source LAYOUT
    Write-MatrixLog "Dragged: $profileName from monitor $sourceMonitor to monitor $TargetMonitor" -Source LAYOUT

    # Update state machine
    $script:AccommodationState = 'CALCULATING'

    # Get current windows on target monitor (excluding the dragged window if it's already counted)
    $windowsOnTarget = Get-WindowsOnMonitor -MonitorIndex $TargetMonitor
    $windowsOnTarget = $windowsOnTarget | Where-Object { $_ -ne $profileName }

    # Get capacity for target monitor
    $mode = Get-CurrentLayoutMode
    $capacity = Get-MonitorCapacity -MonitorIndex $TargetMonitor -Mode $mode

    Write-MatrixLog "Target monitor $TargetMonitor : $($windowsOnTarget.Count) windows (capacity: $capacity)" -Source LAYOUT

    # Check if target has room
    if ($windowsOnTarget.Count -lt $capacity) {
        # Room available - just move the window
        $script:AccommodationState = 'ACCOMMODATING'
        Write-MatrixLog "Target has room - adding window directly" -Source LAYOUT

        # Update tracking: move dragged window to target monitor
        Move-WindowToMonitor -ProfileName $profileName -TargetMonitor $TargetMonitor

        $result.Action = 'Added'
        $result.AffectedMonitors = @($sourceMonitor, $TargetMonitor) | Select-Object -Unique
    }
    else {
        # At capacity - need to bump a window
        $script:AccommodationState = 'BUMP_SELECTING'
        Write-MatrixLog "Target at capacity - selecting window to bump" -Source LAYOUT

        # Get least-used window on target (excluding priority-locked)
        $toBump = Get-LeastUsedWindow -MonitorIndex $TargetMonitor -ExcludePriorityLocked -WindowsOnMonitor $windowsOnTarget

        if ($toBump) {
            Write-MatrixLog "Bumping $toBump to make room for $profileName" -Source LAYOUT

            # Swap: bumped window goes to source monitor, dragged window goes to target
            Move-WindowToMonitor -ProfileName $toBump -TargetMonitor $sourceMonitor
            Move-WindowToMonitor -ProfileName $profileName -TargetMonitor $TargetMonitor

            $result.Action = 'Swapped'
            $result.BumpedWindow = $toBump
            $result.AffectedMonitors = @($sourceMonitor, $TargetMonitor) | Select-Object -Unique
        }
        else {
            # All windows on target are priority-locked - expand layout instead
            Write-MatrixLog "All windows priority-locked - expanding layout" -Source LAYOUT

            # Just add the window anyway (layout will accommodate by shrinking)
            Move-WindowToMonitor -ProfileName $profileName -TargetMonitor $TargetMonitor

            $result.Action = 'Expanded'
            $result.AffectedMonitors = @($sourceMonitor, $TargetMonitor) | Select-Object -Unique
        }
    }

    # Recalculate layouts for affected monitors
    $script:AccommodationState = 'ANIMATING'
    Recalculate-AffectedLayouts -MonitorIndices $result.AffectedMonitors -WindowHandles $WindowHandles

    # Finalize
    $script:AccommodationState = 'FINALIZING'
    $result.Success = $true

    Write-MatrixLog "Accommodation complete: $($result.Action)" -Source LAYOUT
    if ($result.BumpedWindow) {
        Write-MatrixLog "  Bumped window: $($result.BumpedWindow)" -Source LAYOUT
    }
    Write-MatrixLog "  Affected monitors: $($result.AffectedMonitors -join ', ')" -Source LAYOUT

    # Return to idle
    $script:AccommodationState = 'IDLE'

    return $result
}

<#
.SYNOPSIS
    Check if a window position is stable (not still being dragged).

.DESCRIPTION
    Samples the window position twice with a delay to verify the window
    has stopped moving. Returns $true if position is stable.

.PARAMETER WindowHandle
    The window handle to check

.PARAMETER StabilityDelayMs
    Milliseconds to wait between position checks (default: 150)

.PARAMETER TolerancePx
    Maximum pixels of movement to still consider stable (default: 10)

.OUTPUTS
    $true if position is stable, $false if still moving

.EXAMPLE
    if (Test-PositionStable -WindowHandle $hwnd) {
        # Window has stopped moving, safe to accommodate
    }
#>
function Test-PositionStable {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [int]$StabilityDelayMs = 150,

        [int]$TolerancePx = 10
    )

    try {
        # Get first position
        $rect1 = New-Object WindowLayoutAPI+RECT
        if (-not [WindowLayoutAPI]::GetWindowRect($WindowHandle, [ref]$rect1)) {
            return $false
        }

        # Wait for stability check
        Start-Sleep -Milliseconds $StabilityDelayMs

        # Get second position
        $rect2 = New-Object WindowLayoutAPI+RECT
        if (-not [WindowLayoutAPI]::GetWindowRect($WindowHandle, [ref]$rect2)) {
            return $false
        }

        # Check if position changed significantly
        $deltaX = [Math]::Abs($rect2.Left - $rect1.Left)
        $deltaY = [Math]::Abs($rect2.Top - $rect1.Top)

        $isStable = ($deltaX -le $TolerancePx -and $deltaY -le $TolerancePx)

        Write-MatrixLog "Position stability check: deltaX=$deltaX, deltaY=$deltaY, stable=$isStable" -Source LAYOUT -Level DEBUG

        return $isStable
    }
    catch {
        Write-MatrixLog "Position stability check failed: $_" -Source LAYOUT -Level DEBUG
        return $false
    }
}

<#
.SYNOPSIS
    Process potential drag events for all tracked windows.

.DESCRIPTION
    Main entry point for drag-snap monitoring. Checks all windows for
    drag events and triggers accommodation when a cross-monitor drag is detected.

.PARAMETER WindowHandles
    Hashtable of window handles keyed by profile name

.OUTPUTS
    Hashtable with:
    - DragDetected: $true if any window was dragged across monitors
    - ProcessedWindow: Profile name of the window that triggered accommodation
    - AccommodationResult: Result from Invoke-DynamicAccommodation (if triggered)

.EXAMPLE
    # Call periodically from monitor loop
    $result = Process-WindowDragEvents -WindowHandles $global:matrixWindowHandles
    if ($result.DragDetected) {
        Write-Host "Accommodated $($result.ProcessedWindow)"
    }

.NOTES
    This function is designed to be called repeatedly from a polling loop
    (e.g., every 200ms). It will only trigger accommodation when:
    1. A window has moved > 50px
    2. The window center has crossed to a different monitor
    3. The window position has stabilized (not still being dragged)
#>
function Process-WindowDragEvents {
    param(
        [Parameter(Mandatory)]
        [hashtable]$WindowHandles
    )

    $result = @{
        DragDetected = $false
        ProcessedWindow = $null
        AccommodationResult = $null
    }

    # First, update current positions
    $handles = @()
    foreach ($profileName in $WindowHandles.Keys) {
        $entry = $WindowHandles[$profileName]
        $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }
        if ($handle -and $handle -ne [IntPtr]::Zero) {
            $handles += $handle
        }
    }

    $currentPositions = Get-WindowPositions -WindowHandles $handles

    # Update window-monitor assignments
    Update-WindowMonitorAssignments -WindowHandles $WindowHandles

    # Check each window for drag
    foreach ($profileName in $WindowHandles.Keys) {
        $entry = $WindowHandles[$profileName]
        $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }

        if (-not $handle -or $handle -eq [IntPtr]::Zero) { continue }

        $handleKey = $handle.ToString()
        if (-not $currentPositions.ContainsKey($handleKey)) { continue }

        $currentPos = $currentPositions[$handleKey]

        # Check for drag intention
        $dragInfo = Test-DragIntention -WindowHandle $handle -ProfileName $profileName -CurrentPosition $currentPos

        if ($dragInfo.IsDrag) {
            # Check for overlap with other windows on the same monitor
            $hasOverlap = $false
            if (-not $dragInfo.CrossedMonitor) {
                # Check if this window overlaps with any other window on the same monitor
                foreach ($otherProfile in $WindowHandles.Keys) {
                    if ($otherProfile -eq $profileName) { continue }

                    $otherEntry = $WindowHandles[$otherProfile]
                    $otherHandle = if ($otherEntry -is [hashtable]) { $otherEntry.Handle } else { $otherEntry }
                    if (-not $otherHandle -or $otherHandle -eq [IntPtr]::Zero) { continue }

                    $otherKey = $otherHandle.ToString()
                    if (-not $currentPositions.ContainsKey($otherKey)) { continue }

                    $otherPos = $currentPositions[$otherKey]

                    # Check if windows overlap (bounding box intersection)
                    $overlapX = ($currentPos.X -lt ($otherPos.X + $otherPos.Width)) -and (($currentPos.X + $currentPos.Width) -gt $otherPos.X)
                    $overlapY = ($currentPos.Y -lt ($otherPos.Y + $otherPos.Height)) -and (($currentPos.Y + $currentPos.Height) -gt $otherPos.Y)

                    if ($overlapX -and $overlapY) {
                        $hasOverlap = $true
                        Write-MatrixLog "Same-monitor overlap detected: $profileName overlaps with $otherProfile" -Source LAYOUT
                        break
                    }
                }
            }

            # Trigger accommodation if cross-monitor OR same-monitor overlap
            if ($dragInfo.CrossedMonitor -or $hasOverlap) {
                $triggerReason = if ($dragInfo.CrossedMonitor) { "cross-monitor drag" } else { "same-monitor overlap" }
                Write-MatrixLog "Accommodation trigger: $profileName ($triggerReason)" -Source LAYOUT

                # Verify position is stable (user has finished dragging)
                if (Test-PositionStable -WindowHandle $handle) {
                    Write-MatrixLog "Position stable - triggering accommodation" -Source LAYOUT

                    # Trigger accommodation
                    $accommodationResult = Invoke-DynamicAccommodation -DraggedWindow @{
                        ProfileName = $profileName
                        SourceMonitor = $dragInfo.FromMonitor
                    } -TargetMonitor $dragInfo.ToMonitor -WindowHandles $WindowHandles

                    $result.DragDetected = $true
                    $result.ProcessedWindow = $profileName
                    $result.AccommodationResult = $accommodationResult

                    # Only process one drag per cycle to avoid race conditions
                    break
                }
                else {
                    Write-MatrixLog "Position not stable - user still dragging" -Source LAYOUT -Level DEBUG
                }
            }
        }
    }

    # Update last known positions for next cycle
    Update-PositionTracking -WindowHandles $handles

    return $result
}

<#
.SYNOPSIS
    Get a summary of current accommodation state.

.DESCRIPTION
    Returns a formatted string showing the current state of the
    dynamic accommodation system, including windows per monitor
    and any active drag operations.

.OUTPUTS
    String with formatted accommodation state

.EXAMPLE
    $summary = Get-AccommodationStateSummary
    Write-Host $summary
#>
function Get-AccommodationStateSummary {
    $screens = Get-ScreenTopology
    $mode = Get-CurrentLayoutMode

    $lines = @()
    $lines += "Dynamic Accommodation State"
    $lines += "=" * 40
    $lines += "State: $script:AccommodationState"
    $lines += "Mode: $mode"
    $lines += ""
    $lines += "Monitor Assignments:"

    for ($i = 0; $i -lt $screens.Count; $i++) {
        $windowsOnMon = Get-WindowsOnMonitor -MonitorIndex $i
        $capacity = Get-MonitorCapacity -MonitorIndex $i -Mode $mode
        $lines += "  Monitor $i : $($windowsOnMon.Count)/$capacity - $($windowsOnMon -join ', ')"
    }

    return ($lines -join "`n")
}

<#
.SYNOPSIS
    Initialize the accommodation system with current window state.

.DESCRIPTION
    Sets up the window-monitor assignments based on current window positions.
    Should be called when starting the monitor loop or after significant changes.

.PARAMETER WindowHandles
    Hashtable of window handles keyed by profile name

.EXAMPLE
    Initialize-AccommodationSystem -WindowHandles $global:matrixWindowHandles
#>
function Initialize-AccommodationSystem {
    param(
        [Parameter(Mandatory)]
        [hashtable]$WindowHandles
    )

    Write-MatrixLog "Initializing accommodation system..." -Source LAYOUT

    # Reset state
    $script:AccommodationState = 'IDLE'
    $script:WindowMonitorAssignments = @{}

    # Update assignments based on current positions
    Update-WindowMonitorAssignments -WindowHandles $WindowHandles

    # Initialize position tracking
    $handles = @()
    foreach ($profileName in $WindowHandles.Keys) {
        $entry = $WindowHandles[$profileName]
        $handle = if ($entry -is [hashtable]) { $entry.Handle } else { $entry }
        if ($handle -and $handle -ne [IntPtr]::Zero) {
            $handles += $handle
        }
    }
    Initialize-PositionTracking -WindowHandles $handles

    Write-MatrixLog "Accommodation system initialized with $($WindowHandles.Count) windows" -Source LAYOUT
    Write-MatrixLog (Get-AccommodationStateSummary) -Source LAYOUT -Level DEBUG
}
