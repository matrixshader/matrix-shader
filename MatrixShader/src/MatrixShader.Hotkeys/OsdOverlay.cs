using System.Runtime.InteropServices;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Win32 layered popup window for displaying brief OSD toast messages.
/// Shows opacity percentage on Ctrl+Shift+J/K presses, auto-dismisses with fade-out.
///
/// CRITICAL: Must be created on the same thread as HotkeyWindow (the message loop thread).
/// </summary>
public sealed class OsdOverlay : IDisposable
{
    private const string ClassName = "MatrixOsdWindow";
    private const int WindowWidth = 120;
    private const int WindowHeight = 50;
    private const int BottomMargin = 80;
    private const byte InitialAlpha = 220;
    private const byte AlphaDecrement = 22;
    private const uint DisplayTimerMs = 1200;
    private const uint FadeTimerMs = 30;

    // Timer IDs
    private static readonly nint DisplayTimerId = new(1);
    private static readonly nint FadeTimerId = new(2);

    private nint _hWnd;
    private nint _hInstance;
    private bool _disposed;
    private bool _classRegistered;
    private string _text = string.Empty;
    private byte _currentAlpha = InitialAlpha;

    // CRITICAL: Store delegate as field to prevent GC collection during window lifetime
    private readonly HotkeyApi.WNDPROC _wndProcDelegate;

    public OsdOverlay()
    {
        _wndProcDelegate = WndProc;
    }

    /// <summary>
    /// Creates the OSD popup window. Must be called on the message loop thread.
    /// </summary>
    public bool Create()
    {
        if (_hWnd != nint.Zero)
            return true;

        _hInstance = HotkeyApi.GetModuleHandleW(null);

        if (!_classRegistered)
        {
            var wc = HotkeyApi.WNDCLASSEXW.Create();
            wc.lpfnWndProc = _wndProcDelegate;
            wc.hInstance = _hInstance;
            wc.lpszClassName = ClassName;

            if (HotkeyApi.RegisterClassExW(ref wc) == 0)
            {
                int error = Marshal.GetLastWin32Error();
                // 1410 = ERROR_CLASS_ALREADY_EXISTS - this is OK
                if (error != 1410)
                    return false;
            }
            _classRegistered = true;
        }

        // Get primary monitor work area for positioning
        var (x, y) = CalculatePosition();

        // Create layered popup window
        uint exStyle = HotkeyApi.WS_EX_LAYERED | HotkeyApi.WS_EX_TOPMOST
                     | HotkeyApi.WS_EX_NOACTIVATE | HotkeyApi.WS_EX_TOOLWINDOW
                     | HotkeyApi.WS_EX_TRANSPARENT;

        _hWnd = HotkeyApi.CreateWindowExW(
            exStyle,
            ClassName,
            null,                       // No title
            HotkeyApi.WS_POPUP,        // Popup style - no border, no title bar
            x, y,
            WindowWidth, WindowHeight,
            nint.Zero,                  // No parent
            nint.Zero,                  // No menu
            _hInstance,
            nint.Zero);

        if (_hWnd == nint.Zero)
            return false;

        // Set initial layered window alpha
        HotkeyApi.SetLayeredWindowAttributes(_hWnd, 0, InitialAlpha, HotkeyApi.LWA_ALPHA);

        return true;
    }

    /// <summary>
    /// Shows the OSD toast with the given text. Auto-hides after display period + fade.
    /// </summary>
    public void ShowToast(string text)
    {
        if (_hWnd == nint.Zero)
            return;

        // Cancel any existing timers
        HotkeyApi.KillTimer(_hWnd, DisplayTimerId);
        HotkeyApi.KillTimer(_hWnd, FadeTimerId);

        // Update text and reset alpha
        _text = text;
        _currentAlpha = InitialAlpha;
        HotkeyApi.SetLayeredWindowAttributes(_hWnd, 0, InitialAlpha, HotkeyApi.LWA_ALPHA);

        // Repaint
        HotkeyApi.InvalidateRect(_hWnd, nint.Zero, true);

        // Recalculate position (monitor may have changed)
        var (x, y) = CalculatePosition();
        WindowsApi.SetWindowPos(
            _hWnd,
            WindowsApi.HWND_TOPMOST,
            x, y,
            WindowWidth, WindowHeight,
            WindowsApi.SWP_NOACTIVATE);

        // Show without activating
        WindowsApi.ShowWindow(_hWnd, HotkeyApi.SW_SHOWNOACTIVATE);

        // Start display timer -- after this, fade begins
        HotkeyApi.SetTimer(_hWnd, DisplayTimerId, DisplayTimerMs, nint.Zero);
    }

    /// <summary>
    /// Window procedure for the OSD popup.
    /// </summary>
    private nint WndProc(nint hWnd, uint msg, nint wParam, nint lParam)
    {
        switch (msg)
        {
            case HotkeyApi.WM_PAINT:
                OnPaint(hWnd);
                return nint.Zero;

            case HotkeyApi.WM_TIMER:
                OnTimer(hWnd, wParam);
                return nint.Zero;

            case HotkeyApi.WM_DESTROY:
                HotkeyApi.KillTimer(hWnd, DisplayTimerId);
                HotkeyApi.KillTimer(hWnd, FadeTimerId);
                return nint.Zero;

            default:
                return HotkeyApi.DefWindowProcW(hWnd, msg, wParam, lParam);
        }
    }

