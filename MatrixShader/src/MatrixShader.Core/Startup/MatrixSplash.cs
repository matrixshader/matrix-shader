using System.Diagnostics;

namespace MatrixShader.Core.Startup;

/// <summary>
/// Matrix-themed startup splash animation with cascading green numbers.
/// Delivers late-90s telnet hacker aesthetic.
/// </summary>
public static class MatrixSplash
{
    private static readonly Random _rng = new();
    private static readonly char[] _chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ".ToCharArray();

    // ANSI escape codes — matching Linux wakeupneo colors
    private const string Bright = "\x1b[38;2;110;220;170m";   // #6EDCAA
    private const string Base = "\x1b[38;2;53;179;129m";      // #35B381
    private const string Soft = "\x1b[38;2;30;100;72m";       // #1E6448
    private const string Reset = "\x1b[0m";

    /// <summary>
    /// Displays the Matrix number cascade animation.
    /// </summary>
    /// <param name="durationMs">Minimum duration in milliseconds (default 1500ms)</param>
    public static async Task ShowAsync(int durationMs = 1500)
    {
        // Save original cursor state
        var originalVisible = true;
        try
        {
            originalVisible = Console.CursorVisible;
        }
        catch
        {
            // Console.CursorVisible may throw in some environments
        }

        try
        {
            Console.Clear();
            Console.CursorVisible = false;

            var width = Math.Min(Console.WindowWidth, 200); // Cap width to prevent memory issues
            var height = Math.Min(Console.WindowHeight, 50);
            var startTime = Stopwatch.GetTimestamp();

            // Column state: position, speed, trail length
            var columns = new ColumnState[width];
            for (int i = 0; i < width; i++)
            {
                columns[i] = new ColumnState
                {
                    Position = _rng.Next(-height * 2, 0), // Staggered start
                    Speed = _rng.Next(1, 3), // 1 or 2 cells per frame
                    TrailLength = _rng.Next(4, 12)
                };
            }

            var frameCount = 0;

            while (Stopwatch.GetElapsedTime(startTime).TotalMilliseconds < durationMs)
            {
                // Update and render per-character with cursor addressing (no flicker)
                var output = new System.Text.StringBuilder();

                for (int x = 0; x < width; x++)
                {
                    // Move column down based on speed
                    if (frameCount % (4 - columns[x].Speed) == 0)
                    {
                        columns[x].Position++;
                    }

                    // Reset column when trail passes bottom
                    if (columns[x].Position - columns[x].TrailLength >= height)
                    {
                        columns[x].Position = _rng.Next(-10, 0);
                        columns[x].Speed = _rng.Next(1, 3);
                        columns[x].TrailLength = _rng.Next(4, 12);
                    }

                    // Render only trail characters via cursor positioning
                    for (int t = 0; t < columns[x].TrailLength; t++)
                    {
                        int y = columns[x].Position - t;
                        if (y >= 0 && y < height)
                        {
                            char c = _chars[_rng.Next(_chars.Length)];
                            // Cursor to position (1-based)
                            output.Append($"\x1b[{y + 1};{x + 1}H");
                            if (t == 0)
                                output.Append(Bright);
                            else if (t < 3)
                                output.Append(Base);
                            else
                                output.Append(Soft);
                            output.Append(c);
                        }
                    }

                    // Clear the cell just above the trail (erase old lead char)
                    int clearY = columns[x].Position - columns[x].TrailLength;
                    if (clearY >= 0 && clearY < height)
                    {
                        output.Append($"\x1b[{clearY + 1};{x + 1}H ");
                    }
                }

                output.Append("\x1b[H"); // Cursor home
                Console.Write(output.ToString());
                frameCount++;

                await Task.Delay(50); // ~20 FPS
            }

            Console.Clear();
        }
        finally
        {
            // Restore cursor visibility
            try
            {
                Console.CursorVisible = originalVisible;
            }
            catch
            {
                // Ignore errors restoring cursor
            }
        }
    }

    private struct ColumnState
    {
        public int Position;
        public int Speed;
        public int TrailLength;
    }
}
