using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Spectre.Console;

namespace MatrixShader.Cli.WakeupNeo;

/// <summary>
/// Setup wizard - interactive configuration for first-time users.
/// "Wake up, Neo..."
/// </summary>
public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        var services = new ServiceCollection();
        ConfigureServices(services);
        var provider = services.BuildServiceProvider();

        var logger = provider.GetRequiredService<ILogger<SetupWizard>>();

        try
        {
            var wizard = provider.GetRequiredService<SetupWizard>();
            await wizard.RunAsync();
            return 0;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Setup failed");
            AnsiConsole.WriteException(ex);
            return 1;
        }
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddLogging(builder =>
        {
            builder.SetMinimumLevel(LogLevel.Information);
        });

        services.AddSingleton<EnvironmentService>();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<SetupWizard>();
    }
}

/// <summary>
/// Interactive setup wizard with "Blue Pill / Red Pill" choice.
/// </summary>
public class SetupWizard
{
    private readonly IConfigService _configService;
    private readonly EnvironmentService _envService;
    private readonly ILogger<SetupWizard> _logger;

    public SetupWizard(
        IConfigService configService,
        EnvironmentService envService,
        ILogger<SetupWizard> logger)
    {
        _configService = configService;
        _envService = envService;
        _logger = logger;
    }

    public async Task RunAsync()
    {
        Console.Clear();

        // Dramatic intro
        await TypewriterEffect("Wake up, Neo...", 100);
        await Task.Delay(1000);

        await TypewriterEffect("The Matrix has you...", 80);
        await Task.Delay(1000);

        await TypewriterEffect("Follow the white rabbit.", 80);
        await Task.Delay(500);

        Console.Clear();

        // ASCII art
        AnsiConsole.Write(new FigletText("MATRIX")
            .Centered()
            .Color(Color.Green));

        AnsiConsole.WriteLine();

        // Environment detection
        var mode = _envService.DetectRenderMode();
        var terminal = EnvironmentService.GetTerminalType();

        AnsiConsole.MarkupLine($"[dim]Terminal: {terminal}[/]");
        AnsiConsole.MarkupLine($"[dim]Mode: {mode}[/]");
        AnsiConsole.WriteLine();

        // The choice
        var choice = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("[green]This is your last chance. After this, there is no turning back.[/]")
                .AddChoices(
                    "[blue]Blue Pill[/] - Quick setup, return to blissful ignorance",
                    "[red]Red Pill[/] - Full customization, see how deep the rabbit hole goes"));

        if (choice.Contains("Blue"))
        {
            await BluePillPath();
        }
        else
        {
            await RedPillPath();
        }
    }

    private async Task BluePillPath()
    {
        AnsiConsole.MarkupLine("\n[blue]You take the blue pill...[/]");
        await Task.Delay(500);

        // Quick setup with defaults
        var state = new MatrixState();

        AnsiConsole.Status()
            .Spinner(Spinner.Known.Dots)
            .Start("Setting up Matrix...", ctx =>
            {
                ctx.Status("Creating default configuration...");
                _configService.SaveState(state);

                ctx.Status("Complete!");
            });

        AnsiConsole.MarkupLine("\n[green]Setup complete![/]");
        AnsiConsole.MarkupLine("[dim]Run [green]bluepill[/] to start the Matrix rain.[/]");
        AnsiConsole.MarkupLine("[dim]Run [green]redpill[/] for the control panel.[/]");

        await Task.CompletedTask;
    }

    private async Task RedPillPath()
    {
        AnsiConsole.MarkupLine("\n[red]You take the red pill...[/]");
        await Task.Delay(500);

        AnsiConsole.MarkupLine("[red]Remember, all I'm offering is the truth. Nothing more.[/]");
        await Task.Delay(1000);

        // Full customization
        var windowCount = AnsiConsole.Prompt(
            new SelectionPrompt<int>()
                .Title("How many Matrix windows?")
                .AddChoices(1, 2, 3, 4, 6, 8));

        var colorChoice = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("Default color?")
                .AddChoices("Green (Classic)", "Cyan (Electric)", "Red (Alert)", "Purple (Cyber)", "Gold (Machine)", "Teal (Awakened)"));

        var color = colorChoice switch
        {
            "Green (Classic)" => Core.Constants.ColorPresets.Green,
            "Cyan (Electric)" => Core.Constants.ColorPresets.Cyan,
            "Red (Alert)" => Core.Constants.ColorPresets.Red,
            "Purple (Cyber)" => Core.Constants.ColorPresets.Purple,
            "Gold (Machine)" => Core.Constants.ColorPresets.Gold,
            "Teal (Awakened)" => Core.Constants.ColorPresets.Teal,
            _ => Core.Constants.ColorPresets.Green
        };

        var layoutMode = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("Window layout?")
                .AddChoices("Pillars (side by side)", "Quads (2x2 grid)", "Auto (smart selection)"));

        var layout = layoutMode switch
        {
            "Pillars (side by side)" => "Pillars",
            "Quads (2x2 grid)" => "Quads",
            _ => "Auto"
        };

        // Create state with selections
        var configs = new Dictionary<int, ShaderConfig>();
        for (int i = 1; i <= 8; i++)
        {
            configs[i] = new ShaderConfig().WithColor(color.R, color.G, color.B);
        }

        var state = new MatrixState
        {
            ShaderConfigs = configs,
            Layout = new LayoutConfig { Mode = layout }
        };

        AnsiConsole.Status()
            .Spinner(Spinner.Known.Dots)
            .Start("Initializing the Matrix...", ctx =>
            {
                ctx.Status("Creating configuration...");
                _configService.SaveState(state);

                ctx.Status("Welcome to the real world.");
            });

        AnsiConsole.MarkupLine("\n[green]The Matrix is ready.[/]");
        AnsiConsole.MarkupLine($"[dim]Configuration: {windowCount} windows, {layout} layout[/]");
        AnsiConsole.MarkupLine("[dim]Run [green]redpill[/] to enter the control panel.[/]");

        await Task.CompletedTask;
    }

    private static async Task TypewriterEffect(string text, int delayMs)
    {
        foreach (char c in text)
        {
            Console.Write(c);
            await Task.Delay(delayMs);
        }
        Console.WriteLine();
    }
}
