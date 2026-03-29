using System.Text.Json;
using System.Text.RegularExpressions;
using MatrixShader.Core.Models;
using MatrixShader.Core.Serialization;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Persists shader presets as individual JSON files in %LOCALAPPDATA%\MatrixShader\presets\.
/// No caching — fresh disk read every time.
/// </summary>
public class PresetService : IPresetService
{
    private readonly ILogger<PresetService> _logger;
    private readonly string _presetsDir;

    public PresetService(ILogger<PresetService> logger, string? presetsDir = null)
    {
        _logger = logger;
        _presetsDir = presetsDir ?? GetDefaultPresetsDir();
    }

    private static string GetDefaultPresetsDir()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MatrixShader", "presets");
    }

    public ShaderPreset Save(string name, ShaderConfig config)
    {
        var sanitized = SanitizeName(name);
        var preset = ShaderPreset.FromConfig(sanitized, config);

        EnsureDirectory();

        var path = GetPresetPath(sanitized);
        var tempPath = path + ".tmp";
        try
        {
            var json = JsonSerializer.Serialize(preset, MatrixJsonContext.Default.ShaderPreset);
            File.WriteAllText(tempPath, json, new System.Text.UTF8Encoding(false));
            File.Move(tempPath, path, overwrite: true);

            _logger.LogDebug("Saved preset '{Name}' to {Path}", sanitized, path);
            DiagnosticLogger.Debug("PRESET", $"Saved preset '{sanitized}' to {path}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save preset '{Name}'", sanitized);
            DiagnosticLogger.Error("PRESET", $"Failed to save preset '{sanitized}': {ex.Message}");

            try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { }
            throw;
        }

        return preset;
    }

    public ShaderPreset? Load(string name)
    {
        var sanitized = SanitizeName(name);
        var path = GetPresetPath(sanitized);

        if (!File.Exists(path))
        {
            _logger.LogDebug("Preset '{Name}' not found at {Path}", sanitized, path);
            return null;
        }

        try
        {
            var json = File.ReadAllText(path);
            var preset = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.ShaderPreset);
            _logger.LogDebug("Loaded preset '{Name}' from {Path}", sanitized, path);
            return preset;
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Corrupt preset file '{Name}', skipping", sanitized);
            DiagnosticLogger.Warn("PRESET", $"Corrupt preset file '{sanitized}': {ex.Message}");
            return null;
        }
        catch (IOException ex)
        {
            _logger.LogWarning(ex, "Failed to read preset '{Name}'", sanitized);
            DiagnosticLogger.Warn("PRESET", $"Failed to read preset '{sanitized}': {ex.Message}");
            return null;
        }
    }

    public List<ShaderPreset> ListPresets()
    {
        if (!Directory.Exists(_presetsDir))
            return new List<ShaderPreset>();

        var presets = new List<ShaderPreset>();

        foreach (var file in Directory.GetFiles(_presetsDir, "*.json"))
        {
            try
            {
                var json = File.ReadAllText(file);
                var preset = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.ShaderPreset);
                if (preset != null)
                    presets.Add(preset);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Skipping corrupt preset file {File}", Path.GetFileName(file));
                DiagnosticLogger.Warn("PRESET", $"Skipping corrupt preset file {Path.GetFileName(file)}: {ex.Message}");
            }
        }

        // Sort by date descending (newest first)
        presets.Sort((a, b) => b.SavedAt.CompareTo(a.SavedAt));
        return presets;
    }

    public bool Delete(string name)
    {
        var sanitized = SanitizeName(name);
        var path = GetPresetPath(sanitized);

        if (!File.Exists(path))
        {
            _logger.LogDebug("Preset '{Name}' not found for deletion", sanitized);
            return false;
        }

        try
        {
            File.Delete(path);
            _logger.LogDebug("Deleted preset '{Name}' at {Path}", sanitized, path);
            DiagnosticLogger.Debug("PRESET", $"Deleted preset '{sanitized}' at {path}");
            return true;
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "Failed to delete preset '{Name}'", sanitized);
            DiagnosticLogger.Error("PRESET", $"Failed to delete preset '{sanitized}': {ex.Message}");
            return false;
        }
    }

    public bool PresetExists(string name)
    {
        var sanitized = SanitizeName(name);
        return File.Exists(GetPresetPath(sanitized));
    }

    private string GetPresetPath(string sanitizedName)
    {
        return Path.Combine(_presetsDir, $"{sanitizedName}.json");
    }

    private void EnsureDirectory()
    {
        if (!Directory.Exists(_presetsDir))
            Directory.CreateDirectory(_presetsDir);
    }

    /// <summary>
    /// Sanitizes a preset name for use as a filename.
    /// Strips whitespace, lowercases, spaces to dashes, removes non-alphanumeric,
    /// collapses multiple dashes, strips leading/trailing dashes.
    /// </summary>
    internal static string SanitizeName(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Preset name cannot be empty", nameof(name));

        var result = name.Trim().ToLowerInvariant();
        result = result.Replace(' ', '-');
        result = Regex.Replace(result, @"[^a-z0-9-]", "");
        result = Regex.Replace(result, @"-+", "-");
        result = result.Trim('-');

        if (string.IsNullOrEmpty(result))
            throw new ArgumentException($"Preset name '{name}' contains no valid characters", nameof(name));

        return result;
    }
}
