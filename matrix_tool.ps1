# ======================================================
# MATRIX MASTER CONTROL v2.0
# Authentic Katakana-style characters + Enhanced UI
# ======================================================
param(
    [switch]$SkipStartup,    # Go straight to TUI (redpill)
    [switch]$InstantLaunch   # Load last settings and launch immediately (bluepill)
)

$shaderPath = "$env:USERPROFILE\Documents\Matrix\Matrix.hlsl"
$configDir = "$env:USERPROFILE\.matrix-shader"
$configPath = "$configDir\config.json"

# --- MONITOR DETECTION ---
# Add Windows API types for monitor enumeration
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public struct MONITORINFO {
    public uint cbSize;
    public RECT rcMonitor;
    public RECT rcWork;
    public uint dwFlags;
}

public class MonitorDetection {
    public delegate bool MonitorEnumDelegate(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumDelegate lpfnEnum, IntPtr dwData);

    [DllImport("user32.dll")]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

    public static List<MonitorInfo> monitors = new List<MonitorInfo>();

    public class MonitorInfo {
        public int Index;
        public int Left;
        public int Top;
        public int Width;
        public int Height;
        public bool IsPrimary;
    }

    public static bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData) {
        MONITORINFO mi = new MONITORINFO();
        mi.cbSize = (uint)Marshal.SizeOf(typeof(MONITORINFO));

        if (GetMonitorInfo(hMonitor, ref mi)) {
            MonitorInfo info = new MonitorInfo();
            info.Index = monitors.Count + 1;
            info.Left = mi.rcMonitor.Left;
            info.Top = mi.rcMonitor.Top;
            info.Width = mi.rcMonitor.Right - mi.rcMonitor.Left;
            info.Height = mi.rcMonitor.Bottom - mi.rcMonitor.Top;
            info.IsPrimary = (mi.dwFlags & 1) != 0;  // MONITORINFOF_PRIMARY = 1
            monitors.Add(info);
        }
        return true;
    }

    public static MonitorInfo[] GetMonitors() {
        monitors.Clear();
        MonitorEnumDelegate callback = new MonitorEnumDelegate(MonitorEnumProc);
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);

        // Sort by left position (leftmost first)
        monitors.Sort((a, b) => a.Left.CompareTo(b.Left));

        // Re-index after sorting
        for (int i = 0; i < monitors.Count; i++) {
            monitors[i].Index = i + 1;
        }

        return monitors.ToArray();
    }
}
"@ -ErrorAction SilentlyContinue

# Global monitor info storage
$script:detectedMonitors = @()

function Get-DetectedMonitors {
    <#
    .SYNOPSIS
    Detects all connected monitors and returns their info
    .DESCRIPTION
    Uses Windows API to enumerate monitors and get their resolution and position
    .OUTPUTS
    Array of monitor info objects with Index, Left, Top, Width, Height, IsPrimary
    #>
    try {
        $monitors = [MonitorDetection]::GetMonitors()
        $script:detectedMonitors = @()

        foreach ($mon in $monitors) {
            $script:detectedMonitors += [PSCustomObject]@{
                Index = $mon.Index
                Left = $mon.Left
                Top = $mon.Top
                Width = $mon.Width
                Height = $mon.Height
                IsPrimary = $mon.IsPrimary
                Resolution = "$($mon.Width)x$($mon.Height)"
                Position = if ($mon.Left -lt 0) { "Left" } elseif ($mon.Left -eq 0) { "Primary" } else { "Right" }
            }
        }

        return $script:detectedMonitors
    } catch {
        # Fallback: return single monitor with screen dimensions
        $script:detectedMonitors = @([PSCustomObject]@{
            Index = 1
            Left = 0
            Top = 0
            Width = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
            Height = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
            IsPrimary = $true
            Resolution = "$([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width)x$([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)"
            Position = "Primary"
        })
        return $script:detectedMonitors
    }
}

function Show-MonitorInfo {
    <#
    .SYNOPSIS
    Displays detected monitor configuration
    #>
    $monitors = Get-DetectedMonitors

    if ($monitors.Count -eq 0) {
        Write-Host " No monitors detected" -ForegroundColor Red
        return
    }

    # Build summary string
    $resolutions = ($monitors | ForEach-Object { $_.Resolution }) -join ", "
    $uniqueRes = ($monitors | Select-Object -Property Resolution -Unique | ForEach-Object { $_.Resolution }) -join " / "

    if (($monitors | Select-Object -Property Resolution -Unique).Count -eq 1) {
        Write-Host " Detected: $($monitors.Count) monitor(s) ($($monitors[0].Resolution) each)" -ForegroundColor Cyan
    } else {
        Write-Host " Detected: $($monitors.Count) monitor(s) ($uniqueRes)" -ForegroundColor Cyan
    }

    # Show details for each monitor
    foreach ($mon in $monitors) {
        $primary = if ($mon.IsPrimary) { " [PRIMARY]" } else { "" }
        Write-Host "   Monitor $($mon.Index): $($mon.Resolution) at ($($mon.Left), $($mon.Top))$primary" -ForegroundColor DarkCyan
    }
}

