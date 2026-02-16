using System.Diagnostics;
using System.Net.Http;
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

    /// <summary>
    /// Windows Terminal settings.json locations to check (in priority order).
    /// Supports Store, Winget, Scoop, and Chocolatey installations.
    /// </summary>
    private static readonly string[] WtSettingsPaths = new[]
    {
        // Microsoft Store install (most common)
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Packages", "Microsoft.WindowsTerminal_8wekyb3d8bbwe", "LocalState", "settings.json"),
        // Winget / unpackaged install
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Microsoft", "Windows Terminal", "settings.json"),
        // Scoop install
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "scoop", "persist", "windows-terminal", "settings", "settings.json"),
        // Chocolatey install
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "chocolatey", "lib", "microsoft-windows-terminal", "settings.json"),
    };

    // Legacy single path kept for backward compatibility
    private static readonly string SettingsPath = WtSettingsPaths[0];

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
                // Check if WT was actually installed but needs restart
                if (IsWindowsTerminalInstalled())
                {
                    return new BootstrapResult(false, "Restart in Windows Terminal required.");
                }
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
    /// Checks if Windows Terminal is installed by checking multiple known paths.
    /// Supports Store, Winget, Scoop, Chocolatey, and PATH-based installations.
    /// </summary>
    public static bool IsWindowsTerminalInstalled()
    {
        // Check settings files across all known install locations
        if (WtSettingsPaths.Any(File.Exists))
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"WT detected via settings.json: {GetSettingsPath()}");
            return true;
        }

        // Check if wt.exe is in PATH (portable or custom install)
        var wtExePath = GetWindowsTerminalExePath();
        if (wtExePath != null)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"WT detected via PATH: {wtExePath}");
            return true;
        }

        // Check parent process (running inside WT)
        if (EnvironmentService.IsWindowsTerminal())
        {
            DiagnosticLogger.Debug("BOOTSTRAP", "WT detected via parent process");
            return true;
        }

        return false;
    }

    /// <summary>
    /// Finds wt.exe path dynamically across multiple install locations.
    /// </summary>
    /// <returns>Full path to wt.exe if found, null otherwise</returns>
    public static string? GetWindowsTerminalExePath()
    {
        // Check PATH first (most reliable for all install types)
        var pathDirs = Environment.GetEnvironmentVariable("PATH")?.Split(Path.PathSeparator) ?? Array.Empty<string>();
        foreach (var dir in pathDirs)
        {
            try
            {
                var wtPath = Path.Combine(dir, "wt.exe");
                if (File.Exists(wtPath))
                {
                    return wtPath;
                }
            }
            catch
            {
                // Invalid path entry, skip
            }
        }

        // Check common install locations
        var commonPaths = new[]
        {
            // Scoop
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "scoop", "apps", "windows-terminal", "current", "wt.exe"),
            // Chocolatey
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "chocolatey", "bin", "wt.exe"),
        };

        foreach (var path in commonPaths)
        {
            if (File.Exists(path))
            {
                return path;
            }
        }

        // Check WindowsApps for Store install (may have access issues)
        try
        {
            var windowsAppsPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "WindowsApps");

            if (Directory.Exists(windowsAppsPath))
            {
                var wtFolders = Directory.GetDirectories(windowsAppsPath, "Microsoft.WindowsTerminal_*");
                foreach (var folder in wtFolders)
                {
                    var wtPath = Path.Combine(folder, "wt.exe");
                    if (File.Exists(wtPath))
                    {
                        return wtPath;
                    }
                }
            }
        }
        catch (UnauthorizedAccessException)
        {
            // WindowsApps folder is restricted - expected behavior
            DiagnosticLogger.Debug("BOOTSTRAP", "Cannot access WindowsApps folder for wt.exe detection");
        }
        catch
        {
            // Other errors, skip
        }

        // Not found
        return null;
    }

    /// <summary>
    /// Auto-launches Windows Terminal with wakeupneo after WT is installed.
    /// Falls back to manual instructions if auto-launch fails.
    /// </summary>
    private static void ShowRestartInstructions()
    {
        Console.WriteLine();
        ConsoleHelper.WriteLineMatrixGreen(" Windows Terminal installed successfully!");
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Launching Windows Terminal with wakeupneo...");
        Console.WriteLine();

        try
        {
            // Find wakeupneo.exe path
            var wakeupneoPath = Path.Combine(AppContext.BaseDirectory, "wakeupneo.exe");
            if (!File.Exists(wakeupneoPath))
            {
                // Try Program Files
                wakeupneoPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                    "MatrixShader", "wakeupneo.exe");
            }
            if (!File.Exists(wakeupneoPath))
            {
                // Try LocalAppData
                wakeupneoPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Programs", "MatrixShader", "wakeupneo.exe");
            }

            if (File.Exists(wakeupneoPath))
            {
                // Launch WT with wakeupneo
                var psi = new ProcessStartInfo
                {
                    FileName = "wt.exe",
                    Arguments = $"\"{wakeupneoPath}\"",
                    UseShellExecute = true
                };
                Process.Start(psi);

                ConsoleHelper.WriteLineDim(" Windows Terminal is starting...");
                ConsoleHelper.WriteLineDim(" This window will close automatically.");
                Thread.Sleep(2000);
                Environment.Exit(0); // Kill the old cmd/powershell window
                return;
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"Auto-launch failed: {ex.Message}");
        }

        // Fallback to manual instructions if auto-launch fails
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Auto-launch failed. Please manually:");
        ConsoleHelper.WriteLineDim("   1. Close this window");
        ConsoleHelper.WriteLineDim("   2. Type 'wt' to open Windows Terminal");
        ConsoleHelper.WriteLineDim("   3. Run 'wakeupneo' again");
        Console.WriteLine();
        Console.Write(" Press any key to exit...");
        Console.ReadKey(intercept: true);
        Console.WriteLine();
    }

    /// <summary>
    /// Checks if winget is available on this system.
    /// </summary>
    private static bool IsWingetAvailable()
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "winget",
                Arguments = "--version",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process == null)
                return false;

            process.WaitForExit(5000); // 5 second timeout
            return process.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Attempts to install Windows Terminal via multiple methods automatically.
    /// No user prompts — tries each method silently, moves to next on failure.
    /// Priority: winget -> Microsoft Store -> GitHub download -> fallback
    /// </summary>
    private static async Task<bool> TryInstallWindowsTerminalAsync(bool verbose)
    {
        ConsoleHelper.WriteMatrixGreen(" Installing Windows Terminal...");
        Console.WriteLine();

        // Method 1: Try winget (if available)
        if (IsWingetAvailable())
        {
            try
            {
                ConsoleHelper.WriteLineDim("   winget...");

                var psi = new ProcessStartInfo
                {
                    FileName = "winget",
                    Arguments = "install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --silent",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = Process.Start(psi);
                if (process != null)
                {
                    await process.WaitForExitAsync();
                    await Task.Delay(1000);

                    if (IsWindowsTerminalInstalled())
                    {
                        ConsoleHelper.WriteLineMatrixGreen("   winget: OK");
                        if (!EnvironmentService.IsWindowsTerminal())
                        {
                            ShowRestartInstructions();
                            return false;
                        }
                        return true;
                    }
                }
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Debug("BOOTSTRAP", $"winget install failed: {ex.Message}");
            }
            ConsoleHelper.WriteLineDim("   winget: failed");
        }
        else
        {
            ConsoleHelper.WriteLineDim("   winget: not available");
        }

        // Method 2: Direct download from GitHub (fully automatic, no user interaction)
        try
        {
            ConsoleHelper.WriteLineDim("   GitHub download...");
            var downloaded = await TryDownloadFromGitHubAsync(verbose);
            if (downloaded && IsWindowsTerminalInstalled())
            {
                ConsoleHelper.WriteLineMatrixGreen("   GitHub: OK");
                if (!EnvironmentService.IsWindowsTerminal())
                {
                    ShowRestartInstructions();
                    return false;
                }
                return true;
            }
            ConsoleHelper.WriteLineDim("   GitHub: failed");
        }
        catch
        {
            ConsoleHelper.WriteLineDim("   GitHub: failed");
        }

        // Method 3: Microsoft Store (last resort — requires user interaction)
        try
        {
            ConsoleHelper.WriteLineDim("   Microsoft Store...");
            Process.Start(new ProcessStartInfo
            {
                FileName = "ms-windows-store://pdp/?ProductId=9N0DX20HK701",
                UseShellExecute = true
            });

            // Wait for store to open and user to install (poll for 30 seconds)
            for (int i = 0; i < 30; i++)
            {
                await Task.Delay(1000);
                if (IsWindowsTerminalInstalled())
                {
                    ConsoleHelper.WriteLineMatrixGreen("   Microsoft Store: OK");
                    if (!EnvironmentService.IsWindowsTerminal())
                    {
                        ShowRestartInstructions();
                        return false;
                    }
                    return true;
                }
            }
            ConsoleHelper.WriteLineDim("   Microsoft Store: not installed yet");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"Store install failed: {ex.Message}");
            ConsoleHelper.WriteLineDim("   Microsoft Store: not available");
        }

        // All methods failed — continue silently to Lite mode
        Console.WriteLine();
        ConsoleHelper.WriteLineDim(" Windows Terminal not available — continuing with text fallback.");
        Console.WriteLine();

        return false;
    }

    /// <summary>
    /// Downloads and installs Windows Terminal from GitHub releases.
    /// Includes automatic installation of Microsoft.UI.Xaml dependency.
    /// </summary>
    private static async Task<bool> TryDownloadFromGitHubAsync(bool verbose)
    {
        const string releasesApi = "https://api.github.com/repos/microsoft/terminal/releases/latest";
        const string xamlPackageUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6";

        try
        {
            ConsoleHelper.WriteLineDim(" Checking latest release...");

            using var httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.Add("User-Agent", "MatrixShader-Installer");
            httpClient.Timeout = TimeSpan.FromSeconds(120);

            // Get latest release info
            var response = await httpClient.GetStringAsync(releasesApi);

            // Simple JSON parsing for the msixbundle URL
            // Look for: "browser_download_url": "...msixbundle"
            var match = System.Text.RegularExpressions.Regex.Match(
                response,
                @"""browser_download_url"":\s*""([^""]+\.msixbundle)""");

            if (!match.Success)
            {
                ConsoleHelper.WriteLineDim(" Could not find download URL in release.");
                return false;
            }

            var downloadUrl = match.Groups[1].Value;
            var fileName = Path.GetFileName(downloadUrl);
            var tempDir = Path.Combine(Path.GetTempPath(), "MatrixWTInstall");
            Directory.CreateDirectory(tempDir);
            var downloadPath = Path.Combine(tempDir, fileName);

            ConsoleHelper.WriteLineDim($" Downloading: {fileName}");
            ConsoleHelper.WriteLineDim(" (This may take a minute...)");

            // Download the file with progress
            using (var downloadResponse = await httpClient.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead))
            {
                downloadResponse.EnsureSuccessStatusCode();
                var totalBytes = downloadResponse.Content.Headers.ContentLength ?? 0;

                await using var fileStream = File.Create(downloadPath);
                await using var downloadStream = await downloadResponse.Content.ReadAsStreamAsync();

                var buffer = new byte[81920];
                long totalRead = 0;
                int bytesRead;

                while ((bytesRead = await downloadStream.ReadAsync(buffer)) > 0)
                {
                    await fileStream.WriteAsync(buffer.AsMemory(0, bytesRead));
                    totalRead += bytesRead;

                    if (totalBytes > 0 && !verbose)
                    {
                        var progress = (int)(totalRead * 100 / totalBytes);
                        Console.Write($"\r   Progress: {progress}%   ");
                    }
                }
            }

            Console.WriteLine();
            ConsoleHelper.WriteLineDim(" Download complete.");

            // Install XAML dependency first (required for WT msixbundle)
            ConsoleHelper.WriteLineDim(" Installing Microsoft.UI.Xaml dependency...");
            var xamlInstalled = await TryInstallXamlDependencyAsync(httpClient, tempDir, xamlPackageUrl);
            if (!xamlInstalled)
            {
                ConsoleHelper.WriteLineWarning(" XAML dependency installation failed.");
                ConsoleHelper.WriteLineDim(" Windows Terminal may fail to install.");
                ConsoleHelper.WriteLineDim(" Manual fix: Install Microsoft.UI.Xaml from NuGet or Microsoft Store.");
            }

            // Install Windows Terminal using Add-AppxPackage (PowerShell)
            ConsoleHelper.WriteLineDim(" Installing Windows Terminal...");
            var installPsi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -Command \"Add-AppxPackage -Path '{downloadPath}'\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true
            };

            using var installProcess = Process.Start(installPsi);
            if (installProcess != null)
            {
                await installProcess.WaitForExitAsync();

                if (installProcess.ExitCode != 0)
                {
                    var error = await installProcess.StandardError.ReadToEndAsync();
                    DiagnosticLogger.Debug("BOOTSTRAP", $"Install failed: {error}");

                    // Check if it's a dependency error and provide helpful message
                    if (error.Contains("dependency", StringComparison.OrdinalIgnoreCase) ||
                        error.Contains("Xaml", StringComparison.OrdinalIgnoreCase))
                    {
                        ConsoleHelper.WriteLineWarning(" Installation failed due to missing dependency.");
                        ConsoleHelper.WriteLineDim(" Try installing from Microsoft Store instead.");
                    }
                    else
                    {
                        ConsoleHelper.WriteLineDim(" Installation failed. You may need to install manually.");
                    }
                    return false;
                }
            }

            // Wait for settings.json to be created
            await Task.Delay(2000);

            // Cleanup
            try { File.Delete(downloadPath); } catch { }
            try { Directory.Delete(tempDir, recursive: true); } catch { }

            return IsWindowsTerminalInstalled();
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"GitHub download failed: {ex.Message}");
            ConsoleHelper.WriteLineDim($" Download failed: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Downloads and installs Microsoft.UI.Xaml 2.8 dependency from NuGet.
    /// This is required for Windows Terminal msixbundle installation.
    /// </summary>
    private static async Task<bool> TryInstallXamlDependencyAsync(HttpClient httpClient, string tempDir, string xamlPackageUrl)
    {
        try
        {
            var xamlZipPath = Path.Combine(tempDir, "xaml.zip");
            var xamlExtractPath = Path.Combine(tempDir, "xaml");

            // Download XAML package from NuGet
            DiagnosticLogger.Debug("BOOTSTRAP", $"Downloading XAML from: {xamlPackageUrl}");
            using (var xamlResponse = await httpClient.GetAsync(xamlPackageUrl))
            {
                xamlResponse.EnsureSuccessStatusCode();
                await using var xamlFileStream = File.Create(xamlZipPath);
                await xamlResponse.Content.CopyToAsync(xamlFileStream);
            }

            // Extract the zip using PowerShell (Expand-Archive)
            var extractPsi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -Command \"Expand-Archive -Path '{xamlZipPath}' -DestinationPath '{xamlExtractPath}' -Force\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true
            };

            using var extractProcess = Process.Start(extractPsi);
            if (extractProcess != null)
            {
                await extractProcess.WaitForExitAsync();
                if (extractProcess.ExitCode != 0)
                {
                    var error = await extractProcess.StandardError.ReadToEndAsync();
                    DiagnosticLogger.Debug("BOOTSTRAP", $"XAML extract failed: {error}");
                    return false;
                }
            }

            // Find and install the x64 appx (path: tools/AppX/x64/Release/Microsoft.UI.Xaml.2.8.appx)
            var xamlAppxPath = Path.Combine(xamlExtractPath, "tools", "AppX", "x64", "Release", "Microsoft.UI.Xaml.2.8.appx");

            if (!File.Exists(xamlAppxPath))
            {
                // Try alternate path structure
                var altPath = Directory.GetFiles(xamlExtractPath, "Microsoft.UI.Xaml.*.appx", SearchOption.AllDirectories)
                    .FirstOrDefault(p => p.Contains("x64", StringComparison.OrdinalIgnoreCase));

                if (altPath != null)
                {
                    xamlAppxPath = altPath;
                }
                else
                {
                    DiagnosticLogger.Debug("BOOTSTRAP", $"XAML appx not found at expected path: {xamlAppxPath}");
                    return false;
                }
            }

            DiagnosticLogger.Debug("BOOTSTRAP", $"Installing XAML from: {xamlAppxPath}");

            // Install the XAML appx
            var installPsi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -Command \"Add-AppxPackage -Path '{xamlAppxPath}'\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true
            };

            using var installProcess = Process.Start(installPsi);
            if (installProcess != null)
            {
                await installProcess.WaitForExitAsync();
                if (installProcess.ExitCode != 0)
                {
                    var error = await installProcess.StandardError.ReadToEndAsync();
                    // Ignore "already installed" errors
                    if (!error.Contains("already installed", StringComparison.OrdinalIgnoreCase) &&
                        !error.Contains("higher version", StringComparison.OrdinalIgnoreCase))
                    {
                        DiagnosticLogger.Debug("BOOTSTRAP", $"XAML install failed: {error}");
                        return false;
                    }
                    DiagnosticLogger.Debug("BOOTSTRAP", "XAML dependency already installed or newer version present");
                }
            }

            // Cleanup XAML files
            try { File.Delete(xamlZipPath); } catch { }
            try { Directory.Delete(xamlExtractPath, recursive: true); } catch { }

            ConsoleHelper.WriteLineDim(" XAML dependency installed.");
            return true;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("BOOTSTRAP", $"XAML dependency installation failed: {ex.Message}");
            return false;
        }
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
    /// Returns the first existing path from known install locations,
    /// or the default Store path if none exist.
    /// </summary>
    public static string GetSettingsPath()
    {
        var existingPath = WtSettingsPaths.FirstOrDefault(File.Exists);
        return existingPath ?? SettingsPath;
    }

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
