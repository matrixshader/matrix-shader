namespace MatrixShader.Core.Models;

/// <summary>
/// Information about a Matrix shader window.
/// </summary>
public record WindowInfo
{
    /// <summary>Native window handle</summary>
    public nint Handle { get; init; }

    /// <summary>Window title text</summary>
    public string Title { get; init; } = string.Empty;

    /// <summary>Process ID that owns the window</summary>
    public int ProcessId { get; init; }

    /// <summary>Associated terminal profile name</summary>
    public string? ProfileName { get; init; }

    /// <summary>Assigned shader index (1-8)</summary>
    public int ShaderIndex { get; init; }

    /// <summary>Current window position</summary>
    public WindowRect Position { get; init; } = new();

    /// <summary>Identity resolution source</summary>
    public IdentitySource Source { get; init; } = IdentitySource.Unknown;

    /// <summary>Is this the control panel window</summary>
    public bool IsControlPanel { get; init; }
}

/// <summary>
/// Window rectangle position and dimensions.
/// </summary>
public record WindowRect
{
    public int Left { get; init; }
    public int Top { get; init; }
    public int Width { get; init; }
    public int Height { get; init; }

    public int Right => Left + Width;
    public int Bottom => Top + Height;

    public static WindowRect FromLTRB(int left, int top, int right, int bottom) =>
        new() { Left = left, Top = top, Width = right - left, Height = bottom - top };
}

/// <summary>
/// Source of window identity resolution.
/// </summary>
public enum IdentitySource
{
    Unknown = 0,

    /// <summary>Tracked from process launch</summary>
    LaunchTracking = 1,

    /// <summary>Parsed from command line arguments</summary>
    CommandLine = 2,

    /// <summary>Matched from window title</summary>
    Title = 3,

    /// <summary>Resolved via UI Automation (slow)</summary>
    UIAutomation = 4
}
