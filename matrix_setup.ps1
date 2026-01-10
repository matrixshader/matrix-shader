# MATRIX SETUP WIZARD - wakeupneo

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$shadersDir = "$matrixDir\shaders"
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

$shaderTemplate = @'
// MATRIX SHADER - SLOT {SLOT}
#define RAIN_R         {R}
#define RAIN_G         {G}
#define RAIN_B         {B}
#define RAIN_SPEED     {SPEED}
#define GLOW_STRENGTH  {GLOW}
#define FONT_SCALE     1.0
#define CHAR_WIDTH     {WIDTH}
#define TRAIL_POWER    {TRAIL}
#define RAIN_DENSITY   {DENS}
#define SHOW_L1        1.0
#define SHOW_L2        1.0
#define SHOW_L3        1.0

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

static const uint GLYPHS[16] = {
    ((10u<<30)|(4u<<25)|(4u<<20)|(10u<<15)|(17u<<10)|(17u<<5)|14u),
    ((16u<<30)|(8u<<25)|(4u<<20)|(2u<<15)|(1u<<10)|(4u<<5)|4u),
    ((14u<<30)|(17u<<25)|(17u<<20)|(16u<<15)|(16u<<10)|(16u<<5)|31u),
    ((31u<<30)|(4u<<25)|(4u<<20)|(4u<<15)|(4u<<10)|(4u<<5)|31u),
    ((4u<<30)|(31u<<25)|(4u<<20)|(5u<<15)|(5u<<10)|(9u<<5)|17u),
    ((12u<<30)|(18u<<25)|(2u<<20)|(4u<<15)|(8u<<10)|(16u<<5)|31u),
    ((4u<<30)|(31u<<25)|(4u<<20)|(31u<<15)|(4u<<10)|(4u<<5)|4u),
    ((14u<<30)|(17u<<25)|(1u<<20)|(2u<<15)|(4u<<10)|(8u<<5)|16u),
    ((1u<<30)|(2u<<25)|(31u<<20)|(4u<<15)|(8u<<10)|(16u<<5)|16u),
    ((31u<<30)|(1u<<25)|(1u<<20)|(1u<<15)|(1u<<10)|(1u<<5)|31u),
    ((10u<<30)|(10u<<25)|(31u<<20)|(10u<<15)|(2u<<10)|(4u<<5)|8u),
    ((16u<<30)|(4u<<25)|(1u<<20)|(0u<<15)|(17u<<10)|(10u<<5)|4u),
    ((31u<<30)|(1u<<25)|(2u<<20)|(4u<<15)|(8u<<10)|(8u<<5)|8u),
    ((4u<<30)|(4u<<25)|(31u<<20)|(4u<<15)|(31u<<10)|(4u<<5)|4u),
    ((4u<<30)|(4u<<25)|(10u<<20)|(10u<<15)|(17u<<10)|(17u<<5)|17u),
    ((31u<<30)|(1u<<25)|(31u<<20)|(1u<<15)|(31u<<10)|(1u<<5)|31u)
};

float random(float2 uv) { return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123); }

float getGlyphPixel(int glyph_idx, float2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> bit_idx) & 1u);
}

float3 DrawLayer(float2 uv, float depth, float speed_mult, float brightness, float seed_shift) {
    float2 layer_uv = (uv * depth) + float2(seed_shift, seed_shift);
    float2 baseCharSize = float2(CHAR_WIDTH, 14.0) * max(0.001, FONT_SCALE);
    float2 grid_dims = Resolution / baseCharSize;
    float2 grid_uv = layer_uv * grid_dims;
    float2 cell_id = floor(grid_uv);
    float2 local_uv = frac(grid_uv);
    float char_seed = random(cell_id + floor(Time * 4.0) + depth);
    int glyph_idx = int(char_seed * 16.0);
    float2 padded_uv = (local_uv - 0.1) / 0.8;
    padded_uv = clamp(padded_uv, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded_uv);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9) * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;
    float col_rnd = random(float2(cell_id.x, seed_shift));
    if (col_rnd > RAIN_DENSITY) return float3(0,0,0);
    float final_speed = ((col_rnd * 0.5 + 0.2) * 10.0 * RAIN_SPEED * speed_mult) / depth;
    float rain_pos = cell_id.y - (Time * final_speed) + (col_rnd * 1000.0);
    float cycle = frac(rain_pos / grid_dims.y * 1.5);
    float trail = pow(cycle, TRAIL_POWER);
    float is_head = step(0.97, cycle);
    float3 userColor = float3(RAIN_R, RAIN_G, RAIN_B);
    float3 whiteHead = float3(0.9, 1.0, 0.9);
    return lerp(userColor, whiteHead, is_head) * trail * shape * brightness;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
    float3 totalRain = float3(0,0,0);
    if (SHOW_L1 > 0.5) totalRain += DrawLayer(tex, 1.5, 0.8, 0.3, 100.0);
    if (SHOW_L2 > 0.5) totalRain += DrawLayer(tex, 1.2, 0.9, 0.6, 200.0);
    if (SHOW_L3 > 0.5) totalRain += DrawLayer(tex, 0.9, 1.0, 1.0, 300.0);
    float4 text = shaderTexture.Sample(samplerState, tex);
    return text + float4(totalRain * GLOW_STRENGTH, 0.0);
}
'@

