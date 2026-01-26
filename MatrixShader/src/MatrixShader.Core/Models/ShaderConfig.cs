namespace MatrixShader.Core.Models;

/// <summary>
/// Configuration for shader visual parameters.
/// Maps directly to HLSL #define statements.
/// </summary>
public record ShaderConfig
{
    /// <summary>Red color component (0.0 - 1.0)</summary>
    public float R { get; init; } = 0f;

    /// <summary>Green color component (0.0 - 1.0)</summary>
    public float G { get; init; } = 1f;

    /// <summary>Blue color component (0.0 - 1.0)</summary>
    public float B { get; init; } = 0.3f;

    /// <summary>Animation speed multiplier (0.1 - 3.0)</summary>
    public float Speed { get; init; } = 0.8f;

    /// <summary>Glow intensity (0.2 - 3.0)</summary>
    public float Glow { get; init; } = 0.8f;

    /// <summary>Character column width in pixels (6 - 20)</summary>
    public float Width { get; init; } = 10f;

    /// <summary>Trail length multiplier (4 - 15)</summary>
    public float Trail { get; init; } = 8f;

    /// <summary>Character spawn density (0.2 - 1.0)</summary>
    public float Density { get; init; } = 0.4f;

    /// <summary>Far depth layer enabled</summary>
    public bool Layer1 { get; init; } = true;

    /// <summary>Mid depth layer enabled</summary>
    public bool Layer2 { get; init; } = true;

    /// <summary>Near depth layer enabled</summary>
    public bool Layer3 { get; init; } = true;

    /// <summary>
    /// Creates a copy with the specified color preset applied.
    /// </summary>
    public ShaderConfig WithColor(float r, float g, float b) =>
        this with { R = r, G = g, B = b };

    /// <summary>
    /// Validates all parameters are within acceptable ranges.
    /// Ranges match PowerShell matrix_control.ps1 Adj function.
    /// </summary>
    public bool IsValid() =>
        R >= 0f && R <= 1f &&
        G >= 0f && G <= 1f &&
        B >= 0f && B <= 1f &&
        Speed >= 0.1f && Speed <= 3f &&
        Glow >= 0.2f && Glow <= 3f &&
        Width >= 6f && Width <= 20f &&
        Trail >= 4f && Trail <= 15f &&
        Density >= 0.2f && Density <= 1f;
}
