using System.Diagnostics;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Core.Startup;
using MatrixShader.Lite;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// Matrix Shader Control Panel - Full TUI with shader control.
/// </summary>
public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        // Skip splash for help or hotkeys config mode
        if (!args.Contains("--help") && !args.Contains("--hotkeys"))
        {
            await MatrixSplash.ShowAsync();
        }

        try
        {
            // Check for hotkey config mode (early exit, minimal DI)
            if (args.Contains("--hotkeys"))
            {
                var hotkeyServices = new ServiceCollection();
                hotkeyServices.AddLogging(b => b.SetMinimumLevel(LogLevel.Warning));
                hotkeyServices.AddSingleton<IHotkeyConfigService, HotkeyConfigService>();
                var hotkeyProvider = hotkeyServices.BuildServiceProvider();

                var configScreen = new HotkeyConfigScreen(
                    hotkeyProvider.GetRequiredService<IHotkeyConfigService>());
                configScreen.Run();
                return 0;
            }

            // Parse arguments
            var options = CliBootstrap.ParseArgs(args);

            if (options.ShowHelp)
            {
                ShowHelp();
                return 0;
            }

            if (options.Debug)
            {
                DiagnosticLogger.Initialize(true);
            }

            // Setup DI
            var services = new ServiceCollection();
            ConfigureServices(services);
            var provider = services.BuildServiceProvider();

            var logger = provider.GetRequiredService<ILogger<ControlPanel>>();
            var envService = provider.GetRequiredService<EnvironmentService>();

            // Bootstrap initialization
            var bootstrap = await CliBootstrap.InitializeAsync(verbose: options.Debug);
            if (!bootstrap.Success)
            {
                ConsoleHelper.WriteLineMatrixGreen($"Error: {bootstrap.ErrorMessage}");
                return 1;
            }

            // Detect render mode
            var mode = envService.DetectRenderMode();

            logger.LogInformation("Starting Matrix Shader in {Mode} mode", mode);

            // Show random quote
            CliBootstrap.ShowRandomQuote();
            Console.WriteLine();

            if (mode == RenderMode.Full)
            {
                // Full mode with shader control
                var panel = provider.GetRequiredService<ControlPanel>();
                await panel.RunAsync();
            }
            else if (mode == RenderMode.Lite)
            {
                // Lite mode with text renderer
                var menu = new FallbackMenu();
                await menu.RunAsync(CancellationToken.None);
            }
            else
            {
                Console.WriteLine("\x1b[31mNo display available. Use --help for options.\x1b[0m");
                return 1;
            }

            return 0;
        }
        catch (Exception ex)
        {
            var logger = new ServiceCollection()
                .AddLogging(builder => builder.SetMinimumLevel(LogLevel.Information))
                .BuildServiceProvider()
                .GetRequiredService<ILogger<ControlPanel>>();

            logger.LogError(ex, "Unhandled exception");
            MatrixErrorHandler.ShowError(ex.Message);
            return 1;
        }
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddLogging(builder =>
        {
            builder.SetMinimumLevel(LogLevel.Information);
            builder.AddSimpleConsole(options =>
            {
                options.SingleLine = true;
                options.TimestampFormat = "HH:mm:ss ";
            });
        });

        // Core services
        services.AddSingleton<EnvironmentService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<IIdentityService, IdentityService>();
        services.AddSingleton<ILayoutService, LayoutService>();
        services.AddSingleton<ITerminalSettingsService, TerminalSettingsService>();
        services.AddSingleton<IHotkeyConfigService, HotkeyConfigService>();

        // TUI components
        services.AddSingleton<TabManager>();
        services.AddSingleton<ControlPanel>();
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" REDPILL - Matrix Shader Control Panel");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Usage: redpill [options]");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Options:");
        ConsoleHelper.WriteLineDim("   --help       Show this help message");
        ConsoleHelper.WriteLineDim("   --hotkeys    Configure global hotkey bindings");
        ConsoleHelper.WriteLineDim("   --debug      Enable diagnostic logging");
        ConsoleHelper.WriteLineDim("   --morpheus   Philosophical explanations");
        ConsoleHelper.WriteLineDim("   --agent-smith  Chaos mode");
        Console.WriteLine();
    }
}

