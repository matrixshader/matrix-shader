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
    private bool _animationRunning;
    private bool _backgroundMode;
    private CancellationTokenSource? _animationCts;

    // Signals to return to menu instead of exiting
    private volatile bool _returnToMenu;
    private volatile bool _userRequestedExit;

    public FallbackMenu()
    {
        _renderer = new TextMatrixRenderer();
        _currentColor = ColorPresets.Green;
        _speed = 1.0f;
        _density = 0.4f;
        _animationRunning = false;
        _backgroundMode = false;
        _returnToMenu = false;
        _userRequestedExit = false;
    }

    /// <summary>
    /// Gets whether the user requested to exit entirely (vs returning to menu).
    /// </summary>
    public bool UserRequestedExit => _userRequestedExit;

    /// <summary>
    /// Runs the interactive menu loop.
    /// Returns when user presses Q/ESC from menu (or cancellation token is triggered).
    /// </summary>
    public async Task RunAsync(CancellationToken cancellationToken)
    {
        Console.OutputEncoding = Encoding.UTF8;
        _userRequestedExit = false;

        // Register Ctrl+C handler
        Console.CancelKeyPress += OnCancelKeyPress;

        try
        {
            while (!cancellationToken.IsCancellationRequested && !_userRequestedExit)
            {
                if (_animationRunning)
                {
                    // Animation mode - check for keys without blocking
                    if (Console.KeyAvailable)
                    {
                        var key = Console.ReadKey(intercept: true);
                        await HandleAnimationKeyAsync(key);
                    }
                    await Task.Delay(50, cancellationToken);
                }
                else
                {
                    // Menu mode - show menu and wait for input
                    ShowMenu();
                    var key = Console.ReadKey(intercept: true);
                    await HandleMenuKeyAsync(key);
                }
            }
        }
        finally
        {
            Console.CancelKeyPress -= OnCancelKeyPress;
            await StopAnimationAsync();
        }
    }

    /// <summary>
    /// Starts rain immediately (for Blue Pill direct start).
    /// Returns when user presses ESC, Q, or Ctrl+C.
    /// </summary>
    public async Task StartRainDirectAsync(CancellationToken cancellationToken)
    {
        Console.OutputEncoding = Encoding.UTF8;
        _renderer.SetColor(_currentColor);
        _renderer.SetSpeed(_speed);
        _renderer.SetDensity(_density);
        _returnToMenu = false;

        // Register Ctrl+C handler to signal return to menu (not exit)
        Console.CancelKeyPress += OnCancelKeyPress;

        try
        {
            // Show brief hint about how to exit
            Console.Clear();
            Console.WriteLine();
            Console.WriteLine("\x1b[90m  Press ESC, Q, or Ctrl+C to return to menu...\x1b[0m");
            await Task.Delay(1500, cancellationToken);
            Console.Clear();

            // Initialize renderer
            _renderer.Initialize();

            // Run animation loop with key checking
            int frameDelay = (int)(1000 / (30 * _speed));

            while (!cancellationToken.IsCancellationRequested && !_returnToMenu)
            {
                _renderer.RenderFrame();

                // Check for key press without blocking
                if (Console.KeyAvailable)
                {
                    var key = Console.ReadKey(intercept: true);
                    if (key.Key == ConsoleKey.Escape || key.Key == ConsoleKey.Q)
                    {
                        _returnToMenu = true;
                        break;
                    }
                    // Allow color changes and other controls during effect
                    HandleEffectKey(key);
                }

                await Task.Delay(frameDelay, cancellationToken);
            }
        }
        catch (OperationCanceledException)
        {
            // Expected when cancelled
        }
        finally
        {
            Console.CancelKeyPress -= OnCancelKeyPress;
            _renderer.Cleanup();
        }
    }

    /// <summary>
    /// Handler for Ctrl+C that signals return to menu instead of terminating.
    /// </summary>
    private void OnCancelKeyPress(object? sender, ConsoleCancelEventArgs e)
    {
        e.Cancel = true;  // Don't terminate the process
        _returnToMenu = true;  // Signal to return to menu
    }

    /// <summary>
    /// Handles key presses during the effect (color changes, speed, etc.).
    /// </summary>
    private void HandleEffectKey(ConsoleKeyInfo key)
    {
        switch (key.Key)
        {
            case ConsoleKey.D1 or ConsoleKey.NumPad1:
                SetColor(ColorPresets.Green);
                break;
            case ConsoleKey.D2 or ConsoleKey.NumPad2:
                SetColor(ColorPresets.Blue);
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

    private void ShowMenu()
    {
        Console.Clear();
        Console.WriteLine();
        Console.WriteLine("  \x1b[38;2;110;220;170m+==================================================+\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|      MATRIX SHADER - LITE MODE                   |\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m+==================================================+\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m                                                  \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  COLOR PRESETS                                   \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [1] \x1b[38;2;0;255;77mGreen\x1b[0m   [2] \x1b[38;2;0;153;255mBlue\x1b[0m   [3] \x1b[38;2;255;26;26mRed\x1b[0m                  \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [4] \x1b[38;2;178;0;255mPurple\x1b[0m  [5] \x1b[38;2;255;178;0mGold\x1b[0m   [6] \x1b[38;2;0;230;230mTeal\x1b[0m                 \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m                                                  \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  CONTROLS                                        \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [Enter] Start Rain (fullscreen)                 \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [B] Background Mode (rain behind commands)      \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [E/R] Speed -/+                                 \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [D/F] Density -/+                               \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m  [Q] Quit                                        \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m                                                  \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m+--------------------------------------------------+\x1b[0m");
        Console.Write("  \x1b[38;2;110;220;170m|\x1b[0m  Color: ");
        WriteColoredText(_currentColor.Name, _currentColor);
        Console.Write($"  Speed: {_speed:F1}x  Density: {_density:F1}");
        Console.WriteLine("  \x1b[38;2;110;220;170m|\x1b[0m");
        Console.WriteLine("  \x1b[38;2;110;220;170m+==================================================+\x1b[0m");
        Console.WriteLine();
        Console.Write("  \x1b[90mPress a key...\x1b[0m");
    }

    private static void WriteColoredText(string text, MatrixColor color)
    {
        var (r, g, b) = color.ToRgb();
        Console.Write($"\x1b[38;2;{r};{g};{b}m{text,-10}\x1b[0m");
    }

    private async Task HandleMenuKeyAsync(ConsoleKeyInfo key)
    {
        switch (key.Key)
        {
            case ConsoleKey.D1 or ConsoleKey.NumPad1:
                SetColor(ColorPresets.Green);
                break;
            case ConsoleKey.D2 or ConsoleKey.NumPad2:
                SetColor(ColorPresets.Blue);
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
                await StartAnimationAsync(backgroundMode: false);
                break;
            case ConsoleKey.B:
                await StartAnimationAsync(backgroundMode: true);
                break;
            case ConsoleKey.Q:
            case ConsoleKey.Escape:
                _userRequestedExit = true;
                break;
        }
    }

    private async Task HandleAnimationKeyAsync(ConsoleKeyInfo key)
    {
        switch (key.Key)
        {
            case ConsoleKey.D1 or ConsoleKey.NumPad1:
                SetColor(ColorPresets.Green);
                break;
            case ConsoleKey.D2 or ConsoleKey.NumPad2:
                SetColor(ColorPresets.Blue);
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
            case ConsoleKey.Q:
            case ConsoleKey.Escape:
            case ConsoleKey.Enter:
                await StopAnimationAsync();
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

    private async Task StartAnimationAsync(bool backgroundMode)
    {
        _backgroundMode = backgroundMode;
        _animationCts = new CancellationTokenSource();
        _animationRunning = true;

        // Ensure renderer has current settings
        _renderer.SetColor(_currentColor);
        _renderer.SetSpeed(_speed);
        _renderer.SetDensity(_density);

        if (backgroundMode)
        {
            // Background mode: start animation, then return control
            // The animation runs in background while user can still type
            Console.WriteLine("\x1b[38;2;110;220;170mBackground mode - rain runs behind your commands\x1b[0m");
            Console.WriteLine("\x1b[90mPress Ctrl+C to stop\x1b[0m");
            Console.WriteLine();
        }

        // Run animation (blocking for fullscreen, non-blocking for background)
        _ = _renderer.RunAsync(_animationCts.Token);

        if (!backgroundMode)
        {
            // Wait for animation to be stopped by user
            await Task.CompletedTask;
        }
    }

    private async Task StopAnimationAsync()
    {
        if (_animationCts != null)
        {
            await _animationCts.CancelAsync();
            _animationCts.Dispose();
            _animationCts = null;
        }
        _animationRunning = false;
        _renderer.Cleanup();
    }
}
