using MatrixShader.Core.Models;
using MatrixShader.Core.Native;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for calculating and applying window layouts.
/// Ported from WindowLayoutEngine.ps1 with Pillars and Quads strategies.
/// </summary>
public class LayoutService : ILayoutService
{
    private const int MinWindowWidth = 200; // Allow narrower pillars for 4-column layout
    private const int DefaultMaxPillars = 4;
    private const int DefaultGapSize = 30;
    private const int MinGapSize = 0;
    private const int MaxGapSize = 200;
    private const int MinScaledGap = 20; // Minimum gap to ensure clickable space between windows

    private readonly IConfigService _configService;

    /// <summary>
    /// Creates a new layout service with ConfigService for persistence.
    /// </summary>
    /// <param name="configService">Service for state persistence</param>
    public LayoutService(IConfigService configService)
    {
        _configService = configService;
    }

    /// <inheritdoc/>
    public IReadOnlyList<MonitorInfo> GetMonitors()
    {
        var monitors = WindowsApi.GetMonitors();

        // Sort: Primary first, then left-to-right by position
        return monitors
            .OrderByDescending(m => m.IsPrimary)
            .ThenBy(m => m.WorkArea.Left)
            .Select((m, i) => m with { Index = i })
            .ToList();
    }

    /// <inheritdoc/>
    public IReadOnlyList<WindowPosition> CalculateLayout(
        IReadOnlyList<WindowInfo> windows,
        LayoutConfig config)
    {
        if (windows.Count == 0)
            return Array.Empty<WindowPosition>();

        var monitors = GetMonitors();
        if (monitors.Count == 0)
            return Array.Empty<WindowPosition>();

        // Determine effective mode
        var mode = ParseLayoutMode(config.Mode);
        if (mode == LayoutMode.Auto)
        {
            mode = windows.Count <= 4 ? LayoutMode.Pillars : LayoutMode.Quads;
        }

        // Calculate positions based on mode
        var positions = mode switch
        {
            LayoutMode.Pillars => CalculatePillarsLayout(windows.Count, monitors, config),
            LayoutMode.Quads => CalculateQuadsLayout(windows.Count, monitors, config),
            LayoutMode.Overlap => CalculateOverlapLayout(windows.Count, monitors, config),
            _ => CalculatePillarsLayout(windows.Count, monitors, config)
        };

        // Sort windows by shader index for consistent ordering
        var sortedWindows = windows.OrderBy(w => w.ShaderIndex).ToList();

        // Map windows to calculated positions
        var result = new List<WindowPosition>();
        for (int i = 0; i < Math.Min(sortedWindows.Count, positions.Count); i++)
        {
            result.Add(new WindowPosition
            {
                Window = sortedWindows[i],
                Target = positions[i].Rect,
                Monitor = positions[i].Monitor
            });
        }

        return result;
    }

    /// <summary>
    /// Applies calculated positions to windows using border-compensated positioning.
    /// Uses PositionWindowExact to ensure visible window bounds match targets exactly.
    /// Ignores GlitchEnabled - use overload with config for auto-snap behavior.
    /// </summary>
    public void ApplyLayout(IReadOnlyList<WindowPosition> positions)
    {
        ApplyLayoutInternal(positions);
    }

    /// <summary>
    /// Applies calculated positions to windows, respecting GlitchEnabled setting.
    /// If GlitchEnabled is false and force is false, this is a no-op.
    /// </summary>
    public void ApplyLayout(IReadOnlyList<WindowPosition> positions, LayoutConfig config, bool force = false)
    {
        if (!config.GlitchEnabled && !force)
        {
            DiagnosticLogger.Debug("LAYOUT", "Glitch is OFF - skipping auto-layout (use force to override)");
            return;
        }

        ApplyLayoutInternal(positions);
    }

    /// <summary>
    /// Internal implementation of layout application.
    /// </summary>
    private void ApplyLayoutInternal(IReadOnlyList<WindowPosition> positions)
    {
        foreach (var pos in positions)
        {
            // Validate handle is still valid and visible
            if (!WindowsApi.IsHandleValid(pos.Window.Handle))
                continue;

            // Respect user's intentional minimization - skip minimized windows
            if (WindowsApi.IsIconic(pos.Window.Handle))
            {
                DiagnosticLogger.Debug("LAYOUT", $"Skipping minimized window: Matrix-{pos.Window.ShaderIndex}");
                continue;
            }

            // Position with border compensation for pixel-perfect visible bounds
            WindowsApi.PositionWindowExact(pos.Window.Handle, pos.Target);
        }
    }