/// <summary>
/// Full-featured control panel for shader mode.
/// Uses blocking input and pixel-perfect rendering matching PowerShell.
/// </summary>
public class ControlPanel
{
    private readonly IShaderService _shaderService;
    private readonly IConfigService _configService;
    private readonly IIdentityService _identityService;
    private readonly ILayoutService _layoutService;
    private readonly ITerminalSettingsService _terminalSettingsService;
    private readonly IHotkeyConfigService _hotkeyConfigService;
    private readonly ILogger<ControlPanel> _logger;
    private readonly TabManager _tabManager;

    private bool _running = true;
    private int _launchCount = 0;
    private bool _transparency = false;
    private int _opacity = 100;

    public ControlPanel(
        IShaderService shaderService,
        IConfigService configService,
        IIdentityService identityService,
        ILayoutService layoutService,
        ITerminalSettingsService terminalSettingsService,
        IHotkeyConfigService hotkeyConfigService,
        TabManager tabManager,
        ILogger<ControlPanel> logger)
    {
        _shaderService = shaderService;
        _configService = configService;
        _identityService = identityService;
        _layoutService = layoutService;
        _terminalSettingsService = terminalSettingsService;
        _hotkeyConfigService = hotkeyConfigService;
        _tabManager = tabManager;
        _logger = logger;

        // Clean stale registry entries on startup
        _identityService.CleanStaleEntries();
        _identityService.LoadRegistry();
    }

    public Task RunAsync()
    {
        Console.CursorVisible = false;
        Console.Clear();

        try
        {
            while (_running)
            {
                Render();
                var key = Console.ReadKey(intercept: true); // Blocking input
                HandleKey(key);
            }
        }
        finally
        {
            // Save state on exit
            _tabManager.SaveState();
            _identityService.SaveRegistry();

            Console.CursorVisible = true;
            Console.Clear();
        }

        return Task.CompletedTask;
    }

    private void Render()
    {
        Console.SetCursorPosition(0, 0);

        var config = _tabManager.CurrentConfig;

        // Header with dirty indicator
        Console.WriteLine();
        TuiRenderer.WriteHeader(_tabManager.CurrentSlot, _tabManager.IsDirty);

        // Tab bar
        var tabs = _tabManager.GetTabsForRendering();
        TuiRenderer.WriteTabBar(tabs, _tabManager.CurrentSlot);
        Console.WriteLine(" [TAB] next tab");
        Console.WriteLine();

        // Color presets
        TuiRenderer.WriteSectionHeader("COLOR PRESETS");
        TuiRenderer.WriteColorPresets();
        Console.WriteLine();

        // Current color with swatch
        Console.Write($" CURRENT {TuiRenderer.ColorSwatch(config.R, config.G, config.B, 3)}");
        Console.WriteLine();
        TuiRenderer.WriteParameterRow("Q/W", "Red", config.R.ToString("F1"), config.R, 0, 1);
        TuiRenderer.WriteParameterRow("A/S", "Green", config.G.ToString("F1"), config.G, 0, 1);
        TuiRenderer.WriteParameterRow("Z/X", "Blue", config.B.ToString("F1"), config.B, 0, 1);
        Console.WriteLine();

        // Rain effects
        TuiRenderer.WriteSectionHeader("RAIN EFFECTS");
        TuiRenderer.WriteParameterRow("E/R", "Speed", config.Speed.ToString("F1"), config.Speed, 0.1f, 3f);
        TuiRenderer.WriteParameterRow("D/F", "Glow", config.Glow.ToString("F1"), config.Glow, 0.2f, 3f);
        TuiRenderer.WriteParameterRow("C/V", "Width", config.Width.ToString("F0"), config.Width, 6f, 20f);
        TuiRenderer.WriteParameterRow("T/Y", "Trail", config.Trail.ToString("F0"), config.Trail, 4f, 15f);
        TuiRenderer.WriteParameterRow("G/H", "Density", config.Density.ToString("F1"), config.Density, 0.2f, 1f);
        Console.WriteLine();

        // Layers
        TuiRenderer.WriteSectionHeader("LAYERS");
        Console.Write(" ");
        TuiRenderer.WriteLayerStatus("7", "Far", config.Layer1);
        Console.Write("  ");
        TuiRenderer.WriteLayerStatus("8", "Mid", config.Layer2);
        Console.Write("  ");
        TuiRenderer.WriteLayerStatus("9", "Near", config.Layer3);
        Console.WriteLine();
        Console.WriteLine();

        // Window effects
        Console.WriteLine($" \x1b[36mWINDOW EFFECTS\x1b[0m");
        var transStatus = _transparency ? "ON " : "off";
        var transColor = _transparency ? "\x1b[36m" : "\x1b[90m";
        Console.WriteLine($" [B] Transparency:  {transColor}{transStatus}\x1b[0m  \x1b[90m(toggles & applies)\x1b[0m");
        if (_transparency)
        {
            Console.WriteLine($" [K/L] Opacity:     {_opacity,3}% {TuiRenderer.ProgressBar(_opacity, 0, 100)}");
        }

        // Layout mode
        var state = _configService.LoadState();
        var layoutMode = state.Layout.Mode;
        var layoutColor = layoutMode.Equals("pillars", StringComparison.OrdinalIgnoreCase) ? "\x1b[33m" : "\x1b[35m";
        Console.WriteLine($" [Shift+L] Layout:  {layoutColor}{layoutMode}\x1b[0m  \x1b[90m(Pillars=columns, Quads=2x2)\x1b[0m");
        Console.WriteLine();

        // Launch section
        Console.WriteLine($" \x1b[35mLAUNCH\x1b[0m");
        var openWindows = _identityService.FindMatrixWindows();
        var openStr = openWindows.Count > 0
            ? string.Join(",", openWindows.Select(w => w.ShaderIndex))
            : "none";
        Console.WriteLine($" \x1b[90mOpen:\x1b[0m \x1b[32m{openStr}\x1b[0m");

        var launchStatus = _launchCount > 0 ? $"{_launchCount} window(s)" : "disabled";
        var launchColor = _launchCount > 0 ? "\x1b[35m" : "\x1b[90m";
        Console.WriteLine($" [-/+] Count: {launchColor}{launchStatus}\x1b[0m");
        Console.WriteLine();

        // Footer
        TuiRenderer.WriteFooter(_launchCount, _launchCount > 0);
    }