$defaults = @{ R="0.0"; G="1.0"; B="0.3"; Speed="0.8"; Glow="0.8"; Width="10.0"; Trail="8.0"; Dens="0.4" }

$presets = @{
    '1' = @{ Name="Classic"; R="0.0"; G="1.0"; B="0.3" }
    '2' = @{ Name="Cyber";   R="0.0"; G="0.6"; B="1.0" }
    '3' = @{ Name="Blood";   R="1.0"; G="0.1"; B="0.1" }
    '4' = @{ Name="Purple";  R="0.7"; G="0.0"; B="1.0" }
    '5' = @{ Name="Gold";    R="1.0"; G="0.7"; B="0.0" }
    '6' = @{ Name="Cyan";    R="0.0"; G="0.9"; B="0.9" }
}

function Swatch($r,$g,$b,$w) {
    "$([char]27)[48;2;$([int]([float]$r*255));$([int]([float]$g*255));$([int]([float]$b*255))m$(' '*$w)$([char]27)[0m"
}

function Write-Shader($slot, $cfg) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    $content = $shaderTemplate -replace '\{SLOT\}',$slot -replace '\{R\}',$cfg.R -replace '\{G\}',$cfg.G -replace '\{B\}',$cfg.B `
        -replace '\{SPEED\}',$cfg.Speed -replace '\{GLOW\}',$cfg.Glow -replace '\{WIDTH\}',$cfg.Width `
        -replace '\{TRAIL\}',$cfg.Trail -replace '\{DENS\}',$cfg.Dens
    [System.IO.File]::WriteAllText($path, $content)
}

# Window Positioning API
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowPositioning {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_SHOWWINDOW = 0x0040;
}
"@ -ErrorAction SilentlyContinue

function Get-ScreenDimensions {
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    return @{
        Width = $screen.WorkingArea.Width
        Height = $screen.WorkingArea.Height
        Left = $screen.WorkingArea.Left
        Top = $screen.WorkingArea.Top
    }
}

function Position-MatrixWindows([int]$WindowCount) {
    # Wait for windows to fully initialize
    Start-Sleep -Milliseconds 500

    $screen = Get-ScreenDimensions

    # Calculate gap size based on window count
    # 2 windows = 150px gap, 4 windows = 75px gap, etc.
    $gapSize = [int](300 / $WindowCount)
    if ($gapSize -lt 50) { $gapSize = 50 }

    # Calculate window width
    $totalGaps = ($WindowCount + 1) * $gapSize
    $windowWidth = [int](($screen.Width - $totalGaps) / $WindowCount)

    # Find Windows Terminal windows
    $wtProcesses = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
    if (-not $wtProcesses) {
        Write-Host "   Could not find Windows Terminal processes" -ForegroundColor Yellow
        return
    }

    # Get main window handles
    $handles = @()
    foreach ($proc in $wtProcesses) {
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $handles += $proc.MainWindowHandle
        }
    }

    # Position each window
    $positioned = 0
    foreach ($handle in $handles) {
        if ($positioned -ge $WindowCount) { break }

        $x = $screen.Left + $gapSize + ($positioned * ($windowWidth + $gapSize))
        $y = $screen.Top

        [WindowPositioning]::SetWindowPos(
            $handle,
            [IntPtr]::Zero,
            $x, $y,
            $windowWidth, $screen.Height,
            [WindowPositioning]::SWP_NOZORDER -bor [WindowPositioning]::SWP_SHOWWINDOW
        ) | Out-Null

        $positioned++
    }

    Write-Host "   Positioned $positioned windows" -ForegroundColor DarkGray
}

