using System.Diagnostics;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Monitor;

/// <summary>
/// Background monitor service for Matrix window management.
/// Detects window drag events and re-applies layout.
/// </summary>
public static class Program
{
    public static async Task Main(string[] args)
    {
        // Single-instance check — exit if another monitor is already running
        if (ProcessCleanup.IsAnotherInstanceRunning())
        {
            return;
        }

        var builder = Host.CreateApplicationBuilder(args);

        builder.Services.AddLogging(logging =>
        {
            logging.SetMinimumLevel(LogLevel.Information);
        });

        builder.Services.AddHostedService<MonitorService>();
        builder.Services.AddSingleton<IConfigService, ConfigService>();

        var host = builder.Build();
        await host.RunAsync();
    }
}

/// <summary>
/// Supervises the matrix-hotkeys.exe process, restarting it on crash.
/// Per BUG-HK01: Hotkeys stop working after 1-2 uses because service crashes silently.
/// </summary>
public sealed class HotkeyWatchdog : IDisposable
{
    private readonly string _hotkeyExePath;
    private readonly ILogger _logger;
    private readonly Timer _timer;
    private Process? _hotkeyProcess;
    private bool _disposed;

    // Health check interval - 5 seconds
    private const int HealthCheckIntervalMs = 5000;

    public HotkeyWatchdog(string hotkeyExePath, ILogger logger)
    {
        _hotkeyExePath = hotkeyExePath;
        _logger = logger;
        _timer = new Timer(CheckHealth, null, Timeout.Infinite, Timeout.Infinite);
    }

    /// <summary>
    /// Starts the watchdog - begins health checks and starts process if not running.
    /// </summary>
    public void Start()
    {
        _logger.LogInformation("Hotkey watchdog starting, monitoring: {Path}", _hotkeyExePath);

        // Initial start
        EnsureProcessRunning();

        // Start periodic health check
        _timer.Change(HealthCheckIntervalMs, HealthCheckIntervalMs);
    }

    /// <summary>
    /// Stops the watchdog and terminates the monitored process.
    /// </summary>
    public void Stop()
    {
        _timer.Change(Timeout.Infinite, Timeout.Infinite);

        if (_hotkeyProcess != null && !_hotkeyProcess.HasExited)
        {
            try
            {
                _hotkeyProcess.Kill();
                _hotkeyProcess.WaitForExit(3000);
                _logger.LogInformation("Hotkey process terminated");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to terminate hotkey process");
            }
        }
    }

    private void CheckHealth(object? state)
    {
        try
        {
            EnsureProcessRunning();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Health check failed");
        }
    }

    private void EnsureProcessRunning()
    {
        bool needsStart = false;
        string reason = "";

        if (_hotkeyProcess == null)
        {
            needsStart = true;
            reason = "initial start";
        }
        else if (_hotkeyProcess.HasExited)
        {
            var exitCode = _hotkeyProcess.ExitCode;
            _hotkeyProcess.Dispose();
            _hotkeyProcess = null;

            if (exitCode == 0)
            {
                // Clean exit (no Matrix windows left) — don't restart
                _logger.LogInformation("Hotkey process exited cleanly (code 0), not restarting");
                return;
            }

            needsStart = true;
            reason = $"crashed (exit code: {exitCode})";
        }

        if (needsStart)
        {
            if (!File.Exists(_hotkeyExePath))
            {
                _logger.LogError("Hotkey executable not found at: {Path}", _hotkeyExePath);
                return;
            }

            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = _hotkeyExePath,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WorkingDirectory = Path.GetDirectoryName(_hotkeyExePath)
                };

                _hotkeyProcess = Process.Start(startInfo);

                if (_hotkeyProcess != null)
                {
                    _logger.LogInformation("Hotkey process {Action}: PID {Pid}",
                        reason == "initial start" ? "started" : "restarted",
                        _hotkeyProcess.Id);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to start hotkey process");
            }
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        Stop();
        _timer.Dispose();
        _hotkeyProcess?.Dispose();
    }
}

/// <summary>
/// Hosted service that monitors Matrix windows for position changes.
/// Also supervises the hotkey background process via HotkeyWatchdog.
/// </summary>
public class MonitorService : BackgroundService
{
    private readonly ILogger<MonitorService> _logger;
    private readonly IConfigService _configService;
    private readonly IHostApplicationLifetime _lifetime;
    private readonly Dictionary<nint, WindowRect> _lastPositions = new();
    private const int PollIntervalMs = 500;
    private const int AutoExitSeconds = 30;
    private HotkeyWatchdog? _hotkeyWatchdog;
    private DateTime? _noWindowsSince;

