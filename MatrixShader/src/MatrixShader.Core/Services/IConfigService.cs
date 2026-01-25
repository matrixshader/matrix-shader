using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for managing application state persistence.
/// </summary>
public interface IConfigService
{
    /// <summary>
    /// Loads the application state from disk.
    /// </summary>
    /// <returns>Loaded state or default if not found</returns>
    MatrixState LoadState();

    /// <summary>
    /// Saves the application state to disk.
    /// </summary>
    /// <param name="state">State to persist</param>
    void SaveState(MatrixState state);

    /// <summary>
    /// Gets the path to the state file.
    /// </summary>
    string StatePath { get; }

    /// <summary>
    /// Checks if a state file exists.
    /// </summary>
    bool StateExists { get; }

    /// <summary>
    /// Resets state to defaults.
    /// </summary>
    MatrixState ResetState();
}
