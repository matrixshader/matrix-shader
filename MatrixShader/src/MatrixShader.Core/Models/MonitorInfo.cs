namespace MatrixShader.Core.Models;

/// <summary>
/// Information about a display monitor.
/// </summary>
public record MonitorInfo
{
    /// <summary>Monitor handle</summary>
    public nint Handle { get; init; }

    /// <summary>Monitor index (0-based)</summary>
    public int Index { get; init; }

    /// <summary>Full monitor bounds including taskbar</summary>
    public WindowRect Bounds { get; init; } = new();

    /// <summary>Work area excluding taskbar</summary>
    public WindowRect WorkArea { get; init; } = new();

    /// <summary>Is this the primary monitor</summary>
    public bool IsPrimary { get; init; }

    /// <summary>Monitor name/device</summary>
    public string DeviceName { get; init; } = string.Empty;

    /// <summary>DPI scaling factor (1.0 = 100%)</summary>
    public float DpiScale { get; init; } = 1.0f;
}
