using MatrixShader.Core.Models;

namespace MatrixShader.Core.Services;

/// <summary>
/// Service for reading and writing HLSL shader files.
/// </summary>
public interface IShaderService
{
    /// <summary>
    /// Reads the current configuration from a shader file.
    /// </summary>
    /// <param name="shaderIndex">Shader index (1-8)</param>
    /// <returns>Parsed shader configuration</returns>
    ShaderConfig ReadConfig(int shaderIndex);

    /// <summary>
    /// Writes configuration to a shader file, regenerating #define statements.
    /// </summary>
    /// <param name="shaderIndex">Shader index (1-8)</param>
    /// <param name="config">Configuration to write</param>
    void WriteConfig(int shaderIndex, ShaderConfig config);

    /// <summary>
    /// Gets the file path for a shader index.
    /// </summary>
    /// <param name="shaderIndex">Shader index (1-8)</param>
    /// <returns>Full file path to shader</returns>
    string GetShaderPath(int shaderIndex);

    /// <summary>
    /// Checks if a shader file exists.
    /// </summary>
    /// <param name="shaderIndex">Shader index (1-8)</param>
    bool ShaderExists(int shaderIndex);

    /// <summary>
    /// Touches the shader file to trigger Windows Terminal hot-reload.
    /// </summary>
    /// <param name="shaderIndex">Shader index (1-8)</param>
    void TouchShader(int shaderIndex);
}
