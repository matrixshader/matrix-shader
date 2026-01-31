using System.Runtime.InteropServices;
using MatrixShader.Core.Native;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Creates a message-only window to receive WM_HOTKEY messages.
/// Uses HWND_MESSAGE as parent to create an invisible, message-only window.
/// </summary>
/// <remarks>
/// CRITICAL: The WndProc delegate is stored as a field to prevent garbage collection.
/// Without this, the callback could be collected while the window is still active,
/// causing an access violation when Windows tries to call the procedure.
/// </remarks>
public sealed class HotkeyWindow : IDisposable
{
    private const string ClassName = "MatrixHotkeyWindow";
    private static readonly object _lock = new();
    private static bool _classRegistered;
    private static nint _hInstance;

    private nint _hWnd;
    private bool _disposed;
    private volatile bool _running;

    // CRITICAL: Store delegate as field to prevent GC collection during window lifetime
    private readonly HotkeyApi.WNDPROC _wndProcDelegate;

    /// <summary>
    /// Window handle for hotkey registration.
    /// </summary>
    public nint Handle => _hWnd;

    /// <summary>
    /// Indicates if the message loop is currently running.
    /// </summary>
    public bool IsRunning => _running;

    /// <summary>
    /// Called when a WM_HOTKEY message is received.
    /// Parameters: hotkey ID, modifiers, virtual key code.
    /// </summary>
    public event Action<int, uint, uint>? HotkeyPressed;

    /// <summary>
    /// Creates a new hotkey window.
    /// </summary>
    public HotkeyWindow()
    {
        // Store delegate as field to prevent GC
        _wndProcDelegate = WndProc;
    }

    /// <summary>
    /// Creates the message-only window. Must be called before RunMessageLoop.
    /// </summary>
    /// <returns>True if window was created successfully.</returns>
    public bool Create()
    {
        if (_hWnd != nint.Zero)
            return true;

        lock (_lock)
        {
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
        }

        // Create message-only window (HWND_MESSAGE as parent)
        _hWnd = HotkeyApi.CreateWindowExW(
            0,                          // dwExStyle
            ClassName,                  // lpClassName
            "Matrix Hotkeys",           // lpWindowName
            0,                          // dwStyle
            0, 0, 0, 0,                // x, y, width, height
            HotkeyApi.HWND_MESSAGE,    // hWndParent - message-only window
            nint.Zero,                  // hMenu
            _hInstance,                 // hInstance
            nint.Zero                   // lpParam
        );

        return _hWnd != nint.Zero;
    }

    /// <summary>
    /// Runs the message loop on the current thread.
    /// Blocks until Stop() is called from another thread.
    /// </summary>
    /// <remarks>
    /// IMPORTANT: This must be called on the same thread that created the window.
    /// Hotkey messages are delivered to the thread's message queue.
    /// </remarks>
    public void RunMessageLoop()
    {
        if (_hWnd == nint.Zero)
            throw new InvalidOperationException("Window not created. Call Create() first.");

        _running = true;

        while (_running)
        {
            // GetMessageW blocks until a message is available
            // Returns false when WM_QUIT is received
            if (!HotkeyApi.GetMessageW(out var msg, nint.Zero, 0, 0))
            {
                break;
            }

            // Dispatch message to window procedure
            HotkeyApi.DispatchMessageW(ref msg);
        }

        _running = false;
    }

    /// <summary>
    /// Stops the message loop from any thread.
    /// Posts WM_QUIT to the message queue.
    /// </summary>
    public void Stop()
    {
        _running = false;
        if (_hWnd != nint.Zero)
        {
            // Post WM_QUIT to break out of GetMessage loop
            HotkeyApi.PostQuitMessage(0);
        }
    }

    /// <summary>
    /// Window procedure that processes messages for this window.
    /// </summary>
    private nint WndProc(nint hWnd, uint msg, nint wParam, nint lParam)
    {
        switch (msg)
        {
            case HotkeyApi.WM_HOTKEY:
                // wParam = hotkey ID
                // lParam low-order = modifiers, high-order = virtual key
                int hotkeyId = (int)wParam;
                uint modifiers = HotkeyApi.GetHotkeyModifiers(lParam);
                uint vk = HotkeyApi.GetHotkeyVirtualKey(lParam);

                HotkeyPressed?.Invoke(hotkeyId, modifiers, vk);
                return nint.Zero;

            case HotkeyApi.WM_DESTROY:
                HotkeyApi.PostQuitMessage(0);
                return nint.Zero;

            default:
                return HotkeyApi.DefWindowProcW(hWnd, msg, wParam, lParam);
        }
    }

    /// <summary>
    /// Releases resources and destroys the window.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        Stop();

        if (_hWnd != nint.Zero)
        {
            HotkeyApi.DestroyWindow(_hWnd);
            _hWnd = nint.Zero;
        }
    }
}
