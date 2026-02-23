namespace MatrixShader.Core.Models;

/// <summary>
/// Configuration for window layout positioning.
/// </summary>
public record LayoutConfig
{
    /// <summary>Number of monitors detected</summary>
    public int MonitorCount { get; init; } = 1;

    /// <summary>Gap size in pixels between windows</summary>
    public int GapSize { get; init; } = 120;

    /// <summary>Layout mode: Pillars, Quads, Overlap, or Auto</summary>
    public string Mode { get; init; } = "Pillars";

    /// <summary>Enable glitch effect positioning</summary>
    public bool GlitchEnabled { get; init; } = true;

    /// <summary>When true, specific windows are locked to primary monitor</summary>
    public bool PriorityLock { get; init; } = false;

    /// <summary>Override for windows on primary monitor. 0 = auto distribution</summary>
    public int PrimaryWindowCount { get; init; } = 0;

    /// <summary>Overlap percentage for Overlap mode (0-20)</summary>
    public int OverlapPercent { get; init; } = 5;

    /// <summary>Maximum windows per monitor</summary>
    public int MaxWindowsPerMonitor { get; init; } = 4;

    /// <summary>
    /// Validates all parameters are within acceptable ranges.
    /// </summary>
    public bool IsValid() =>
        MonitorCount >= 1 && MonitorCount <= 16 &&
        GapSize >= 0 && GapSize <= 200 &&
        !string.IsNullOrEmpty(Mode) &&
        OverlapPercent >= 0 && OverlapPercent <= 20 &&
        MaxWindowsPerMonitor >= 1 && MaxWindowsPerMonitor <= 8;
}

/// <summary>
/// Layout mode enumeration for type-safe mode selection.
/// </summary>
public enum LayoutMode
{
    /// <summary>Side-by-side vertical columns</summary>
    Pillars,

    /// <summary>2x2 grid layout</summary>
    Quads,

    /// <summary>Overlapping windows for 5+ windows</summary>
    Overlap,

    /// <summary>Auto-select based on window count</summary>
    Auto
}
