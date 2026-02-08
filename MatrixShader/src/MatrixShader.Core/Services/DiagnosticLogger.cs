namespace MatrixShader.Core.Services;

/// <summary>
/// Diagnostic logging for Matrix Terminal Shader.
/// Activates with MATRIX_DEBUG=1 environment variable or --debug flag.
/// Matches PowerShell MatrixLogging.ps1 behavior.
/// </summary>
public static class DiagnosticLogger
{
    private static bool _enabled;
    private static string? _logPath;
    private static readonly object _lock = new();

    /// <summary>
    /// Gets whether diagnostic logging is enabled.
    /// </summary>
    public static bool IsEnabled => _enabled;

    /// <summary>
    /// Gets the log file path.
    /// </summary>
    public static string LogPath => _logPath ?? GetDefaultLogPath();

    /// <summary>
    /// Initializes diagnostic logging. Call once at startup.
    /// </summary>
    /// <param name="debugFlag">True if --debug command line flag was passed</param>
    public static void Initialize(bool debugFlag = false)
    {
        // Check environment variable MATRIX_DEBUG=1
        var envDebug = Environment.GetEnvironmentVariable("MATRIX_DEBUG");
        _enabled = debugFlag || envDebug == "1";

        if (_enabled)
        {
            _logPath = GetDefaultLogPath();

            // Ensure directory exists
            var dir = Path.GetDirectoryName(_logPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                try
                {
                    Directory.CreateDirectory(dir);
                }
                catch
                {
                    // If we can't create directory, disable file logging
                    // but keep console logging
                }
            }

            Log("STARTUP", "INFO", "Diagnostic logging enabled");
        }
    }

    /// <summary>
    /// Logs a message if diagnostic logging is enabled.
    /// </summary>
    /// <param name="source">Source component (e.g., "SHADER", "LAYOUT", "IDENTITY")</param>
    /// <param name="level">Log level: DEBUG, INFO, WARN, ERROR</param>
    /// <param name="message">Log message</param>
    public static void Log(string source, string level, string message)
    {
        if (!_enabled) return;

        var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
        var logEntry = $"[{timestamp}] [{source}] [{level}] {message}";

        // Console output with color
        WriteColoredConsole(level, logEntry);

        // File output
        WriteToFile(logEntry);
    }

    /// <summary>
    /// Logs a DEBUG level message.
    /// </summary>
    public static void Debug(string source, string message) => Log(source, "DEBUG", message);

    /// <summary>
    /// Logs an INFO level message.
    /// </summary>
    public static void Info(string source, string message) => Log(source, "INFO", message);

    /// <summary>
    /// Logs a WARN level message.
    /// </summary>
    public static void Warn(string source, string message) => Log(source, "WARN", message);

    /// <summary>
    /// Logs an ERROR level message.
    /// </summary>
    public static void Error(string source, string message) => Log(source, "ERROR", message);

    /// <summary>
    /// Logs an exception with ERROR level.
    /// </summary>
    public static void Error(string source, string message, Exception ex)
    {
        Log(source, "ERROR", $"{message}: {ex.Message}");
        if (_enabled)
        {
            // Log stack trace on separate line for debugging
            WriteToFile($"    Stack trace: {ex.StackTrace}");
        }
    }

    /// <summary>
    /// Logs a production error that ALWAYS writes to the log file, regardless of _enabled flag.
    /// Use for unhandled exceptions and critical failures that must be captured in production.
    /// </summary>
    public static void ProductionError(string source, string message)
    {
        var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
        var logEntry = $"[{timestamp}] [{source}] [FATAL] {message}";

        // Always write to file, even if debug logging is disabled
        var logPath = _logPath ?? GetDefaultLogPath();
        try
        {
            var dir = Path.GetDirectoryName(logPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            lock (_lock)
            {
                File.AppendAllText(logPath, logEntry + Environment.NewLine);
            }
        }
        catch
        {
            // Last resort - nothing we can do
        }
    }

    private static string GetDefaultLogPath()
    {
        // Match PowerShell: $env:USERPROFILE\Documents\Matrix\debug.log
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "Matrix",
            "debug.log");
    }

    private static void WriteColoredConsole(string level, string entry)
    {
        // Match PowerShell color scheme
        var color = level switch
        {
            "DEBUG" => ConsoleColor.DarkGray,
            "INFO" => ConsoleColor.Gray,
            "WARN" => ConsoleColor.Yellow,
            "ERROR" => ConsoleColor.Red,
            _ => ConsoleColor.Gray
        };

        var originalColor = Console.ForegroundColor;
        try
        {
            Console.ForegroundColor = color;
            Console.WriteLine(entry);
        }
        finally
        {
            Console.ForegroundColor = originalColor;
        }
    }

    private static void WriteToFile(string entry)
    {
        if (string.IsNullOrEmpty(_logPath)) return;

        try
        {
            lock (_lock)
            {
                File.AppendAllText(_logPath, entry + Environment.NewLine);
            }
        }
        catch
        {
            // Silently ignore file write errors to match PowerShell behavior
            // (uses -ErrorAction SilentlyContinue)
        }
    }
}