    /// <inheritdoc/>
    public LayoutMode CycleMode(LayoutMode currentMode)
    {
        return currentMode switch
        {
            LayoutMode.Pillars => LayoutMode.Quads,
            LayoutMode.Quads => LayoutMode.Overlap,
            LayoutMode.Overlap => LayoutMode.Auto,
            LayoutMode.Auto => LayoutMode.Pillars,
            _ => LayoutMode.Pillars
        };
    }

    /// <inheritdoc/>
    public LayoutConfig CycleMode(LayoutConfig current)
    {
        var nextMode = CycleMode(ParseLayoutMode(current.Mode));
        return current with { Mode = nextMode.ToString().ToLowerInvariant() };
    }

    /// <inheritdoc/>
    public LayoutConfig AdjustGap(LayoutConfig current, int delta)
    {
        // Clamp gap size to valid range 0-200
        var newGap = Math.Clamp(current.GapSize + delta, 0, 200);
        return current with { GapSize = newGap };
    }

    /// <inheritdoc/>
    public void UpdateConfig(LayoutConfig config)
    {
        // Load current state, update layout, save immediately
        var state = _configService.LoadState();
        state = state with { Layout = config };
        _configService.SaveState(state);
    }

    /// <inheritdoc/>
    public void SaveWindowSlots(IReadOnlyList<WindowPosition> positions)
    {
        var state = _configService.LoadState();
        var slots = new Dictionary<string, WindowSlot>();

        for (int i = 0; i < positions.Count; i++)
        {
            var pos = positions[i];
            var key = $"Matrix-{pos.Window.ShaderIndex}";
            slots[key] = new WindowSlot
            {
                ShaderIndex = pos.Window.ShaderIndex,
                SlotPosition = i,
                MonitorIndex = pos.Monitor.Index,
                LastPosition = pos.Target
            };
        }

        state = state with { WindowSlots = slots };
        _configService.SaveState(state);
    }

    /// <inheritdoc/>
    public IReadOnlyList<WindowPosition> LoadWindowSlots(IReadOnlyList<WindowInfo> windows)
    {
        var state = _configService.LoadState();
        var savedSlots = state.WindowSlots;

        // Calculate base positions for current layout
        var basePositions = CalculateLayout(windows, state.Layout);

        // If no saved slots, return calculated positions
        if (savedSlots.Count == 0)
            return basePositions;

        // Map windows to their saved slot positions
        var result = new List<WindowPosition>();
        var usedPositions = new HashSet<int>();
        var assignedWindows = new HashSet<int>(); // Track windows by ShaderIndex

        // First pass: assign windows with valid saved slots
        foreach (var window in windows.OrderBy(w => w.ShaderIndex))
        {
            var key = $"Matrix-{window.ShaderIndex}";
            if (savedSlots.TryGetValue(key, out var slot) && slot.SlotPosition < basePositions.Count)
            {
                // Use saved slot position
                result.Add(basePositions[slot.SlotPosition] with { Window = window });
                usedPositions.Add(slot.SlotPosition);
                assignedWindows.Add(window.ShaderIndex);
            }
        }

        // Second pass: assign windows without saved slots to remaining positions
        foreach (var window in windows.OrderBy(w => w.ShaderIndex))
        {
            if (assignedWindows.Contains(window.ShaderIndex))
                continue; // Already assigned in first pass

            // Find first unused position
            for (int i = 0; i < basePositions.Count; i++)
            {
                if (!usedPositions.Contains(i))
                {
                    result.Add(basePositions[i] with { Window = window });
                    usedPositions.Add(i);
                    assignedWindows.Add(window.ShaderIndex);
                    break;
                }
            }
        }

        return result;
    }

