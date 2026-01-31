namespace MatrixShader.Core.Models;

/// <summary>
/// Represents a single hotkey binding configuration.
/// Immutable record for thread-safety and JSON serialization.
/// </summary>
/// <param name="Action">The action this hotkey triggers.</param>
/// <param name="DisplayName">Human-readable description like "Ctrl+Shift+Left".</param>
/// <param name="Modifiers">Combined modifier flags (MOD_CONTROL | MOD_SHIFT, etc.).</param>
/// <param name="VirtualKey">Virtual key code (VK_LEFT, VK_1, etc.).</param>
/// <param name="Enabled">Whether this binding is currently active.</param>
public record HotkeyBinding(
    HotkeyAction Action,
    string DisplayName,
    uint Modifiers,
    uint VirtualKey,
    bool Enabled = true)
{
    /// <summary>
    /// Creates a binding with Ctrl+Shift modifier and the specified key.
    /// </summary>
    public static HotkeyBinding CtrlShift(HotkeyAction action, uint vk, string keyName) =>
        new(action, $"Ctrl+Shift+{keyName}",
            Native.HotkeyApi.MOD_CONTROL | Native.HotkeyApi.MOD_SHIFT | Native.HotkeyApi.MOD_NOREPEAT,
            vk);
}