function Update-ProfileShaderPath([int]$Slot) {
    # Updates Windows Terminal settings.json so Matrix-$Slot profile points to shaders/Matrix-$Slot.hlsl
    if (-not (Test-Path $wtSettingsPath)) {
        Write-Host "   WARNING: Windows Terminal settings.json not found" -ForegroundColor Yellow
        return
    }

    try {
        $content = Get-Content $wtSettingsPath -Raw -Encoding UTF8
        $settings = $content | ConvertFrom-Json

        $shaderPath = "$shadersDir\Matrix-$Slot.hlsl"
        $updated = $false

        for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
            if ($settings.profiles.list[$i].name -eq "Matrix-$Slot") {
                $settings.profiles.list[$i].'experimental.pixelShaderPath' = $shaderPath
                $updated = $true
                break
            }
        }

        if ($updated) {
            $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
        }
    } catch {
        Write-Host "   WARNING: Failed to update profile path: $_" -ForegroundColor Yellow
    }
}


# Ensure shaders directory exists
if (-not (Test-Path $shadersDir)) {
    New-Item -ItemType Directory -Path $shadersDir -Force | Out-Null
}

# MAIN
Clear-Host
Write-Host ""
Write-Host " WAKE UP, NEO..." -ForegroundColor Green
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host ""

$numInput = Read-Host " How many Matrix tabs? (1-8)"
$numTabs = [Math]::Max(1, [Math]::Min(8, [int]$numInput))

$tabConfigs = @()

for ($i = 1; $i -le $numTabs; $i++) {
    Clear-Host
    Write-Host ""
    Write-Host " TAB $i OF $numTabs" -ForegroundColor Green
    Write-Host " ========================================" -ForegroundColor DarkGray
    Write-Host ""
    foreach ($k in ('1','2','3','4','5','6')) {
        $p = $presets[$k]
        Write-Host "   [$k] $(Swatch $p.R $p.G $p.B 2) $($p.Name)"
    }
    Write-Host ""

    $choice = Read-Host " Color (1-6)"
    if (-not $choice -or -not $presets.ContainsKey($choice)) { $choice = '1' }
    $color = $presets[$choice]

    $cfg = $defaults.Clone()
    $cfg.R = $color.R
    $cfg.G = $color.G
    $cfg.B = $color.B

    $cfg['Slot'] = $i
    $cfg['Name'] = $color.Name
    $tabConfigs += $cfg

    Write-Host ""
    Write-Host " Tab ${i} - $(Swatch $cfg.R $cfg.G $cfg.B 2) $($color.Name)" -ForegroundColor Cyan
    Start-Sleep -Milliseconds 300
}

# Summary
Clear-Host
Write-Host ""
Write-Host " THE MATRIX HAS YOU..." -ForegroundColor Green
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host ""
foreach ($cfg in $tabConfigs) {
    Write-Host "   Tab $($cfg.Slot): $(Swatch $cfg.R $cfg.G $cfg.B 2) $($cfg.Name)"
}
Write-Host ""
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   [1] " -NoNewline -ForegroundColor White
Write-Host "BLUE PILL" -NoNewline -ForegroundColor Blue
Write-Host " - Enter the Matrix" -ForegroundColor DarkGray
Write-Host "   [2] " -NoNewline -ForegroundColor White
Write-Host "RED PILL" -NoNewline -ForegroundColor Red
Write-Host " - Full Customization" -ForegroundColor DarkGray
Write-Host ""
$choice = Read-Host " Choose your path (1/2)"
if ($choice -eq '2') {
    # Red Pill - launch TUI with current config
    Write-Host ""
    Write-Host " Follow the white rabbit..." -ForegroundColor Green
    Start-Sleep -Milliseconds 500
    & "$matrixDir\matrix_tool.ps1" -SkipStartup
    exit
}
if ($choice -eq 'q' -or $choice -eq 'Q') { exit }

Write-Host ""
Write-Host " Creating shaders..." -ForegroundColor Cyan

foreach ($cfg in $tabConfigs) {
    Write-Shader $cfg.Slot $cfg
    Update-ProfileShaderPath $cfg.Slot
    Write-Host "   Matrix-$($cfg.Slot).hlsl -> profile updated" -ForegroundColor DarkGray
}

# Wait a moment before opening windows
Start-Sleep -Milliseconds 500

Write-Host ""
Write-Host " Opening windows..." -ForegroundColor Cyan

foreach ($cfg in $tabConfigs) {
    $slot = $cfg.Slot
    $pname = "Matrix-$slot"
    Write-Host "   Opening $pname..." -ForegroundColor DarkGray
    Start-Process wt -ArgumentList "-p `"$pname`""
    Start-Sleep -Milliseconds 1500
}

Write-Host ""
Write-Host " Positioning windows..." -ForegroundColor Cyan
Position-MatrixWindows $numTabs

Write-Host ""
Write-Host " FOLLOW THE WHITE RABBIT." -ForegroundColor Green
Write-Host " Type 'redpill' for live controls." -ForegroundColor DarkGray
Start-Sleep -Seconds 2
