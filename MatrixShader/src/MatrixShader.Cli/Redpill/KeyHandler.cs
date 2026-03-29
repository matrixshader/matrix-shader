// KeyHandler.cs - Keyboard input handling for Control Panel TUI
// Matches PowerShell matrix_control.ps1 key bindings exactly

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// All possible actions that can result from a key press.
/// </summary>
public enum KeyAction
{
    /// <summary>No action - unrecognized key.</summary>
    None,

    // Navigation
    /// <summary>Tab key - cycle through open windows.</summary>
    Tab,
    /// <summary>Escape key - quit the control panel.</summary>
    Quit,

    // Color presets (1-6)
    /// <summary>Key 1 - Green preset (0.0, 1.0, 0.3).</summary>
    PresetGreen,
    /// <summary>Key 2 - Blue preset (0.0, 0.6, 1.0).</summary>
    PresetBlue,
    /// <summary>Key 3 - Red preset (1.0, 0.1, 0.1).</summary>
    PresetRed,
    /// <summary>Key 4 - Purple preset (0.7, 0.0, 1.0).</summary>
    PresetPurple,
    /// <summary>Key 5 - Gold preset (1.0, 0.7, 0.0).</summary>
    PresetGold,
    /// <summary>Key 6 - Teal preset (0.0, 0.9, 0.9).</summary>
    PresetTeal,

    // RGB adjustments (Q/W, A/S, Z/X)
    /// <summary>Q key - decrease red by 0.05.</summary>
    RedDecrease,
    /// <summary>W key - increase red by 0.05.</summary>
    RedIncrease,
    /// <summary>A key - decrease green by 0.05.</summary>
    GreenDecrease,
    /// <summary>S key - increase green by 0.05.</summary>
    GreenIncrease,
    /// <summary>Z key - decrease blue by 0.05.</summary>
    BlueDecrease,
    /// <summary>X key - increase blue by 0.05.</summary>
    BlueIncrease,

    // Effects adjustments
    /// <summary>E key - decrease speed.</summary>
    SpeedDecrease,
    /// <summary>R key - increase speed.</summary>
    SpeedIncrease,
    /// <summary>D key - decrease glow.</summary>
    GlowDecrease,
    /// <summary>F key - increase glow.</summary>
    GlowIncrease,
    /// <summary>C key - decrease width.</summary>
    WidthDecrease,
    /// <summary>V key - increase width.</summary>
    WidthIncrease,
    /// <summary>T key - decrease trail.</summary>
    TrailDecrease,
    /// <summary>Y key - increase trail.</summary>
    TrailIncrease,
    /// <summary>G key - decrease density.</summary>
    DensityDecrease,
    /// <summary>H key - increase density.</summary>
    DensityIncrease,

    // Layer toggles (7/8/9)
    /// <summary>Key 7 - toggle layer 1 (far).</summary>
    Layer1Toggle,
    /// <summary>Key 8 - toggle layer 2 (mid).</summary>
    Layer2Toggle,
    /// <summary>Key 9 - toggle layer 3 (near).</summary>
    Layer3Toggle,

    // Window effects
    /// <summary>B key - toggle window transparency.</summary>
    TransparencyToggle,
    /// <summary>K key - decrease opacity (more transparent).</summary>
    OpacityDecrease,
    /// <summary>L key (lowercase) - increase opacity (less transparent).</summary>
    OpacityIncrease,

    // Launch controls
    /// <summary>Minus key - decrease launch count.</summary>
    LaunchDecrease,
    /// <summary>Plus/Equals key - increase launch count.</summary>
    LaunchIncrease,
    /// <summary>Enter key - launch windows.</summary>
    Launch,

    // Save/Reset
    /// <summary>P key (lowercase) - save current shader settings.</summary>
    Save,
    /// <summary>Key 0 - reset to defaults.</summary>
    Reset,

    // Shift+ combinations (detected before lowercase normalization)
    /// <summary>Shift+L - cycle layout mode (Pillars/Quads).</summary>
    LayoutCycle,
    /// <summary>Shift+S - save snapback position.</summary>
    SnapbackSave,
    /// <summary>Shift+R - restore snapback position.</summary>
    SnapbackRestore,
    /// <summary>Shift+P - open preset management screen.</summary>
    PresetMenu,
    /// <summary>Shift+G - toggle glitch mode.</summary>
    GlitchToggle,
    /// <summary>Shift+M - change monitor count.</summary>
    MonitorChange,
    /// <summary>Shift+H - open hotkey configuration screen.</summary>
    HotkeyConfig,

    // Primary monitor controls
    /// <summary>Comma key - decrease windows on primary monitor.</summary>
    PrimaryDecrease,
    /// <summary>Period key - increase windows on primary monitor.</summary>
    PrimaryIncrease,
    /// <summary>Shift+0 (right paren) - reset to auto distribution.</summary>
    PrimaryReset,

    /// <summary>Question mark key - show hotkey help.</summary>
    Help
}

