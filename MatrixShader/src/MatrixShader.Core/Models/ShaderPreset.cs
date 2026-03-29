namespace MatrixShader.Core.Models;

/// <summary>
/// A saved shader configuration preset.
/// Persisted as individual JSON files in %LOCALAPPDATA%\MatrixShader\presets\.
/// </summary>
public record ShaderPreset
{
    /// <summary>Sanitized preset name (used as filename stem)</summary>
    public string Name { get; init; } = string.Empty;

    /// <summary>Red color component (0.0 - 1.0)</summary>
    public float R { get; init; }

    /// <summary>Green color component (0.0 - 1.0)</summary>
    public float G { get; init; } = 1f;

    /// <summary>Blue color component (0.0 - 1.0)</summary>
    public float B { get; init; } = 0.3f;

    /// <summary>Animation speed multiplier (0.1 - 5.0)</summary>
    public float Speed { get; init; } = 0.8f;

    /// <summary>Glow intensity (0.2 - 3.0)</summary>
    public float Glow { get; init; } = 0.8f;

    /// <summary>Character column width in pixels (6 - 20)</summary>
    public float Width { get; init; } = 10f;

    /// <summary>Trail length multiplier (4 - 15)</summary>
    public float Trail { get; init; } = 8f;

    /// <summary>Character spawn density (0.2 - 1.0)</summary>
    public float Density { get; init; } = 0.25f;

    /// <summary>Far depth layer enabled</summary>
    public bool Layer1 { get; init; } = true;

    /// <summary>Mid depth layer enabled</summary>
    public bool Layer2 { get; init; } = true;

    /// <summary>Near depth layer enabled</summary>
    public bool Layer3 { get; init; } = true;

    /// <summary>UTC timestamp when preset was saved</summary>
    public DateTime SavedAt { get; init; } = DateTime.UtcNow;

    /// <summary>
    /// Creates a ShaderPreset from a ShaderConfig and a name.
    /// </summary>
    public static ShaderPreset FromConfig(string name, ShaderConfig config) => new()
    {
        Name = name,
        R = config.R,
        G = config.G,
        B = config.B,
        Speed = config.Speed,
        Glow = config.Glow,
        Width = config.Width,
        Trail = config.Trail,
        Density = config.Density,
        Layer1 = config.Layer1,
        Layer2 = config.Layer2,
        Layer3 = config.Layer3,
        SavedAt = DateTime.UtcNow
    };

    /// <summary>
    /// Converts this preset back to a ShaderConfig.
    /// </summary>
    public ShaderConfig ToConfig() => new()
    {
        R = R,
        G = G,
        B = B,
        Speed = Speed,
        Glow = Glow,
        Width = Width,
        Trail = Trail,
        Density = Density,
        Layer1 = Layer1,
        Layer2 = Layer2,
        Layer3 = Layer3
    };
}
