using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
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

    // Standard Windows Terminal settings path
    private static readonly string DefaultSettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Packages",
        "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
        "LocalState",
        "settings.json");

    public TerminalSettingsService(ILogger<TerminalSettingsService> logger, string? settingsPath = null)
    {
        _logger = logger;
        SettingsPath = settingsPath ?? DefaultSettingsPath;
        BackupPath = SettingsPath + ".matrix-backup";
    }

    public string SettingsPath { get; }
    public string BackupPath { get; }
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
        CreateBackup();
        try
        {
            var recoveredSettings = RecoverSettings(content);
            if (recoveredSettings != null)
            {
                _logger.LogInformation("Recovered settings from malformed JSON");
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
            catch
            {
                // Skip unparseable profiles
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
}
