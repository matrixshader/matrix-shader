using System.Text.Json.Serialization;
using MatrixShader.Core.Models;

namespace MatrixShader.Core.Serialization;

/// <summary>
/// Source-generated JSON serializer context for Native AOT compatibility.
/// All JSON serialization must use this context instead of reflection.
/// </summary>
[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    UseStringEnumConverter = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
[JsonSerializable(typeof(MatrixState))]
[JsonSerializable(typeof(ShaderConfig))]
[JsonSerializable(typeof(ShaderPreset))]
[JsonSerializable(typeof(LayoutConfig))]
[JsonSerializable(typeof(Dictionary<int, ShaderConfig>))]
[JsonSerializable(typeof(IdentityRegistry))]
[JsonSerializable(typeof(IdentityEntry))]
[JsonSerializable(typeof(Dictionary<string, IdentityEntry>))]
[JsonSerializable(typeof(WindowSlot))]
[JsonSerializable(typeof(Dictionary<string, WindowSlot>))]
[JsonSerializable(typeof(TerminalSettings))]
[JsonSerializable(typeof(TerminalProfile))]
[JsonSerializable(typeof(ProfilesContainer))]
[JsonSerializable(typeof(List<TerminalProfile>))]
// Additional types for AOT completeness (GAP-I06)
[JsonSerializable(typeof(RenderMode))]
[JsonSerializable(typeof(LayoutMode))]
[JsonSerializable(typeof(BorderMargins))]
[JsonSerializable(typeof(MonitorInfo))]
[JsonSerializable(typeof(WindowRect))]
[JsonSerializable(typeof(IdentitySource))]
// Hotkey configuration types (Phase 10.5)
[JsonSerializable(typeof(HotkeyConfig))]
[JsonSerializable(typeof(HotkeyBinding))]
[JsonSerializable(typeof(HotkeyAction))]
[JsonSerializable(typeof(Dictionary<HotkeyAction, HotkeyBinding>))]
internal partial class MatrixJsonContext : JsonSerializerContext
{
}
