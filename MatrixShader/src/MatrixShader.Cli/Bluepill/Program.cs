using System.Diagnostics;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Core.Startup;
using MatrixShader.Lite;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.Bluepill;

/// <summary>
/// Bluepill - Quick session restore for Matrix Shader.
/// "Straight into the Matrix Shader, Coppertop!"
/// </summary>
public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        // Skip splash for help
        if (!args.Contains("--help"))
        {
            await MatrixSplash.ShowAsync();
        }

        try
        {
            // Parse arguments
            var options = CliBootstrap.ParseArgs(args);

            if (options.ShowHelp)
            {
                ShowHelp();
                return 0;
            }

            // Bootstrap
            var bootstrap = await CliBootstrap.InitializeAsync(verbose: options.Debug);
            if (!bootstrap.Success)
            {
                ConsoleHelper.WriteLineMatrixGreen($"Error: {bootstrap.ErrorMessage}");
                return 1;
            }

            // Set up DI
            var services = new ServiceCollection();
            ConfigureServices(services);
            var provider = services.BuildServiceProvider();

            var restorer = provider.GetRequiredService<SessionRestorer>();

            // Show header and random quote
            Console.WriteLine();
            ConsoleHelper.WriteLineMatrixGreen(" BLUEPILL - Enter the Matrix");
            ConsoleHelper.WriteLineDim(" ----------------------------");
            Console.WriteLine();
            CliBootstrap.ShowRandomQuote();

            // Detect render mode
            var envService = provider.GetRequiredService<EnvironmentService>();
            var mode = envService.DetectRenderMode();

            if (mode == RenderMode.Lite)
            {
                // Lite mode - use text-based Matrix rain
                Console.WriteLine();
                ConsoleHelper.WriteLineMatrixGreen(" LITE MODE - No Windows Terminal detected");
                ConsoleHelper.WriteLineDim(" Running text-based Matrix rain...");
                Console.WriteLine();

                var menu = new FallbackMenu();
                await menu.RunAsync(CancellationToken.None);
                return 0;
            }
            else if (mode == RenderMode.Headless)
            {
                Console.WriteLine("\x1b[31mNo display available. Use --help for options.\x1b[0m");
                return 1;
            }

            // Full mode continues with session restore...

            // Morpheus mode: philosophical intro
            if (options.Morpheus)
            {
                await ShowMorpheusIntro();
            }

            // Run session restore
            var result = await restorer.RestoreSessionAsync();

            if (!result.Success)
            {
                ConsoleHelper.WriteLineMatrixGreen($" Error: {result.ErrorMessage}");
                return 1;
            }

            // Start background monitor for drag-snap functionality
            StartMonitorProcess();

            // Launch hotkeys background process
            LaunchHotkeysProcess();

            // Theatrical ending: "There is no spoon..."
            Console.WriteLine();
            await CliBootstrap.TypewriterAsync(" There is no spoon...", charDelayMs: 150);
            Console.WriteLine();

            // Wait for any key
            ConsoleHelper.WriteLineDim(" Press any key to exit...");
            Console.ReadKey(intercept: true);

            return 0;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("BLUEPILL", $"Unhandled exception: {ex.Message}");
            MatrixErrorHandler.ShowError(ex.Message);
            return 1;
        }
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" BLUEPILL - Straight into the Matrix Shader, Coppertop!");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Usage: bluepill [options]");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Options:");
        ConsoleHelper.WriteLineDim("   --help       Show this help message");
        ConsoleHelper.WriteLineDim("   --debug      Enable diagnostic logging");
        ConsoleHelper.WriteLineDim("   --morpheus   Philosophical explanations");
        ConsoleHelper.WriteLineDim("   --agent-smith  Chaos mode");
        Console.WriteLine();
    }

    private static async Task ShowMorpheusIntro()
    {
        await CliBootstrap.TypewriterAsync(" Let me tell you why you're here...", 100);
        await Task.Delay(500);
        await CliBootstrap.TypewriterAsync(" You're here because you know something.", 80);
        await Task.Delay(300);
        await CliBootstrap.TypewriterAsync(" What you know, you can't explain.", 80);
        await Task.Delay(300);
        await CliBootstrap.TypewriterAsync(" But you feel it.", 80);
        await Task.Delay(500);
        Console.WriteLine();
    }

    private static void StartMonitorProcess()
    {
        // Primary: installed name from installer
        var monitorPath = Path.Combine(AppContext.BaseDirectory, "matrix-monitor.exe");
        DiagnosticLogger.Info("BLUEPILL", $"Looking for monitor at: {monitorPath}");

        // Legacy fallback for older installations or development
        if (!File.Exists(monitorPath))
        {
            monitorPath = Path.Combine(AppContext.BaseDirectory, "MatrixShader.Monitor.exe");
        }

        if (File.Exists(monitorPath))
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = monitorPath,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    UseShellExecute = true
                };
                Process.Start(psi);
                DiagnosticLogger.Info("BLUEPILL", "Started background monitor");
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Warn("BLUEPILL", $"Failed to start monitor: {ex.Message}");
            }
        }
        else
        {
            DiagnosticLogger.Info("BLUEPILL", "Monitor executable not found, skipping");
        }
    }

    /// <summary>
    /// Launches the hotkeys background process if not already running.
    /// </summary>
    private static void LaunchHotkeysProcess()
    {
        try
        {
            // Find matrix-hotkeys.exe relative to current executable
            var exeDir = AppContext.BaseDirectory;
            var hotkeyExe = Path.Combine(exeDir, "matrix-hotkeys.exe");

            if (!File.Exists(hotkeyExe))
            {
                // Try parent directory (development layout)
                var parentDir = Directory.GetParent(exeDir)?.FullName;
                if (parentDir != null)
                {
                    hotkeyExe = Path.Combine(parentDir, "MatrixShader.Hotkeys", "matrix-hotkeys.exe");
                }
            }

            if (!File.Exists(hotkeyExe))
            {
                DiagnosticLogger.Debug("BLUEPILL", "matrix-hotkeys.exe not found, skipping hotkey launch");
                return;
            }

            // Start as hidden background process
            var startInfo = new ProcessStartInfo
            {
                FileName = hotkeyExe,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            Process.Start(startInfo);
            DiagnosticLogger.Debug("BLUEPILL", $"Launched hotkeys process: {hotkeyExe}");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("BLUEPILL", $"Failed to launch hotkeys: {ex.Message}");
            // Non-fatal - Matrix works without hotkeys
        }
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddLogging(builder =>
        {
            builder.SetMinimumLevel(LogLevel.Warning);
        });

        // Core services
        services.AddSingleton<EnvironmentService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<IIdentityService, IdentityService>();
        services.AddSingleton<ILayoutService, LayoutService>();
        services.AddSingleton<ITerminalSettingsService, TerminalSettingsService>();

        // Bluepill-specific
        services.AddSingleton<SessionRestorer>();
    }
}

