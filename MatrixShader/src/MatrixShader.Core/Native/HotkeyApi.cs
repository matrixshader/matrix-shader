using System.Runtime.InteropServices;

namespace MatrixShader.Core.Native;

/// <summary>
/// P/Invoke declarations for Windows global hotkey API.
/// Used for registering system-wide hotkeys and processing hotkey messages.
/// </summary>
public static partial class HotkeyApi
{
    #region Hotkey Registration

    /// <summary>
    /// Registers a system-wide hotkey.
    /// </summary>
    /// <param name="hWnd">Handle to the window that will receive WM_HOTKEY messages.</param>
    /// <param name="id">Unique identifier for the hotkey.</param>
    /// <param name="fsModifiers">Modifier keys (MOD_ALT, MOD_CONTROL, MOD_SHIFT, MOD_WIN).</param>
    /// <param name="vk">Virtual key code.</param>
    /// <returns>True if successful, false if hotkey is already registered or invalid.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool RegisterHotKey(nint hWnd, int id, uint fsModifiers, uint vk);

    /// <summary>
    /// Unregisters a previously registered system-wide hotkey.
    /// </summary>
    /// <param name="hWnd">Handle to the window that receives hotkey messages.</param>
    /// <param name="id">Identifier of the hotkey to unregister.</param>
    /// <returns>True if successful.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool UnregisterHotKey(nint hWnd, int id);

    #endregion

    #region Message Pump

