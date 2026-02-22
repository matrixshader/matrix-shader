namespace MatrixShader.Core.Models;

/// <summary>
/// Complete application state for persistence.
/// </summary>
public record MatrixState
{
    /// <summary>Currently selected tab index (1-8)</summary>
    public int ActiveTab { get; init; } = 1;

    /// <summary>Configuration for each shader window</summary>
    public Dictionary<int, ShaderConfig> ShaderConfigs { get; init; } = new()
    {
        [1] = new ShaderConfig(),
        [2] = new ShaderConfig(),
        [3] = new ShaderConfig(),
        [4] = new ShaderConfig(),
        [5] = new ShaderConfig(),
        [6] = new ShaderConfig(),
        [7] = new ShaderConfig(),
        [8] = new ShaderConfig()
    };

    /// <summary>Layout configuration</summary>
    public LayoutConfig Layout { get; init; } = new();

    /// <summary>Current render mode</summary>
    public RenderMode RenderMode { get; init; } = RenderMode.Full;

    /// <summary>Debug logging enabled</summary>
    public bool DebugEnabled { get; init; }

    /// <summary>Last save timestamp</summary>
    public DateTime LastModified { get; init; } = DateTime.UtcNow;

    /// <summary>Window slot assignments for layout persistence</summary>
    public Dictionary<string, WindowSlot> WindowSlots { get; init; } = new();

    /// <summary>Whether the hotkey help overlay has been auto-shown at least once</summary>
    public bool HelpShownOnce { get; init; }
}

/// <summary>
/// Rendering mode based on environment detection.
/// </summary>
public enum RenderMode
{
    /// <summary>Full shader mode (Windows Terminal)</summary>
    Full,

    /// <summary>Text-based fallback (any terminal)</summary>
    Lite,

    /// <summary>No UI, window management only</summary>
    Headless
}
