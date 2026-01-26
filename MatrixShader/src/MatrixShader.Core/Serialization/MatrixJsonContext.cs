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
[JsonSerializable(typeof(LayoutConfig))]
[JsonSerializable(typeof(Dictionary<int, ShaderConfig>))]
internal partial class MatrixJsonContext : JsonSerializerContext
{
}
