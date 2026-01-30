namespace MatrixShader.Core.Startup;

/// <summary>
/// Matrix-themed error handler with late-90s telnet hacker aesthetic.
/// Displays "SYSTEM FAILURE" ASCII art banner and waits for keypress.
/// </summary>
public static class MatrixErrorHandler
{
    // ANSI escape codes
    private const string Red = "\x1b[31m";
    private const string Green = "\x1b[32m";
    private const string DarkGray = "\x1b[90m";
    private const string Reset = "\x1b[0m";

    /// <summary>
    /// Displays a Matrix-themed error message with ASCII art banner.
    /// </summary>
    /// <param name="message">The error message to display</param>
    /// <param name="actionUrl">Optional URL for user to visit for help</param>
    public static void ShowError(string message, string? actionUrl = null)
    {
        Console.Clear();
        Console.WriteLine();

        // SYSTEM FAILURE ASCII art in red (compact version for terminal width)
        Console.WriteLine($"{Red} ███████ ██    ██ ███████ ████████ ███████ ███    ███ {Reset}");
        Console.WriteLine($"{Red} ██       ██  ██  ██         ██    ██      ████  ████ {Reset}");
        Console.WriteLine($"{Red} ███████   ████   ███████    ██    █████   ██ ████ ██ {Reset}");
        Console.WriteLine($"{Red}      ██    ██         ██    ██    ██      ██  ██  ██ {Reset}");
        Console.WriteLine($"{Red} ███████    ██    ███████    ██    ███████ ██      ██ {Reset}");
        Console.WriteLine();
        Console.WriteLine($"{Red} ███████  █████  ██ ██      ██    ██ ██████  ███████ {Reset}");
        Console.WriteLine($"{Red} ██      ██   ██ ██ ██      ██    ██ ██   ██ ██      {Reset}");
        Console.WriteLine($"{Red} █████   ███████ ██ ██      ██    ██ ██████  █████   {Reset}");
        Console.WriteLine($"{Red} ██      ██   ██ ██ ██      ██    ██ ██   ██ ██      {Reset}");
        Console.WriteLine($"{Red} ██      ██   ██ ██ ███████  ██████  ██   ██ ███████ {Reset}");
        Console.WriteLine();
        Console.WriteLine();

        // Error message in Matrix green
        Console.WriteLine($"{Green} > {message}{Reset}");
        Console.WriteLine();

        // Optional action URL
        if (!string.IsNullOrEmpty(actionUrl))
        {
            Console.WriteLine($"{DarkGray} Jack in at: {actionUrl}{Reset}");
            Console.WriteLine();
        }

        // Wait for keypress
        Console.WriteLine($"{DarkGray} Press any key to exit the simulation...{Reset}");
        Console.ReadKey(intercept: true);
    }

    /// <summary>
    /// Displays a Matrix-themed error for exceptions.
    /// </summary>
    /// <param name="exception">The exception to display</param>
    /// <param name="actionUrl">Optional URL for user to visit for help</param>
    public static void ShowError(Exception exception, string? actionUrl = null)
    {
        ShowError(exception.Message, actionUrl);
    }

    /// <summary>
    /// Displays a Matrix-themed fatal error and exits with code 1.
    /// </summary>
    /// <param name="message">The error message to display</param>
    /// <param name="actionUrl">Optional URL for user to visit for help</param>
    public static void ShowFatalError(string message, string? actionUrl = null)
    {
        ShowError(message, actionUrl);
        Environment.Exit(1);
    }
}