# --- CONFIG PERSISTENCE FUNCTIONS ---
function Save-MatrixConfig {
    param([hashtable]$Settings)
    try {
        # Ensure config directory exists
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Build config object with all settings
        $config = @{
            colorPreset = $script:currentPreset
            colors = @{
                R = $Settings.R
                G = $Settings.G
                B = $Settings.B
            }
            effects = @{
                Speed = $Settings.Speed
                Glow = $Settings.Glow
                Scale = $Settings.Scale
                Width = $Settings.Width
                Trail = $Settings.Trail
                Dens = $Settings.Dens
            }
            layers = @{
                L1 = $Settings.L1
                L2 = $Settings.L2
                L3 = $Settings.L3
            }
            transparency = @{
                enabled = $script:transparencyEnabled
                opacity = $script:opacityValue
            }
            windowLayout = @{
                windowCount = $script:windowCount
                gapSize = $script:gapSize
                monitors = $script:selectedMonitors
            }
            detectedMonitors = @($script:detectedMonitors | ForEach-Object {
                @{
                    Index = $_.Index
                    Width = $_.Width
                    Height = $_.Height
                    Left = $_.Left
                    Top = $_.Top
                    IsPrimary = $_.IsPrimary
                }
            })
            lastSaved = (Get-Date).ToString("o")
        }

        $config | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8
        return $true
    } catch {
        Write-Host " ERROR: Failed to save config - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Load-MatrixConfig {
    try {
        if (-not (Test-Path $configPath)) {
            return $null
        }

        $json = Get-Content -Path $configPath -Raw -ErrorAction Stop
        $config = $json | ConvertFrom-Json

        # Validate required fields exist
        if (-not $config.colors -or -not $config.effects -or -not $config.layers) {
            return $null
        }

        return $config
    } catch {
        # Corrupted or invalid config - return null to use defaults
        return $null
    }
}

function Get-DefaultConfig {
    return @{
        colorPreset = "Classic Green"
        colors = @{ R = "0.0"; G = "1.0"; B = "0.2" }
        effects = @{ Speed = "1.0"; Glow = "1.5"; Scale = "1.0"; Width = "8.0"; Trail = "8.0"; Dens = "1.0" }
        layers = @{ L1 = "1.0"; L2 = "1.0"; L3 = "1.0" }
        transparency = @{ enabled = $false; opacity = 100 }
        windowLayout = @{ windowCount = 4; gapSize = 150; monitors = @() }
    }
}

# --- WINDOWS TERMINAL SETTINGS ---
$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

function Update-TerminalOpacity {
    param(
        [int]$Opacity = 100,  # 0-100 integer
        [bool]$UseAcrylic = $false
    )
    try {
        if (-not (Test-Path $terminalSettingsPath)) {
            return $false
        }

        # Ensure opacity is valid integer 0-100
        $Opacity = [Math]::Max(0, [Math]::Min(100, [int]$Opacity))

        $settings = Get-Content $terminalSettingsPath -Raw | ConvertFrom-Json

        # Update all Matrix profiles (guid pattern: *7ce5bfe-*7ed-5f3a-ab15-5cd5baafed5b)
        foreach ($profile in $settings.profiles.list) {
            if ($profile.name -like "Matrix-*") {
                # Set opacity as INTEGER (Windows Terminal expects 0-100)
                $profile | Add-Member -NotePropertyName "opacity" -NotePropertyValue $Opacity -Force

                if ($UseAcrylic) {
                    $profile | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $true -Force
                } else {
                    # Remove acrylic properties if present
                    $profile.PSObject.Properties.Remove("useAcrylic")
                    $profile.PSObject.Properties.Remove("acrylicOpacity")
                }

                # Always remove CRT effect
                $profile.PSObject.Properties.Remove("experimental.retroTerminalEffect")
            }
        }

        # Write back with proper formatting
        $settings | ConvertTo-Json -Depth 10 | Set-Content $terminalSettingsPath -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

# --- WINDOW POSITIONING ---
# Add Windows API for window positioning
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WindowPositioning {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_SHOWWINDOW = 0x0040;
}
"@ -ErrorAction SilentlyContinue

function Get-WindowsByProcessId {
    <#
    .SYNOPSIS
    Gets window handles for a given process ID
    #>
    param([int]$ProcessId)

    $windows = @()
    $callback = [WindowPositioning+EnumWindowsProc]{
        param($hWnd, $lParam)

        $procId = 0
        [WindowPositioning]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null

        if ($procId -eq $ProcessId -and [WindowPositioning]::IsWindowVisible($hWnd)) {
            $length = [WindowPositioning]::GetWindowTextLength($hWnd)
            if ($length -gt 0) {
                $script:foundWindows += $hWnd
            }
        }
        return $true
    }

    $script:foundWindows = @()
    [WindowPositioning]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
    return $script:foundWindows
}

function Set-WindowPosition {
    <#
    .SYNOPSIS
    Positions a window at the specified location and size
    #>
    param(
        [IntPtr]$WindowHandle,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    $result = [WindowPositioning]::SetWindowPos(
        $WindowHandle,
        [IntPtr]::Zero,
        $X, $Y, $Width, $Height,
        [WindowPositioning]::SWP_NOZORDER -bor [WindowPositioning]::SWP_SHOWWINDOW
    )
    return $result
}

function Get-SmartGapSize {
    <#
    .SYNOPSIS
    Returns appropriate gap size based on windows per monitor
    #>
    param([int]$WindowsPerMonitor)

    switch ($WindowsPerMonitor) {
        1 { return 0 }       # Single window - no gap needed
        2 { return 150 }     # 2 windows - larger gap
        3 { return 75 }      # 3 windows - smaller gap
        default { return 50 } # 4+ windows - minimal gap
    }
}

function Calculate-WindowLayout {
    <#
    .SYNOPSIS
    Calculates window positions for smart multi-monitor layout
    .OUTPUTS
    Array of position objects with X, Y, Width, Height for each window
    #>
    param(
        [int]$WindowCount = 4,
        [int]$GapOverride = -1  # -1 means use smart gaps
    )

    $monitors = Get-DetectedMonitors
    $monitorCount = $monitors.Count

    if ($monitorCount -eq 0) {
        return @()
    }

    $positions = @()
    $windowsRemaining = $WindowCount

    # Distribute windows across monitors
    $windowsPerMonitor = [Math]::Ceiling($WindowCount / $monitorCount)

    foreach ($monitor in $monitors) {
        if ($windowsRemaining -le 0) { break }

        $windowsOnThisMonitor = [Math]::Min($windowsPerMonitor, $windowsRemaining)

        # Get gap size (smart or override)
        $gap = if ($GapOverride -ge 0) { $GapOverride } else { Get-SmartGapSize -WindowsPerMonitor $windowsOnThisMonitor }

        # Calculate window width accounting for gaps
        # Total gaps = (windowsOnThisMonitor - 1) internal gaps + 1 center gap
        $totalGapWidth = $gap * $windowsOnThisMonitor
        $availableWidth = $monitor.Width - $totalGapWidth
        $windowWidth = [Math]::Floor($availableWidth / $windowsOnThisMonitor)

        # Position windows on this monitor
        for ($i = 0; $i -lt $windowsOnThisMonitor; $i++) {
            # X position: monitor left + (window index * (window width + gap)) + half gap
            $x = $monitor.Left + ($i * ($windowWidth + $gap)) + [Math]::Floor($gap / 2)

            $positions += [PSCustomObject]@{
                X = $x
                Y = $monitor.Top
                Width = $windowWidth
                Height = $monitor.Height
                MonitorIndex = $monitor.Index
            }
        }

        $windowsRemaining -= $windowsOnThisMonitor
    }

    return $positions
}

# --- WINDOW LAUNCHING ---
function Launch-MatrixWindows {
    <#
    .SYNOPSIS
    Launches Matrix terminal windows using Windows Terminal profiles with smart positioning
    .PARAMETER WindowCount
    Number of windows to launch (1-8)
    .PARAMETER UseSmartPositioning
    If true, positions windows with smart gaps across monitors
    #>
    param(
        [int]$WindowCount = 4,
        [bool]$UseSmartPositioning = $true
    )

    # Clamp to available profiles (Matrix-1 through Matrix-8)
    $WindowCount = [Math]::Max(1, [Math]::Min(8, $WindowCount))

    # Matrix profile GUIDs
    $profileGuids = @(
        "{17ce5bfe-17ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-1
        "{27ce5bfe-27ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-2
        "{37ce5bfe-37ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-3
        "{47ce5bfe-47ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-4
        "{57ce5bfe-57ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-5
        "{67ce5bfe-67ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-6
        "{77ce5bfe-77ed-5f3a-ab15-5cd5baafed5b}",  # Matrix-7
        "{87ce5bfe-87ed-5f3a-ab15-5cd5baafed5b}"   # Matrix-8
    )

    Write-Host ""
    Write-Host " Entering the Matrix..." -ForegroundColor Green

    # Calculate positions if smart positioning enabled
    $positions = @()
    if ($UseSmartPositioning) {
        $positions = Calculate-WindowLayout -WindowCount $WindowCount -GapOverride $script:gapSize
    }

    # Launch each window and track process IDs
    $processes = @()
    for ($i = 0; $i -lt $WindowCount; $i++) {
        $guid = $profileGuids[$i]
        $proc = Start-Process "wt.exe" -ArgumentList "-p", $guid -WindowStyle Normal -PassThru
        $processes += $proc
        Start-Sleep -Milliseconds 300  # Small delay between launches
    }

    # Position windows if smart positioning enabled
    if ($UseSmartPositioning -and $positions.Count -gt 0) {
        Write-Host " Positioning windows..." -ForegroundColor DarkGreen
        Start-Sleep -Milliseconds 800  # Wait for windows to initialize

        for ($i = 0; $i -lt $processes.Count; $i++) {
            if ($i -ge $positions.Count) { break }

            $proc = $processes[$i]
            $pos = $positions[$i]

            # Find the window handle for this process
            $windows = Get-WindowsByProcessId -ProcessId $proc.Id

            if ($windows.Count -gt 0) {
                $hwnd = $windows[0]
                Set-WindowPosition -WindowHandle $hwnd -X $pos.X -Y $pos.Y -Width $pos.Width -Height $pos.Height | Out-Null
            }
        }
    }

    Write-Host " Launched $WindowCount Matrix window(s)" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
}

# --- STATE VARIABLES FOR CONFIG ---
$script:currentPreset = "Classic Green"
$script:transparencyEnabled = $false
$script:opacityValue = 100
$script:windowCount = 4
$script:gapSize = 150
$script:selectedMonitors = @()

# --- SELECTION STATE FOR TUI NAVIGATION ---
# Sections: 0=Parameters, 1=Layers, 2=Transparency
$script:currentSection = 0
# Items within each section
$script:parameterItems = @("Speed", "Glow", "Width", "Trail", "Dens")
$script:layerItems = @("L1", "L2", "L3")
$script:transparencyItems = @("Toggle", "Opacity")
# Current selection within section
$script:currentItem = 0

function Get-HighlightedText {
    <#
    .SYNOPSIS
    Returns text with highlight formatting if selected
    #>
    param(
        [string]$Text,
        [bool]$IsSelected,
        [string]$NormalColor = "White",
        [string]$SelectedBg = "DarkCyan"
    )

    if ($IsSelected) {
        # Return with inverse/highlight colors
        return @{ Text = $Text; FG = "Black"; BG = $SelectedBg }
    } else {
        return @{ Text = $Text; FG = $NormalColor; BG = $null }
    }
}

function Write-SelectableLine {
    <#
    .SYNOPSIS
    Writes a line with optional selection highlighting
    #>
    param(
        [string]$Text,
        [bool]$IsSelected,
        [string]$Prefix = "   "
    )

    if ($IsSelected) {
        Write-Host "$Prefix" -NoNewline
        Write-Host " $Text " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        Write-Host ""
    } else {
        Write-Host "$Prefix$Text"
    }
}

# Detect monitors on startup
$null = Get-DetectedMonitors

function Apply-ConfigToSettings {
    param($Config, [hashtable]$Settings)

    if ($Config.colors) {
        if ($Config.colors.R) { $Settings.R = $Config.colors.R }
        if ($Config.colors.G) { $Settings.G = $Config.colors.G }
        if ($Config.colors.B) { $Settings.B = $Config.colors.B }
    }
    if ($Config.effects) {
        if ($Config.effects.Speed) { $Settings.Speed = $Config.effects.Speed }
        if ($Config.effects.Glow) { $Settings.Glow = $Config.effects.Glow }
        if ($Config.effects.Scale) { $Settings.Scale = $Config.effects.Scale }
        if ($Config.effects.Width) { $Settings.Width = $Config.effects.Width }
        if ($Config.effects.Trail) { $Settings.Trail = $Config.effects.Trail }
        if ($Config.effects.Dens) { $Settings.Dens = $Config.effects.Dens }
    }
    if ($Config.layers) {
        if ($Config.layers.L1) { $Settings.L1 = $Config.layers.L1 }
        if ($Config.layers.L2) { $Settings.L2 = $Config.layers.L2 }
        if ($Config.layers.L3) { $Settings.L3 = $Config.layers.L3 }
    }
    if ($Config.colorPreset) {
        $script:currentPreset = $Config.colorPreset
    }
    if ($Config.transparency) {
        $script:transparencyEnabled = [bool]$Config.transparency.enabled
        $script:opacityValue = [int]$Config.transparency.opacity
    }
    if ($Config.windowLayout) {
        if ($Config.windowLayout.windowCount) { $script:windowCount = [int]$Config.windowLayout.windowCount }
        if ($Config.windowLayout.gapSize) { $script:gapSize = [int]$Config.windowLayout.gapSize }
        if ($Config.windowLayout.monitors) { $script:selectedMonitors = @($Config.windowLayout.monitors) }
    }

    return $Settings
}

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
$defaults = @{ R="0.0"; G="1.0"; B="0.3"; Speed="0.8"; Glow="0.8"; Scale="1.0"; Width="10.0"; Trail="8.0"; Dens="0.4"; L1="1.0"; L2="0.0"; L3="1.0" }

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
# First try to load from saved config, then fall back to shader file, then defaults
$loadedConfig = Load-MatrixConfig

if ($loadedConfig) {
    # Config exists - use it as base, start with defaults
    $s = $defaults.Clone()
    $s = Apply-ConfigToSettings -Config $loadedConfig -Settings $s
} elseif (Test-Path $shaderPath) {
    # No config but shader exists - read from shader
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
} else {
    # Nothing exists - use defaults
    $s = $defaults.Clone()
}

# --- STATE ---
$showHelp = $false

function Save-Shader {
    param([switch]$SaveConfig = $true)
    try {
        $out = $shaderTemplate -replace "{R}",$s.R -replace "{G}",$s.G -replace "{B}",$s.B `
            -replace "{SPEED}",$s.Speed -replace "{GLOW}",$s.Glow -replace "{SCALE}",$s.Scale `
            -replace "{WIDTH}",$s.Width -replace "{TRAIL}",$s.Trail -replace "{DENS}",$s.Dens `
            -replace "{L1}",$s.L1 -replace "{L2}",$s.L2 -replace "{L3}",$s.L3
        Set-Content -Path $shaderPath -Value $out -ErrorAction Stop
        (Get-Item $shaderPath).LastWriteTime = Get-Date

        # Also save to config file for persistence
        if ($SaveConfig) {
            Save-MatrixConfig -Settings $s | Out-Null
        }
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

function Get-Bar($val, $min, $max, $width) {
    $pct = ([float]$val - $min) / ($max - $min)
    $filled = [int]($pct * $width)
    $empty = $width - $filled
    "$([char]27)[32m$('█' * $filled)$([char]27)[90m$('░' * $empty)$([char]27)[0m"
}

# --- PER-WINDOW SHADER SUPPORT ---
$script:currentSlot = 1
$script:shadersDir = "$env:USERPROFILE\Documents\Matrix\shaders"

function Get-ExistingSlots {
    $slots = @()
    # Check for individual shader files
    if (Test-Path $script:shadersDir) {
        for ($i = 1; $i -le 8; $i++) {
            if (Test-Path "$script:shadersDir\Matrix-$i.hlsl") {
                $slots += $i
            }
        }
    }
    # If no individual shaders, return slot 1 as default
    if ($slots.Count -eq 0) { $slots = @(1) }
    return $slots
}

function Show-HelpScreen {
    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host " ║           MATRIX MASTER CONTROL - HELP                   ║" -ForegroundColor Green
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host " NAVIGATION (Arrow Keys)" -ForegroundColor Yellow
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   Up/Down     Move selection between settings"
    Write-Host "   Left/Right  Adjust selected value"
    Write-Host "   +/-         Alternative: adjust selected value"
    Write-Host ""
    Write-Host " COLOR CONTROLS" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   r/R     Red channel      -/+ (0.0 - 1.0)"
    Write-Host "   g/G     Green channel    -/+ (0.0 - 1.0)"
    Write-Host "   b/B     Blue channel     -/+ (0.0 - 1.0)"
    Write-Host ""
    Write-Host " PRESETS" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   1-6     Color presets (Green, Blue, Red, Purple, Gold, Teal)"
    Write-Host "   0       Reset All (back to defaults)"
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
    Write-Host " TRANSPARENCY" -ForegroundColor Cyan
    Write-Host " ─────────────────────────────────────────────────────────"
    Write-Host "   X       Toggle transparency ON/OFF"
    Write-Host "   o/O     Opacity level      -/+ (0-100%)"
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

    # Show monitor info
    Show-MonitorInfo
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

    # PARAMETERS section with selection highlighting
    $paramHeader = if ($script:currentSection -eq 0) { " PARAMETERS" } else { " PARAMETERS" }
    Write-Host $paramHeader -ForegroundColor $(if ($script:currentSection -eq 0) { "Cyan" } else { "DarkGreen" })

    # Row 1: Speed, Glow, Width
    Write-Host "   " -NoNewline
    $items = @(
        @{ Key = "S"; Name = "Speed"; Value = $s.Speed; Idx = 0 },
        @{ Key = "L"; Name = "Glow"; Value = $s.Glow; Idx = 1 },
        @{ Key = "W"; Name = "Width"; Value = $s.Width; Idx = 2 }
    )
    foreach ($item in $items) {
        $isSelected = ($script:currentSection -eq 0 -and $script:currentItem -eq $item.Idx)
        $text = "[$($item.Key)] $($item.Name): $($item.Value)"
        if ($isSelected) {
            Write-Host " $text " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        } else {
            Write-Host "$text" -NoNewline
        }
        Write-Host "   " -NoNewline
    }
    Write-Host ""

    # Row 2: Trail, Dens
    Write-Host "   " -NoNewline
    $items2 = @(
        @{ Key = "T"; Name = "Trail"; Value = $s.Trail; Idx = 3 },
        @{ Key = "D"; Name = "Dens"; Value = $s.Dens; Idx = 4 }
    )
    foreach ($item in $items2) {
        $isSelected = ($script:currentSection -eq 0 -and $script:currentItem -eq $item.Idx)
        $text = "[$($item.Key)] $($item.Name): $($item.Value)"
        if ($isSelected) {
            Write-Host " $text " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        } else {
            Write-Host "$text" -NoNewline
        }
        Write-Host "   " -NoNewline
    }
    Write-Host ""
    Write-Host ""

    # LAYERS section with selection highlighting
    Write-Host " LAYERS" -ForegroundColor $(if ($script:currentSection -eq 1) { "Cyan" } else { "DarkGreen" })
    $l1 = if($s.L1 -eq "1.0"){"ON "}else{"OFF"}
    $l2 = if($s.L2 -eq "1.0"){"ON "}else{"OFF"}
    $l3 = if($s.L3 -eq "1.0"){"ON "}else{"OFF"}

    Write-Host "   " -NoNewline
    $layerItems = @(
        @{ Key = "7"; Name = "FAR"; Value = $l1; Idx = 0 },
        @{ Key = "8"; Name = "MID"; Value = $l2; Idx = 1 },
        @{ Key = "9"; Name = "NEAR"; Value = $l3; Idx = 2 }
    )
    foreach ($item in $layerItems) {
        $isSelected = ($script:currentSection -eq 1 -and $script:currentItem -eq $item.Idx)
        $text = "[$($item.Key)] $($item.Name): $($item.Value)"
        if ($isSelected) {
            Write-Host " $text " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
        } else {
            Write-Host "$text" -NoNewline
        }
        Write-Host "   " -NoNewline
    }
    Write-Host ""
    Write-Host ""

    # TRANSPARENCY section with selection highlighting
    Write-Host " TRANSPARENCY" -ForegroundColor $(if ($script:currentSection -eq 2) { "Cyan" } else { "DarkGreen" })
    $transStatus = if($script:transparencyEnabled){"ON "}else{"OFF"}
    $opacityBar = "[" + ("=" * [Math]::Floor($script:opacityValue / 10)) + (" " * (10 - [Math]::Floor($script:opacityValue / 10))) + "]"

    Write-Host "   " -NoNewline
    # Toggle item
    $isSelectedToggle = ($script:currentSection -eq 2 -and $script:currentItem -eq 0)
    $toggleText = "[X] Transparency: $transStatus"
    if ($isSelectedToggle) {
        Write-Host " $toggleText " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
    } else {
        Write-Host "$toggleText" -NoNewline
    }
    Write-Host "   " -NoNewline

    # Opacity item
    $isSelectedOpacity = ($script:currentSection -eq 2 -and $script:currentItem -eq 1)
    $opacityText = "[O/o] Opacity: $($script:opacityValue)% $opacityBar"
    if ($isSelectedOpacity) {
        Write-Host " $opacityText " -ForegroundColor Black -BackgroundColor DarkCyan -NoNewline
    } else {
        Write-Host "$opacityText" -NoNewline
    }
    Write-Host ""
    Write-Host ""

    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [Arrow] Navigate   [H] Help   [0] Reset   [Q] Quit" -ForegroundColor DarkGray
}

# --- STARTUP BANNER AND MENU ---
function Show-WakeUpBanner {
    [System.Console]::Clear()
    Write-Host ""
    Write-Host ""
    Write-Host "        Wake up, Neo..." -ForegroundColor Green
    Start-Sleep -Milliseconds 800
    Write-Host ""
    Write-Host "        The Matrix has you..." -ForegroundColor Green
    Start-Sleep -Milliseconds 800
    Write-Host ""
    Write-Host "        Follow the white rabbit." -ForegroundColor Green
    Start-Sleep -Milliseconds 1000
}

function Show-StartupMenu {
    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host " ║              MATRIX SHADER CONTROL                       ║" -ForegroundColor Green
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    # Show monitor info
    Show-MonitorInfo
    Write-Host ""

    # Check if we have saved settings
    $hasSavedConfig = Test-Path $configPath

    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    if ($hasSavedConfig) {
        Write-Host "   [1] " -NoNewline -ForegroundColor White
        Write-Host "Knock, Knock, Neo" -NoNewline -ForegroundColor Cyan
        Write-Host "   - Launch with last settings" -ForegroundColor DarkGray
    } else {
        Write-Host "   [1] " -NoNewline -ForegroundColor DarkGray
        Write-Host "Knock, Knock, Neo" -NoNewline -ForegroundColor DarkGray
        Write-Host "   - (no saved settings)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "   [2] " -NoNewline -ForegroundColor White
    Write-Host "Blue Pill" -NoNewline -ForegroundColor Blue
    Write-Host "          - Quick preset selection" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [3] " -NoNewline -ForegroundColor White
    Write-Host "Red Pill" -NoNewline -ForegroundColor Red
    Write-Host "           - Full customization wizard" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""

    return $hasSavedConfig
}

function Run-StartupMenu {
    <#
    .SYNOPSIS
    Shows the 3-option startup menu and returns the user's choice
    .OUTPUTS
    "knock" | "blue" | "red" | "quit"
    #>
    $hasSavedConfig = Show-StartupMenu

    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $ch = $key.Character

        switch ($ch) {
            '1' {
                if ($hasSavedConfig) {
                    return "knock"
                }
                # No saved config - flash message and continue
                Write-Host "`r   No saved settings found. Try Blue Pill or Red Pill.    " -ForegroundColor Yellow -NoNewline
                Start-Sleep -Milliseconds 1500
                $null = Show-StartupMenu
            }
            '2' { return "blue" }
            '3' { return "red" }
            'q' { return "quit" }
            'Q' { return "quit" }
        }
    }
}

# --- BLUE PILL FLOW ---
function Show-BluePillPresets {
    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host " ║              BLUE PILL - Quick Setup                     ║" -ForegroundColor Blue
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    Write-Host " Choose your color:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($key in '1','2','3','4','5','6') {
        $p = $presets[$key]
        $sw = Get-PresetSwatch $p
        Write-Host "   [$key] $sw $($p.Name)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [B] Back   [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-BluePillTransparency {
    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host " ║              BLUE PILL - Transparency                    ║" -ForegroundColor Blue
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    Write-Host " Choose transparency mode:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] Solid Black    - No transparency (default)" -ForegroundColor White
    Write-Host "   [2] Transparent    - 50% see-through" -ForegroundColor White
    Write-Host "   [3] Custom         - Enter your own value (0-100)" -ForegroundColor White
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [B] Back   [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-BluePillConfirm {
    param($PresetName, $TransparencyMode, $OpacityValue)

    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host " ║              BLUE PILL - Ready to Launch                 ║" -ForegroundColor Blue
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    Write-Host " Your settings:" -ForegroundColor Cyan
    Write-Host "   Color:        $PresetName" -ForegroundColor White
    Write-Host "   Transparency: $TransparencyMode ($OpacityValue%)" -ForegroundColor White
    Write-Host "   Windows:      $($script:windowCount)" -ForegroundColor White
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [Enter] " -NoNewline -ForegroundColor White
    Write-Host "Enter the Matrix" -NoNewline -ForegroundColor Green
    Write-Host "   - Launch now!" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [R]     " -NoNewline -ForegroundColor White
    Write-Host "Red Pill" -NoNewline -ForegroundColor Red
    Write-Host "           - Customize more" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [B] Back   [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

function Run-BluePillFlow {
    <#
    .SYNOPSIS
    Runs the Blue Pill quick setup flow
    .OUTPUTS
    "launch" | "red" | "quit"
    #>

    # Step 1: Color preset selection
    Show-BluePillPresets

    $selectedPreset = $null
    while ($null -eq $selectedPreset) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $ch = $key.Character

        switch ($ch) {
            '1' { $selectedPreset = $presets['1']; $s.R=$presets['1'].R; $s.G=$presets['1'].G; $s.B=$presets['1'].B; $script:currentPreset=$presets['1'].Name }
            '2' { $selectedPreset = $presets['2']; $s.R=$presets['2'].R; $s.G=$presets['2'].G; $s.B=$presets['2'].B; $script:currentPreset=$presets['2'].Name }
            '3' { $selectedPreset = $presets['3']; $s.R=$presets['3'].R; $s.G=$presets['3'].G; $s.B=$presets['3'].B; $script:currentPreset=$presets['3'].Name }
            '4' { $selectedPreset = $presets['4']; $s.R=$presets['4'].R; $s.G=$presets['4'].G; $s.B=$presets['4'].B; $script:currentPreset=$presets['4'].Name }
            '5' { $selectedPreset = $presets['5']; $s.R=$presets['5'].R; $s.G=$presets['5'].G; $s.B=$presets['5'].B; $script:currentPreset=$presets['5'].Name }
            '6' { $selectedPreset = $presets['6']; $s.R=$presets['6'].R; $s.G=$presets['6'].G; $s.B=$presets['6'].B; $script:currentPreset=$presets['6'].Name }
            'b' { return "back" }
            'B' { return "back" }
            'q' { return "quit" }
            'Q' { return "quit" }
        }
    }

    # Step 2: Transparency selection
    Show-BluePillTransparency

    $transparencyMode = $null
    while ($null -eq $transparencyMode) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $ch = $key.Character

        switch ($ch) {
            '1' {
                $transparencyMode = "Solid"
                $script:transparencyEnabled = $false
                $script:opacityValue = 100
            }
            '2' {
                $transparencyMode = "Transparent"
                $script:transparencyEnabled = $true
                $script:opacityValue = 50
            }
            '3' {
                # Custom - prompt for value
                Write-Host "`r   Enter opacity (0-100): " -NoNewline -ForegroundColor Yellow
                $input = ""
                while ($true) {
                    $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($k.VirtualKeyCode -eq 13) { break }  # Enter
                    if ($k.VirtualKeyCode -eq 8) {  # Backspace
                        if ($input.Length -gt 0) {
                            $input = $input.Substring(0, $input.Length - 1)
                            Write-Host "`b `b" -NoNewline
                        }
                    } elseif ($k.Character -match '[0-9]') {
                        $input += $k.Character
                        Write-Host $k.Character -NoNewline
                    }
                }
                $val = [int]$input
                $val = [Math]::Max(0, [Math]::Min(100, $val))
                $transparencyMode = "Custom"
                $script:transparencyEnabled = ($val -lt 100)
                $script:opacityValue = $val
            }
            'b' { return Run-BluePillFlow }  # Restart flow
            'B' { return Run-BluePillFlow }
            'q' { return "quit" }
            'Q' { return "quit" }
        }
    }

    # Step 3: Confirmation
    Show-BluePillConfirm -PresetName $selectedPreset.Name -TransparencyMode $transparencyMode -OpacityValue $script:opacityValue

    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        if ($key.VirtualKeyCode -eq 13) {  # Enter
            return "launch"
        }

        $ch = $key.Character
        switch ($ch) {
            'r' { return "red" }
            'R' { return "red" }
            'b' { return Run-BluePillFlow }  # Restart flow
            'B' { return Run-BluePillFlow }
            'q' { return "quit" }
            'Q' { return "quit" }
        }
    }
}

# --- RED PILL WIZARD ---
function Show-RedPillHeader {
    param([string]$StepTitle, [int]$StepNum, [int]$TotalSteps = 4)
    [System.Console]::Clear()
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host " ║              RED PILL - Full Customization               ║" -ForegroundColor Red
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host " Step $StepNum of $TotalSteps : $StepTitle" -ForegroundColor Yellow
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-RedPillStep1-Color {
    Show-RedPillHeader -StepTitle "Color Settings" -StepNum 1 -TotalSteps 5

    $swatch = Get-ColorSwatch
    Write-Host " Current Color: $swatch R:$($s.R) G:$($s.G) B:$($s.B)" -ForegroundColor White
    Write-Host ""
    Write-Host " PRESETS:" -ForegroundColor Cyan
    foreach ($key in '1','2','3','4','5','6') {
        $p = $presets[$key]
        $sw = Get-PresetSwatch $p
        Write-Host "   [$key] $sw $($p.Name)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host " CUSTOM RGB (fine tune):" -ForegroundColor Cyan
    Write-Host "   [R/r] Red   +/-     Current: $($s.R)" -ForegroundColor White
    Write-Host "   [G/g] Green +/-     Current: $($s.G)" -ForegroundColor White
    Write-Host "   [B/b] Blue  +/-     Current: $($s.B)" -ForegroundColor White
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [N] Next Step   [C] Cancel" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-RedPillStep2-Effects {
    Show-RedPillHeader -StepTitle "Effect Settings" -StepNum 2 -TotalSteps 5

    Write-Host " Adjust rain effect parameters:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [S/s] Speed    +/-     Current: $($s.Speed)" -ForegroundColor White
    Write-Host "   [D/d] Density  +/-     Current: $($s.Dens)" -ForegroundColor White
    Write-Host "   [L/l] Glow     +/-     Current: $($s.Glow)" -ForegroundColor White
    Write-Host "   [W/w] Width    +/-     Current: $($s.Width)" -ForegroundColor White
    Write-Host "   [T/t] Trail    +/-     Current: $($s.Trail)" -ForegroundColor White
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [N] Next Step   [P] Previous Step   [C] Cancel" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-RedPillStep3-Layers {
    Show-RedPillHeader -StepTitle "Layer Settings" -StepNum 3 -TotalSteps 5

    $l1 = if($s.L1 -eq "1.0"){"ON "}else{"OFF"}
    $l2 = if($s.L2 -eq "1.0"){"ON "}else{"OFF"}
    $l3 = if($s.L3 -eq "1.0"){"ON "}else{"OFF"}

    Write-Host " Toggle depth layers for parallax effect:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] FAR layer   (background, subtle)    : $l1" -ForegroundColor White
    Write-Host "   [2] MID layer   (middle depth)          : $l2" -ForegroundColor White
    Write-Host "   [3] NEAR layer  (foreground, bright)    : $l3" -ForegroundColor White
    Write-Host ""
    Write-Host " Tip: All layers ON creates the classic Matrix look." -ForegroundColor DarkGray
    Write-Host "      Try just NEAR for a cleaner effect." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [N] Next Step   [P] Previous Step   [C] Cancel" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-RedPillStep4-Transparency {
    Show-RedPillHeader -StepTitle "Transparency Settings" -StepNum 4 -TotalSteps 5

    $transStatus = if($script:transparencyEnabled){"ON "}else{"OFF"}
    $opacityBar = "[" + ("=" * [Math]::Floor($script:opacityValue / 10)) + (" " * (10 - [Math]::Floor($script:opacityValue / 10))) + "]"

    Write-Host " Configure window transparency:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [X] Toggle Transparency    : $transStatus" -ForegroundColor White
    Write-Host ""
    if ($script:transparencyEnabled) {
        Write-Host "   [O/o] Opacity +/-          : $($script:opacityValue)% $opacityBar" -ForegroundColor White
        Write-Host ""
        Write-Host "   0% = fully transparent, 100% = solid" -ForegroundColor DarkGray
    } else {
        Write-Host "   Transparency is OFF (solid black background)" -ForegroundColor DarkGray
        Write-Host "   Press X to enable and adjust opacity" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [N] Next Step   [P] Previous Step   [C] Cancel" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-LayoutPreview {
    <#
    .SYNOPSIS
    Returns ASCII art preview of window layout
    #>
    param([int]$WindowCount, [int]$MonitorCount)

    $windowsPerMonitor = [Math]::Ceiling($WindowCount / $MonitorCount)
    $lines = @()

    # Build monitor preview
    $monitorWidth = 20
    $monitorHeight = 5

    # Top border
    $topLine = ""
    for ($m = 0; $m -lt $MonitorCount; $m++) {
        $topLine += "+" + ("-" * $monitorWidth) + "+"
        if ($m -lt $MonitorCount - 1) { $topLine += " " }
    }
    $lines += $topLine

    # Middle rows with windows
    for ($row = 0; $row -lt $monitorHeight; $row++) {
        $rowLine = ""
        for ($m = 0; $m -lt $MonitorCount; $m++) {
            $rowLine += "|"
            $windowsThisMonitor = [Math]::Min($windowsPerMonitor, $WindowCount - ($m * $windowsPerMonitor))
            if ($windowsThisMonitor -le 0) { $windowsThisMonitor = 0 }

            if ($windowsThisMonitor -gt 0) {
                $winWidth = [Math]::Floor(($monitorWidth - $windowsThisMonitor + 1) / $windowsThisMonitor)
                for ($w = 0; $w -lt $windowsThisMonitor; $w++) {
                    if ($row -eq [Math]::Floor($monitorHeight / 2)) {
                        $num = ($m * $windowsPerMonitor) + $w + 1
                        if ($num -le $WindowCount) {
                            $content = " $num "
                        } else {
                            $content = "   "
                        }
                    } else {
                        $content = "   "
                    }
                    $padding = $winWidth - 3
                    if ($padding -lt 0) { $padding = 0 }
                    $rowLine += "[" + $content + (" " * $padding) + "]"
                }
                $remaining = $monitorWidth - ($windowsThisMonitor * ($winWidth + 1))
                if ($remaining -gt 0) { $rowLine += " " * $remaining }
            } else {
                $rowLine += " " * $monitorWidth
            }
            $rowLine += "|"
            if ($m -lt $MonitorCount - 1) { $rowLine += " " }
        }
        $lines += $rowLine
    }

    # Bottom border with labels
    $bottomLine = ""
    for ($m = 0; $m -lt $MonitorCount; $m++) {
        $bottomLine += "+" + ("-" * $monitorWidth) + "+"
        if ($m -lt $MonitorCount - 1) { $bottomLine += " " }
    }
    $lines += $bottomLine

    # Monitor labels
    $labelLine = ""
    for ($m = 0; $m -lt $MonitorCount; $m++) {
        $label = "Monitor $($m + 1)"
        $padLeft = [Math]::Floor(($monitorWidth + 2 - $label.Length) / 2)
        $padRight = $monitorWidth + 2 - $label.Length - $padLeft
        $labelLine += (" " * $padLeft) + $label + (" " * $padRight)
        if ($m -lt $MonitorCount - 1) { $labelLine += " " }
    }
    $lines += $labelLine

    return $lines
}

function Show-RedPillStep5-Layout {
    Show-RedPillHeader -StepTitle "Window Layout" -StepNum 5 -TotalSteps 5

    $monitors = Get-DetectedMonitors
    $monitorCount = $monitors.Count

    Write-Host " Configure window layout:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [W/w] Windows +/-    : $($script:windowCount)" -ForegroundColor White
    Write-Host "   [G/g] Gap size +/-   : $($script:gapSize)px" -ForegroundColor White
    Write-Host ""
    Write-Host "   Quick presets:" -ForegroundColor DarkGray
    Write-Host "   [1] 2 windows   [2] 4 windows   [3] 6 windows   [4] 8 windows" -ForegroundColor White
    Write-Host ""
    Write-Host "   [0] Reset All to Defaults" -ForegroundColor Yellow
    Write-Host ""

    # Show layout preview
    Write-Host " Layout Preview:" -ForegroundColor Cyan
    $preview = Get-LayoutPreview -WindowCount $script:windowCount -MonitorCount $monitorCount
    foreach ($line in $preview) {
        Write-Host "   $line" -ForegroundColor DarkCyan
    }
    Write-Host ""

    Write-Host " ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   [Enter] Finish & Launch   [P] Previous Step   [C] Cancel" -ForegroundColor DarkGray
    Write-Host ""
}

function Run-RedPillWizard {
    <#
    .SYNOPSIS
    Runs the Red Pill full customization wizard
    .OUTPUTS
    "launch" | "cancel"
    #>
    $currentStep = 1
    $totalSteps = 5

    while ($true) {
        switch ($currentStep) {
            1 {
                Show-RedPillStep1-Color
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $ch = $key.Character

                switch -CaseSensitive ($ch) {
                    # Presets
                    '1' { $s.R=$presets['1'].R; $s.G=$presets['1'].G; $s.B=$presets['1'].B; $script:currentPreset=$presets['1'].Name }
                    '2' { $s.R=$presets['2'].R; $s.G=$presets['2'].G; $s.B=$presets['2'].B; $script:currentPreset=$presets['2'].Name }
                    '3' { $s.R=$presets['3'].R; $s.G=$presets['3'].G; $s.B=$presets['3'].B; $script:currentPreset=$presets['3'].Name }
                    '4' { $s.R=$presets['4'].R; $s.G=$presets['4'].G; $s.B=$presets['4'].B; $script:currentPreset=$presets['4'].Name }
                    '5' { $s.R=$presets['5'].R; $s.G=$presets['5'].G; $s.B=$presets['5'].B; $script:currentPreset=$presets['5'].Name }
                    '6' { $s.R=$presets['6'].R; $s.G=$presets['6'].G; $s.B=$presets['6'].B; $script:currentPreset=$presets['6'].Name }
                    # RGB adjust
                    'r' { if([float]$s.R -gt 0.0) { $s.R = "{0:N1}" -f ([float]$s.R - 0.1) } }
                    'R' { if([float]$s.R -lt 1.0) { $s.R = "{0:N1}" -f ([float]$s.R + 0.1) } }
                    'g' { if([float]$s.G -gt 0.0) { $s.G = "{0:N1}" -f ([float]$s.G - 0.1) } }
                    'G' { if([float]$s.G -lt 1.0) { $s.G = "{0:N1}" -f ([float]$s.G + 0.1) } }
                    'b' { if([float]$s.B -gt 0.0) { $s.B = "{0:N1}" -f ([float]$s.B - 0.1) } }
                    'B' { if([float]$s.B -lt 1.0) { $s.B = "{0:N1}" -f ([float]$s.B + 0.1) } }
                    # Navigation
                    'n' { $currentStep = 2 }
                    'N' { $currentStep = 2 }
                    'c' { return "cancel" }
                    'C' { return "cancel" }
                }
            }
            2 {
                Show-RedPillStep2-Effects
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $ch = $key.Character

                switch -CaseSensitive ($ch) {
                    # Effect adjustments
                    's' { if([float]$s.Speed -gt 0.1) { $s.Speed = "{0:N1}" -f ([float]$s.Speed - 0.1) } }
                    'S' { if([float]$s.Speed -lt 5.0) { $s.Speed = "{0:N1}" -f ([float]$s.Speed + 0.1) } }
                    'd' { if([float]$s.Dens -gt 0.1) { $s.Dens = "{0:N1}" -f ([float]$s.Dens - 0.1) } }
                    'D' { if([float]$s.Dens -lt 1.0) { $s.Dens = "{0:N1}" -f ([float]$s.Dens + 0.1) } }
                    'l' { if([float]$s.Glow -gt 0.2) { $s.Glow = "{0:N1}" -f ([float]$s.Glow - 0.2) } }
                    'L' { if([float]$s.Glow -lt 10.0) { $s.Glow = "{0:N1}" -f ([float]$s.Glow + 0.2) } }
                    'w' { if([float]$s.Width -gt 4.0) { $s.Width = "{0:N1}" -f ([float]$s.Width - 0.5) } }
                    'W' { if([float]$s.Width -lt 20.0) { $s.Width = "{0:N1}" -f ([float]$s.Width + 0.5) } }
                    't' { if([float]$s.Trail -gt 2.0) { $s.Trail = "{0:N1}" -f ([float]$s.Trail - 0.5) } }
                    'T' { if([float]$s.Trail -lt 20.0) { $s.Trail = "{0:N1}" -f ([float]$s.Trail + 0.5) } }
                    # Navigation
                    'n' { $currentStep = 3 }
                    'N' { $currentStep = 3 }
                    'p' { $currentStep = 1 }
                    'P' { $currentStep = 1 }
                    'c' { return "cancel" }
                    'C' { return "cancel" }
                }
            }
            3 {
                Show-RedPillStep3-Layers
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $ch = $key.Character

                switch ($ch) {
                    # Layer toggles
                    '1' { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"} }
                    '2' { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"} }
                    '3' { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"} }
                    # Navigation
                    'n' { $currentStep = 4 }
                    'N' { $currentStep = 4 }
                    'p' { $currentStep = 2 }
                    'P' { $currentStep = 2 }
                    'c' { return "cancel" }
                    'C' { return "cancel" }
                }
            }
            4 {
                Show-RedPillStep4-Transparency
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $ch = $key.Character

                switch -CaseSensitive ($ch) {
                    # Transparency toggle
                    'x' { $script:transparencyEnabled = -not $script:transparencyEnabled }
                    'X' { $script:transparencyEnabled = -not $script:transparencyEnabled }
                    # Opacity adjust
                    'o' { if ($script:transparencyEnabled -and $script:opacityValue -gt 0) { $script:opacityValue = [Math]::Max(0, $script:opacityValue - 10) } }
                    'O' { if ($script:transparencyEnabled -and $script:opacityValue -lt 100) { $script:opacityValue = [Math]::Min(100, $script:opacityValue + 10) } }
                    # Navigation
                    'n' { $currentStep = 5 }
                    'N' { $currentStep = 5 }
                    'p' { $currentStep = 3 }
                    'P' { $currentStep = 3 }
                    'c' { return "cancel" }
                    'C' { return "cancel" }
                }
            }
            5 {
                Show-RedPillStep5-Layout
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                if ($key.VirtualKeyCode -eq 13) {  # Enter
                    return "launch"
                }

                $ch = $key.Character
                switch -CaseSensitive ($ch) {
                    # Window count adjust
                    'w' { if ($script:windowCount -gt 1) { $script:windowCount-- } }
                    'W' { if ($script:windowCount -lt 8) { $script:windowCount++ } }
                    # Gap size adjust
                    'g' { if ($script:gapSize -gt 0) { $script:gapSize = [Math]::Max(0, $script:gapSize - 25) } }
                    'G' { if ($script:gapSize -lt 300) { $script:gapSize = [Math]::Min(300, $script:gapSize + 25) } }
                    # Quick presets
                    '1' { $script:windowCount = 2 }
                    '2' { $script:windowCount = 4 }
                    '3' { $script:windowCount = 6 }
                    '4' { $script:windowCount = 8 }
                    # Reset to defaults
                    '0' {
                        $s.R = $defaults.R; $s.G = $defaults.G; $s.B = $defaults.B
                        $s.Speed = $defaults.Speed; $s.Glow = $defaults.Glow
                        $s.Scale = $defaults.Scale; $s.Width = $defaults.Width
                        $s.Trail = $defaults.Trail; $s.Dens = $defaults.Dens
                        $s.L1 = $defaults.L1; $s.L2 = $defaults.L2; $s.L3 = $defaults.L3
                        $script:currentPreset = "Classic Green"
                        $script:transparencyEnabled = $false
                        $script:opacityValue = 100
                        $script:windowCount = 4
                        $script:gapSize = 150
                    }
                    # Navigation
                    'p' { $currentStep = 4 }
                    'P' { $currentStep = 4 }
                    'c' { return "cancel" }
                    'C' { return "cancel" }
                }
            }
        }
    }
}

# --- MAIN STARTUP FLOW ---

# Handle command-line parameters
if ($InstantLaunch) {
    # bluepill - Load saved config and launch immediately, no prompts
    $loadedConfig = Load-MatrixConfig
    if ($loadedConfig) {
        $s = $defaults.Clone()
        $s = Apply-ConfigToSettings -Config $loadedConfig -Settings $s
    } else {
        $s = $defaults.Clone()
        $script:windowCount = 4
    }
    Save-Shader -SaveConfig:$false
    if ($script:transparencyEnabled) {
        Update-TerminalOpacity -Opacity $script:opacityValue
    } else {
        Update-TerminalOpacity -Opacity 100
    }
    Launch-MatrixWindows -WindowCount $script:windowCount
    [System.Console]::CursorVisible = $true
    return
}

if ($SkipStartup) {
    # redpill - Skip to TUI control loop
    # Load config first so we have settings
    $loadedConfig = Load-MatrixConfig
    if ($loadedConfig) {
        $s = $defaults.Clone()
        $s = Apply-ConfigToSettings -Config $loadedConfig -Settings $s
    }
    # Fall through to control loop below
} else {
    # Normal startup - Show the wake up banner and menu
    Show-WakeUpBanner
    $startupChoice = Run-StartupMenu

    switch ($startupChoice) {
    "quit" {
        [System.Console]::CursorVisible = $true
        return
    }
    "knock" {
        # Load saved config and launch immediately (US-011)
        $loadedConfig = Load-MatrixConfig
        if ($loadedConfig) {
            $s = $defaults.Clone()
            $s = Apply-ConfigToSettings -Config $loadedConfig -Settings $s
        } else {
            # No saved config - use defaults
            $s = $defaults.Clone()
            $script:windowCount = 4
        }

        # Regenerate shader with loaded settings
        Save-Shader -SaveConfig:$false

        # Apply transparency settings
        if ($script:transparencyEnabled) {
            Update-TerminalOpacity -Opacity $script:opacityValue
        } else {
            Update-TerminalOpacity -Opacity 100
        }

        # Launch windows immediately and exit
        Launch-MatrixWindows -WindowCount $script:windowCount
        [System.Console]::CursorVisible = $true
        return
    }
    "blue" {
        # Blue Pill quick flow (US-012)
        $bluePillResult = Run-BluePillFlow

        switch ($bluePillResult) {
            "back" {
                # User went back - restart main menu
                $startupChoice = Run-StartupMenu
                # Re-process (simplified - in production would loop)
            }
            "quit" {
                [System.Console]::CursorVisible = $true
                return
            }
            "launch" {
                # Save shader and config, apply transparency, launch
                Save-Shader
                if ($script:transparencyEnabled) {
                    Update-TerminalOpacity -Opacity $script:opacityValue
                } else {
                    Update-TerminalOpacity -Opacity 100
                }
                Launch-MatrixWindows -WindowCount $script:windowCount
                [System.Console]::CursorVisible = $true
                return
            }
            "red" {
                # Fall through to Red Pill / main control loop
            }
        }
    }
    "red" {
        # Red Pill wizard (US-014)
        $redPillResult = Run-RedPillWizard

        switch ($redPillResult) {
            "cancel" {
                # User cancelled - go back to main menu
                $startupChoice = Run-StartupMenu
                # Would need to re-process, but for now fall through to main loop
            }
            "launch" {
                # Save shader and config, apply transparency, launch
                Save-Shader
                if ($script:transparencyEnabled) {
                    Update-TerminalOpacity -Opacity $script:opacityValue
                } else {
                    Update-TerminalOpacity -Opacity 100
                }
                Launch-MatrixWindows -WindowCount $script:windowCount
                [System.Console]::CursorVisible = $true
                return
            }
        }
    }
}
}  # End of else block for normal startup

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
        $vk = $key.VirtualKeyCode

        # If help is shown, any key dismisses it
        if ($showHelp) {
            $showHelp = $false
            continue
        }

        # Arrow key navigation (US-017)
        # VirtualKeyCode: Up=38, Down=40, Left=37, Right=39
        if ($vk -eq 38) {  # Up arrow
            # Move to previous item, or previous section if at first item
            if ($script:currentItem -gt 0) {
                $script:currentItem--
            } else {
                # Move to previous section
                if ($script:currentSection -gt 0) {
                    $script:currentSection--
                    # Set to last item in new section
                    switch ($script:currentSection) {
                        0 { $script:currentItem = 4 }  # Last parameter (Dens)
                        1 { $script:currentItem = 2 }  # Last layer (NEAR)
                    }
                }
            }
            continue
        }
        if ($vk -eq 40) {  # Down arrow
            # Get max items for current section
            $maxItems = switch ($script:currentSection) {
                0 { 4 }  # Parameters: 0-4 (5 items)
                1 { 2 }  # Layers: 0-2 (3 items)
                2 { 1 }  # Transparency: 0-1 (2 items)
            }

            if ($script:currentItem -lt $maxItems) {
                $script:currentItem++
            } else {
                # Move to next section
                if ($script:currentSection -lt 2) {
                    $script:currentSection++
                    $script:currentItem = 0
                }
            }
            continue
        }

        # Left/Right arrow value adjustment (US-018)
        if ($vk -eq 37 -or $vk -eq 39) {  # Left=37, Right=39
            $direction = if ($vk -eq 39) { 1 } else { -1 }  # Right = increase, Left = decrease

            switch ($script:currentSection) {
                0 {  # Parameters section
                    switch ($script:currentItem) {
                        0 {  # Speed
                            $newVal = [float]$s.Speed + ($direction * 0.1)
                            if ($newVal -ge 0.1 -and $newVal -le 5.0) {
                                $s.Speed = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        1 {  # Glow
                            $newVal = [float]$s.Glow + ($direction * 0.2)
                            if ($newVal -ge 0.2 -and $newVal -le 10.0) {
                                $s.Glow = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        2 {  # Width
                            $newVal = [float]$s.Width + ($direction * 0.5)
                            if ($newVal -ge 4.0 -and $newVal -le 20.0) {
                                $s.Width = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        3 {  # Trail
                            $newVal = [float]$s.Trail + ($direction * 0.5)
                            if ($newVal -ge 2.0 -and $newVal -le 20.0) {
                                $s.Trail = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        4 {  # Dens
                            $newVal = [float]$s.Dens + ($direction * 0.1)
                            if ($newVal -ge 0.1 -and $newVal -le 1.0) {
                                $s.Dens = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                    }
                }
                1 {  # Layers section - toggle on any arrow
                    switch ($script:currentItem) {
                        0 { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
                        1 { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
                        2 { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
                    }
                }
                2 {  # Transparency section
                    switch ($script:currentItem) {
                        0 {  # Toggle
                            $script:transparencyEnabled = -not $script:transparencyEnabled
                            if ($script:transparencyEnabled) {
                                Update-TerminalOpacity -Opacity $script:opacityValue
                            } else {
                                Update-TerminalOpacity -Opacity 100
                            }
                            Save-Shader
                        }
                        1 {  # Opacity
                            if ($script:transparencyEnabled) {
                                $newVal = $script:opacityValue + ($direction * 10)
                                if ($newVal -ge 0 -and $newVal -le 100) {
                                    $script:opacityValue = $newVal
                                    Update-TerminalOpacity -Opacity $script:opacityValue
                                    Save-Shader
                                }
                            }
                        }
                    }
                }
            }
            continue
        }

        # Plus/Minus keys as alternative adjustment (US-019)
        if ($ch -eq '+' -or $ch -eq '=' -or $ch -eq '-' -or $ch -eq '_') {
            # + or = (unshifted plus) increases, - or _ (unshifted minus) decreases
            $direction = if ($ch -eq '+' -or $ch -eq '=') { 1 } else { -1 }

            switch ($script:currentSection) {
                0 {  # Parameters section
                    switch ($script:currentItem) {
                        0 {  # Speed
                            $newVal = [float]$s.Speed + ($direction * 0.1)
                            if ($newVal -ge 0.1 -and $newVal -le 5.0) {
                                $s.Speed = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        1 {  # Glow
                            $newVal = [float]$s.Glow + ($direction * 0.2)
                            if ($newVal -ge 0.2 -and $newVal -le 10.0) {
                                $s.Glow = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        2 {  # Width
                            $newVal = [float]$s.Width + ($direction * 0.5)
                            if ($newVal -ge 4.0 -and $newVal -le 20.0) {
                                $s.Width = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        3 {  # Trail
                            $newVal = [float]$s.Trail + ($direction * 0.5)
                            if ($newVal -ge 2.0 -and $newVal -le 20.0) {
                                $s.Trail = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                        4 {  # Dens
                            $newVal = [float]$s.Dens + ($direction * 0.1)
                            if ($newVal -ge 0.1 -and $newVal -le 1.0) {
                                $s.Dens = "{0:N1}" -f $newVal
                                Save-Shader
                            }
                        }
                    }
                }
                1 {  # Layers section - toggle on +/-
                    switch ($script:currentItem) {
                        0 { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
                        1 { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
                        2 { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
                    }
                }
                2 {  # Transparency section
                    switch ($script:currentItem) {
                        0 {  # Toggle
                            $script:transparencyEnabled = -not $script:transparencyEnabled
                            if ($script:transparencyEnabled) {
                                Update-TerminalOpacity -Opacity $script:opacityValue
                            } else {
                                Update-TerminalOpacity -Opacity 100
                            }
                            Save-Shader
                        }
                        1 {  # Opacity
                            if ($script:transparencyEnabled) {
                                $newVal = $script:opacityValue + ($direction * 10)
                                if ($newVal -ge 0 -and $newVal -le 100) {
                                    $script:opacityValue = $newVal
                                    Update-TerminalOpacity -Opacity $script:opacityValue
                                    Save-Shader
                                }
                            }
                        }
                    }
                }
            }
            continue
        }

        switch -CaseSensitive ($ch) {
            # Layer toggles
            '7' { $s.L1 = if($s.L1 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
            '8' { $s.L2 = if($s.L2 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }
            '9' { $s.L3 = if($s.L3 -eq "1.0"){"0.0"}else{"1.0"}; Save-Shader }

            # Color presets
            '1' { $s.R=$presets['1'].R; $s.G=$presets['1'].G; $s.B=$presets['1'].B; $script:currentPreset=$presets['1'].Name; Save-Shader }
            '2' { $s.R=$presets['2'].R; $s.G=$presets['2'].G; $s.B=$presets['2'].B; $script:currentPreset=$presets['2'].Name; Save-Shader }
            '3' { $s.R=$presets['3'].R; $s.G=$presets['3'].G; $s.B=$presets['3'].B; $script:currentPreset=$presets['3'].Name; Save-Shader }
            '4' { $s.R=$presets['4'].R; $s.G=$presets['4'].G; $s.B=$presets['4'].B; $script:currentPreset=$presets['4'].Name; Save-Shader }
            '5' { $s.R=$presets['5'].R; $s.G=$presets['5'].G; $s.B=$presets['5'].B; $script:currentPreset=$presets['5'].Name; Save-Shader }
            '6' { $s.R=$presets['6'].R; $s.G=$presets['6'].G; $s.B=$presets['6'].B; $script:currentPreset=$presets['6'].Name; Save-Shader }

            # Reset to defaults
            '0' { $s = $defaults.Clone(); $script:currentPreset="Classic Green"; Save-Shader }

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

            # Transparency toggle (X key)
            'x' {
                $script:transparencyEnabled = -not $script:transparencyEnabled
                if ($script:transparencyEnabled) {
                    # Turn ON transparency - apply current opacity
                    Update-TerminalOpacity -Opacity $script:opacityValue
                } else {
                    # Turn OFF transparency - set to 100 (solid black)
                    Update-TerminalOpacity -Opacity 100
                }
                Save-Shader
            }
            'X' {
                $script:transparencyEnabled = -not $script:transparencyEnabled
                if ($script:transparencyEnabled) {
                    Update-TerminalOpacity -Opacity $script:opacityValue
                } else {
                    Update-TerminalOpacity -Opacity 100
                }
                Save-Shader
            }

            # Opacity adjust (O/o keys) - only works when transparency is ON
            'o' {
                if ($script:transparencyEnabled -and $script:opacityValue -gt 0) {
                    $script:opacityValue = [Math]::Max(0, $script:opacityValue - 10)
                    Update-TerminalOpacity -Opacity $script:opacityValue
                    Save-Shader
                }
            }
            'O' {
                if ($script:transparencyEnabled -and $script:opacityValue -lt 100) {
                    $script:opacityValue = [Math]::Min(100, $script:opacityValue + 10)
                    Update-TerminalOpacity -Opacity $script:opacityValue
                    Save-Shader
                }
            }

            # Launch Matrix windows (Enter key)
            ([char]13) {
                Save-Shader
                if ($script:transparencyEnabled) {
                    Update-TerminalOpacity -Opacity $script:opacityValue
                } else {
                    Update-TerminalOpacity -Opacity 100
                }
                Launch-MatrixWindows -WindowCount $script:windowCount
                return
            }

            # Quit
            'q' { return }
            'Q' { return }
        }
    }
} finally {
    [System.Console]::CursorVisible = $true
}

