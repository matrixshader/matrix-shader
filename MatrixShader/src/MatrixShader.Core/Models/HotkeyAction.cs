namespace MatrixShader.Core.Models;

/// <summary>
/// Actions that can be triggered by global hotkeys.
/// Each action maps to a PowerShell control panel equivalent.
/// </summary>
public enum HotkeyAction
{
    /// <summary>Swap focused window with the one to its left.</summary>
    SwapLeft,

    /// <summary>Swap focused window with the one to its right.</summary>
    SwapRight,

    /// <summary>Cycle through layout modes (Pillars/Quads).</summary>
    CycleLayout,

    /// <summary>Toggle window transparency on/off.</summary>
    ToggleTransparency,

    /// <summary>Decrease window opacity by 5%.</summary>
    OpacityDown,

    /// <summary>Increase window opacity by 5%.</summary>
    OpacityUp,

    // CycleShader REMOVED - corrupts shader parameters (BUG-SHADER04, BUG-SHADER05)
    // Shaders only differ by color, which can be changed via color presets

    /// <summary>Increase rain fall speed.</summary>
    SpeedUp,

    /// <summary>Decrease rain fall speed.</summary>
    SpeedDown,

    /// <summary>Toggle the far (background) layer.</summary>
    ToggleFar,

    /// <summary>Toggle the mid layer.</summary>
    ToggleMid,

    /// <summary>Toggle the near (foreground) layer.</summary>
    ToggleNear,

    /// <summary>Show hotkey help overlay.</summary>
    ShowHelp,

    /// <summary>Force reload all shaders by re-saving WT settings.</summary>
    ManualReload,

    /// <summary>Save current window positions as snapback point.</summary>
    SnapbackSave,

    /// <summary>Restore windows to last snapback positions.</summary>
    SnapbackRestore,

    // --- User-addable actions (no default binding, added via hotkey config menu) ---

    /// <summary>Increase glow strength.</summary>
    GlowUp,
    /// <summary>Decrease glow strength.</summary>
    GlowDown,
    /// <summary>Increase character width.</summary>
    WidthUp,
    /// <summary>Decrease character width.</summary>
    WidthDown,
    /// <summary>Increase trail power.</summary>
    TrailUp,
    /// <summary>Decrease trail power.</summary>
    TrailDown,
    /// <summary>Increase rain density.</summary>
    DensityUp,
    /// <summary>Decrease rain density.</summary>
    DensityDown,
    /// <summary>Increase red channel.</summary>
    RedUp,
    /// <summary>Decrease red channel.</summary>
    RedDown,
    /// <summary>Increase green channel.</summary>
    GreenUp,
    /// <summary>Decrease green channel.</summary>
    GreenDown,
    /// <summary>Increase blue channel.</summary>
    BlueUp,
    /// <summary>Decrease blue channel.</summary>
    BlueDown
}
