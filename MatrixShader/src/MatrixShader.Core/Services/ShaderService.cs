using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using MatrixShader.Core.Constants;
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
        // Priority order for shader resolution:
        var candidates = new[]
        {
            // 1. LocalAppData (canonical user location post-install)
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "MatrixShader", "shaders"),
            // 2. Program Files (installed location, fallback)
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "MatrixShader", "shaders"),
            // 3. App directory (development/portable)
            Path.Combine(AppContext.BaseDirectory, "shaders"),
        };

        var selectedPath = candidates.FirstOrDefault(Directory.Exists);
        if (selectedPath != null)
        {
            DiagnosticLogger.Debug("SHADER", $"Using shaders from: {selectedPath}");
            return selectedPath;
        }

        // Default to LocalAppData location (will be created on first use)
        DiagnosticLogger.Debug("SHADER", $"No shader directory found, defaulting to: {candidates[0]}");
        return candidates[0];
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
            // Create new shader from template
            CreateShader(shaderIndex, config);
            return;
        }

        // Modify existing shader
        var content = File.ReadAllText(path);
        var newContent = ApplyConfig(content, config);

        // Atomic write: write to temp file, then move
        var tempPath = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tempPath, newContent, new UTF8Encoding(false));
            File.Move(tempPath, path, overwrite: true);

            // Force-bump timestamp so Windows Terminal's file watcher detects the change.
            // File.Move alone doesn't always trigger WT's shader hot-reload on Windows.
            File.SetLastWriteTimeUtc(path, DateTime.UtcNow);

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
        // Color values
        content = ReplaceDefine(content, "RAIN_R", config.R);
        content = ReplaceDefine(content, "RAIN_G", config.G);
        content = ReplaceDefine(content, "RAIN_B", config.B);

        // Animation parameters
        content = ReplaceDefine(content, "RAIN_SPEED", config.Speed);
        content = ReplaceDefine(content, "GLOW_STRENGTH", config.Glow);
        content = ReplaceDefine(content, "CHAR_WIDTH", config.Width);
        content = ReplaceDefine(content, "TRAIL_POWER", config.Trail);
        content = ReplaceDefine(content, "RAIN_DENSITY", config.Density);

        // Layer toggles as floats (1.0 or 0.0)
        content = ReplaceDefine(content, "SHOW_L1", config.Layer1 ? 1.0f : 0.0f);
        content = ReplaceDefine(content, "SHOW_L2", config.Layer2 ? 1.0f : 0.0f);
        content = ReplaceDefine(content, "SHOW_L3", config.Layer3 ? 1.0f : 0.0f);

        return content;
    }

    private static string ReplaceDefine(string content, string name, float value)
    {
        // Match #define NAME followed by whitespace and numeric value
        var pattern = $@"(#define\s+{name}\s+)[\d.]+";
        // Use MatchEvaluator to avoid regex backreference interpretation issues
        // (e.g., "$10.0" would be interpreted as capture group 10, not "$1" + "0.0")
        var replacement = value.ToString("F1", CultureInfo.InvariantCulture);
        return Regex.Replace(content, pattern, m => m.Groups[1].Value + replacement);
    }

    public void WriteDefines(int shaderIndex, params (string name, float value)[] defines)
    {
        var path = GetShaderPath(shaderIndex);
        if (!File.Exists(path)) return;

        var content = File.ReadAllText(path);
        foreach (var (name, value) in defines)
        {
            content = ReplaceDefine(content, name, value);
        }

        var tempPath = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tempPath, content, new UTF8Encoding(false));
            File.Move(tempPath, path, overwrite: true);
            File.SetLastWriteTimeUtc(path, DateTime.UtcNow);
        }
        catch
        {
            if (File.Exists(tempPath)) File.Delete(tempPath);
            throw;
        }
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

    /// <summary>
    /// Creates a new shader file from template with the given configuration.
    /// </summary>
    /// <param name="shaderIndex">Shader index (1-8)</param>
    /// <param name="config">Configuration for the new shader</param>
    public void CreateShader(int shaderIndex, ShaderConfig config)
    {
        var path = GetShaderPath(shaderIndex);
        var tempPath = Path.GetTempFileName();

        try
        {
            var content = GenerateShaderContent(shaderIndex, config);
            File.WriteAllText(tempPath, content, new UTF8Encoding(false));

            // Ensure directory exists
            var dir = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            File.Move(tempPath, path, overwrite: true);
            _logger.LogDebug("Created shader: {Path}", path);
        }
        catch
        {
            if (File.Exists(tempPath))
                File.Delete(tempPath);
            throw;
        }
    }

    private static string GenerateShaderContent(int shaderIndex, ShaderConfig config)
    {
        return ShaderTemplate.Template
            .Replace("{SLOT}", shaderIndex.ToString())
            .Replace("{R}", config.R.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{G}", config.G.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{B}", config.B.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{SPEED}", config.Speed.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{GLOW}", config.Glow.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{WIDTH}", config.Width.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{TRAIL}", config.Trail.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{DENS}", config.Density.ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{L1}", (config.Layer1 ? 1.0f : 0.0f).ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{L2}", (config.Layer2 ? 1.0f : 0.0f).ToString("F1", CultureInfo.InvariantCulture))
            .Replace("{L3}", (config.Layer3 ? 1.0f : 0.0f).ToString("F1", CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// Checks if the system can use Windows Terminal shaders.
    /// Returns false if WT is not installed or version doesn't support shaders.
    /// </summary>
    /// <returns>Tuple of (canUse, reason) where reason explains the result</returns>
    public static (bool CanUse, string Reason) CanUseShaders()
    {
        // Check if Windows Terminal settings exist (Store version)
        var wtSettingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Packages",
            "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
            "LocalState",
            "settings.json");

        if (!File.Exists(wtSettingsPath))
        {
            // Check for unpackaged WT (winget/scoop installed)
            var unpackagedPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Microsoft",
                "Windows Terminal",
                "settings.json");

            if (!File.Exists(unpackagedPath))
            {
                DiagnosticLogger.Warn("SHADER", "Windows Terminal settings.json not found");
                return (false, "Windows Terminal is not installed. Use 'matrixlite' for text-mode fallback.");
            }
            else
            {
                DiagnosticLogger.Debug("SHADER", $"Found unpackaged WT settings: {unpackagedPath}");
            }
        }
        else
        {
            DiagnosticLogger.Debug("SHADER", $"Found Store WT settings: {wtSettingsPath}");
        }

        // Check Windows version (shaders require Windows 10 1903+ / build 18362+)
        var osVersion = Environment.OSVersion.Version;
        if (osVersion.Major < 10 || (osVersion.Major == 10 && osVersion.Build < 18362))
        {
            DiagnosticLogger.Warn("SHADER", $"Windows version {osVersion} does not support shaders (requires 10.0.18362+)");
            return (false, "Windows 10 version 1903 or later required for shaders. Use 'matrixlite' for text-mode fallback.");
        }

        DiagnosticLogger.Info("SHADER", "Shader support available");
        return (true, "Shader support available");
    }

    /// <summary>
    /// Attempts to detect Windows Terminal version for diagnostics.
    /// </summary>
    /// <returns>Version string if detected, null otherwise</returns>
    public static string? GetWindowsTerminalVersion()
    {
        try
        {
            // Check Store package version via WindowsApps folder
            var packagePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "WindowsApps");

            // Look for Microsoft.WindowsTerminal_* folder
            if (Directory.Exists(packagePath))
            {
                try
                {
                    var wtFolders = Directory.GetDirectories(packagePath, "Microsoft.WindowsTerminal_*");
                    if (wtFolders.Length > 0)
                    {
                        // Extract version from folder name (e.g., Microsoft.WindowsTerminal_1.19.10821.0_x64__8wekyb3d8bbwe)
                        var folderName = Path.GetFileName(wtFolders[0]);
                        var parts = folderName.Split('_');
                        if (parts.Length >= 2)
                        {
                            DiagnosticLogger.Debug("SHADER", $"Detected WT version: {parts[1]}");
                            return parts[1];
                        }
                    }
                }
                catch (UnauthorizedAccessException)
                {
                    // WindowsApps folder is restricted - this is expected
                    DiagnosticLogger.Debug("SHADER", "Cannot access WindowsApps folder for version detection");
                }
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Debug("SHADER", $"WT version detection failed: {ex.Message}");
        }

        return null;
    }
}
