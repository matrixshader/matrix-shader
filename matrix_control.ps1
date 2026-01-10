# MATRIX CONTROL PANEL - redpill

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
#define SHOW_L1        {L1}
#define SHOW_L2        {L2}
#define SHOW_L3        {L3}

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

$defaults = @{ R="0.0"; G="1.0"; B="0.3"; Speed="0.8"; Glow="0.8"; Width="10.0"; Trail="8.0"; Dens="0.4"; L1="1.0"; L2="0.0"; L3="1.0" }

# Current state
$currentSlot = 1
$s = $defaults.Clone()
$dirty = $false

# Terminal effects state (from settings.json) - true transparency
$transparency = $false
$opacity = 1.0

function Swatch($r,$g,$b,$w) {
    "$([char]27)[48;2;$([int]([float]$r*255));$([int]([float]$g*255));$([int]([float]$b*255))m$(' '*$w)$([char]27)[0m"
}

function Get-ExistingSlots {
    $slots = @()
    for ($i = 1; $i -le 8; $i++) {
        if (Test-Path "$shadersDir\Matrix-$i.hlsl") {
            $slots += $i
        }
    }
    return $slots
}

function Load-Shader($slot) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    $cfg = $defaults.Clone()
    if (Test-Path $path) {
        $c = Get-Content $path -Raw
        $map = @{ R="RAIN_R"; G="RAIN_G"; B="RAIN_B"; Speed="RAIN_SPEED"; Glow="GLOW_STRENGTH"; Width="CHAR_WIDTH"; Trail="TRAIL_POWER"; Dens="RAIN_DENSITY"; L1="SHOW_L1"; L2="SHOW_L2"; L3="SHOW_L3" }
        foreach ($k in $map.Keys) {
            $m = [regex]::Match($c, "#define $($map[$k])\s+([\d\.]+)")
            if ($m.Success) { $cfg[$k] = $m.Groups[1].Value }
        }
    }
    return $cfg
}

