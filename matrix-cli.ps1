<# Matrix CLI - Command-line control for Matrix shader
Usage:
  matrix-cli color R G B     - Set RGB color (0.0-1.0 floats)
  matrix-cli color #RRGGBB   - Set color from hex
  matrix-cli speed N         - Set rain speed
  matrix-cli glow N          - Set glow strength
  matrix-cli status          - Show current slot settings
#>

param(
    [Parameter(Position=0)]
    [string]$Command,
    [Parameter(Position=1)]
    [string]$Arg1,
    [Parameter(Position=2)]
    [string]$Arg2,
    [Parameter(Position=3)]
    [string]$Arg3
)

$ErrorActionPreference = "Stop"

# Paths
$BaseDir = "C:\Users\ehome\Documents\Matrix"
$ConfigPath = Join-Path $BaseDir "config\slots.json"
$ShadersDir = Join-Path $BaseDir "shaders"

# Get current slot from environment
$Slot = $env:MATRIX_SLOT
if (-not $Slot) {
    Write-Error "MATRIX_SLOT environment variable not set. Set it to a slot number (1-8) before running."
    exit 1
}

# Validate slot number
if ($Slot -notmatch '^[1-8]$') {
    Write-Error "MATRIX_SLOT must be 1-8, got: $Slot"
    exit 1
}

$ShaderPath = Join-Path $ShadersDir "Matrix-$Slot.hlsl"

# Load config
function Get-Config {
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

# Save config
function Save-Config($config) {
    $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
}

# Get slot settings
function Get-SlotSettings {
    $config = Get-Config
    return $config.slots.$Slot
}

# Update shader file with new settings
function Update-Shader($settings) {
    if (-not (Test-Path $ShaderPath)) {
        Write-Error "Shader file not found: $ShaderPath"
        exit 1
    }

    $content = Get-Content $ShaderPath -Raw

    # Update #define values using regex
    $content = $content -replace '(#define\s+RAIN_R\s+)[\d.]+', "`$1$($settings.r)"
    $content = $content -replace '(#define\s+RAIN_G\s+)[\d.]+', "`$1$($settings.g)"
    $content = $content -replace '(#define\s+RAIN_B\s+)[\d.]+', "`$1$($settings.b)"
    $content = $content -replace '(#define\s+RAIN_SPEED\s+)[\d.]+', "`$1$($settings.speed)"
    $content = $content -replace '(#define\s+GLOW_STRENGTH\s+)[\d.]+', "`$1$($settings.glow)"

    # Write back and touch timestamp
    Set-Content $ShaderPath $content -NoNewline -Encoding UTF8
    (Get-Item $ShaderPath).LastWriteTime = Get-Date

    Write-Host "Updated shader: $ShaderPath"
}

# Parse hex color to RGB floats
function ConvertFrom-HexColor($hex) {
    $hex = $hex.TrimStart('#')
    if ($hex.Length -ne 6) {
        Write-Error "Invalid hex color format. Use #RRGGBB"
        exit 1
    }
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0
    return @{ r = [math]::Round($r, 3); g = [math]::Round($g, 3); b = [math]::Round($b, 3) }
}

# Commands
switch ($Command) {
    "color" {
        $config = Get-Config
        $settings = $config.slots.$Slot

        if ($Arg1 -match '^#') {
            # Hex color
            $rgb = ConvertFrom-HexColor $Arg1
            $settings.r = $rgb.r
            $settings.g = $rgb.g
            $settings.b = $rgb.b
        } elseif ($Arg1 -and $Arg2 -and $Arg3) {
            # RGB floats
            $settings.r = [double]$Arg1
            $settings.g = [double]$Arg2
            $settings.b = [double]$Arg3
        } else {
            Write-Error "Usage: matrix-cli color R G B  or  matrix-cli color #RRGGBB"
            exit 1
        }

        $config.slots.$Slot = $settings
        Save-Config $config
        Update-Shader $settings
        Write-Host "Color set to RGB($($settings.r), $($settings.g), $($settings.b))"
    }

    "speed" {
        if (-not $Arg1) {
            Write-Error "Usage: matrix-cli speed N"
            exit 1
        }
        $config = Get-Config
        $settings = $config.slots.$Slot
        $settings.speed = [double]$Arg1
        $config.slots.$Slot = $settings
        Save-Config $config
        Update-Shader $settings
        Write-Host "Speed set to $($settings.speed)"
    }

    "glow" {
        if (-not $Arg1) {
            Write-Error "Usage: matrix-cli glow N"
            exit 1
        }
        $config = Get-Config
        $settings = $config.slots.$Slot
        $settings.glow = [double]$Arg1
        $config.slots.$Slot = $settings
        Save-Config $config
        Update-Shader $settings
        Write-Host "Glow set to $($settings.glow)"
    }

    "status" {
        $settings = Get-SlotSettings
        Write-Host "Matrix Shader - Slot $Slot"
        Write-Host "  Color: RGB($($settings.r), $($settings.g), $($settings.b))"
        Write-Host "  Speed: $($settings.speed)"
        Write-Host "  Glow:  $($settings.glow)"
        Write-Host "  Scale: $($settings.scale)"
        Write-Host "  Width: $($settings.width)"
        Write-Host "  Trail: $($settings.trail)"
        Write-Host "  Density: $($settings.density)"
        Write-Host "  Layers: L1=$($settings.l1) L2=$($settings.l2) L3=$($settings.l3)"
        Write-Host "  Shader: $ShaderPath"
    }

    default {
        Write-Host "Matrix CLI - Control Matrix shader from command line"
        Write-Host ""
        Write-Host "Usage:"
        Write-Host "  matrix-cli color R G B     - Set RGB color (0.0-1.0 floats)"
        Write-Host "  matrix-cli color #RRGGBB   - Set color from hex"
        Write-Host "  matrix-cli speed N         - Set rain speed"
        Write-Host "  matrix-cli glow N          - Set glow strength"
        Write-Host "  matrix-cli status          - Show current slot settings"
        Write-Host ""
        Write-Host "Environment:"
        Write-Host "  MATRIX_SLOT = $Slot"
        if (-not $Command) {
            exit 0
        } else {
            Write-Error "Unknown command: $Command"
            exit 1
        }
    }
}
