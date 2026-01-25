using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for calculating and applying window layouts.
/// </summary>
public interface ILayoutService
{
    /// <summary>
    /// Gets information about all connected monitors.
    /// </summary>
    IReadOnlyList<MonitorInfo> GetMonitors();

    /// <summary>
    /// Calculates window positions for the given layout mode.
    /// </summary>
    /// <param name="windows">Windows to position</param>
    /// <param name="config">Layout configuration</param>
    /// <returns>Calculated positions for each window</returns>
    IReadOnlyList<WindowPosition> CalculateLayout(
        IReadOnlyList<WindowInfo> windows,
        LayoutConfig config);

    /// <summary>
    /// Applies calculated positions to windows.
    /// </summary>
    /// <param name="positions">Positions to apply</param>
    void ApplyLayout(IReadOnlyList<WindowPosition> positions);

    /// <summary>
    /// Cycles to the next layout mode.
    /// </summary>
    /// <param name="currentMode">Current layout mode</param>
    /// <returns>Next mode in cycle</returns>
    LayoutMode CycleMode(LayoutMode currentMode);
}

/// <summary>
/// A calculated window position.
/// </summary>
public record WindowPosition
{
    /// <summary>Window to position</summary>
    public required WindowInfo Window { get; init; }

    /// <summary>Calculated position rectangle</summary>
    public required WindowRect Target { get; init; }

    /// <summary>Target monitor</summary>
    public required MonitorInfo Monitor { get; init; }
}
