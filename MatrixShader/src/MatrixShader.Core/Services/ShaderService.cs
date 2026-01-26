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

    // Regex patterns for parsing #define statements (names match actual HLSL file)
    [GeneratedRegex(@"#define\s+RAIN_R\s+([\d.]+)")]
    private static partial Regex RainRRegex();

    [GeneratedRegex(@"#define\s+RAIN_G\s+([\d.]+)")]
    private static partial Regex RainGRegex();

    [GeneratedRegex(@"#define\s+RAIN_B\s+([\d.]+)")]
    private static partial Regex RainBRegex();

    [GeneratedRegex(@"#define\s+RAIN_SPEED\s+([\d.]+)")]
    private static partial Regex RainSpeedRegex();

    [GeneratedRegex(@"#define\s+GLOW_STRENGTH\s+([\d.]+)")]
    private static partial Regex GlowStrengthRegex();

    [GeneratedRegex(@"#define\s+CHAR_WIDTH\s+([\d.]+)")]
    private static partial Regex CharWidthRegex();

    [GeneratedRegex(@"#define\s+TRAIL_POWER\s+([\d.]+)")]
    private static partial Regex TrailPowerRegex();

    [GeneratedRegex(@"#define\s+RAIN_DENSITY\s+([\d.]+)")]
    private static partial Regex RainDensityRegex();

    [GeneratedRegex(@"#define\s+SHOW_L1\s+([\d.]+)")]
    private static partial Regex ShowL1Regex();

    [GeneratedRegex(@"#define\s+SHOW_L2\s+([\d.]+)")]
    private static partial Regex ShowL2Regex();

    [GeneratedRegex(@"#define\s+SHOW_L3\s+([\d.]+)")]
    private static partial Regex ShowL3Regex();

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
            if (match.Success)
            {
                var valueStr = match.Groups[1].Value;
                // Validate: must be valid float format (digits, optional decimal point, more digits)
                if (Regex.IsMatch(valueStr, @"^\d+\.?\d*$") &&
                    float.TryParse(valueStr, System.Globalization.CultureInfo.InvariantCulture, out var value))
                {
                    return value;
                }
            }
            return defaultValue;
        }

        return new ShaderConfig
        {
            R = ParseFloat(RainRRegex(), 0f),
            G = ParseFloat(RainGRegex(), 1f),
            B = ParseFloat(RainBRegex(), 0.3f),
            Speed = ParseFloat(RainSpeedRegex(), 0.8f),
            Glow = ParseFloat(GlowStrengthRegex(), 0.8f),
            Width = ParseFloat(CharWidthRegex(), 10f),
            Trail = ParseFloat(TrailPowerRegex(), 8f),
            Density = ParseFloat(RainDensityRegex(), 0.4f),
            // Layer toggles: HLSL uses 1.0/0.0, parse as float and compare > 0.5
            Layer1 = ParseFloat(ShowL1Regex(), 1f) > 0.5f,
            Layer2 = ParseFloat(ShowL2Regex(), 1f) > 0.5f,
            Layer3 = ParseFloat(ShowL3Regex(), 1f) > 0.5f
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
        content = ReplaceDefine(content, RainRRegex(), "RAIN_R", config.R);
        content = ReplaceDefine(content, RainGRegex(), "RAIN_G", config.G);
        content = ReplaceDefine(content, RainBRegex(), "RAIN_B", config.B);
        content = ReplaceDefine(content, RainSpeedRegex(), "RAIN_SPEED", config.Speed);
        content = ReplaceDefine(content, GlowStrengthRegex(), "GLOW_STRENGTH", config.Glow);
        content = ReplaceDefine(content, CharWidthRegex(), "CHAR_WIDTH", config.Width);
        content = ReplaceDefine(content, TrailPowerRegex(), "TRAIL_POWER", config.Trail);
        content = ReplaceDefine(content, RainDensityRegex(), "RAIN_DENSITY", config.Density);
        // Layer toggles: write as float (1.0/0.0) to match HLSL format
        content = ReplaceDefine(content, ShowL1Regex(), "SHOW_L1", config.Layer1 ? 1.0f : 0.0f);
        content = ReplaceDefine(content, ShowL2Regex(), "SHOW_L2", config.Layer2 ? 1.0f : 0.0f);
        content = ReplaceDefine(content, ShowL3Regex(), "SHOW_L3", config.Layer3 ? 1.0f : 0.0f);
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
