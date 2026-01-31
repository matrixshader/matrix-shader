using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for managing hotkey configuration persistence.
/// </summary>
public interface IHotkeyConfigService
{
    /// <summary>
    /// Loads the hotkey configuration from disk.
    /// Returns defaults if file doesn't exist or is invalid.
    /// </summary>
    /// <returns>Loaded config or default bindings.</returns>
    HotkeyConfig LoadConfig();

    /// <summary>
    /// Saves the hotkey configuration to disk.
    /// Uses atomic write (temp file + move) for safety.
    /// </summary>
    /// <param name="config">Configuration to persist.</param>
    void SaveConfig(HotkeyConfig config);

    /// <summary>
    /// Resets configuration to defaults and removes custom config file.
    /// </summary>
    /// <returns>Default hotkey bindings.</returns>
    HotkeyConfig ResetToDefaults();

    /// <summary>
    /// Gets the path to the hotkey configuration file.
    /// </summary>
    string ConfigPath { get; }

    /// <summary>
    /// Checks if a custom configuration file exists.
    /// </summary>
    bool ConfigExists { get; }
}
