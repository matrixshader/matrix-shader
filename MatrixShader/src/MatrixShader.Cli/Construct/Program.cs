using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.Construct;

/// <summary>
/// construct - Enter the Construct. Pick your reality.
/// Usage: construct [color]  or  construct --color
/// Colors: green, blue, red, purple, gold, teal (default: green)
/// No args = white room color picker (CRT TV experience)
/// </summary>
public static class Program
{
    private static readonly Dictionary<string, MatrixColor> ColorMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["green"] = ColorPresets.Green,
        ["blue"] = ColorPresets.Blue,
        ["red"] = ColorPresets.Red,
        ["purple"] = ColorPresets.Purple,
        ["gold"] = ColorPresets.Gold,
        ["teal"] = ColorPresets.Teal,
    };

    public static int Main(string[] args)
    {
        // Set up DI (shared across both paths)
        var services = new ServiceCollection();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<ITerminalSettingsService, TerminalSettingsService>();
        services.AddSingleton<IIdentityService, IdentityService>();
        services.AddLogging(b => b.SetMinimumLevel(LogLevel.Warning));
        var provider = services.BuildServiceProvider();

        var configService = provider.GetRequiredService<IConfigService>();
        var shaderService = provider.GetRequiredService<IShaderService>();
        var terminalService = provider.GetRequiredService<ITerminalSettingsService>();
        var identityService = provider.GetRequiredService<IIdentityService>();

        // Branch: no args = white room picker, args = direct color launch
        var color = ParseColor(args);

        if (color == null)
        {
            // --help or invalid arg
            ShowHelp();
            return 1;
        }

        if (args.Length == 0)
        {
            // No args: launch white room picker
            return RunWhiteRoom(configService, shaderService, terminalService, identityService);
        }

        // Args provided: direct color launch
        return LaunchWithColor(color.Value, configService, shaderService, terminalService, identityService);
    }

    /// <summary>
    /// Launches a Matrix rain window directly with the specified color.
    /// This is the existing --color path, refactored into its own method.
    /// </summary>
    private static int LaunchWithColor(
        MatrixColor color,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService)
    {
        // Find next available slot (checks running windows via IdentityService)
        var state = configService.LoadState();
        int slot = FindAvailableSlot(state, shaderService, identityService);
        if (slot == -1)
        {
            Console.WriteLine("\x1b[31mAll 8 shader slots are in use. Close a Matrix window first.\x1b[0m");
            return 1;
        }

        // Write shader with requested color
        var config = new ShaderConfig().WithColor(color.R, color.G, color.B);
        if (shaderService.ShaderExists(slot))
        {
            shaderService.WriteConfig(slot, config);
        }
        else
        {
            shaderService.CreateShader(slot, config);
        }

        // Ensure profiles exist in Windows Terminal
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var settings = terminalService.LoadSettings();
        terminalService.CreateMatrixProfiles(settings, 8, shadersDir);

        // Fix Bug 1: Tab color sync -- explicitly set the correct tab color for this slot
        var profileName = $"Matrix-{slot}";
        var profile = terminalService.GetProfile(settings, profileName);
        if (profile != null)
        {
            var (r, g, b) = color.ToRgb();
            var updatedProfile = profile with { TabColor = $"#{r:X2}{g:X2}{b:X2}" };
            terminalService.UpsertProfile(settings, updatedProfile);
        }
        terminalService.SaveSettings(settings);

        // Save state
        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);

        // Launch
        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = wtPath,
                Arguments = $"-p \"{profileName}\"",
                UseShellExecute = true
            };
            Process.Start(psi);

            var (cr, cg, cb) = color.ToRgb();
            Console.WriteLine($"\x1b[38;2;{cr};{cg};{cb}m{color.Name}\x1b[0m Matrix window launched (slot {slot}).");
            ConsoleHelper.ShowCommandBanner();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mFailed to launch Windows Terminal: {ex.Message}\x1b[0m");
            return 1;
        }

        return 0;
    }

    /// <summary>
    /// Runs the white room color picker experience.
    /// Launches a WT window with WhiteRoom.hlsl, runs input loop for arrow keys,
    /// transitions to rain shader on Enter.
    /// </summary>
    private static int RunWhiteRoom(
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService)
    {
        var state = configService.LoadState();
        int slot = FindAvailableSlot(state, shaderService, identityService);
        if (slot == -1)
        {
            Console.WriteLine("\x1b[31mAll 8 shader slots are in use. Close a Matrix window first.\x1b[0m");
            return 1;
        }

        // Deploy WhiteRoom.hlsl to user's shaders directory
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var whiteRoomPath = DeployWhiteRoomShader(shadersDir);
        if (whiteRoomPath == null)
        {
            Console.WriteLine("\x1b[31mFailed to deploy WhiteRoom.hlsl shader.\x1b[0m");
            return 1;
        }

        // Write initial state: STATE=0 (power-on), SELECTED=0, STATE_TIME=0.0
        WriteWhiteRoomState(whiteRoomPath, state: 0, selected: 0, stateTime: 0.0f);

        // Set up WT profile: WhiteRoom.hlsl at 100% opacity (opaque white void)
        var settings = terminalService.LoadSettings();
        terminalService.CreateMatrixProfiles(settings, 8, shadersDir);

        var profileName = $"Matrix-{slot}";
        var profile = terminalService.GetProfile(settings, profileName);
        if (profile != null)
        {
            var updatedProfile = profile with
            {
                PixelShaderPath = whiteRoomPath,
                Opacity = 100,  // Opaque for white void
                TabColor = "#FFFFFF"  // White tab during selection
            };
            terminalService.UpsertProfile(settings, updatedProfile);
        }
        terminalService.SaveSettings(settings);

        // Launch WT window
        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
        try
        {
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
            Console.WriteLine($"\x1b[31mFailed to launch Windows Terminal: {ex.Message}\x1b[0m");
            return 1;
        }

        // Wait for window to appear and power-on animation to play
        // Power-on animation is 1.2s; allow extra time for WT startup
        Thread.Sleep(1800);

        // Transition to picking state (STATE=1)
        // Use a Stopwatch to track elapsed time for STATE_TIME writes
        var stopwatch = Stopwatch.StartNew();
        WriteWhiteRoomState(whiteRoomPath, state: 1, selected: 0, stateTime: (float)stopwatch.Elapsed.TotalSeconds);

        // Input loop: arrow keys navigate, Enter selects
        int selected = 0;
        Console.CursorVisible = false;

        // Show minimal feedback in the console where construct was run
        Console.WriteLine();
        Console.WriteLine("\x1b[90m White room active. Use arrow keys in the new window to pick a color.\x1b[0m");
        Console.WriteLine("\x1b[90m Press Enter to select, or Escape to cancel.\x1b[0m");
        Console.WriteLine();

        try
        {
            while (true)
            {
                var keyInfo = Console.ReadKey(intercept: true);

                switch (keyInfo.Key)
                {
                    case ConsoleKey.LeftArrow:
                        selected = (selected - 1 + 6) % 6;
                        WriteWhiteRoomState(whiteRoomPath, state: 1, selected, (float)stopwatch.Elapsed.TotalSeconds);
                        break;

                    case ConsoleKey.RightArrow:
                        selected = (selected + 1) % 6;
                        WriteWhiteRoomState(whiteRoomPath, state: 1, selected, (float)stopwatch.Elapsed.TotalSeconds);
                        break;

                    case ConsoleKey.UpArrow:
                        selected = (selected + 3) % 6;  // Jump between rows (0-2 <-> 3-5)
                        WriteWhiteRoomState(whiteRoomPath, state: 1, selected, (float)stopwatch.Elapsed.TotalSeconds);
                        break;

                    case ConsoleKey.DownArrow:
                        selected = (selected + 3) % 6;  // Jump between rows (0-2 <-> 3-5)
                        WriteWhiteRoomState(whiteRoomPath, state: 1, selected, (float)stopwatch.Elapsed.TotalSeconds);
                        break;

                    case ConsoleKey.Enter:
                        // Trigger power-off animation (STATE=2)
                        WriteWhiteRoomState(whiteRoomPath, state: 2, selected, (float)stopwatch.Elapsed.TotalSeconds);

                        // Wait for power-off animation (1.0s) + WT reload margin
                        Thread.Sleep(1200);

                        // Transition to rain shader
                        var selectedColor = ColorPresets.All[selected];
                        TransitionToRain(slot, selected, selectedColor, configService, shaderService, terminalService, shadersDir);

                        var (r, g, b) = selectedColor.ToRgb();
                        Console.WriteLine($"\x1b[38;2;{r};{g};{b}m{selectedColor.Name}\x1b[0m Matrix window launched (slot {slot}).");
                        ConsoleHelper.ShowCommandBanner();
                        return 0;

                    case ConsoleKey.Escape:
                        // Cancel: trigger power-off but don't transition to rain
                        WriteWhiteRoomState(whiteRoomPath, state: 2, selected, (float)stopwatch.Elapsed.TotalSeconds);
                        Thread.Sleep(1200);

                        // Close the WT window by swapping to a non-existent shader or just leaving it dark
                        Console.WriteLine("\x1b[90mCancelled. The white room window will go dark.\x1b[0m");
                        return 0;
                }
            }
        }
        finally
        {
            Console.CursorVisible = true;
        }
    }

    /// <summary>
    /// Writes white room #define values to WhiteRoom.hlsl using regex replacement + atomic write.
    /// This is separate from ShaderService.WriteConfig() which only knows rain shader defines.
    /// </summary>
    private static void WriteWhiteRoomState(string shaderPath, int state, int selected, float stateTime)
    {
        var content = File.ReadAllText(shaderPath);

        // Replace white room-specific defines
        content = Regex.Replace(content, @"(#define\s+STATE\s+)\d+", $"${{1}}{state}");
        content = Regex.Replace(content, @"(#define\s+SELECTED\s+)\d+", $"${{1}}{selected}");
        content = Regex.Replace(content,
            @"(#define\s+STATE_TIME\s+)[\d.]+",
            m => m.Groups[1].Value + stateTime.ToString("F2", CultureInfo.InvariantCulture));

        // Atomic write: write to temp file, then move (same pattern as ShaderService)
        var tempPath = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tempPath, content, new UTF8Encoding(false));
            File.Move(tempPath, shaderPath, overwrite: true);

            // Force-bump timestamp so Windows Terminal's file watcher detects the change
            File.SetLastWriteTimeUtc(shaderPath, DateTime.UtcNow);
        }
        catch
        {
            if (File.Exists(tempPath))
                File.Delete(tempPath);
            throw;
        }
    }

    /// <summary>
    /// Copies WhiteRoom.hlsl from the application directory or installed location
    /// to the user's shaders directory.
    /// </summary>
    /// <returns>Full path to deployed WhiteRoom.hlsl, or null on failure</returns>
    private static string? DeployWhiteRoomShader(string shadersDir)
    {
        var targetPath = Path.Combine(shadersDir, "WhiteRoom.hlsl");

        // If already deployed, return it
        if (File.Exists(targetPath))
            return targetPath;

        // Look for source shader in known locations
        var candidates = new[]
        {
            // Application directory (development/portable)
            Path.Combine(AppContext.BaseDirectory, "shaders", "WhiteRoom.hlsl"),
            // Installed location (Program Files)
            Path.Combine(CliBootstrap.GetInstalledShadersDirectory(), "WhiteRoom.hlsl"),
        };

        var sourcePath = candidates.FirstOrDefault(File.Exists);
        if (sourcePath == null)
            return null;

        try
        {
            // Ensure directory exists
            if (!Directory.Exists(shadersDir))
                Directory.CreateDirectory(shadersDir);

            File.Copy(sourcePath, targetPath, overwrite: true);
            return targetPath;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Transitions the WT profile from WhiteRoom.hlsl to Matrix-{slot}.hlsl rain shader.
    /// Sets opacity to 85%, writes rain shader config with selected color, fixes tab color.
    /// </summary>
    private static void TransitionToRain(
        int slot,
        int colorIndex,
        MatrixColor color,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        string shadersDir)
    {
        // Write rain shader config with selected color
        var config = new ShaderConfig().WithColor(color.R, color.G, color.B);
        if (shaderService.ShaderExists(slot))
        {
            shaderService.WriteConfig(slot, config);
        }
        else
        {
            shaderService.CreateShader(slot, config);
        }

        // Swap profile: shader path to Matrix-{slot}.hlsl, opacity to 85%, correct tab color
        var settings = terminalService.LoadSettings();
        var profileName = $"Matrix-{slot}";
        var profile = terminalService.GetProfile(settings, profileName);
        if (profile != null)
        {
            var rainShaderPath = Path.Combine(shadersDir, $"Matrix-{slot}.hlsl");
            var (r, g, b) = color.ToRgb();

            var updatedProfile = profile with
            {
                PixelShaderPath = rainShaderPath,
                Opacity = 85,
                TabColor = $"#{r:X2}{g:X2}{b:X2}"
            };
            terminalService.UpsertProfile(settings, updatedProfile);
        }
        terminalService.SaveSettings(settings);

        // Save state
        var state = configService.LoadState();
        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);
    }

    /// <summary>
    /// Finds the next available slot (1-8), checking running windows via IdentityService
    /// to avoid profile name collisions. (Fixes Bug 2: duplicate profile naming)
    /// </summary>
    private static int FindAvailableSlot(MatrixState state, IShaderService shaderService, IIdentityService identityService)
    {
        // Get slots currently in use by running Matrix windows
        var usedSlots = new HashSet<int>(identityService.FindMatrixWindows()
            .Where(w => w.ShaderIndex > 0 && !w.IsControlPanel)
            .Select(w => w.ShaderIndex));

        for (int i = 1; i <= 8; i++)
        {
            if (!usedSlots.Contains(i))
                return i;
        }

        return -1;  // All 8 slots occupied by running windows
    }

    private static MatrixColor? ParseColor(string[] args)
    {
        if (args.Length == 0)
            return ColorPresets.Green; // Sentinel value; Main() checks args.Length separately

        if (args.Contains("--help") || args.Contains("-h") || args.Contains("/?"))
            return null;

        foreach (var arg in args)
        {
            if (!arg.StartsWith("--"))
                continue;
            var name = arg.Substring(2);
            if (ColorMap.TryGetValue(name, out var color))
                return color;
        }

        Console.WriteLine($"\x1b[31mUnknown color: {args[0]}\x1b[0m");
        Console.WriteLine();
        return null;
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        Console.WriteLine("\x1b[32m CONSTRUCT\x1b[0m \u2014 Enter the Construct. Pick your reality.");
        Console.WriteLine();
        Console.WriteLine(" Usage: construct          Launch white room color picker");
        Console.WriteLine("        construct --[color] Launch with specific color");
        Console.WriteLine();
        Console.WriteLine(" Colors:");
        foreach (var preset in ColorPresets.All)
        {
            var (r, g, b) = preset.ToRgb();
            Console.WriteLine($"   \x1b[38;2;{r};{g};{b}m--{preset.Name.ToLower(),-12}\x1b[0m {preset.Description}");
        }
        Console.WriteLine();
        Console.WriteLine(" Examples:");
        Console.WriteLine("   construct          White room CRT TV color picker");
        Console.WriteLine("   construct --red    Jack in with red");
        Console.WriteLine("   construct --blue   Jack in with blue");
        Console.WriteLine("   construct --gold   Jack in with gold");
        Console.WriteLine();
    }
}
