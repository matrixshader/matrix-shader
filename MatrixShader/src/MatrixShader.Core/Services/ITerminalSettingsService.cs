using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for reading and writing Windows Terminal settings.json.
/// </summary>
public interface ITerminalSettingsService
{
    /// <summary>
    /// Gets the path to Windows Terminal settings.json.
    /// </summary>
    string SettingsPath { get; }

    /// <summary>
    /// Gets the path to the backup file.
    /// </summary>
    string BackupPath { get; }

    /// <summary>
    /// Checks if Windows Terminal settings file exists.
    /// </summary>
    bool SettingsExist { get; }

    /// <summary>
    /// Reads and parses settings.json with error recovery.
    /// If JSON is malformed, creates backup and attempts recovery.
    /// </summary>
    /// <returns>Parsed settings or new default settings if recovery fails</returns>
    TerminalSettings LoadSettings();

    /// <summary>
    /// Saves settings to settings.json using atomic write pattern.
    /// </summary>
    /// <param name="settings">Settings to save</param>
    /// <exception cref="IOException">If file is locked by Windows Terminal</exception>
    void SaveSettings(TerminalSettings settings);

    /// <summary>
    /// Creates a backup of current settings.json.
    /// </summary>
    /// <returns>True if backup created successfully</returns>
    bool CreateBackup();

    /// <summary>
    /// Gets a profile by name from settings.
    /// </summary>
    /// <param name="settings">Settings to search</param>
    /// <param name="profileName">Profile name to find</param>
    /// <returns>Profile or null if not found</returns>
    TerminalProfile? GetProfile(TerminalSettings settings, string profileName);

    /// <summary>
    /// Adds or updates a profile in settings.
    /// </summary>
    /// <param name="settings">Settings to modify</param>
    /// <param name="profile">Profile to upsert</param>
    void UpsertProfile(TerminalSettings settings, TerminalProfile profile);
}
