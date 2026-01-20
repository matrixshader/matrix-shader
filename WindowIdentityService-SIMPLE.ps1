# WindowIdentityService-SIMPLE.ps1
# SIMPLE WORKING VERSION - Title matching + launch tracking
# Replaces the broken 1150-line version

$script:LaunchRegistry = @{}

# Load Windows API for window enumeration
if (-not ([System.Management.Automation.PSTypeName]'SimpleWindowAPI').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class SimpleWindowAPI {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public static List<WindowInfo> FindAllTerminalWindows() {
        var windows = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            int length = GetWindowTextLength(hWnd);
            if (length == 0) return true;

            StringBuilder sb = new StringBuilder(length + 1);
            GetWindowText(hWnd, sb, sb.Capacity);
            string title = sb.ToString();

            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);

            // Check if this is a Windows Terminal window
            try {
                var proc = System.Diagnostics.Process.GetProcessById((int)pid);
                if (proc.ProcessName.Contains("WindowsTerminal") || proc.ProcessName == "wt") {
                    RECT rect;
                    GetWindowRect(hWnd, out rect);
                    windows.Add(new WindowInfo {
                        Handle = hWnd,
                        Title = title,
                        ProcessId = pid,
                        Left = rect.Left,
                        Top = rect.Top,
                        Width = rect.Right - rect.Left,
                        Height = rect.Bottom - rect.Top
                    });
                }
            } catch { }
            return true;
        }, IntPtr.Zero);
        return windows;
    }

    public class WindowInfo {
        public IntPtr Handle;
        public string Title;
        public uint ProcessId;
        public int Left, Top, Width, Height;
    }
}
"@
}

function Register-MatrixWindowLaunch {
    param(
        [string]$ProfileName,
        [IntPtr]$WindowHandle
    )
    $script:LaunchRegistry[$WindowHandle] = @{
        ProfileName = $ProfileName
        RegisteredAt = Get-Date
    }
    Write-Host "[Identity] Registered: $ProfileName -> Handle $WindowHandle" -ForegroundColor Cyan
}

function Get-AllMatrixWindows {
    $results = @()
    $windows = [SimpleWindowAPI]::FindAllTerminalWindows()

    foreach ($win in $windows) {
        $profileName = $null
        $source = "Unknown"

        # Layer 1: Launch Registry (windows we spawned)
        if ($script:LaunchRegistry.ContainsKey($win.Handle)) {
            $profileName = $script:LaunchRegistry[$win.Handle].ProfileName
            $source = "LaunchRegistry"
        }

        # Layer 2: Title Matching (SIMPLE AND WORKS)
        if (-not $profileName) {
            if ($win.Title -match "Matrix-(\d+)") {
                $profileName = "Matrix-$($Matches[1])"
                $source = "TitleMatch"
            }
            elseif ($win.Title -match "Redpill|RED\s*PILL") {
                $profileName = "Redpill"
                $source = "TitleMatch"
            }
        }

        if ($profileName) {
            $results += [PSCustomObject]@{
                Handle = $win.Handle
                ProfileName = $profileName
                Title = $win.Title
                ProcessId = $win.ProcessId
                IdentitySource = $source
                Left = $win.Left
                Top = $win.Top
                Width = $win.Width
                Height = $win.Height
            }
        }
    }

    return $results
}

function Get-AllTerminalWindows {
    # Returns ALL terminal windows, not just Matrix ones
    return [SimpleWindowAPI]::FindAllTerminalWindows()
}

Write-Host "[WindowIdentityService-SIMPLE] Loaded - Title matching + launch registry" -ForegroundColor Green
