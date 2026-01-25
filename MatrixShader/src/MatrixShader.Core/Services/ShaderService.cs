using System.Text;
using System.Text.RegularExpressions;
using MatrixShader.Core.Models;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Core.Services;

/// <summary>
/// Implementation of shader file read/write operations.
/// </summary>
public partial class ShaderService : IShaderService
{
    private readonly ILogger<ShaderService> _logger;
    private readonly string _shadersPath;

    // Regex patterns for parsing #define statements
    [GeneratedRegex(@"#define\s+COLOR_R\s+([\d.]+)")]
    private static partial Regex ColorRRegex();

    [GeneratedRegex(@"#define\s+COLOR_G\s+([\d.]+)")]
    private static partial Regex ColorGRegex();

    [GeneratedRegex(@"#define\s+COLOR_B\s+([\d.]+)")]
    private static partial Regex ColorBRegex();

    [GeneratedRegex(@"#define\s+SPEED\s+([\d.]+)")]
    private static partial Regex SpeedRegex();

    [GeneratedRegex(@"#define\s+GLOW\s+([\d.]+)")]
    private static partial Regex GlowRegex();

    [GeneratedRegex(@"#define\s+WIDTH\s+([\d.]+)")]
    private static partial Regex WidthRegex();

    [GeneratedRegex(@"#define\s+TRAIL\s+([\d.]+)")]
    private static partial Regex TrailRegex();

    [GeneratedRegex(@"#define\s+DENSITY\s+([\d.]+)")]
    private static partial Regex DensityRegex();

    [GeneratedRegex(@"#define\s+LAYER1\s+(\d)")]
    private static partial Regex Layer1Regex();

    [GeneratedRegex(@"#define\s+LAYER2\s+(\d)")]
    private static partial Regex Layer2Regex();

    [GeneratedRegex(@"#define\s+LAYER3\s+(\d)")]
    private static partial Regex Layer3Regex();

    public ShaderService(ILogger<ShaderService> logger, string? shadersPath = null)
    {
        _logger = logger;
        _shadersPath = shadersPath ?? GetDefaultShadersPath();
    }

    private static string GetDefaultShadersPath()
    {
        // Try common locations
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Matrix", "shaders"),
            Path.Combine(AppContext.BaseDirectory, "shaders"),
            @"C:\Users\ehome\Documents\Matrix\shaders"
        };

        return candidates.FirstOrDefault(Directory.Exists) ?? candidates[0];
    }

    public string GetShaderPath(int shaderIndex)
    {
        if (shaderIndex < 1 || shaderIndex > 8)
            throw new ArgumentOutOfRangeException(nameof(shaderIndex), "Shader index must be 1-8");

        return Path.Combine(_shadersPath, $"Matrix-{shaderIndex}.hlsl");
    }

    public bool ShaderExists(int shaderIndex) =>
        File.Exists(GetShaderPath(shaderIndex));

    public ShaderConfig ReadConfig(int shaderIndex)
    {
        var path = GetShaderPath(shaderIndex);
        if (!File.Exists(path))
        {
            _logger.LogWarning("Shader file not found: {Path}", path);
            return new ShaderConfig();
        }

        var content = File.ReadAllText(path);
        return ParseConfig(content);
    }

    private static ShaderConfig ParseConfig(string content)
    {
        float ParseFloat(Regex regex, float defaultValue)
        {
            var match = regex.Match(content);
            return match.Success && float.TryParse(match.Groups[1].Value, out var value)
                ? value
                : defaultValue;
        }

        bool ParseBool(Regex regex, bool defaultValue)
        {
            var match = regex.Match(content);
            return match.Success ? match.Groups[1].Value == "1" : defaultValue;
        }

        return new ShaderConfig
        {
            R = ParseFloat(ColorRRegex(), 0f),
            G = ParseFloat(ColorGRegex(), 1f),
            B = ParseFloat(ColorBRegex(), 0.3f),
            Speed = ParseFloat(SpeedRegex(), 0.8f),
            Glow = ParseFloat(GlowRegex(), 0.8f),
            Width = ParseFloat(WidthRegex(), 10f),
            Trail = ParseFloat(TrailRegex(), 8f),
            Density = ParseFloat(DensityRegex(), 0.4f),
            Layer1 = ParseBool(Layer1Regex(), true),
            Layer2 = ParseBool(Layer2Regex(), true),
            Layer3 = ParseBool(Layer3Regex(), true)
        };
    }

    public void WriteConfig(int shaderIndex, ShaderConfig config)
    {
        var path = GetShaderPath(shaderIndex);

        if (!File.Exists(path))
        {
            _logger.LogError("Cannot write to non-existent shader: {Path}", path);
            throw new FileNotFoundException("Shader file not found", path);
        }

        var content = File.ReadAllText(path);
        var newContent = ApplyConfig(content, config);

        // Atomic write: write to temp file, then move
        var tempPath = path + ".tmp";
        try
        {
            File.WriteAllText(tempPath, newContent, Encoding.UTF8);
            File.Move(tempPath, path, overwrite: true);
            _logger.LogDebug("Wrote shader config to {Path}", path);
        }
        catch
        {
            // Clean up temp file on failure
            if (File.Exists(tempPath))
                File.Delete(tempPath);
            throw;
        }
    }

    private static string ApplyConfig(string content, ShaderConfig config)
    {
        content = ReplaceDefine(content, ColorRRegex(), "COLOR_R", config.R);
        content = ReplaceDefine(content, ColorGRegex(), "COLOR_G", config.G);
        content = ReplaceDefine(content, ColorBRegex(), "COLOR_B", config.B);
        content = ReplaceDefine(content, SpeedRegex(), "SPEED", config.Speed);
        content = ReplaceDefine(content, GlowRegex(), "GLOW", config.Glow);
        content = ReplaceDefine(content, WidthRegex(), "WIDTH", config.Width);
        content = ReplaceDefine(content, TrailRegex(), "TRAIL", config.Trail);
        content = ReplaceDefine(content, DensityRegex(), "DENSITY", config.Density);
        content = ReplaceBoolDefine(content, Layer1Regex(), "LAYER1", config.Layer1);
        content = ReplaceBoolDefine(content, Layer2Regex(), "LAYER2", config.Layer2);
        content = ReplaceBoolDefine(content, Layer3Regex(), "LAYER3", config.Layer3);
        return content;
    }

    private static string ReplaceDefine(string content, Regex regex, string name, float value)
    {
        var match = regex.Match(content);
        if (match.Success)
        {
            return content[..match.Index] +
                   $"#define {name} {value:F2}" +
                   content[(match.Index + match.Length)..];
        }
        return content;
    }

    private static string ReplaceBoolDefine(string content, Regex regex, string name, bool value)
    {
        var match = regex.Match(content);
        if (match.Success)
        {
            return content[..match.Index] +
                   $"#define {name} {(value ? 1 : 0)}" +
                   content[(match.Index + match.Length)..];
        }
        return content;
    }

    public void TouchShader(int shaderIndex)
    {
        var path = GetShaderPath(shaderIndex);
        if (File.Exists(path))
        {
            File.SetLastWriteTimeUtc(path, DateTime.UtcNow);
            _logger.LogDebug("Touched shader file: {Path}", path);
        }
    }
}
