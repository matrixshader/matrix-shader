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
        // Top-level exception handler - log crashes before exit
        AppDomain.CurrentDomain.UnhandledException += (s, e) =>
        {
            DiagnosticLogger.Error("HOTKEYS", $"Unhandled exception: {e.ExceptionObject}");
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
            DiagnosticLogger.Error("HOTKEYS", $"Fatal error in Run(): {ex}");
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
            if (hotkeyIdToHandler.TryGetValue(id, out var handler))
            {
                try
                {
                    handler();
                }
                catch (Exception ex)
                {
                    DiagnosticLogger.Warn("HOTKEYS", $"Action handler failed: {ex.Message}");
                    // Fail silently - keep running
                }
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
