namespace MatrixShader.Core.Models;

/// <summary>
/// Persisted window slot assignment for layout restoration.
/// Maps a Matrix shader window to a specific layout slot.
/// </summary>
public record WindowSlot
{
    /// <summary>Shader index (1-8) this slot is assigned to</summary>
    public int ShaderIndex { get; init; }

    /// <summary>Slot position in layout (0-based)</summary>
    public int SlotPosition { get; init; }

    /// <summary>Monitor index where window should appear</summary>
    public int MonitorIndex { get; init; }

    /// <summary>Last known position for validation</summary>
    public WindowRect? LastPosition { get; init; }

    /// <summary>Working directory the shell was in when saved</summary>
    public string? WorkingDirectory { get; init; }
}
