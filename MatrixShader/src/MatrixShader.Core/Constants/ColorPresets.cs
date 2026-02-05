namespace MatrixShader.Core.Constants;

/// <summary>
/// Matrix-themed color presets matching the original film aesthetic.
/// </summary>
public static class ColorPresets
{
    // Classic Matrix green (default)
    public static readonly MatrixColor Green = new(0f, 1f, 0.3f, "Green", "Classic Matrix");

    // Electric blue
    public static readonly MatrixColor Blue = new(0f, 0.6f, 1f, "Blue", "Electric blue");

    // Blood/warning red
    public static readonly MatrixColor Red = new(1f, 0.1f, 0.1f, "Red", "Sentinel alert");

    // Cyber purple
    public static readonly MatrixColor Purple = new(0.7f, 0f, 1f, "Purple", "Cyber dreams");

    // Ancient gold
    public static readonly MatrixColor Gold = new(1f, 0.7f, 0f, "Gold", "Machine city");

    // Ocean teal
    public static readonly MatrixColor Teal = new(0f, 0.9f, 0.9f, "Teal", "Awakened");

    /// <summary>
    /// All available color presets in display order.
    /// </summary>
    public static readonly MatrixColor[] All = [Green, Blue, Red, Purple, Gold, Teal];

    /// <summary>
    /// Get preset by number key (1-6).
    /// </summary>
    public static MatrixColor? GetByKey(int key) =>
        key >= 1 && key <= All.Length ? All[key - 1] : null;

    /// <summary>
    /// Get preset by name (case-insensitive).
    /// </summary>
    public static MatrixColor? GetByName(string name) =>
        All.FirstOrDefault(c => c.Name.Equals(name, StringComparison.OrdinalIgnoreCase));
}

/// <summary>
/// A named color preset with RGB values.
/// </summary>
public readonly record struct MatrixColor(float R, float G, float B, string Name, string Description)
{
    /// <summary>
    /// Convert to 24-bit RGB for ANSI escape codes.
    /// </summary>
    public (byte R, byte G, byte B) ToRgb() =>
        ((byte)(R * 255), (byte)(G * 255), (byte)(B * 255));

    /// <summary>
    /// Generate ANSI escape code for foreground color.
    /// </summary>
    public string ToAnsiFg()
    {
        var (r, g, b) = ToRgb();
        return $"\x1b[38;2;{r};{g};{b}m";
    }

    /// <summary>
    /// Generate ANSI escape code for background color.
    /// </summary>
    public string ToAnsiBg()
    {
        var (r, g, b) = ToRgb();
        return $"\x1b[48;2;{r};{g};{b}m";
    }
}
