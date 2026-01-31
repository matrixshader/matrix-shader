using System.Text;
using System.Text.Json;
using MatrixShader.Core.Models;
using MatrixShader.Core.Serialization;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Implementation of hotkey configuration persistence.
/// Stores config in LocalAppData/MatrixShader/hotkey-config.json.
/// </summary>
public class HotkeyConfigService : IHotkeyConfigService
{
    private readonly ILogger<HotkeyConfigService> _logger;
    private readonly string _configPath;

    /// <summary>
    /// Default file name for hotkey configuration.
    /// </summary>
    public const string DefaultFileName = "hotkey-config.json";

    public HotkeyConfigService(ILogger<HotkeyConfigService> logger, string? configPath = null)
    {
        _logger = logger;
        _configPath = configPath ?? GetDefaultConfigPath();
    }

    /// <summary>
    /// Gets the default path for hotkey configuration.
    /// Uses LocalAppData/MatrixShader/ directory (same as identity-registry.json).
    /// </summary>
    private static string GetDefaultConfigPath()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(localAppData, "MatrixShader", DefaultFileName);
    }

    /// <inheritdoc />
    public string ConfigPath => _configPath;

    /// <inheritdoc />
    public bool ConfigExists => File.Exists(_configPath);

    /// <inheritdoc />
    public HotkeyConfig LoadConfig()
    {
        if (!ConfigExists)
        {
            _logger.LogInformation("No hotkey config file found, using defaults");
            DiagnosticLogger.Debug("HOTKEY", "No config file found, using defaults");
            return HotkeyConfig.DefaultBindings();
        }

        try
        {
            var json = File.ReadAllText(_configPath);
            var config = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.HotkeyConfig);

            if (config is null)
            {
                _logger.LogWarning("Hotkey config file was empty, using defaults");
                DiagnosticLogger.Warn("HOTKEY", "Config file was empty, using defaults");
                return HotkeyConfig.DefaultBindings();
            }

            _logger.LogDebug("Loaded hotkey config from {Path}", _configPath);
            DiagnosticLogger.Debug("HOTKEY", $"Loaded config from {_configPath}");
            return config;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse hotkey config file, using defaults");
            DiagnosticLogger.Warn("HOTKEY", $"Failed to parse config: {ex.Message}");
            return HotkeyConfig.DefaultBindings();
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "Failed to read hotkey config file, using defaults");
            DiagnosticLogger.Warn("HOTKEY", $"Failed to read config: {ex.Message}");
            return HotkeyConfig.DefaultBindings();
        }
    }

    /// <inheritdoc />
    public void SaveConfig(HotkeyConfig config)
    {
        var tempPath = _configPath + ".tmp";

        try
        {
            // Ensure directory exists
            var dir = Path.GetDirectoryName(_configPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            // Serialize to JSON
            var json = JsonSerializer.Serialize(config, MatrixJsonContext.Default.HotkeyConfig);

            // Atomic write: write to temp file, then move atomically
            File.WriteAllText(tempPath, json, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
            File.Move(tempPath, _configPath, overwrite: true);

            _logger.LogDebug("Saved hotkey config to {Path}", _configPath);
            DiagnosticLogger.Debug("HOTKEY", $"Saved config to {_configPath}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save hotkey config to {Path}", _configPath);
            DiagnosticLogger.Error("HOTKEY", $"Failed to save config: {ex.Message}");

            // Clean up temp file on failure
            try
            {
                if (File.Exists(tempPath))
                    File.Delete(tempPath);
            }
            catch
            {
                // Ignore cleanup failures
            }

            throw;
        }
    }

    /// <inheritdoc />
    public HotkeyConfig ResetToDefaults()
    {
        try
        {
            if (File.Exists(_configPath))
            {
                File.Delete(_configPath);
                _logger.LogInformation("Deleted custom hotkey config, reset to defaults");
                DiagnosticLogger.Info("HOTKEY", "Reset config to defaults");
            }
        }
        catch (IOException ex)
        {
            _logger.LogWarning(ex, "Failed to delete hotkey config file during reset");
            DiagnosticLogger.Warn("HOTKEY", $"Failed to delete config: {ex.Message}");
        }

        return HotkeyConfig.DefaultBindings();
    }
}
