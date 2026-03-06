using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Matrix Hotkeys - Background process for system-wide keyboard shortcuts.
///
/// Lifecycle:
/// - Launched from bluepill/redpill/wakeupneo (not Windows login)
/// - Single instance enforced via named mutex
/// - Auto-exits when no Matrix windows exist
/// - Silent operation - no console window, no tray icon
/// </summary>
public static class Program
{
    public static int Main(string[] args)
    {
        // Handle --help-overlay: show help in this console window and exit
        if (args.Contains("--help-overlay"))
        {
            HotkeyHelpOverlay.Show();
            return 0;
        }

        // Initialize diagnostic logging (reads MATRIX_DEBUG env var or --debug flag)
        DiagnosticLogger.Initialize(args.Contains("--debug"));

        // Top-level exception handler - ALWAYS log crashes (even without MATRIX_DEBUG)
        AppDomain.CurrentDomain.UnhandledException += (s, e) =>
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"Unhandled exception: {e.ExceptionObject}");
        };

        // Single-instance check - exit silently if already running
        using var singleInstance = new SingleInstance();
        if (!singleInstance.TryAcquire())
        {
            return 0; // Another instance running - success (not an error)
        }

        try
        {
            return Run();
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"Fatal error in Run(): {ex}");
            return 1;
        }
        finally
        {
            ToastNotifications.Cleanup();
        }
    }

    private static int Run()
    {
        // Set up DI container
        var services = new ServiceCollection();
        ConfigureServices(services);
        using var provider = services.BuildServiceProvider();

        // Load hotkey configuration
        var configService = provider.GetRequiredService<IHotkeyConfigService>();
        var config = configService.LoadConfig();

        // Get services needed for hotkey actions
        var actions = provider.GetRequiredService<HotkeyActions>();

        // Create hidden window for message pump
        using var hotkeyWindow = new HotkeyWindow();
        if (!hotkeyWindow.Create())
        {
            DiagnosticLogger.Error("HOTKEYS", "Failed to create message window");
            return 1; // Failed to create window
        }

        // Create OSD overlay on message loop thread (same thread as HotkeyWindow)
        using var osdOverlay = new OsdOverlay();
        osdOverlay.Create();
        actions.SetOsd(osdOverlay);

        // Create hotkey manager
        using var hotkeyManager = new HotkeyManager(hotkeyWindow.Handle);

        // Map hotkey IDs to action handlers
        var hotkeyIdToHandler = new Dictionary<int, Action>();

        // Register all enabled hotkeys from config
        foreach (var (action, binding) in config.Bindings)
        {
            if (binding.Enabled)
            {
                var hotkeyId = hotkeyManager.RegisterHotkey(binding.Modifiers, binding.VirtualKey, binding.DisplayName);
                if (hotkeyId > 0)
                {
                    // Store the handler for this hotkey ID
                    hotkeyIdToHandler[hotkeyId] = actions.GetHandler(action);
                }
            }
        }

        // Wire up event handler to dispatch to correct action
        hotkeyWindow.HotkeyPressed += (id, modifiers, vk) =>
        {
            DiagnosticLogger.Debug("HOTKEYS", $"Dispatching hotkey id={id}");
            if (hotkeyIdToHandler.TryGetValue(id, out var handler))
            {
                try
                {
                    handler();
                    DiagnosticLogger.Debug("HOTKEYS", $"Handler completed for id={id}");
                }
                catch (Exception ex)
                {
                    DiagnosticLogger.Warn("HOTKEYS", $"Action handler failed: {ex.Message}");
                    // Fail silently - keep running
                }
            }
            else
            {
                DiagnosticLogger.Warn("HOTKEYS", $"No handler found for hotkey id={id}");
            }
        };

        // Show toast if any hotkeys failed to register
        var failed = hotkeyManager.GetFailedHotkeys();
        if (failed.Count > 0)
        {
            ToastNotifications.ShowConflictWarning(failed);
        }

        DiagnosticLogger.Info("HOTKEYS", $"Registered {hotkeyManager.RegisteredCount}/{config.Bindings.Count} hotkeys");

        // Start window monitor (auto-exit when no Matrix windows + Glitch overlap detection)
        var identityService = provider.GetRequiredService<IIdentityService>();
        var layoutService = provider.GetRequiredService<ILayoutService>();
        var coreConfigService = provider.GetRequiredService<IConfigService>();
        using var monitor = new MatrixWindowMonitor(identityService, layoutService, coreConfigService, hotkeyWindow.Stop);
        monitor.StartMonitoring();

        // Auto-show help overlay on first launch
        var state = coreConfigService.LoadState();
        if (!state.HelpShownOnce)
        {
            HotkeyHelpOverlay.SpawnOverlay();
            coreConfigService.SaveState(state with { HelpShownOnce = true });
        }

        // Subscribe to display changes for auto-repositioning
        hotkeyWindow.DisplayChanged += (bpp, width, height) =>
        {
            // Trigger layout refresh on a small delay to let Windows settle
            Task.Delay(500).ContinueWith(_ => monitor.TriggerLayoutRefresh());
        };

        // Run message loop (blocks until Stop() called)
        hotkeyWindow.RunMessageLoop();

        DiagnosticLogger.Info("HOTKEYS", "Message loop exited, shutting down");

        return 0;
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        // Logging (minimal for background process)
        services.AddLogging(builder => builder
            .SetMinimumLevel(LogLevel.Warning)
            .AddFilter("MatrixShader", LogLevel.Warning));

        // Core services
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<ILayoutService, LayoutService>();
        services.AddSingleton<IIdentityService, IdentityService>();
        services.AddSingleton<ITerminalSettingsService, TerminalSettingsService>();
        services.AddSingleton<IHotkeyConfigService, HotkeyConfigService>();

        // Hotkey actions
        services.AddSingleton<HotkeyActions>();
    }
}
