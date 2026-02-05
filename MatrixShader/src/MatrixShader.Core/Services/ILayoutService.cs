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

    /// <summary>
    /// Cycles to the next layout mode and returns updated config.
    /// </summary>
    /// <param name="current">Current layout configuration</param>
    /// <returns>New config with next mode</returns>
    LayoutConfig CycleMode(LayoutConfig current);

    /// <summary>
    /// Adjusts gap size by delta, clamping to valid range 0-200.
    /// </summary>
    /// <param name="current">Current layout configuration</param>
    /// <param name="delta">Amount to adjust (+/- 5 typical)</param>
    /// <returns>New config with adjusted gap size</returns>
    LayoutConfig AdjustGap(LayoutConfig current, int delta);

    /// <summary>
    /// Saves the layout configuration immediately to persistent state.
    /// </summary>
    /// <param name="config">Configuration to persist</param>
    void UpdateConfig(LayoutConfig config);

    /// <summary>
    /// Saves current window slot assignments for persistence.
    /// </summary>
    /// <param name="positions">Current window positions to persist as slots</param>
    void SaveWindowSlots(IReadOnlyList<WindowPosition> positions);

    /// <summary>
    /// Loads saved slot assignments and returns windows mapped to slots.
    /// </summary>
    /// <param name="windows">Windows to map to saved slots</param>
    /// <returns>Windows positioned according to saved slot assignments</returns>
    IReadOnlyList<WindowPosition> LoadWindowSlots(IReadOnlyList<WindowInfo> windows);

    /// <summary>
    /// Assigns a new window to the next available slot.
    /// </summary>
    /// <param name="window">Window to assign</param>
    /// <returns>Assigned slot position (0-based)</returns>
    int AssignSlot(WindowInfo window);
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
