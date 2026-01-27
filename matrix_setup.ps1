# MATRIX SETUP WIZARD - wakeupneo

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$shadersDir = "$matrixDir\shaders"
$stateFile = "$matrixDir\matrix_state.json"
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Unified logging
. "$PSScriptRoot\MatrixLogging.ps1"

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

# Import shared utilities (includes Swatch alias for Get-ColorSwatch)
. "$PSScriptRoot\MatrixUtils.ps1"

function Write-Shader($slot, $cfg) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    Write-MatrixLog "Writing shader slot=$slot to $path" -Source SETUP
    $content = $shaderTemplate -replace '\{SLOT\}',$slot -replace '\{R\}',$cfg.R -replace '\{G\}',$cfg.G -replace '\{B\}',$cfg.B `
        -replace '\{SPEED\}',$cfg.Speed -replace '\{GLOW\}',$cfg.Glow -replace '\{WIDTH\}',$cfg.Width `
        -replace '\{TRAIL\}',$cfg.Trail -replace '\{DENS\}',$cfg.Dens
    [System.IO.File]::WriteAllText($path, $content)
    Write-MatrixLog "Shader slot=$slot written successfully" -Source SETUP
}

# Import WindowLayoutEngine for centralized positioning
. "$PSScriptRoot\WindowLayoutEngine.ps1"

# Import WindowIdentityService for launch tracking and window detection
. "$PSScriptRoot\WindowIdentityService.ps1"

function Position-MatrixWindows([int]$WindowCount) {
    # Wait for windows to fully initialize
    Start-Sleep -Milliseconds 500

    # Use WindowIdentityService to find all Matrix windows
    $identityWindows = Get-AllMatrixWindows -IncludeRedpill:$false
    $windowHandles = @{}

    foreach ($win in $identityWindows) {
        if ($win.Slot) {
            $windowHandles["Matrix-$($win.Slot)"] = @{ Handle = $win.Handle }
        }
    }

    if ($windowHandles.Count -eq 0) {
        Write-Host "   No Matrix windows detected" -ForegroundColor Yellow
        return
    }

    # Use WindowLayoutEngine for positioning
    $result = Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode 'Auto'

    Write-Host "   Positioned $($windowHandles.Count) windows via identity service" -ForegroundColor DarkGray
}

function Update-ProfileShaderPath([int]$Slot) {
    Write-MatrixLog "Updating profile shader path for slot $Slot" -Source SETUP
    # Updates Windows Terminal settings.json so Matrix-$Slot profile points to shaders/Matrix-$Slot.hlsl
    if (-not (Test-Path $wtSettingsPath)) {
        Write-MatrixLog "Windows Terminal settings.json not found" -Source SETUP -Level WARN
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
            Write-MatrixLog "Updating settings.json with shader path: $shaderPath" -Source SETUP
            # US-001: Atomic write pattern - temp file + move (critical for settings.json)
            $tempFile = [System.IO.Path]::GetTempFileName()
            $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding UTF8
            Move-Item -Path $tempFile -Destination $wtSettingsPath -Force
            Write-MatrixLog "Settings.json updated successfully" -Source SETUP
        }
    } catch {
        Write-MatrixLog "Failed to update profile path: $_" -Source SETUP -Level ERROR
        Write-Host "   WARNING: Failed to update profile path: $_" -ForegroundColor Yellow
        # Clean up temp file on failure
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}


# Ensure shaders directory exists
if (-not (Test-Path $shadersDir)) {
    New-Item -ItemType Directory -Path $shadersDir -Force | Out-Null
}

# State persistence functions
function Save-MatrixState($slots) {
    Write-MatrixLog "Saving Matrix state: slots=[$($slots -join ',')]" -Source SETUP
    $state = @{
        lastSlots = $slots
        lastSaved = (Get-Date).ToString("o")
    }
    try {
        # US-001: Atomic write pattern - temp file + move
        $tempFile = [System.IO.Path]::GetTempFileName()
        $state | ConvertTo-Json | Out-File -FilePath $tempFile -Encoding UTF8
        Move-Item -Path $tempFile -Destination $stateFile -Force
        Write-MatrixLog "Matrix state saved successfully" -Source SETUP
    } catch {
        Write-MatrixLog "Failed to save Matrix state: $_" -Source SETUP -Level ERROR
        Write-Host "   Warning: Could not save state: $_" -ForegroundColor Yellow
        # Clean up temp file on failure
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Load-MatrixState {
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json
            return $state
        } catch {
            return $null
        }
    }
    return $null
}