/// <summary>
/// Result of session restore operation.
/// </summary>
public record RestoreResult(
    bool Success,
    string? ErrorMessage = null,
    int WindowsLaunched = 0,
    int WindowsAlreadyOpen = 0);

/// <summary>
/// Restores previous Matrix session.
/// </summary>
public class SessionRestorer
{
    private readonly IConfigService _configService;
    private readonly IShaderService _shaderService;
    private readonly IIdentityService _identityService;
    private readonly ILayoutService _layoutService;
    private readonly ILogger<SessionRestorer> _logger;

    public SessionRestorer(
        IConfigService configService,
        IShaderService shaderService,
        IIdentityService identityService,
        ILayoutService layoutService,
        ILogger<SessionRestorer> logger)
    {
        _configService = configService;
        _shaderService = shaderService;
        _identityService = identityService;
        _layoutService = layoutService;
        _logger = logger;
    }

    public async Task<RestoreResult> RestoreSessionAsync()
    {
        DiagnosticLogger.Info("BLUEPILL", "Starting session restore");

        // Load saved state
        var state = _configService.LoadState();
        var slots = GetActiveSlots(state);

        if (slots.Count == 0)
        {
            // First run: launch single green window
            DiagnosticLogger.Info("BLUEPILL", "First run - launching single green window");
            ConsoleHelper.WriteLineMatrixGreen(" First time? Creating your Matrix...");
            slots = new List<int> { 1 };

            // Ensure default green shader exists
            if (!_shaderService.ShaderExists(1))
            {
                _shaderService.CreateShader(1, new ShaderConfig());
                ConsoleHelper.WriteLineDim("   Created Matrix-1 shader (classic green)");
            }
        }

        ConsoleHelper.WriteLineDim($" Restoring slots [{string.Join(", ", slots)}]");
        Console.WriteLine();

        // Check for existing windows
        ConsoleHelper.WriteMatrixGreen(" Checking for existing windows...");
        Console.WriteLine();

        _identityService.CleanStaleEntries();
        _identityService.LoadRegistry();

        var existingWindows = _identityService.FindMatrixWindows();
        var openSlots = new HashSet<int>(existingWindows.Select(w => w.ShaderIndex));

        foreach (var slot in openSlots.Intersect(slots))
        {
            ConsoleHelper.WriteLineDim($"   Slot {slot} already open");
        }

        // Launch missing windows
        ConsoleHelper.WriteMatrixGreen(" Launching windows...");
        Console.WriteLine();

        int launched = 0;
        int alreadyOpen = openSlots.Count;

        foreach (var slot in slots)
        {
            if (openSlots.Contains(slot))
            {
                ConsoleHelper.WriteLineDim($"   Matrix-{slot} - already open, skipping");
                continue;
            }

            var profileName = $"Matrix-{slot}";
            Console.Write($"   Waiting for {profileName}...");

            // Capture existing handles before launch
            var existingHandles = GetExistingWindowHandles();

            // Launch via wt.exe
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "wt.exe",
                    Arguments = $"-p \"{profileName}\"",
                    UseShellExecute = true
                };
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                ConsoleHelper.WriteLineDim($" FAILED ({ex.Message})");
                DiagnosticLogger.Error("BLUEPILL", $"Failed to launch {profileName}: {ex.Message}");
                continue;
            }