    private void HandleKey(ConsoleKeyInfo key)
    {
        var action = KeyHandler.ProcessKey(key);
        var config = _tabManager.CurrentConfig;

        switch (action)
        {
            case KeyAction.Tab:
                _tabManager.SwitchToNextTab();
                break;

            case KeyAction.Quit:
                _running = false;
                break;

            // Color presets
            case KeyAction.PresetGreen:
                _tabManager.UpdateConfig(config.WithColor(0f, 1f, 0.3f));
                break;
            case KeyAction.PresetCyan:
                _tabManager.UpdateConfig(config.WithColor(0f, 0.6f, 1f));
                break;
            case KeyAction.PresetRed:
                _tabManager.UpdateConfig(config.WithColor(1f, 0.1f, 0.1f));
                break;
            case KeyAction.PresetPurple:
                _tabManager.UpdateConfig(config.WithColor(0.7f, 0f, 1f));
                break;
            case KeyAction.PresetGold:
                _tabManager.UpdateConfig(config.WithColor(1f, 0.7f, 0f));
                break;
            case KeyAction.PresetTeal:
                _tabManager.UpdateConfig(config.WithColor(0f, 0.9f, 0.9f));
                break;

            // RGB adjustments
            case KeyAction.RedDecrease:
                _tabManager.UpdateConfig(config with { R = config.R - 0.05f });
                break;
            case KeyAction.RedIncrease:
                _tabManager.UpdateConfig(config with { R = config.R + 0.05f });
                break;
            case KeyAction.GreenDecrease:
                _tabManager.UpdateConfig(config with { G = config.G - 0.05f });
                break;
            case KeyAction.GreenIncrease:
                _tabManager.UpdateConfig(config with { G = config.G + 0.05f });
                break;
            case KeyAction.BlueDecrease:
                _tabManager.UpdateConfig(config with { B = config.B - 0.05f });
                break;
            case KeyAction.BlueIncrease:
                _tabManager.UpdateConfig(config with { B = config.B + 0.05f });
                break;

            // Effects
            case KeyAction.SpeedDecrease:
                _tabManager.UpdateConfig(config with { Speed = config.Speed - 0.1f });
                break;
            case KeyAction.SpeedIncrease:
                _tabManager.UpdateConfig(config with { Speed = config.Speed + 0.1f });
                break;
            case KeyAction.GlowDecrease:
                _tabManager.UpdateConfig(config with { Glow = config.Glow - 0.1f });
                break;
            case KeyAction.GlowIncrease:
                _tabManager.UpdateConfig(config with { Glow = config.Glow + 0.1f });
                break;
            case KeyAction.WidthDecrease:
                _tabManager.UpdateConfig(config with { Width = config.Width - 1f });
                break;
            case KeyAction.WidthIncrease:
                _tabManager.UpdateConfig(config with { Width = config.Width + 1f });
                break;
            case KeyAction.TrailDecrease:
                _tabManager.UpdateConfig(config with { Trail = config.Trail - 0.5f });
                break;
            case KeyAction.TrailIncrease:
                _tabManager.UpdateConfig(config with { Trail = config.Trail + 0.5f });
                break;
            case KeyAction.DensityDecrease:
                _tabManager.UpdateConfig(config with { Density = config.Density - 0.1f });
                break;
            case KeyAction.DensityIncrease:
                _tabManager.UpdateConfig(config with { Density = config.Density + 0.1f });
                break;

            // Layers
            case KeyAction.Layer1Toggle:
                _tabManager.UpdateConfig(config with { Layer1 = !config.Layer1 });
                break;
            case KeyAction.Layer2Toggle:
                _tabManager.UpdateConfig(config with { Layer2 = !config.Layer2 });
                break;
            case KeyAction.Layer3Toggle:
                _tabManager.UpdateConfig(config with { Layer3 = !config.Layer3 });
                break;

            // Transparency
            case KeyAction.TransparencyToggle:
                _transparency = !_transparency;
                ApplyOpacityToProfile(_transparency ? _opacity : 100);
                break;
            case KeyAction.OpacityDecrease:
                if (_transparency && _opacity > 0)
                {
                    _opacity -= 5;
                    ApplyOpacityToProfile(_opacity);
                }
                break;
            case KeyAction.OpacityIncrease:
                if (_transparency && _opacity < 100)
                {
                    _opacity += 5;
                    ApplyOpacityToProfile(_opacity);
                }
                break;

            // Launch
            case KeyAction.LaunchDecrease:
                if (_launchCount > 0) _launchCount--;
                break;
            case KeyAction.LaunchIncrease:
                _launchCount++;
                break;
            case KeyAction.Launch:
                if (_launchCount > 0)
                {
                    Task.Run(async () => await LaunchWindowsAsync(_launchCount)).Wait();
                }
                break;

            // Save/Reset
            case KeyAction.Save:
                _tabManager.SaveCurrentShader();
                break;
            case KeyAction.Reset:
                _tabManager.UpdateConfig(new ShaderConfig());
                break;

            // Layout
            case KeyAction.LayoutCycle:
                var currentState = _configService.LoadState();
                var newConfig = _layoutService.CycleMode(currentState.Layout);
                _layoutService.UpdateConfig(newConfig);
                var windows = _identityService.FindMatrixWindows();
                var positions = _layoutService.CalculateLayout(windows, newConfig);
                _layoutService.ApplyLayout(positions);
                break;

            case KeyAction.SnapbackSave:
                // Save current window positions to layout service
                {
                    var snapWindows = _identityService.FindMatrixWindows();
                    var snapState = _configService.LoadState();
                    var snapPositions = _layoutService.CalculateLayout(snapWindows, snapState.Layout);
                    _layoutService.SaveWindowSlots(snapPositions);
                    DiagnosticLogger.Info("REDPILL", $"Saved {snapPositions.Count} window positions");
                }
                break;

            case KeyAction.SnapbackRestore:
                // Restore saved window positions
                {
                    var restoreWindows = _identityService.FindMatrixWindows();
                    var loadedSlots = _layoutService.LoadWindowSlots(restoreWindows);
                    _layoutService.ApplyLayout(loadedSlots);
                    DiagnosticLogger.Info("REDPILL", "Restored window positions");
                }
                break;

            case KeyAction.PriorityToggle:
                // Toggle priority lock (keeps specific windows on primary monitor)
                {
                    var priorityState = _configService.LoadState();
                    var newPriorityLayout = priorityState.Layout with { PriorityLock = !priorityState.Layout.PriorityLock };
                    _layoutService.UpdateConfig(newPriorityLayout);
                    DiagnosticLogger.Info("REDPILL", $"Priority lock: {newPriorityLayout.PriorityLock}");
                }
                break;

            case KeyAction.GlitchToggle:
                // Toggle glitch auto-snap mode
                {
                    var glitchState = _configService.LoadState();
                    var newGlitchLayout = glitchState.Layout with { GlitchEnabled = !glitchState.Layout.GlitchEnabled };
                    _layoutService.UpdateConfig(newGlitchLayout);
                    DiagnosticLogger.Info("REDPILL", $"Glitch mode: {newGlitchLayout.GlitchEnabled}");
                }
                break;

            case KeyAction.MonitorChange:
                // Cycle through available monitor counts (simplified - just refreshes layout)
                {
                    var monitorWindows = _identityService.FindMatrixWindows();
                    var monitorState = _configService.LoadState();
                    var monitorPositions = _layoutService.CalculateLayout(monitorWindows, monitorState.Layout);
                    _layoutService.ApplyLayout(monitorPositions);
                    DiagnosticLogger.Info("REDPILL", "Refreshed layout across monitors");
                }
                break;

            case KeyAction.PrimaryDecrease:
                // Decrease windows on primary monitor
                {
                    var decState = _configService.LoadState();
                    var newDecCount = Math.Max(0, decState.Layout.PrimaryWindowCount - 1);
                    var newDecLayout = decState.Layout with { PrimaryWindowCount = newDecCount };
                    _layoutService.UpdateConfig(newDecLayout);
                    DiagnosticLogger.Info("REDPILL", $"Primary window count: {newDecCount}");
                }
                break;

            case KeyAction.PrimaryIncrease:
                // Increase windows on primary monitor
                {
                    var incState = _configService.LoadState();
                    var newIncCount = Math.Min(8, incState.Layout.PrimaryWindowCount + 1);
                    var newIncLayout = incState.Layout with { PrimaryWindowCount = newIncCount };
                    _layoutService.UpdateConfig(newIncLayout);
                    DiagnosticLogger.Info("REDPILL", $"Primary window count: {newIncCount}");
                }
                break;

            case KeyAction.PrimaryReset:
                // Reset to auto distribution
                {
                    var resetState = _configService.LoadState();
                    var newResetLayout = resetState.Layout with { PrimaryWindowCount = 0 }; // 0 = auto
                    _layoutService.UpdateConfig(newResetLayout);
                    DiagnosticLogger.Info("REDPILL", "Primary window count reset to auto");
                }
                break;

            case KeyAction.HotkeyConfig:
                // Open hotkey configuration screen (Shift+H)
                {
                    var configScreen = new HotkeyConfigScreen(_hotkeyConfigService);
                    configScreen.Run();
                    // Refresh main TUI after config screen exits
                    Console.Clear();
                }
                break;
        }
    }

