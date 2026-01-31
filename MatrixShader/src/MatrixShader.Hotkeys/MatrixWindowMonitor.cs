using MatrixShader.Core.Services;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Monitors for Matrix windows and triggers exit when none exist.
/// Per CONTEXT.md: "Auto-exits when all Matrix windows close"
/// </summary>
public sealed class MatrixWindowMonitor : IDisposable
{
    private readonly IIdentityService _identityService;
    private readonly Action _onNoWindows;
    private readonly Timer _timer;
    private bool _disposed;

    // Poll interval - check for windows every 2 seconds
    private const int PollIntervalMs = 2000;

    // Grace period - wait a few checks before exiting (handles brief window recreation)
    private int _noWindowCount;

    /// <summary>
    /// Number of consecutive checks with no windows before triggering exit.
    /// At 2 second intervals, this means 6 seconds of no windows before exit.
    /// </summary>
    public const int NoWindowThreshold = 3;

    public MatrixWindowMonitor(IIdentityService identityService, Action onNoWindows)
    {
        _identityService = identityService ?? throw new ArgumentNullException(nameof(identityService));
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
        try
        {
            var windows = _identityService.FindMatrixWindows();

            // Filter out control panel - only count shader windows
            var shaderWindowCount = 0;
            foreach (var window in windows)
            {
                if (!window.IsControlPanel)
                {
                    shaderWindowCount++;
                }
            }

            if (shaderWindowCount == 0)
            {
                _noWindowCount++;
                DiagnosticLogger.Debug("HOTKEYS", $"No shader windows detected ({_noWindowCount}/{NoWindowThreshold})");

                if (_noWindowCount >= NoWindowThreshold)
                {
                    DiagnosticLogger.Info("HOTKEYS", "No Matrix windows for grace period, triggering exit");
                    StopMonitoring();
                    _onNoWindows();
                }
            }
            else
            {
                // Reset counter when windows exist
                if (_noWindowCount > 0)
                {
                    DiagnosticLogger.Debug("HOTKEYS", $"Matrix windows detected ({shaderWindowCount}), resetting counter");
                }
                _noWindowCount = 0;
            }
        }
        catch (Exception ex)
        {
            // Silent failure - keep monitoring
            DiagnosticLogger.Warn("HOTKEYS", $"Window check failed: {ex.Message}");
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _timer.Dispose();
    }
}
