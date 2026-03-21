using System.Text.Json;
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

    // NOTE: Opacity is set per-profile, not on profiles.defaults.
    // This ensures only Matrix windows get transparency.
    // Per user requirement: non-Matrix windows stay 100% opaque.
    public int Opacity { get; init; } = 85;

    // Transparency toggle (acrylic effect) - required for Opacity to work
    public bool UseAcrylic { get; init; } = true;

    // Shader configuration - NOTE: JSON property name is "experimental.pixelShaderPath"
    // Use JsonPropertyName attribute for the dotted property name
    [JsonPropertyName("experimental.pixelShaderPath")]
    public string? PixelShaderPath { get; init; }

    // Tab color (hex format like "#00FF4C")
    public string? TabColor { get; init; }

    // Background image (path to image file)
    public string? BackgroundImage { get; init; }
    public string? BackgroundImageStretchMode { get; init; }
    public string? BackgroundImageAlignment { get; init; }
    public double? BackgroundImageOpacity { get; init; }

    // Text colors (hex format like "#FFFFFF")
    public string? Foreground { get; init; }
    public string? Background { get; init; }

    // Terminal padding (e.g. "0" to remove padding)
    public string? Padding { get; init; }

    // Prevent shell from overriding profile name in tab title.
    // Required for hotkey identity resolution (Layer 3: title pattern matching).
    public bool SuppressApplicationTitle { get; init; } = true;

    [JsonExtensionData]
    public Dictionary<string, JsonElement>? ExtensionData { get; set; }
}