    public MonitorService(ILogger<MonitorService> logger, IConfigService configService, IHostApplicationLifetime lifetime)
    {
        _logger = logger;
        _configService = configService;
        _lifetime = lifetime;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Matrix Monitor started");

        // Start hotkey watchdog
        var hotkeyPath = FindHotkeyExePath();
        if (hotkeyPath != null)
        {
            _hotkeyWatchdog = new HotkeyWatchdog(hotkeyPath, _logger);
            _hotkeyWatchdog.Start();
        }
        else
        {
            _logger.LogWarning("Hotkey executable not found, watchdog disabled");
        }

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    CheckWindows();

                    // Auto-exit when no Matrix windows for 30 seconds
                    if (_lastPositions.Count == 0)
                    {
                        _noWindowsSince ??= DateTime.UtcNow;
                        if ((DateTime.UtcNow - _noWindowsSince.Value).TotalSeconds >= AutoExitSeconds)
                        {
                            _logger.LogInformation("No Matrix windows for {Seconds}s, shutting down", AutoExitSeconds);
                            _lifetime.StopApplication();
                            break;
                        }
                    }
                    else
                    {
                        _noWindowsSince = null;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error checking windows");
                }

                await Task.Delay(PollIntervalMs, stoppingToken);
            }
        }
        finally
        {
            _hotkeyWatchdog?.Dispose();
        }

        _logger.LogInformation("Matrix Monitor stopped");
    }

    /// <summary>
    /// Finds the path to matrix-hotkeys.exe.
    /// Checks: same directory as monitor, Program Files, LocalAppData.
    /// </summary>
    private static string? FindHotkeyExePath()
    {
        // Path 1: Same directory as matrix-monitor.exe (development/installed)
        var baseDir = AppContext.BaseDirectory;
        var sameDirPath = Path.Combine(baseDir, "matrix-hotkeys.exe");
        if (File.Exists(sameDirPath))
            return sameDirPath;

        // Path 2: Program Files (admin install)
        var programFilesPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "MatrixShader",
            "matrix-hotkeys.exe");
        if (File.Exists(programFilesPath))
            return programFilesPath;

        // Path 3: LocalAppData (non-admin install)
        var localAppDataPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MatrixShader",
            "matrix-hotkeys.exe");
        if (File.Exists(localAppDataPath))
            return localAppDataPath;

        return null;
    }

    private void CheckWindows()
    {
        if (!OperatingSystem.IsWindows())
            return;

        var windows = FindMatrixWindows();

        foreach (var (hwnd, currentPos) in windows)
        {
            if (_lastPositions.TryGetValue(hwnd, out var lastPos))
            {
                // Check if window was moved (user drag)
                if (HasMoved(lastPos, currentPos))
                {
                    _logger.LogDebug("Window {Handle} moved from {Old} to {New}",
                        hwnd, lastPos, currentPos);

                    OnWindowMoved(hwnd, currentPos);
                }
            }
            else
            {
                // New window detected
                _logger.LogInformation("New Matrix window detected: {Handle}", hwnd);
            }

            _lastPositions[hwnd] = currentPos;
        }

        // Clean up closed windows
        var closedWindows = _lastPositions.Keys
            .Where(h => !windows.ContainsKey(h))
            .ToList();

        foreach (var hwnd in closedWindows)
        {
            _logger.LogInformation("Matrix window closed: {Handle}", hwnd);
            _lastPositions.Remove(hwnd);
        }
    }

    private static Dictionary<nint, WindowRect> FindMatrixWindows()
    {
        var result = new Dictionary<nint, WindowRect>();

        var handles = WindowsApi.GetVisibleWindows();

        foreach (var hwnd in handles)
        {
            var title = WindowsApi.GetWindowTitle(hwnd);
            var className = WindowsApi.GetWindowClassName(hwnd);

            // Look for Windows Terminal windows with Matrix in title
            if (className == "CASCADIA_HOSTING_WINDOW_CLASS" &&
                (title.Contains("Matrix", StringComparison.OrdinalIgnoreCase) ||
                 title.Contains("Redpill", StringComparison.OrdinalIgnoreCase)))
            {
                var pos = WindowsApi.GetWindowPosition(hwnd);
                if (pos != null)
                {
                    result[hwnd] = pos;
                }
            }
        }

        return result;
    }

    private static bool HasMoved(WindowRect old, WindowRect current)
    {
        const int Threshold = 5; // Ignore tiny movements

        return Math.Abs(old.Left - current.Left) > Threshold ||
               Math.Abs(old.Top - current.Top) > Threshold ||
               Math.Abs(old.Width - current.Width) > Threshold ||
               Math.Abs(old.Height - current.Height) > Threshold;
    }

    private void OnWindowMoved(nint hwnd, WindowRect newPos)
    {
        // Detect snap to monitor edge
        var monitors = WindowsApi.GetMonitors();

        foreach (var monitor in monitors)
        {
            // Check if snapped to edge
            if (IsNearEdge(newPos.Left, monitor.WorkArea.Left) ||
                IsNearEdge(newPos.Top, monitor.WorkArea.Top) ||
                IsNearEdge(newPos.Right, monitor.WorkArea.Right) ||
                IsNearEdge(newPos.Bottom, monitor.WorkArea.Bottom))
            {
                _logger.LogInformation("Window snapped to monitor {Index} edge", monitor.Index);
                // Could trigger layout recalculation here
            }
        }
    }

    private static bool IsNearEdge(int position, int edge)
    {
        const int SnapThreshold = 20;
        return Math.Abs(position - edge) < SnapThreshold;
    }
}
