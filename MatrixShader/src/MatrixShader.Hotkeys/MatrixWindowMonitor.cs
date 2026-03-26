using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Monitors for Matrix windows and triggers exit when none exist.
/// Also monitors for window overlap to trigger auto-repositioning (Glitch system).
/// Per CONTEXT.md: "Auto-exits when all Matrix windows close"
/// </summary>
public sealed class MatrixWindowMonitor : IDisposable
{
    private readonly IIdentityService _identityService;
    private readonly ILayoutService? _layoutService;
    private readonly IConfigService? _configService;
    private readonly Action _onNoWindows;
    private readonly Timer _timer;
    private bool _disposed;

    // Poll interval - check for windows every 2 seconds
    private const int PollIntervalMs = 2000;

    // Grace period - wait a few checks before exiting (handles brief window recreation)
    private int _noWindowCount;

    // Stay-alive timer - keep running for 30 seconds after last window seen
    // This allows users to reopen Matrix windows without restarting hotkey service
    private DateTime _lastWindowSeen = DateTime.Now;
    private const int StayAliveSeconds = 30;

    // Overlap detection cooldown - avoid repositioning spam
    private DateTime _lastOverlapReposition = DateTime.MinValue;
    private static readonly TimeSpan OverlapCooldown = TimeSpan.FromSeconds(3);

    // Manual action pause - when user does hotkey rotation, pause Glitch
    private static DateTime _glitchPauseUntil = DateTime.MinValue;
    private static readonly TimeSpan ManualActionPause = TimeSpan.FromSeconds(5);

    // Minimum overlap area to trigger repositioning (in pixels squared)
    private const int MinOverlapArea = 10000; // ~100x100 pixels

    // Reentrancy guard - prevents overlapping CheckWindows calls
    private int _checkingWindows;

    // Truth positions - where windows "should" be (updated on layout apply or user drag)
    private Dictionary<nint, WindowRect> _truthPositions = new();

    // Static reference to the singleton instance for cross-class truth updates
    private static MatrixWindowMonitor? _instance;

    // Threshold for detecting user drag (pixels)
    private const int UserDragThreshold = 100;

    /// <summary>
    /// Pauses Glitch auto-repositioning for a few seconds.
    /// Called by HotkeyActions when user manually rotates/moves windows.
    /// </summary>
    public static void PauseGlitch()
    {
        _glitchPauseUntil = DateTime.Now + ManualActionPause;
        DiagnosticLogger.Debug("HOTKEYS", $"Glitch paused for {ManualActionPause.TotalSeconds}s");
    }

    /// <summary>
    /// Updates truth position for a window after hotkey rotation/movement.
    /// This prevents Glitch from snapping windows back to pre-rotation positions.
    /// </summary>
    public static void UpdateTruth(nint handle, WindowRect position)
    {
        if (_instance != null)
        {
            _instance._truthPositions[handle] = position;
        }
    }

    /// <summary>
    /// Number of consecutive checks with no windows before triggering exit.
    /// At 2 second intervals, this works with the stay-alive timer (30 seconds).
    /// Threshold ensures grace period is respected before exit.
    /// </summary>
    public const int NoWindowThreshold = 15; // 15 * 2s = 30 seconds

    /// <summary>
    /// Creates a monitor for window existence only (original behavior).
    /// </summary>
    public MatrixWindowMonitor(IIdentityService identityService, Action onNoWindows)
        : this(identityService, null, null, onNoWindows)
    {
    }

    /// <summary>
    /// Creates a monitor with full Glitch system support (overlap detection + auto-reposition).
    /// </summary>
    public MatrixWindowMonitor(
        IIdentityService identityService,
        ILayoutService? layoutService,
        IConfigService? configService,
        Action onNoWindows)
    {
        _identityService = identityService ?? throw new ArgumentNullException(nameof(identityService));
        _layoutService = layoutService;
        _configService = configService;
        _onNoWindows = onNoWindows ?? throw new ArgumentNullException(nameof(onNoWindows));
        _timer = new Timer(CheckWindows, null, Timeout.Infinite, Timeout.Infinite);
        _instance = this;
    }

    /// <summary>
    /// Starts monitoring for Matrix windows.
    /// </summary>
    public void StartMonitoring()
    {
        _timer.Change(PollIntervalMs, PollIntervalMs);
        DiagnosticLogger.Debug("HOTKEYS", "Window monitor started");
    }

    /// <summary>
    /// Stops monitoring.
    /// </summary>
    public void StopMonitoring()
    {
        _timer.Change(Timeout.Infinite, Timeout.Infinite);
        DiagnosticLogger.Debug("HOTKEYS", "Window monitor stopped");
    }

