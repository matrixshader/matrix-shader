using System.Diagnostics;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.Construct;

/// <summary>
/// construct - Enter the Construct. Pick your reality.
/// Usage: construct [color]  or  construct --color
/// Colors: green, blue, red, purple, gold, teal (default: green)
/// No args = default green (white room picker coming soon)
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
        var color = ParseColor(args);
        if (color == null)
        {
            ShowHelp();
            return 1;
        }

        // Set up minimal DI
        var services = new ServiceCollection();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<ITerminalSettingsService, TerminalSettingsService>();
        services.AddLogging(b => b.SetMinimumLevel(LogLevel.Warning));
        var provider = services.BuildServiceProvider();

        var configService = provider.GetRequiredService<IConfigService>();
        var shaderService = provider.GetRequiredService<IShaderService>();
        var terminalService = provider.GetRequiredService<ITerminalSettingsService>();

        // Find next available slot (1-8)
        var state = configService.LoadState();
        int slot = FindAvailableSlot(state, shaderService);
        if (slot == -1)
        {
            Console.WriteLine("\x1b[31mAll 8 shader slots are in use. Close a Matrix window first.\x1b[0m");
            return 1;
        }

        // Write shader with requested color
        var config = new ShaderConfig().WithColor(color.Value.R, color.Value.G, color.Value.B);
        if (shaderService.ShaderExists(slot))
        {
            shaderService.WriteConfig(slot, config);
        }
        else
        {
            shaderService.CreateShader(slot, config);
        }

        // Ensure profile exists in Windows Terminal
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var settings = terminalService.LoadSettings();
        terminalService.CreateMatrixProfiles(settings, 8, shadersDir);

        // Save state
        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);

        // Launch
        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
        var profileName = $"Matrix-{slot}";

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = wtPath,
                Arguments = $"-p \"{profileName}\"",
                UseShellExecute = true
            };
            Process.Start(psi);

            var (r, g, b) = color.Value.ToRgb();
            Console.WriteLine($"\x1b[38;2;{r};{g};{b}m{color.Value.Name}\x1b[0m Matrix window launched (slot {slot}).");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mFailed to launch Windows Terminal: {ex.Message}\x1b[0m");
            return 1;
        }

        return 0;
    }

    private static MatrixColor? ParseColor(string[] args)
    {
        if (args.Length == 0)
            return ColorPresets.Green; // TODO: white room picker

        if (args.Contains("--help") || args.Contains("-h") || args.Contains("/?"))
            return null;

        foreach (var arg in args)
        {
            // Support both "red" and "--red"
            var name = arg.TrimStart('-');
            if (ColorMap.TryGetValue(name, out var color))
                return color;
        }

        Console.WriteLine($"\x1b[31mUnknown color: {args[0]}\x1b[0m");
        Console.WriteLine();
        return null;
    }

    private static int FindAvailableSlot(MatrixState state, IShaderService shaderService)
    {
        for (int i = 1; i <= 8; i++)
        {
            if (!shaderService.ShaderExists(i))
                return i;
        }

        for (int i = 1; i <= 8; i++)
        {
            if (!state.ShaderConfigs.ContainsKey(i))
                return i;
        }

        return 8;
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        Console.WriteLine("\x1b[32m CONSTRUCT\x1b[0m \u2014 Enter the Construct. Pick your reality.");
        Console.WriteLine();
        Console.WriteLine(" Usage: construct [color]");
        Console.WriteLine();
        Console.WriteLine(" Colors:");
        foreach (var preset in ColorPresets.All)
        {
            var (r, g, b) = preset.ToRgb();
            Console.WriteLine($"   \x1b[38;2;{r};{g};{b}m{preset.Name,-10}\x1b[0m {preset.Description}");
        }
        Console.WriteLine();
        Console.WriteLine(" Examples:");
        Console.WriteLine("   construct          Launch with green (default)");
        Console.WriteLine("   construct red      Jack in with red");
        Console.WriteLine("   construct --blue   Jack in with blue");
        Console.WriteLine("   construct gold     Jack in with gold");
        Console.WriteLine();
    }
}
