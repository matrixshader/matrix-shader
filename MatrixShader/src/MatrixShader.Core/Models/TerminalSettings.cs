using System.Text.Json;
using System.Text.Json.Serialization;

namespace MatrixShader.Core.Models;

/// <summary>
/// Represents Windows Terminal settings.json structure.
/// Only models the portions we need to modify (profiles.list).
/// </summary>
public class TerminalSettings
{
    // We only need profiles for Matrix profile management
    public ProfilesContainer? Profiles { get; set; }

    // Preserve all other properties as-is using JsonExtensionData
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? ExtensionData { get; set; }
}

/// <summary>
/// Container for profiles section in settings.json.
/// </summary>
public class ProfilesContainer
{
    public List<TerminalProfile>? List { get; set; }

    // Preserve defaults and other profile properties
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? ExtensionData { get; set; }
}
