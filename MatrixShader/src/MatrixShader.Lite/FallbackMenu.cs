using System.Text;
using MatrixShader.Core.Constants;

namespace MatrixShader.Lite;

/// <summary>
/// Simplified control menu for Lite mode.
/// Provides basic controls without full TUI framework.
/// </summary>
public class FallbackMenu
{
    private readonly TextMatrixRenderer _renderer;
    private MatrixColor _currentColor;
    private float _speed;
    private float _density;
    private bool _running;
    private CancellationTokenSource? _animationCts;

    public FallbackMenu()
    {
        _renderer = new TextMatrixRenderer();
        _currentColor = ColorPresets.Green;
        _speed = 1.0f;
        _density = 0.4f;
    }

    /// <summary>
    /// Runs the interactive menu loop.
    /// </summary>
    public async Task RunAsync(CancellationToken cancellationToken)
    {
        Console.OutputEncoding = Encoding.UTF8;

        while (!cancellationToken.IsCancellationRequested)
        {
            if (_running)
            {
                // Animation mode - check for key to return to menu
                if (Console.KeyAvailable)
                {
                    var key = Console.ReadKey(intercept: true);
                    if (key.Key == ConsoleKey.Q || key.Key == ConsoleKey.Escape)
                    {
                        await StopAnimation();
                        ShowMenu();
                    }
                    else
                    {
                        HandleAnimationKey(key);
                    }
                }
                await Task.Delay(10, cancellationToken);
            }
            else
            {
                // Menu mode
                ShowMenu();
                var key = Console.ReadKey(intercept: true);
                await HandleMenuKey(key);
            }
        }

        await StopAnimation();
    }

    private void ShowMenu()
    {
        Console.Clear();
        Console.WriteLine();
        Console.WriteLine("  ╔══════════════════════════════════════════════════╗");
        Console.WriteLine("  ║      MATRIX SHADER - LITE MODE                   ║");
        Console.WriteLine("  ╠══════════════════════════════════════════════════╣");
        Console.WriteLine("  ║                                                  ║");
        Console.WriteLine("  ║  COLOR PRESETS                                   ║");
        Console.WriteLine("  ║  [1] Green   [2] Cyan   [3] Red                  ║");
        Console.WriteLine("  ║  [4] Purple  [5] Gold   [6] Teal                 ║");
        Console.WriteLine("  ║                                                  ║");
        Console.WriteLine("  ║  CONTROLS                                        ║");
        Console.WriteLine("  ║  [Enter] Start/Stop Rain                         ║");
        Console.WriteLine("  ║  [E/R] Speed -/+                                 ║");
        Console.WriteLine("  ║  [D/F] Density -/+                               ║");
        Console.WriteLine("  ║  [Q] Quit                                        ║");
        Console.WriteLine("  ║                                                  ║");
        Console.WriteLine("  ╠══════════════════════════════════════════════════╣");
        Console.Write("  ║  Color: ");
        Console.ForegroundColor = GetConsoleColor(_currentColor);
        Console.Write($"{_currentColor.Name,-10}");
        Console.ResetColor();
        Console.WriteLine($" Speed: {_speed:F1}x  Density: {_density:F1}  ║");
        Console.WriteLine("  ╚══════════════════════════════════════════════════╝");
        Console.WriteLine();
        Console.Write("  Press a key...");
    }

    private async Task HandleMenuKey(ConsoleKeyInfo key)
    {
        switch (key.Key)
        {
            case ConsoleKey.D1 or ConsoleKey.NumPad1:
                SetColor(ColorPresets.Green);
                break;
            case ConsoleKey.D2 or ConsoleKey.NumPad2:
                SetColor(ColorPresets.Cyan);
                break;
            case ConsoleKey.D3 or ConsoleKey.NumPad3:
                SetColor(ColorPresets.Red);
                break;
            case ConsoleKey.D4 or ConsoleKey.NumPad4:
                SetColor(ColorPresets.Purple);
                break;
            case ConsoleKey.D5 or ConsoleKey.NumPad5:
                SetColor(ColorPresets.Gold);
                break;
            case ConsoleKey.D6 or ConsoleKey.NumPad6:
                SetColor(ColorPresets.Teal);
                break;
            case ConsoleKey.E:
                AdjustSpeed(-0.1f);
                break;
            case ConsoleKey.R:
                AdjustSpeed(0.1f);
                break;
            case ConsoleKey.D:
                AdjustDensity(-0.1f);
                break;
            case ConsoleKey.F:
                AdjustDensity(0.1f);
                break;
            case ConsoleKey.Enter:
                await StartAnimation();
                break;
            case ConsoleKey.Q:
            case ConsoleKey.Escape:
                Environment.Exit(0);
                break;
        }
    }

    private void HandleAnimationKey(ConsoleKeyInfo key)
    {
        switch (key.Key)
        {
            case ConsoleKey.D1 or ConsoleKey.NumPad1:
                SetColor(ColorPresets.Green);
                break;
            case ConsoleKey.D2 or ConsoleKey.NumPad2:
                SetColor(ColorPresets.Cyan);
                break;
            case ConsoleKey.D3 or ConsoleKey.NumPad3:
                SetColor(ColorPresets.Red);
                break;
            case ConsoleKey.D4 or ConsoleKey.NumPad4:
                SetColor(ColorPresets.Purple);
                break;
            case ConsoleKey.D5 or ConsoleKey.NumPad5:
                SetColor(ColorPresets.Gold);
                break;
            case ConsoleKey.D6 or ConsoleKey.NumPad6:
                SetColor(ColorPresets.Teal);
                break;
            case ConsoleKey.E:
                AdjustSpeed(-0.1f);
                break;
            case ConsoleKey.R:
                AdjustSpeed(0.1f);
                break;
            case ConsoleKey.D:
                AdjustDensity(-0.1f);
                break;
            case ConsoleKey.F:
                AdjustDensity(0.1f);
                break;
        }
    }

    private void SetColor(MatrixColor color)
    {
        _currentColor = color;
        _renderer.SetColor(color);
    }

    private void AdjustSpeed(float delta)
    {
        _speed = Math.Clamp(_speed + delta, 0.1f, 3.0f);
        _renderer.SetSpeed(_speed);
    }

    private void AdjustDensity(float delta)
    {
        _density = Math.Clamp(_density + delta, 0.1f, 1.0f);
        _renderer.SetDensity(_density);
    }

    private async Task StartAnimation()
    {
        _animationCts = new CancellationTokenSource();
        _running = true;

        // Ensure renderer has current settings before starting
        // This guarantees color/speed/density are synchronized
        _renderer.SetColor(_currentColor);
        _renderer.SetSpeed(_speed);
        _renderer.SetDensity(_density);

        // Run animation in background
        _ = _renderer.RunAsync(_animationCts.Token);
        await Task.CompletedTask;
    }

    private async Task StopAnimation()
    {
        if (_animationCts != null)
        {
            await _animationCts.CancelAsync();
            _animationCts.Dispose();
            _animationCts = null;
        }
        _running = false;
        _renderer.Cleanup();
    }

    private static ConsoleColor GetConsoleColor(MatrixColor color)
    {
        // Map to nearest console color
        return color.Name switch
        {
            "Green" => ConsoleColor.Green,
            "Cyan" => ConsoleColor.Cyan,
            "Red" => ConsoleColor.Red,
            "Purple" => ConsoleColor.Magenta,
            "Gold" => ConsoleColor.Yellow,
            "Teal" => ConsoleColor.DarkCyan,
            _ => ConsoleColor.Green
        };
    }
}
