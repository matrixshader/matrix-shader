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
    ShowHelp
}
