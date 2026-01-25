using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Lite;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Spectre.Console;

namespace MatrixShader.Cli.Bluepill;

/// <summary>
/// Quick launcher - starts Matrix rain with saved settings.
/// No UI, just immediate visual effect.
/// </summary>
public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        var services = new ServiceCollection();
        ConfigureServices(services);
        var provider = services.BuildServiceProvider();

        var logger = provider.GetRequiredService<ILogger<QuickLauncher>>();
        var envService = provider.GetRequiredService<EnvironmentService>();
        var configService = provider.GetRequiredService<IConfigService>();

        var mode = envService.DetectRenderMode();
        logger.LogInformation("Bluepill starting in {Mode} mode", mode);

        try
        {
            if (mode == RenderMode.Full)
            {
                // Full mode - launch shader windows
                var launcher = provider.GetRequiredService<QuickLauncher>();
                await launcher.LaunchAsync();
            }
            else if (mode == RenderMode.Lite)
            {
                // Lite mode - run text animation directly
                var state = configService.LoadState();
                var config = state.ShaderConfigs.GetValueOrDefault(1, new ShaderConfig());

                using var renderer = new TextMatrixRenderer();
                renderer.SetColor(new Core.Constants.MatrixColor(
                    config.R, config.G, config.B, "Custom", ""));
                renderer.SetSpeed(config.Speed);
                renderer.SetDensity(config.Density);

                using var cts = new CancellationTokenSource();

                // Handle Ctrl+C
                Console.CancelKeyPress += (_, e) =>
                {
                    e.Cancel = true;
                    cts.Cancel();
                };

                AnsiConsole.MarkupLine("[dim]Press Ctrl+C to exit[/]");
                await Task.Delay(1000);

                await renderer.RunAsync(cts.Token);
            }
            else
            {
                AnsiConsole.MarkupLine("[red]No display available.[/]");
                return 1;
            }

            return 0;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception");
            return 1;
        }
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddLogging(builder =>
        {
            builder.SetMinimumLevel(LogLevel.Warning);
        });

        services.AddSingleton<EnvironmentService>();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<QuickLauncher>();
    }
}

/// <summary>
/// Launches Matrix shader windows quickly.
/// </summary>
public class QuickLauncher
{
    private readonly IConfigService _configService;
    private readonly ILogger<QuickLauncher> _logger;

    public QuickLauncher(IConfigService configService, ILogger<QuickLauncher> logger)
    {
        _configService = configService;
        _logger = logger;
    }

    public async Task LaunchAsync()
    {
        var state = _configService.LoadState();

        AnsiConsole.Status()
            .Spinner(Spinner.Known.Dots)
            .Start("Launching Matrix...", ctx =>
            {
                // In full mode, we would launch Windows Terminal windows here
                // For now, just display a message
                ctx.Status("Matrix activated");
            });

        AnsiConsole.MarkupLine("[green]Matrix is running.[/]");
        AnsiConsole.MarkupLine("[dim]Press any key to exit...[/]");

        Console.ReadKey(intercept: true);
        await Task.CompletedTask;
    }
}