    /// <inheritdoc/>
    public int AssignSlot(WindowInfo window)
    {
        var state = _configService.LoadState();
        var usedSlots = state.WindowSlots.Values.Select(s => s.SlotPosition).ToHashSet();

        // Find first unused slot (0-7)
        for (int i = 0; i < 8; i++)
        {
            if (!usedSlots.Contains(i))
                return i;
        }

        return state.WindowSlots.Count; // Overflow to next position
    }

    #region Pillars Layout

    /// <summary>
    /// Calculate Pillars layout: vertical columns arranged side-by-side.
    /// Ported from Get-PillarsLayout in WindowLayoutEngine.ps1
    /// </summary>
    private List<CalculatedPosition> CalculatePillarsLayout(
        int windowCount,
        IReadOnlyList<MonitorInfo> monitors,
        LayoutConfig config)
    {
        var gapSize = CalculateScaledGap(config.GapSize, windowCount);
        var maxPillars = config.MaxWindowsPerMonitor > 0 ? config.MaxWindowsPerMonitor : DefaultMaxPillars;

        // Distribute windows across monitors
        var distribution = DistributeWindows(windowCount, monitors.Count, maxPillars);

        var positions = new List<CalculatedPosition>();
        int windowIndex = 0;

        for (int screenIdx = 0; screenIdx < monitors.Count; screenIdx++)
        {
            var monitor = monitors[screenIdx];
            int windowsOnScreen = distribution[screenIdx];

            if (windowsOnScreen == 0)
                continue;

            var workArea = monitor.WorkArea;

            // Calculate grid dimensions - Pillars mode always uses single row
            int columns = windowsOnScreen;
            int rows = 1;

            // Calculate initial dimensions
            int adjustedGapSize = gapSize;
            int totalHGaps = (columns + 1) * adjustedGapSize;
            int totalVGaps = (rows + 1) * adjustedGapSize;
            int cellWidth = (workArea.Width - totalHGaps) / columns;
            int cellHeight = (workArea.Height - totalVGaps) / rows;

            // If width below minimum and we have gaps, reduce gaps first
            while (cellWidth < MinWindowWidth && adjustedGapSize > 0 && columns > 1)
            {
                // Reduce gap size by 5px increments
                adjustedGapSize = Math.Max(0, adjustedGapSize - 5);
                totalHGaps = (columns + 1) * adjustedGapSize;
                cellWidth = (workArea.Width - totalHGaps) / columns;
            }

            // If still too narrow after removing all gaps, use zero gaps
            if (cellWidth < MinWindowWidth)
            {
                adjustedGapSize = 0;
                totalHGaps = 0;
                cellWidth = workArea.Width / columns;
            }

            // Recalculate height with adjusted gap
            totalVGaps = (rows + 1) * adjustedGapSize;
            cellHeight = (workArea.Height - totalVGaps) / rows;

            // Place each window in grid (column-major order)
            for (int i = 0; i < windowsOnScreen; i++)
            {
                int col = i % columns;
                int row = i / columns;

                // Calculate pixel position using adjusted gap size
                // Formula: edge gap + (cell_index * (cell_size + gap))
                int x = workArea.Left + adjustedGapSize + (col * (cellWidth + adjustedGapSize));
                int y = workArea.Top + adjustedGapSize + (row * (cellHeight + adjustedGapSize));

                positions.Add(new CalculatedPosition
                {
                    Rect = new WindowRect
                    {
                        Left = x,
                        Top = y,
                        Width = cellWidth,
                        Height = cellHeight
                    },
                    Monitor = monitor,
                    WindowIndex = windowIndex++
                });
            }
        }

        return positions;
    }

    #endregion

    #region Quads Layout

