using System.Diagnostics;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Core.Startup;
using MatrixShader.Lite;
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
                ConsoleHelper.EnableAnsiEscapeCodes();
                ShowHelp();
                return 0;
            }

            if (options.Debug)
            {
                DiagnosticLogger.Initialize(true);
            }

            // If not running inside Windows Terminal, relaunch in WT.
            // Shaders and transparency only work in WT — a regular console is useless.
            if (!EnvironmentService.IsWindowsTerminal())
            {
                var wtPath = CliBootstrap.GetWindowsTerminalExePath();
                if (wtPath != null)
                {
                    var self = Process.GetCurrentProcess().MainModule?.FileName
                               ?? Path.Combine(AppContext.BaseDirectory, "wakeupneo.exe");
                    var wtArgs = string.Join(" ", args.Select(a => a.Contains(' ') ? $"\"{a}\"" : a));
                    // Create a WakeupNeo profile with opacity 100 (opaque black world)
                    var termSvc = new TerminalSettingsService(
                        Microsoft.Extensions.Logging.Abstractions.NullLogger<TerminalSettingsService>.Instance);
                    var wakeupProfile = new TerminalProfile
                    {
                        Name = "WakeupNeo",
                        Guid = termSvc.GetProfileGuid("WakeupNeo") ?? $"{{{Guid.NewGuid()}}}",
                        Commandline = $"\"{self}\" {wtArgs}".Trim(),
                        Hidden = true,
                        Opacity = 100,
                        UseAcrylic = false,
                        FontFace = "Nimbus Mono PS",
                        FontWeight = "bold",
                    };
                    termSvc.UpsertProfileSurgical(wakeupProfile);
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = wtPath,
                        Arguments = $"-w -1 --fullscreen -p \"WakeupNeo\"",
                        UseShellExecute = true
                    });
                    DiagnosticLogger.Info("WAKEUPNEO", "Relaunched in Windows Terminal");
                    return 0;
                }
            }

            // Bootstrap — CliBootstrap handles WT detection + auto-install (winget → Store → GitHub)
            var bootstrap = await CliBootstrap.InitializeAsync(verbose: options.Debug);
            if (!bootstrap.Success)
            {
                // If WT not installed, fall through to lite mode instead of exiting
                if (bootstrap.ErrorMessage?.Contains("Windows Terminal") == true)
                {
                    DiagnosticLogger.Info("WAKEUPNEO", "WT not available, will fall through to lite mode");
                }
                else
                {
                    ConsoleHelper.WriteLineMatrixGreen($"Error: {bootstrap.ErrorMessage}");
                    return 1;
                }
            }

            // Set up DI
            var services = new ServiceCollection();
            ConfigureServices(services);
            var provider = services.BuildServiceProvider();

            // Detect render mode
            var envService = provider.GetRequiredService<EnvironmentService>();
            var mode = envService.DetectRenderMode();

            if (mode == RenderMode.Lite)
            {
                // Lite mode - wizard requires WT, fall back to text rain
                Console.Clear();
                Console.WriteLine();
                ConsoleHelper.WriteLineMatrixGreen(" LITE MODE - Windows Terminal not detected");
                Console.WriteLine();
                ConsoleHelper.WriteLineDim(" The setup wizard requires Windows Terminal for shader profiles.");
                ConsoleHelper.WriteLineDim(" Running text-based Matrix rain instead...");
                Console.WriteLine();

                await Task.Delay(2000); // Let user read the message

                var menu = new FallbackMenu();
                await menu.RunAsync(CancellationToken.None);
                return 0;
            }
            else if (mode == RenderMode.Headless)
            {
                Console.WriteLine("\x1b[31mNo display available. Use --help for options.\x1b[0m");
                return 1;
            }

            // Full mode continues with setup wizard
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
public record ColorPreset(string Name, float R, float G, float B, string Key, string AnsiColor = "\x1b[38;2;110;220;170m");

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
        new("Classic Green", 0.0f, 1.0f, 0.3f, "1", "\x1b[38;2;0;255;77m"),
        new("Cyber Blue", 0.0f, 0.6f, 1.0f, "2", "\x1b[38;2;0;153;255m"),
        new("Blood Red", 1.0f, 0.1f, 0.1f, "3", "\x1b[38;2;255;26;26m"),
        new("Purple", 0.7f, 0.0f, 1.0f, "4", "\x1b[38;2;178;0;255m"),
        new("Gold", 1.0f, 0.7f, 0.0f, "5", "\x1b[38;2;255;178;0m"),
        new("Teal", 0.0f, 0.9f, 0.9f, "6", "\x1b[38;2;0;230;230m")
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

        // Force opaque black background for the wizard window.
        // If wakeupneo is launched from a Matrix profile that has opacity<100 or a shader,
        // the typewriter text would appear over the transparent/shader background.
        // ANSI \x1b[40m sets text bg to black; we also need to set the WT profile
        // to opacity=100 since ANSI bg color doesn't affect WT window compositing.
        int? originalOpacity = null;
        string? currentProfileGuid = null;
        try
        {
            currentProfileGuid = Environment.GetEnvironmentVariable("WT_PROFILE_ID");
            if (!string.IsNullOrEmpty(currentProfileGuid))
            {
                var settings = _terminalService.LoadSettings();
                var currentProfile = settings.Profiles?.List?.FirstOrDefault(p =>
                    string.Equals(p.Guid, currentProfileGuid, StringComparison.OrdinalIgnoreCase));
                if (currentProfile != null && currentProfile.Opacity < 100)
                {
                    originalOpacity = currentProfile.Opacity;
                    _terminalService.UpsertProfileSurgical(currentProfile with { Opacity = 100 });
                    DiagnosticLogger.Info("WAKEUPNEO", $"Set profile '{currentProfile.Name}' to opacity 100 (was {originalOpacity})");
                }
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("WAKEUPNEO", $"Could not set opaque background: {ex.Message}");
        }

        try
        {
        // Dramatic intro — matches Linux wakeupneo timing
        // Set black background, clear screen, and home cursor to ensure solid black canvas
        Console.Write("\x1b[40m\x1b[2J\x1b[H");
        Console.WriteLine();
        await CliBootstrap.TypewriterAsync(" Wake up, Neo...", 100);
        await Task.Delay(1000);

        await CliBootstrap.TypewriterAsync(" The Matrix has you...", 80);
        await Task.Delay(1000);

        await CliBootstrap.TypewriterAsync(" Follow the white rabbit.", 80);
        await Task.Delay(500);

        // Show random quote before header (matches Linux flow)
        CliBootstrap.ShowRandomQuote();
        await Task.Delay(1000);

        // Morpheus mode: extended philosophical intro
        if (morpheusMode)
        {
            await ShowMorpheusIntro();
        }

        // Clear and show header
        Console.Clear();
        Console.WriteLine();
        Console.WriteLine(" WAKE UP, NEO...");
        ConsoleHelper.WriteLineDim(" ----------------------------------------");
        Console.WriteLine();

        // Check for previous session
        // IMPORTANT: Use IsFirstRun first! The default MatrixState() has 8 ShaderConfigs,
        // and ShaderExists() finds bundled shaders in Program Files, causing false detection.
        var isFirstRun = _configService.IsFirstRun;
        var state = _configService.LoadState();
        var previousSlots = isFirstRun ? new List<int>() : GetActiveSlots(state);
        List<TabConfig> tabConfigs;

        DiagnosticLogger.Debug("WAKEUPNEO", $"IsFirstRun: {isFirstRun}, previousSlots: [{string.Join(", ", previousSlots)}]");

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
            var ansiColor = GetPresetAnsiColor(cfg.R, cfg.G, cfg.B);
            Console.WriteLine($"   Tab {cfg.Slot}: {swatch} {ansiColor}{cfg.ColorName}\x1b[0m");
        }

        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" ----------------------------------------");

        // Blue Pill / Red Pill choice using arrow-key menu
        // Check license to show appropriate Red Pill label
        var licenseService = new LicenseService();
        var isLicensed = licenseService.IsLicensed;

        var redPillLabel = isLicensed
            ? "\x1b[31mRED PILL\x1b[0m  - Full Customization (control panel)"
            : "\x1b[31mRED PILL\x1b[0m  - Full Control Panel (requires license)";

        var pillOptions = new[]
        {
            "\x1b[34mBLUE PILL\x1b[0m - Enter the Matrix",
            redPillLabel
        };

        var pillChoice = CliBootstrap.ArrowKeyMenu(pillOptions, "Choose your path:");

        if (pillChoice == -1)
        {
            ConsoleHelper.WriteLineDim(" Setup cancelled.");
            return 2;
        }

        var isRedPill = pillChoice == 1;

        // Create shaders (silent — Linux doesn't show this step)
        foreach (var cfg in tabConfigs)
        {
            var config = new ShaderConfig().WithColor(cfg.R, cfg.G, cfg.B);
            _shaderService.WriteConfig(cfg.Slot, config);
        }

        // Ensure profiles exist in Windows Terminal
        var terminalSettings = _terminalService.LoadSettings();
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var profileCount = tabConfigs.Count;
        _terminalService.CreateMatrixProfiles(terminalSettings, 8, shadersDir);
        _terminalService.CreateRedpillProfile(terminalSettings, shadersDir);

        // Sync tab colors from actual shader RGB (not just preset defaults)
        foreach (var cfg in tabConfigs)
        {
            var profileName = $"Matrix-{cfg.Slot}";
            var profile = _terminalService.GetProfile(terminalSettings, profileName);
            if (profile != null)
            {
                var shaderCfg = _shaderService.ReadConfig(cfg.Slot);
                var r = (int)(shaderCfg.R * 255);
                var g = (int)(shaderCfg.G * 255);
                var b = (int)(shaderCfg.B * 255);
                var color = $"#{r:X2}{g:X2}{b:X2}";
                var updatedProfile = profile with { TabColor = color, Foreground = color };
                _terminalService.UpsertProfile(terminalSettings, updatedProfile);
            }
        }

        _terminalService.SaveSettings(terminalSettings);

        // Verify profiles were created correctly
        var verification = _terminalService.VerifyProfiles(profileCount);
        if (!verification.Success)
        {
            Console.WriteLine();
            ConsoleHelper.WriteLineDim("Warning: Profile verification found issues:");

            foreach (var missing in verification.MissingProfiles)
            {
                ConsoleHelper.WriteLineDim($"  - Missing: {missing}");
            }

            foreach (var invalid in verification.InvalidShaderPaths)
            {
                ConsoleHelper.WriteLineDim($"  - Invalid path: {invalid}");
            }

            Console.WriteLine();
            ConsoleHelper.WriteLineDim("Try running wakeupneo again or check shader files.");
        }
        else
        {
            DiagnosticLogger.Info("WAKEUPNEO", $"Verified {profileCount} profiles successfully");
        }

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
        Console.Clear();
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" Opening windows...");
        Console.WriteLine();

        _identityService.CleanStaleEntries();
        _identityService.LoadRegistry();

        foreach (var cfg in tabConfigs)
        {
            var profileName = $"Matrix-{cfg.Slot}";
            Console.Write($"   Waiting for Matrix-{cfg.Slot}...");

            var existingHandles = GetExistingWindowHandles();

            try
            {
                var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
                var psi = new ProcessStartInfo
                {
                    FileName = wtPath,
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
                var swatch = GetColorSwatch(cfg.R, cfg.G, cfg.B);
                var ansiColor = GetPresetAnsiColor(cfg.R, cfg.G, cfg.B);
                Console.WriteLine($" {swatch} {ansiColor}{cfg.ColorName}\x1b[0m \x1b[38;2;0;255;77mOK\x1b[0m");
            }
            else
            {
                ConsoleHelper.WriteLineDim(" TIMEOUT");
            }
        }

        // Position windows
        await Task.Delay(500);

        var allWindows = _identityService.FindMatrixWindows();
        if (allWindows.Count > 0)
        {
            var positions = _layoutService.CalculateLayout(allWindows, newState.Layout);
            _layoutService.ApplyLayout(positions);
            Console.WriteLine($"   Positioned {allWindows.Count} window(s) in layout");
        }

        _identityService.SaveRegistry();

        // Kill any orphaned background processes before launching fresh ones
        ProcessCleanup.KillBackgroundProcesses();

        // Start background monitor (watchdog for matrix-hotkeys)
        StartMonitorProcess();

        // Launch hotkeys background process (includes Glitch auto-snap)
        Console.WriteLine();
        ConsoleHelper.WriteMatrixGreen(" Starting hotkeys...");
        var hotkeyStarted = LaunchHotkeysProcess();
        if (hotkeyStarted)
        {
            Console.WriteLine(" \x1b[1;37mOK\x1b[0m");
        }
        else
        {
            ConsoleHelper.WriteLineDim(" (not available)");
        }

        // Red Pill: also launch control panel
        if (isRedPill)
        {
            Console.WriteLine();
            ConsoleHelper.WriteMatrixGreen(" Opening control panel...");
            Console.WriteLine();

            try
            {
                var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
                var psi = new ProcessStartInfo
                {
                    FileName = wtPath,
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

        // Final message (matches Linux flow)
        // The choice is made. The veil lifts — make this window transparent.
        // The user now sees through the boring black terminal world they started in.
        try
        {
            var wakeupGuid = _terminalService.GetProfileGuid("WakeupNeo");
            if (wakeupGuid != null)
            {
                var settings = _terminalService.LoadSettings();
                var prof = settings.Profiles?.List?.FirstOrDefault(p =>
                    string.Equals(p.Guid, wakeupGuid, StringComparison.OrdinalIgnoreCase));
                if (prof != null)
                    _terminalService.UpsertProfileSurgical(prof with { Opacity = 85 });
            }
        }
        catch { }

        Console.WriteLine();
        if (isRedPill)
        {
            if (isLicensed)
            {
                ConsoleHelper.WriteLineMatrixGreen(" THE MATRIX HAS YOU.");
                ConsoleHelper.WriteLineDim(" Launching control panel...");
            }
            else
            {
                ConsoleHelper.WriteLineMatrixGreen(" THE RED PILL");
                Console.WriteLine();
                ConsoleHelper.WriteLineDim(" Opening purchase page...");
                Console.WriteLine();
                Console.WriteLine(" \x1b]8;;https://matrixshader.com/redpill\x07\x1b[36mmatrixshader.com/redpill\x1b[0m\x1b]8;;\x07");
            }
        }
        else
        {
            ConsoleHelper.WriteLineMatrixGreen(" FOLLOW THE WHITE RABBIT.");
            Console.WriteLine();
            ConsoleHelper.WriteLineDim(" Unlock the Red Pill control panel:");
            Console.WriteLine(" \x1b[36m matrixshader.com/redpill\x1b[0m");
        }

        // Show global hotkeys summary (matches Linux format)
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" ----------------------------------------");
        Console.WriteLine(" \x1b[36mGLOBAL HOTKEYS\x1b[0m \x1b[90m(Ctrl+Shift+H for full reference)\x1b[0m");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+Left/Right   Rotate windows");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+L            Cycle layout mode");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+B            Toggle transparency");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+Up/Down      Change rain speed");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+1/2/3        Toggle Far/Mid/Near layers");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+H            Hotkey help overlay");

        ConsoleHelper.ShowCommandBanner();

        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Enjoying Matrix Shader? Buy me a coffee:");
        Console.WriteLine(" \x1b]8;;https://buymeacoffee.com/IKnowKungFu\x07\x1b[33mhttps://buymeacoffee.com/IKnowKungFu\x1b[0m\x1b]8;;\x07");

        Console.WriteLine();

        DiagnosticLogger.Info("WAKEUPNEO", "Setup wizard complete");

        // Window stays open — user closes it when they're done reading.
        // This window is now transparent, showing the Matrix behind it.
        await Task.Delay(Timeout.Infinite);
        return 0;

        } // end try (opaque background)
        finally
        {
            // Restore original profile opacity if we changed it.
            // This runs on normal exit, early cancel (return 2), and exceptions.
            RestoreProfileOpacity(originalOpacity, currentProfileGuid);
        }
    }

    /// <summary>
    /// Restores the original opacity on the current WT profile after the wizard finishes.
    /// Called from the finally block so it runs on both normal exit and early cancel.
    /// </summary>
    private void RestoreProfileOpacity(int? originalOpacity, string? profileGuid)
    {
        if (originalOpacity == null || string.IsNullOrEmpty(profileGuid))
            return;

        try
        {
            var settings = _terminalService.LoadSettings();
            var profile = settings.Profiles?.List?.FirstOrDefault(p =>
                string.Equals(p.Guid, profileGuid, StringComparison.OrdinalIgnoreCase));
            if (profile != null)
            {
                _terminalService.UpsertProfileSurgical(profile with { Opacity = originalOpacity.Value });
                DiagnosticLogger.Info("WAKEUPNEO", $"Restored profile '{profile.Name}' opacity to {originalOpacity.Value}");
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("WAKEUPNEO", $"Could not restore opacity: {ex.Message}");
        }
    }

    private async Task ShowMorpheusIntro()
    {
        Console.WriteLine();
        await CliBootstrap.TypewriterAsync(" I imagine that right now, you're feeling a bit like Alice.", 50);
        await Task.Delay(500);
        await CliBootstrap.TypewriterAsync(" Tumbling down the rabbit hole.", 50);
        await Task.Delay(500);
        Console.WriteLine();
        await CliBootstrap.TypewriterAsync(" You take the red pill, you stay in Wonderland...", 60);
        await Task.Delay(300);
        await CliBootstrap.TypewriterAsync(" and I show you how deep the rabbit hole goes.", 60);
        await Task.Delay(800);
        Console.WriteLine();
        await CliBootstrap.TypewriterAsync(" Remember, all I'm offering is the truth.", 50);
        await Task.Delay(300);
        await CliBootstrap.TypewriterAsync(" Nothing more.", 60);
        await Task.Delay(1000);
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

        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen($" Chaos applied to {windows.Count} window(s).");
        ConsoleHelper.WriteLineDim(" There is no spoon.");
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

        // Ask for window count (matches Linux — no slot listing)
        Console.WriteLine();
        Console.Write($" How many NEW MatrixShader terminals? (1-{maxNewWindows}): ");
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

            // Show color presets with colored names (matches Linux)
            foreach (var preset in Presets)
            {
                var swatch = GetColorSwatch(preset.R, preset.G, preset.B);
                Console.WriteLine($"   [{preset.Key}] {swatch} {preset.AnsiColor}{preset.Name}\x1b[0m");
            }

            Console.WriteLine();
            Console.Write($" Color (1-{Presets.Length}): ");
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
            Console.WriteLine($" Tab {i} -> Matrix-{assignedSlot} {swatch2} {selectedPreset.AnsiColor}{selectedPreset.Name}\x1b[0m");
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
        // Create a colored block using ANSI 24-bit color (3 chars wide, matches Linux)
        var ri = (int)(r * 255);
        var gi = (int)(g * 255);
        var bi = (int)(b * 255);
        return $"\x1b[48;2;{ri};{gi};{bi}m   \x1b[0m";
    }

    /// <summary>
    /// Returns the ANSI color escape for a preset matching the given RGB, or green as default.
    /// </summary>
    private static string GetPresetAnsiColor(float r, float g, float b)
    {
        foreach (var preset in Presets)
        {
            if (Math.Abs(preset.R - r) < 0.05f &&
                Math.Abs(preset.G - g) < 0.05f &&
                Math.Abs(preset.B - b) < 0.05f)
            {
                return preset.AnsiColor;
            }
        }
        return "\x1b[38;2;110;220;170m"; // Default green
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

    /// <summary>
    /// Launches the hotkeys background process if not already running.
    /// Returns true if launched successfully.
    /// </summary>
    private static bool LaunchHotkeysProcess()
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
                DiagnosticLogger.Debug("WAKEUPNEO", "matrix-hotkeys.exe not found, skipping hotkey launch");
                return false;
            }

            // Start as hidden background process
            var startInfo = new ProcessStartInfo
            {
                FileName = hotkeyExe,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            var process = Process.Start(startInfo);
            if (process == null)
            {
                DiagnosticLogger.ProductionError("WAKEUPNEO", $"Failed to start: {hotkeyExe}");
                return false;
            }
            DiagnosticLogger.Debug("WAKEUPNEO", $"Launched hotkeys process: {hotkeyExe}");
            return true;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("WAKEUPNEO", $"Failed to launch hotkeys: {ex.Message}");
            // Non-fatal - Matrix works without hotkeys
            return false;
        }
    }

    /// <summary>
    /// Starts the background monitor process (watchdog for matrix-hotkeys).
    /// </summary>
    private static void StartMonitorProcess()
    {
        var monitorPath = Path.Combine(AppContext.BaseDirectory, "matrix-monitor.exe");
        DiagnosticLogger.Info("WAKEUPNEO", $"Looking for monitor at: {monitorPath}");

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
                DiagnosticLogger.Info("WAKEUPNEO", "Started background monitor");
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Warn("WAKEUPNEO", $"Failed to start monitor: {ex.Message}");
            }
        }
        else
        {
            DiagnosticLogger.Info("WAKEUPNEO", "Monitor executable not found, skipping");
        }
    }
}
