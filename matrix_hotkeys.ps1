# Matrix Global Hotkeys
# Runs in background and handles system-wide hotkeys for Matrix window management
# Hotkeys:
#   Win+Alt+Left/Right - Swap focused window with neighbor
#   Win+Alt+L - Cycle layout mode (Pillars ↔ Quads)
#   Win+Alt+B - Toggle background transparency
#   Win+Alt+J/K - Decrease/Increase opacity

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Import required modules
. "$PSScriptRoot\WindowIdentityService.ps1"
. "$PSScriptRoot\WindowLayoutEngine.ps1"

# --- Win32 API for Hotkeys ---
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class HotkeyManager : Form {
    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);

    // Modifier keys
    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const uint MOD_WIN = 0x0008;
    public const uint MOD_NOREPEAT = 0x4000;

    // Virtual key codes
    public const uint VK_LEFT = 0x25;
    public const uint VK_RIGHT = 0x27;
    public const uint VK_L = 0x4C;
    public const uint VK_B = 0x42;
    public const uint VK_J = 0x4A;
    public const uint VK_K = 0x4B;

    // Hotkey IDs
    public const int HOTKEY_SWAP_LEFT = 1;
    public const int HOTKEY_SWAP_RIGHT = 2;
    public const int HOTKEY_LAYOUT = 3;
    public const int HOTKEY_TRANSPARENCY = 4;
    public const int HOTKEY_OPACITY_DOWN = 5;
    public const int HOTKEY_OPACITY_UP = 6;

    // WM_HOTKEY message
    private const int WM_HOTKEY = 0x0312;

    public event Action<int> HotkeyPressed;

    public HotkeyManager() {
        this.FormBorderStyle = FormBorderStyle.None;
        this.ShowInTaskbar = false;
        this.WindowState = FormWindowState.Minimized;
        this.Visible = false;
    }

    public bool RegisterAllHotkeys() {
        uint mods = MOD_WIN | MOD_ALT | MOD_NOREPEAT;
        bool success = true;

        success &= RegisterHotKey(this.Handle, HOTKEY_SWAP_LEFT, mods, VK_LEFT);
        success &= RegisterHotKey(this.Handle, HOTKEY_SWAP_RIGHT, mods, VK_RIGHT);
        success &= RegisterHotKey(this.Handle, HOTKEY_LAYOUT, mods, VK_L);
        success &= RegisterHotKey(this.Handle, HOTKEY_TRANSPARENCY, mods, VK_B);
        success &= RegisterHotKey(this.Handle, HOTKEY_OPACITY_DOWN, mods, VK_J);
        success &= RegisterHotKey(this.Handle, HOTKEY_OPACITY_UP, mods, VK_K);

        return success;
    }

    public void UnregisterAllHotkeys() {
        UnregisterHotKey(this.Handle, HOTKEY_SWAP_LEFT);
        UnregisterHotKey(this.Handle, HOTKEY_SWAP_RIGHT);
        UnregisterHotKey(this.Handle, HOTKEY_LAYOUT);
        UnregisterHotKey(this.Handle, HOTKEY_TRANSPARENCY);
        UnregisterHotKey(this.Handle, HOTKEY_OPACITY_DOWN);
        UnregisterHotKey(this.Handle, HOTKEY_OPACITY_UP);
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            int id = m.WParam.ToInt32();
            if (HotkeyPressed != null) {
                HotkeyPressed(id);
            }
        }
        base.WndProc(ref m);
    }

    protected override void OnFormClosing(FormClosingEventArgs e) {
        UnregisterAllHotkeys();
        base.OnFormClosing(e);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

# --- Unified Logging ---
. "$PSScriptRoot\MatrixLogging.ps1"

# --- Hotkey Handlers ---

function Get-FocusedMatrixWindow {
    # Get the currently focused window and check if it's a Matrix window
    $fgHandle = [HotkeyManager]::GetForegroundWindow()

    # Check if it's a Windows Terminal window
    $classBuilder = New-Object System.Text.StringBuilder 256
    [HotkeyManager]::GetClassName($fgHandle, $classBuilder, 256) | Out-Null
    $className = $classBuilder.ToString()

    if ($className -ne "CASCADIA_HOSTING_WINDOW_CLASS") {
        return $null  # Not a Windows Terminal window
    }

    # Get all Matrix windows and find this one
    $windows = Get-AllMatrixWindows -IncludeRedpill:$false
    $match = $windows | Where-Object { $_.Handle -eq $fgHandle }

    return $match
}

function Invoke-SwapWindows {
    param([string]$Direction)  # "Left" or "Right"

    Write-MatrixLog "Swap $Direction requested" -Source HOTKEY

    $focused = Get-FocusedMatrixWindow
    if (-not $focused) {
        Write-MatrixLog "Focused window is not a Matrix window" -Source HOTKEY -Level WARN
        return
    }

    $windows = Get-AllMatrixWindows -IncludeRedpill:$false | Sort-Object { $_.Slot }
    $currentIndex = -1
    for ($i = 0; $i -lt $windows.Count; $i++) {
        if ($windows[$i].Handle -eq $focused.Handle) {
            $currentIndex = $i
            break
        }
    }

    if ($currentIndex -lt 0) {
        Write-MatrixLog "Could not find focused window in list" -Source HOTKEY -Level WARN
        return
    }

    # Determine swap target
    $targetIndex = if ($Direction -eq "Left") { $currentIndex - 1 } else { $currentIndex + 1 }

    # Wrap around
    if ($targetIndex -lt 0) { $targetIndex = $windows.Count - 1 }
    if ($targetIndex -ge $windows.Count) { $targetIndex = 0 }

    if ($targetIndex -eq $currentIndex) {
        Write-MatrixLog "Only one window, nothing to swap" -Source HOTKEY
        return
    }

    $targetWindow = $windows[$targetIndex]

    Write-MatrixLog "Swapping Slot $($focused.Slot) with Slot $($targetWindow.Slot)" -Source HOTKEY

    # Get current positions
    $rect1 = New-Object 'MatrixWindowAPI+RECT'
    $rect2 = New-Object 'MatrixWindowAPI+RECT'
    [MatrixWindowAPI]::GetWindowRect($focused.Handle, [ref]$rect1) | Out-Null
    [MatrixWindowAPI]::GetWindowRect($targetWindow.Handle, [ref]$rect2) | Out-Null

    # Swap positions
    [WindowLayoutAPI]::SetWindowPos(
        $focused.Handle, [IntPtr]::Zero,
        $rect2.Left, $rect2.Top,
        ($rect2.Right - $rect2.Left), ($rect2.Bottom - $rect2.Top),
        0x0040  # SWP_SHOWWINDOW
    ) | Out-Null

    [WindowLayoutAPI]::SetWindowPos(
        $targetWindow.Handle, [IntPtr]::Zero,
        $rect1.Left, $rect1.Top,
        ($rect1.Right - $rect1.Left), ($rect1.Bottom - $rect1.Top),
        0x0040  # SWP_SHOWWINDOW
    ) | Out-Null

    Write-MatrixLog "Swap complete" -Source HOTKEY
}

function Invoke-CycleLayout {
    Write-MatrixLog "Layout cycle requested" -Source HOTKEY

    $config = Get-MatrixLayoutConfig
    $newMode = if ($config.Mode -eq 'Pillars') { 'Quads' } else { 'Pillars' }
    $config.Mode = $newMode
    Set-MatrixLayoutConfig -Config $config

    # Get windows and apply layout preserving monitors
    $windows = Get-AllMatrixWindows -IncludeRedpill:$false
    if ($windows.Count -eq 0) {
        Write-MatrixLog "No Matrix windows to layout" -Source HOTKEY -Level WARN
        return
    }

    $windowHandles = @{}
    foreach ($w in $windows) {
        $windowHandles["Matrix-$($w.Slot)"] = @{ Handle = $w.Handle }
    }

    Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode $newMode -PreserveMonitors

    Write-MatrixLog "Layout changed to $newMode" -Source HOTKEY
}

function Invoke-ToggleTransparency {
    Write-MatrixLog "Transparency toggle requested" -Source HOTKEY

    $focused = Get-FocusedMatrixWindow
    if (-not $focused) {
        Write-MatrixLog "Focused window is not a Matrix window" -Source HOTKEY -Level WARN
        return
    }

    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    try {
        $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
        $settings = $content | ConvertFrom-Json -ErrorAction Stop

        # Find the Matrix-N profile for this slot
        $profileName = "Matrix-$($focused.Slot)"
        $profileIndex = -1
        for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
            if ($settings.profiles.list[$i].name -eq $profileName) {
                $profileIndex = $i
                break
            }
        }

        if ($profileIndex -lt 0) {
            Write-MatrixLog "Profile $profileName not found in settings" -Source HOTKEY -Level WARN
            return
        }

        # Toggle: if opacity exists and < 100, set to 100 (solid); otherwise set to 80 (transparent)
        $profile = $settings.profiles.list[$profileIndex]
        $currentOpacity = if ($profile.opacity) { $profile.opacity } else { 100 }

        if ($currentOpacity -lt 100) {
            # Currently transparent -> make solid
            $settings.profiles.list[$profileIndex].PSObject.Properties.Remove('opacity')
            Write-MatrixLog "Transparency OFF for $profileName" -Source HOTKEY
        } else {
            # Currently solid -> make transparent
            $settings.profiles.list[$profileIndex] | Add-Member -NotePropertyName 'opacity' -NotePropertyValue 80 -Force
            Write-MatrixLog "Transparency ON (80%) for $profileName" -Source HOTKEY
        }

        # US-001: Atomic write pattern
        $tempFile = [System.IO.Path]::GetTempFileName()
        $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding UTF8
        Move-Item -Path $tempFile -Destination $wtSettingsPath -Force
    } catch {
        Write-MatrixLog "Failed to toggle transparency: $_" -Source HOTKEY -Level ERROR
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-AdjustOpacity {
    param([string]$Direction)  # "Up" or "Down"

    Write-MatrixLog "Opacity $Direction requested" -Source HOTKEY

    $focused = Get-FocusedMatrixWindow
    if (-not $focused) {
        Write-MatrixLog "Focused window is not a Matrix window" -Source HOTKEY -Level WARN
        return
    }

    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    try {
        $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
        $settings = $content | ConvertFrom-Json -ErrorAction Stop

        # Find the Matrix-N profile for this slot
        $profileName = "Matrix-$($focused.Slot)"
        $profileIndex = -1
        for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
            if ($settings.profiles.list[$i].name -eq $profileName) {
                $profileIndex = $i
                break
            }
        }

        if ($profileIndex -lt 0) {
            Write-MatrixLog "Profile $profileName not found in settings" -Source HOTKEY -Level WARN
            return
        }

        # Get current opacity (default 100 if not set)
        $profile = $settings.profiles.list[$profileIndex]
        $currentOpacity = if ($profile.opacity) { [int]$profile.opacity } else { 100 }

        # Adjust by 5% steps
        $step = 5
        $newOpacity = if ($Direction -eq "Up") {
            [Math]::Min(100, $currentOpacity + $step)
        } else {
            [Math]::Max(10, $currentOpacity - $step)  # Min 10% to keep window visible
        }

        # Apply new opacity
        if ($newOpacity -ge 100) {
            # Fully opaque - remove opacity property
            $settings.profiles.list[$profileIndex].PSObject.Properties.Remove('opacity')
        } else {
            $settings.profiles.list[$profileIndex] | Add-Member -NotePropertyName 'opacity' -NotePropertyValue $newOpacity -Force
        }

        Write-MatrixLog "Opacity changed to $newOpacity% for $profileName" -Source HOTKEY

        # US-001: Atomic write pattern
        $tempFile = [System.IO.Path]::GetTempFileName()
        $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding UTF8
        Move-Item -Path $tempFile -Destination $wtSettingsPath -Force
    } catch {
        Write-MatrixLog "Failed to adjust opacity: $_" -Source HOTKEY -Level ERROR
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Main ---

Write-MatrixLog "Matrix Global Hotkeys starting..." -Source HOTKEY
Write-MatrixLog "Registering hotkeys:" -Source HOTKEY
Write-MatrixLog "  Win+Alt+Left/Right - Swap windows" -Source HOTKEY
Write-MatrixLog "  Win+Alt+L - Cycle layout" -Source HOTKEY
Write-MatrixLog "  Win+Alt+B - Toggle transparency" -Source HOTKEY
Write-MatrixLog "  Win+Alt+J/K - Opacity down/up" -Source HOTKEY

# Create hotkey manager
$manager = New-Object HotkeyManager

# Debounce tracking - prevent double-fires
$script:lastHotkeyTime = @{}
$script:debounceMs = 500  # Minimum milliseconds between same hotkey

# Register event handler
$manager.add_HotkeyPressed({
    param($id)

    # Debounce check
    $now = [DateTime]::Now
    if ($script:lastHotkeyTime.ContainsKey($id)) {
        $elapsed = ($now - $script:lastHotkeyTime[$id]).TotalMilliseconds
        if ($elapsed -lt $script:debounceMs) {
            Write-MatrixLog "Debounced hotkey $id (${elapsed}ms since last)" -Source HOTKEY -Level DEBUG
            return
        }
    }
    $script:lastHotkeyTime[$id] = $now

    switch ($id) {
        1 { Invoke-SwapWindows -Direction "Left" }
        2 { Invoke-SwapWindows -Direction "Right" }
        3 { Invoke-CycleLayout }
        4 { Invoke-ToggleTransparency }
        5 { Invoke-AdjustOpacity -Direction "Down" }
        6 { Invoke-AdjustOpacity -Direction "Up" }
    }
})

# Register hotkeys
if ($manager.RegisterAllHotkeys()) {
    Write-MatrixLog "All hotkeys registered successfully" -Source HOTKEY
} else {
    Write-MatrixLog "Some hotkeys failed to register - may be in use by another app" -Source HOTKEY -Level WARN
}

Write-MatrixLog "Hotkey manager running. Press Ctrl+C to exit." -Source HOTKEY

# Run the message loop
try {
    [System.Windows.Forms.Application]::Run($manager)
} finally {
    $manager.UnregisterAllHotkeys()
    Write-MatrixLog "Hotkeys unregistered, exiting" -Source HOTKEY
}
