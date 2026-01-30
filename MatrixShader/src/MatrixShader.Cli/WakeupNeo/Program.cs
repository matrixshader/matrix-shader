using System.Diagnostics;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Core.Startup;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.WakeupNeo;

/// <summary>
/// WakeupNeo - Setup wizard for Matrix Shader.
/// "Walking the path"
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

            if (options.Debug)
            {
                DiagnosticLogger.Initialize(true);
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

            var wizard = provider.GetRequiredService<SetupWizard>();

            var exitCode = await wizard.RunAsync(options.Morpheus, options.AgentSmith);
            return exitCode;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("WAKEUPNEO", $"Unhandled exception: {ex.Message}");
            MatrixErrorHandler.ShowError(ex.Message);
            return 1;
        }
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" WAKEUPNEO - Walking the path");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Usage: wakeupneo [options]");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Options:");
        ConsoleHelper.WriteLineDim("   --help       Show this help message");
        ConsoleHelper.WriteLineDim("   --debug      Enable diagnostic logging");
        ConsoleHelper.WriteLineDim("   --morpheus   Philosophical explanations");
        ConsoleHelper.WriteLineDim("   --agent-smith  Chaos mode");
        Console.WriteLine();
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

        // Wizard
        services.AddSingleton<SetupWizard>();
    }
}

/// <summary>
/// Color preset definition for wizard.
/// </summary>
public record ColorPreset(string Name, float R, float G, float B, string Key);

/// <summary>
/// Tab configuration created during setup.
/// </summary>
public record TabConfig(int Slot, string ColorName, float R, float G, float B);

/// <summary>
/// Interactive setup wizard with Blue Pill / Red Pill choice.
/// </summary>
public class SetupWizard
{
    private readonly IConfigService _configService;
    private readonly IShaderService _shaderService;
    private readonly IIdentityService _identityService;
    private readonly ILayoutService _layoutService;
    private readonly ITerminalSettingsService _terminalService;
    private readonly ILogger<SetupWizard> _logger;

    private static readonly ColorPreset[] Presets =
    {
        new("Classic Green", 0.0f, 1.0f, 0.3f, "1"),
        new("Cyber Blue", 0.0f, 0.6f, 1.0f, "2"),
        new("Blood Red", 1.0f, 0.1f, 0.1f, "3"),
        new("Purple", 0.7f, 0.0f, 1.0f, "4"),
        new("Gold", 1.0f, 0.7f, 0.0f, "5"),
        new("Teal", 0.0f, 0.9f, 0.9f, "6")
    };

    public SetupWizard(
        IConfigService configService,
        IShaderService shaderService,
        IIdentityService identityService,
        ILayoutService layoutService,
        ITerminalSettingsService terminalService,
        ILogger<SetupWizard> logger)
    {
        _configService = configService;
        _shaderService = shaderService;
        _identityService = identityService;
        _layoutService = layoutService;
        _terminalService = terminalService;
        _logger = logger;
    }

    public async Task<int> RunAsync(bool morpheusMode, bool agentSmithMode)
    {
        DiagnosticLogger.Info("WAKEUPNEO", "Setup wizard starting");

        // Agent Smith mode: chaos
        if (agentSmithMode)
        {
            await RunAgentSmithModeAsync();
            return 0;
        }

        // Dramatic intro
        Console.Clear();
        Console.WriteLine();
        await CliBootstrap.TypewriterAsync(" Wake up, Neo...", 100);
        await Task.Delay(1000);

        await CliBootstrap.TypewriterAsync(" The Matrix has you...", 80);
        await Task.Delay(1000);

        await CliBootstrap.TypewriterAsync(" Follow the white rabbit.", 80);
        await Task.Delay(500);

        // Header
        Console.Clear();
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" WAKE UP, NEO...");
        ConsoleHelper.WriteLineDim(" ----------------------------------------");
        Console.WriteLine();

        // Show random quote
        CliBootstrap.ShowRandomQuote();

        // Morpheus mode intro
        if (morpheusMode)
        {
            await ShowMorpheusIntro();
        }

        // Check for previous session
        var state = _configService.LoadState();
        var previousSlots = GetActiveSlots(state);
        List<TabConfig> tabConfigs;

