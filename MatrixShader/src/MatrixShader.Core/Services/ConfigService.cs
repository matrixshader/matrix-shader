using System.Text.Json;
using MatrixShader.Core.Models;
using MatrixShader.Core.Serialization;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Implementation of application state persistence.
/// </summary>
public class ConfigService : IConfigService
{
    private readonly ILogger<ConfigService> _logger;
    private readonly string _configPath;

    public ConfigService(ILogger<ConfigService> logger, string? configPath = null)
    {
        _logger = logger;
        _configPath = configPath ?? GetDefaultConfigPath();
    }

    private static string GetDefaultConfigPath()
    {
        var candidates = new[]
        {
            // 1. LocalAppData (canonical user location post-install)
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "MatrixShader"),
            // 2. App directory (development/portable)
            Path.Combine(AppContext.BaseDirectory, "config"),
        };

        return candidates.FirstOrDefault(Directory.Exists) ?? candidates[0];
    }

    public string StatePath => Path.Combine(_configPath, "matrix_state.json");

    public bool StateExists => File.Exists(StatePath);

    /// <summary>
    /// Checks if this is a first run (no saved state file).
    /// This is the authoritative check - don't rely on ShaderConfigs.Count
    /// because the default MatrixState() constructor creates 8 empty slots.
    /// </summary>
    public bool IsFirstRun
    {
        get
        {
            var result = !StateExists;
            DiagnosticLogger.Debug("CONFIG", $"IsFirstRun check: {result} (path: {StatePath})");
            return result;
        }
    }

    public MatrixState LoadState()
    {
        if (!StateExists)
        {
            _logger.LogInformation("No state file found, using defaults");
            return new MatrixState();
        }

        try
        {
            var json = File.ReadAllText(StatePath);
            var state = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.MatrixState);
            _logger.LogDebug("Loaded state from {Path}", StatePath);
            DiagnosticLogger.Debug("CONFIG", $"Loaded state from {StatePath}");
            return state ?? new MatrixState();
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse state file, using defaults");
            DiagnosticLogger.Warn("CONFIG", $"Failed to parse state file: {ex.Message}");
            return new MatrixState();
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "Failed to read state file, using defaults");
            DiagnosticLogger.Warn("CONFIG", $"Failed to read state file: {ex.Message}");
            return new MatrixState();
        }
    }

    public void SaveState(MatrixState state)
    {
        var tempPath = StatePath + ".tmp";
        try
        {
            // Ensure directory exists
            var dir = Path.GetDirectoryName(StatePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            // Update timestamp
            state = state with { LastModified = DateTime.UtcNow };

            // Atomic write: write to temp file, then move atomically
            var json = JsonSerializer.Serialize(state, MatrixJsonContext.Default.MatrixState);
            File.WriteAllText(tempPath, json, new System.Text.UTF8Encoding(false));
            File.Move(tempPath, StatePath, overwrite: true);

            _logger.LogDebug("Saved state to {Path}", StatePath);
            DiagnosticLogger.Debug("CONFIG", $"Saved state to {StatePath}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save state to {Path}", StatePath);
            DiagnosticLogger.Error("CONFIG", $"Failed to save state: {ex.Message}");

            // Clean up temp file on failure (enhancement to atomic write)
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

    public MatrixState ResetState()
    {
        var state = new MatrixState();
        SaveState(state);
        _logger.LogInformation("Reset state to defaults");
        DiagnosticLogger.Info("CONFIG", "Reset state to defaults");
        return state;
    }
}
