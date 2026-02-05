using System.Diagnostics;

namespace MatrixShader.Core.Startup;

/// <summary>
/// Matrix-themed startup splash animation with cascading green numbers.
/// Delivers late-90s telnet hacker aesthetic.
/// </summary>
public static class MatrixSplash
{
    private static readonly Random _rng = new();
    private static readonly char[] _chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray();

    // ANSI escape codes
    private const string BrightWhite = "\x1b[97m";
    private const string BrightGreen = "\x1b[92m";
    private const string Green = "\x1b[32m";
    private const string DarkGreen = "\x1b[2;32m";
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

            // Screen buffer for characters (to avoid flickering)
            var screen = new char[height, width];
            var frameCount = 0;

            while (Stopwatch.GetElapsedTime(startTime).TotalMilliseconds < durationMs)
            {
                // Update columns
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

                    // Update screen buffer for this column
                    for (int y = 0; y < height; y++)
                    {
                        int distance = columns[x].Position - y;
                        if (distance >= 0 && distance < columns[x].TrailLength)
                        {
                            // Within trail - show a character
                            screen[y, x] = _chars[_rng.Next(_chars.Length)];
                        }
                        else
                        {
                            screen[y, x] = ' ';
                        }
                    }
                }

                // Render screen with colors
                var output = new System.Text.StringBuilder();
                output.Append("\x1b[H"); // Move cursor to top-left

                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        char c = screen[y, x];
                        if (c == ' ')
                        {
                            output.Append(' ');
                        }
                        else
                        {
                            int distance = columns[x].Position - y;
                            if (distance == 0)
                            {
                                // Lead character - bright white
                                output.Append(BrightWhite);
                                output.Append(c);
                                output.Append(Reset);
                            }
                            else if (distance == 1)
                            {
                                // Second char - bright green
                                output.Append(BrightGreen);
                                output.Append(c);
                                output.Append(Reset);
                            }
                            else if (distance < columns[x].TrailLength / 2)
                            {
                                // Upper trail - normal green
                                output.Append(Green);
                                output.Append(c);
                                output.Append(Reset);
                            }
                            else
                            {
                                // Lower trail - dark green (fading)
                                output.Append(DarkGreen);
                                output.Append(c);
                                output.Append(Reset);
                            }
                        }
                    }
                    if (y < height - 1)
                        output.AppendLine();
                }

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
