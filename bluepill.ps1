# BLUEPILL - Instant Matrix Launch
# No prompts - uses last saved settings from config.json

$configDir = "$env:USERPROFILE\.matrix-shader"
$configPath = "$configDir\config.json"
$shadersDir = "$env:USERPROFILE\Documents\Matrix\shaders"

# Check if config exists
if (-not (Test-Path $configPath)) {
    Write-Host ""
    Write-Host " ERROR: No saved configuration found." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' first to set up your Matrix." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Load config
try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Host ""
    Write-Host " ERROR: Could not read configuration." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' to reconfigure." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Count existing shader files to determine how many windows to launch
$shaderFiles = Get-ChildItem "$shadersDir\Matrix-*.hlsl" -ErrorAction SilentlyContinue
if (-not $shaderFiles -or $shaderFiles.Count -eq 0) {
    Write-Host ""
    Write-Host " ERROR: No shader files found." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' first to create shaders." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$numWindows = $shaderFiles.Count

Write-Host ""
Write-Host " BLUEPILL - Instant Launch" -ForegroundColor Blue
Write-Host " =========================" -ForegroundColor DarkGray
Write-Host ""
Write-Host " Launching $numWindows Matrix window(s)..." -ForegroundColor Cyan

# --- WINDOW POSITIONING (P/Invoke) ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WindowPositioning {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
}
"@

Add-Type -AssemblyName System.Windows.Forms

function Get-ScreenDimensions {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    return @{
        Width = $screen.Width
        Height = $screen.Height
        X = $screen.X
        Y = $screen.Y
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

    # Sort by handle value to get consistent ordering
    $handles = $handles | Sort-Object

    # Take only the windows we need
    $handles = $handles | Select-Object -Last $WindowCount

    # Position each window
    for ($i = 0; $i -lt $handles.Count; $i++) {
        $x = $screen.X + $gapSize + ($i * ($windowWidth + $gapSize))
        $y = $screen.Y

        [WindowPositioning]::SetWindowPos(
            $handles[$i],
            [IntPtr]::Zero,
            $x,
            $y,
            $windowWidth,
            $screen.Height,
            [WindowPositioning]::SWP_NOZORDER -bor [WindowPositioning]::SWP_NOACTIVATE
        ) | Out-Null
    }

    Write-Host "   Positioned $($handles.Count) windows" -ForegroundColor Green
}

# Launch windows
for ($i = 1; $i -le $numWindows; $i++) {
    $pname = "Matrix-$i"
    Write-Host "   Opening $pname..." -ForegroundColor DarkGray
    Start-Process wt -ArgumentList "-p `"$pname`""
    Start-Sleep -Milliseconds 1500
}

Write-Host ""
Write-Host " Positioning windows..." -ForegroundColor Cyan
Position-MatrixWindows $numWindows

Write-Host ""
Write-Host " THE MATRIX HAS YOU." -ForegroundColor Green
Write-Host " Type 'redpill' to customize." -ForegroundColor DarkGray
Write-Host ""
