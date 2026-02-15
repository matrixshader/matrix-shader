using MatrixShader.Core.Native;

namespace MatrixShader.Core.Models;

/// <summary>
/// Configuration for all global hotkey bindings.
/// Immutable record for thread-safety and JSON serialization.
/// </summary>
/// <param name="Bindings">Dictionary mapping actions to their key bindings.</param>
public record HotkeyConfig(
    Dictionary<HotkeyAction, HotkeyBinding> Bindings)
{
    /// <summary>
    /// Creates a new config with default Ctrl+Shift bindings.
    /// </summary>
    public static HotkeyConfig DefaultBindings() => new(new Dictionary<HotkeyAction, HotkeyBinding>
    {
        // Window swapping (arrows)
        [HotkeyAction.SwapLeft] = HotkeyBinding.CtrlShift(HotkeyAction.SwapLeft, HotkeyApi.VK_LEFT, "Left"),
        [HotkeyAction.SwapRight] = HotkeyBinding.CtrlShift(HotkeyAction.SwapRight, HotkeyApi.VK_RIGHT, "Right"),

        // Layout cycling
        [HotkeyAction.CycleLayout] = HotkeyBinding.CtrlShift(HotkeyAction.CycleLayout, HotkeyApi.VK_L, "L"),

        // Transparency/opacity
        [HotkeyAction.ToggleTransparency] = HotkeyBinding.CtrlShift(HotkeyAction.ToggleTransparency, HotkeyApi.VK_B, "B"),
        [HotkeyAction.OpacityDown] = HotkeyBinding.CtrlShift(HotkeyAction.OpacityDown, HotkeyApi.VK_J, "J"),
        [HotkeyAction.OpacityUp] = HotkeyBinding.CtrlShift(HotkeyAction.OpacityUp, HotkeyApi.VK_K, "K"),

        // CycleShader REMOVED - corrupts shader parameters (BUG-SHADER04, BUG-SHADER05)

        // Rain speed (up/down arrows)
        [HotkeyAction.SpeedUp] = HotkeyBinding.CtrlShift(HotkeyAction.SpeedUp, HotkeyApi.VK_UP, "Up"),
        [HotkeyAction.SpeedDown] = HotkeyBinding.CtrlShift(HotkeyAction.SpeedDown, HotkeyApi.VK_DOWN, "Down"),

        // Layer toggles (number keys)
        [HotkeyAction.ToggleFar] = HotkeyBinding.CtrlShift(HotkeyAction.ToggleFar, HotkeyApi.VK_1, "1"),
        [HotkeyAction.ToggleMid] = HotkeyBinding.CtrlShift(HotkeyAction.ToggleMid, HotkeyApi.VK_2, "2"),
        [HotkeyAction.ToggleNear] = HotkeyBinding.CtrlShift(HotkeyAction.ToggleNear, HotkeyApi.VK_3, "3"),

        // Help overlay
        [HotkeyAction.ShowHelp] = HotkeyBinding.CtrlShift(HotkeyAction.ShowHelp, HotkeyApi.VK_H, "H")
    });

    /// <summary>
    /// Gets a binding by action, or null if not found.
    /// </summary>
    public HotkeyBinding? GetBinding(HotkeyAction action) =>
        Bindings.TryGetValue(action, out var binding) ? binding : null;

    /// <summary>
    /// Gets all enabled bindings.
    /// </summary>
    public IEnumerable<HotkeyBinding> GetEnabledBindings() =>
        Bindings.Values.Where(b => b.Enabled);

    /// <summary>
    /// Creates a new config with the specified binding updated.
    /// </summary>
    public HotkeyConfig WithBinding(HotkeyAction action, HotkeyBinding binding)
    {
        var newBindings = new Dictionary<HotkeyAction, HotkeyBinding>(Bindings)
        {
            [action] = binding
        };
        return new HotkeyConfig(newBindings);
    }

    /// <summary>
    /// Creates a new config with the specified action enabled/disabled.
    /// </summary>
    public HotkeyConfig WithEnabled(HotkeyAction action, bool enabled)
    {
        if (!Bindings.TryGetValue(action, out var binding))
            return this;

        return WithBinding(action, binding with { Enabled = enabled });
    }
}
