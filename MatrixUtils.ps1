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

<#
.SYNOPSIS
    Extract the rain color from a shader file.

.DESCRIPTION
    Parses the HLSL shader file to extract RAIN_R, RAIN_G, RAIN_B values.
    Returns the color as RGB floats (0.0-1.0).

.PARAMETER ShaderPath
    Full path to the .hlsl shader file.

.OUTPUTS
    Hashtable with R, G, B properties (floats 0.0-1.0), or $null if not found.

.EXAMPLE
    $color = Get-ShaderColor "C:\Users\ehome\Documents\Matrix\shaders\Matrix-1.hlsl"
    Write-Host "Red: $($color.R), Green: $($color.G), Blue: $($color.B)"
#>
function Get-ShaderColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShaderPath
    )

    if (-not (Test-Path $ShaderPath)) {
        return $null
    }

    try {
        $content = Get-Content $ShaderPath -Raw

        $r = 0.0
        $g = 1.0
        $b = 0.3

        if ($content -match '#define\s+RAIN_R\s+([\d.]+)') {
            $r = [float]$Matches[1]
        }
        if ($content -match '#define\s+RAIN_G\s+([\d.]+)') {
            $g = [float]$Matches[1]
        }
        if ($content -match '#define\s+RAIN_B\s+([\d.]+)') {
            $b = [float]$Matches[1]
        }

        return @{
            R = $r
            G = $g
            B = $b
        }
    }
    catch {
        return $null
    }
}

<#
.SYNOPSIS
    Convert RGB floats to a hex color string.

.DESCRIPTION
    Converts RGB values (0.0-1.0) to a hex color string like "#00FF4C".

.PARAMETER R
    Red component (0.0 to 1.0)

.PARAMETER G
    Green component (0.0 to 1.0)

.PARAMETER B
    Blue component (0.0 to 1.0)

.OUTPUTS
    Hex color string like "#00FF4C"

.EXAMPLE
    $hex = Convert-RGBToHex 0.0 1.0 0.3
    # Returns "#00FF4C"
#>
function Convert-RGBToHex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [float]$R,

        [Parameter(Mandatory)]
        [float]$G,

        [Parameter(Mandatory)]
        [float]$B
    )

    $r8 = [int]([Math]::Min(255, [Math]::Max(0, $R * 255)))
    $g8 = [int]([Math]::Min(255, [Math]::Max(0, $G * 255)))
    $b8 = [int]([Math]::Min(255, [Math]::Max(0, $B * 255)))

    return "#{0:X2}{1:X2}{2:X2}" -f $r8, $g8, $b8
}

<#
.SYNOPSIS
    Update a Windows Terminal profile's tab color to match the shader color.

.DESCRIPTION
    Reads the shader file, extracts its color, and updates the corresponding
    profile's tabColor in Windows Terminal settings.json.

.PARAMETER ProfileName
    The profile name (e.g., "Matrix-1")

.PARAMETER ShaderPath
    Full path to the shader file (optional - will be auto-detected from profile name)

.EXAMPLE
    Sync-TabColorToShader -ProfileName "Matrix-1"
#>
function Sync-TabColorToShader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [string]$ShaderPath
    )

    $paths = Get-MatrixPaths
    $wtSettingsPath = $paths.WTSettings

    # Auto-detect shader path if not provided
    if (-not $ShaderPath) {
        if ($ProfileName -match 'Matrix-(\d+)') {
            $slot = $Matches[1]
            $ShaderPath = Join-Path $paths.ShadersDir "Matrix-$slot.hlsl"
        } else {
            return $false
        }
    }

    # Get color from shader
    $color = Get-ShaderColor -ShaderPath $ShaderPath
    if (-not $color) {
        return $false
    }

    # Convert to hex
    $hexColor = Convert-RGBToHex -R $color.R -G $color.G -B $color.B

    # Update Windows Terminal settings
    try {
        $wt = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

        $updated = $false
        foreach ($profile in $wt.profiles.list) {
            if ($profile.name -eq $ProfileName) {
                # Add or update tabColor
                if ($profile.PSObject.Properties['tabColor']) {
                    $profile.tabColor = $hexColor
                } else {
                    $profile | Add-Member -NotePropertyName 'tabColor' -NotePropertyValue $hexColor -Force
                }
                $updated = $true
                break
            }
        }

        if ($updated) {
            # Atomic write
            $tempFile = [System.IO.Path]::GetTempFileName()
            $wt | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding UTF8
            Move-Item -Path $tempFile -Destination $wtSettingsPath -Force
            return $true
        }
    }
    catch {
        # Clean up temp file on error
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }

    return $false
}

<#
.SYNOPSIS
    Sync all Matrix profile tab colors to their shader colors.

.DESCRIPTION
    Updates tabColor for all Matrix-1 through Matrix-8 profiles based on
    their current shader color values.

.EXAMPLE
    Sync-AllTabColors
#>
function Sync-AllTabColors {
    [CmdletBinding()]
    param()

    $paths = Get-MatrixPaths
    $synced = 0

    for ($i = 1; $i -le 8; $i++) {
        $profileName = "Matrix-$i"
        $shaderPath = Join-Path $paths.ShadersDir "Matrix-$i.hlsl"

        if (Test-Path $shaderPath) {
            if (Sync-TabColorToShader -ProfileName $profileName -ShaderPath $shaderPath) {
                $synced++
            }
        }
    }

    return $synced
}

# Note: This file is designed to be dot-sourced, not imported as a module
