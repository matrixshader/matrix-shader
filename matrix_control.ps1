# MATRIX CONTROL PANEL - redpill

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$shadersDir = "$matrixDir\shaders"
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$windowRegistryPath = "$matrixDir\window-registry.json"

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
$opacity = 100

# Launch settings
$launchCount = 0

# Diagnostic logging (only when MATRIX_DEBUG=1)
$debugLogPath = "$matrixDir\debug.log"

function Write-Log([string]$message, [string]$operation = "INFO") {
    if ($env:MATRIX_DEBUG -ne "1") { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $entry = "[$timestamp] [$operation] $message"
    Add-Content -Path $debugLogPath -Value $entry -ErrorAction SilentlyContinue
}

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
        try {
            $c = Get-Content $path -Raw -ErrorAction Stop
            $map = @{ R="RAIN_R"; G="RAIN_G"; B="RAIN_B"; Speed="RAIN_SPEED"; Glow="GLOW_STRENGTH"; Width="CHAR_WIDTH"; Trail="TRAIL_POWER"; Dens="RAIN_DENSITY"; L1="SHOW_L1"; L2="SHOW_L2"; L3="SHOW_L3" }
            foreach ($k in $map.Keys) {
                $m = [regex]::Match($c, "#define $($map[$k])\s+([\d\.]+)")
                if ($m.Success) {
                    $val = $m.Groups[1].Value
                    # Validate: must be valid float format (digits, optional single decimal, more digits)
                    if ($val -match '^\d+\.?\d*$') {
                        $cfg[$k] = $val
                    } else {
                        Write-Host " Warning: Invalid value '$val' for $($map[$k]), using default" -ForegroundColor Yellow
                    }
                }
            }
        }
        catch {
            Write-Host " Warning: Could not read shader file: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host " Using default shader settings" -ForegroundColor DarkGray
        }
    }
    return $cfg
}

