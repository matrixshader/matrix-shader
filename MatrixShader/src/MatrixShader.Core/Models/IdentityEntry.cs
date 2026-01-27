namespace MatrixShader.Core.Models;

/// <summary>
/// Persisted identity registry format.
/// Stored at AppData\Local\MatrixShader\identity-registry.json
/// </summary>
public record IdentityRegistry
{
    /// <summary>Registry format version</summary>
    public string Version { get; init; } = "1.0";

    /// <summary>Timestamp when registry was last saved</summary>
    public DateTime SavedAt { get; init; }

    /// <summary>
    /// Window identity entries keyed by window handle (as string).
    /// Keys are string because nint is not JSON-friendly.
    /// </summary>
    public Dictionary<string, IdentityEntry> Entries { get; init; } = new();
}

/// <summary>
/// Single entry in the identity registry.
/// Keys in the registry are window handles as strings.
/// </summary>
public record IdentityEntry
{
    /// <summary>Terminal profile name (e.g., "Matrix-1")</summary>
    public string ProfileName { get; init; } = string.Empty;

    /// <summary>Assigned shader index (1-8)</summary>
    public int ShaderIndex { get; init; }

    /// <summary>Process ID that owns the window</summary>
    public int ProcessId { get; init; }

    /// <summary>Window handle as string (nint is not JSON-friendly)</summary>
    public string WindowHandle { get; init; } = string.Empty;

    /// <summary>When the window was launched/tracked</summary>
    public DateTime LaunchTime { get; init; }

    /// <summary>Unique correlation ID for launch tracking</summary>
    public string CorrelationId { get; init; } = string.Empty;
}
