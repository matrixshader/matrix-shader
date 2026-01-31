using System.Runtime.InteropServices;
using MatrixShader.Core.Native;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Manages registration and unregistration of global hotkeys.
/// Tracks registration success/failure for each hotkey.
/// </summary>
public sealed class HotkeyManager : IDisposable
{
    private readonly nint _hWnd;
    private readonly Dictionary<int, RegisteredHotkey> _registeredHotkeys = new();
    private readonly List<FailedHotkey> _failedHotkeys = new();
    private bool _disposed;
    private int _nextId = 1;

    /// <summary>
    /// Creates a new HotkeyManager for the specified window.
    /// </summary>
    /// <param name="hWnd">Window handle that will receive WM_HOTKEY messages.</param>
    public HotkeyManager(nint hWnd)
    {
        if (hWnd == nint.Zero)
            throw new ArgumentException("Invalid window handle", nameof(hWnd));

        _hWnd = hWnd;
    }

    /// <summary>
    /// Registers a global hotkey with the system.
    /// Always includes MOD_NOREPEAT to prevent auto-repeat spam.
    /// </summary>
    /// <param name="modifiers">Modifier keys (MOD_CONTROL, MOD_SHIFT, MOD_ALT, MOD_WIN).</param>
    /// <param name="vk">Virtual key code.</param>
    /// <param name="actionName">Name of the action this hotkey triggers (for display).</param>
    /// <returns>Hotkey ID if successful, or -1 if registration failed.</returns>
    public int RegisterHotkey(uint modifiers, uint vk, string actionName)
    {
        int id = _nextId++;

        // Always include MOD_NOREPEAT to prevent holding key from spamming
        uint effectiveModifiers = modifiers | HotkeyApi.MOD_NOREPEAT;

        bool success = HotkeyApi.RegisterHotKey(_hWnd, id, effectiveModifiers, vk);

        if (success)
        {
            _registeredHotkeys[id] = new RegisteredHotkey(id, modifiers, vk, actionName);
            return id;
        }
        else
        {
            int error = Marshal.GetLastWin32Error();
            string displayName = HotkeyApi.GetHotkeyDisplayName(modifiers, vk);

            _failedHotkeys.Add(new FailedHotkey(
                modifiers,
                vk,
                actionName,
                displayName,
                error,
                GetErrorMessage(error)
            ));

            return -1;
        }
    }

    /// <summary>
    /// Unregisters a specific hotkey by ID.
    /// </summary>
    /// <param name="id">Hotkey ID returned from RegisterHotkey.</param>
    /// <returns>True if unregistration succeeded.</returns>
    public bool UnregisterHotkey(int id)
    {
        if (!_registeredHotkeys.ContainsKey(id))
            return false;

        bool success = HotkeyApi.UnregisterHotKey(_hWnd, id);
        if (success)
        {
            _registeredHotkeys.Remove(id);
        }
        return success;
    }

    /// <summary>
    /// Unregisters all registered hotkeys.
    /// </summary>
    public void UnregisterAll()
    {
        foreach (var id in _registeredHotkeys.Keys.ToList())
        {
            HotkeyApi.UnregisterHotKey(_hWnd, id);
        }
        _registeredHotkeys.Clear();
    }

    /// <summary>
    /// Gets information about a registered hotkey by ID.
    /// </summary>
    /// <param name="id">Hotkey ID.</param>
    /// <returns>Hotkey info or null if not found.</returns>
    public RegisteredHotkey? GetHotkey(int id)
    {
        return _registeredHotkeys.TryGetValue(id, out var hotkey) ? hotkey : null;
    }

    /// <summary>
    /// Gets all currently registered hotkeys.
    /// </summary>
    public IReadOnlyList<RegisteredHotkey> GetRegisteredHotkeys()
    {
        return _registeredHotkeys.Values.ToList();
    }

    /// <summary>
    /// Gets all hotkeys that failed to register.
    /// </summary>
    public IReadOnlyList<FailedHotkey> GetFailedHotkeys()
    {
        return _failedHotkeys.ToList();
    }

    /// <summary>
    /// Clears the list of failed hotkeys.
    /// </summary>
    public void ClearFailedHotkeys()
    {
        _failedHotkeys.Clear();
    }

    /// <summary>
    /// Handles a WM_HOTKEY message and returns the action name.
    /// </summary>
    /// <param name="hotkeyId">Hotkey ID from WM_HOTKEY wParam.</param>
    /// <returns>Action name for the hotkey, or null if not found.</returns>
    public string? HandleHotkey(int hotkeyId)
    {
        return _registeredHotkeys.TryGetValue(hotkeyId, out var hotkey)
            ? hotkey.ActionName
            : null;
    }

    /// <summary>
    /// Gets the count of successfully registered hotkeys.
    /// </summary>
    public int RegisteredCount => _registeredHotkeys.Count;

    /// <summary>
    /// Gets the count of failed hotkey registrations.
    /// </summary>
    public int FailedCount => _failedHotkeys.Count;

    private static string GetErrorMessage(int error) => error switch
    {
        1409 => "Hotkey already registered by another application",
        1419 => "Hotkey was not registered",
        87 => "Invalid parameter",
        _ => $"Error code: {error}"
    };

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        UnregisterAll();
    }
}

/// <summary>
/// Information about a successfully registered hotkey.
/// </summary>
/// <param name="Id">Unique identifier for this registration.</param>
/// <param name="Modifiers">Modifier keys (without MOD_NOREPEAT).</param>
/// <param name="VirtualKey">Virtual key code.</param>
/// <param name="ActionName">Name of the action this hotkey triggers.</param>
public readonly record struct RegisteredHotkey(
    int Id,
    uint Modifiers,
    uint VirtualKey,
    string ActionName
)
{
    /// <summary>
    /// Gets the display name for this hotkey (e.g., "Ctrl+Shift+B").
    /// </summary>
    public string DisplayName => HotkeyApi.GetHotkeyDisplayName(Modifiers, VirtualKey);
}

/// <summary>
/// Information about a hotkey that failed to register.
/// </summary>
/// <param name="Modifiers">Requested modifier keys.</param>
/// <param name="VirtualKey">Requested virtual key code.</param>
/// <param name="ActionName">Name of the action this was meant to trigger.</param>
/// <param name="DisplayName">Human-readable hotkey name.</param>
/// <param name="ErrorCode">Win32 error code.</param>
/// <param name="ErrorMessage">Human-readable error message.</param>
public readonly record struct FailedHotkey(
    uint Modifiers,
    uint VirtualKey,
    string ActionName,
    string DisplayName,
    int ErrorCode,
    string ErrorMessage
);