function Save-Shader($slot, $cfg) {
    $path = "$shadersDir\Matrix-$slot.hlsl"
    Write-Log "Saving shader slot=$slot R=$($cfg.R) G=$($cfg.G) B=$($cfg.B)" "SAVE"
    $content = $shaderTemplate -replace '\{SLOT\}',$slot -replace '\{R\}',$cfg.R -replace '\{G\}',$cfg.G -replace '\{B\}',$cfg.B `
        -replace '\{SPEED\}',$cfg.Speed -replace '\{GLOW\}',$cfg.Glow -replace '\{WIDTH\}',$cfg.Width `
        -replace '\{TRAIL\}',$cfg.Trail -replace '\{DENS\}',$cfg.Dens `
        -replace '\{L1\}',$cfg.L1 -replace '\{L2\}',$cfg.L2 -replace '\{L3\}',$cfg.L3
    try {
        [System.IO.File]::WriteAllText($path, $content)
        Write-Log "Shader saved successfully: $path" "SAVE"
        return $true
    }
    catch {
        Write-Log "ERROR saving shader: $($_.Exception.Message)" "SAVE"
        Write-Host ""
        Write-Host " Error saving shader: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return $false
    }
}

function Load-TerminalEffects($slot) {
    # Default values (degraded mode if JSON fails)
    $script:transparency = $false
    $script:opacity = 100

    try {
        $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
        $settings = $content | ConvertFrom-Json -ErrorAction Stop
        $profile = $settings.profiles.list | Where-Object { $_.name -eq "Matrix-$slot" }

        if ($profile) {
            # Check for true transparency (opacity setting, integer 0-100)
            if ($null -ne $profile.opacity -and $profile.opacity -lt 100) {
                $script:transparency = $true
                $script:opacity = [int]$profile.opacity
            }
        }
    }
    catch [System.IO.IOException] {
        Write-Host " Warning: Cannot read settings.json (file locked)" -ForegroundColor Yellow
        Write-Host " Using default transparency settings" -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 1500
    }
    catch [System.ArgumentException] {
        Write-Host " Warning: settings.json is malformed" -ForegroundColor Yellow
        Write-Host " Using default transparency settings" -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 1500
    }
    catch {
        Write-Host " Warning: Could not load terminal settings: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host " Using default transparency settings" -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 1500
    }
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

# --- WINDOW POSITIONING & TRANSPARENCY (P/Invoke) ---
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class WindowAPI {
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
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_LAYERED = 0x80000;
    public const uint LWA_ALPHA = 0x2;

    private static List<KeyValuePair<IntPtr, string>> foundWindows;

    public static List<KeyValuePair<IntPtr, string>> FindWindowsByPattern(string pattern) {
        foundWindows = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                var sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                var title = sb.ToString();
                if (!string.IsNullOrEmpty(title) && System.Text.RegularExpressions.Regex.IsMatch(title, pattern)) {
                    foundWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, title));
                }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }

    // Find ALL Windows Terminal windows (by process name) except those matching excludePattern
    public static List<KeyValuePair<IntPtr, string>> FindAllTerminalWindows(string excludePattern) {
        foundWindows = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                uint processId;
                GetWindowThreadProcessId(hWnd, out processId);
                try {
                    var process = Process.GetProcessById((int)processId);
                    // Check if this is a Windows Terminal window
                    if (process.ProcessName.Equals("WindowsTerminal", StringComparison.OrdinalIgnoreCase)) {
                        var sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, 256);
                        var title = sb.ToString();
                        if (!string.IsNullOrEmpty(title)) {
                            // Exclude windows matching the pattern (e.g., "Redpill")
                            if (string.IsNullOrEmpty(excludePattern) ||
                                !System.Text.RegularExpressions.Regex.IsMatch(title, excludePattern)) {
                                foundWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, title));
                            }
                        }
                    }
                } catch { }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }
}
"@

Add-Type -AssemblyName System.Windows.Forms

# Import Window Layout Engine
. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"

function Get-ScreenDimensions {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    return @{
        Width = $screen.Width
        Height = $screen.Height
        X = $screen.X
        Y = $screen.Y
    }
}

function Position-MatrixWindows {
    # Position ALL open Windows Terminal windows (except Redpill) using the Window Layout Engine
    # Supports Pillars (vertical columns) and Quads (2x2 grid) layout modes
    Write-Log "Positioning windows via Layout Engine..." "POSITION"
    Start-Sleep -Milliseconds 300
    $windowInfo = Get-MatrixWindowInfo
    if ($windowInfo.Count -eq 0) {
        Write-Log "No windows to position" "POSITION"
        return
    }

    # Build hashtable for Invoke-MatrixWindowLayout: Key = shader name, Value = @{Handle}
    $windowHandles = @{}
    foreach ($win in $windowInfo) {
        $windowHandles["Matrix-$($win.Slot)"] = @{ Handle = $win.Handle }
    }

    # Get layout configuration and invoke the layout engine
    $config = Get-MatrixLayoutConfig
    $mode = if ($config.Mode) { $config.Mode } else { 'Pillars' }
    Write-Log "Layout mode: $mode, Windows: $($windowInfo.Count)" "POSITION"

    try {
        Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode $mode
        Write-Log "Layout applied successfully" "POSITION"

        # Update position tracking after repositioning
        $handleArray = @($windowInfo | ForEach-Object { $_.Handle })
        if ($handleArray.Count -gt 0) {
            Update-PositionTracking -WindowHandles $handleArray
        }
    }
    catch {
        Write-Log "ERROR applying layout: $($_.Exception.Message)" "POSITION"
    }
}

function Get-MatrixWindows {
    # Find ALL Windows Terminal windows EXCEPT the Redpill control panel
    # These are all "Matrix windows" because they run with shader effects
    $windows = [WindowAPI]::FindAllTerminalWindows("Redpill")
    return $windows
}

function Get-WindowShaderMapping {
    # Load window registry (handle -> shader file mapping)
    $registry = @{}
    if (Test-Path $windowRegistryPath) {
        try {
            $content = Get-Content $windowRegistryPath -Raw
            $data = $content | ConvertFrom-Json
            # Convert PSObject to hashtable
            $data.PSObject.Properties | ForEach-Object { $registry[$_.Name] = $_.Value }
        } catch { }
    }
    return $registry
}

function Clean-WindowRegistry {
    # Remove stale entries for windows that no longer exist
    if (-not (Test-Path $windowRegistryPath)) { return }

    try {
        $registry = Get-WindowShaderMapping
        $currentWindows = Get-MatrixWindows
        $validHandles = $currentWindows | ForEach-Object { $_.Key.ToString() }

        $cleanedRegistry = @{}
        foreach ($key in $registry.Keys) {
            if ($key -in $validHandles) {
                $cleanedRegistry[$key] = $registry[$key]
            }
        }

        $cleanedRegistry | ConvertTo-Json | Set-Content $windowRegistryPath -Encoding UTF8
    } catch { }
}

function Populate-WindowRegistry {
    # Assign shaders to current windows that aren't in registry yet
    # Uses title matching, profile detection, then sequential assignment
    $windows = Get-MatrixWindows
    $registry = Get-WindowShaderMapping
    $usedSlots = @{}

    # Track which slots are already used
    foreach ($key in $registry.Keys) {
        if ($registry[$key] -match "Matrix-(\d+)\.hlsl") {
            $usedSlots[[int]$Matches[1]] = $true
        }
    }

    # Also track slots from windows with Matrix-N titles
    foreach ($win in $windows) {
        if ($win.Value -match "Matrix-(\d+)") {
            $usedSlots[[int]$Matches[1]] = $true
        }
    }

    $nextSlot = 1
    foreach ($win in $windows) {
        $handleKey = $win.Key.ToString()

        # Skip if already in registry
        if ($registry.ContainsKey($handleKey)) { continue }

        # Try to determine slot from title
        if ($win.Value -match "Matrix-(\d+)") {
            $slot = [int]$Matches[1]
        }
        # Try to determine from profile settings (only if slot not already used)
        else {
            $profileSlot = Get-SlotFromSettings $win.Value
            if ($profileSlot -and -not $usedSlots.ContainsKey($profileSlot)) {
                $slot = $profileSlot
            }
        }

        # If still no slot, assign next available
        if (-not $slot) {
            while ($usedSlots.ContainsKey($nextSlot)) { $nextSlot++ }
            $slot = $nextSlot
            $nextSlot++
        }

        $registry[$handleKey] = "Matrix-$slot.hlsl"
        $usedSlots[$slot] = $true
    }

    # Save updated registry
    try {
        $registry | ConvertTo-Json | Set-Content $windowRegistryPath -Encoding UTF8
    } catch { }
}

function Save-CurrentState {
    # Save current open slots to matrix_state.json for Blue Pill to use
    $stateFile = "$matrixDir\matrix_state.json"
    $openSlots = Get-OpenMatrixSlots

    $state = @{
        lastSlots = $openSlots
        lastSaved = (Get-Date).ToString("o")
    }

    try {
        $state | ConvertTo-Json | Set-Content $stateFile -Encoding UTF8
    } catch { }
}

function Get-OpenMatrixSlots {
    # Extract slot numbers from windows using registry + title fallback
    $windowInfo = Get-MatrixWindowInfo
    return $windowInfo | ForEach-Object { $_.Slot } | Sort-Object -Unique
}

function Get-SlotFromSettings($windowTitle) {
    # Determine shader slot by checking profile settings
    # Returns slot number or $null if can't determine
    try {
        $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
        $settings = $content | ConvertFrom-Json -ErrorAction Stop

        # Check if window title contains any profile name with a shader override
        foreach ($profile in $settings.profiles.list) {
            if ($profile.name -and $windowTitle -like "*$($profile.name)*") {
                if ($profile.'experimental.pixelShaderPath' -match "Matrix-(\d+)\.hlsl") {
                    return [int]$Matches[1]
                }
            }
        }

        # Fallback to profiles.defaults
        $defaultShader = $settings.profiles.defaults.'experimental.pixelShaderPath'
        if ($defaultShader -match "Matrix-(\d+)\.hlsl") {
            return [int]$Matches[1]
        }
    } catch { }
    return $null
}

function Get-MatrixWindowInfo {
    # Returns array of @{Handle, Title, Slot, ShaderPath} for Matrix windows ONLY
    # Uses title matching to detect Matrix-N windows
    Write-Log "Detecting Matrix windows..." "DETECT"
    $windows = Get-MatrixWindows
    Write-Log "Found $($windows.Count) terminal windows" "DETECT"
    $result = @()

    foreach ($win in $windows) {
        $slot = $null
        $shaderFile = $null

        # Title matching (Matrix-N in title)
        if ($win.Value -match "Matrix-(\d+)") {
            $slot = [int]$Matches[1]
            $shaderFile = "Matrix-$slot.hlsl"
            Write-Log "  Title match: handle=$($win.Key) -> Slot $slot" "DETECT"
        }
        # No Matrix profile detected - skip this window
        else {
            Write-Log "  Skipping non-Matrix window: handle=$($win.Key) title='$($win.Value)'" "DETECT"
            continue
        }

        $result += @{
            Handle = $win.Key
            Title = $win.Value
            Slot = $slot
            ShaderFile = $shaderFile
            ShaderPath = "$shadersDir\$shaderFile"
        }
    }

    # Update registry with detected mappings
    $registry = @{}
    foreach ($w in $result) {
        $registry[$w.Handle.ToString()] = $w.ShaderFile
    }
    try {
        $registry | ConvertTo-Json | Set-Content $windowRegistryPath -Encoding UTF8
    } catch { }

    $sorted = $result | Sort-Object { $_.Slot }
    Write-Log "Detected $($sorted.Count) Matrix windows" "DETECT"
    foreach ($w in $sorted) {
        Write-Log "  Slot $($w.Slot): handle=$($w.Handle) title='$($w.Title)'" "DETECT"
    }
    return $sorted
}

function Apply-WindowTransparency {
    # Apply transparency via Windows Terminal profile settings (background only, not text/effects)
    # This modifies settings.json and Windows Terminal hot-reloads
    try {
        $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
        $settings = $content | ConvertFrom-Json -ErrorAction Stop

        # Apply to profiles.defaults (affects windows using default profile)
        if ($script:transparency) {
            $settings.profiles.defaults | Add-Member -NotePropertyName 'opacity' -NotePropertyValue $script:opacity -Force
        } else {
            $settings.profiles.defaults.PSObject.Properties.Remove('opacity')
        }

        # Apply to ALL Matrix-N profiles
        for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
            $profileName = $settings.profiles.list[$i].name
            if ($profileName -match "^Matrix-\d+$") {
                if ($script:transparency) {
                    $settings.profiles.list[$i] | Add-Member -NotePropertyName 'opacity' -NotePropertyValue $script:opacity -Force
                } else {
                    $settings.profiles.list[$i].PSObject.Properties.Remove('opacity')
                }
            }
        }

        # Safe atomic write
        $json = $settings | ConvertTo-Json -Depth 10
        $tempPath = "$wtSettingsPath.tmp"
        [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.Encoding]::UTF8)
        Move-Item $tempPath $wtSettingsPath -Force -ErrorAction Stop
    }
    catch { }
}

function Wait-ForMatrixWindow([string]$profileName, [int]$timeoutMs = 5000) {
    # Poll for window with title containing profileName (e.g., "Matrix-1")
    # Returns $true if found, $false if timeout
    # Uses fast title-only search (no process lookup) for speed
    $pollInterval = 100
    $startTime = Get-Date

    while ($true) {
        Start-Sleep -Milliseconds $pollInterval

        # Strict timeout check
        if (((Get-Date) - $startTime).TotalMilliseconds -ge $timeoutMs) {
            return $false
        }

        # Fast check - just look for window title matching profile name
        $matches = [WindowAPI]::FindWindowsByPattern($profileName)
        if ($matches.Count -gt 0) {
            return $true
        }
    }
}

function Launch-MatrixWindows([int]$count) {
    Write-Log "Launch requested: count=$count" "LAUNCH"
    $existingSlots = Get-ExistingSlots
    $openSlots = Get-OpenMatrixSlots
    Write-Log "Existing slots: $($existingSlots -join ',') Open: $($openSlots -join ',')" "LAUNCH"

    # Find available slots (exist but not currently open)
    $availableSlots = $existingSlots | Where-Object { $_ -notin $openSlots }

    if ($availableSlots.Count -eq 0) {
        Write-Log "No available slots to launch" "LAUNCH"
        Write-Host ""
        Write-Host " All Matrix windows are already open!" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    $numWindows = [Math]::Min($count, $availableSlots.Count)
    $slotsToLaunch = $availableSlots | Select-Object -First $numWindows
    Write-Log "Launching slots: $($slotsToLaunch -join ',')" "LAUNCH"

    # Save shaders for slots we're launching
    foreach ($slot in $slotsToLaunch) {
        $cfg = Load-Shader $slot
        Save-Shader $slot $cfg
    }

    Write-Host ""
    Write-Host " Launching $numWindows Matrix window(s)..." -ForegroundColor Cyan
    Write-Host " Open: [$($openSlots -join ', ')] | Launching: [$($slotsToLaunch -join ', ')]" -ForegroundColor DarkGray

    foreach ($slot in $slotsToLaunch) {
        $pname = "Matrix-$slot"
        Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
        Start-Process wt -ArgumentList "-p `"$pname`""

        if (Wait-ForMatrixWindow $pname) {
            Write-Log "Window $pname launched successfully" "LAUNCH"
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Log "Window $pname TIMEOUT after 5s" "LAUNCH"
            Write-Host " TIMEOUT (5s)" -ForegroundColor Yellow
        }
    }

    # Position ALL open Matrix windows (existing + new)
    Write-Host " Positioning windows..." -ForegroundColor Cyan
    Position-MatrixWindows

    # Start background monitor for drag-snap (if not already running)
    $monitorScript = "$PSScriptRoot\matrix_monitor.ps1"
    if (Test-Path $monitorScript) {
        Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitorScript`"" -WindowStyle Hidden
    }

    Write-Host " THE MATRIX HAS YOU." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

function UI {
    Clear-Host
    $windowInfo = Get-MatrixWindowInfo  # Get ALL Windows Terminal windows except Redpill
    $dirtyMark = if ($dirty) { "*" } else { " " }

    Write-Host ""
    Write-Host " RED PILL$dirtyMark- Tab $currentSlot" -ForegroundColor Red
    Write-Host ""

    # Tab selector - shows ALL Windows Terminal windows with shader effects
    Write-Host " TABS: " -NoNewline
    if ($windowInfo.Count -eq 0) {
        Write-Host "(no Matrix windows detected)" -ForegroundColor DarkGray -NoNewline
    } else {
        foreach ($winInfo in $windowInfo) {
            $slot = $winInfo.Slot
            $title = $winInfo.Title
            # For Matrix-N windows, load their shader config. For others, use defaults
            if ($slot -lt 100) {
                $cfg = Load-Shader $slot
                $displayName = "$slot"
            } else {
                $cfg = $defaults.Clone()
                # Abbreviate long titles (first 8 chars)
                if ($title.Length -gt 8) {
                    $displayName = $title.Substring(0, 8) + ".."
                } else {
                    $displayName = $title
                }
            }
            if ($slot -eq $currentSlot) {
                Write-Host "[$displayName]$(Swatch $cfg.R $cfg.G $cfg.B 1)" -NoNewline -ForegroundColor Yellow
            } else {
                Write-Host " $displayName $(Swatch $cfg.R $cfg.G $cfg.B 1)" -NoNewline -ForegroundColor DarkGray
            }
            Write-Host " " -NoNewline
        }
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

    # Terminal Effects (transparency and layout)
    Write-Host " WINDOW EFFECTS" -ForegroundColor Cyan
    $transStatus = if($transparency){"ON "}else{"off"}
    $transColor = if($transparency){"Cyan"}else{"DarkGray"}
    Write-Host " [B] Transparency:  " -NoNewline; Write-Host $transStatus -ForegroundColor $transColor -NoNewline
    Write-Host "  (toggles & applies)" -ForegroundColor DarkGray
    if ($transparency) {
        Write-Host " [K/l] Opacity:     $($opacity.ToString().PadLeft(3))% $(Bar $opacity 0 100 15)"
    }
    # Layout mode display
    $layoutConfig = Get-MatrixLayoutConfig
    $layoutMode = if ($layoutConfig.Mode) { $layoutConfig.Mode } else { 'Pillars' }
    $layoutColor = if ($layoutMode -eq 'Pillars') { "Yellow" } else { "Magenta" }
    Write-Host " [Shift+L] Layout:  " -NoNewline; Write-Host $layoutMode -ForegroundColor $layoutColor -NoNewline
    Write-Host "  (Pillars=columns, Quads=2x2)" -ForegroundColor DarkGray

    # Windows on Primary display
    $screens = Get-ScreenTopology
    if ($screens.Count -gt 1) {
        $windowsOnPrimary = $layoutConfig.WindowsOnPrimary
        if ($null -eq $windowsOnPrimary -or $windowsOnPrimary -lt 0) {
            $primaryDisplay = "Auto"
            $primaryColor = "Cyan"
        } else {
            $primaryDisplay = "$windowsOnPrimary"
            $primaryColor = "Yellow"
        }
        Write-Host " [</>] Primary:     " -NoNewline; Write-Host $primaryDisplay -ForegroundColor $primaryColor -NoNewline
        Write-Host "  (windows on primary monitor)  [)] Auto" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Launch section
    Write-Host " LAUNCH" -ForegroundColor Magenta
    $existingSlots = Get-ExistingSlots
    $openSlots = Get-OpenMatrixSlots
    $availableSlots = $existingSlots | Where-Object { $_ -notin $openSlots }
    $availableCount = $availableSlots.Count

    # Show open/available status
    $openStr = if ($openSlots.Count -gt 0) { $openSlots -join ',' } else { "none" }
    $availStr = if ($availableCount -gt 0) { $availableSlots -join ',' } else { "none" }
    Write-Host " Open: " -NoNewline -ForegroundColor DarkGray
    Write-Host $openStr -NoNewline -ForegroundColor Green
    Write-Host " | Available: " -NoNewline -ForegroundColor DarkGray
    Write-Host $availStr -ForegroundColor Cyan

    $launchStatus = if($launchCount -gt 0){"$launchCount window(s)"}else{"disabled"}
    $launchColor = if($launchCount -gt 0){"Magenta"}else{"DarkGray"}
    Write-Host " [-/+] Count: " -NoNewline; Write-Host $launchStatus -ForegroundColor $launchColor -NoNewline
    Write-Host " (max: $availableCount)" -ForegroundColor DarkGray
    Write-Host ""

    # Footer
    $enterAction = if($launchCount -gt 0){"[ENTER] Launch $launchCount window(s)"}else{"[ENTER] (set count first)"}
    $enterColor = if($launchCount -gt 0){"Yellow"}else{"DarkGray"}
    Write-Host " $enterAction  " -ForegroundColor $enterColor -NoNewline
    Write-Host "[P] Save shader" -ForegroundColor Yellow
    Write-Host " [0] Reset  [ESC] Quit" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " Shader changes apply automatically when saved (hot-reload)" -ForegroundColor DarkGray
}

# Check for existing shaders
$existingSlots = Get-ExistingSlots
if ($existingSlots.Count -eq 0) {
    Write-Host ""
    Write-Host " No Matrix tabs found." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' first to create some." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Clean stale window registry entries and populate with current windows
Clean-WindowRegistry
Populate-WindowRegistry

# Load first OPEN slot (or first existing if none open)
$openSlots = Get-OpenMatrixSlots
if ($openSlots.Count -gt 0) {
    $currentSlot = $openSlots[0]
} else {
    $currentSlot = $existingSlots[0]  # Fallback if no windows open yet
}
$s = Load-Shader $currentSlot
Load-TerminalEffects $currentSlot

# Drag detection is handled by matrix_monitor.ps1 background process
# Redpill uses simple blocking input for responsive UI

[Console]::CursorVisible = $false
try {
    while ($true) {
        UI
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $k = $key.Character
        $vk = $key.VirtualKeyCode

        # Tab key (VK 9) to switch between OPEN windows only
        if ($vk -eq 9) {
            # Auto-save before switching tabs
            if ($dirty) {
                Save-Shader $currentSlot $s
                $dirty = $false
            }
            $openSlots = Get-OpenMatrixSlots
            if ($openSlots.Count -gt 0) {
                $idx = [array]::IndexOf($openSlots, $currentSlot)
                if ($idx -lt 0) { $idx = 0 }  # If current slot closed, go to first
                $idx = ($idx + 1) % $openSlots.Count
                $currentSlot = $openSlots[$idx]
                $s = Load-Shader $currentSlot
                Load-TerminalEffects $currentSlot
                $dirty = $false
                # Track tab focus for smart window management
                Update-WindowUsage -ProfileName "Matrix-$($script:currentSlot)" -EventType "Focus"
            }
        }
        # Enter key (VK 13) to launch windows (only if launchCount > 0)
        elseif ($vk -eq 13) {
            if ($launchCount -gt 0) {
                Save-Shader $currentSlot $s
                $dirty = $false
                Launch-MatrixWindows $launchCount
            }
        }
        # Escape key (VK 27) to quit
        elseif ($vk -eq 27) {
            # Save current window setup for next Blue Pill run
            Save-CurrentState

            # Save window positions for exact restoration (like Chrome)
            $windowInfo = Get-MatrixWindowInfo
            if ($windowInfo.Count -gt 0) {
                Save-WindowPositions -WindowInfo $windowInfo
            }

            return
        }
        else {
            # Handle Shift+L (uppercase L) for layout mode BEFORE normalizing
            # This preserves case-sensitivity for layout toggle vs opacity control
            if ($k -ceq 'L') {
                # Cycle layout mode: Pillars -> Quads -> Pillars
                $config = Get-MatrixLayoutConfig
                $newMode = if ($config.Mode -eq 'Pillars') { 'Quads' } else { 'Pillars' }
                $config.Mode = $newMode
                Set-MatrixLayoutConfig -Config $config
                Position-MatrixWindows
                Write-Host ""
                Write-Host " Layout mode: $newMode" -ForegroundColor Cyan
                Start-Sleep -Milliseconds 800
                continue
            }

            # Shift+S: Save Snapback
            if ($k -ceq 'S') {
                try {
                    Save-PositionPreset -Name "_snapback"
                    Write-Host ""
                    Write-Host " Snapback position saved" -ForegroundColor Green
                    Start-Sleep -Milliseconds 800
                } catch {
                    Write-Host ""
                    Write-Host " Failed to save snapback: $_" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
                continue
            }

            # Shift+R: Restore Snapback
            if ($k -ceq 'R') {
                try {
                    $result = Restore-PositionPreset -Name "_snapback"
                    Write-Host ""
                    if ($result) {
                        Write-Host " Snapback restored" -ForegroundColor Green
                    } else {
                        Write-Host " No snapback saved" -ForegroundColor Yellow
                    }
                    Start-Sleep -Milliseconds 800
                } catch {
                    Write-Host ""
                    Write-Host " Failed to restore: $_" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
                continue
            }

            # Shift+P: Toggle Priority Lock
            if ($k -ceq 'P') {
                $profile = "Matrix-$($script:currentSlot)"
                $usage = Get-WindowUsageData -ProfileName $profile
                $newLock = -not ($usage.isPriorityLocked -eq $true)
                Set-WindowPriority -ProfileName $profile -Locked $newLock
                $status = if ($newLock) { "LOCKED" } else { "unlocked" }
                Write-Host ""
                Write-Host " $profile priority: $status" -ForegroundColor Cyan
                Start-Sleep -Milliseconds 800
                continue
            }

            # Normalize letter keys to lowercase for case-insensitive handling
            $key = if ($k -match '^[A-Za-z]$') { [char]::ToLower($k) } else { $k }

            switch ($key) {
                # Color presets (1-6)
                '1' { $s.R="0.0"; $s.G="1.0"; $s.B="0.3"; $dirty=$true }
                '2' { $s.R="0.0"; $s.G="0.6"; $s.B="1.0"; $dirty=$true }
                '3' { $s.R="1.0"; $s.G="0.1"; $s.B="0.1"; $dirty=$true }
                '4' { $s.R="0.7"; $s.G="0.0"; $s.B="1.0"; $dirty=$true }
                '5' { $s.R="1.0"; $s.G="0.7"; $s.B="0.0"; $dirty=$true }
                '6' { $s.R="0.0"; $s.G="0.9"; $s.B="0.9"; $dirty=$true }

                # RGB controls (Q/W, A/S, Z/X)
                'q' { Adj 'R' -0.05 0 1 }
                'w' { Adj 'R' 0.05 0 1 }
                'a' { Adj 'G' -0.05 0 1 }
                's' { Adj 'G' 0.05 0 1 }
                'z' { Adj 'B' -0.05 0 1 }
                'x' { Adj 'B' 0.05 0 1 }

                # Effects (paired keys for -/+)
                'e' { Adj 'Speed' -0.1 0.1 3 }
                'r' { Adj 'Speed' 0.1 0.1 3 }
                'd' { Adj 'Glow' -0.1 0.2 3 }
                'f' { Adj 'Glow' 0.1 0.2 3 }
                'c' { Adj 'Width' -1 6 20 }
                'v' { Adj 'Width' 1 6 20 }
                't' { Adj 'Trail' -0.5 4 15 }
                'y' { Adj 'Trail' 0.5 4 15 }
                'g' { Adj 'Dens' -0.1 0.2 1 }
                'h' { Adj 'Dens' 0.1 0.2 1 }

                # Layers (7/8/9)
                '7' { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"}; $dirty=$true }
                '8' { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"}; $dirty=$true }
                '9' { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"}; $dirty=$true }

                # Window transparency
                'b' { $script:transparency = -not $transparency; Apply-WindowTransparency }
                'k' { if ($transparency -and $opacity -gt 0) { $script:opacity = $opacity - 5; Apply-WindowTransparency } }
                'l' { if ($transparency -and $opacity -lt 100) { $script:opacity = $opacity + 5; Apply-WindowTransparency } }

                # Launch count controls
                '-' { if ($launchCount -gt 0) { $script:launchCount = $launchCount - 1 } }
                '+' {
                    $existingSlots = Get-ExistingSlots
                    $openSlots = Get-OpenMatrixSlots
                    $availableCount = ($existingSlots | Where-Object { $_ -notin $openSlots }).Count
                    if ($launchCount -lt $availableCount) { $script:launchCount = $launchCount + 1 }
                }
                '=' {
                    $existingSlots = Get-ExistingSlots
                    $openSlots = Get-OpenMatrixSlots
                    $availableCount = ($existingSlots | Where-Object { $_ -notin $openSlots }).Count
                    if ($launchCount -lt $availableCount) { $script:launchCount = $launchCount + 1 }
                }

                # Reset
                '0' { $s = $defaults.Clone(); $dirty=$true }

                # Save shader
                'p' {
                    Save-Shader $currentSlot $s
                    $dirty = $false
                    Write-Host ""
                    Write-Host " Shader saved! Changes apply automatically." -ForegroundColor Green
                    Start-Sleep -Milliseconds 1200
                }

                # Windows on Primary controls (< and > keys = comma and period)
                ',' {
                    # Decrease windows on primary
                    $config = Get-MatrixLayoutConfig
                    $screens = Get-ScreenTopology
                    if ($screens.Count -gt 1) {
                        $current = $config.WindowsOnPrimary
                        if ($null -eq $current -or $current -lt 0) {
                            # Auto mode -> switch to one less than total windows
                            $openCount = (Get-OpenMatrixSlots).Count
                            $config.WindowsOnPrimary = [Math]::Max(0, $openCount - 1)
                        } elseif ($current -gt 0) {
                            $config.WindowsOnPrimary = $current - 1
                        }
                        Set-MatrixLayoutConfig -Config $config
                        Position-MatrixWindows
                        Write-Host ""
                        Write-Host " Primary: $($config.WindowsOnPrimary) windows" -ForegroundColor Cyan
                        Start-Sleep -Milliseconds 500
                    }
                }
                '.' {
                    # Increase windows on primary
                    $config = Get-MatrixLayoutConfig
                    $screens = Get-ScreenTopology
                    if ($screens.Count -gt 1) {
                        $current = $config.WindowsOnPrimary
                        $openCount = (Get-OpenMatrixSlots).Count
                        if ($null -eq $current -or $current -lt 0) {
                            # Already auto (all on primary), can't increase more
                        } elseif ($current -lt $openCount) {
                            $config.WindowsOnPrimary = $current + 1
                            Set-MatrixLayoutConfig -Config $config
                            Position-MatrixWindows
                            Write-Host ""
                            Write-Host " Primary: $($config.WindowsOnPrimary) windows" -ForegroundColor Cyan
                            Start-Sleep -Milliseconds 500
                        }
                    }
                }
                ')' {
                    # Reset to Auto (Shift+0)
                    $config = Get-MatrixLayoutConfig
                    $screens = Get-ScreenTopology
                    if ($screens.Count -gt 1) {
                        $config.WindowsOnPrimary = $null
                        Set-MatrixLayoutConfig -Config $config
                        Position-MatrixWindows
                        Write-Host ""
                        Write-Host " Primary: Auto (all windows)" -ForegroundColor Cyan
                        Start-Sleep -Milliseconds 500
                    }
                }
            }
        }
    }
} finally {
    [Console]::CursorVisible = $true
}
