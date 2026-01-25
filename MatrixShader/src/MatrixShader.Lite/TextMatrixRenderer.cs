using System.Text;
using MatrixShader.Core.Constants;

namespace MatrixShader.Lite;

/// <summary>
/// Text-based Matrix rain renderer using ANSI escape codes.
/// Works in any terminal with Unicode and ANSI color support.
/// </summary>
public class TextMatrixRenderer : IDisposable
{
    private readonly Column[] _columns;
    private readonly Random _random;
    private readonly StringBuilder _buffer;
    private readonly int _width;
    private readonly int _height;
    private MatrixColor _color;
    private float _speed;
    private float _density;
    private bool _disposed;

    // ANSI escape codes
    private const string Reset = "\x1b[0m";
    private const string HideCursor = "\x1b[?25l";
    private const string ShowCursor = "\x1b[?25h";
    private const string ClearScreen = "\x1b[2J";
    private const string Home = "\x1b[H";

    public TextMatrixRenderer(int? width = null, int? height = null)
    {
        _width = width ?? Console.WindowWidth;
        _height = height ?? Console.WindowHeight;
        _random = new Random();
        _buffer = new StringBuilder(_width * _height * 30); // Pre-allocate for ANSI codes
        _color = ColorPresets.Green;
        _speed = 1.0f;
        _density = 0.4f;

        // Create columns - one per character position
        _columns = new Column[_width];
        for (int x = 0; x < _width; x++)
        {
            _columns[x] = new Column(x, _height, _random);
            // Stagger initial positions
            if (_random.NextDouble() > _density)
            {
                _columns[x].Reset();
            }
        }
    }

    /// <summary>
    /// Sets the color preset for the rain.
    /// </summary>
    public void SetColor(MatrixColor color)
    {
        _color = color;
    }

    /// <summary>
    /// Sets the animation speed multiplier.
    /// </summary>
    public void SetSpeed(float speed)
    {
        _speed = Math.Clamp(speed, 0.1f, 3.0f);
    }

    /// <summary>
    /// Sets the column spawn density.
    /// </summary>
    public void SetDensity(float density)
    {
        _density = Math.Clamp(density, 0.1f, 1.0f);
    }

    /// <summary>
    /// Initializes the terminal for rendering.
    /// </summary>
    public void Initialize()
    {
        Console.OutputEncoding = Encoding.UTF8;
        Console.Write(HideCursor);
        Console.Write(ClearScreen);
        Console.Write(Home);
    }

    /// <summary>
    /// Renders one frame of the Matrix rain animation.
    /// </summary>
    public void RenderFrame()
    {
        _buffer.Clear();
        _buffer.Append(Home);

        // Track which screen positions have been written
        var screen = new char[_height, _width];
        var brightness = new float[_height, _width];

        // Update all columns and collect characters
        foreach (var col in _columns)
        {
            col.Update();

            // Respawn inactive columns based on density
            if (!col.IsActive && _random.NextDouble() < _density * 0.1)
            {
                col.Reset();
            }

            if (!col.IsActive) continue;

            // Draw head (bright white)
            if (col.HeadY >= 0 && col.HeadY < _height)
            {
                screen[col.HeadY, col.X] = col.HeadChar;
                brightness[col.HeadY, col.X] = 1.5f; // Brighter than max for head
            }

            // Draw trail
            for (int i = 0; i < col.TrailLength; i++)
            {
                int y = col.HeadY - i - 1;
                if (y >= 0 && y < _height)
                {
                    screen[y, col.X] = col.TrailChars[i];
                    brightness[y, col.X] = col.GetBrightness(i);
                }
            }
        }

        // Render to buffer with colors
        var (baseR, baseG, baseB) = _color.ToRgb();

        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                char c = screen[y, x];
                float b = brightness[y, x];

                if (c == '\0' || b <= 0)
                {
                    _buffer.Append(' ');
                    continue;
                }

                // Calculate color based on brightness
                if (b > 1.0f)
                {
                    // Head character - bright white/color
                    _buffer.Append($"\x1b[38;2;255;255;255m{c}");
                }
                else
                {
                    // Trail character - fading color
                    byte r = (byte)(baseR * b);
                    byte g = (byte)(baseG * b);
                    byte bl = (byte)(baseB * b);
                    _buffer.Append($"\x1b[38;2;{r};{g};{bl}m{c}");
                }
            }

            if (y < _height - 1)
            {
                _buffer.Append(Reset);
                _buffer.AppendLine();
            }
        }

        _buffer.Append(Reset);

        // Output the entire frame at once
        Console.Write(_buffer.ToString());
    }

    /// <summary>
    /// Runs the animation loop until cancelled.
    /// </summary>
    /// <param name="cancellationToken">Token to stop the animation</param>
    /// <param name="targetFps">Target frames per second (default 30)</param>
    public async Task RunAsync(CancellationToken cancellationToken, int targetFps = 30)
    {
        Initialize();

        int frameDelay = (int)(1000 / (targetFps * _speed));

        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                RenderFrame();
                await Task.Delay(frameDelay, cancellationToken);
            }
        }
        catch (OperationCanceledException)
        {
            // Expected when cancelled
        }
        finally
        {
            Cleanup();
        }
    }

    /// <summary>
    /// Restores terminal state.
    /// </summary>
    public void Cleanup()
    {
        Console.Write(ShowCursor);
        Console.Write(Reset);
        Console.Write(ClearScreen);
        Console.Write(Home);
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            Cleanup();
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }
}
