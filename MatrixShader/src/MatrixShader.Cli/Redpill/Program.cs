using MatrixShader.Core.Constants;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Lite;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Spectre.Console;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// Matrix Shader Control Panel - Full TUI with shader control.
/// </summary>
public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        // Setup DI
        var services = new ServiceCollection();
        ConfigureServices(services);
        var provider = services.BuildServiceProvider();

        var logger = provider.GetRequiredService<ILogger<ControlPanel>>();
        var envService = provider.GetRequiredService<EnvironmentService>();

        // Detect render mode
        var mode = envService.DetectRenderMode();

        logger.LogInformation("Starting Matrix Shader in {Mode} mode", mode);

        try
        {
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
                AnsiConsole.MarkupLine("[red]No display available. Use --help for options.[/]");
                return 1;
            }

            return 0;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception");
            AnsiConsole.WriteException(ex);
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

        services.AddSingleton<EnvironmentService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<ControlPanel>();
    }
}

/// <summary>
/// Full-featured control panel for shader mode.
/// </summary>
public class ControlPanel
{
    private readonly IShaderService _shaderService;
    private readonly IConfigService _configService;
    private readonly ILogger<ControlPanel> _logger;
    private MatrixState _state;
    private bool _dirty;
    private bool _running = true;

    public ControlPanel(
        IShaderService shaderService,
        IConfigService configService,
        ILogger<ControlPanel> logger)
    {
        _shaderService = shaderService;
        _configService = configService;
        _logger = logger;
        _state = _configService.LoadState();
    }

    public async Task RunAsync()
    {
        Console.CursorVisible = false;
        Console.Clear();

        while (_running)
        {
            Render();

            if (Console.KeyAvailable)
            {
                var key = Console.ReadKey(intercept: true);
                HandleKey(key);
            }

            await Task.Delay(50);
        }

        // Save on exit
        if (_dirty)
        {
            _configService.SaveState(_state);
        }

        Console.CursorVisible = true;
        Console.Clear();
    }

    private void Render()
    {
        Console.SetCursorPosition(0, 0);

        var config = GetCurrentConfig();

        // Header
        AnsiConsole.Write(new Rule("[green]MATRIX SHADER CONTROL PANEL[/]").RuleStyle("green"));

        // Tab bar
        var tabs = new Table().Border(TableBorder.None).HideHeaders();
        tabs.AddColumn("");
        var tabRow = new List<string>();
        for (int i = 1; i <= 8; i++)
        {
            if (i == _state.ActiveTab)
                tabRow.Add($"[black on green] {i} [/]");
            else if (_shaderService.ShaderExists(i))
                tabRow.Add($"[green] {i} [/]");
            else
                tabRow.Add($"[dim] {i} [/]");
        }
        tabs.AddRow(string.Join(" ", tabRow));
        AnsiConsole.Write(tabs);

        Console.WriteLine();

        // Color preview
        var colorTable = new Table().Border(TableBorder.Rounded);
        colorTable.AddColumn(new TableColumn("[green]COLOR PRESETS[/]").Centered());
        colorTable.AddRow("[green]1[/] Green  [cyan]2[/] Cyan  [red]3[/] Red");
        colorTable.AddRow("[magenta]4[/] Purple [yellow]5[/] Gold  [teal]6[/] Teal");
        AnsiConsole.Write(colorTable);

        Console.WriteLine();

        // Current values
        var valueTable = new Table().Border(TableBorder.Rounded);
        valueTable.AddColumn("Parameter");
        valueTable.AddColumn("Value");
        valueTable.AddColumn("Keys");

        valueTable.AddRow("Speed", $"{config.Speed:F1}", "[E] - / [R] +");
        valueTable.AddRow("Glow", $"{config.Glow:F1}", "[G] - / [H] +");
        valueTable.AddRow("Width", $"{config.Width:F0}", "[W] - / [T] +");
        valueTable.AddRow("Trail", $"{config.Trail:F0}", "[Y] - / [U] +");
        valueTable.AddRow("Density", $"{config.Density:F1}", "[D] - / [F] +");
        valueTable.AddRow("Layer 1", config.Layer1 ? "[green]ON[/]" : "[dim]OFF[/]", "[7]");
        valueTable.AddRow("Layer 2", config.Layer2 ? "[green]ON[/]" : "[dim]OFF[/]", "[8]");
        valueTable.AddRow("Layer 3", config.Layer3 ? "[green]ON[/]" : "[dim]OFF[/]", "[9]");

        AnsiConsole.Write(valueTable);

        Console.WriteLine();

        // Controls
        AnsiConsole.MarkupLine("[dim]Tab: 1-8 | Save: S | Layout: L | Quit: Q[/]");

        if (_dirty)
        {
            AnsiConsole.MarkupLine("[yellow]* Unsaved changes[/]");
        }
    }

