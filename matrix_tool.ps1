# ======================================================
# MATRIX MASTER CONTROL v2.0
# Authentic Katakana-style characters + Enhanced UI
# ======================================================
$shaderPath = "$env:USERPROFILE\Documents\Matrix\Matrix.hlsl"

# --- SHADER TEMPLATE ---
$shaderTemplate = @"
// MATRIX SETTINGS
#define RAIN_R         {R}
#define RAIN_G         {G}
#define RAIN_B         {B}
#define RAIN_SPEED     {SPEED}
#define GLOW_STRENGTH  {GLOW}
#define FONT_SCALE     {SCALE}
#define CHAR_WIDTH     {WIDTH}
#define TRAIL_POWER    {TRAIL}
#define RAIN_DENSITY   {DENS}
// LAYER TOGGLES
#define SHOW_L1        {L1}
#define SHOW_L2        {L2}
#define SHOW_L3        {L3}

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// ============================================================
// MATRIX GLYPH DEFINITIONS - 16 Katakana-inspired characters
// Each glyph is 5 wide x 7 tall, encoded as 35 bits in a uint
// ============================================================
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
"@

# --- DEFAULT VALUES ---
$defaults = @{ R="0.0"; G="1.0"; B="0.2"; Speed="1.0"; Glow="1.5"; Scale="1.0"; Width="8.0"; Trail="8.0"; Dens="1.0"; L1="1.0"; L2="1.0"; L3="1.0" }

# --- PRESET DEFINITIONS ---
$presets = @{
    '1' = @{ Name="Classic Green"; R="0.0"; G="1.0"; B="0.2" }
    '2' = @{ Name="Cyber Blue";    R="0.0"; G="0.5"; B="1.0" }
    '3' = @{ Name="Blood Red";     R="1.0"; G="0.0"; B="0.0" }
    '4' = @{ Name="Neon Purple";   R="0.8"; G="0.0"; B="1.0" }
    '5' = @{ Name="Solar Gold";    R="1.0"; G="0.8"; B="0.0" }
    '6' = @{ Name="Teal Cyan";     R="0.0"; G="1.0"; B="1.0" }
}

# --- INIT SETTINGS ---
if (-not (Test-Path $shaderPath)) {
    $s = $defaults.Clone()
} else {
    $c = Get-Content $shaderPath -Raw
    $s = @{
        R     = [regex]::Match($c, "#define RAIN_R\s+([\d\.]+)").Groups[1].Value
        G     = [regex]::Match($c, "#define RAIN_G\s+([\d\.]+)").Groups[1].Value
        B     = [regex]::Match($c, "#define RAIN_B\s+([\d\.]+)").Groups[1].Value
        Speed = [regex]::Match($c, "#define RAIN_SPEED\s+([\d\.]+)").Groups[1].Value
        Glow  = [regex]::Match($c, "#define GLOW_STRENGTH\s+([\d\.]+)").Groups[1].Value
        Scale = [regex]::Match($c, "#define FONT_SCALE\s+([\d\.]+)").Groups[1].Value
        Width = [regex]::Match($c, "#define CHAR_WIDTH\s+([\d\.]+)").Groups[1].Value
        Trail = [regex]::Match($c, "#define TRAIL_POWER\s+([\d\.]+)").Groups[1].Value
        Dens  = [regex]::Match($c, "#define RAIN_DENSITY\s+([\d\.]+)").Groups[1].Value
        L1    = [regex]::Match($c, "#define SHOW_L1\s+([\d\.]+)").Groups[1].Value
        L2    = [regex]::Match($c, "#define SHOW_L2\s+([\d\.]+)").Groups[1].Value
        L3    = [regex]::Match($c, "#define SHOW_L3\s+([\d\.]+)").Groups[1].Value
    }
    foreach ($key in $defaults.Keys) {
        if (-not $s[$key]) { $s[$key] = $defaults[$key] }
    }
}

# --- STATE ---
$showHelp = $false