    private async Task LaunchWindowsAsync(int count)
    {
        var existingHandles = GetExistingWindowHandles();

        for (int i = 0; i < count; i++)
        {
            var nextSlot = FindNextAvailableSlot();
            if (nextSlot == -1) break;

            var profileName = $"Matrix-{nextSlot}";
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "wt.exe",
                    Arguments = $"-p \"{profileName}\"",
                    UseShellExecute = true
                };
                Process.Start(psi);

                var newHandle = await WaitForNewWindowAsync(existingHandles);
                if (newHandle != nint.Zero)
                {
                    _identityService.RegisterWindowHandle(newHandle, profileName, nextSlot);
                    existingHandles.Add(newHandle);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to launch {Profile}", profileName);
            }
        }

        // Apply layout after all windows launched
        var windows = _identityService.FindMatrixWindows();
        var state = _configService.LoadState();
        var positions = _layoutService.CalculateLayout(windows, state.Layout);
        _layoutService.ApplyLayout(positions);

        // Reset launch count
        _launchCount = 0;
    }

    private int FindNextAvailableSlot()
    {
        var usedSlots = new HashSet<int>(_identityService.FindMatrixWindows().Select(w => w.ShaderIndex));
        for (int i = 1; i <= 8; i++)
        {
            if (!usedSlots.Contains(i)) return i;
        }
        return -1;
    }

    private HashSet<nint> GetExistingWindowHandles()
    {
        return new HashSet<nint>(_identityService.FindMatrixWindows().Select(w => w.Handle));
    }

    private async Task<nint> WaitForNewWindowAsync(HashSet<nint> existingHandles)
    {
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
                    return window.Handle;
                }
            }
        }
        return nint.Zero;
    }

    private void ApplyOpacityToProfile(int opacity)
    {
        try
        {
            var settings = _terminalSettingsService.LoadSettings();
            var profileName = $"Matrix-{_tabManager.CurrentSlot}";
            var profile = _terminalSettingsService.GetProfile(settings, profileName);

            if (profile != null)
            {
                var updatedProfile = profile with { Opacity = opacity };
                _terminalSettingsService.UpsertProfile(settings, updatedProfile);
                _terminalSettingsService.SaveSettings(settings);
                DiagnosticLogger.Info("REDPILL", $"Applied opacity {opacity}% to {profileName}");
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to apply opacity to profile");
        }
    }
}
