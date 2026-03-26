using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Models;
using MatrixShader.Core.Serialization;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for reading and writing Windows Terminal settings.json.
/// Implements three-layer error recovery and atomic writes.
/// </summary>
public class TerminalSettingsService : ITerminalSettingsService
{
    private readonly ILogger<TerminalSettingsService> _logger;

    public TerminalSettingsService(ILogger<TerminalSettingsService> logger, string? settingsPath = null)
    {
        _logger = logger;
        // Use dynamic settings path resolution (supports Store, Winget, Scoop, Chocolatey)
        SettingsPath = settingsPath ?? CliBootstrap.GetSettingsPath();
        BackupPath = SettingsPath + ".matrix-backup";

        DiagnosticLogger.Debug("TERMINAL", $"Using settings path: {SettingsPath}");
    }

    public string SettingsPath { get; }
    public string BackupPath { get; }
    public string OriginalBackupPath => SettingsPath + ".matrix-original";
    public bool SettingsExist => File.Exists(SettingsPath);

    public TerminalSettings LoadSettings()
    {
        if (!SettingsExist)
        {
            _logger.LogWarning("Windows Terminal settings not found at {Path}", SettingsPath);
            return CreateDefaultSettings();
        }

        string content;
        try
        {
            content = File.ReadAllText(SettingsPath);
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "Cannot read settings.json (file may be locked)");
            throw; // File locked - cannot recover, caller must handle
        }

        // Layer 1: Try normal JSON parse
        try
        {
            var settings = JsonSerializer.Deserialize(content, MatrixJsonContext.Default.TerminalSettings);
            if (settings != null)
            {
                _logger.LogDebug("Successfully loaded settings from {Path}", SettingsPath);
                return settings;
            }
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Settings.json is malformed, attempting recovery");
        }

        // Layer 2: Backup and attempt lenient recovery
        var backupPath = BackupPath;
        CreateBackup();
        try
        {
            var recoveredSettings = RecoverSettings(content);
            if (recoveredSettings != null)
            {
                _logger.LogWarning("Settings recovery will preserve only profile data. Original backed up to {Path}", backupPath);
                SaveSettings(recoveredSettings);
                return recoveredSettings;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Recovery failed, creating fresh settings");
        }

        // Layer 3: Create fresh default settings
        var defaultSettings = CreateDefaultSettings();
        SaveSettings(defaultSettings);
        return defaultSettings;
    }

