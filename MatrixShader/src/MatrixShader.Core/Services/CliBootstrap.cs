using System.Diagnostics;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;

namespace MatrixShader.Core.Services;

/// <summary>
/// Result of CLI bootstrap initialization.
/// </summary>
/// <param name="Success">Whether initialization succeeded</param>
/// <param name="ErrorMessage">Error message if failed</param>
/// <param name="WasFirstRun">Whether this was the first run (directories created)</param>
/// <param name="ProfilesCreated">Number of Matrix profiles created</param>
public record BootstrapResult(
    bool Success,
    string? ErrorMessage = null,
    bool WasFirstRun = false,
    int ProfilesCreated = 0);

/// <summary>
/// Shared bootstrap logic for all CLI entry points.
/// Handles Windows Terminal detection, installation, directory setup, and profile creation.
/// </summary>
public static class CliBootstrap
{
    private static readonly string MatrixDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MatrixShader");

    private static readonly string ShadersDir = Path.Combine(MatrixDir, "shaders");

    private static readonly string InstalledShadersDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
        "MatrixShader", "shaders");

    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Packages",
        "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
        "LocalState",
        "settings.json");

    /// <summary>
    /// Initializes the CLI environment.
    /// Checks for Windows Terminal, creates directories, sets up profiles.
    /// </summary>
    /// <param name="verbose">Whether to show verbose output</param>
    /// <param name="skipTerminalCheck">Skip Windows Terminal check (for testing)</param>
    /// <returns>Bootstrap result indicating success/failure</returns>
    public static async Task<BootstrapResult> InitializeAsync(bool verbose = false, bool skipTerminalCheck = false)
    {
        // Enable ANSI escape codes first
        ConsoleHelper.EnableAnsiEscapeCodes();

        // Check for --debug flag or MATRIX_DEBUG environment variable
        var debugEnabled = Environment.GetEnvironmentVariable("MATRIX_DEBUG") == "1";
        DiagnosticLogger.Initialize(debugEnabled);

        DiagnosticLogger.Info("BOOTSTRAP", "CLI bootstrap starting");

        // Step 1: Check Windows Terminal
        if (!skipTerminalCheck && !IsWindowsTerminalInstalled())
        {
            DiagnosticLogger.Warn("BOOTSTRAP", "Windows Terminal not found");

            if (verbose)
            {
                ConsoleHelper.WriteLineDim("Windows Terminal not detected.");
            }

            var installed = await TryInstallWindowsTerminalAsync(verbose);
            if (!installed)
            {
                return new BootstrapResult(false, "Windows Terminal is required but not installed.");
            }

            DiagnosticLogger.Info("BOOTSTRAP", "Windows Terminal installed successfully");
        }

        // Step 2: Ensure directories exist
        var wasFirstRun = EnsureDirectories();

        if (wasFirstRun)
        {
            DiagnosticLogger.Info("BOOTSTRAP", "First run - created Matrix directories");
        }

        DiagnosticLogger.Info("BOOTSTRAP", "CLI bootstrap complete");

        return new BootstrapResult(true, WasFirstRun: wasFirstRun);
    }

    /// <summary>
    /// Checks if Windows Terminal is installed by verifying settings.json exists.
    /// </summary>
    public static bool IsWindowsTerminalInstalled()
    {
        return File.Exists(SettingsPath);
    }

    /// <summary>
    /// Attempts to install Windows Terminal via winget, with Microsoft Store fallback.
    /// </summary>
    private static async Task<bool> TryInstallWindowsTerminalAsync(bool verbose)
    {
        // Try winget first
        try
        {
            ConsoleHelper.WriteLineMatrixGreen("Installing Windows Terminal via winget...");

            var psi = new ProcessStartInfo
            {
                FileName = "winget",
                Arguments = "install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements",
                RedirectStandardOutput = !verbose,
                RedirectStandardError = !verbose,
                UseShellExecute = false,
                CreateNoWindow = !verbose
            };

            using var process = Process.Start(psi);
            if (process == null)
            {
                DiagnosticLogger.Warn("BOOTSTRAP", "Failed to start winget process");
            }
            else
            {
                await process.WaitForExitAsync();

                // Wait a moment for settings.json to be created
                await Task.Delay(1000);

                // Verify installation succeeded
                if (IsWindowsTerminalInstalled())
                {
                    ConsoleHelper.WriteLineMatrixGreen("Windows Terminal installed successfully!");
                    return true;
                }
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("BOOTSTRAP", $"winget installation failed: {ex.Message}");
        }

        // Fallback: Prompt for Microsoft Store
        Console.WriteLine();
        Console.Write("\x1b[33mWindows Terminal not found. Install from Microsoft Store? [Y/N]: \x1b[0m");
        var key = Console.ReadKey(intercept: true);
        Console.WriteLine();

        if (key.Key == ConsoleKey.Y)
        {
            // Open Microsoft Store page
            Process.Start(new ProcessStartInfo
            {
                FileName = "ms-windows-store://pdp/?ProductId=9N0DX20HK701",
                UseShellExecute = true
            });

            ConsoleHelper.WriteLineDim("Press any key after installation completes...");
            Console.ReadKey(intercept: true);

            return IsWindowsTerminalInstalled();
        }

        return false;
    }

    /// <summary>
    /// Ensures Matrix directories exist.
    /// </summary>
    /// <returns>True if this was first run (directories created)</returns>
    private static bool EnsureDirectories()
    {
        var wasFirstRun = !Directory.Exists(MatrixDir);

        if (!Directory.Exists(MatrixDir))
        {
            Directory.CreateDirectory(MatrixDir);
            DiagnosticLogger.Debug("BOOTSTRAP", $"Created directory: {MatrixDir}");
        }

        if (!Directory.Exists(ShadersDir))
        {
            Directory.CreateDirectory(ShadersDir);
            DiagnosticLogger.Debug("BOOTSTRAP", $"Created directory: {ShadersDir}");
        }

        // Check shader availability and log path being used
        var localShadersExist = Directory.Exists(ShadersDir) &&
            Directory.GetFiles(ShadersDir, "*.hlsl").Length > 0;
        var installedShadersExist = Directory.Exists(InstalledShadersDir) &&
            Directory.GetFiles(InstalledShadersDir, "*.hlsl").Length > 0;

        if (localShadersExist)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"Using shaders from LocalAppData: {ShadersDir}");
        }
        else if (installedShadersExist)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"Installed shaders found at: {InstalledShadersDir}");
            DiagnosticLogger.Info("BOOTSTRAP", "Run 'wakeupneo' to copy shaders to user directory");
        }
        else
        {
            DiagnosticLogger.Warn("BOOTSTRAP", "No shaders found - run 'wakeupneo' to set up");
        }

        return wasFirstRun;
    }

    /// <summary>
    /// Displays a random Matrix quote.
    /// </summary>
    public static void ShowRandomQuote()
    {
        var quote = MatrixQuotes.GetRandom();
        ConsoleHelper.WriteLineDim($" \"{quote}\"");
        Console.WriteLine();
    }

    /// <summary>
    /// Typewriter effect - writes text character by character.
    /// </summary>
    /// <param name="text">Text to display</param>
    /// <param name="charDelayMs">Delay between characters (default 150ms for cinematic feel)</param>
    /// <param name="useMatrixGreen">Whether to use Matrix green color</param>
    /// <param name="ct">Cancellation token</param>
    public static async Task TypewriterAsync(
        string text,
        int charDelayMs = 150,
        bool useMatrixGreen = true,
        CancellationToken ct = default)
    {
        if (useMatrixGreen)
            Console.Write("\x1b[32m");

        foreach (char c in text)
        {
            if (ct.IsCancellationRequested)
                break;

            Console.Write(c);

            try
            {
                await Task.Delay(charDelayMs, ct);
            }
            catch (TaskCanceledException)
            {
                break;
            }
        }

        if (useMatrixGreen)
            Console.Write("\x1b[0m");

        Console.WriteLine();
    }

    /// <summary>
    /// Arrow-key menu for interactive selection.
    /// </summary>
    /// <param name="options">Menu options</param>
    /// <param name="prompt">Prompt to display above options</param>
    /// <returns>Index of selected option, or -1 if user cancelled with Escape</returns>
    public static int ArrowKeyMenu(string[] options, string prompt)
    {
        int selected = 0;
        ConsoleKey key;

        do
        {
            Console.Clear();
            ConsoleHelper.WriteLineMatrixGreen($" {prompt}");
            Console.WriteLine();

            for (int i = 0; i < options.Length; i++)
            {
                if (i == selected)
                {
                    Console.WriteLine($" > \x1b[1;32m{options[i]}\x1b[0m");
                }
                else
                {
                    Console.WriteLine($"   \x1b[90m{options[i]}\x1b[0m");
                }
            }

            key = Console.ReadKey(intercept: true).Key;

            if (key == ConsoleKey.UpArrow)
                selected = (selected - 1 + options.Length) % options.Length;
            else if (key == ConsoleKey.DownArrow)
                selected = (selected + 1) % options.Length;
            else if (key == ConsoleKey.Escape)
                return -1; // User cancelled

        } while (key != ConsoleKey.Enter);

        return selected;
    }

    /// <summary>
    /// Gets the Matrix directory path.
    /// </summary>
    public static string GetMatrixDirectory() => MatrixDir;

    /// <summary>
    /// Gets the shaders directory path (user's LocalAppData).
    /// </summary>
    public static string GetShadersDirectory() => ShadersDir;

    /// <summary>
    /// Gets the installed shaders directory path (Program Files).
    /// This is where the installer places shaders.
    /// </summary>
    public static string GetInstalledShadersDirectory() => InstalledShadersDir;

    /// <summary>
    /// Gets the Windows Terminal settings.json path.
    /// </summary>
    public static string GetSettingsPath() => SettingsPath;

    /// <summary>
    /// Parses common CLI arguments.
    /// </summary>
    /// <param name="args">Command line arguments</param>
    /// <returns>Parsed options</returns>
    public static CliOptions ParseArgs(string[] args)
    {
        return new CliOptions
        {
            ShowHelp = args.Contains("--help") || args.Contains("-h"),
            Debug = args.Contains("--debug") || Environment.GetEnvironmentVariable("MATRIX_DEBUG") == "1",
            Morpheus = args.Contains("--morpheus"),
            AgentSmith = args.Contains("--agent-smith")
        };
    }
}

/// <summary>
/// Parsed CLI options.
/// </summary>
public record CliOptions
{
    /// <summary>Show help text and exit.</summary>
    public bool ShowHelp { get; init; }

    /// <summary>Enable debug/diagnostic logging.</summary>
    public bool Debug { get; init; }

    /// <summary>Easter egg: Morpheus mode - philosophical explanations.</summary>
    public bool Morpheus { get; init; }

    /// <summary>Easter egg: Agent Smith chaos mode.</summary>
    public bool AgentSmith { get; init; }
}
