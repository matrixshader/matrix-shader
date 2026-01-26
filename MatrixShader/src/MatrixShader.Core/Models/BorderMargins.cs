namespace MatrixShader.Core.Models;

/// <summary>
/// Represents the invisible border margins around a window.
/// Windows 10/11 have invisible resize borders (typically 7px on left/right/bottom)
/// that GetWindowRect includes but aren't visible on screen.
/// Use DwmGetWindowAttribute with DWMWA_EXTENDED_FRAME_BOUNDS to get actual visible bounds,
/// then calculate margins as the difference.
/// </summary>
public record BorderMargins
{
    /// <summary>Left invisible border width in pixels</summary>
    public int Left { get; init; }

    /// <summary>Top invisible border width in pixels (usually 0)</summary>
    public int Top { get; init; }

    /// <summary>Right invisible border width in pixels</summary>
    public int Right { get; init; }

    /// <summary>Bottom invisible border width in pixels</summary>
    public int Bottom { get; init; }

    /// <summary>
    /// Zero margins (no invisible borders).
    /// </summary>
    public static BorderMargins Zero { get; } = new();
}