    /// <summary>
    /// Retrieves a message from the calling thread's message queue.
    /// </summary>
    /// <param name="lpMsg">Pointer to an MSG structure that receives message information.</param>
    /// <param name="hWnd">Handle to the window whose messages are to be retrieved (0 for all).</param>
    /// <param name="wMsgFilterMin">The integer value of the lowest message value to be retrieved.</param>
    /// <param name="wMsgFilterMax">The integer value of the highest message value to be retrieved.</param>
    /// <returns>True if a message was retrieved, false if WM_QUIT was received.</returns>
    [LibraryImport("user32.dll", EntryPoint = "GetMessageW", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetMessageW(out MSG lpMsg, nint hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    /// <summary>
    /// Dispatches a message to a window procedure.
    /// </summary>
    /// <param name="lpMsg">Pointer to an MSG structure containing the message.</param>
    /// <returns>The return value specifies the value returned by the window procedure.</returns>
    [LibraryImport("user32.dll", EntryPoint = "DispatchMessageW")]
    public static partial nint DispatchMessageW(ref MSG lpMsg);

    /// <summary>
    /// Posts a WM_QUIT message to the thread's message queue.
    /// </summary>
    /// <param name="nExitCode">The application exit code.</param>
    [LibraryImport("user32.dll")]
    public static partial void PostQuitMessage(int nExitCode);

    #endregion

    #region Message-Only Window Creation

    /// <summary>
    /// Creates an extended window (used to create message-only windows).
    /// </summary>
    /// <param name="dwExStyle">Extended window styles.</param>
    /// <param name="lpClassName">Window class name.</param>
    /// <param name="lpWindowName">Window name.</param>
    /// <param name="dwStyle">Window styles.</param>
    /// <param name="X">Horizontal position.</param>
    /// <param name="Y">Vertical position.</param>
    /// <param name="nWidth">Width.</param>
    /// <param name="nHeight">Height.</param>
    /// <param name="hWndParent">Parent window handle (HWND_MESSAGE for message-only).</param>
    /// <param name="hMenu">Menu handle.</param>
    /// <param name="hInstance">Instance handle.</param>
    /// <param name="lpParam">Creation parameters.</param>
    /// <returns>Handle to the new window, or IntPtr.Zero on failure.</returns>
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint CreateWindowExW(
        uint dwExStyle,
        string lpClassName,
        string? lpWindowName,
        uint dwStyle,
        int X,
        int Y,
        int nWidth,
        int nHeight,
        nint hWndParent,
        nint hMenu,
        nint hInstance,
        nint lpParam);

    /// <summary>
    /// Default window procedure for processing messages.
    /// </summary>
    /// <param name="hWnd">Window handle.</param>
    /// <param name="Msg">Message.</param>
    /// <param name="wParam">Additional message information.</param>
    /// <param name="lParam">Additional message information.</param>
    /// <returns>Result of the message processing.</returns>
    [LibraryImport("user32.dll", EntryPoint = "DefWindowProcW")]
    public static partial nint DefWindowProcW(nint hWnd, uint Msg, nint wParam, nint lParam);

    /// <summary>
    /// Registers a window class for subsequent use.
    /// Uses DllImport because WNDCLASSEXW contains function pointer unsupported by LibraryImport source gen.
    /// </summary>
    [DllImport("user32.dll", EntryPoint = "RegisterClassExW", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern ushort RegisterClassExW(ref WNDCLASSEXW lpwcx);

    /// <summary>
    /// Destroys a window.
    /// </summary>
    /// <param name="hWnd">Handle to the window to be destroyed.</param>
    /// <returns>True if successful.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool DestroyWindow(nint hWnd);

    /// <summary>
    /// Retrieves the module handle for the current process.
    /// </summary>
    /// <param name="lpModuleName">Module name (null for current executable).</param>
    /// <returns>Module handle.</returns>
    [LibraryImport("kernel32.dll", EntryPoint = "GetModuleHandleW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint GetModuleHandleW(string? lpModuleName);

    #endregion

    #region Modifier Constants

    /// <summary>Alt key modifier.</summary>
    public const uint MOD_ALT = 0x0001;

    /// <summary>Ctrl key modifier.</summary>
    public const uint MOD_CONTROL = 0x0002;

    /// <summary>Shift key modifier.</summary>
    public const uint MOD_SHIFT = 0x0004;

    /// <summary>Win key modifier.</summary>
    public const uint MOD_WIN = 0x0008;

    /// <summary>Prevents repeat from holding key down.</summary>
    public const uint MOD_NOREPEAT = 0x4000;

    #endregion

    #region Message Constants

    /// <summary>Posted when a registered hotkey is pressed.</summary>
    public const uint WM_HOTKEY = 0x0312;

    /// <summary>Sent when the window is being destroyed.</summary>
    public const uint WM_DESTROY = 0x0002;

    /// <summary>Window creation message.</summary>
    public const uint WM_CREATE = 0x0001;

    /// <summary>Null message.</summary>
    public const uint WM_NULL = 0x0000;

    /// <summary>Sent when the display resolution changes.</summary>
    public const uint WM_DISPLAYCHANGE = 0x007E;

    #endregion

    #region Virtual Key Codes

    /// <summary>Left arrow key.</summary>
    public const uint VK_LEFT = 0x25;

    /// <summary>Up arrow key.</summary>
    public const uint VK_UP = 0x26;

    /// <summary>Right arrow key.</summary>
    public const uint VK_RIGHT = 0x27;

    /// <summary>Down arrow key.</summary>
    public const uint VK_DOWN = 0x28;

    /// <summary>1 key.</summary>
    public const uint VK_1 = 0x31;

    /// <summary>2 key.</summary>
    public const uint VK_2 = 0x32;

    /// <summary>3 key.</summary>
    public const uint VK_3 = 0x33;

    /// <summary>B key.</summary>
    public const uint VK_B = 0x42;

    /// <summary>H key.</summary>
    public const uint VK_H = 0x48;

    /// <summary>J key.</summary>
    public const uint VK_J = 0x4A;

    /// <summary>K key.</summary>
    public const uint VK_K = 0x4B;

    /// <summary>L key.</summary>
    public const uint VK_L = 0x4C;

    /// <summary>S key.</summary>
    public const uint VK_S = 0x53;

    /// <summary>F5 key.</summary>
    public const uint VK_F5 = 0x74;

    #endregion

    #region Window Constants

    /// <summary>Handle for message-only window parent.</summary>
    public static readonly nint HWND_MESSAGE = new(-3);

    /// <summary>CreateWindowEx: Uses default position.</summary>
    public const int CW_USEDEFAULT = unchecked((int)0x80000000);

    #endregion

    #region Structures

    /// <summary>
    /// Contains message information from a thread's message queue.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    public struct MSG
    {
        /// <summary>Window handle.</summary>
        public nint hwnd;

        /// <summary>Message identifier.</summary>
        public uint message;

        /// <summary>Additional message information.</summary>
        public nint wParam;

        /// <summary>Additional message information.</summary>
        public nint lParam;

        /// <summary>Time the message was posted.</summary>
        public uint time;

        /// <summary>Cursor position X when posted.</summary>
        public int pt_x;

        /// <summary>Cursor position Y when posted.</summary>
        public int pt_y;
    }

    /// <summary>
    /// Window procedure callback delegate.
    /// </summary>
    public delegate nint WNDPROC(nint hWnd, uint msg, nint wParam, nint lParam);

    /// <summary>
    /// Extended window class structure.
    /// </summary>
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WNDCLASSEXW
    {
        /// <summary>Size of this structure in bytes.</summary>
        public uint cbSize;

        /// <summary>Class style(s).</summary>
        public uint style;

        /// <summary>Pointer to the window procedure.</summary>
        public WNDPROC lpfnWndProc;

        /// <summary>Extra bytes to allocate following the window-class structure.</summary>
        public int cbClsExtra;

        /// <summary>Extra bytes to allocate following the window instance.</summary>
        public int cbWndExtra;

        /// <summary>Handle to the instance that contains the window procedure.</summary>
        public nint hInstance;

        /// <summary>Handle to the class icon.</summary>
        public nint hIcon;

        /// <summary>Handle to the class cursor.</summary>
        public nint hCursor;

        /// <summary>Handle to the class background brush.</summary>
        public nint hbrBackground;

        /// <summary>Resource name of the class menu.</summary>
        public string? lpszMenuName;

        /// <summary>Window class name.</summary>
        public string lpszClassName;

        /// <summary>Handle to the small icon.</summary>
        public nint hIconSm;

        /// <summary>
        /// Creates a WNDCLASSEXW with cbSize initialized.
        /// </summary>
        public static WNDCLASSEXW Create()
        {
            return new WNDCLASSEXW
            {
                cbSize = (uint)Marshal.SizeOf<WNDCLASSEXW>()
            };
        }
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Extracts the virtual key code from a WM_HOTKEY wParam.
    /// </summary>
    public static uint GetHotkeyVirtualKey(nint lParam) => (uint)((lParam >> 16) & 0xFFFF);

    /// <summary>
    /// Extracts the modifier flags from a WM_HOTKEY wParam.
    /// </summary>
    public static uint GetHotkeyModifiers(nint lParam) => (uint)(lParam & 0xFFFF);

    /// <summary>
    /// Gets a human-readable name for a virtual key code.
    /// </summary>
    public static string GetVirtualKeyName(uint vk) => vk switch
    {
        VK_LEFT => "Left",
        VK_RIGHT => "Right",
        VK_UP => "Up",
        VK_DOWN => "Down",
        VK_1 => "1",
        VK_2 => "2",
        VK_3 => "3",
        VK_B => "B",
        VK_J => "J",
        VK_K => "K",
        VK_L => "L",
        VK_S => "S",
        VK_F5 => "F5",
        _ => $"0x{vk:X2}"
    };

    /// <summary>
    /// Gets a human-readable name for modifier flags.
    /// </summary>
    public static string GetModifierName(uint modifiers)
    {
        var parts = new List<string>();
        if ((modifiers & MOD_CONTROL) != 0) parts.Add("Ctrl");
        if ((modifiers & MOD_SHIFT) != 0) parts.Add("Shift");
        if ((modifiers & MOD_ALT) != 0) parts.Add("Alt");
        if ((modifiers & MOD_WIN) != 0) parts.Add("Win");
        return string.Join("+", parts);
    }

    /// <summary>
    /// Creates a display name for a hotkey combination.
    /// </summary>
    public static string GetHotkeyDisplayName(uint modifiers, uint vk)
    {
        var modName = GetModifierName(modifiers);
        var keyName = GetVirtualKeyName(vk);
        return string.IsNullOrEmpty(modName) ? keyName : $"{modName}+{keyName}";
    }

    #endregion
}
