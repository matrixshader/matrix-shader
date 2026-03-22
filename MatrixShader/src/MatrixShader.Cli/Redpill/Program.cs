using System.Diagnostics;
using System.Text;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
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
    /// <summary>
    /// Checks if currently running in the Redpill WT profile.
    /// </summary>
    private static bool IsRunningInRedpillProfile()
    {
        // Check if WT_PROFILE_ID contains "Redpill" (set by WT when using named profile)
        var profileId = Environment.GetEnvironmentVariable("WT_PROFILE_ID");
        if (!string.IsNullOrEmpty(profileId) &&
            profileId.Contains("Redpill", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Fallback: check window title contains "Redpill"
        try
        {
            var title = Console.Title;
            if (title.Contains("Redpill", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        catch { }

        return false;
    }

    public static async Task<int> Main(string[] args)
    {
        // Handle --activate before anything else (no splash, no relaunch)
        if (args.Length >= 2 && args[0] == "--activate")
        {
            return HandleActivation(args[1]);
        }

        // Self-launch: If running in WT but not in Redpill profile, open new WT window with Redpill profile
        // Skip self-launch for help/hotkeys/no-relaunch modes
        if (!args.Contains("--help") && !args.Contains("--hotkeys") && !args.Contains("--no-relaunch"))
        {
            // Check if we're in WT but NOT in Redpill profile
            if (EnvironmentService.IsWindowsTerminal() && !IsRunningInRedpillProfile())
            {
                // Launch new WT window with Redpill profile
                var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
                try
                {
                    var psi = new ProcessStartInfo
                    {
                        FileName = wtPath,
                        Arguments = "-p \"Redpill\"",
                        UseShellExecute = true
                    };
                    Process.Start(psi);

                    // Exit current instance - the new window will run redpill
                    return 0;
                }
                catch (Exception ex)
                {
                    DiagnosticLogger.Debug("REDPILL", $"Self-launch failed: {ex.Message}");
                    // Fall through to run in current window if launch fails
                }
            }
        }

        // Skip splash for help or hotkeys config mode
        if (!args.Contains("--help") && !args.Contains("--hotkeys"))
        {
            await MatrixSplash.ShowAsync();
        }

        try
        {
            // License check — gate Red Pill behind valid license
            if (!args.Contains("--help"))
            {
                var licenseService = new LicenseService();
                if (!licenseService.IsLicensed)
                {
                    ShowPurchasePrompt();

                    // Show hotkey hint since hotkeys still work in free mode
                    Console.WriteLine(" \x1b[36mPress Ctrl+Shift+H for hotkey help\x1b[0m");
                    Console.WriteLine();

                    // Interactive activation — let them paste a key right here
                    Console.Write(" \x1b[36mAlready have a key? Paste it here (or press Enter to close): \x1b[0m");
                    var input = Console.ReadLine()?.Trim();
                    if (!string.IsNullOrEmpty(input))
                    {
                        return HandleActivation(input);
                    }
                    return 0;
                }
            }

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
                // Launch hotkeys background process
                LaunchHotkeysProcess();

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
        ConsoleHelper.WriteLineDim("   --help         Show this help message");
        ConsoleHelper.WriteLineDim("   --activate KEY Activate Red Pill license (REDPILL-XXXX-XXXX-XXXX-XXXX)");
        ConsoleHelper.WriteLineDim("   --hotkeys      Configure global hotkey bindings");
        ConsoleHelper.WriteLineDim("   --debug        Enable diagnostic logging");
        ConsoleHelper.WriteLineDim("   --no-relaunch  Stay in current window (don't open Redpill profile)");
        ConsoleHelper.WriteLineDim("   --morpheus     Philosophical explanations");
        ConsoleHelper.WriteLineDim("   --agent-smith  Chaos mode");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Global Hotkeys (press [?] in control panel for list):");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+L   Cycle layout mode");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+B   Toggle background transparency");
        ConsoleHelper.WriteLineDim("   ... and more - see [?] in control panel");
        Console.WriteLine();
    }

    /// <summary>
    /// Handles --activate REDPILL-XXXX-XXXX-XXXX-XXXX license activation.
    /// </summary>
    private static int HandleActivation(string key)
    {
        ConsoleHelper.EnableAnsiEscapeCodes();
        Console.WriteLine();

        var licenseService = new LicenseService();
        var result = licenseService.Activate(key);

        switch (result)
        {
            case ActivationResult.Success:
                ConsoleHelper.WriteLineMatrixGreen(" Welcome to the real world.");
                Console.WriteLine();
                ConsoleHelper.WriteLineDim(" License activated. Run 'redpill' to open the control panel.");
                Console.WriteLine();
                return 0;

            case ActivationResult.ActivationLimitExceeded:
                Console.WriteLine(" \x1b[31mActivation limit reached.\x1b[0m");
                Console.WriteLine();
                ConsoleHelper.WriteLineDim(" This key has been activated on too many machines.");
                ConsoleHelper.WriteLineDim(" If this is your key, contact support for help.");
                Console.WriteLine();
                return 1;

            case ActivationResult.ServerUnreachable:
                Console.WriteLine(" \x1b[33mCouldn't reach the activation server.\x1b[0m");
                Console.WriteLine();
                ConsoleHelper.WriteLineDim(" An internet connection is required for first-time activation.");
                ConsoleHelper.WriteLineDim(" After that, your license works fully offline — no phone-home ever.");
                ConsoleHelper.WriteLineDim(" Check your connection and try again.");
                Console.WriteLine();
                return 1;

            default:
                Console.WriteLine(" \x1b[31mInvalid license key.\x1b[0m");
                Console.WriteLine();
                ConsoleHelper.WriteLineDim(" Format: REDPILL-XXXX-XXXX-XXXX-XXXX");
                ConsoleHelper.WriteLineDim(" Get your key at: https://matrixshader.com/redpill");
                Console.WriteLine();
                return 1;
        }
    }

    /// <summary>
    /// Shows Matrix-styled purchase prompt when Red Pill is not licensed.
    /// </summary>
    private static void ShowPurchasePrompt()
    {
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" THE RED PILL");
        ConsoleHelper.WriteLineDim(" ----------------------------------------");
        Console.WriteLine();

        ConsoleHelper.WriteLineDim(" The Red Pill unlocks the full control panel:");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim("   - Live parameter adjustment (speed, glow, width, trail, density)");
        ConsoleHelper.WriteLineDim("   - Custom RGB color picker (any color, not just presets)");
        ConsoleHelper.WriteLineDim("   - Per-window layer toggles (Far/Mid/Near)");
        ConsoleHelper.WriteLineDim("   - Multi-tab management (up to 8 shader configs)");
        ConsoleHelper.WriteLineDim("   - Layout mode controls (Pillars/Quads/Auto)");
        ConsoleHelper.WriteLineDim("   - Snapback position save/restore");
        ConsoleHelper.WriteLineDim("   - Hotkey configuration (remap bindings)");
        ConsoleHelper.WriteLineDim("   - Neo vision shader background");
        Console.WriteLine();

        Console.WriteLine(" \x1b[33m$5 — one-time purchase, yours forever.\x1b[0m");
        Console.WriteLine();
        Console.WriteLine(" \x1b]8;;https://matrixshader.com/redpill\x07\x1b[36mmatrixshader.com/redpill\x1b[0m\x1b]8;;\x07");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Already purchased? Activate with:");
        ConsoleHelper.WriteLineDim("   redpill --activate REDPILL-XXXX-XXXX-XXXX-XXXX");
        Console.WriteLine();

        // Open the Redpill purchase page in the default browser
        try
        {
            Process.Start(new ProcessStartInfo("https://matrixshader.com/redpill") { UseShellExecute = true });
        }
        catch { /* Non-fatal — terminal link is the fallback */ }
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
                DiagnosticLogger.Debug("REDPILL", "matrix-hotkeys.exe not found, skipping hotkey launch");
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

            var process = Process.Start(startInfo);
            if (process == null)
            {
                DiagnosticLogger.ProductionError("REDPILL", $"Failed to start: {hotkeyExe}");
                return;
            }
            DiagnosticLogger.Debug("REDPILL", $"Launched hotkeys process: {hotkeyExe}");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("REDPILL", $"Failed to launch hotkeys: {ex.Message}");
            // Non-fatal - Matrix works without hotkeys
        }
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
            ConsoleHelper.ShowCommandBanner();
            Console.WriteLine();
        }

        return Task.CompletedTask;
    }

    private void Render()
    {
        var cw = TuiRenderer.ClearWidth;
        var sb = new StringBuilder(cw * 35); // Pre-allocate for ~35 lines
        var config = _tabManager.CurrentConfig;

        // Header with dirty indicator
        TuiRenderer.AppendPaddedLine(sb, cw, "");
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatHeader(_tabManager.CurrentSlot, _tabManager.IsDirty));
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Tab bar
        var tabs = _tabManager.GetTabsForRendering();
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatTabBar(tabs, _tabManager.CurrentSlot));
        TuiRenderer.AppendPaddedLine(sb, cw, " [TAB] next tab");
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Agent colors (presets)
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatSectionHeader("AGENT COLORS"));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatColorPresets());
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Current color with swatch
        TuiRenderer.AppendPaddedLine(sb, cw, $" CURRENT {TuiRenderer.ColorSwatch(config.R, config.G, config.B, 3)}");
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("Q/W", "Red", config.R.ToString("F1"), config.R, 0, 1));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("A/S", "Green", config.G.ToString("F1"), config.G, 0, 1));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("Z/X", "Blue", config.B.ToString("F1"), config.B, 0, 1));
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Rain parameters
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatSectionHeader("RAIN PARAMETERS"));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("E/R", "Speed", config.Speed.ToString("F1"), config.Speed, 0.1f, 5f));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("D/F", "Glow", config.Glow.ToString("F1"), config.Glow, 0.2f, 3f));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("C/V", "Width", config.Width.ToString("F0"), config.Width, 6f, 20f));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("T/Y", "Trail", config.Trail.ToString("F0"), config.Trail, 4f, 15f));
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatParameterRow("G/H", "Density", config.Density.ToString("F1"), config.Density, 0.2f, 1f));
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Layers
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatSectionHeader("LAYERS"));
        var layerLine = TuiRenderer.FormatLayerStatus("7", "Far", config.Layer1)
            + "  " + TuiRenderer.FormatLayerStatus("8", "Mid", config.Layer2)
            + "  " + TuiRenderer.FormatLayerStatus("9", "Near", config.Layer3);
        TuiRenderer.AppendPaddedLine(sb, cw, layerLine);
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Window effects
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatSectionHeader("WINDOW EFFECTS"));
        var transStatus = _transparency ? "ON " : "off";
        var transColor = _transparency ? TuiRenderer.CYAN : TuiRenderer.GRAY;
        TuiRenderer.AppendPaddedLine(sb, cw, $" [B] Transparency:  {transColor}{transStatus}{TuiRenderer.RESET}  {TuiRenderer.GRAY}(toggles & applies){TuiRenderer.RESET}");
        if (_transparency)
        {
            TuiRenderer.AppendPaddedLine(sb, cw, $" [K/L] Opacity:     {_opacity,3}% {TuiRenderer.ProgressBar(_opacity, 0, 100)}");
        }
        else
        {
            TuiRenderer.AppendPaddedLine(sb, cw, "");
        }

        // Combat training (Glitch)
        var state = _configService.LoadState();
        var glitchEnabled = state.Layout.GlitchEnabled;
        var glitchStatus = glitchEnabled ? "ON " : "off";
        var glitchColor = glitchEnabled ? TuiRenderer.CYAN : TuiRenderer.GRAY;
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatSectionHeader("COMBAT TRAINING"));
        TuiRenderer.AppendPaddedLine(sb, cw, $" [Shift+G] Glitch:  {glitchColor}{glitchStatus}{TuiRenderer.RESET}  {TuiRenderer.GRAY}(windows auto-snap to formation){TuiRenderer.RESET}");

        // Layout mode
        var layoutMode = state.Layout.Mode;
        var layoutColor = layoutMode.Equals("pillars", StringComparison.OrdinalIgnoreCase) ? TuiRenderer.YELLOW : TuiRenderer.MAGENTA;
        TuiRenderer.AppendPaddedLine(sb, cw, $" [Shift+L] Layout:  {layoutColor}{layoutMode}{TuiRenderer.RESET}  {TuiRenderer.GRAY}(Pillars=columns, Quads=2x2){TuiRenderer.RESET}");
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Deploy section
        TuiRenderer.AppendPaddedLine(sb, cw, $" {TuiRenderer.MAGENTA}DEPLOY{TuiRenderer.RESET}");
        var openWindows = _identityService.FindMatrixWindows();
        var openStr = openWindows.Count > 0
            ? string.Join(",", openWindows.Select(w => w.ShaderIndex))
            : "none";
        TuiRenderer.AppendPaddedLine(sb, cw, $" {TuiRenderer.GRAY}Open:{TuiRenderer.RESET} {TuiRenderer.GREEN}{openStr}{TuiRenderer.RESET}");

        var launchStatus = _launchCount > 0 ? $"{_launchCount} window(s)" : "disabled";
        var launchColor2 = _launchCount > 0 ? TuiRenderer.MAGENTA : TuiRenderer.GRAY;
        TuiRenderer.AppendPaddedLine(sb, cw, $" [-/+] Count: {launchColor2}{launchStatus}{TuiRenderer.RESET}");
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        // Footer
        TuiRenderer.AppendFooter(sb, cw, _launchCount, _launchCount > 0, glitchEnabled);

        // Count actual lines written and fill remaining visible rows with blanks
        var linesWritten = 0;
        for (int i = 0; i < sb.Length; i++)
            if (sb[i] == '\n') linesWritten++;
        var maxRows = Console.WindowHeight;
        var remaining = maxRows - linesWritten - 1; // -1 to avoid scroll on last row
        if (remaining > 0)
        {
            TuiRenderer.AppendBlankLines(sb, cw, remaining);
        }

        // ANSI cursor home (viewport-relative, not buffer-relative)
        // Console.SetCursorPosition(0,0) uses buffer coords which break after scroll
        Console.Write("\x1b[H");
        Console.Write(sb.ToString());
    }

    /// <summary>
    /// Shows the hotkey help screen with all available key bindings.
    /// </summary>
    private void ShowHotkeyHelp()
    {
        Console.Clear();
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" HOTKEY HELP");
        Console.WriteLine();

        ConsoleHelper.WriteLineDim(" CONTROL PANEL KEYS (local):");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim("   [1-6]      Agent colors (Green/Blue/Red/Purple/Gold/Teal)");
        ConsoleHelper.WriteLineDim("   [Q/W]      Red -/+          [A/S] Green -/+    [Z/X] Blue -/+");
        ConsoleHelper.WriteLineDim("   [E/R]      Speed -/+        [D/F] Glow -/+");
        ConsoleHelper.WriteLineDim("   [C/V]      Width -/+        [T/Y] Trail -/+    [G/H] Density -/+");
        ConsoleHelper.WriteLineDim("   [7/8/9]    Toggle layers (Far/Mid/Near)");
        ConsoleHelper.WriteLineDim("   [B]        Toggle transparency    [K/L] Opacity -/+");
        ConsoleHelper.WriteLineDim("   [-/+]      Deploy count -/+       [ENTER] Deploy windows");
        ConsoleHelper.WriteLineDim("   [0]        Reset to defaults       (all changes apply instantly)");
        ConsoleHelper.WriteLineDim("   [TAB]      Switch tabs            [ESC] Quit");
        Console.WriteLine();

        ConsoleHelper.WriteLineDim(" SHIFT KEYS (local):");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim("   [Shift+G]  Toggle Glitch (auto-snap to formation)");
        ConsoleHelper.WriteLineDim("   [Shift+L]  Cycle layout mode (Pillars/Quads/Overlap)");
        ConsoleHelper.WriteLineDim("   [Shift+H]  Configure global hotkey bindings");
        ConsoleHelper.WriteLineDim("   [Shift+S]  Save snapback position");
        ConsoleHelper.WriteLineDim("   [Shift+R]  Restore snapback position");
        Console.WriteLine();

        ConsoleHelper.WriteLineMatrixGreen(" GLOBAL HOTKEYS (active when Matrix windows exist):");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+L       Cycle layout mode");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+B       Toggle background transparency");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+K/O     Decrease/Increase opacity");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+Up/Down Cycle shader in library");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+, / .   Decrease/Increase rain speed");
        ConsoleHelper.WriteLineDim("   Ctrl+Shift+1/2/3   Toggle FAR/MID/NEAR layers");
        Console.WriteLine();

        ConsoleHelper.WriteLineDim(" Press [Shift+H] to customize global hotkey bindings.");
        Console.WriteLine();
        Console.Write(" Press any key to return...");
        Console.ReadKey(intercept: true);
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
            case KeyAction.PresetBlue:
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

            // Reset
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
                // Save current window positions + working directories
                {
                    var snapWindows = _identityService.FindMatrixWindows()
                        .Where(w => w.ShaderIndex > 0 && !w.IsControlPanel && !w.IsConstruct)
                        .ToList();
                    var snapState = _configService.LoadState();
                    var snapPositions = _layoutService.CalculateLayout(snapWindows, snapState.Layout);
                    _layoutService.SaveWindowSlots(snapPositions);

                    // Also save working directories by reading window titles
                    foreach (var w in snapWindows)
                    {
                        var cwd = WindowsApi.GetWorkingDirectoryFromTitle(w.Handle);
                        if (cwd != null)
                        {
                            var slotKey = $"slot-{w.ShaderIndex}";
                            var existingSlot = snapState.WindowSlots.GetValueOrDefault(slotKey);
                            if (existingSlot != null)
                            {
                                snapState.WindowSlots[slotKey] = existingSlot with { WorkingDirectory = cwd };
                            }
                        }
                    }
                    _configService.SaveState(snapState);
                    DiagnosticLogger.Info("REDPILL", $"Saved {snapPositions.Count} window positions with working directories");
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

            case KeyAction.Help:
                // Show hotkey help screen (?)
                ShowHotkeyHelp();
                Console.Clear();
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
                var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
                var psi = new ProcessStartInfo
                {
                    FileName = wtPath,
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
