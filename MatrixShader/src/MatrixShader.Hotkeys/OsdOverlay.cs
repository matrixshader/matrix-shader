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
    private const int WindowWidth = 160;
    private const int WindowHeight = 60;
    private const int BottomMargin = 80;
    private const byte InitialAlpha = 230;
    private const byte AlphaDecrement = 23;
    private const uint DisplayTimerMs = 1200;
    private const uint FadeTimerMs = 30;

    // Transparent background via color key — text floats with no visible box
    private const uint TransparentKeyColor = 0x00010101; // Near-black key (COLORREF)
    // Text color: #2c6e49 → COLORREF 0x00496E2C (BBGGRR)
    private const uint TextColor = 0x00496E2C;

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

            var atom = HotkeyApi.RegisterClassExW(ref wc);
            if (atom == 0)
            {
                int error = Marshal.GetLastWin32Error();
                DiagnosticLogger.Warn("OSD", $"RegisterClassExW failed: error={error}");
                // 1410 = ERROR_CLASS_ALREADY_EXISTS - this is OK
                if (error != 1410)
                    return false;
            }
            _classRegistered = true;
        }

        // Get primary monitor work area for positioning
        var (x, y) = CalculatePosition();
        DiagnosticLogger.Debug("OSD", $"Create: position=({x},{y}), size={WindowWidth}x{WindowHeight}");

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
        {
            DiagnosticLogger.Warn("OSD", $"CreateWindowExW failed: error={Marshal.GetLastWin32Error()}");
            return false;
        }

        // Color key for transparent background + alpha for fade
        HotkeyApi.SetLayeredWindowAttributes(_hWnd, TransparentKeyColor, InitialAlpha,
            HotkeyApi.LWA_COLORKEY | HotkeyApi.LWA_ALPHA);

        DiagnosticLogger.Debug("OSD", $"OSD window created: hWnd=0x{_hWnd:X}");
        return true;
    }

    /// <summary>
    /// Shows the OSD toast with the given text. Auto-hides after display period + fade.
    /// </summary>
    public void ShowToast(string text)
    {
        DiagnosticLogger.Debug("OSD", $"ShowToast('{text}'): hWnd=0x{_hWnd:X}");
        if (_hWnd == nint.Zero)
            return;

        // Cancel any existing timers
        HotkeyApi.KillTimer(_hWnd, DisplayTimerId);
        HotkeyApi.KillTimer(_hWnd, FadeTimerId);

        // Update text and reset alpha
        _text = text;
        _currentAlpha = InitialAlpha;
        HotkeyApi.SetLayeredWindowAttributes(_hWnd, TransparentKeyColor, InitialAlpha,
            HotkeyApi.LWA_COLORKEY | HotkeyApi.LWA_ALPHA);

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
    /// Handles WM_PAINT: fills with color key (becomes transparent), draws floating green text.
    /// </summary>
    private void OnPaint(nint hWnd)
    {
        var hdc = HotkeyApi.BeginPaint(hWnd, out var ps);
        if (hdc == nint.Zero)
            return;

        try
        {
            HotkeyApi.GetClientRect(hWnd, out var clientRect);

            // Fill with color key — this area becomes fully transparent
            var hBrush = HotkeyApi.CreateSolidBrush(TransparentKeyColor);
            HotkeyApi.FillRect(hdc, ref clientRect, hBrush);
            HotkeyApi.DeleteObject(hBrush);

            // Nimbus Mono PS, 28px, bold
            var hFont = HotkeyApi.CreateFontW(
                -28,            // Height
                0,              // Width (default)
                0, 0,           // Escapement, Orientation
                700,            // Weight (bold)
                0, 0, 0,        // Italic, Underline, StrikeOut
                0,              // CharSet (ANSI_CHARSET)
                0, 0,           // OutPrecision, ClipPrecision
                5,              // Quality (CLEARTYPE_QUALITY)
                0,              // PitchAndFamily
                "Nimbus Mono PS");

            var oldFont = HotkeyApi.SelectObject(hdc, hFont);

            HotkeyApi.SetBkMode(hdc, HotkeyApi.TRANSPARENT);
            HotkeyApi.SetTextColor(hdc, TextColor); // #2c6e49 green

            // Center text
            int textWidth = _text.Length * 14;
            int x = Math.Max(0, (clientRect.Right - clientRect.Left - textWidth) / 2);
            int y = Math.Max(0, (clientRect.Bottom - clientRect.Top - 28) / 2);

            HotkeyApi.ExtTextOutW(hdc, x, y, 0, nint.Zero, _text, (uint)_text.Length, nint.Zero);

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
                HotkeyApi.SetLayeredWindowAttributes(hWnd, TransparentKeyColor, InitialAlpha,
                    HotkeyApi.LWA_COLORKEY | HotkeyApi.LWA_ALPHA);
            }
            else
            {
                _currentAlpha -= AlphaDecrement;
                HotkeyApi.SetLayeredWindowAttributes(hWnd, TransparentKeyColor, _currentAlpha,
                    HotkeyApi.LWA_COLORKEY | HotkeyApi.LWA_ALPHA);
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
