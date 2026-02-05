using System.Diagnostics;
using System.Management;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows.Automation;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Serialization;

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
    /// <summary>
    /// In-memory launch registry for Layer 1 identity resolution.
    /// Keys are either window handle or process ID as string.
    /// </summary>
    private readonly Dictionary<string, LaunchEntry> _launchRegistry = new();

    /// <summary>
    /// Tracks which registry entries were loaded from disk (vs registered this session).
    /// Used to distinguish fresh (1.0 confidence) from recovered (0.95 confidence).
    /// </summary>
    private readonly HashSet<string> _recoveredKeys = new();

    /// <summary>
    /// Path to the persisted identity registry file.
    /// </summary>
    private readonly string _registryPath;

    /// <summary>
    /// Lock for thread-safe registry access.
    /// </summary>
    private readonly object _lock = new();

    // Regex to extract shader index from profile name or title
    private static readonly Regex MatrixProfileRegex = new(@"Matrix-(\d+)", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private const string WindowsTerminalProcessName = "WindowsTerminal";
    private const string ControlPanelTitle = "Matrix Control Panel";

    public IdentityService()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        _registryPath = Path.Combine(localAppData, "MatrixShader", "identity-registry.json");

        // Load existing registry on construction
        LoadRegistry();
    }

    /// <inheritdoc/>
    public IReadOnlyList<WindowInfo> FindMatrixWindows()
    {
        var results = new List<WindowInfo>();
        var terminalWindows = GetTerminalWindows();

        if (terminalWindows.Count == 0)
            return results;

        // Batch query command lines for all PIDs (Layer 2 optimization - O(1) instead of O(n))
        var pids = terminalWindows.Select(w => w.processId).Distinct();
        var commandLineCache = BatchQueryCommandLines(pids);

        foreach (var (hwnd, title, processId) in terminalWindows)
        {
            var identity = ResolveIdentityWithCache(hwnd, title, processId, commandLineCache);
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
        // Validate handle first - BOTH IsWindow AND IsWindowVisible must pass
        if (!WindowsApi.IsHandleValid(hwnd))
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

        // Layer 2: Command Line Analysis (single process - batch used in FindMatrixWindows)
        var cmdLineIdentity = GetCommandLineIdentity(hwnd, processId, title);
        if (cmdLineIdentity != null)
            return cmdLineIdentity;

        // Layer 3: Title Pattern Matching (fast, ~5ms)
        var titleIdentity = GetTitleIdentity(hwnd, processId, title);
        if (titleIdentity != null)
            return titleIdentity;

        // Layer 4: UI Automation (slow fallback, 100-300ms)
        var uiaIdentity = GetUIAutomationIdentity(hwnd, processId, title);
        if (uiaIdentity != null)
            return uiaIdentity;

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
            _recoveredKeys.Clear();
            SaveRegistry();
        }
    }

    /// <inheritdoc/>
    public int CleanStaleEntries(TimeSpan? maxAge = null)
    {
        var age = maxAge ?? TimeSpan.FromHours(24);
        var cutoff = DateTime.UtcNow - age;
        var removed = 0;

        lock (_lock)
        {
            var keysToRemove = new List<string>();

            foreach (var (key, entry) in _launchRegistry)
            {
                var shouldRemove = false;

                // Check if process still exists
                if (entry.ProcessId > 0)
                {
                    try
                    {
                        using var process = Process.GetProcessById(entry.ProcessId);
                        if (process.HasExited)
                            shouldRemove = true;
                    }
                    catch
                    {
                        // Process doesn't exist - mark for removal
                        shouldRemove = true;
                    }
                }

                // Check age
                if (!shouldRemove && entry.LaunchTime < cutoff)
                    shouldRemove = true;

                // Check handle validity (if stored)
                if (!shouldRemove && entry.WindowHandle != nint.Zero)
                {
                    if (!WindowsApi.IsHandleValid(entry.WindowHandle))
                        shouldRemove = true;
                }

                if (shouldRemove)
                    keysToRemove.Add(key);
            }

            foreach (var key in keysToRemove)
            {
                _launchRegistry.Remove(key);
                _recoveredKeys.Remove(key);
                removed++;
            }

            // Save cleaned registry
            if (removed > 0)
                SaveRegistryAtomic();
        }

        return removed;
    }

    /// <inheritdoc/>
    public void LoadRegistry()
    {
        lock (_lock)
        {
            _launchRegistry.Clear();
            _recoveredKeys.Clear();

            if (!File.Exists(_registryPath))
                return;

            try
            {
                var json = File.ReadAllText(_registryPath);
                var registry = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.IdentityRegistry);

                if (registry?.Entries != null)
                {
                    foreach (var (key, entry) in registry.Entries)
                    {
                        _launchRegistry[key] = new LaunchEntry
                        {
                            ProfileName = entry.ProfileName,
                            ShaderIndex = entry.ShaderIndex,
                            ProcessId = entry.ProcessId,
                            WindowHandle = nint.TryParse(entry.WindowHandle, out var hwnd) ? hwnd : nint.Zero,
                            LaunchTime = entry.LaunchTime,
                            CorrelationId = entry.CorrelationId
                        };
                        // Track that this entry was loaded from disk (recovered)
                        _recoveredKeys.Add(key);
                    }
                }
            }
            catch
            {
                // Silently fail - registry is optional, will start fresh
            }
        }
    }

    /// <inheritdoc/>
    public void SaveRegistry()
    {
        lock (_lock)
        {
            SaveRegistryAtomic();
        }
    }

    /// <summary>
    /// Atomic registry save: temp file + File.Move pattern.
    /// Uses source-generated JSON for AOT compatibility.
    /// </summary>
    private void SaveRegistryAtomic()
    {
        string? tempPath = null;
        try
        {
            var directory = Path.GetDirectoryName(_registryPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // Build IdentityRegistry from internal LaunchEntry dictionary
            var registry = new IdentityRegistry
            {
                Version = "1.0",
                SavedAt = DateTime.UtcNow,
                Entries = _launchRegistry.ToDictionary(
                    kvp => kvp.Key,
                    kvp => new IdentityEntry
                    {
                        ProfileName = kvp.Value.ProfileName,
                        ShaderIndex = kvp.Value.ShaderIndex,
                        ProcessId = kvp.Value.ProcessId,
                        WindowHandle = kvp.Value.WindowHandle.ToString(),
                        LaunchTime = kvp.Value.LaunchTime,
                        CorrelationId = kvp.Value.CorrelationId
                    })
            };

            // Atomic write: temp file + move
            tempPath = _registryPath + ".tmp";
            var json = JsonSerializer.Serialize(registry, MatrixJsonContext.Default.IdentityRegistry);
            File.WriteAllText(tempPath, json, new UTF8Encoding(false));
            File.Move(tempPath, _registryPath, overwrite: true);
        }
        catch
        {
            // Clean up temp file on failure
            if (tempPath != null)
            {
                try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { }
            }
            // Silently fail - registry is optional
        }
    }

    #region Layer 1: Launch Tracking

    /// <summary>
    /// Layer 1: Look up identity from launch registry (instant).
    /// Checks both handle-based and PID-based entries.
    /// Returns LaunchTracking (confidence 1.0) for fresh registrations,
    /// LaunchTrackingRecovered (confidence 0.95) for entries loaded from disk.
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
                    // Distinguish fresh vs recovered for confidence scoring
                    var source = _recoveredKeys.Contains(handleKey)
                        ? IdentitySource.LaunchTrackingRecovered
                        : IdentitySource.LaunchTracking;

                    return CreateWindowInfo(
                        hwnd,
                        WindowsApi.GetWindowTitle(hwnd),
                        processId,
                        handleEntry.ProfileName,
                        handleEntry.ShaderIndex,
                        source
                    );
                }
                else
                {
                    // Window gone - remove stale entry
                    _launchRegistry.Remove(handleKey);
                    _recoveredKeys.Remove(handleKey);
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
                        // Distinguish fresh vs recovered for confidence scoring
                        var source = _recoveredKeys.Contains(pidKey)
                            ? IdentitySource.LaunchTrackingRecovered
                            : IdentitySource.LaunchTracking;

                        return CreateWindowInfo(
                            hwnd,
                            WindowsApi.GetWindowTitle(hwnd),
                            processId,
                            pidEntry.ProfileName,
                            pidEntry.ShaderIndex,
                            source
                        );
                    }
                }
                catch
                {
                    // Process gone - remove stale entry
                    _launchRegistry.Remove(pidKey);
                    _recoveredKeys.Remove(pidKey);
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

    /// <summary>
    /// Batch query command lines for multiple processes in single WMI call.
    /// O(1) instead of O(n) for multiple processes.
    /// </summary>
    private static Dictionary<int, string> BatchQueryCommandLines(IEnumerable<int> processIds)
    {
        var results = new Dictionary<int, string>();
        var pidList = processIds.ToList();
        if (pidList.Count == 0) return results;

        try
        {
            // Build WMI query: SELECT ProcessId, CommandLine FROM Win32_Process WHERE ProcessId=1 OR ProcessId=2...
            var pidFilter = string.Join(" OR ", pidList.Select(p => $"ProcessId={p}"));
            var query = $"SELECT ProcessId, CommandLine FROM Win32_Process WHERE ({pidFilter})";

            using var searcher = new ManagementObjectSearcher(query);
            foreach (ManagementObject obj in searcher.Get())
            {
                var pid = Convert.ToInt32(obj["ProcessId"]);
                var cmdLine = obj["CommandLine"]?.ToString();
                if (!string.IsNullOrEmpty(cmdLine))
                {
                    results[pid] = cmdLine;
                }
            }
        }
        catch
        {
            // WMI query failed - return empty results
        }

        return results;
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

    #region Layer 4: UI Automation

    /// <summary>
    /// Layer 4: UI Automation identity resolution (100-300ms).
    /// Checks TermControl first (0.95), then TabItem (0.85), then Name (0.90).
    /// </summary>
    private WindowInfo? GetUIAutomationIdentity(nint hwnd, int processId, string title)
    {
        try
        {
            var element = AutomationElement.FromHandle(hwnd);
            if (element == null) return null;

            // Priority 1: TermControl has profile name in Name property (confidence 0.95)
            var classCondition = new PropertyCondition(
                AutomationElement.ClassNameProperty, "TermControl");
            var termControls = element.FindAll(TreeScope.Descendants, classCondition);

            foreach (AutomationElement tc in termControls)
            {
                var name = tc.Current.Name;
                if (TryParseMatrixProfile(name, out var shaderIndex))
                {
                    return CreateWindowInfo(hwnd, title, processId,
                        $"Matrix-{shaderIndex}", shaderIndex,
                        IdentitySource.UIAutomationTermControl);
                }
            }

            // Priority 2: TabItem fallback (confidence 0.85)
            var tabCondition = new PropertyCondition(
                AutomationElement.ControlTypeProperty, ControlType.TabItem);
            var tabs = element.FindAll(TreeScope.Descendants, tabCondition);

            foreach (AutomationElement tab in tabs)
            {
                var name = tab.Current.Name;
                if (TryParseMatrixProfile(name, out var shaderIndex))
                {
                    return CreateWindowInfo(hwnd, title, processId,
                        $"Matrix-{shaderIndex}", shaderIndex,
                        IdentitySource.UIAutomationTab);
                }
            }

            // Priority 3: Window Name fallback (confidence 0.90)
            var windowName = element.Current.Name;
            if (TryParseMatrixProfile(windowName, out var idx))
            {
                return CreateWindowInfo(hwnd, title, processId,
                    $"Matrix-{idx}", idx,
                    IdentitySource.UIAutomationName);
            }
        }
        catch
        {
            // UI Automation failed - return null
        }

        return null;
    }

    /// <summary>
    /// Try to parse Matrix-N pattern from text.
    /// </summary>
    private static bool TryParseMatrixProfile(string? text, out int shaderIndex)
    {
        shaderIndex = 0;
        if (string.IsNullOrEmpty(text)) return false;

        var match = MatrixProfileRegex.Match(text);
        if (match.Success)
        {
            shaderIndex = int.Parse(match.Groups[1].Value);
            return true;
        }
        return false;
    }

    #endregion

    #region Batch Resolution

    /// <summary>
    /// Resolve identity with pre-cached command lines for batch performance.
    /// </summary>
    private WindowInfo? ResolveIdentityWithCache(nint hwnd, string title, int processId,
        Dictionary<int, string> commandLineCache)
    {
        if (!WindowsApi.IsHandleValid(hwnd))
            return null;

        // Check if this is the control panel window
        if (title.Contains(ControlPanelTitle, StringComparison.OrdinalIgnoreCase))
        {
            return CreateWindowInfo(hwnd, title, processId, "ControlPanel", 0, IdentitySource.Title);
        }

        // Layer 1: Launch Tracking
        var launchIdentity = GetLaunchRegistryIdentity(hwnd, processId);
        if (launchIdentity != null)
            return launchIdentity;

        // Layer 2: Command Line (from cache)
        if (commandLineCache.TryGetValue(processId, out var cmdLine))
        {
            var cmdIdentity = ParseCommandLineIdentity(hwnd, processId, title, cmdLine);
            if (cmdIdentity != null)
                return cmdIdentity;
        }

        // Layer 3: Title Pattern Matching
        var titleIdentity = GetTitleIdentity(hwnd, processId, title);
        if (titleIdentity != null)
            return titleIdentity;

        // Layer 4: UI Automation (slow fallback)
        var uiaIdentity = GetUIAutomationIdentity(hwnd, processId, title);
        return uiaIdentity;
    }

    /// <summary>
    /// Parse command line to extract identity (used with cache).
    /// </summary>
    private WindowInfo? ParseCommandLineIdentity(nint hwnd, int processId, string title, string commandLine)
    {
        var profileMatch = Regex.Match(commandLine, @"-p\s+[""']?([^""'\s]+)[""']?", RegexOptions.IgnoreCase);
        if (!profileMatch.Success)
        {
            profileMatch = Regex.Match(commandLine, @"--profile\s+[""']?([^""'\s]+)[""']?", RegexOptions.IgnoreCase);
        }

        if (profileMatch.Success)
        {
            var profileArg = profileMatch.Groups[1].Value;
            if (TryParseMatrixProfile(profileArg, out var shaderIndex))
            {
                return CreateWindowInfo(hwnd, title, processId, $"Matrix-{shaderIndex}", shaderIndex, IdentitySource.CommandLine);
            }
        }
        return null;
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Gets all Windows Terminal windows (includes minimized).
    /// Context decision: Include minimized windows for Matrix window tracking.
    /// </summary>
    private List<(nint hwnd, string title, int processId)> GetTerminalWindows()
    {
        var results = new List<(nint, string, int)>();
        var allWindows = WindowsApi.GetAllWindows();  // Includes minimized

        foreach (var hwnd in allWindows)
        {
            try
            {
                var processId = WindowsApi.GetWindowProcessId(hwnd);
                using var process = Process.GetProcessById(processId);

                if (process.ProcessName.Equals(WindowsTerminalProcessName, StringComparison.OrdinalIgnoreCase))
                {
                    var title = WindowsApi.GetWindowTitle(hwnd);
                    results.Add((hwnd, title, processId));
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
    /// Confidence is automatically set based on the identity source.
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
            Confidence = source.GetConfidence(),
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