    public void SaveSettings(TerminalSettings settings)
    {
        var tempPath = SettingsPath + ".tmp";
        try
        {
            // Ensure directory exists
            var dir = Path.GetDirectoryName(SettingsPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            // Serialize using AOT-compatible source-generated context
            // Note: MatrixJsonContext already has WriteIndented = true in options
            var json = JsonSerializer.Serialize(settings, MatrixJsonContext.Default.TerminalSettings);

            // Atomic write: temp file + move
            File.WriteAllText(tempPath, json, new UTF8Encoding(false));
            File.Move(tempPath, SettingsPath, overwrite: true);

            _logger.LogDebug("Saved settings to {Path}", SettingsPath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save settings");

            // Clean up temp file
            try
            {
                if (File.Exists(tempPath))
                    File.Delete(tempPath);
            }
            catch { /* Ignore cleanup errors */ }

            throw;
        }
    }

    public bool CreateBackup()
    {
        if (!SettingsExist)
            return false;

        try
        {
            File.Copy(SettingsPath, BackupPath, overwrite: true);
            _logger.LogDebug("Created backup at {Path}", BackupPath);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not create backup");
            return false;
        }
    }

    /// <summary>
    /// Creates a one-time backup of the original settings before any Matrix modifications.
    /// Only creates if it doesn't exist, preserving the FIRST original state.
    /// </summary>
    public bool CreateOriginalBackup()
    {
        // Only create if it doesn't exist (preserve FIRST original state)
        if (File.Exists(OriginalBackupPath))
        {
            DiagnosticLogger.Debug("TERMINAL", "Original backup already exists, preserving");
            return true;
        }
        if (!SettingsExist) return false;
        try
        {
            File.Copy(SettingsPath, OriginalBackupPath);
            DiagnosticLogger.Info("TERMINAL", $"Created original backup: {OriginalBackupPath}");
            return true;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("TERMINAL", $"Failed to create original backup: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Restores the original settings from the .matrix-original backup.
    /// Used during uninstall to fully clean up Matrix modifications.
    /// </summary>
    public bool RestoreOriginalSettings()
    {
        if (!File.Exists(OriginalBackupPath))
        {
            DiagnosticLogger.Warn("TERMINAL", "No original backup to restore");
            return false;
        }
        try
        {
            File.Copy(OriginalBackupPath, SettingsPath, overwrite: true);
            DiagnosticLogger.Info("TERMINAL", "Restored original settings");
            return true;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("TERMINAL", $"Failed to restore: {ex.Message}");
            return false;
        }
    }

    public TerminalProfile? GetProfile(TerminalSettings settings, string profileName)
    {
        return settings.Profiles?.List?.FirstOrDefault(p =>
            string.Equals(p.Name, profileName, StringComparison.OrdinalIgnoreCase));
    }

    public void UpsertProfile(TerminalSettings settings, TerminalProfile profile)
    {
        // Ensure profiles structure exists
        settings.Profiles ??= new ProfilesContainer();
        settings.Profiles.List ??= new List<TerminalProfile>();

        // Find existing profile index
        var existingIndex = settings.Profiles.List.FindIndex(p =>
            string.Equals(p.Name, profile.Name, StringComparison.OrdinalIgnoreCase));

        if (existingIndex >= 0)
        {
            // Update existing
            settings.Profiles.List[existingIndex] = profile;
            _logger.LogDebug("Updated profile {Name}", profile.Name);
        }
        else
        {
            // Insert at beginning (Matrix profiles should be at top)
            settings.Profiles.List.Insert(0, profile);
            _logger.LogDebug("Added profile {Name}", profile.Name);
        }
    }

    public int CreateMatrixProfiles(TerminalSettings settings, int count, string shadersDirectory)
    {
        // Backup original settings before any Matrix modifications
        CreateOriginalBackup();

        if (count < 1 || count > 8)
            throw new ArgumentOutOfRangeException(nameof(count), "Count must be between 1 and 8");

        DiagnosticLogger.Info("TERMINAL", $"Creating profiles with shader path: {shadersDirectory}");

        var created = 0;
        for (int i = 1; i <= count; i++)
        {
            var profileName = $"Matrix-{i}";
            var existing = GetProfile(settings, profileName);

            // NOTE: Opacity is set per-profile, not on profiles.defaults.
            // This ensures only Matrix windows get transparency.
            // Per user requirement: non-Matrix windows stay 100% opaque.
            // UseAcrylic = false gives PLAIN transparency (no blur/haze) on Windows 11.
            var preset = ColorPresets.GetByKey(i);
            string? tabColor = null;
            if (preset != null)
            {
                var (pr, pg, pb) = preset.Value.ToRgb();
                tabColor = $"#{pr:X2}{pg:X2}{pb:X2}";
            }

            var profile = new TerminalProfile
            {
                Name = profileName,
                Guid = existing?.Guid ?? $"{{{Guid.NewGuid()}}}",
                Commandline = $"powershell.exe -NoExit -Command \"$host.UI.RawUI.WindowTitle = 'Matrix-{i}'; Write-Host ' Matrix Terminal {i}' -ForegroundColor Green\"",
                Hidden = true,
                Opacity = 85,  // 85% opacity for Matrix windows only
                UseAcrylic = false,  // Plain transparency (no blur) - desktop shows clearly
                PixelShaderPath = Path.Combine(shadersDirectory, $"Matrix-{i}.hlsl"),
                TabColor = tabColor,
                Foreground = tabColor,  // Text color matches rain color
                FontFace = "Nimbus Mono PS",
                FontSize = 16,
                FontWeight = "bold",
                SuppressApplicationTitle = false
            };

            UpsertProfile(settings, profile);
            created++;
            _logger.LogDebug("Created profile {Name}", profileName);
        }

        DiagnosticLogger.Info("TERMINAL", $"Created {created} Matrix profiles");
        return created;
    }

    public void CreateRedpillProfile(TerminalSettings settings, string shadersDirectory, string? controlPanelPath = null)
    {
        // Backup original settings before any Matrix modifications
        CreateOriginalBackup();

        const string profileName = "Redpill";

        // Resolve the control panel executable path
        var effectivePath = string.IsNullOrEmpty(controlPanelPath)
            ? GetRedpillExecutablePath()
            : controlPanelPath;

        DiagnosticLogger.Debug("TERMINAL", $"Redpill profile using control panel: {effectivePath}");

        var existing = GetProfile(settings, profileName);

        // NOTE: Opacity is set per-profile, not on profiles.defaults.
        // This ensures only Matrix windows get transparency.
        // UseAcrylic = false gives PLAIN transparency (no blur/haze) on Windows 11.
        var profile = new TerminalProfile
        {
            Name = profileName,
            Guid = existing?.Guid ?? $"{{{Guid.NewGuid()}}}",
            Commandline = $"\"{effectivePath}\"",
            Hidden = true,
            Opacity = 100,  // No transparency for Redpill — city shader is the background
            UseAcrylic = false,
            PixelShaderPath = Path.Combine(shadersDirectory, "MatrixCodeVision.hlsl")
        };

        UpsertProfile(settings, profile);
        DiagnosticLogger.Info("TERMINAL", "Created Redpill control panel profile");
    }

    /// <summary>
    /// Finds the installed redpill.exe executable path.
    /// Priority: Program Files install location, then local directory.
    /// </summary>
    private static string GetRedpillExecutablePath()
    {
        // Try Program Files first (admin install location)
        var programFilesPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "MatrixShader", "redpill.exe");

        if (File.Exists(programFilesPath))
        {
            DiagnosticLogger.Debug("TERMINAL", $"Found redpill at installed location: {programFilesPath}");
            return programFilesPath;
        }

        // Try LocalAppData\Programs (non-admin CLI install location)
        var localAppDataPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs", "MatrixShader", "redpill.exe");

        if (File.Exists(localAppDataPath))
        {
            DiagnosticLogger.Debug("TERMINAL", $"Found redpill at user install location: {localAppDataPath}");
            return localAppDataPath;
        }

        // Fallback to same directory as current executable
        var localPath = Path.Combine(AppContext.BaseDirectory, "redpill.exe");
        if (File.Exists(localPath))
        {
            DiagnosticLogger.Debug("TERMINAL", $"Found redpill at local location: {localPath}");
            return localPath;
        }

        // Return the expected installed path even if not found (will error clearly at runtime)
        DiagnosticLogger.Warn("TERMINAL", $"redpill.exe not found, using expected path: {programFilesPath}");
        return programFilesPath;
    }

    public int UpdateShaderPaths(TerminalSettings settings, string currentShadersDirectory)
    {
        if (settings.Profiles?.List == null)
            return 0;

        var updated = 0;
        for (int i = 0; i < settings.Profiles.List.Count; i++)
        {
            var profile = settings.Profiles.List[i];

            // Check if this is a Matrix or Redpill profile
            if (!IsMatrixProfile(profile.Name))
                continue;

            var shaderPath = profile.PixelShaderPath;
            if (string.IsNullOrEmpty(shaderPath))
                continue;

            // Check if path needs updating
            var shaderDir = Path.GetDirectoryName(shaderPath);
            if (string.Equals(shaderDir, currentShadersDirectory, StringComparison.OrdinalIgnoreCase))
                continue;

            // Update path
            var filename = Path.GetFileName(shaderPath);
            var newPath = Path.Combine(currentShadersDirectory, filename);

            // Create new profile with updated path
            settings.Profiles.List[i] = profile with { PixelShaderPath = newPath };
            updated++;

            DiagnosticLogger.Debug("TERMINAL", $"Updated shader path for {profile.Name}: {newPath}");
        }

        if (updated > 0)
        {
            DiagnosticLogger.Info("TERMINAL", $"Updated {updated} shader paths to {currentShadersDirectory}");
        }

        return updated;
    }

    public int GetMatrixProfileCount(TerminalSettings settings)
    {
        if (settings.Profiles?.List == null)
            return 0;

        return settings.Profiles.List.Count(p => IsMatrixProfile(p.Name));
    }

    public bool HasMatrixProfiles(TerminalSettings settings)
    {
        return GetMatrixProfileCount(settings) > 0;
    }

    /// <inheritdoc/>
    public void ForceShaderReload()
    {
        try
        {
            if (!SettingsExist) return;

            var json = File.ReadAllText(SettingsPath);

            string modified;
            // Toggle path between "shaders\\X" and "shaders\\.\\X"
            // Both resolve to the same file on disk, but WT sees different strings → triggers reload.
            // Single atomic write — no delay, no passthrough shader, no freeze in other windows.
            if (json.Contains("shaders\\\\.\\\\"))
            {
                // Currently has dot segment → remove it (restore clean paths)
                modified = json.Replace("shaders\\\\.\\\\", "shaders\\\\");
            }
            else
            {
                // Currently clean → add dot segment to all shader paths
                modified = json.Replace("shaders\\\\Matrix-", "shaders\\\\.\\\\Matrix-")
                              .Replace("shaders\\\\Redpill-", "shaders\\\\.\\\\Redpill-")
                              .Replace("shaders\\\\passthrough", "shaders\\\\.\\\\passthrough");
            }

            if (modified == json)
            {
                DiagnosticLogger.Debug("TERMINAL", "ForceShaderReload: no shader paths found to toggle");
                return;
            }

            File.WriteAllText(SettingsPath, modified, new System.Text.UTF8Encoding(false));
            DiagnosticLogger.Debug("TERMINAL", "Forced shader reload via path toggle");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("TERMINAL", $"ForceShaderReload failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Surgically upserts a single profile in settings.json using JsonNode.
    /// This preserves ALL other content: formatting, comments, unknown properties,
    /// property ordering, and non-Matrix profiles are completely untouched.
    ///
    /// This avoids the destructive full-deserialization approach where:
    /// - Non-Matrix profiles get extra properties injected (opacity, useAcrylic, etc.)
    /// - The "source" property is stripped from generated profiles (WSL, Azure, VS)
    /// - Property ordering and indentation are changed
    /// - Special characters get Unicode-escaped (e.g. ctrl+c → ctrl\u002Bc)
    /// </summary>
    public void UpsertProfileSurgical(TerminalProfile profile)
    {
        // Named mutex serializes settings.json writes across concurrent construct.exe processes.
        // Without this, rapid launches (construct --green & --red & --blue) create a TOCTOU race:
        // Process A reads, Process B reads (same content), A writes (adds Matrix-1),
        // B writes (adds Matrix-3 but overwrites A's file, losing Matrix-1) → WT closes A's window.
        using var mutex = new Mutex(false, @"Global\MatrixShader_SettingsWrite");
        try { mutex.WaitOne(TimeSpan.FromSeconds(10)); }
        catch (AbandonedMutexException) { /* Safe to proceed */ }

        try
        {
            UpsertProfileSurgicalCore(profile);
        }
        finally
        {
            mutex.ReleaseMutex();
        }
    }

    private void UpsertProfileSurgicalCore(TerminalProfile profile)
    {
        if (!SettingsExist)
        {
            var settings = CreateDefaultSettings();
            UpsertProfile(settings, profile);
            SaveSettings(settings);
            return;
        }

        var json = File.ReadAllText(SettingsPath);
        var profileObj = BuildProfileJsonObject(profile);

        // PRIMARY: Text-based splice — preserves comments, formatting, other profiles byte-for-byte.
        // Only the target profile's JSON object is replaced; everything else is untouched.
        // This prevents the "tab kill" bug where full re-serialization strips JSONC comments
        // and reformats indentation, causing WT to see a massive diff and reload aggressively.
        if (TrySpliceProfileText(json, profile.Name, profileObj, out var modified))
        {
            var tempPath = SettingsPath + ".tmp";
            File.WriteAllText(tempPath, modified, new UTF8Encoding(false));
            File.Move(tempPath, SettingsPath, overwrite: true);
            DiagnosticLogger.Debug("TERMINAL", $"Text splice complete for {profile.Name}");
            return;
        }

        // FALLBACK: Full JsonNode re-serialization (strips comments, reformats, but always works)
        _logger.LogDebug("Text splice failed for {Name}, falling back to JsonNode", profile.Name);
        var root = JsonNode.Parse(json, documentOptions: new JsonDocumentOptions
        {
            CommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true
        });
        if (root == null)
        {
            var settings = LoadSettings();
            UpsertProfile(settings, profile);
            SaveSettings(settings);
            return;
        }

        var profiles = root["profiles"] as JsonObject;
        if (profiles == null)
        {
            profiles = new JsonObject { ["list"] = new JsonArray(), ["defaults"] = new JsonObject() };
            root["profiles"] = profiles;
        }
        var list = profiles["list"] as JsonArray;
        if (list == null)
        {
            list = new JsonArray();
            profiles["list"] = list;
        }

        int existingIndex = -1;
        for (int i = 0; i < list!.Count; i++)
        {
            var name = list[i]?["name"]?.GetValue<string>();
            if (string.Equals(name, profile.Name, StringComparison.OrdinalIgnoreCase))
            {
                existingIndex = i;
                break;
            }
        }

        if (existingIndex >= 0)
            list[existingIndex] = profileObj;
        else
            list.Insert(0, profileObj);

        WriteSurgicalResult(root!);
        DiagnosticLogger.Debug("TERMINAL", $"JsonNode upsert complete for {profile.Name}");
    }

    /// <summary>
    /// Text-based profile splice: finds the target profile's { } object in the raw JSON text
    /// and replaces it in-place. Everything else (comments, formatting, other profiles) is
    /// preserved byte-for-byte. If the profile doesn't exist, inserts at the start of the list.
    /// Returns false only if the JSON structure can't be parsed (malformed file).
    /// </summary>
    private static bool TrySpliceProfileText(string json, string profileName, JsonObject newProfile, out string result)
    {
        result = json;

        // Detect file's indentation by finding the first indented line
        int indentSize = 4; // WT default
        foreach (var line in json.Split('\n'))
        {
            int s = 0;
            while (s < line.Length && line[s] == ' ') s++;
            if (s >= 2 && s <= 8) { indentSize = s; break; }
        }

        // Build the replacement profile JSON with matching indentation
        // Profiles in WT's settings.json are at indent level 3: root > profiles > list > [item]
        var baseIndent = new string(' ', indentSize * 3);
        var innerIndent = new string(' ', indentSize * 4);
        var newProfileStr = FormatProfileObject(newProfile, baseIndent, innerIndent);

        // Try to find and replace an existing profile
        var range = FindProfileObjectRange(json, profileName);
        if (range.HasValue)
        {
            var (start, end) = range.Value;
            result = json.Substring(0, start) + newProfileStr + json.Substring(end + 1);
            return true;
        }

        // Profile doesn't exist — insert at start of "list" array
        int listBracket = FindListArrayBracket(json);
        if (listBracket < 0) return false;

        int insertPos = listBracket + 1;
        // Check if list is empty (only whitespace/] after [)
        int peek = insertPos;
        while (peek < json.Length && char.IsWhiteSpace(json[peek])) peek++;
        bool emptyList = peek < json.Length && json[peek] == ']';

        if (emptyList)
        {
            result = json.Substring(0, insertPos)
                + "\n" + newProfileStr + "\n" + new string(' ', indentSize * 2)
                + json.Substring(peek);
        }
        else
        {
            result = json.Substring(0, insertPos)
                + "\n" + newProfileStr + ","
                + json.Substring(insertPos);
        }
        return true;
    }

    /// <summary>
    /// Finds the byte range (start, end inclusive) of a profile object by name in the JSON text.
    /// Walks the "list" array tracking brace depth to find each object's boundaries,
    /// then checks if the object contains the target "name" key-value pair.
    /// </summary>
    private static (int start, int end)? FindProfileObjectRange(string json, string profileName)
    {
        int listStart = FindListArrayBracket(json);
        if (listStart < 0) return null;

        int pos = listStart + 1;
        while (pos < json.Length)
        {
            while (pos < json.Length && (char.IsWhiteSpace(json[pos]) || json[pos] == ',')) pos++;
            if (pos >= json.Length || json[pos] == ']') break;
            if (json[pos] != '{') break;

            int objStart = pos;
            int objEnd = FindMatchingBrace(json, pos);
            if (objEnd < 0) break;

            // Check if this object contains "name": "profileName"
            var segment = json.AsSpan(objStart, objEnd - objStart + 1);
            var namePattern = $"\"name\"\\s*:\\s*\"{Regex.Escape(profileName)}\"";
            if (Regex.IsMatch(segment.ToString(), namePattern, RegexOptions.IgnoreCase))
            {
                return (objStart, objEnd);
            }

            pos = objEnd + 1;
        }
        return null;
    }

    /// <summary>
    /// Finds the position of the '[' bracket for the profiles.list array.
    /// </summary>
    private static int FindListArrayBracket(string json)
    {
        // Find "profiles" section first, then "list" within it
        var profilesMatch = Regex.Match(json, @"""profiles""\s*:\s*\{");
        if (!profilesMatch.Success) return -1;

        var listMatch = Regex.Match(json, @"""list""\s*:\s*\[", RegexOptions.None, TimeSpan.FromSeconds(1));
        if (!listMatch.Success || listMatch.Index < profilesMatch.Index) return -1;

        return listMatch.Index + listMatch.Length - 1; // Position of '['
    }

    /// <summary>
    /// Finds the matching '}' for a '{' at the given position, correctly handling
    /// nested braces and JSON string escaping (won't be fooled by braces inside strings).
    /// </summary>
    private static int FindMatchingBrace(string json, int openPos)
    {
        int depth = 0;
        bool inStr = false;
        bool escaped = false;

        for (int i = openPos; i < json.Length; i++)
        {
            char c = json[i];
            if (escaped) { escaped = false; continue; }
            if (c == '\\' && inStr) { escaped = true; continue; }
            if (c == '"') inStr = !inStr;
            if (!inStr)
            {
                if (c == '{') depth++;
                else if (c == '}')
                {
                    depth--;
                    if (depth == 0) return i;
                }
            }
        }
        return -1;
    }

    /// <summary>
    /// Serializes a profile JsonObject with specific indentation to match the file's style.
    /// </summary>
    private static string FormatProfileObject(JsonObject profile, string baseIndent, string innerIndent)
    {
        var sb = new StringBuilder();
        sb.Append(baseIndent).Append('{').Append('\n');

        var entries = new List<string>();
        foreach (var kv in profile)
        {
            var valueStr = kv.Value?.ToJsonString() ?? "null";
            entries.Add($"{innerIndent}\"{kv.Key}\": {valueStr}");
        }
        sb.Append(string.Join(",\n", entries));
        sb.Append('\n').Append(baseIndent).Append('}');

        return sb.ToString();
    }

    /// <summary>
    /// Surgically upserts multiple profiles in a single settings.json write.
    /// More efficient than calling UpsertProfileSurgical multiple times.
    /// </summary>
    public void UpsertProfilesSurgical(IEnumerable<TerminalProfile> profilesToUpsert)
    {
        if (!SettingsExist)
        {
            var settings = CreateDefaultSettings();
            foreach (var p in profilesToUpsert)
                UpsertProfile(settings, p);
            SaveSettings(settings);
            return;
        }

        var json = File.ReadAllText(SettingsPath);
        var root = JsonNode.Parse(json, documentOptions: new JsonDocumentOptions
        {
            CommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true
        });
        if (root == null)
        {
            var settings = LoadSettings();
            foreach (var p in profilesToUpsert)
                UpsertProfile(settings, p);
            SaveSettings(settings);
            return;
        }

        var profiles = root["profiles"] as JsonObject;
        if (profiles == null)
        {
            profiles = new JsonObject { ["list"] = new JsonArray(), ["defaults"] = new JsonObject() };
            root["profiles"] = profiles;
        }
        var list = profiles["list"] as JsonArray;
        if (list == null)
        {
            list = new JsonArray();
            profiles["list"] = list;
        }

        foreach (var profile in profilesToUpsert)
        {
            var profileObj = BuildProfileJsonObject(profile);

            int existingIndex = -1;
            for (int i = 0; i < list.Count; i++)
            {
                var name = list[i]?["name"]?.GetValue<string>();
                if (string.Equals(name, profile.Name, StringComparison.OrdinalIgnoreCase))
                {
                    existingIndex = i;
                    break;
                }
            }

            if (existingIndex >= 0)
                list[existingIndex] = profileObj;
            else
                list.Insert(0, profileObj);
        }

        WriteSurgicalResult(root);
    }

    /// <summary>
    /// Surgically removes a profile by name from settings.json using text splice.
    /// Finds the profile object by name, removes it and its trailing/leading comma,
    /// preserving all other content byte-for-byte. Uses the same mutex as
    /// UpsertProfileSurgical to prevent concurrent write races.
    /// </summary>
    public void RemoveProfileSurgical(string profileName)
    {
        using var mutex = new Mutex(false, @"Global\MatrixShader_SettingsWrite");
        try { mutex.WaitOne(TimeSpan.FromSeconds(10)); }
        catch (AbandonedMutexException) { /* Safe to proceed */ }

        try
        {
            if (!SettingsExist) return;

            var json = File.ReadAllText(SettingsPath);
            var range = FindProfileObjectRange(json, profileName);
            if (!range.HasValue)
            {
                DiagnosticLogger.Debug("TERMINAL", $"RemoveProfileSurgical: profile '{profileName}' not found, nothing to remove");
                return;
            }

            var (start, end) = range.Value;

            // Expand removal range to include trailing comma+whitespace, or leading comma+whitespace
            int removeStart = start;
            int removeEnd = end;

            // Try to consume trailing comma and whitespace first
            int afterObj = end + 1;
            while (afterObj < json.Length && char.IsWhiteSpace(json[afterObj])) afterObj++;
            if (afterObj < json.Length && json[afterObj] == ',')
            {
                removeEnd = afterObj; // include the trailing comma
            }
            else
            {
                // No trailing comma — consume leading comma and whitespace instead
                int beforeObj = start - 1;
                while (beforeObj >= 0 && char.IsWhiteSpace(json[beforeObj])) beforeObj--;
                if (beforeObj >= 0 && json[beforeObj] == ',')
                {
                    removeStart = beforeObj; // include the leading comma
                }
            }

            // Also consume whitespace (newlines) around the removed section
            while (removeEnd + 1 < json.Length && (json[removeEnd + 1] == '\r' || json[removeEnd + 1] == '\n'))
                removeEnd++;

            var modified = json.Substring(0, removeStart) + json.Substring(removeEnd + 1);

            var tempPath = SettingsPath + ".tmp";
            File.WriteAllText(tempPath, modified, new UTF8Encoding(false));
            File.Move(tempPath, SettingsPath, overwrite: true);
            DiagnosticLogger.Info("TERMINAL", $"Removed profile '{profileName}' from settings.json");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("TERMINAL", $"RemoveProfileSurgical failed for '{profileName}': {ex.Message}");
        }
        finally
        {
            mutex.ReleaseMutex();
        }
    }

    /// <summary>
    /// Atomically replaces one profile with another in a single settings.json write.
    /// Removes the old profile (by name) and upserts the new profile in one file write.
    /// This prevents the duplicate-GUID popup that occurs when WT's file watcher detects
    /// an intermediate state where two profiles share the same GUID (e.g., during
    /// Construct → Matrix transition where the GUID is swapped between profiles).
    /// </summary>
    public void ReplaceProfileSurgical(string oldProfileName, TerminalProfile newProfile)
    {
        using var mutex = new Mutex(false, @"Global\MatrixShader_SettingsWrite");
        try { mutex.WaitOne(TimeSpan.FromSeconds(10)); }
        catch (AbandonedMutexException) { /* Safe to proceed */ }

        try
        {
            if (!SettingsExist) return;

            var json = File.ReadAllText(SettingsPath);

            // Step 1: Remove the old profile from the text
            var oldRange = FindProfileObjectRange(json, oldProfileName);
            if (oldRange.HasValue)
            {
                var (start, end) = oldRange.Value;

                // Expand removal range to include trailing or leading comma
                int removeStart = start;
                int removeEnd = end;

                int afterObj = end + 1;
                while (afterObj < json.Length && char.IsWhiteSpace(json[afterObj])) afterObj++;
                if (afterObj < json.Length && json[afterObj] == ',')
                {
                    removeEnd = afterObj;
                }
                else
                {
                    int beforeObj = start - 1;
                    while (beforeObj >= 0 && char.IsWhiteSpace(json[beforeObj])) beforeObj--;
                    if (beforeObj >= 0 && json[beforeObj] == ',')
                    {
                        removeStart = beforeObj;
                    }
                }

                // Consume surrounding newlines
                while (removeEnd + 1 < json.Length && (json[removeEnd + 1] == '\r' || json[removeEnd + 1] == '\n'))
                    removeEnd++;

                json = json.Substring(0, removeStart) + json.Substring(removeEnd + 1);
                DiagnosticLogger.Debug("TERMINAL", $"ReplaceProfileSurgical: removed old profile '{oldProfileName}'");
            }

            // Step 2: Upsert the new profile into the (now modified) text
            var profileObj = BuildProfileJsonObject(newProfile);

            if (TrySpliceProfileText(json, newProfile.Name, profileObj, out var modified))
            {
                var tempPath = SettingsPath + ".tmp";
                File.WriteAllText(tempPath, modified, new UTF8Encoding(false));
                File.Move(tempPath, SettingsPath, overwrite: true);
                DiagnosticLogger.Info("TERMINAL", $"ReplaceProfileSurgical: atomic swap '{oldProfileName}' → '{newProfile.Name}'");
                return;
            }

            // Fallback to JsonNode
            var root = JsonNode.Parse(json, documentOptions: new JsonDocumentOptions
            {
                CommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true
            });
            if (root == null) return;

            var list = root["profiles"]?["list"]?.AsArray();
            if (list == null) return;

            int existingIndex = -1;
            for (int i = 0; i < list.Count; i++)
            {
                var name = list[i]?["name"]?.GetValue<string>();
                if (string.Equals(name, newProfile.Name, StringComparison.OrdinalIgnoreCase))
                {
                    existingIndex = i;
                    break;
                }
            }

            if (existingIndex >= 0)
                list[existingIndex] = profileObj;
            else
                list.Insert(0, profileObj);

            WriteSurgicalResult(root);
            DiagnosticLogger.Info("TERMINAL", $"ReplaceProfileSurgical (JsonNode fallback): '{oldProfileName}' → '{newProfile.Name}'");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("TERMINAL", $"ReplaceProfileSurgical failed: {ex.Message}");
        }
        finally
        {
            mutex.ReleaseMutex();
        }
    }

    /// <summary>
    /// Removes all profiles whose names start with the given prefix.
    /// Used to clean up stale Construct-{id} profiles from previous sessions
    /// that were not properly removed (e.g., user pressed Escape, process crashed).
    /// </summary>
    public void RemoveProfilesByPrefixSurgical(string namePrefix)
    {
        using var mutex = new Mutex(false, @"Global\MatrixShader_SettingsWrite");
        try { mutex.WaitOne(TimeSpan.FromSeconds(10)); }
        catch (AbandonedMutexException) { /* Safe to proceed */ }

        try
        {
            if (!SettingsExist) return;

            var json = File.ReadAllText(SettingsPath);

            // Find all profile names matching the prefix
            var profilesToRemove = new List<string>();
            var namePattern = new Regex($@"""name""\s*:\s*""({Regex.Escape(namePrefix)}[^""]*?)""");
            foreach (Match m in namePattern.Matches(json))
            {
                profilesToRemove.Add(m.Groups[1].Value);
            }

            if (profilesToRemove.Count == 0) return;

            // Remove each one from the text (re-find range each time since offsets shift)
            foreach (var profileName in profilesToRemove)
            {
                var range = FindProfileObjectRange(json, profileName);
                if (!range.HasValue) continue;

                var (start, end) = range.Value;
                int removeStart = start;
                int removeEnd = end;

                int afterObj = end + 1;
                while (afterObj < json.Length && char.IsWhiteSpace(json[afterObj])) afterObj++;
                if (afterObj < json.Length && json[afterObj] == ',')
                {
                    removeEnd = afterObj;
                }
                else
                {
                    int beforeObj = start - 1;
                    while (beforeObj >= 0 && char.IsWhiteSpace(json[beforeObj])) beforeObj--;
                    if (beforeObj >= 0 && json[beforeObj] == ',')
                    {
                        removeStart = beforeObj;
                    }
                }

                while (removeEnd + 1 < json.Length && (json[removeEnd + 1] == '\r' || json[removeEnd + 1] == '\n'))
                    removeEnd++;

                json = json.Substring(0, removeStart) + json.Substring(removeEnd + 1);
                DiagnosticLogger.Debug("TERMINAL", $"RemoveProfilesByPrefix: removed '{profileName}'");
            }

            var tempPath = SettingsPath + ".tmp";
            File.WriteAllText(tempPath, json, new UTF8Encoding(false));
            File.Move(tempPath, SettingsPath, overwrite: true);
            DiagnosticLogger.Info("TERMINAL", $"RemoveProfilesByPrefix: cleaned up {profilesToRemove.Count} profiles with prefix '{namePrefix}'");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("TERMINAL", $"RemoveProfilesByPrefix failed: {ex.Message}");
        }
        finally
        {
            mutex.ReleaseMutex();
        }
    }

    /// <summary>
    /// Gets the GUID of an existing profile by name, reading directly from JSON.
    /// Returns null if the profile doesn't exist.
    /// </summary>
    public string? GetProfileGuid(string profileName)
    {
        if (!SettingsExist) return null;
        try
        {
            var json = File.ReadAllText(SettingsPath);
            var root = JsonNode.Parse(json, documentOptions: new JsonDocumentOptions
            {
                CommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true
            });
            var list = root?["profiles"]?["list"]?.AsArray();
            if (list == null) return null;
            for (int i = 0; i < list.Count; i++)
            {
                var name = list[i]?["name"]?.GetValue<string>();
                if (string.Equals(name, profileName, StringComparison.OrdinalIgnoreCase))
                    return list[i]?["guid"]?.GetValue<string>();
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("TERMINAL", $"GetProfileGuid failed: {ex.Message}");
        }
        return null;
    }

    /// <summary>
    /// Builds a JsonObject from a TerminalProfile, only including non-null optional properties.
    /// </summary>
    private static JsonObject BuildProfileJsonObject(TerminalProfile profile)
    {
        var obj = new JsonObject
        {
            ["name"] = profile.Name,
            ["guid"] = profile.Guid,
        };
        if (profile.Commandline != null) obj["commandline"] = profile.Commandline;
        obj["hidden"] = profile.Hidden;
        obj["opacity"] = profile.Opacity;
        obj["useAcrylic"] = profile.UseAcrylic;
        if (profile.PixelShaderPath != null) obj["experimental.pixelShaderPath"] = profile.PixelShaderPath;
        if (profile.TabColor != null) obj["tabColor"] = profile.TabColor;
        if (profile.BackgroundImage != null) obj["backgroundImage"] = profile.BackgroundImage;
        if (profile.BackgroundImageStretchMode != null) obj["backgroundImageStretchMode"] = profile.BackgroundImageStretchMode;
        if (profile.BackgroundImageAlignment != null) obj["backgroundImageAlignment"] = profile.BackgroundImageAlignment;
        if (profile.BackgroundImageOpacity != null) obj["backgroundImageOpacity"] = profile.BackgroundImageOpacity.Value;
        if (profile.Foreground != null) obj["foreground"] = profile.Foreground;
        if (profile.Background != null) obj["background"] = profile.Background;
        if (profile.Padding != null) obj["padding"] = profile.Padding;
        if (profile.FontFace != null || profile.FontSize != null || profile.FontWeight != null)
        {
            var fontObj = new JsonObject();
            if (profile.FontFace != null) fontObj["face"] = profile.FontFace;
            if (profile.FontSize != null) fontObj["size"] = profile.FontSize.Value;
            if (profile.FontWeight != null) fontObj["weight"] = profile.FontWeight;
            obj["font"] = fontObj;
        }
        obj["suppressApplicationTitle"] = profile.SuppressApplicationTitle;
        return obj;
    }

    /// <summary>
    /// Writes the modified JsonNode back to settings.json via atomic temp file + move.
    /// </summary>
    private void WriteSurgicalResult(JsonNode root)
    {
        var options = new JsonSerializerOptions { WriteIndented = true };
        var result = root.ToJsonString(options);

        var tempPath = SettingsPath + ".tmp";
        File.WriteAllText(tempPath, result, new UTF8Encoding(false));
        File.Move(tempPath, SettingsPath, overwrite: true);
    }

    /// <summary>
    /// Checks if a profile name is a Matrix-related profile (Matrix-N or Redpill).
    /// </summary>
    private static bool IsMatrixProfile(string? profileName)
    {
        if (string.IsNullOrEmpty(profileName))
            return false;

        return Regex.IsMatch(profileName, @"^Matrix-\d+$")
            || string.Equals(profileName, "Redpill", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Creates default settings with minimal structure.
    /// </summary>
    private TerminalSettings CreateDefaultSettings()
    {
        return new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>()
            }
        };
    }

    /// <summary>
    /// Attempts to recover profiles from malformed JSON using regex.
    /// </summary>
    private TerminalSettings? RecoverSettings(string content)
    {
        // Try to extract profiles.list section using regex
        // This handles common JSON errors like trailing commas
        var profiles = new List<TerminalProfile>();

        // Match profile objects with name and guid
        var profilePattern = new Regex(
            @"\{[^{}]*""name""\s*:\s*""([^""]+)""[^{}]*""guid""\s*:\s*""([^""]+)""[^{}]*\}",
            RegexOptions.Singleline);

        foreach (Match match in profilePattern.Matches(content))
        {
            // Try to parse individual profile
            try
            {
                var profileJson = match.Value;
                var profile = JsonSerializer.Deserialize(profileJson, MatrixJsonContext.Default.TerminalProfile);
                if (profile != null && !string.IsNullOrEmpty(profile.Name))
                {
                    profiles.Add(profile);
                }
            }
            catch (Exception ex)
            {
                DiagnosticLogger.ProductionError("TERMINAL", $"Failed to parse profile during recovery: {ex.Message}");
            }
        }

        if (profiles.Count == 0)
            return null;

        _logger.LogInformation("Recovered {Count} profiles from malformed JSON", profiles.Count);

        return new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = profiles
            }
        };
    }

    /// <summary>
    /// Verifies that Matrix profiles exist and have valid shader paths.
    /// </summary>
    /// <param name="profileCount">Number of profiles expected (1-8)</param>
    /// <returns>Verification result with details</returns>
    public ProfileVerificationResult VerifyProfiles(int profileCount)
    {
        var settings = LoadSettings();
        var profiles = settings.Profiles?.List ?? new List<TerminalProfile>();

        var missing = new List<string>();
        var invalidPaths = new List<string>();

        for (int i = 1; i <= profileCount; i++)
        {
            var profileName = $"Matrix-{i}";
            var profile = profiles.FirstOrDefault(p => p.Name == profileName);

            if (profile == null)
            {
                missing.Add(profileName);
                continue;
            }

            if (!string.IsNullOrEmpty(profile.PixelShaderPath) && !File.Exists(profile.PixelShaderPath))
            {
                invalidPaths.Add($"{profileName}: {profile.PixelShaderPath}");
            }
        }

        return new ProfileVerificationResult
        {
            Success = missing.Count == 0 && invalidPaths.Count == 0,
            MissingProfiles = missing,
            InvalidShaderPaths = invalidPaths
        };
    }
}

/// <summary>
/// Result of profile verification.
/// </summary>
public record ProfileVerificationResult
{
    /// <summary>Whether all profiles exist and have valid shader paths.</summary>
    public bool Success { get; init; }

    /// <summary>List of profile names that were expected but not found.</summary>
    public List<string> MissingProfiles { get; init; } = new();

    /// <summary>List of profiles with invalid (non-existent) shader paths.</summary>
    public List<string> InvalidShaderPaths { get; init; } = new();
}
