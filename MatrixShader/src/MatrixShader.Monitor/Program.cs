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
/// Hosted service that monitors Matrix windows for position changes.
/// </summary>
public class MonitorService : BackgroundService
{
    private readonly ILogger<MonitorService> _logger;
    private readonly IConfigService _configService;
    private readonly Dictionary<nint, WindowRect> _lastPositions = new();
    private const int PollIntervalMs = 500;

    public MonitorService(ILogger<MonitorService> logger, IConfigService configService)
    {
        _logger = logger;
        _configService = configService;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Matrix Monitor started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                CheckWindows();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking windows");
            }

            await Task.Delay(PollIntervalMs, stoppingToken);
        }

        _logger.LogInformation("Matrix Monitor stopped");
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