    /// <summary>
    /// Calculate Quads layout: 2x2 grid with plus-shaped gap in center.
    /// Ported from Get-QuadsLayout in WindowLayoutEngine.ps1
    /// </summary>
    private List<CalculatedPosition> CalculateQuadsLayout(
        int windowCount,
        IReadOnlyList<MonitorInfo> monitors,
        LayoutConfig config)
    {
        var gapSize = CalculateScaledGap(config.GapSize, windowCount);
        const int windowsPerQuad = 4;

        // Distribute windows across monitors
        var distribution = DistributeWindows(windowCount, monitors.Count, windowsPerQuad);

        // Check for overflow - if more windows than quad capacity, use extended grid
        int totalCapacity = monitors.Count * windowsPerQuad;
        if (windowCount > totalCapacity)
        {
            return CalculateExtendedGridLayout(windowCount, monitors, config, distribution);
        }

        var positions = new List<CalculatedPosition>();
        int windowIndex = 0;

        for (int screenIdx = 0; screenIdx < monitors.Count; screenIdx++)
        {
            var monitor = monitors[screenIdx];
            int windowsOnScreen = distribution[screenIdx];

            if (windowsOnScreen == 0)
                continue;

            var workArea = monitor.WorkArea;

            // Plus-gap calculation:
            // Each dimension has 3 gaps: edge + center + edge
            // Two quadrants share the remaining space equally
            // Formula: (total - 3*gap) / 2
            int halfWidth = (workArea.Width - (3 * gapSize)) / 2;
            int halfHeight = (workArea.Height - (3 * gapSize)) / 2;

            // Define quad positions: TL, TR, BL, BR
            var quadPositions = new[]
            {
                (X: workArea.Left + gapSize, Y: workArea.Top + gapSize),                                           // TL
                (X: workArea.Left + (2 * gapSize) + halfWidth, Y: workArea.Top + gapSize),                        // TR
                (X: workArea.Left + gapSize, Y: workArea.Top + (2 * gapSize) + halfHeight),                       // BL
                (X: workArea.Left + (2 * gapSize) + halfWidth, Y: workArea.Top + (2 * gapSize) + halfHeight)      // BR
            };

            // Place windows in order: TL, TR, BL, BR
            for (int posIdx = 0; posIdx < windowsOnScreen && posIdx < 4; posIdx++)
            {
                positions.Add(new CalculatedPosition
                {
                    Rect = new WindowRect
                    {
                        Left = quadPositions[posIdx].X,
                        Top = quadPositions[posIdx].Y,
                        Width = halfWidth,
                        Height = halfHeight
                    },
                    Monitor = monitor,
                    WindowIndex = windowIndex++
                });
            }
        }

        return positions;
    }

    /// <summary>
    /// Extended grid for overflow (more than 4 windows per screen).
    /// </summary>
    private List<CalculatedPosition> CalculateExtendedGridLayout(
        int windowCount,
        IReadOnlyList<MonitorInfo> monitors,
        LayoutConfig config,
        int[] distribution)
    {
        var gapSize = Math.Max(0, config.GapSize);
        var positions = new List<CalculatedPosition>();
        int windowIndex = 0;

        for (int screenIdx = 0; screenIdx < monitors.Count; screenIdx++)
        {
            int windowsOnThisScreen = distribution[screenIdx];
            if (windowsOnThisScreen <= 0)
                continue;

            var monitor = monitors[screenIdx];
            var workArea = monitor.WorkArea;

            // Calculate grid dimensions to fit all windows
            // Try to maintain roughly square cells
            int cols = (int)Math.Ceiling(Math.Sqrt(windowsOnThisScreen * ((double)workArea.Width / workArea.Height)));
            cols = Math.Max(cols, 2); // At least 2 columns for quad-like appearance
            int rows = (int)Math.Ceiling((double)windowsOnThisScreen / cols);

            // Calculate cell dimensions with gaps
            int totalHGaps = (cols + 1) * gapSize;
            int totalVGaps = (rows + 1) * gapSize;
            int cellWidth = (workArea.Width - totalHGaps) / cols;
            int cellHeight = (workArea.Height - totalVGaps) / rows;

            // Place windows in grid
            for (int i = 0; i < windowsOnThisScreen; i++)
            {
                int col = i % cols;
                int row = i / cols;

                int x = workArea.Left + gapSize + (col * (cellWidth + gapSize));
                int y = workArea.Top + gapSize + (row * (cellHeight + gapSize));

                positions.Add(new CalculatedPosition
                {
                    Rect = new WindowRect
                    {
                        Left = x,
                        Top = y,
                        Width = cellWidth,
                        Height = cellHeight
                    },
                    Monitor = monitor,
                    WindowIndex = windowIndex++
                });
            }
        }

        return positions;
    }

    #endregion