        if (previousSlots.Count > 0)
        {
            ConsoleHelper.WriteMatrixGreen(" Previous session found:");
            Console.WriteLine();
            ConsoleHelper.WriteLineDim($"   {previousSlots.Count} windows, slots: [{string.Join(", ", previousSlots)}]");
            Console.WriteLine();

            Console.Write(" Restore previous? (y/n): ");
            var restoreKey = Console.ReadKey(intercept: true);
            Console.WriteLine();

            if (restoreKey.Key == ConsoleKey.Y)
            {
                tabConfigs = LoadPreviousConfigs(previousSlots, state);
                Console.WriteLine();
                ConsoleHelper.WriteLineMatrixGreen($" Restoring {tabConfigs.Count} window(s)...");
            }
            else
            {
                Console.WriteLine();
                tabConfigs = await ConfigureNewWindowsAsync(morpheusMode);
            }
        }
        else
        {
            tabConfigs = await ConfigureNewWindowsAsync(morpheusMode);
        }

        if (tabConfigs.Count == 0)
        {
            ConsoleHelper.WriteLineDim(" Setup cancelled.");
            return 2; // User cancelled
        }

        // Summary and pill choice
        Console.Clear();
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" THE MATRIX HAS YOU...");
        ConsoleHelper.WriteLineDim(" ----------------------------------------");
        Console.WriteLine();

        foreach (var cfg in tabConfigs)
        {
            var swatch = GetColorSwatch(cfg.R, cfg.G, cfg.B);
            Console.WriteLine($"   Tab {cfg.Slot}: {swatch} {cfg.ColorName}");
        }

        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" ----------------------------------------");
        Console.WriteLine();

        // Blue Pill / Red Pill choice using arrow-key menu
        var pillOptions = new[]
        {
            "BLUE PILL - Enter the Matrix",
            "RED PILL - Full Customization (opens control panel)"
        };

        var pillChoice = CliBootstrap.ArrowKeyMenu(pillOptions, "This is your last chance. After this, there is no turning back.");

        if (pillChoice == -1)
        {
            ConsoleHelper.WriteLineDim(" Setup cancelled.");
            return 2;
        }

        var isRedPill = pillChoice == 1;

        // Create shaders
        Console.WriteLine();
        ConsoleHelper.WriteMatrixGreen(" Creating shaders...");
        Console.WriteLine();

        foreach (var cfg in tabConfigs)
        {
            var config = new ShaderConfig().WithColor(cfg.R, cfg.G, cfg.B);
            _shaderService.WriteConfig(cfg.Slot, config);
            ConsoleHelper.WriteLineDim($"   Matrix-{cfg.Slot}.hlsl created");
        }

        // Ensure profiles exist in Windows Terminal
        var terminalSettings = _terminalService.LoadSettings();
        var shadersDir = CliBootstrap.GetShadersDirectory();
        _terminalService.CreateMatrixProfiles(terminalSettings, 8, shadersDir);
        _terminalService.SaveSettings(terminalSettings);

        // Save state
        var newState = new MatrixState
        {
            ShaderConfigs = tabConfigs.ToDictionary(
                c => c.Slot,
                c => new ShaderConfig().WithColor(c.R, c.G, c.B)),
            Layout = state.Layout
        };
        _configService.SaveState(newState);

        // Launch windows
        await Task.Delay(500);

        Console.WriteLine();
        if (isRedPill)
        {
            ConsoleHelper.WriteLineMatrixGreen(" Follow the white rabbit...");
        }
        Console.WriteLine();
        ConsoleHelper.WriteMatrixGreen(" Opening windows...");
        Console.WriteLine();

        _identityService.CleanStaleEntries();
        _identityService.LoadRegistry();

        foreach (var cfg in tabConfigs)
        {
            var profileName = $"Matrix-{cfg.Slot}";
            Console.Write($"   Waiting for {profileName}...");

            var existingHandles = GetExistingWindowHandles();

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
                continue;
            }

            var newHandle = await WaitForNewWindowAsync(existingHandles);

            if (newHandle != IntPtr.Zero)
            {
                _identityService.RegisterWindowHandle(newHandle, profileName, cfg.Slot);
                ConsoleHelper.WriteLineMatrixGreen(" OK");
            }
            else
            {
                ConsoleHelper.WriteLineDim(" TIMEOUT");
            }
        }

        // Position windows
        Console.WriteLine();
        ConsoleHelper.WriteMatrixGreen(" Positioning windows...");
        Console.WriteLine();

        await Task.Delay(500);

        var allWindows = _identityService.FindMatrixWindows();
        if (allWindows.Count > 0)
        {
            var positions = _layoutService.CalculateLayout(allWindows, newState.Layout);
            _layoutService.ApplyLayout(positions);
            ConsoleHelper.WriteLineDim($"   Positioned {allWindows.Count} windows");
        }

        _identityService.SaveRegistry();

        // Red Pill: also launch control panel
        if (isRedPill)
        {
            Console.WriteLine();
            ConsoleHelper.WriteMatrixGreen(" Opening control panel...");
            Console.WriteLine();

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "wt.exe",
                    Arguments = "-p \"Redpill\"",
                    UseShellExecute = true
                };
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Warn("WAKEUPNEO", $"Failed to launch Redpill: {ex.Message}");
            }
        }

        // Final message
        Console.WriteLine();
        if (isRedPill)
        {
            ConsoleHelper.WriteLineMatrixGreen(" THE MATRIX HAS YOU.");
            ConsoleHelper.WriteLineDim(" Control panel ready for live adjustments.");
        }
        else
        {
            ConsoleHelper.WriteLineMatrixGreen(" FOLLOW THE WHITE RABBIT.");
            ConsoleHelper.WriteLineDim(" Type 'redpill' for live controls.");
        }

        await Task.Delay(2000);

        DiagnosticLogger.Info("WAKEUPNEO", "Setup wizard complete");

        return 0;
    }

    private async Task ShowMorpheusIntro()
    {
        Console.WriteLine();
        await CliBootstrap.TypewriterAsync(" You take the red pill, you stay in Wonderland...", 60);
        await Task.Delay(300);
        await CliBootstrap.TypewriterAsync(" and I show you how deep the rabbit hole goes.", 60);
        await Task.Delay(500);
        Console.WriteLine();
    }

    private async Task RunAgentSmithModeAsync()
    {
        ConsoleHelper.WriteLineMatrixGreen(" AGENT SMITH MODE: CHAOS");
        Console.WriteLine();

        await CliBootstrap.TypewriterAsync(" Mr. Anderson...", 100);
        await Task.Delay(500);
        await CliBootstrap.TypewriterAsync(" You're going to help us, Mr. Anderson.", 80);
        await Task.Delay(500);
        await CliBootstrap.TypewriterAsync(" Whether you want to or not.", 80);
        await Task.Delay(1000);

        // Randomize all existing windows
        var windows = _identityService.FindMatrixWindows();
        foreach (var window in windows)
        {
            var chaosConfig = new ShaderConfig()
                .WithColor(
                    Random.Shared.NextSingle(),
                    Random.Shared.NextSingle(),
                    Random.Shared.NextSingle())
                with { Speed = (float)(Random.Shared.NextDouble() * 2.5 + 0.5) };

            _shaderService.WriteConfig(window.ShaderIndex, chaosConfig);
        }

        ConsoleHelper.WriteLineMatrixGreen($" Chaos applied to {windows.Count} windows.");
    }

    private async Task<List<TabConfig>> ConfigureNewWindowsAsync(bool morpheusMode)
    {
        // Detect currently open Matrix windows to avoid slot collisions
        var openWindows = _identityService.FindMatrixWindows();
        var occupiedSlots = new HashSet<int>(openWindows.Select(w => w.ShaderIndex));

        if (occupiedSlots.Count > 0)
        {
            Console.WriteLine();
            ConsoleHelper.WriteLineDim($" Detected {occupiedSlots.Count} open Matrix window(s): slots [{string.Join(", ", occupiedSlots)}]");
        }

        // Calculate available slots (1-8 minus occupied)
        var availableSlots = Enumerable.Range(1, 8).Where(s => !occupiedSlots.Contains(s)).ToList();
        var maxNewWindows = availableSlots.Count;

        if (maxNewWindows == 0)
        {
            Console.WriteLine();
            ConsoleHelper.WriteLineMatrixGreen(" All 8 Matrix slots are in use!");
            ConsoleHelper.WriteLineDim(" Close some Matrix windows first, or use the control panel.");
            await Task.Delay(3000);
            return new List<TabConfig>();
        }

        // Ask for window count
        Console.WriteLine();
        ConsoleHelper.WriteLineDim($" Available slots: [{string.Join(", ", availableSlots)}]");
        Console.Write($" How many NEW Matrix tabs? (1-{maxNewWindows}): ");
        var countInput = Console.ReadLine() ?? "1";

        if (!int.TryParse(countInput, out var numTabs))
            numTabs = 1;

        numTabs = Math.Max(1, Math.Min(maxNewWindows, numTabs));

        // Configure each tab
        var tabConfigs = new List<TabConfig>();
        var slotIndex = 0;

        for (int i = 1; i <= numTabs; i++)
        {
            Console.Clear();
            Console.WriteLine();
            ConsoleHelper.WriteLineMatrixGreen($" TAB {i} OF {numTabs}");
            ConsoleHelper.WriteLineDim(" ----------------------------------------");
            Console.WriteLine();

            // Show color presets
            foreach (var preset in Presets)
            {
                var swatch = GetColorSwatch(preset.R, preset.G, preset.B);
                Console.WriteLine($"   [{preset.Key}] {swatch} {preset.Name}");
            }

            Console.WriteLine();
            Console.Write(" Color (1-6): ");
            var colorInput = Console.ReadLine() ?? "1";

            var selectedPreset = Presets.FirstOrDefault(p => p.Key == colorInput) ?? Presets[0];

            var assignedSlot = availableSlots[slotIndex++];

            tabConfigs.Add(new TabConfig(
                assignedSlot,
                selectedPreset.Name,
                selectedPreset.R,
                selectedPreset.G,
                selectedPreset.B));

            var swatch2 = GetColorSwatch(selectedPreset.R, selectedPreset.G, selectedPreset.B);
            Console.WriteLine();
            ConsoleHelper.WriteMatrixGreen($" Tab {i} -> Matrix-{assignedSlot} - {swatch2} {selectedPreset.Name}");
            await Task.Delay(300);
        }

        return tabConfigs;
    }

    private List<TabConfig> LoadPreviousConfigs(List<int> slots, MatrixState state)
    {
        var configs = new List<TabConfig>();

        foreach (var slot in slots)
        {
            if (state.ShaderConfigs.TryGetValue(slot, out var config))
            {
                var colorName = GetColorName(config.R, config.G, config.B);
                configs.Add(new TabConfig(slot, colorName, config.R, config.G, config.B));
            }
            else
            {
                // Default green
                configs.Add(new TabConfig(slot, "Classic Green", 0f, 1f, 0.3f));
            }
        }

        return configs;
    }

    private static string GetColorName(float r, float g, float b)
    {
        foreach (var preset in Presets)
        {
            if (Math.Abs(preset.R - r) < 0.05f &&
                Math.Abs(preset.G - g) < 0.05f &&
                Math.Abs(preset.B - b) < 0.05f)
            {
                return preset.Name;
            }
        }
        return "Custom";
    }

    private static string GetColorSwatch(float r, float g, float b)
    {
        // Create a colored block using ANSI 24-bit color
        var ri = (int)(r * 255);
        var gi = (int)(g * 255);
        var bi = (int)(b * 255);
        return $"\x1b[48;2;{ri};{gi};{bi}m  \x1b[0m";
    }

    private List<int> GetActiveSlots(MatrixState state)
    {
        if (state.ShaderConfigs == null || state.ShaderConfigs.Count == 0)
            return new List<int>();

        // Return slots that have shader files created (matches Bluepill behavior)
        return state.ShaderConfigs.Keys
            .Where(k => _shaderService.ShaderExists(k))
            .OrderBy(k => k)
            .ToList();
    }

    private HashSet<IntPtr> GetExistingWindowHandles()
    {
        var handles = new HashSet<IntPtr>();
        var windows = _identityService.FindMatrixWindows();
        foreach (var w in windows)
        {
            handles.Add(w.Handle);
        }
        return handles;
    }

    private async Task<IntPtr> WaitForNewWindowAsync(HashSet<IntPtr> existingHandles)
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

        return IntPtr.Zero;
    }
}
