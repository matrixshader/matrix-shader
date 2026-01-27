using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for identifying and tracking Matrix shader windows.
/// Uses a 4-layer resolution hierarchy for reliability.
/// </summary>
public interface IIdentityService
{
    /// <summary>
    /// Finds all Matrix shader windows.
    /// </summary>
    /// <returns>List of identified windows</returns>
    IReadOnlyList<WindowInfo> FindMatrixWindows();

    /// <summary>
    /// Resolves the identity of a specific window.
    /// </summary>
    /// <param name="hwnd">Window handle</param>
    /// <returns>Window identity or null if not a Matrix window</returns>
    WindowInfo? ResolveIdentity(nint hwnd);

    /// <summary>
    /// Registers a newly launched window for tracking.
    /// </summary>
    /// <param name="processId">Process ID</param>
    /// <param name="profileName">Terminal profile name</param>
    /// <param name="shaderIndex">Associated shader index</param>
    void RegisterLaunch(int processId, string profileName, int shaderIndex);

    /// <summary>
    /// Clears the launch tracking registry.
    /// </summary>
    void ClearRegistry();

    /// <summary>
    /// Loads the identity registry from disk.
    /// </summary>
    void LoadRegistry();

    /// <summary>
    /// Saves the identity registry to disk.
    /// </summary>
    void SaveRegistry();

    /// <summary>
    /// Cleans stale entries from the registry.
    /// Should be called on application startup.
    /// </summary>
    /// <param name="maxAge">Maximum age for entries (default: 24 hours)</param>
    /// <returns>Number of entries removed</returns>
    int CleanStaleEntries(TimeSpan? maxAge = null);

    /// <summary>
    /// Registers a window by its handle for tracking.
    /// More reliable than PID for wt.exe launches.
    /// </summary>
    /// <param name="hwnd">Window handle</param>
    /// <param name="profileName">Terminal profile name</param>
    /// <param name="shaderIndex">Associated shader index</param>
    void RegisterWindowHandle(nint hwnd, string profileName, int shaderIndex);
}
