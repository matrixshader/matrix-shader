using MatrixShader.Core.Models;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for detecting the runtime environment and selecting render mode.
/// </summary>
public class EnvironmentService
{
    private readonly ILogger<EnvironmentService> _logger;

    public EnvironmentService(ILogger<EnvironmentService> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Detects the current environment and returns the appropriate render mode.
    /// </summary>
    public RenderMode DetectRenderMode()
    {
        // Check if running inside Windows Terminal (WT_SESSION env var)
        if (IsWindowsTerminal())
        {
            _logger.LogInformation("Detected Windows Terminal (WT_SESSION) - using Full mode");
            return RenderMode.Full;
        }

        // Also check if WT is installed even if we're not running inside it
        // (e.g. CMD tab in WT may not have WT_SESSION, or launched from outside WT)
        if (CliBootstrap.IsWindowsTerminalInstalled())
        {
            _logger.LogInformation("Windows Terminal installed (not running inside it) - using Full mode");
            return RenderMode.Full;
        }

        // Check if running on Windows with console access
        if (OperatingSystem.IsWindows() && HasConsole())
        {
            _logger.LogInformation("Detected Windows console - using Lite mode");
            return RenderMode.Lite;
        }

        // Check for any terminal with ANSI support
        if (HasAnsiSupport())
        {
            _logger.LogInformation("Detected ANSI-capable terminal - using Lite mode");
            return RenderMode.Lite;
        }

        // Headless fallback
        _logger.LogWarning("No suitable display detected - using Headless mode");
        return RenderMode.Headless;
    }

    /// <summary>
    /// Checks if running inside Windows Terminal.
    /// </summary>
    public static bool IsWindowsTerminal()
    {
        // WT_SESSION is set when running in Windows Terminal
        var wtSession = Environment.GetEnvironmentVariable("WT_SESSION");
        return !string.IsNullOrEmpty(wtSession);
    }

    /// <summary>
    /// Checks if running in Windows Terminal with shader support.
    /// </summary>
    public bool CanUseShaders()
    {
        if (!IsWindowsTerminal())
            return false;

        // Check Windows Terminal version supports shaders (1.12+)
        var wtProfile = Environment.GetEnvironmentVariable("WT_PROFILE_ID");
        return !string.IsNullOrEmpty(wtProfile);
    }

    /// <summary>
    /// Checks if a console is available.
    /// </summary>
    public static bool HasConsole()
    {
        try
        {
            // Try to get console window handle
            return Console.WindowWidth > 0 && Console.WindowHeight > 0;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Checks if the terminal supports ANSI escape codes.
    /// </summary>
    public static bool HasAnsiSupport()
    {
        // Check common environment variables indicating ANSI support
        var term = Environment.GetEnvironmentVariable("TERM");
        if (!string.IsNullOrEmpty(term) &&
            (term.Contains("xterm") || term.Contains("256color") || term.Contains("ansi")))
        {
            return true;
        }

        // Check for COLORTERM
        var colorTerm = Environment.GetEnvironmentVariable("COLORTERM");
        if (!string.IsNullOrEmpty(colorTerm))
        {
            return true;
        }

        // Windows 10+ consoles support ANSI by default
        if (OperatingSystem.IsWindows())
        {
            return Environment.OSVersion.Version.Major >= 10;
        }

        // Assume Unix-like systems support ANSI
        return OperatingSystem.IsLinux() || OperatingSystem.IsMacOS();
    }

    /// <summary>
    /// Gets the terminal type description.
    /// </summary>
    public static string GetTerminalType()
    {
        if (IsWindowsTerminal())
            return "Windows Terminal";

        var term = Environment.GetEnvironmentVariable("TERM") ?? "unknown";

        if (OperatingSystem.IsWindows())
        {
            var comspec = Environment.GetEnvironmentVariable("COMSPEC") ?? "";
            if (comspec.Contains("cmd.exe", StringComparison.OrdinalIgnoreCase))
                return "Command Prompt";
            if (comspec.Contains("powershell", StringComparison.OrdinalIgnoreCase))
                return "PowerShell";
        }

        return term;
    }
}
