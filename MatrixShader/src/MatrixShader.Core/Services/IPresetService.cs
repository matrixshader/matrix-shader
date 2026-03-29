using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for saving, loading, listing, and deleting shader presets.
/// </summary>
public interface IPresetService
{
    /// <summary>
    /// Saves a shader configuration as a named preset.
    /// Overwrites if a preset with the same sanitized name already exists.
    /// </summary>
    /// <param name="name">Preset name (will be sanitized for filename)</param>
    /// <param name="config">Shader configuration to save</param>
    /// <returns>The saved preset</returns>
    ShaderPreset Save(string name, ShaderConfig config);

    /// <summary>
    /// Loads a preset by name.
    /// </summary>
    /// <param name="name">Preset name (will be sanitized for lookup)</param>
    /// <returns>The preset, or null if not found</returns>
    ShaderPreset? Load(string name);

    /// <summary>
    /// Lists all saved presets, sorted by date descending (newest first).
    /// </summary>
    /// <returns>List of all presets</returns>
    List<ShaderPreset> ListPresets();

    /// <summary>
    /// Deletes a preset by name.
    /// </summary>
    /// <param name="name">Preset name (will be sanitized for lookup)</param>
    /// <returns>True if deleted, false if not found</returns>
    bool Delete(string name);

    /// <summary>
    /// Checks if a preset with the given name exists.
    /// </summary>
    /// <param name="name">Preset name (will be sanitized for lookup)</param>
    /// <returns>True if the preset exists</returns>
    bool PresetExists(string name);
}