    /// <summary>
    /// Handles WM_PAINT: draws dark background with centered white bold text.
    /// </summary>
    private void OnPaint(nint hWnd)
    {
        var hdc = HotkeyApi.BeginPaint(hWnd, out var ps);
        if (hdc == nint.Zero)
            return;

        try
        {
            // Get client rect
            HotkeyApi.GetClientRect(hWnd, out var clientRect);

            // Fill background with dark color
            var hBrush = HotkeyApi.CreateSolidBrush(0x001A1A1A); // Dark gray (COLORREF: 0x00BBGGRR)
            HotkeyApi.FillRect(hdc, ref clientRect, hBrush);
            HotkeyApi.DeleteObject(hBrush);

            // Create bold font (~24px, Segoe UI for modern Windows look)
            var hFont = HotkeyApi.CreateFontW(
                -24,            // Height (negative = character height, not cell height)
                0,              // Width (0 = default)
                0, 0,           // Escapement, Orientation
                700,            // Weight (700 = bold)
                0, 0, 0,        // Italic, Underline, StrikeOut
                0,              // CharSet (ANSI_CHARSET)
                0, 0,           // OutPrecision, ClipPrecision
                5,              // Quality (CLEARTYPE_QUALITY)
                0,              // PitchAndFamily
                "Segoe UI");

            var oldFont = HotkeyApi.SelectObject(hdc, hFont);

            // Set transparent background and white text
            HotkeyApi.SetBkMode(hdc, HotkeyApi.TRANSPARENT);
            HotkeyApi.SetTextColor(hdc, 0x00FFFFFF); // White (COLORREF: 0x00BBGGRR)

            // Calculate centered position
            // Simple centering: estimate text width (~12px per char at this size)
            int textWidth = _text.Length * 12;
            int x = Math.Max(0, (clientRect.Right - clientRect.Left - textWidth) / 2);
            int y = Math.Max(0, (clientRect.Bottom - clientRect.Top - 24) / 2);

            HotkeyApi.ExtTextOutW(hdc, x, y, 0, nint.Zero, _text, (uint)_text.Length, nint.Zero);

            // Cleanup GDI objects
            HotkeyApi.SelectObject(hdc, oldFont);
            HotkeyApi.DeleteObject(hFont);
        }
        finally
        {
            HotkeyApi.EndPaint(hWnd, ref ps);
        }
    }

    /// <summary>
    /// Handles WM_TIMER: display period elapsed or fade tick.
    /// </summary>
    private void OnTimer(nint hWnd, nint timerId)
    {
        if (timerId == DisplayTimerId)
        {
            // Display period elapsed, begin fade-out
            HotkeyApi.KillTimer(hWnd, DisplayTimerId);
            HotkeyApi.SetTimer(hWnd, FadeTimerId, FadeTimerMs, nint.Zero);
        }
        else if (timerId == FadeTimerId)
        {
            // Fade tick: decrease alpha
            if (_currentAlpha <= AlphaDecrement)
            {
                // Fade complete: hide window and reset
                HotkeyApi.KillTimer(hWnd, FadeTimerId);
                _currentAlpha = InitialAlpha;
                WindowsApi.ShowWindow(hWnd, WindowsApi.SW_HIDE);
                // Reset alpha for next show
                HotkeyApi.SetLayeredWindowAttributes(hWnd, 0, InitialAlpha, HotkeyApi.LWA_ALPHA);
            }
            else
            {
                _currentAlpha -= AlphaDecrement;
                HotkeyApi.SetLayeredWindowAttributes(hWnd, 0, _currentAlpha, HotkeyApi.LWA_ALPHA);
            }
        }
    }

    /// <summary>
    /// Calculates the bottom-center position on the primary monitor.
    /// </summary>
    private static (int x, int y) CalculatePosition()
    {
        try
        {
            var monitors = WindowsApi.GetMonitors();
            if (monitors.Count > 0)
            {
                var primary = monitors[0]; // Primary is always first after sorting
                var workArea = primary.WorkArea;
                int x = workArea.Left + (workArea.Width - WindowWidth) / 2;
                int y = workArea.Top + workArea.Height - WindowHeight - BottomMargin;
                return (x, y);
            }
        }
        catch
        {
            // Fall through to defaults
        }

        // Fallback: assume 1920x1080
        return ((1920 - WindowWidth) / 2, 1080 - WindowHeight - BottomMargin);
    }

    /// <summary>
    /// Releases resources and destroys the window.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;

        if (_hWnd != nint.Zero)
        {
            HotkeyApi.KillTimer(_hWnd, DisplayTimerId);
            HotkeyApi.KillTimer(_hWnd, FadeTimerId);
            HotkeyApi.DestroyWindow(_hWnd);
            _hWnd = nint.Zero;
        }
    }
}