/// <summary>
/// Processes keyboard input and maps keys to actions.
/// Exactly matches PowerShell matrix_control.ps1 key handling behavior.
/// </summary>
/// <remarks>
/// CRITICAL: Shift combinations are detected BEFORE normalizing to lowercase.
/// This preserves the distinction between:
/// - Shift+L (LayoutCycle) vs lowercase l (OpacityIncrease)
/// - Shift+P (PresetMenu) vs lowercase p (Save)
/// - Shift+S (SnapbackSave) vs lowercase s (GreenIncrease)
/// - etc.
///
/// The order of checks matters:
/// 1. Special keys (Tab, Enter, Escape) via ConsoleKey enum
/// 2. Shift combinations via case-sensitive KeyChar check
/// 3. All other keys via lowercase-normalized KeyChar
/// </remarks>
public static class KeyHandler
{
    /// <summary>
    /// Processes a key press and returns the corresponding action.
    /// </summary>
    /// <param name="key">The ConsoleKeyInfo from Console.ReadKey().</param>
    /// <returns>The KeyAction to perform, or KeyAction.None for unrecognized keys.</returns>
    /// <remarks>
    /// Checks shift combinations BEFORE normalizing to lowercase.
    /// This matches the PowerShell behavior:
    /// <code>
    /// # Handle Shift+L (uppercase L) for layout mode BEFORE normalizing
    /// if ($k -ceq 'L') { ... }
    /// # Normalize letter keys to lowercase for case-insensitive handling
    /// $key = if ($k -match '^[A-Za-z]$') { [char]::ToLower($k) } else { $k }
    /// </code>
    /// </remarks>
    public static KeyAction ProcessKey(ConsoleKeyInfo key)
    {
        // Special keys via ConsoleKey enum (most reliable detection)
        if (key.Key == ConsoleKey.Tab)
            return KeyAction.Tab;

        if (key.Key == ConsoleKey.Enter)
            return KeyAction.Launch;

        if (key.Key == ConsoleKey.Escape)
            return KeyAction.Quit;

        // Check shift combinations FIRST (case-sensitive on KeyChar)
        // When Shift is held, letter KeyChar is uppercase
        // This MUST happen before ToLower normalization
        switch (key.KeyChar)
        {
            case 'L': return KeyAction.LayoutCycle;      // Shift+L
            case 'S': return KeyAction.SnapbackSave;     // Shift+S
            case 'R': return KeyAction.SnapbackRestore;  // Shift+R
            case 'P': return KeyAction.PresetMenu;        // Shift+P
            case 'G': return KeyAction.GlitchToggle;     // Shift+G
            case 'M': return KeyAction.MonitorChange;    // Shift+M
            case 'H': return KeyAction.HotkeyConfig;     // Shift+H
            case '?': return KeyAction.Help;             // ? (Shift+/)
        }

        // Now normalize to lowercase for case-insensitive handling
        // This matches PowerShell: $key = [char]::ToLower($k)
        var ch = char.ToLower(key.KeyChar);

        // Map all remaining keys
        return ch switch
        {
            // Color presets (1-6)
            '1' => KeyAction.PresetGreen,
            '2' => KeyAction.PresetBlue,
            '3' => KeyAction.PresetRed,
            '4' => KeyAction.PresetPurple,
            '5' => KeyAction.PresetGold,
            '6' => KeyAction.PresetTeal,

            // RGB controls (Q/W, A/S, Z/X) - adjusts by 0.05
            'q' => KeyAction.RedDecrease,
            'w' => KeyAction.RedIncrease,
            'a' => KeyAction.GreenDecrease,
            's' => KeyAction.GreenIncrease,
            'z' => KeyAction.BlueDecrease,
            'x' => KeyAction.BlueIncrease,

            // Effects (paired keys for -/+)
            'e' => KeyAction.SpeedDecrease,
            'r' => KeyAction.SpeedIncrease,
            'd' => KeyAction.GlowDecrease,
            'f' => KeyAction.GlowIncrease,
            'c' => KeyAction.WidthDecrease,
            'v' => KeyAction.WidthIncrease,
            't' => KeyAction.TrailDecrease,
            'y' => KeyAction.TrailIncrease,
            'g' => KeyAction.DensityDecrease,
            'h' => KeyAction.DensityIncrease,

            // Layers (7/8/9)
            '7' => KeyAction.Layer1Toggle,
            '8' => KeyAction.Layer2Toggle,
            '9' => KeyAction.Layer3Toggle,

            // Window transparency
            'b' => KeyAction.TransparencyToggle,
            'k' => KeyAction.OpacityDecrease,
            'l' => KeyAction.OpacityIncrease,  // lowercase 'l', NOT LayoutCycle

            // Launch count controls
            '-' => KeyAction.LaunchDecrease,
            '+' or '=' => KeyAction.LaunchIncrease,

            // Reset
            '0' => KeyAction.Reset,

            // Windows on Primary controls (< and > keys = comma and period)
            ',' => KeyAction.PrimaryDecrease,
            '.' => KeyAction.PrimaryIncrease,
            ')' => KeyAction.PrimaryReset,  // Shift+0

            _ => KeyAction.None
        };
    }
}