function Save-Shader($slot, $cfg) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    $content = $shaderTemplate -replace '\{SLOT\}',$slot -replace '\{R\}',$cfg.R -replace '\{G\}',$cfg.G -replace '\{B\}',$cfg.B `
        -replace '\{SPEED\}',$cfg.Speed -replace '\{GLOW\}',$cfg.Glow -replace '\{WIDTH\}',$cfg.Width `
        -replace '\{TRAIL\}',$cfg.Trail -replace '\{DENS\}',$cfg.Dens `
        -replace '\{L1\}',$cfg.L1 -replace '\{L2\}',$cfg.L2 -replace '\{L3\}',$cfg.L3
    [System.IO.File]::WriteAllText($path, $content)
}

function Load-TerminalEffects($slot) {
    $content = Get-Content $wtSettingsPath -Raw
    $settings = $content | ConvertFrom-Json
    $profile = $settings.profiles.list | Where-Object { $_.name -eq "Matrix-$slot" }

    $script:transparency = $false
    $script:opacity = 1.0

    if ($profile) {
        # Check for true transparency (opacity setting)
        if ($null -ne $profile.opacity -and $profile.opacity -lt 1.0) {
            $script:transparency = $true
            $script:opacity = [float]$profile.opacity
        }
    }
}

function Save-TerminalEffects($slot) {
    $content = Get-Content $wtSettingsPath -Raw
    $settings = $content | ConvertFrom-Json

    for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
        if ($settings.profiles.list[$i].name -eq "Matrix-$slot") {
            # Set true transparency (opacity setting - black becomes see-through)
            if ($transparency) {
                $settings.profiles.list[$i] | Add-Member -NotePropertyName 'opacity' -NotePropertyValue $opacity -Force
                # useAcrylic adds blur behind transparency, optional but looks good
                $settings.profiles.list[$i] | Add-Member -NotePropertyName 'useAcrylic' -NotePropertyValue $true -Force
            } else {
                $settings.profiles.list[$i].PSObject.Properties.Remove('opacity')
                $settings.profiles.list[$i].PSObject.Properties.Remove('useAcrylic')
            }
            break
        }
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
}

function Adj($p, $d, $mn, $mx) {
    $v = [float]$s[$p] + $d
    if ($v -ge $mn -and $v -le $mx) {
        $s[$p] = $v.ToString("N1")
        $script:dirty = $true
    }
}

function Bar($val, $min, $max, $width) {
    $pct = ([float]$val - $min) / ($max - $min)
    $filled = [int]($pct * $width)
    $empty = $width - $filled
    "$([char]27)[32m$('=' * $filled)$([char]27)[90m$('-' * $empty)$([char]27)[0m"
}

function UI {
    Clear-Host
    $slots = Get-ExistingSlots
    $dirtyMark = if ($dirty) { "*" } else { " " }

    Write-Host ""
    Write-Host " RED PILL$dirtyMark- Tab $currentSlot" -ForegroundColor Red
    Write-Host ""

    # Tab selector
    Write-Host " TABS: " -NoNewline
    foreach ($slot in $slots) {
        $cfg = Load-Shader $slot
        if ($slot -eq $currentSlot) {
            Write-Host "[$slot]$(Swatch $cfg.R $cfg.G $cfg.B 1)" -NoNewline -ForegroundColor Yellow
        } else {
            Write-Host " $slot $(Swatch $cfg.R $cfg.G $cfg.B 1)" -NoNewline -ForegroundColor DarkGray
        }
        Write-Host " " -NoNewline
    }
    Write-Host ""
    Write-Host " [TAB] next tab" -ForegroundColor DarkGray
    Write-Host ""

    # Color section
    Write-Host " COLOR PRESETS" -ForegroundColor White
    Write-Host " [1]$(Swatch 0 1 0.3 1)Green [2]$(Swatch 0 0.6 1 1)Cyan [3]$(Swatch 1 0.1 0.1 1)Red [4]$(Swatch 0.7 0 1 1)Purple [5]$(Swatch 1 0.7 0 1)Gold [6]$(Swatch 0 0.9 0.9 1)Teal"
    Write-Host ""

    # Current color with sliders
    Write-Host " CURRENT $(Swatch $s.R $s.G $s.B 3)" -ForegroundColor White
    Write-Host " [Q/W] Red   $($s.R.PadLeft(4)) $(Bar $s.R 0 1 15)"
    Write-Host " [A/S] Green $($s.G.PadLeft(4)) $(Bar $s.G 0 1 15)"
    Write-Host " [Z/X] Blue  $($s.B.PadLeft(4)) $(Bar $s.B 0 1 15)"
    Write-Host ""

    # Effects
    Write-Host " RAIN EFFECTS" -ForegroundColor White
    Write-Host " [E/R] Speed   $($s.Speed.PadLeft(4)) $(Bar $s.Speed 0.1 3 15)"
    Write-Host " [D/F] Glow    $($s.Glow.PadLeft(4)) $(Bar $s.Glow 0.2 3 15)"
    Write-Host " [C/V] Width   $($s.Width.PadLeft(4)) $(Bar $s.Width 6 20 15)"
    Write-Host " [T/Y] Trail   $($s.Trail.PadLeft(4)) $(Bar $s.Trail 4 15 15)"
    Write-Host " [G/H] Density $($s.Dens.PadLeft(4)) $(Bar $s.Dens 0.2 1 15)"
    Write-Host ""

    # Layers
    $l1 = if($s.L1 -eq "1.0"){"ON "}else{"off"}
    $l2 = if($s.L2 -eq "1.0"){"ON "}else{"off"}
    $l3 = if($s.L3 -eq "1.0"){"ON "}else{"off"}
    $l1c = if($s.L1 -eq "1.0"){"Green"}else{"DarkGray"}
    $l2c = if($s.L2 -eq "1.0"){"Green"}else{"DarkGray"}
    $l3c = if($s.L3 -eq "1.0"){"Green"}else{"DarkGray"}
    Write-Host " LAYERS" -ForegroundColor White
    Write-Host " [7] Far: " -NoNewline; Write-Host $l1 -ForegroundColor $l1c -NoNewline
    Write-Host "  [8] Mid: " -NoNewline; Write-Host $l2 -ForegroundColor $l2c -NoNewline
    Write-Host "  [9] Near: " -NoNewline; Write-Host $l3 -ForegroundColor $l3c
    Write-Host ""

    # Terminal Effects (transparency)
    Write-Host " WINDOW EFFECTS" -ForegroundColor Cyan
    $transStatus = if($transparency){"ON "}else{"off"}
    $transColor = if($transparency){"Cyan"}else{"DarkGray"}
    Write-Host " [B] Transparency:  " -NoNewline; Write-Host $transStatus -ForegroundColor $transColor
    if ($transparency) {
        $opacityPct = [int]($opacity * 100)
        Write-Host " [K/L] Opacity:     $($opacityPct.ToString().PadLeft(3))% $(Bar $opacity 0.1 1 15)"
    }
    Write-Host ""

    # Footer
    Write-Host " [ENTER] Save shader  [SPACE] Save terminal effects" -ForegroundColor Yellow
    Write-Host " [0] Reset  [ESC] Quit" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " After saving, press Shift+F10 twice in Matrix window to reload" -ForegroundColor DarkGray
}

# Check for existing shaders
$slots = Get-ExistingSlots
if ($slots.Count -eq 0) {
    Write-Host ""
    Write-Host " No Matrix tabs found." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' first to create some." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Load first slot
$currentSlot = $slots[0]
$s = Load-Shader $currentSlot
Load-TerminalEffects $currentSlot

[Console]::CursorVisible = $false
try {
    while ($true) {
        UI
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $k = $key.Character
        $vk = $key.VirtualKeyCode

        # Tab key (VK 9) to switch slots
        if ($vk -eq 9) {
            $slots = Get-ExistingSlots
            $idx = [array]::IndexOf($slots, $currentSlot)
            $idx = ($idx + 1) % $slots.Count
            $currentSlot = $slots[$idx]
            $s = Load-Shader $currentSlot
            Load-TerminalEffects $currentSlot
            $dirty = $false
        }
        # Enter key (VK 13) to save shader
        elseif ($vk -eq 13) {
            Save-Shader $currentSlot $s
            $dirty = $false
            Write-Host ""
            Write-Host " Shader saved! Press Shift+F10 twice in Matrix window." -ForegroundColor Green
            Start-Sleep -Milliseconds 1200
        }
        # Space key (VK 32) to save terminal effects
        elseif ($vk -eq 32) {
            Save-TerminalEffects $currentSlot
            Write-Host ""
            Write-Host " Terminal effects saved! Reopen Matrix window to apply." -ForegroundColor Cyan
            Start-Sleep -Milliseconds 1200
        }
        # Escape key (VK 27) to quit
        elseif ($vk -eq 27) {
            return
        }
        else {
            switch -CaseSensitive ($k) {
                # Color presets (1-6)
                '1' { $s.R="0.0"; $s.G="1.0"; $s.B="0.3"; $dirty=$true }
                '2' { $s.R="0.0"; $s.G="0.6"; $s.B="1.0"; $dirty=$true }
                '3' { $s.R="1.0"; $s.G="0.1"; $s.B="0.1"; $dirty=$true }
                '4' { $s.R="0.7"; $s.G="0.0"; $s.B="1.0"; $dirty=$true }
                '5' { $s.R="1.0"; $s.G="0.7"; $s.B="0.0"; $dirty=$true }
                '6' { $s.R="0.0"; $s.G="0.9"; $s.B="0.9"; $dirty=$true }

                # RGB controls (Q/W, A/S, Z/X)
                'q' { Adj 'R' -0.1 0 1 }
                'Q' { Adj 'R' -0.1 0 1 }
                'w' { Adj 'R' 0.1 0 1 }
                'W' { Adj 'R' 0.1 0 1 }
                'a' { Adj 'G' -0.1 0 1 }
                'A' { Adj 'G' -0.1 0 1 }
                's' { Adj 'G' 0.1 0 1 }
                'S' { Adj 'G' 0.1 0 1 }
                'z' { Adj 'B' -0.1 0 1 }
                'Z' { Adj 'B' -0.1 0 1 }
                'x' { Adj 'B' 0.1 0 1 }
                'X' { Adj 'B' 0.1 0 1 }

                # Effects (paired keys for -/+)
                'e' { Adj 'Speed' -0.1 0.1 3 }
                'E' { Adj 'Speed' -0.1 0.1 3 }
                'r' { Adj 'Speed' 0.1 0.1 3 }
                'R' { Adj 'Speed' 0.1 0.1 3 }
                'd' { Adj 'Glow' -0.1 0.2 3 }
                'D' { Adj 'Glow' -0.1 0.2 3 }
                'f' { Adj 'Glow' 0.1 0.2 3 }
                'F' { Adj 'Glow' 0.1 0.2 3 }
                'c' { Adj 'Width' -1 6 20 }
                'C' { Adj 'Width' -1 6 20 }
                'v' { Adj 'Width' 1 6 20 }
                'V' { Adj 'Width' 1 6 20 }
                't' { Adj 'Trail' -0.5 4 15 }
                'T' { Adj 'Trail' -0.5 4 15 }
                'y' { Adj 'Trail' 0.5 4 15 }
                'Y' { Adj 'Trail' 0.5 4 15 }
                'g' { Adj 'Dens' -0.1 0.2 1 }
                'G' { Adj 'Dens' -0.1 0.2 1 }
                'h' { Adj 'Dens' 0.1 0.2 1 }
                'H' { Adj 'Dens' 0.1 0.2 1 }

                # Layers (7/8/9)
                '7' { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"}; $dirty=$true }
                '8' { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"}; $dirty=$true }
                '9' { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"}; $dirty=$true }

                # Window transparency (terminal setting)
                'b' { $script:transparency = -not $transparency }
                'B' { $script:transparency = -not $transparency }
                'k' { if ($transparency -and $opacity -gt 0.1) { $script:opacity = [Math]::Round($opacity - 0.1, 1) } }
                'K' { if ($transparency -and $opacity -gt 0.1) { $script:opacity = [Math]::Round($opacity - 0.1, 1) } }
                'l' { if ($transparency -and $opacity -lt 1.0) { $script:opacity = [Math]::Round($opacity + 0.1, 1) } }
                'L' { if ($transparency -and $opacity -lt 1.0) { $script:opacity = [Math]::Round($opacity + 0.1, 1) } }

                # Reset
                '0' { $s = $defaults.Clone(); $dirty=$true }
            }
        }
    }
} finally {
    [Console]::CursorVisible = $true
}
