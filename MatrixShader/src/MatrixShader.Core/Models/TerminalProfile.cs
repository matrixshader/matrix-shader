using System.Text.Json.Serialization;

namespace MatrixShader.Core.Models;

/// <summary>
/// Represents a Windows Terminal profile for Matrix shader windows.
/// Maps to entries in settings.json profiles.list array.
/// </summary>
public record TerminalProfile
{
    // Required fields
    public string Name { get; init; } = "";
    public string Guid { get; init; } = "";

    // Matrix-specific fields
    public string? Commandline { get; init; }
    public bool Hidden { get; init; } = true;
    public int Opacity { get; init; } = 95;

    // Shader configuration - NOTE: JSON property name is "experimental.pixelShaderPath"
    // Use JsonPropertyName attribute for the dotted property name
    [JsonPropertyName("experimental.pixelShaderPath")]
    public string? PixelShaderPath { get; init; }

    // Tab color (hex format like "#00FF4C")
    public string? TabColor { get; init; }
}
