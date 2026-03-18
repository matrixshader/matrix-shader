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

    /// <summary>Confidence level of identity resolution (0.0 to 1.0)</summary>
    public double Confidence { get; init; }

    /// <summary>Is this the control panel window</summary>
    public bool IsControlPanel { get; init; }

    /// <summary>Is this a Construct picker window (not yet transitioned to rain)</summary>
    public bool IsConstruct { get; init; }
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

    /// <summary>
    /// An empty rectangle with all values at zero.
    /// Useful for error returns and default values.
    /// </summary>
    public static WindowRect Empty { get; } = new();

    public static WindowRect FromLTRB(int left, int top, int right, int bottom) =>
        new() { Left = left, Top = top, Width = right - left, Height = bottom - top };
}

/// <summary>
/// Source of window identity resolution.
/// Each source has an associated confidence level.
/// </summary>
public enum IdentitySource
{
    /// <summary>Unknown source (confidence 0.0)</summary>
    Unknown = 0,

    /// <summary>Tracked from process launch - fresh (confidence 1.0)</summary>
    LaunchTracking = 1,

    /// <summary>Recovered from disk after restart (confidence 0.95)</summary>
    LaunchTrackingRecovered = 2,

    /// <summary>Parsed from command line arguments (confidence 0.95)</summary>
    CommandLine = 3,

    /// <summary>Matched from window title (confidence 0.70)</summary>
    Title = 4,

    /// <summary>Resolved via UI Automation TermControl (confidence 0.95)</summary>
    UIAutomationTermControl = 5,

    /// <summary>Resolved via UI Automation Tab (confidence 0.85)</summary>
    UIAutomationTab = 6,

    /// <summary>Resolved via UI Automation Name (confidence 0.90)</summary>
    UIAutomationName = 7,

    /// <summary>Resolved by elimination - only one unclaimed index matches (confidence 0.80)</summary>
    Elimination = 8
}

/// <summary>
/// Extension methods for IdentitySource enum.
/// </summary>
public static class IdentitySourceExtensions
{
    /// <summary>
    /// Gets the confidence score for the identity source.
    /// Matches PowerShell WindowIdentityService.ps1 confidence values exactly.
    /// </summary>
    public static double GetConfidence(this IdentitySource source) => source switch
    {
        IdentitySource.LaunchTracking => 1.0,
        IdentitySource.LaunchTrackingRecovered => 0.95,
        IdentitySource.CommandLine => 0.95,
        IdentitySource.UIAutomationTermControl => 0.95,
        IdentitySource.UIAutomationName => 0.90,
        IdentitySource.UIAutomationTab => 0.85,
        IdentitySource.Elimination => 0.80,
        IdentitySource.Title => 0.70,
        _ => 0.0
    };
}