    #region Overlap Layout

    /// <summary>
    /// Calculate Overlap layout: windows with slight overlap for 5+ windows.
    /// </summary>
    private List<CalculatedPosition> CalculateOverlapLayout(
        int windowCount,
        IReadOnlyList<MonitorInfo> monitors,
        LayoutConfig config)
    {
        var gapSize = CalculateScaledGap(config.GapSize, windowCount);
        var overlapPercent = Math.Clamp(config.OverlapPercent, 0, 20);

        var positions = new List<CalculatedPosition>();
        int windowIndex = 0;

        // Use primary monitor for overlap
        var monitor = monitors.FirstOrDefault(m => m.IsPrimary) ?? monitors[0];
        var workArea = monitor.WorkArea;

        // Calculate overlap offset
        int overlapOffset = (int)(workArea.Width * overlapPercent / 100.0);

        // Calculate window size (each window slightly overlaps the next)
        int windowWidth = (workArea.Width - gapSize * 2 + overlapOffset * (windowCount - 1)) / windowCount;
        windowWidth = Math.Max(windowWidth, MinWindowWidth);
        int windowHeight = workArea.Height - gapSize * 2;

        // Calculate starting X to center the group
        int totalWidth = windowWidth * windowCount - overlapOffset * (windowCount - 1);
        int startX = workArea.Left + (workArea.Width - totalWidth) / 2;

        for (int i = 0; i < windowCount; i++)
        {
            int x = startX + i * (windowWidth - overlapOffset);
            int y = workArea.Top + gapSize;

            positions.Add(new CalculatedPosition
            {
                Rect = new WindowRect
                {
                    Left = x,
                    Top = y,
                    Width = windowWidth,
                    Height = windowHeight
                },
                Monitor = monitor,
                WindowIndex = windowIndex++
            });
        }

        return positions;
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Distribute windows across monitors.
    /// Ported from Get-WindowDistributionWithPrimary in WindowLayoutEngine.ps1
    /// </summary>
    private int[] DistributeWindows(int windowCount, int screenCount, int maxPerScreen)
    {
        var distribution = new int[screenCount];

        if (windowCount <= 0 || screenCount <= 0)
            return distribution;

        // Single screen - put everything there
        if (screenCount == 1)
        {
            distribution[0] = windowCount;
            return distribution;
        }

        // Multi-screen: balanced distribution
        int baseCount = windowCount / screenCount;
        int remainder = windowCount % screenCount;

        for (int i = 0; i < screenCount; i++)
        {
            // Each screen gets base count, first screens get +1 for remainder
            int count = baseCount + (i < remainder ? 1 : 0);
            // Cap at maxPerScreen
            distribution[i] = Math.Min(count, maxPerScreen);
        }

        return distribution;
    }

    /// <summary>
    /// Parse layout mode from string.
    /// </summary>
    private static LayoutMode ParseLayoutMode(string? mode)
    {
        if (string.IsNullOrEmpty(mode))
            return LayoutMode.Auto;

        return mode.ToLowerInvariant() switch
        {
            "pillars" => LayoutMode.Pillars,
            "quads" => LayoutMode.Quads,
            "overlap" => LayoutMode.Overlap,
            "auto" => LayoutMode.Auto,
            _ => LayoutMode.Auto
        };
    }

    /// <summary>
    /// Calculates scaled gap size based on window count.
    /// More windows = proportionally smaller gaps, but never below 20px minimum.
    /// Formula: 1-2 windows: 100%, 3 windows: 80%, 4+ windows: 60% of base gap
    /// </summary>
    private static int CalculateScaledGap(int baseGap, int windowCount)
    {
        double scaleFactor = windowCount switch
        {
            <= 2 => 1.0,
            3 => 0.8,
            _ => 0.6
        };

        int scaledGap = (int)(baseGap * scaleFactor);
        return Math.Max(scaledGap, MinScaledGap);
    }

    #endregion

    /// <summary>
    /// Internal structure for calculated positions before mapping to windows.
    /// </summary>
    private record struct CalculatedPosition
    {
        public WindowRect Rect { get; init; }
        public MonitorInfo Monitor { get; init; }
        public int WindowIndex { get; init; }
    }
}
