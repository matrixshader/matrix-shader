using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Startup;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.Construct;

/// <summary>
/// construct - Enter the Construct. Pick your reality.
/// No args = white room color picker (CRT TV experience)
/// --pick = internal: run picker input loop inside WT window
/// --color = direct launch with specific color
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
        try
        {
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

            if (args.Length >= 1 && args[0] == "--pick")
            {
                return RunPicker(configService, shaderService, terminalService, identityService);
            }

            var color = ParseColor(args);
            if (color == null) { ShowHelp(); return 1; }

            if (args.Length == 0)
                return RunWhiteRoom(terminalService);

            return LaunchWithColor(color.Value, configService, shaderService, terminalService, identityService);
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("CONSTRUCT", $"Unhandled exception: {ex.Message}");
            MatrixErrorHandler.ShowError(ex.Message);
            return 1;
        }
    }

    private static int LaunchWithColor(
        MatrixColor color,
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

        var config = new ShaderConfig().WithColor(color.R, color.G, color.B);
        if (shaderService.ShaderExists(slot))
            shaderService.WriteConfig(slot, config);
        else
            shaderService.CreateShader(slot, config);

        var shadersDir = CliBootstrap.GetShadersDirectory();
        var settings = terminalService.LoadSettings();
        terminalService.CreateMatrixProfiles(settings, 8, shadersDir);

        var profileName = $"Matrix-{slot}";
        var profile = terminalService.GetProfile(settings, profileName);
        if (profile != null)
        {
            var (r, g, b) = color.ToRgb();
            terminalService.UpsertProfile(settings, profile with { TabColor = $"#{r:X2}{g:X2}{b:X2}" });
        }
        terminalService.SaveSettings(settings);

        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);

        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
        try
        {
            Process.Start(new ProcessStartInfo { FileName = wtPath, Arguments = $"-p \"{profileName}\"", UseShellExecute = true });
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

    private static int RunWhiteRoom(ITerminalSettingsService terminalService)
    {
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var whiteRoomPath = DeployWhiteRoomShader(shadersDir);
        if (whiteRoomPath == null)
        {
            Console.WriteLine("\x1b[31mFailed to deploy WhiteRoom.hlsl shader.\x1b[0m");
            return 1;
        }

        // Write initial state: STATE=1 (picking mode)
        WriteShaderState(whiteRoomPath, state: 1, stateTime: 0.0f);

        var exePath = Process.GetCurrentProcess().MainModule?.FileName
                      ?? Path.Combine(AppContext.BaseDirectory, "construct.exe");

        var settings = terminalService.LoadSettings();
        var existing = terminalService.GetProfile(settings, "Construct");
        var constructProfile = new TerminalProfile
        {
            Name = "Construct",
            Guid = existing?.Guid ?? $"{{{Guid.NewGuid()}}}",
            Commandline = $"\"{exePath}\" --pick",
            Hidden = true,
            Opacity = 100,
            UseAcrylic = false,
            PixelShaderPath = whiteRoomPath,
            TabColor = "#FFFFFF",
            SuppressApplicationTitle = true
        };
        terminalService.UpsertProfile(settings, constructProfile);
        terminalService.SaveSettings(settings);

        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = wtPath,
                Arguments = "-p \"Construct\"",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mFailed to launch Windows Terminal: {ex.Message}\x1b[0m");
            return 1;
        }
        return 0;
    }

    /// <summary>
    /// Picker input loop — runs INSIDE the WT window (launched via --pick).
    /// Selection is communicated to the shader via ANSI-colored terminal output,
    /// not via file writes. The shader reads shaderTexture to determine selection.
    /// </summary>
    private static int RunPicker(
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService)
    {
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var whiteRoomPath = Path.Combine(shadersDir, "WhiteRoom.hlsl");
        if (!File.Exists(whiteRoomPath)) return 1;

        int selected = 0;
        try { Console.CursorVisible = false; } catch { }

        // --- Zoom-in animation: TV starts small/far, approaches viewer ---
        // 1.5 seconds, ease-out curve, ~60fps
        var sw = Stopwatch.StartNew();
        const double zoomDurationMs = 1500.0;
        while (sw.ElapsedMilliseconds < zoomDurationMs)
        {
            double t = sw.ElapsedMilliseconds / zoomDurationMs;
            // Ease-out cubic: fast start, gentle arrival
            double eased = 1.0 - Math.Pow(1.0 - t, 3.0);
            int zoomByte = (int)(eased * 255.0);
            WritePickerState(selected, zoomByte);
            Thread.Sleep(16); // ~60fps
        }
        // Ensure we land exactly at full zoom
        WritePickerState(selected, 255);

        try
        {
            while (true)
            {
                var keyInfo = Console.ReadKey(intercept: true);
                switch (keyInfo.Key)
                {
                    case ConsoleKey.LeftArrow:
                        selected = (selected - 1 + 6) % 6;
                        break;
                    case ConsoleKey.RightArrow:
                        selected = (selected + 1) % 6;
                        break;
                    case ConsoleKey.UpArrow:
                    case ConsoleKey.DownArrow:
                        selected = (selected + 3) % 6;
                        break;
                    case ConsoleKey.Enter:
                        // Check slot availability BEFORE starting the irreversible animation
                        var preState = configService.LoadState();
                        int slot = FindAvailableSlot(preState, shaderService, identityService);
                        if (slot == -1)
                        {
                            // All 8 slots full — flash error and continue picking
                            continue;
                        }

                        // CRT power-off animation via shaderTexture
                        AnimatePowerOff(selected);

                        // Same-window transition (no new window!)
                        var selectedColor = ColorPresets.All[selected];
                        TransitionToRain(selectedColor, slot, configService, shaderService,
                                         terminalService, identityService, shadersDir);
                        return 0;

                    case ConsoleKey.Escape:
                        AnimatePowerOff(selected);
                        return 0;

                    default:
                        continue;
                }

                // Instant: write state to terminal — shader reads it next frame
                WritePickerState(selected, 255);
            }
        }
        finally
        {
            try { Console.CursorVisible = true; } catch { }
        }
    }

    /// <summary>
    /// Writes picker state to the terminal as ANSI-colored background blocks.
    /// The shader samples shaderTexture at the top-left to read state.
    /// Encoding:
    ///   R = (selected+1) * 40  (values: 40, 80, 120, 160, 200, 240)
    ///   G = zoom byte 0-255    (0 = far/small, 255 = close/full size)
    ///   B = power-off byte 0-255 (0 = normal, 255 = fully black)
    /// </summary>
    private static void WritePickerState(int selected, int zoomByte, int powerOffByte = 0)
    {
        int r = (selected + 1) * 40;
        int g = Math.Clamp(zoomByte, 0, 255);
        int b = Math.Clamp(powerOffByte, 0, 255);
        Console.Write($"\x1b[H\x1b[48;2;{r};{g};{b}m{new string(' ', 80)}\x1b[0m");
    }

    /// <summary>
    /// Animates CRT power-off: zoom shrinks to a point while brightness fades to black.
    /// Driven entirely via shaderTexture (G=zoom, B=brightness), no file writes needed.
    /// </summary>
    private static void AnimatePowerOff(int selected)
    {
        var sw = Stopwatch.StartNew();
        const double durationMs = 1000.0;
        while (sw.ElapsedMilliseconds < durationMs)
        {
            double t = sw.ElapsedMilliseconds / durationMs;
            // Ease-in: slow start, accelerates (CRT shrink feel)
            double eased = t * t;
            // Zoom shrinks from 255 (full) to ~20 (tiny point)
            int zoomByte = (int)(255.0 * (1.0 - eased * 0.92));
            // Brightness fades: starts fading at t=0.4, fully black by t=1.0
            double fadeT = Math.Clamp((t - 0.4) / 0.6, 0.0, 1.0);
            int powerByte = (int)(fadeT * 255.0);
            WritePickerState(selected, zoomByte, powerByte);
            Thread.Sleep(16);
        }
        // Hold black
        WritePickerState(selected, 0, 255);
        Thread.Sleep(200);
    }

    /// <summary>
    /// Performs same-window transition from Construct white room to Matrix rain.
    /// Modifies the Construct profile IN PLACE in settings.json — swapping the shader
    /// path, opacity, and tab color. WT detects the change and loads the new shader
    /// into the already-open window. The profile name stays "Construct" to avoid
    /// GUID conflicts with UpsertProfile.
    /// </summary>
    private static void TransitionToRain(
        MatrixColor color,
        int slot,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService,
        string shadersDir)
    {
        // 1. Create/configure the rain shader file for this slot
        var config = new ShaderConfig().WithColor(color.R, color.G, color.B);
        if (shaderService.ShaderExists(slot))
            shaderService.WriteConfig(slot, config);
        else
            shaderService.CreateShader(slot, config);

        // 2. Modify the Construct profile IN PLACE in settings.json
        //    CRITICAL: Keep Name = "Construct" -- UpsertProfile matches by name.
        //    Renaming to "Matrix-{slot}" would find the Matrix-{slot} template
        //    (different GUID), overwrite it, and leave the Construct profile
        //    untouched — causing a duplicate GUID conflict.
        var settings = terminalService.LoadSettings();

        // Ensure Matrix profiles exist (creates templates if missing)
        terminalService.CreateMatrixProfiles(settings, 8, shadersDir);

        // Get the Construct profile and swap its visual properties
        var constructProfile = terminalService.GetProfile(settings, "Construct");
        if (constructProfile != null)
        {
            var (r, g, b) = color.ToRgb();
            var transitioned = constructProfile with
            {
                PixelShaderPath = Path.Combine(shadersDir, $"Matrix-{slot}.hlsl"),
                Opacity = 85,
                UseAcrylic = false,
                TabColor = $"#{r:X2}{g:X2}{b:X2}",
            };
            terminalService.UpsertProfile(settings, transitioned);
        }

        terminalService.SaveSettings(settings);

        // 3. Persist shader state
        var state = configService.LoadState();
        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);

        // 4. Register window identity so Redpill and hotkeys can find it
        var hwnd = WindowsApi.GetForegroundWindow();
        if (hwnd != nint.Zero)
        {
            identityService.RegisterWindowHandle(hwnd, $"Matrix-{slot}", slot);
        }

        // 5. Wait for WT to detect settings.json change and load new shader
        //    Screen is black, so this delay is invisible to user
        Thread.Sleep(500);
    }

    /// <summary>
    /// Write STATE and STATE_TIME to shader file (only for state transitions like power-off).
    /// Selection is handled via terminal output, not file writes.
    /// </summary>
    private static void WriteShaderState(string shaderPath, int state, float stateTime)
    {
        var content = File.ReadAllText(shaderPath);
        content = Regex.Replace(content, @"(#define\s+STATE\s+)\d+", $"${{1}}{state}");
        content = Regex.Replace(content,
            @"(#define\s+STATE_TIME\s+)[\d.]+",
            m => m.Groups[1].Value + stateTime.ToString("F2", CultureInfo.InvariantCulture));

        var tempPath = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tempPath, content, new UTF8Encoding(false));
            File.Move(tempPath, shaderPath, overwrite: true);
            File.SetLastWriteTimeUtc(shaderPath, DateTime.UtcNow);
        }
        catch
        {
            if (File.Exists(tempPath)) File.Delete(tempPath);
            throw;
        }
    }

    private static string? DeployWhiteRoomShader(string shadersDir)
    {
        var targetPath = Path.Combine(shadersDir, "WhiteRoom.hlsl");
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "shaders", "WhiteRoom.hlsl"),
            Path.Combine(CliBootstrap.GetInstalledShadersDirectory(), "WhiteRoom.hlsl"),
        };
        var sourcePath = candidates.FirstOrDefault(File.Exists);
        if (sourcePath == null)
            return File.Exists(targetPath) ? targetPath : null;
        try
        {
            if (!Directory.Exists(shadersDir)) Directory.CreateDirectory(shadersDir);
            File.Copy(sourcePath, targetPath, overwrite: true);
            return targetPath;
        }
        catch { return File.Exists(targetPath) ? targetPath : null; }
    }

    private static float GetApproxShaderTime()
    {
        foreach (var name in new[] { "WindowsTerminal", "WindowsTerminalPreview" })
        {
            var procs = Process.GetProcessesByName(name);
            if (procs.Length > 0)
                return (float)(DateTime.UtcNow - procs[0].StartTime.ToUniversalTime()).TotalSeconds;
        }
        return 0f;
    }

    private static int FindAvailableSlot(MatrixState state, IShaderService shaderService, IIdentityService identityService)
    {
        var usedSlots = new HashSet<int>(identityService.FindMatrixWindows()
            .Where(w => w.ShaderIndex > 0 && !w.IsControlPanel)
            .Select(w => w.ShaderIndex));
        for (int i = 1; i <= 8; i++)
            if (!usedSlots.Contains(i)) return i;
        return -1;
    }

    private static MatrixColor? ParseColor(string[] args)
    {
        if (args.Length == 0) return ColorPresets.Green;
        if (args.Contains("--help") || args.Contains("-h") || args.Contains("/?")) return null;
        foreach (var arg in args)
        {
            if (!arg.StartsWith("--")) continue;
            var name = arg.Substring(2);
            if (ColorMap.TryGetValue(name, out var color)) return color;
        }
        Console.WriteLine($"\x1b[31mUnknown color: {args[0]}\x1b[0m");
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
    }
}
