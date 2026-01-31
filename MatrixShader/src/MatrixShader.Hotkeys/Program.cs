namespace MatrixShader.Hotkeys;

/// <summary>
/// Matrix Hotkeys - Background global hotkey listener for Matrix Shader.
/// Runs as an invisible process, receives WM_HOTKEY messages via message-only window.
/// </summary>
public static class Program
{
    /// <summary>
    /// Entry point for the hotkey service.
    /// Will be implemented in Plan 04 to wire up all components.
    /// </summary>
    public static int Main(string[] args)
    {
        // Placeholder - will be implemented in Plan 04
        // Components to integrate:
        // - SingleInstance: Prevent duplicate processes
        // - HotkeyWindow: Message-only window for WM_HOTKEY
        // - HotkeyManager: Register/unregister hotkeys
        // - Configuration: Load hotkey bindings from config
        // - Action dispatch: Execute CLI commands on hotkey press
        return 0;
    }
}