    private void CheckWindows(object? state)
    {
        // Reentrancy guard - skip if previous check is still running
        if (Interlocked.Exchange(ref _checkingWindows, 1) == 1)
            return;

        try
        {
            var windows = _identityService.FindMatrixWindows();

            // Filter out control panel and Construct - only count shader windows
            var shaderWindows = new List<WindowInfo>();
            foreach (var window in windows)
            {
                if (!window.IsControlPanel && !window.IsConstruct)
                {
                    shaderWindows.Add(window);
                }
            }

            if (shaderWindows.Count == 0)
            {
                _noWindowCount++;

                // Calculate remaining stay-alive time
                var elapsed = DateTime.Now - _lastWindowSeen;
                var remaining = StayAliveSeconds - (int)elapsed.TotalSeconds;

                if (remaining > 0)
                {
                    DiagnosticLogger.Debug("HOTKEYS", $"No shader windows, stay-alive: {remaining}s remaining");
                }
                else if (_noWindowCount >= NoWindowThreshold)
                {
                    DiagnosticLogger.Info("HOTKEYS", "No Matrix windows for stay-alive period, triggering exit");
                    StopMonitoring();
                    _onNoWindows();
                }
            }
            else
            {
                // Reset counter and stay-alive timer when windows exist
                if (_noWindowCount > 0)
                {
                    DiagnosticLogger.Debug("HOTKEYS", $"Matrix windows detected ({shaderWindows.Count}), resetting counters");
                }
                _noWindowCount = 0;
                _lastWindowSeen = DateTime.Now;

                // Check for overlapping windows (Glitch system)
                CheckForOverlap(shaderWindows);
            }
        }
        catch (Exception ex)
        {
            // Silent failure - keep monitoring
            DiagnosticLogger.Warn("HOTKEYS", $"Window check failed: {ex.Message}");
        }
        finally
        {
            Interlocked.Exchange(ref _checkingWindows, 0);
        }
    }

