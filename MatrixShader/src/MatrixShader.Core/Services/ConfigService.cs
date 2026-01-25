using System.Text.Json;
using System.Text.Json.Serialization;
using MatrixShader.Core.Models;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Implementation of application state persistence.
/// </summary>
public class ConfigService : IConfigService
{
    private readonly ILogger<ConfigService> _logger;
    private readonly string _configPath;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter() }
    };

    public ConfigService(ILogger<ConfigService> logger, string? configPath = null)
    {
        _logger = logger;
        _configPath = configPath ?? GetDefaultConfigPath();
    }

    private static string GetDefaultConfigPath()
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Matrix"),
            Path.Combine(AppContext.BaseDirectory, "config"),
            @"C:\Users\ehome\Documents\Matrix"
        };

        return candidates.FirstOrDefault(Directory.Exists) ?? candidates[0];
    }

    public string StatePath => Path.Combine(_configPath, "matrix_state.json");

    public bool StateExists => File.Exists(StatePath);

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
            var state = JsonSerializer.Deserialize<MatrixState>(json, JsonOptions);
            _logger.LogDebug("Loaded state from {Path}", StatePath);
            return state ?? new MatrixState();
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse state file, using defaults");
            return new MatrixState();
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "Failed to read state file, using defaults");
            return new MatrixState();
        }
    }

    public void SaveState(MatrixState state)
    {
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

            // Atomic write
            var tempPath = StatePath + ".tmp";
            var json = JsonSerializer.Serialize(state, JsonOptions);
            File.WriteAllText(tempPath, json);
            File.Move(tempPath, StatePath, overwrite: true);

            _logger.LogDebug("Saved state to {Path}", StatePath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save state");
            throw;
        }
    }

    public MatrixState ResetState()
    {
        var state = new MatrixState();
        SaveState(state);
        _logger.LogInformation("Reset state to defaults");
        return state;
    }
}