function Load-ShaderConfig($slot) {
    # Read shader config from existing HLSL file
    $path = "$shadersDir\Matrix-$slot.hlsl"
    $cfg = $defaults.Clone()
    if (Test-Path $path) {
        try {
            $c = Get-Content $path -Raw
            $map = @{ R="RAIN_R"; G="RAIN_G"; B="RAIN_B"; Speed="RAIN_SPEED"; Glow="GLOW_STRENGTH"; Width="CHAR_WIDTH"; Trail="TRAIL_POWER"; Dens="RAIN_DENSITY" }
            foreach ($k in $map.Keys) {
                $m = [regex]::Match($c, "#define $($map[$k])\s+([\d\.]+)")
                if ($m.Success) { $cfg[$k] = $m.Groups[1].Value }
            }
        } catch { }
    }
    $cfg['Slot'] = $slot
    # Determine color name based on RGB values
    $cfg['Name'] = "Custom"
    foreach ($k in ('1','2','3','4','5','6')) {
        $p = $presets[$k]
        if ($cfg.R -eq $p.R -and $cfg.G -eq $p.G -and $cfg.B -eq $p.B) {
            $cfg['Name'] = $p.Name
            break
        }
    }
    return $cfg
}

# MAIN
Clear-Host
Write-Host ""
Write-Host " WAKE UP, NEO..." -ForegroundColor Green
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host ""

# Check for previous state
$previousState = Load-MatrixState
$usePreviousState = $false

if ($previousState -and $previousState.lastSlots.Count -gt 0) {
    Write-Host " Previous session found:" -ForegroundColor Cyan
    Write-Host "   $($previousState.lastSlots.Count) windows, slots: [$($previousState.lastSlots -join ', ')]" -ForegroundColor DarkGray
    Write-Host ""
    $restore = Read-Host " Restore previous? (y/n)"
    if ($restore -eq 'y' -or $restore -eq 'Y') {
        $usePreviousState = $true
        $numTabs = $previousState.lastSlots.Count
        $tabConfigs = @()
        foreach ($slot in $previousState.lastSlots) {
            $cfg = Load-ShaderConfig $slot
            $tabConfigs += $cfg
        }
        Write-Host ""
        Write-Host " Restoring $numTabs window(s)..." -ForegroundColor Green
    } else {
        Write-Host ""
    }
}

if (-not $usePreviousState) {
    # Detect currently open Matrix windows to avoid slot collisions
    $openWindows = @(Get-AllMatrixWindows -IncludeRedpill:$false)
    $occupiedSlots = @($openWindows | Where-Object { $_.Slot } | ForEach-Object { $_.Slot })
    if ($occupiedSlots.Count -gt 0) {
        Write-Host ""
        Write-Host " Detected $($occupiedSlots.Count) open Matrix window(s): slots [$($occupiedSlots -join ', ')]" -ForegroundColor Yellow
        Write-MatrixLog "Detected occupied slots: [$($occupiedSlots -join ', ')]" -Source SETUP
    }

    # Calculate available slots (1-8 minus occupied)
    $availableSlots = @(1..8 | Where-Object { $_ -notin $occupiedSlots })
    $maxNewWindows = $availableSlots.Count

    if ($maxNewWindows -eq 0) {
        Write-Host ""
        Write-Host " All 8 Matrix slots are in use!" -ForegroundColor Red
        Write-Host " Close some Matrix windows first, or use the control panel." -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
        exit
    }

    Write-Host " Available slots: [$($availableSlots -join ', ')]" -ForegroundColor DarkGray
    $numInput = Read-Host " How many NEW Matrix tabs? (1-$maxNewWindows)"
    $numTabs = [Math]::Max(1, [Math]::Min($maxNewWindows, [int]$numInput))

    $tabConfigs = @()
    $slotIndex = 0  # Index into availableSlots array

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

        # Assign to next available slot (not just $i)
        $assignedSlot = $availableSlots[$slotIndex]
        $slotIndex++
        $cfg['Slot'] = $assignedSlot
        $cfg['Name'] = $color.Name
        $tabConfigs += $cfg

        Write-Host ""
        Write-Host " Tab ${i} -> Matrix-$assignedSlot - $(Swatch $cfg.R $cfg.G $cfg.B 2) $($color.Name)" -ForegroundColor Cyan
        Start-Sleep -Milliseconds 300
    }
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
if ($choice -eq 'q' -or $choice -eq 'Q') { exit }

# Create shaders for both paths
Write-Host ""
Write-Host " Creating shaders..." -ForegroundColor Cyan