function Save-Shader {
    try {
        $out = $shaderTemplate -replace "{R}",$s.R -replace "{G}",$s.G -replace "{B}",$s.B `
            -replace "{SPEED}",$s.Speed -replace "{GLOW}",$s.Glow -replace "{SCALE}",$s.Scale `
            -replace "{WIDTH}",$s.Width -replace "{TRAIL}",$s.Trail -replace "{DENS}",$s.Dens `
            -replace "{L1}",$s.L1 -replace "{L2}",$s.L2 -replace "{L3}",$s.L3
        Set-Content -Path $shaderPath -Value $out -ErrorAction Stop
        (Get-Item $shaderPath).LastWriteTime = Get-Date
    } catch {
        Write-Host " ERROR: Failed to save shader - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-ColorSwatch {
    $r = [int]([float]$s.R * 255)
    $g = [int]([float]$s.G * 255)
    $b = [int]([float]$s.B * 255)
    return "$([char]27)[48;2;${r};${g};${b}m    $([char]27)[0m"
}

function Get-PresetSwatch($preset) {
    $r = [int]([float]$preset.R * 255)
    $g = [int]([float]$preset.G * 255)
    $b = [int]([float]$preset.B * 255)
    return "$([char]27)[48;2;${r};${g};${b}m  $([char]27)[0m"
}

function Show-HelpScreen {
    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host " ║           MATRIX MASTER CONTROL - HELP                   ║" -ForegroundColor Green
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host " COLOR CONTROLS" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   r/R     Red channel      -/+ (0.0 - 1.0)"
    Write-Host "   g/G     Green channel    -/+ (0.0 - 1.0)"
    Write-Host "   b/B     Blue channel     -/+ (0.0 - 1.0)"
    Write-Host ""
    Write-Host " PRESETS" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   1       Classic Green    (The Matrix original)"
    Write-Host "   2       Cyber Blue       (Futuristic)"
    Write-Host "   3       Blood Red        (Alert/Danger)"
    Write-Host "   4       Neon Purple      (Synthwave)"
    Write-Host "   5       Solar Gold       (Warning)"
    Write-Host "   6       Teal Cyan        (Cool)"
    Write-Host "   0       Reset All        (Back to defaults)"
    Write-Host ""
    Write-Host " EFFECT CONTROLS" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   s/S     Speed            -/+ (0.1 - 5.0)"
    Write-Host "   l/L     Glow/Brightness  -/+ (0.2 - 10.0)"
    Write-Host "   w/W     Character Width  -/+ (4.0 - 20.0)"
    Write-Host "   t/T     Trail Length     -/+ (2.0 - 20.0)"
    Write-Host "   d/D     Rain Density     -/+ (0.1 - 1.0)"
    Write-Host ""
    Write-Host " LAYER CONTROLS" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   7       Toggle FAR layer   (background, subtle)"
    Write-Host "   8       Toggle MID layer   (middle depth)"
    Write-Host "   9       Toggle NEAR layer  (foreground, bright)"
    Write-Host ""
    Write-Host " GENERAL" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   H       Toggle this help screen"
    Write-Host "   Q       Quit"
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   Press any key to return..." -ForegroundColor DarkGray
}

function Show-MainScreen {
    [System.Console]::Clear()
    $swatch = Get-ColorSwatch

    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host " ║           MATRIX MASTER CONTROL v2.0                     ║" -ForegroundColor Green
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host " COLOR $swatch R:$($s.R) G:$($s.G) B:$($s.B)" -ForegroundColor White
    Write-Host ""
    Write-Host " PRESETS" -ForegroundColor DarkGreen
    foreach ($key in '1','2','3') {
        $p = $presets[$key]
        $sw = Get-PresetSwatch $p
        Write-Host "   [$key] $sw $($p.Name)" -NoNewline
        Write-Host "  " -NoNewline
    }
    Write-Host ""
    foreach ($key in '4','5','6') {
        $p = $presets[$key]
        $sw = Get-PresetSwatch $p
        Write-Host "   [$key] $sw $($p.Name)" -NoNewline
        Write-Host "  " -NoNewline
    }
    Write-Host ""
    Write-Host ""
    Write-Host " PARAMETERS" -ForegroundColor DarkGreen
    Write-Host "   [S] Speed : $($s.Speed)    [L] Glow  : $($s.Glow)    [W] Width : $($s.Width)"
    Write-Host "   [T] Trail : $($s.Trail)    [D] Dens  : $($s.Dens)"
    Write-Host ""
    Write-Host " LAYERS" -ForegroundColor DarkGreen
    $l1 = if($s.L1 -eq "1.0"){"ON "}else{"OFF"}
    $l2 = if($s.L2 -eq "1.0"){"ON "}else{"OFF"}
    $l3 = if($s.L3 -eq "1.0"){"ON "}else{"OFF"}
    Write-Host "   [7] FAR: $l1   [8] MID: $l2   [9] NEAR: $l3"
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [H] Help   [0] Reset   [Q] Quit" -ForegroundColor DarkGray
}

# --- CONTROL LOOP ---
[System.Console]::CursorVisible = $false
try {
    while ($true) {
        if ($showHelp) {
            Show-HelpScreen
        } else {
            Show-MainScreen
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $ch = $key.Character

        # If help is shown, any key dismisses it
        if ($showHelp) {
            $showHelp = $false
            continue
        }

        switch -CaseSensitive ($ch) {
            # Layer toggles
            '7' { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
            '8' { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
            '9' { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }

            # Color presets
            '1' { $s.R=$presets['1'].R; $s.G=$presets['1'].G; $s.B=$presets['1'].B; Save-Shader }
            '2' { $s.R=$presets['2'].R; $s.G=$presets['2'].G; $s.B=$presets['2'].B; Save-Shader }
            '3' { $s.R=$presets['3'].R; $s.G=$presets['3'].G; $s.B=$presets['3'].B; Save-Shader }
            '4' { $s.R=$presets['4'].R; $s.G=$presets['4'].G; $s.B=$presets['4'].B; Save-Shader }
            '5' { $s.R=$presets['5'].R; $s.G=$presets['5'].G; $s.B=$presets['5'].B; Save-Shader }
            '6' { $s.R=$presets['6'].R; $s.G=$presets['6'].G; $s.B=$presets['6'].B; Save-Shader }

            # Reset to defaults
            '0' { $s = $defaults.Clone(); Save-Shader }

            # Help toggle
            'h' { $showHelp = $true }
            'H' { $showHelp = $true }

            # Glow/Brightness
            'l' { if([float]$s.Glow -gt 0.2) { $s.Glow = "{0:N1}" -f ([float]$s.Glow - 0.2); Save-Shader } }
            'L' { if([float]$s.Glow -lt 10.0) { $s.Glow = "{0:N1}" -f ([float]$s.Glow + 0.2); Save-Shader } }

            # Speed
            's' { if([float]$s.Speed -gt 0.1) { $s.Speed = "{0:N1}" -f ([float]$s.Speed - 0.1); Save-Shader } }
            'S' { if([float]$s.Speed -lt 5.0) { $s.Speed = "{0:N1}" -f ([float]$s.Speed + 0.1); Save-Shader } }

            # Width
            'w' { if([float]$s.Width -gt 4.0) { $s.Width = "{0:N1}" -f ([float]$s.Width - 0.5); Save-Shader } }
            'W' { if([float]$s.Width -lt 20.0) { $s.Width = "{0:N1}" -f ([float]$s.Width + 0.5); Save-Shader } }

            # Trail
            'T' { if([float]$s.Trail -lt 20.0) { $s.Trail = "{0:N1}" -f ([float]$s.Trail + 0.5); Save-Shader } }
            't' { if([float]$s.Trail -gt 2.0) { $s.Trail = "{0:N1}" -f ([float]$s.Trail - 0.5); Save-Shader } }

            # Density
            'd' { if([float]$s.Dens -gt 0.1) { $s.Dens = "{0:N1}" -f ([float]$s.Dens - 0.1); Save-Shader } }
            'D' { if([float]$s.Dens -lt 1.0) { $s.Dens = "{0:N1}" -f ([float]$s.Dens + 0.1); Save-Shader } }

            # RGB fine control
            'r' { if([float]$s.R -gt 0.0) { $s.R = "{0:N1}" -f ([float]$s.R - 0.1); Save-Shader } }
            'R' { if([float]$s.R -lt 1.0) { $s.R = "{0:N1}" -f ([float]$s.R + 0.1); Save-Shader } }
            'g' { if([float]$s.G -gt 0.0) { $s.G = "{0:N1}" -f ([float]$s.G - 0.1); Save-Shader } }
            'G' { if([float]$s.G -lt 1.0) { $s.G = "{0:N1}" -f ([float]$s.G + 0.1); Save-Shader } }
            'b' { if([float]$s.B -gt 0.0) { $s.B = "{0:N1}" -f ([float]$s.B - 0.1); Save-Shader } }
            'B' { if([float]$s.B -lt 1.0) { $s.B = "{0:N1}" -f ([float]$s.B + 0.1); Save-Shader } }

            # Quit
            'q' { return }
            'Q' { return }
        }
    }
} finally {
    [System.Console]::CursorVisible = $true
}
