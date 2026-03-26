$ErrorActionPreference = 'Stop'

# Generate shader HLSL files from the C# ShaderTemplate — single source of truth.
# Called by copy-fresh-build.ps1 instead of copying static files.

$TemplateFile = Join-Path $PSScriptRoot "..\MatrixShader\src\MatrixShader.Core\Constants\ShaderTemplate.cs"
$OutputDir = Join-Path $PSScriptRoot "publish\shaders"

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

# Extract the template string from ShaderTemplate.cs
$csContent = Get-Content $TemplateFile -Raw
if ($csContent -match '(?s)Template = @"(.+?)";') {
    $template = $matches[1]
} else {
    Write-Error "Could not extract template from ShaderTemplate.cs"
    exit 1
}

# Color presets (must match ColorPresets.cs)
$presets = @(
    @{ Slot=1; R="0.0"; G="1.0"; B="0.3" },   # Green
    @{ Slot=2; R="0.0"; G="0.6"; B="1.0" },   # Blue
    @{ Slot=3; R="1.0"; G="0.1"; B="0.1" },   # Red
    @{ Slot=4; R="0.7"; G="0.0"; B="1.0" },   # Purple
    @{ Slot=5; R="1.0"; G="0.7"; B="0.0" },   # Gold
    @{ Slot=6; R="0.0"; G="0.9"; B="0.9" },   # Teal
    @{ Slot=7; R="0.0"; G="1.0"; B="0.3" },   # Green (default)
    @{ Slot=8; R="0.0"; G="1.0"; B="0.3" }    # Green (default)
)

# ShaderConfig defaults (must match ShaderConfig.cs)
$defaults = @{
    SPEED = "0.8"
    GLOW  = "0.8"
    WIDTH = "10.0"
    TRAIL = "8.0"
    DENS  = "0.2"
    L1    = "1.0"
    L2    = "1.0"
    L3    = "1.0"
}

foreach ($preset in $presets) {
    $content = $template
    $content = $content.Replace("{SLOT}", "$($preset.Slot)")
    $content = $content.Replace("{R}", $preset.R)
    $content = $content.Replace("{G}", $preset.G)
    $content = $content.Replace("{B}", $preset.B)
    $content = $content.Replace("{SPEED}", $defaults.SPEED)
    $content = $content.Replace("{GLOW}", $defaults.GLOW)
    $content = $content.Replace("{WIDTH}", $defaults.WIDTH)
    $content = $content.Replace("{TRAIL}", $defaults.TRAIL)
    $content = $content.Replace("{DENS}", $defaults.DENS)
    $content = $content.Replace("{L1}", $defaults.L1)
    $content = $content.Replace("{L2}", $defaults.L2)
    $content = $content.Replace("{L3}", $defaults.L3)

    $outFile = Join-Path $OutputDir "Matrix-$($preset.Slot).hlsl"
    Set-Content -Path $outFile -Value $content -NoNewline -Encoding UTF8
    Write-Host "  Generated: Matrix-$($preset.Slot).hlsl" -ForegroundColor Green
}

# Copy non-generated shaders (Redpill-Neo, WhiteRoom, etc.) from source
$srcShaders = Join-Path $PSScriptRoot "..\MatrixShader\shaders"
Get-ChildItem -Path $srcShaders -Filter "*.hlsl" | Where-Object { $_.Name -notmatch "^Matrix-\d+\.hlsl$" } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $OutputDir $_.Name) -Force
    Write-Host "  Copied: $($_.Name)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Shaders generated from ShaderTemplate.cs (single source of truth)" -ForegroundColor Yellow
