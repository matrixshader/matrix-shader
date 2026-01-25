using MatrixShader.Core.Constants;

namespace MatrixShader.Lite;

/// <summary>
/// Represents a single column of falling Matrix characters.
/// </summary>
public class Column
{
    private readonly Random _random;
    private readonly int _x;
    private readonly int _maxY;
    private readonly char[] _trail;
    private int _headY;
    private int _speed;
    private int _tickCounter;
    private bool _active;

    public Column(int x, int maxY, Random random)
    {
        _x = x;
        _maxY = maxY;
        _random = random;
        _trail = new char[30]; // Max trail length
        Reset();
    }

    /// <summary>X position (column) on screen</summary>
    public int X => _x;

    /// <summary>Y position of the head character</summary>
    public int HeadY => _headY;

    /// <summary>Current head character</summary>
    public char HeadChar { get; private set; }

    /// <summary>Trail characters behind the head</summary>
    public ReadOnlySpan<char> TrailChars => _trail.AsSpan(0, TrailLength);

    /// <summary>Current trail length</summary>
    public int TrailLength { get; private set; }

    /// <summary>Whether this column is currently falling</summary>
    public bool IsActive => _active;

    /// <summary>
    /// Resets the column to start a new fall.
    /// </summary>
    public void Reset()
    {
        _headY = _random.Next(-20, -1); // Start above screen
        _speed = _random.Next(1, 4); // Variable speed
        _tickCounter = 0;
        _active = true;
        TrailLength = _random.Next(8, 25); // Variable trail length
        HeadChar = KatakanaChars.GetRandom(_random);

        // Initialize trail with random characters
        for (int i = 0; i < _trail.Length; i++)
        {
            _trail[i] = KatakanaChars.GetRandom(_random);
        }
    }

    /// <summary>
    /// Updates the column state for one tick.
    /// </summary>
    /// <returns>True if the column moved this tick</returns>
    public bool Update()
    {
        if (!_active) return false;

        _tickCounter++;
        if (_tickCounter < _speed) return false;

        _tickCounter = 0;

        // Move head down
        _headY++;

        // Check if completely off screen
        if (_headY - TrailLength > _maxY)
        {
            _active = false;
            return false;
        }

        // Occasionally change the head character
        if (_random.Next(10) < 3)
        {
            HeadChar = KatakanaChars.GetRandom(_random);
        }

        // Shift trail and add new character
        for (int i = _trail.Length - 1; i > 0; i--)
        {
            _trail[i] = _trail[i - 1];
        }
        _trail[0] = HeadChar;

        // Occasionally mutate a trail character (Matrix "glitch" effect)
        if (_random.Next(20) < 1 && TrailLength > 0)
        {
            int mutateIdx = _random.Next(TrailLength);
            _trail[mutateIdx] = KatakanaChars.GetRandom(_random);
        }

        return true;
    }

    /// <summary>
    /// Gets the brightness factor for a trail position (0.0 - 1.0).
    /// </summary>
    /// <param name="trailIndex">Position in trail (0 = just behind head)</param>
    public float GetBrightness(int trailIndex)
    {
        if (trailIndex < 0 || trailIndex >= TrailLength)
            return 0f;

        // Exponential falloff for realistic fade
        return MathF.Pow(1f - (trailIndex / (float)TrailLength), 1.5f);
    }
}
