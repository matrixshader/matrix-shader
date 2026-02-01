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

    public int CreateMatrixProfiles(TerminalSettings settings, int count, string shadersDirectory)
    {
        if (count < 1 || count > 8)
            throw new ArgumentOutOfRangeException(nameof(count), "Count must be between 1 and 8");

        DiagnosticLogger.Info("TERMINAL", $"Creating profiles with shader path: {shadersDirectory}");

        var created = 0;
        for (int i = 1; i <= count; i++)
        {
            var profileName = $"Matrix-{i}";

            // Skip if profile already exists
            if (GetProfile(settings, profileName) != null)
            {
                _logger.LogDebug("Profile {Name} already exists, skipping", profileName);
                continue;
            }

            var profile = new TerminalProfile
            {
                Name = profileName,
                Guid = $"{{{Guid.NewGuid()}}}",
                Commandline = $"powershell.exe -NoExit -Command \"Write-Host ' Matrix Terminal {i}' -ForegroundColor Green\"",
                Hidden = true,
                Opacity = 95,
                PixelShaderPath = Path.Combine(shadersDirectory, $"Matrix-{i}.hlsl")
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
        const string profileName = "Redpill";

        // Check if already exists
        if (GetProfile(settings, profileName) != null)
        {
            _logger.LogDebug("Redpill profile already exists");
            return;
        }

        // Resolve the control panel executable path
        var effectivePath = string.IsNullOrEmpty(controlPanelPath)
            ? GetRedpillExecutablePath()
            : controlPanelPath;

        DiagnosticLogger.Debug("TERMINAL", $"Redpill profile using control panel: {effectivePath}");

        var profile = new TerminalProfile
        {
            Name = profileName,
            Guid = $"{{{Guid.NewGuid()}}}",
            Commandline = $"\"{effectivePath}\"",
            Hidden = true,
            Opacity = 95,
            PixelShaderPath = Path.Combine(shadersDirectory, "Redpill-Neo.hlsl")
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
        // Try Program Files first (installed location)
        var programFilesPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "MatrixShader", "redpill.exe");

        if (File.Exists(programFilesPath))
        {
            DiagnosticLogger.Debug("TERMINAL", $"Found redpill at installed location: {programFilesPath}");
            return programFilesPath;
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
