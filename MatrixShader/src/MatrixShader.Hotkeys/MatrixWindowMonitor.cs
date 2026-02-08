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

            // Filter out control panel - only count shader windows
            var shaderWindows = new List<WindowInfo>();
            foreach (var window in windows)
            {
                if (!window.IsControlPanel)
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
    /// </summary>
    private void CheckForOverlap(List<WindowInfo> windows)
    {
        // Skip if we don't have layout service
        if (_layoutService == null || _configService == null)
            return;

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

        // Filter out fullscreen windows - only check tiled windows for overlap
        // This prevents F11 fullscreen windows from triggering snap-back (BUG-LAYOUT06)
        var tiledWindows = new List<WindowInfo>();
        foreach (var window in windows)
        {
            if (!WindowsApi.IsZoomed(window.Handle))
            {
                tiledWindows.Add(window);
            }
        }

        var fullscreenCount = windows.Count - tiledWindows.Count;
        if (fullscreenCount > 0)
        {
            DiagnosticLogger.Debug("HOTKEYS", $"Excluding {fullscreenCount} fullscreen window(s) from glitch detection");
        }

        // Skip if less than 2 tiled windows remain
        if (tiledWindows.Count < 2)
            return;

        // Check for overlap between any two tiled windows
        bool hasOverlap = false;
        for (int i = 0; i < tiledWindows.Count && !hasOverlap; i++)
        {
            for (int j = i + 1; j < tiledWindows.Count && !hasOverlap; j++)
            {
                var overlapArea = CalculateOverlapArea(tiledWindows[i].Position, tiledWindows[j].Position);
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
                // Only reposition tiled windows, leave fullscreen alone
                var positions = _layoutService.CalculateLayout(tiledWindows, state.Layout);
                _layoutService.ApplyLayout(positions, state.Layout, force: true);
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Warn("HOTKEYS", $"Auto-reposition failed: {ex.Message}");
            }
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
                .Where(w => !w.IsControlPanel)
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