    private void HandleKey(ConsoleKeyInfo key)
    {
        var config = GetCurrentConfig();

        switch (key.Key)
        {
            // Tab switching (1-8)
            case ConsoleKey.D1 or ConsoleKey.NumPad1:
                if (key.Modifiers == 0) SwitchTab(1);
                else SetColor(ColorPresets.Green);
                break;
            case ConsoleKey.D2 or ConsoleKey.NumPad2:
                if (key.Modifiers == 0) SwitchTab(2);
                else SetColor(ColorPresets.Cyan);
                break;
            case ConsoleKey.D3 or ConsoleKey.NumPad3:
                if (key.Modifiers == 0) SwitchTab(3);
                else SetColor(ColorPresets.Red);
                break;
            case ConsoleKey.D4 or ConsoleKey.NumPad4:
                if (key.Modifiers == 0) SwitchTab(4);
                else SetColor(ColorPresets.Purple);
                break;
            case ConsoleKey.D5 or ConsoleKey.NumPad5:
                if (key.Modifiers == 0) SwitchTab(5);
                else SetColor(ColorPresets.Gold);
                break;
            case ConsoleKey.D6 or ConsoleKey.NumPad6:
                if (key.Modifiers == 0) SwitchTab(6);
                else SetColor(ColorPresets.Teal);
                break;
            case ConsoleKey.D7 or ConsoleKey.NumPad7:
                if (key.Modifiers == 0) SwitchTab(7);
                else ToggleLayer(1);
                break;
            case ConsoleKey.D8 or ConsoleKey.NumPad8:
                if (key.Modifiers == 0) SwitchTab(8);
                else ToggleLayer(2);
                break;
            case ConsoleKey.D9 or ConsoleKey.NumPad9:
                ToggleLayer(3);
                break;

            // Speed
            case ConsoleKey.E:
                UpdateConfig(config with { Speed = Math.Max(0.1f, config.Speed - 0.1f) });
                break;
            case ConsoleKey.R:
                UpdateConfig(config with { Speed = Math.Min(2.0f, config.Speed + 0.1f) });
                break;

            // Glow
            case ConsoleKey.G:
                UpdateConfig(config with { Glow = Math.Max(0f, config.Glow - 0.1f) });
                break;
            case ConsoleKey.H:
                UpdateConfig(config with { Glow = Math.Min(2.0f, config.Glow + 0.1f) });
                break;

            // Width
            case ConsoleKey.W:
                UpdateConfig(config with { Width = Math.Max(5f, config.Width - 1f) });
                break;
            case ConsoleKey.T:
                UpdateConfig(config with { Width = Math.Min(20f, config.Width + 1f) });
                break;

            // Trail
            case ConsoleKey.Y:
                UpdateConfig(config with { Trail = Math.Max(1f, config.Trail - 1f) });
                break;
            case ConsoleKey.U:
                UpdateConfig(config with { Trail = Math.Min(20f, config.Trail + 1f) });
                break;

            // Density
            case ConsoleKey.D:
                UpdateConfig(config with { Density = Math.Max(0.1f, config.Density - 0.1f) });
                break;
            case ConsoleKey.F:
                UpdateConfig(config with { Density = Math.Min(1.0f, config.Density + 0.1f) });
                break;

            // Save
            case ConsoleKey.S:
                SaveAll();
                break;

            // Quit
            case ConsoleKey.Q:
            case ConsoleKey.Escape:
                _running = false;
                break;
        }
    }

    private ShaderConfig GetCurrentConfig()
    {
        return _state.ShaderConfigs.TryGetValue(_state.ActiveTab, out var config)
            ? config
            : new ShaderConfig();
    }

    private void SwitchTab(int tab)
    {
        if (tab == _state.ActiveTab) return;

        // Auto-save before switching
        if (_dirty)
        {
            SaveCurrentShader();
        }

        _state = _state with { ActiveTab = tab };
        _logger.LogDebug("Switched to tab {Tab}", tab);
    }

    private void SetColor(MatrixColor color)
    {
        var config = GetCurrentConfig();
        UpdateConfig(config.WithColor(color.R, color.G, color.B));
    }

    private void ToggleLayer(int layer)
    {
        var config = GetCurrentConfig();
        config = layer switch
        {
            1 => config with { Layer1 = !config.Layer1 },
            2 => config with { Layer2 = !config.Layer2 },
            3 => config with { Layer3 = !config.Layer3 },
            _ => config
        };
        UpdateConfig(config);
    }

    private void UpdateConfig(ShaderConfig config)
    {
        var configs = new Dictionary<int, ShaderConfig>(_state.ShaderConfigs)
        {
            [_state.ActiveTab] = config
        };
        _state = _state with { ShaderConfigs = configs };
        _dirty = true;

        // Write to shader file immediately for hot-reload
        if (_shaderService.ShaderExists(_state.ActiveTab))
        {
            try
            {
                _shaderService.WriteConfig(_state.ActiveTab, config);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to write shader {Index}", _state.ActiveTab);
            }
        }
    }

    private void SaveCurrentShader()
    {
        var config = GetCurrentConfig();
        if (_shaderService.ShaderExists(_state.ActiveTab))
        {
            _shaderService.WriteConfig(_state.ActiveTab, config);
        }
    }

    private void SaveAll()
    {
        SaveCurrentShader();
        _configService.SaveState(_state);
        _dirty = false;
        _logger.LogInformation("Saved state");
    }
}
