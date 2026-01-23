# MatrixUtils.ps1
# Shared utility functions for Matrix Terminal Shader
# Used by: matrix_setup.ps1, matrix_control.ps1, bluepill.ps1

<#
.SYNOPSIS
    Create a colored swatch block for terminal display.

.DESCRIPTION
    Generates an ANSI escape sequence that renders a colored rectangle
    using 24-bit RGB background color.

.PARAMETER R
    Red component (0.0 to 1.0)

.PARAMETER G
    Green component (0.0 to 1.0)

.PARAMETER B
    Blue component (0.0 to 1.0)

.PARAMETER Width
    Width of the swatch in characters. Default is 2.

.EXAMPLE
    Write-Host "Color: $(Get-ColorSwatch 1.0 0.0 0.0 3)"  # Red swatch, 3 chars wide
#>
function Get-ColorSwatch {
    param(
        [Parameter(Mandatory)]
        [float]$R,

        [Parameter(Mandatory)]
        [float]$G,

        [Parameter(Mandatory)]
        [float]$B,

        [int]$Width = 2
    )

    $r8 = [int]([Math]::Min(255, [Math]::Max(0, $R * 255)))
    $g8 = [int]([Math]::Min(255, [Math]::Max(0, $G * 255)))
    $b8 = [int]([Math]::Min(255, [Math]::Max(0, $B * 255)))

    return "$([char]27)[48;2;${r8};${g8};${b8}m$(' ' * $Width)$([char]27)[0m"
}

# Alias for backward compatibility with existing code (Global scope for dot-sourcing)
Set-Alias -Name Swatch -Value Get-ColorSwatch -Scope Global

<#
.SYNOPSIS
    Get the dimensions of the primary screen's working area.

.DESCRIPTION
    Returns the usable screen dimensions (excluding taskbar) for the primary monitor.
    Uses System.Windows.Forms.Screen to detect screen properties.

.OUTPUTS
    Hashtable with Width, Height, Left, Top properties.

.EXAMPLE
    $screen = Get-PrimaryScreenDimensions
    Write-Host "Screen: $($screen.Width)x$($screen.Height)"
#>
function Get-PrimaryScreenDimensions {
    [CmdletBinding()]
    param()

    # Ensure Windows Forms assembly is loaded
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        return @{
            Width  = $screen.WorkingArea.Width
            Height = $screen.WorkingArea.Height
            Left   = $screen.WorkingArea.X
            Top    = $screen.WorkingArea.Y
        }
    }
    catch {
        # Fallback to reasonable defaults if screen detection fails
        return @{
            Width  = 1920
            Height = 1040
            Left   = 0
            Top    = 0
        }
    }
}

# Alias for backward compatibility (Global scope for dot-sourcing)
Set-Alias -Name Get-ScreenDimensions -Value Get-PrimaryScreenDimensions -Scope Global

<#
.SYNOPSIS
    Common paths used throughout the Matrix system.

.DESCRIPTION
    Centralized path definitions to avoid hardcoding paths in multiple files.
#>
$script:MatrixPaths = @{
    MatrixDir       = "$env:USERPROFILE\Documents\Matrix"
    ShadersDir      = "$env:USERPROFILE\Documents\Matrix\shaders"
    StateFile       = "$env:USERPROFILE\Documents\Matrix\matrix_state.json"
    DebugLog        = "$env:USERPROFILE\Documents\Matrix\debug.log"
    IdentityRegistry = "$env:USERPROFILE\Documents\Matrix\identity-registry.json"
    WTSettings      = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
}

<#
.SYNOPSIS
    Get Matrix system paths.

.EXAMPLE
    $paths = Get-MatrixPaths
    $shadersDir = $paths.ShadersDir
#>
function Get-MatrixPaths {
    return $script:MatrixPaths
}

# Note: This file is designed to be dot-sourced, not imported as a module