foreach ($cfg in $tabConfigs) {
    Write-Shader $cfg.Slot $cfg
    Update-ProfileShaderPath $cfg.Slot
    Write-Host "   Matrix-$($cfg.Slot).hlsl -> profile updated" -ForegroundColor DarkGray
}

# Save state for future "restore previous" option
# Include BOTH occupied slots and new slots (if in new mode)
$newSlots = @($tabConfigs | ForEach-Object { $_.Slot })
if ($occupiedSlots) {
    $allSlots = @($occupiedSlots + $newSlots | Sort-Object -Unique)
    Write-MatrixLog "Saving state: occupied=[$($occupiedSlots -join ',')] + new=[$($newSlots -join ',')] = all=[$($allSlots -join ',')]" -Source SETUP
} else {
    $allSlots = $newSlots
    Write-MatrixLog "Saving state (restore mode): slots=[$($allSlots -join ',')]" -Source SETUP
}
Save-MatrixState $allSlots

Start-Sleep -Milliseconds 500

if ($choice -eq '2') {
    # Red Pill - launch Matrix windows PLUS control panel
    Write-MatrixLog "Red Pill selected - launching $($tabConfigs.Count) Matrix windows" -Source SETUP
    Write-Host ""
    Write-Host " Follow the white rabbit..." -ForegroundColor Green
    Write-Host ""
    Write-Host " Opening Matrix windows..." -ForegroundColor Cyan

    foreach ($cfg in $tabConfigs) {
        $slot = $cfg.Slot
        $pname = "Matrix-$slot"

        # Sync tab color to match shader color BEFORE launching
        Sync-TabColorToShader -ProfileName $pname | Out-Null

        Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
        Write-MatrixLog "Launching window: $pname" -Source SETUP

        # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
        $existingHandles = Get-ExistingWindowHandles

        Start-Process wt -ArgumentList "-p `"$pname`""

        # LAYER 1 INTEGRATION: Wait for new handle and register it
        $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

        if ($newHandle -ne [IntPtr]::Zero) {
            Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
            Write-MatrixLog "Window $pname launched successfully (handle: $newHandle)" -Source SETUP
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-MatrixLog "Window $pname TIMEOUT" -Source SETUP -Level WARN
            Write-Host " TIMEOUT" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host " Positioning windows..." -ForegroundColor Cyan
    Position-MatrixWindows $numTabs

    # Start background monitor for drag-snap
    $monitorScript = "$matrixDir\matrix_monitor.ps1"
    if (Test-Path $monitorScript) {
        Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorScript`"" -WindowStyle Hidden
    }

    Write-Host ""
    Write-Host " Opening control panel..." -ForegroundColor Cyan
    Start-Process "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe" -ArgumentList "--profile `"Redpill`""

    Write-Host ""
    Write-Host " THE MATRIX HAS YOU." -ForegroundColor Green
    Write-Host " Control panel ready for live adjustments." -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    exit
}

# Blue Pill path - launch windows user just configured
Write-MatrixLog "Blue Pill selected - launching $($tabConfigs.Count) Matrix windows" -Source SETUP
Write-Host ""
Write-Host " Opening windows..." -ForegroundColor Cyan

foreach ($cfg in $tabConfigs) {
    $slot = $cfg.Slot
    $pname = "Matrix-$slot"

    # Sync tab color to match shader color BEFORE launching
    Sync-TabColorToShader -ProfileName $pname | Out-Null

    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
    Write-MatrixLog "Launching window: $pname" -Source SETUP

    # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
    $existingHandles = Get-ExistingWindowHandles

    Start-Process wt -ArgumentList "-p `"$pname`""

    # LAYER 1 INTEGRATION: Wait for new handle and register it
    $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

    if ($newHandle -ne [IntPtr]::Zero) {
        Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
        Write-MatrixLog "Window $pname launched successfully (handle: $newHandle)" -Source SETUP
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-MatrixLog "Window $pname TIMEOUT" -Source SETUP -Level WARN
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host " Positioning windows..." -ForegroundColor Cyan
Position-MatrixWindows $numTabs

# Start background monitor for drag-snap
$monitorScript = "$matrixDir\matrix_monitor.ps1"
if (Test-Path $monitorScript) {
    Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorScript`"" -WindowStyle Hidden
}

Write-Host ""
Write-Host " FOLLOW THE WHITE RABBIT." -ForegroundColor Green
Write-Host " Type 'redpill' for live controls." -ForegroundColor DarkGray
Start-Sleep -Seconds 2
