# BLUEPILL - Instant Matrix Launch
# Uses saved state from matrix_state.json, detects existing windows

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$stateFile = "$matrixDir\matrix_state.json"
$shadersDir = "$matrixDir\shaders"
$windowRegistryPath = "$matrixDir\window-registry.json"

# Check if state exists
if (-not (Test-Path $stateFile)) {
    Write-Host ""
    Write-Host " ERROR: No saved state found." -ForegroundColor Red
    Write-Host " Run 'wakeupneo' first to set up your Matrix." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Load state
try {
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    $slots = @($state.lastSlots)
    if ($slots.Count -eq 0) {
        Write-Host ""
        Write-Host " ERROR: No slots in saved state." -ForegroundColor Red
        Write-Host " Run 'wakeupneo' to configure." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host " ERROR: Could not read state: $_" -ForegroundColor Red
    Write-Host " Run 'wakeupneo' to reconfigure." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host " BLUEPILL - Instant Launch" -ForegroundColor Blue
Write-Host " =========================" -ForegroundColor DarkGray
Write-Host ""
Write-Host " Saved state: slots [$($slots -join ', ')]" -ForegroundColor DarkGray

# --- WINDOW POSITIONING (P/Invoke) ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;
using System.Diagnostics;

public class BluepillAPI {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_SHOWWINDOW = 0x0040;

    private static List<KeyValuePair<IntPtr, string>> foundWindows;

    public static List<KeyValuePair<IntPtr, string>> FindAllTerminalWindows() {
        foundWindows = new List<KeyValuePair<IntPtr, string>>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                uint processId;
                GetWindowThreadProcessId(hWnd, out processId);
                try {
                    var process = Process.GetProcessById((int)processId);
                    if (process.ProcessName.Equals("WindowsTerminal", StringComparison.OrdinalIgnoreCase)) {
                        var sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, 256);
                        var title = sb.ToString();
                        if (!string.IsNullOrEmpty(title)) {
                            foundWindows.Add(new KeyValuePair<IntPtr, string>(hWnd, title));
                        }
                    }
                } catch { }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }

    // Fast title-only search (no process lookup) for polling
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
}
"@ -ErrorAction SilentlyContinue

# Import WindowLayoutEngine for centralized positioning
. "$PSScriptRoot\WindowLayoutEngine.ps1"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Get-ScreenDimensions {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    return @{
        Width = $screen.Width
        Height = $screen.Height
        Left = $screen.X
        Top = $screen.Y
    }
}

function Get-ProfileFromUIAutomation($windowHandle) {
    try {
        $auto = [System.Windows.Automation.AutomationElement]
        $winElement = $auto::FromHandle($windowHandle)
        if (-not $winElement) { return $null }

        $allCondition = [System.Windows.Automation.Condition]::TrueCondition
        $children = $winElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allCondition)

        foreach ($child in $children) {
            $childName = $child.Current.Name
            if ($childName -match "^Matrix-(\d+)$") {
                return [int]$Matches[1]
            }
        }
    } catch { }
    return $null
}

function Wait-ForMatrixWindow([string]$profileName, [int]$timeoutMs = 5000) {
    # Poll for window with title containing profileName
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
        $matches = [BluepillAPI]::FindWindowsByPattern($profileName)
        if ($matches.Count -gt 0) {
            return $true
        }
    }
}

function Position-MatrixWindows {
    Start-Sleep -Milliseconds 500

    $windows = [BluepillAPI]::FindAllTerminalWindows()
    $windowHandles = @{}

    foreach ($win in $windows) {
        if ($win.Value -match "Redpill") { continue }
        $slot = Get-ProfileFromUIAutomation $win.Key
        if ($slot) {
            $windowHandles["Matrix-$slot"] = @{ Handle = $win.Key }
        }
    }

    if ($windowHandles.Count -eq 0) {
        Write-Host "   No Matrix windows detected" -ForegroundColor Yellow
        return
    }

    # Use WindowLayoutEngine for positioning
    $result = Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode 'Auto'

    Write-Host "   Positioned $($windowHandles.Count) windows by slot order" -ForegroundColor Green
}

# Find which slots are already open
Write-Host " Checking for existing windows..." -ForegroundColor Cyan
$existingWindows = [BluepillAPI]::FindAllTerminalWindows()
$openSlots = @{}

foreach ($win in $existingWindows) {
    if ($win.Value -match "Redpill") { continue }
    $slot = Get-ProfileFromUIAutomation $win.Key
    if ($slot) {
        $openSlots[$slot] = $true
        Write-Host "   Slot $slot already open" -ForegroundColor DarkGray
    }
}

# Launch only slots that aren't open
Write-Host " Launching windows..." -ForegroundColor Cyan

$launched = 0
foreach ($slot in $slots) {
    $pname = "Matrix-$slot"

    if ($openSlots.ContainsKey($slot)) {
        Write-Host "   $pname - already open, skipping" -ForegroundColor DarkGray
        continue
    }

    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
    Start-Process wt -ArgumentList "-p `"$pname`""

    if (Wait-ForMatrixWindow $pname) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
    $launched++
}

if ($launched -eq 0 -and $openSlots.Count -gt 0) {
    Write-Host "   All windows already open" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host " Positioning windows..." -ForegroundColor Cyan
Position-MatrixWindows

Write-Host ""
Write-Host " THE MATRIX HAS YOU." -ForegroundColor Green
Write-Host " Type 'redpill' to customize." -ForegroundColor DarkGray
Write-Host ""