            // Wait for new window to appear
            var newHandle = await WaitForNewWindowAsync(profileName, existingHandles);

            if (newHandle != IntPtr.Zero)
            {
                // Register the new window
                _identityService.RegisterWindowHandle(newHandle, profileName, slot);
                ConsoleHelper.WriteLineMatrixGreen(" OK");
                launched++;
            }
            else
            {
                ConsoleHelper.WriteLineDim(" TIMEOUT");
            }
        }

        if (launched == 0 && alreadyOpen > 0)
        {
            ConsoleHelper.WriteLineDim("   All windows already open");
        }

        // Position windows
        Console.WriteLine();
        ConsoleHelper.WriteMatrixGreen(" Positioning windows...");
        Console.WriteLine();

        await Task.Delay(500); // Let windows initialize

        // Refresh window list
        var allWindows = _identityService.FindMatrixWindows();

        if (allWindows.Count > 0)
        {
            // Try to restore saved positions first
            if (TryRestoreSavedPositions(allWindows, state))
            {
                ConsoleHelper.WriteLineDim($"   Restored {allWindows.Count} windows to saved positions");
            }
            else
            {
                // Fall back to layout engine
                var layoutConfig = state.Layout;
                var positions = _layoutService.CalculateLayout(allWindows, layoutConfig);
                _layoutService.ApplyLayout(positions);
                ConsoleHelper.WriteLineDim($"   Positioned {allWindows.Count} windows using layout engine");
            }
        }
        else
        {
            ConsoleHelper.WriteLineDim("   No Matrix windows detected");
        }

        // Save registry
        _identityService.SaveRegistry();

        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" THE MATRIX HAS YOU.");
        ConsoleHelper.WriteLineDim(" Type 'redpill' to customize.");

        DiagnosticLogger.Info("BLUEPILL", $"Session restore complete: {launched} launched, {alreadyOpen} already open");

        return new RestoreResult(true, WindowsLaunched: launched, WindowsAlreadyOpen: alreadyOpen);
    }

    private List<int> GetActiveSlots(MatrixState state)
    {
        // Get slots that have shader configs
        if (state.ShaderConfigs == null || state.ShaderConfigs.Count == 0)
            return new List<int>();

        // Return only slots where shader files actually exist
        return state.ShaderConfigs.Keys
            .Where(k => _shaderService.ShaderExists(k))
            .OrderBy(k => k)
            .ToList();
    }

    private HashSet<nint> GetExistingWindowHandles()
    {
        var handles = new HashSet<nint>();
        var windows = _identityService.FindMatrixWindows();
        foreach (var w in windows)
        {
            handles.Add(w.Handle);
        }
        return handles;
    }

    private async Task<nint> WaitForNewWindowAsync(string profileName, HashSet<nint> existingHandles)
    {
        // Poll for new window (100ms intervals, 5s timeout)
        const int maxAttempts = 50;
        const int pollIntervalMs = 100;

        for (int i = 0; i < maxAttempts; i++)
        {
            await Task.Delay(pollIntervalMs);

            var currentWindows = _identityService.FindMatrixWindows();
            foreach (var window in currentWindows)
            {
                if (!existingHandles.Contains(window.Handle))
                {
                    DiagnosticLogger.Debug("BLUEPILL", $"New window detected: {window.Handle}");
                    return window.Handle;
                }
            }
        }

        DiagnosticLogger.Warn("BLUEPILL", $"Timeout waiting for {profileName}");
        return IntPtr.Zero;
    }

    private bool TryRestoreSavedPositions(IReadOnlyList<WindowInfo> windows, MatrixState state)
    {
        // Check if we have saved window slots/positions
        if (state.WindowSlots == null || state.WindowSlots.Count == 0)
            return false;

        // Try to use the layout service's slot-based positioning
        var positions = _layoutService.LoadWindowSlots(windows);
        if (positions.Count > 0)
        {
            _layoutService.ApplyLayout(positions);
            return true;
        }

        return false;
    }
}