    /// <summary>
    /// Checks if any windows overlap and triggers auto-repositioning if Glitch is enabled.
    /// Fullscreen windows are excluded from overlap detection (fixes BUG-LAYOUT06: F11 snap-back).
    /// User drags are detected and accepted as new truth positions instead of snapping back.
    /// </summary>
    private void CheckForOverlap(List<WindowInfo> windows)
    {
        // Skip if we don't have layout service
        if (_layoutService == null || _configService == null)
            return;

        // Clean stale handles from truth positions
        CleanStaleTruthPositions();

        // Skip if less than 2 windows
        if (windows.Count < 2)
            return;

        // Check cooldown
        if (DateTime.Now - _lastOverlapReposition < OverlapCooldown)
            return;

        // Check if manually paused (user did hotkey rotation)
        if (DateTime.Now < _glitchPauseUntil)
            return;

        // Load config to check if Glitch is enabled
        var state = _configService.LoadState();
        if (!state.Layout.GlitchEnabled)
            return;

        // Filter out fullscreen and minimized windows — only check tiled windows
        var tiledWindows = new List<WindowInfo>();
        foreach (var window in windows)
        {
            if (!WindowsApi.IsZoomed(window.Handle) && !WindowsApi.IsIconic(window.Handle))
            {
                tiledWindows.Add(window);
            }
        }

        var fullscreenCount = windows.Count - tiledWindows.Count;
        if (fullscreenCount > 0)
        {
            DiagnosticLogger.Debug("HOTKEYS", $"Excluding {fullscreenCount} fullscreen/minimized window(s) from glitch detection");
        }

        // Get VISIBLE bounds for overlap detection.
        // WindowInfo.Position uses GetWindowRect which includes invisible DWM borders
        // (~7px left/right/bottom on Windows 10/11). Using those for overlap detection
        // causes false positives — adjacent windows with proper gaps between their
        // visible edges will appear to overlap due to invisible borders.
        var visibleBounds = new Dictionary<nint, WindowRect>();
        foreach (var window in tiledWindows)
        {
            visibleBounds[window.Handle] = WindowsApi.GetVisibleWindowBounds(window.Handle);
        }

        // Detect user drags — update truth instead of snapping back
        foreach (var window in tiledWindows)
        {
            var currentPos = visibleBounds[window.Handle];
            if (_truthPositions.TryGetValue(window.Handle, out var truth))
            {
                var dx = Math.Abs(currentPos.Left - truth.Left);
                var dy = Math.Abs(currentPos.Top - truth.Top);
                if (dx > UserDragThreshold || dy > UserDragThreshold)
                {
                    // User moved this window — accept as new truth
                    _truthPositions[window.Handle] = currentPos;
                    DiagnosticLogger.Debug("HOTKEYS", $"User moved Matrix-{window.ShaderIndex}, updated truth (+{dx},{dy}px)");
                }
            }
            else
            {
                // New window — initialize truth from current position
                _truthPositions[window.Handle] = currentPos;
            }
        }

        // Skip if less than 2 tiled windows remain
        if (tiledWindows.Count < 2)
            return;

        // Check for overlap between any two tiled windows using VISIBLE bounds
        bool hasOverlap = false;
        for (int i = 0; i < tiledWindows.Count && !hasOverlap; i++)
        {
            for (int j = i + 1; j < tiledWindows.Count && !hasOverlap; j++)
            {
                var boundsI = visibleBounds[tiledWindows[i].Handle];
                var boundsJ = visibleBounds[tiledWindows[j].Handle];
                var overlapArea = CalculateOverlapArea(boundsI, boundsJ);
                if (overlapArea >= MinOverlapArea)
                {
                    hasOverlap = true;
                    DiagnosticLogger.Info("HOTKEYS", $"Overlap detected between windows {i} and {j} (area: {overlapArea}px^2)");
                }
            }
        }

        // Trigger auto-repositioning if overlap detected
        if (hasOverlap)
        {
            DiagnosticLogger.Info("HOTKEYS", "Glitch triggered: auto-repositioning windows");
            _lastOverlapReposition = DateTime.Now;

            try
            {
                // Reposition by current monitor — respects user drags
                var positions = _layoutService.CalculateLayoutByCurrentMonitor(tiledWindows, state.Layout);
                _layoutService.ApplyLayout(positions, state.Layout, force: true);

                // Update truth positions after layout apply
                foreach (var pos in positions)
                {
                    _truthPositions[pos.Window.Handle] = pos.Target;
                }
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Warn("HOTKEYS", $"Auto-reposition failed: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Removes stale handles from truth positions dictionary.
    /// </summary>
    private void CleanStaleTruthPositions()
    {
        var staleKeys = new List<nint>();
        foreach (var kv in _truthPositions)
        {
            if (!WindowsApi.IsHandleValid(kv.Key))
                staleKeys.Add(kv.Key);
        }
        foreach (var key in staleKeys)
        {
            _truthPositions.Remove(key);
        }
    }

    /// <summary>
    /// Calculates the overlapping area between two window rectangles.
    /// </summary>
    private static int CalculateOverlapArea(WindowRect a, WindowRect b)
    {
        // Calculate intersection rectangle
        int left = Math.Max(a.Left, b.Left);
        int top = Math.Max(a.Top, b.Top);
        int right = Math.Min(a.Left + a.Width, b.Left + b.Width);
        int bottom = Math.Min(a.Top + a.Height, b.Top + b.Height);

        // If no intersection, return 0
        if (left >= right || top >= bottom)
            return 0;

        return (right - left) * (bottom - top);
    }

    /// <summary>
    /// Triggers an immediate layout refresh (used when display changes).
    /// Excludes fullscreen windows from repositioning (fixes BUG-LAYOUT07: drag/snap state corruption).
    /// </summary>
    public void TriggerLayoutRefresh()
    {
        if (_layoutService == null || _configService == null)
            return;

        try
        {
            var allWindows = _identityService.FindMatrixWindows()
                .Where(w => !w.IsControlPanel && !w.IsConstruct)
                .ToList();

            // Filter out fullscreen windows - only reposition tiled windows
            var tiledWindows = allWindows
                .Where(w => !WindowsApi.IsZoomed(w.Handle))
                .ToList();

            if (tiledWindows.Count == 0)
                return;

            var fullscreenCount = allWindows.Count - tiledWindows.Count;
            if (fullscreenCount > 0)
            {
                DiagnosticLogger.Debug("HOTKEYS", $"Layout refresh: excluding {fullscreenCount} fullscreen window(s)");
            }

            var state = _configService.LoadState();
            var positions = _layoutService.CalculateLayout(tiledWindows, state.Layout);

            // Force apply even if Glitch is disabled (display change is always important)
            _layoutService.ApplyLayout(positions, state.Layout, force: true);

            // Update truth positions after layout refresh
            foreach (var pos in positions)
            {
                _truthPositions[pos.Window.Handle] = pos.Target;
            }

            // Reset cooldown to prevent immediate snap-back after manual layout change (BUG-LAYOUT07)
            _lastOverlapReposition = DateTime.Now;

            DiagnosticLogger.Info("HOTKEYS", $"Layout refreshed for {tiledWindows.Count} tiled windows");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("HOTKEYS", $"Layout refresh failed: {ex.Message}");
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _timer.Dispose();
    }
}
