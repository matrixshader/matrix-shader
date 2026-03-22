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

    /// <summary>
    /// Creates Matrix-1 through Matrix-N profiles.
    /// </summary>
    /// <param name="settings">Settings to modify</param>
    /// <param name="count">Number of profiles to create (1-8)</param>
    /// <param name="shadersDirectory">Path to shaders directory</param>
    /// <returns>Number of profiles created</returns>
    int CreateMatrixProfiles(TerminalSettings settings, int count, string shadersDirectory);

    /// <summary>
    /// Creates the Redpill control panel profile.
    /// </summary>
    /// <param name="settings">Settings to modify</param>
    /// <param name="shadersDirectory">Path to shaders directory</param>
    /// <param name="controlPanelPath">Path to control panel executable (optional - auto-resolved if null)</param>
    void CreateRedpillProfile(TerminalSettings settings, string shadersDirectory, string? controlPanelPath = null);

    /// <summary>
    /// Verifies that Matrix profiles exist and have valid shader paths.
    /// </summary>
    /// <param name="profileCount">Number of profiles expected (1-8)</param>
    /// <returns>Verification result with details</returns>
    ProfileVerificationResult VerifyProfiles(int profileCount);

    /// <summary>
    /// Checks and updates shader paths if Matrix folder has moved.
    /// </summary>
    /// <param name="settings">Settings to check</param>
    /// <param name="currentShadersDirectory">Current shaders directory path</param>
    /// <returns>Number of paths updated</returns>
    int UpdateShaderPaths(TerminalSettings settings, string currentShadersDirectory);

    /// <summary>
    /// Gets the count of existing Matrix profiles in settings.
    /// </summary>
    /// <param name="settings">Settings to check</param>
    /// <returns>Number of Matrix-N profiles found</returns>
    int GetMatrixProfileCount(TerminalSettings settings);

    /// <summary>
    /// Checks if Matrix profiles exist in settings.
    /// </summary>
    /// <param name="settings">Settings to check</param>
    /// <returns>True if at least one Matrix profile exists</returns>
    bool HasMatrixProfiles(TerminalSettings settings);

    /// <summary>
    /// Forces Windows Terminal to reload shaders by re-saving settings.json.
    /// WT's file watcher doesn't reliably detect .hlsl file changes,
    /// but it always detects settings.json writes.
    /// </summary>
    void ForceShaderReload();

    /// <summary>
    /// Surgically upserts a single profile using JsonNode, preserving all other
    /// content in settings.json (other profiles, comments, property ordering).
    /// Prevents the tab-kill bug caused by full deserialization stripping/adding
    /// properties on non-Matrix profiles.
    /// </summary>
    void UpsertProfileSurgical(TerminalProfile profile);

    /// <summary>
    /// Surgically upserts multiple profiles in a single settings.json write.
    /// </summary>
    void UpsertProfilesSurgical(IEnumerable<TerminalProfile> profiles);

    /// <summary>
    /// Gets the GUID of an existing profile by name, reading directly from JSON.
    /// </summary>
    string? GetProfileGuid(string profileName);

    /// <summary>
    /// Surgically removes a profile by name from settings.json using text splice.
    /// Preserves all other content (comments, formatting, other profiles) byte-for-byte.
    /// Used to clean up orphaned Construct profiles after GUID swap transition.
    /// </summary>
    void RemoveProfileSurgical(string profileName);
}
