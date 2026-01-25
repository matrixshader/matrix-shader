using System.Diagnostics;
using System.Management;
using System.Text.Json;
using System.Text.RegularExpressions;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for identifying and tracking Matrix shader windows.
/// Implements 4-layer resolution hierarchy for reliability.
/// Ported from WindowIdentityService.ps1
///
/// Performance targets:
/// - Layer 1 (Launch Tracking): less than 1ms per window
/// - Layer 2 (Command Line): ~20ms per window
/// - Layer 3 (Title Match): ~5ms per window
/// - Layer 4 (UI Automation): 100-300ms per window (last resort)
/// </summary>
public class IdentityService : IIdentityService
{
    private readonly Dictionary<string, LaunchEntry> _launchRegistry = new();
    private readonly string _registryPath;
    private readonly object _lock = new();

    // Regex to extract shader index from profile name or title
    private static readonly Regex MatrixProfileRegex = new(@"Matrix-(\d+)", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private const string WindowsTerminalProcessName = "WindowsTerminal";
    private const string ControlPanelTitle = "Matrix Control Panel";

    public IdentityService()
    {
        var documentsPath = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        _registryPath = Path.Combine(documentsPath, "Matrix", "identity-registry.json");
    }

    /// <inheritdoc/>
    public IReadOnlyList<WindowInfo> FindMatrixWindows()
    {
        var results = new List<WindowInfo>();
        var terminalWindows = GetTerminalWindows();

        foreach (var (hwnd, title, processId) in terminalWindows)
        {
            var identity = ResolveIdentity(hwnd);
            if (identity != null)
            {
                results.Add(identity);
            }
        }

        // Sort by shader index for consistent ordering
        return results.OrderBy(w => w.ShaderIndex).ToList();
    }

    /// <inheritdoc/>
    public WindowInfo? ResolveIdentity(nint hwnd)
    {
        if (hwnd == nint.Zero)
            return null;

        var title = WindowsApi.GetWindowTitle(hwnd);
        var processId = WindowsApi.GetWindowProcessId(hwnd);

        // Check if this is the control panel window
        if (title.Contains(ControlPanelTitle, StringComparison.OrdinalIgnoreCase))
        {
            return CreateWindowInfo(hwnd, title, processId, "ControlPanel", 0, IdentitySource.Title);
        }

        // Layer 1: Launch Tracking (instant, 100% reliable for windows we launched)
        var launchIdentity = GetLaunchRegistryIdentity(hwnd, processId);
        if (launchIdentity != null)
            return launchIdentity;

        // Layer 2: Command Line Analysis (WMI query, ~20ms)
        var cmdLineIdentity = GetCommandLineIdentity(hwnd, processId, title);
        if (cmdLineIdentity != null)
            return cmdLineIdentity;

        // Layer 3: Title Pattern Matching (fast, ~5ms)
        var titleIdentity = GetTitleIdentity(hwnd, processId, title);
        if (titleIdentity != null)
            return titleIdentity;

        // Layer 4: UI Automation (slow, 100-300ms) - Skip for now, title match is usually sufficient
        // This would require Windows.UI.Automation references

        return null;
    }

    /// <inheritdoc/>
    public void RegisterLaunch(int processId, string profileName, int shaderIndex)
    {
        lock (_lock)
        {
            var entry = new LaunchEntry
            {
                ProfileName = profileName,
                ShaderIndex = shaderIndex,
                ProcessId = processId,
                LaunchTime = DateTime.UtcNow,
                CorrelationId = Guid.NewGuid().ToString("N")[..8]
            };

            // Store by process ID
            _launchRegistry[processId.ToString()] = entry;

            // Persist to disk
            SaveRegistry();
        }
    }

    /// <summary>
    /// Registers a window by its handle for tracking.
    /// More reliable than PID for wt.exe launches since the launcher process exits.
    /// </summary>
    public void RegisterWindowHandle(nint hwnd, string profileName, int shaderIndex)
    {
        lock (_lock)
        {
            var processId = WindowsApi.GetWindowProcessId(hwnd);
            var entry = new LaunchEntry
            {
                ProfileName = profileName,
                ShaderIndex = shaderIndex,
                ProcessId = processId,
                WindowHandle = hwnd,
                LaunchTime = DateTime.UtcNow,
                CorrelationId = Guid.NewGuid().ToString("N")[..8]
            };

            // Store by handle (more reliable than PID)
            _launchRegistry[hwnd.ToString()] = entry;

            // Persist to disk
            SaveRegistry();
        }
    }

    /// <inheritdoc/>
    public void ClearRegistry()
    {
        lock (_lock)
        {
            _launchRegistry.Clear();
            SaveRegistry();
        }
    }

    /// <inheritdoc/>
    public void LoadRegistry()
    {
        lock (_lock)
        {
            _launchRegistry.Clear();

            if (!File.Exists(_registryPath))
                return;

            try
            {
                var json = File.ReadAllText(_registryPath);
                var entries = JsonSerializer.Deserialize<Dictionary<string, LaunchEntry>>(json);

                if (entries != null)
                {
                    foreach (var kvp in entries)
                    {
                        _launchRegistry[kvp.Key] = kvp.Value;
                    }
                }
            }
            catch (Exception)
            {
                // Silently fail - registry is optional
            }
        }
    }

    /// <inheritdoc/>
    public void SaveRegistry()
    {
        lock (_lock)
        {
            try
            {
                var directory = Path.GetDirectoryName(_registryPath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                // Atomic write: temp file + move
                var tempFile = Path.GetTempFileName();
                var json = JsonSerializer.Serialize(_launchRegistry, new JsonSerializerOptions
                {
                    WriteIndented = true
                });
                File.WriteAllText(tempFile, json);
                File.Move(tempFile, _registryPath, overwrite: true);
            }
            catch (Exception)
            {
                // Silently fail - registry is optional
            }
        }
    }

    #region Layer 1: Launch Tracking

    /// <summary>
    /// Layer 1: Look up identity from launch registry (instant).
    /// Checks both handle-based and PID-based entries.
    /// </summary>
    private WindowInfo? GetLaunchRegistryIdentity(nint hwnd, int processId)
    {
        lock (_lock)
        {
            // Try handle-based lookup first (more reliable)
            var handleKey = hwnd.ToString();
            if (_launchRegistry.TryGetValue(handleKey, out var handleEntry))
            {
                // Validate window still exists
                if (WindowsApi.IsWindowVisible(hwnd))
                {
                    return CreateWindowInfo(
                        hwnd,
                        WindowsApi.GetWindowTitle(hwnd),
                        processId,
                        handleEntry.ProfileName,
                        handleEntry.ShaderIndex,
                        IdentitySource.LaunchTracking
                    );
                }
                else
                {
                    // Window gone - remove stale entry
                    _launchRegistry.Remove(handleKey);
                }
            }

            // Try PID-based lookup
            var pidKey = processId.ToString();
            if (_launchRegistry.TryGetValue(pidKey, out var pidEntry))
            {
                // Validate process still running
                try
                {
                    using var process = Process.GetProcessById(processId);
                    if (process != null && !process.HasExited)
                    {
                        return CreateWindowInfo(
                            hwnd,
                            WindowsApi.GetWindowTitle(hwnd),
                            processId,
                            pidEntry.ProfileName,
                            pidEntry.ShaderIndex,
                            IdentitySource.LaunchTracking
                        );
                    }
                }
                catch
                {
                    // Process gone - remove stale entry
                    _launchRegistry.Remove(pidKey);
                }
            }
        }

        return null;
    }

    #endregion

    #region Layer 2: Command Line Analysis

    /// <summary>
    /// Layer 2: Extract profile name from process command line (~20ms).
    /// Uses WMI to query the command line arguments.
    /// </summary>
    private WindowInfo? GetCommandLineIdentity(nint hwnd, int processId, string title)
    {
        try
        {
            var commandLine = GetProcessCommandLine(processId);
            if (string.IsNullOrEmpty(commandLine))
                return null;

            // Look for profile argument: -p "Matrix-N" or --profile "Matrix-N"
            var profileMatch = Regex.Match(commandLine, @"-p\s+[""']?([^""'\s]+)[""']?", RegexOptions.IgnoreCase);
            if (!profileMatch.Success)
            {
                profileMatch = Regex.Match(commandLine, @"--profile\s+[""']?([^""'\s]+)[""']?", RegexOptions.IgnoreCase);
            }

            if (profileMatch.Success)
            {
                var profileArg = profileMatch.Groups[1].Value;
                var matrixMatch = MatrixProfileRegex.Match(profileArg);
                if (matrixMatch.Success)
                {
                    var shaderIndex = int.Parse(matrixMatch.Groups[1].Value);
                    return CreateWindowInfo(hwnd, title, processId, $"Matrix-{shaderIndex}", shaderIndex, IdentitySource.CommandLine);
                }
            }
        }
        catch
        {
            // Fall through to next layer
        }

        return null;
    }

    /// <summary>
    /// Gets the command line for a process using WMI.
    /// </summary>
    private static string? GetProcessCommandLine(int processId)
    {
        try
        {
            using var searcher = new ManagementObjectSearcher(
                $"SELECT CommandLine FROM Win32_Process WHERE ProcessId = {processId}");

            foreach (ManagementObject obj in searcher.Get())
            {
                return obj["CommandLine"]?.ToString();
            }
        }
        catch
        {
            // WMI query failed
        }

        return null;
    }

    #endregion

    #region Layer 3: Title Pattern Matching

    /// <summary>
    /// Layer 3: Match window title pattern (~5ms).
    /// Looks for "Matrix-N" pattern in the window title.
    /// </summary>
    private WindowInfo? GetTitleIdentity(nint hwnd, int processId, string title)
    {
        if (string.IsNullOrEmpty(title))
            return null;

        var match = MatrixProfileRegex.Match(title);
        if (match.Success)
        {
            var shaderIndex = int.Parse(match.Groups[1].Value);
            return CreateWindowInfo(hwnd, title, processId, $"Matrix-{shaderIndex}", shaderIndex, IdentitySource.Title);
        }

        return null;
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Gets all visible Windows Terminal windows.
    /// </summary>
    private List<(nint hwnd, string title, int processId)> GetTerminalWindows()
    {
        var results = new List<(nint, string, int)>();
        var allWindows = WindowsApi.GetVisibleWindows();

        foreach (var hwnd in allWindows)
        {
            try
            {
                var processId = WindowsApi.GetWindowProcessId(hwnd);
                using var process = Process.GetProcessById(processId);

                if (process.ProcessName.Equals(WindowsTerminalProcessName, StringComparison.OrdinalIgnoreCase))
                {
                    var title = WindowsApi.GetWindowTitle(hwnd);
                    if (!string.IsNullOrEmpty(title))
                    {
                        results.Add((hwnd, title, processId));
                    }
                }
            }
            catch
            {
                // Process may have exited - skip
            }
        }

        return results;
    }

    /// <summary>
    /// Creates a WindowInfo record with all identity information.
    /// </summary>
    private static WindowInfo CreateWindowInfo(
        nint hwnd,
        string title,
        int processId,
        string profileName,
        int shaderIndex,
        IdentitySource source)
    {
        var position = WindowsApi.GetWindowPosition(hwnd) ?? new WindowRect();
        var isControlPanel = profileName == "ControlPanel" || title.Contains(ControlPanelTitle, StringComparison.OrdinalIgnoreCase);

        return new WindowInfo
        {
            Handle = hwnd,
            Title = title,
            ProcessId = processId,
            ProfileName = profileName,
            ShaderIndex = shaderIndex,
            Position = position,
            Source = source,
            IsControlPanel = isControlPanel
        };
    }

    #endregion

    #region Internal Types

    /// <summary>
    /// Entry stored in the launch tracking registry.
    /// </summary>
    private record LaunchEntry
    {
        public string ProfileName { get; init; } = string.Empty;
        public int ShaderIndex { get; init; }
        public int ProcessId { get; init; }
        public nint WindowHandle { get; init; }
        public DateTime LaunchTime { get; init; }
        public string CorrelationId { get; init; } = string.Empty;
    }

    #endregion
}
