using System.Runtime.InteropServices;
using MatrixShader.Core.Models;

namespace MatrixShader.Core.Native;

/// <summary>
/// P/Invoke declarations for Windows API functions.
/// Used for window management and positioning.
/// </summary>
public static partial class WindowsApi
{
    #region Window Functions

    /// <summary>
    /// Retrieves a handle to the foreground window.
    /// </summary>
    [LibraryImport("user32.dll")]
    public static partial nint GetForegroundWindow();

    /// <summary>
    /// Retrieves the window handle of the console.
    /// </summary>
    [LibraryImport("kernel32.dll")]
    public static partial nint GetConsoleWindow();

    /// <summary>
    /// Retrieves the text of the specified window's title bar.
    /// Internal implementation for AOT compatibility using char array.
    /// </summary>
    [LibraryImport("user32.dll", EntryPoint = "GetWindowTextW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int GetWindowTextInternal(nint hWnd, [Out] char[] lpString, int nMaxCount);

    /// <summary>
    /// Retrieves the length of the specified window's title bar text.
    /// </summary>
    [LibraryImport("user32.dll", EntryPoint = "GetWindowTextLengthW")]
    public static partial int GetWindowTextLength(nint hWnd);

    /// <summary>
    /// Retrieves the name of the class to which the specified window belongs.
    /// Internal implementation for AOT compatibility using char array.
    /// </summary>
    [LibraryImport("user32.dll", EntryPoint = "GetClassNameW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int GetClassNameInternal(nint hWnd, [Out] char[] lpClassName, int nMaxCount);

    /// <summary>
    /// Retrieves the identifier of the thread that created the specified window
    /// and the identifier of the process that created the window.
    /// </summary>
    [LibraryImport("user32.dll")]
    public static partial uint GetWindowThreadProcessId(nint hWnd, out uint lpdwProcessId);

    /// <summary>
    /// Determines whether the specified window is visible.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsWindowVisible(nint hWnd);

    /// <summary>
    /// Determines whether the specified window is minimized.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsIconic(nint hWnd);

    /// <summary>
    /// Determines whether the specified window is maximized (fullscreen).
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsZoomed(nint hWnd);

    /// <summary>
    /// Determines whether the specified window handle identifies an existing window.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsWindow(nint hWnd);

    /// <summary>
    /// Retrieves the ancestor of the specified window.
    /// </summary>
    [LibraryImport("user32.dll")]
    public static partial nint GetAncestor(nint hwnd, uint gaFlags);

    #endregion

    #region Window Positioning

    /// <summary>
    /// Changes the size, position, and Z order of a window.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetWindowPos(
        nint hWnd,
        nint hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags);

    /// <summary>
    /// Retrieves the dimensions of the bounding rectangle of the specified window.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetWindowRect(nint hWnd, out RECT lpRect);

    /// <summary>
    /// Shows/hides a window.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool ShowWindow(nint hWnd, int nCmdShow);

    /// <summary>
    /// Brings the thread that created the window to the foreground.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetForegroundWindow(nint hWnd);

    /// <summary>
    /// Retrieves system metrics or system configuration settings.
    /// </summary>
    [LibraryImport("user32.dll")]
    public static partial int GetSystemMetrics(int nIndex);

    // GetAncestor flags
    public const uint GA_PARENT = 1;
    public const uint GA_ROOT = 2;
    public const uint GA_ROOTOWNER = 3;

    // GetSystemMetrics indices
    public const int SM_CXSCREEN = 0;
    public const int SM_CYSCREEN = 1;

    // SetWindowPos flags
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;

    /// <summary>
    /// Synthesizes a keystroke (key down or up event).
    /// </summary>
    [LibraryImport("user32.dll")]
    public static partial void keybd_event(byte bVk, byte bScan, uint dwFlags, nuint dwExtraInfo);

    public const byte VK_F11 = 0x7A;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    // ShowWindow commands
    public const int SW_HIDE = 0;
    public const int SW_SHOWNORMAL = 1;
    public const int SW_SHOWMINIMIZED = 2;
    public const int SW_SHOWMAXIMIZED = 3;
    public const int SW_RESTORE = 9;

    // Window insertion handles
    public static readonly nint HWND_TOP = nint.Zero;
    public static readonly nint HWND_BOTTOM = new(1);
    public static readonly nint HWND_TOPMOST = new(-1);
    public static readonly nint HWND_NOTOPMOST = new(-2);

    #endregion

    #region Window Enumeration

    /// <summary>
    /// Enumerates all top-level windows on the screen.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool EnumWindows(EnumWindowsProc lpEnumFunc, nint lParam);

    /// <summary>
    /// Callback function for EnumWindows.
    /// </summary>
    public delegate bool EnumWindowsProc(nint hWnd, nint lParam);

    #endregion

    #region Monitor Functions

    /// <summary>
    /// Enumerates display monitors.
    /// </summary>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool EnumDisplayMonitors(
        nint hdc,
        nint lprcClip,
        MonitorEnumProc lpfnEnum,
        nint dwData);

    /// <summary>
    /// Callback function for EnumDisplayMonitors.
    /// </summary>
    public delegate bool MonitorEnumProc(nint hMonitor, nint hdcMonitor, ref RECT lprcMonitor, nint dwData);

    /// <summary>
    /// Retrieves information about a display monitor.
    /// Uses DllImport because MONITORINFOEX contains fixed char array unsupported by LibraryImport.
    /// </summary>
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetMonitorInfo(nint hMonitor, ref MONITORINFOEX lpmi);

    /// <summary>
    /// Retrieves a handle to the display monitor nearest to the specified window.
    /// </summary>
    [LibraryImport("user32.dll")]
    public static partial nint MonitorFromWindow(nint hwnd, uint dwFlags);

    public const uint MONITOR_DEFAULTTONEAREST = 2;

    #endregion

    #region Console Functions

    [LibraryImport("kernel32.dll", SetLastError = true)]
    public static partial nint GetStdHandle(int nStdHandle);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetConsoleMode(nint hConsoleHandle, out uint lpMode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetConsoleMode(nint hConsoleHandle, uint dwMode);

    public const int STD_INPUT_HANDLE = -10;
    public const uint ENABLE_ECHO_INPUT = 0x0004;
    public const uint ENABLE_LINE_INPUT = 0x0002;
    public const uint ENABLE_PROCESSED_INPUT = 0x0001;
    public const uint ENABLE_WINDOW_INPUT = 0x0008;
    public const uint ENABLE_MOUSE_INPUT = 0x0010;
    public const uint ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200;

    /// <summary>
    /// Restores the console input mode to the default state expected by interactive shells.
    /// Call this after using Console.ReadKey which disables LINE_INPUT and ECHO_INPUT.
    /// </summary>
    public static void RestoreConsoleMode()
    {
        var hStdIn = GetStdHandle(STD_INPUT_HANDLE);
        if (hStdIn == nint.Zero) return;
        // Default console mode: echo, line input, processed input, VT input
        uint defaultMode = ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT | ENABLE_VIRTUAL_TERMINAL_INPUT;
        SetConsoleMode(hStdIn, defaultMode);
    }

    #endregion

    #region Process Functions

    /// <summary>
    /// Opens an existing local process object.
    /// </summary>
    [LibraryImport("kernel32.dll")]
    public static partial nint OpenProcess(uint dwDesiredAccess, [MarshalAs(UnmanagedType.Bool)] bool bInheritHandle, uint dwProcessId);

    /// <summary>
    /// Closes an open object handle.
    /// </summary>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool CloseHandle(nint hObject);

    public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

    #endregion

    #region DWM Functions

    /// <summary>
    /// Retrieves the current value of a specified Desktop Window Manager (DWM) attribute.
    /// Used with DWMWA_EXTENDED_FRAME_BOUNDS to get visible window bounds
    /// (excluding invisible resize borders on Windows 10/11).
    /// </summary>
    [LibraryImport("dwmapi.dll")]
    public static partial int DwmGetWindowAttribute(
        nint hwnd,
        int dwAttribute,
        out RECT pvAttribute,
        int cbAttribute);

    /// <summary>
    /// DWM attribute for extended frame bounds (visible window area).
    /// Returns the bounds of the window excluding invisible resize borders.
    /// </summary>
    public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;

    #endregion

    #region Structures

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;

        public readonly int Width => Right - Left;
        public readonly int Height => Bottom - Top;

        public readonly WindowRect ToWindowRect() =>
            new() { Left = Left, Top = Top, Width = Width, Height = Height };
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public unsafe struct MONITORINFOEX
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;

        public fixed char szDevice[32];

        public static MONITORINFOEX Create()
        {
            var mi = new MONITORINFOEX();
            mi.cbSize = sizeof(MONITORINFOEX);
            return mi;
        }

        public readonly unsafe string GetDeviceName()
        {
            fixed (char* p = szDevice)
            {
                return new string(p);
            }
        }
    }

    public const uint MONITORINFOF_PRIMARY = 1;

    #endregion

    #region Helper Methods

    /// <summary>
    /// Gets the window title as a string.
    /// </summary>
    public static string GetWindowTitle(nint hWnd)
    {
        int length = GetWindowTextLength(hWnd);
        if (length == 0) return string.Empty;

        var buffer = new char[length + 1];
        GetWindowTextInternal(hWnd, buffer, buffer.Length);
        return new string(buffer, 0, length);
    }

    /// <summary>
    /// Gets the window class name as a string.
    /// </summary>
    public static string GetWindowClassName(nint hWnd)
    {
        var buffer = new char[256];
        int length = GetClassNameInternal(hWnd, buffer, buffer.Length);
        if (length == 0) return string.Empty;
        return new string(buffer, 0, length);
    }

    /// <summary>
    /// Gets the process ID for a window.
    /// </summary>
    public static int GetWindowProcessId(nint hWnd)
    {
        GetWindowThreadProcessId(hWnd, out uint processId);
        return (int)processId;
    }

    /// <summary>
    /// Positions a window to the specified rectangle (window rect, not visible rect).
    /// Note: Does NOT compensate for invisible borders. Use PositionWindowExact() for
    /// pixel-perfect visible positioning that accounts for Windows 10/11 invisible borders.
    /// </summary>
    public static bool PositionWindow(nint hWnd, WindowRect rect)
    {
        return SetWindowPos(
            hWnd,
            HWND_TOP,
            rect.Left,
            rect.Top,
            rect.Width,
            rect.Height,
            SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }

    /// <summary>
    /// Gets the current position of a window.
    /// </summary>
    public static WindowRect? GetWindowPosition(nint hWnd)
    {
        if (GetWindowRect(hWnd, out RECT rect))
        {
            return rect.ToWindowRect();
        }
        return null;
    }

    /// <summary>
    /// Enumerates all visible top-level windows (excludes minimized).
    /// </summary>
    public static List<nint> GetVisibleWindows()
    {
        var windows = new List<nint>();
        EnumWindows((hWnd, _) =>
        {
            if (IsWindowVisible(hWnd) && !IsIconic(hWnd))
            {
                windows.Add(hWnd);
            }
            return true;
        }, nint.Zero);
        return windows;
    }

    /// <summary>
    /// Enumerates ALL visible top-level windows including minimized.
    /// Context decision: Include minimized windows for Matrix window tracking.
    /// </summary>
    public static List<nint> GetAllWindows()
    {
        var windows = new List<nint>();
        EnumWindows((hWnd, _) =>
        {
            // IsWindowVisible returns true for minimized windows
            if (IsWindowVisible(hWnd))
            {
                windows.Add(hWnd);
            }
            return true;
        }, nint.Zero);
        return windows;
    }

    /// <summary>
    /// Gets the visible bounds of a window, excluding invisible borders.
    /// Falls back to GetWindowRect if DWM is unavailable.
    /// </summary>
    public static WindowRect GetVisibleWindowBounds(nint hWnd)
    {
        if (DwmGetWindowAttribute(
            hWnd,
            DWMWA_EXTENDED_FRAME_BOUNDS,
            out RECT visibleBounds,
            Marshal.SizeOf<RECT>()) == 0)  // S_OK
        {
            return visibleBounds.ToWindowRect();
        }

        // Fallback for DWM-disabled scenarios (rare on Windows 10+)
        if (GetWindowRect(hWnd, out RECT rect))
        {
            return rect.ToWindowRect();
        }

        return WindowRect.Empty;
    }

    /// <summary>
    /// Calculates the invisible border margins for a window.
    /// Returns BorderMargins.Zero if window rect cannot be retrieved or DWM unavailable.
    /// </summary>
    public static BorderMargins GetBorderMargins(nint hWnd)
    {
        if (!GetWindowRect(hWnd, out RECT windowRect))
            return BorderMargins.Zero;

        if (DwmGetWindowAttribute(hWnd, DWMWA_EXTENDED_FRAME_BOUNDS,
            out RECT extendedRect, Marshal.SizeOf<RECT>()) != 0)
            return BorderMargins.Zero;

        return new BorderMargins
        {
            Left = extendedRect.Left - windowRect.Left,
            Top = extendedRect.Top - windowRect.Top,
            Right = windowRect.Right - extendedRect.Right,
            Bottom = windowRect.Bottom - extendedRect.Bottom
        };
    }

    /// <summary>
    /// Positions a window to exact visible pixel coordinates, compensating for invisible borders.
    /// Preserves z-order (doesn't bring to top) and doesn't activate the window.
    /// </summary>
    /// <param name="hWnd">Window handle</param>
    /// <param name="targetVisible">Target visible bounds (what user sees)</param>
    /// <returns>True if positioning succeeded</returns>
    public static bool PositionWindowExact(nint hWnd, WindowRect targetVisible)
    {
        // Get current invisible border margins
        var margins = GetBorderMargins(hWnd);

        // Expand target rect to account for invisible borders
        // The window rect needs to be larger than visible rect by the border amounts
        int windowLeft = targetVisible.Left - margins.Left;
        int windowTop = targetVisible.Top - margins.Top;
        int windowWidth = targetVisible.Width + margins.Left + margins.Right;
        int windowHeight = targetVisible.Height + margins.Top + margins.Bottom;

        return SetWindowPos(
            hWnd,
            nint.Zero,           // Don't change z-order
            windowLeft,
            windowTop,
            windowWidth,
            windowHeight,
            SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }

    /// <summary>
    /// Gets information about all connected monitors.
    /// Sorted: primary first, then left-to-right by working area position.
    /// Matches PowerShell Get-ScreenTopology behavior.
    /// </summary>
    public static List<MonitorInfo> GetMonitors()
    {
        var monitors = new List<MonitorInfo>();

        EnumDisplayMonitors(nint.Zero, nint.Zero, (nint hMonitor, nint hdcMonitor, ref RECT lprcMonitor, nint dwData) =>
        {
            var mi = MONITORINFOEX.Create();
            if (GetMonitorInfo(hMonitor, ref mi))
            {
                monitors.Add(new MonitorInfo
                {
                    Handle = hMonitor,
                    Index = 0,  // Will be re-indexed after sorting
                    Bounds = mi.rcMonitor.ToWindowRect(),
                    WorkArea = mi.rcWork.ToWindowRect(),
                    IsPrimary = (mi.dwFlags & MONITORINFOF_PRIMARY) != 0,
                    DeviceName = mi.GetDeviceName()
                });
            }
            return true;
        }, nint.Zero);

        // Sort: Primary first, then left-to-right (matches PowerShell)
        var sorted = monitors
            .OrderByDescending(m => m.IsPrimary)
            .ThenBy(m => m.WorkArea.Left)
            .ToList();

        // Re-index after sorting
        for (int i = 0; i < sorted.Count; i++)
        {
            sorted[i] = sorted[i] with { Index = i };
        }

        return sorted;
    }

    /// <summary>
    /// Validates that a window handle is valid AND visible.
    /// Context decision: Both IsWindow AND IsWindowVisible must pass for handle validation.
    /// </summary>
    public static bool IsHandleValid(nint hWnd)
    {
        if (hWnd == nint.Zero)
            return false;
        return IsWindow(hWnd) && IsWindowVisible(hWnd);
    }

    #endregion
}
