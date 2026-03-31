using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for ShaderService — HLSL shader file read/write/create operations.
/// Reference: linux/tests/test_shader_service.py
/// </summary>
public class ShaderServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ShaderService _service;
    private readonly Mock<ILogger<ShaderService>> _logger;

    // Sample HLSL content matching the ShaderTemplate structure
    private const string SampleShaderContent = @"// MATRIX SHADER - SLOT 1
#define RAIN_R         0.0
#define RAIN_G         1.0
#define RAIN_B         0.3
#define RAIN_SPEED     0.8
#define GLOW_STRENGTH  0.8
#define FONT_SCALE     1.0
#define CHAR_WIDTH     10.0
#define TRAIL_POWER    8.0
#define RAIN_DENSITY   0.4
#define SHOW_L1        1.0
#define SHOW_L2        1.0
#define SHOW_L3        1.0
#define FADE_DURATION  0.0

float4 main() { return float4(0,0,0,0); }
";

    public ShaderServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "MatrixShaderTests_Shader_" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(_tempDir);
        _logger = new Mock<ILogger<ShaderService>>();
        _service = new ShaderService(_logger.Object, _tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, recursive: true); } catch { }
    }

    private string WriteShaderFile(int index, string content)
    {
        var path = Path.Combine(_tempDir, $"Matrix-{index}.hlsl");
        File.WriteAllText(path, content);
        return path;
    }

    // -----------------------------------------------------------------------
    // GetShaderPath
    // -----------------------------------------------------------------------

    [Fact]
    public void GetShaderPath_ReturnsCorrectPath()
    {
        var path = _service.GetShaderPath(1);
        path.Should().Be(Path.Combine(_tempDir, "Matrix-1.hlsl"));
    }

    [Fact]
    public void GetShaderPath_Index5_ReturnsCorrectPath()
    {
        var path = _service.GetShaderPath(5);
        path.Should().Be(Path.Combine(_tempDir, "Matrix-5.hlsl"));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(9)]
    [InlineData(100)]
    public void GetShaderPath_InvalidIndex_Throws(int index)
    {
        var act = () => _service.GetShaderPath(index);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    // -----------------------------------------------------------------------
    // ShaderExists
    // -----------------------------------------------------------------------

    [Fact]
    public void ShaderExists_ReturnsTrueWhenFilePresent()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.ShaderExists(1).Should().BeTrue();
    }

    [Fact]
    public void ShaderExists_ReturnsFalseWhenFileMissing()
    {
        _service.ShaderExists(1).Should().BeFalse();
    }

    // -----------------------------------------------------------------------
    // ReadConfig — parses all 11 defines
    // -----------------------------------------------------------------------

    [Fact]
    public void ReadConfig_ParsesAll11Params()
    {
        WriteShaderFile(1, SampleShaderContent);
        var config = _service.ReadConfig(1);

        config.R.Should().Be(0f);
        config.G.Should().Be(1f);
        config.B.Should().BeApproximately(0.3f, 0.001f);
        config.Speed.Should().BeApproximately(0.8f, 0.001f);
        config.Glow.Should().BeApproximately(0.8f, 0.001f);
        config.Width.Should().Be(10f);
        config.Trail.Should().Be(8f);
        config.Density.Should().BeApproximately(0.4f, 0.001f);
        config.Layer1.Should().BeTrue();
        config.Layer2.Should().BeTrue();
        config.Layer3.Should().BeTrue();
    }

    [Fact]
    public void ReadConfig_ReturnsDefaults_WhenFileMissing()
    {
        var config = _service.ReadConfig(1);
        config.Should().BeEquivalentTo(new ShaderConfig());
    }

    [Fact]
    public void ReadConfig_ReturnsDefaults_ForMissingDefines()
    {
        WriteShaderFile(1, "#define RAIN_R  0.5\nvoid main() {}\n");
        var config = _service.ReadConfig(1);
        config.R.Should().Be(0.5f);
        // Missing params get defaults
        config.G.Should().Be(1f);
        config.Speed.Should().BeApproximately(0.8f, 0.001f);
        config.Layer1.Should().BeTrue();
    }

    [Fact]
    public void ReadConfig_HandlesIntegerValues()
    {
        WriteShaderFile(1, "#define SHOW_L1  1\n#define RAIN_SPEED  2\n");
        var config = _service.ReadConfig(1);
        config.Layer1.Should().BeTrue();
        config.Speed.Should().Be(2f);
    }

    [Fact]
    public void ReadConfig_ParsesLayerToggles()
    {
        var content = SampleShaderContent
            .Replace("#define SHOW_L1        1.0", "#define SHOW_L1        0.0")
            .Replace("#define SHOW_L3        1.0", "#define SHOW_L3        0.0");
        WriteShaderFile(1, content);

        var config = _service.ReadConfig(1);
        config.Layer1.Should().BeFalse();
        config.Layer2.Should().BeTrue();
        config.Layer3.Should().BeFalse();
    }

    [Fact]
    public void ReadConfig_ParsesCustomColorValues()
    {
        var content = SampleShaderContent
            .Replace("#define RAIN_R         0.0", "#define RAIN_R         0.7")
            .Replace("#define RAIN_G         1.0", "#define RAIN_G         0.2")
            .Replace("#define RAIN_B         0.3", "#define RAIN_B         0.9");
        WriteShaderFile(1, content);

        var config = _service.ReadConfig(1);
        config.R.Should().BeApproximately(0.7f, 0.001f);
        config.G.Should().BeApproximately(0.2f, 0.001f);
        config.B.Should().BeApproximately(0.9f, 0.001f);
    }

    [Fact]
    public void ReadConfig_HandlesVaryingWhitespace()
    {
        WriteShaderFile(1, "#define RAIN_R\t\t0.5\n#define RAIN_G   1.0\n");
        var config = _service.ReadConfig(1);
        config.R.Should().Be(0.5f);
        config.G.Should().Be(1f);
    }

    // -----------------------------------------------------------------------
    // WriteConfig — preserves file content, only changes defines
    // -----------------------------------------------------------------------

    [Fact]
    public void WriteConfig_PreservesExistingContent()
    {
        WriteShaderFile(1, SampleShaderContent);
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0f };
        _service.WriteConfig(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("float4 main()");
        content.Should().Contain("FONT_SCALE");
    }

    [Fact]
    public void WriteConfig_UpdatesColorDefines()
    {
        WriteShaderFile(1, SampleShaderContent);
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0.5f };
        _service.WriteConfig(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         1.0");
        content.Should().Contain("#define RAIN_G         0.0");
        content.Should().Contain("#define RAIN_B         0.5");
    }

    [Fact]
    public void WriteConfig_UpdatesAllParams()
    {
        WriteShaderFile(1, SampleShaderContent);
        var config = new ShaderConfig
        {
            R = 0.7f, G = 0.2f, B = 0.9f,
            Speed = 2.5f, Glow = 1.5f, Width = 12f,
            Trail = 10f, Density = 0.6f,
            Layer1 = false, Layer2 = true, Layer3 = false
        };
        _service.WriteConfig(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         0.7");
        content.Should().Contain("#define RAIN_G         0.2");
        content.Should().Contain("#define RAIN_B         0.9");
        content.Should().Contain("#define RAIN_SPEED     2.5");
        content.Should().Contain("#define GLOW_STRENGTH  1.5");
        content.Should().Contain("#define CHAR_WIDTH     12.0");
        content.Should().Contain("#define TRAIL_POWER    10.0");
        content.Should().Contain("#define RAIN_DENSITY   0.6");
        content.Should().Contain("#define SHOW_L1        0.0");
        content.Should().Contain("#define SHOW_L2        1.0");
        content.Should().Contain("#define SHOW_L3        0.0");
    }

    [Fact]
    public void WriteConfig_CreatesFileFromTemplate_WhenMissing()
    {
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0f };
        _service.WriteConfig(1, config);

        File.Exists(Path.Combine(_tempDir, "Matrix-1.hlsl")).Should().BeTrue();
        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         1.0");
        content.Should().Contain("GLYPHS");
    }

    [Fact]
    public void WriteConfig_FormatsFloatsWithOneDecimal()
    {
        WriteShaderFile(1, SampleShaderContent);
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0f };
        _service.WriteConfig(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        // Should be "1.0" not just "1"
        content.Should().Contain("#define RAIN_R         1.0");
        content.Should().NotContain("#define RAIN_R         1\n");
    }

    [Fact]
    public void WriteConfig_FormatsFloatsWithLeadingZero()
    {
        WriteShaderFile(1, SampleShaderContent);
        var config = new ShaderConfig { R = 0.3f };
        _service.WriteConfig(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         0.3");
    }

    // -----------------------------------------------------------------------
    // WriteDefines — changes only specified defines, leaves others untouched
    // -----------------------------------------------------------------------

    [Fact]
    public void WriteDefines_ChangesOnlySpecifiedDefines()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1, ("RAIN_SPEED", 2.5f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_SPEED     2.5");
        // Colors should be unchanged
        content.Should().Contain("#define RAIN_R         0.0");
        content.Should().Contain("#define RAIN_G         1.0");
        content.Should().Contain("#define RAIN_B         0.3");
        content.Should().Contain("#define GLOW_STRENGTH  0.8");
    }

    [Fact]
    public void WriteDefines_MultipleDefinesAtOnce()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1,
            ("RAIN_SPEED", 3.0f),
            ("RAIN_R", 1.0f),
            ("RAIN_G", 0.0f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_SPEED     3.0");
        content.Should().Contain("#define RAIN_R         1.0");
        content.Should().Contain("#define RAIN_G         0.0");
        // B should be unchanged
        content.Should().Contain("#define RAIN_B         0.3");
    }

    [Fact]
    public void WriteDefines_NoOp_WhenFileMissing()
    {
        // Should not throw, just return silently
        _service.WriteDefines(1, ("RAIN_SPEED", 2.5f));
        File.Exists(Path.Combine(_tempDir, "Matrix-1.hlsl")).Should().BeFalse();
    }

    [Fact]
    public void WriteDefines_NonexistentDefine_LeavesContentUnchanged()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1, ("NONEXISTENT_PARAM", 5.0f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         0.0");
        content.Should().Contain("#define RAIN_G         1.0");
    }

    [Fact]
    public void WriteDefines_LayerToggle()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1, ("SHOW_L1", 0.0f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define SHOW_L1        0.0");
        // Other layers unchanged
        content.Should().Contain("#define SHOW_L2        1.0");
        content.Should().Contain("#define SHOW_L3        1.0");
    }

    [Fact]
    public void WriteDefines_LayerToggleOnAndOff()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1, ("SHOW_L1", 0.0f));
        _service.WriteDefines(1, ("SHOW_L1", 1.0f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define SHOW_L1        1.0");
    }

    // -----------------------------------------------------------------------
    // CreateShader — creates from template
    // -----------------------------------------------------------------------

    [Fact]
    public void CreateShader_CreatesFileWithCorrectStructure()
    {
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0f };
        _service.CreateShader(1, config);

        var path = Path.Combine(_tempDir, "Matrix-1.hlsl");
        File.Exists(path).Should().BeTrue();

        var content = File.ReadAllText(path);
        content.Should().Contain("GLYPHS");
        content.Should().Contain("DrawLayer");
        content.Should().Contain("float4 main");
        content.Should().Contain("SLOT 1");
    }

    [Fact]
    public void CreateShader_InjectsRGBValues()
    {
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0.5f };
        _service.CreateShader(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         1.0");
        content.Should().Contain("#define RAIN_G         0.0");
        content.Should().Contain("#define RAIN_B         0.5");
    }

    [Fact]
    public void CreateShader_InjectsAllParams()
    {
        var config = new ShaderConfig
        {
            R = 0.7f, G = 0.2f, B = 0.9f,
            Speed = 2.5f, Glow = 1.5f, Width = 12f,
            Trail = 10f, Density = 0.6f,
            Layer1 = false, Layer2 = true, Layer3 = false
        };
        _service.CreateShader(2, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-2.hlsl"));
        content.Should().Contain("SLOT 2");
        content.Should().Contain("#define RAIN_R         0.7");
        content.Should().Contain("#define RAIN_SPEED     2.5");
        content.Should().Contain("#define SHOW_L1        0.0");
        content.Should().Contain("#define SHOW_L3        0.0");
    }

    [Fact]
    public void CreateShader_OverwritesExistingFile()
    {
        WriteShaderFile(1, "old content");
        var config = new ShaderConfig { R = 1f, G = 0f, B = 0f };
        _service.CreateShader(1, config);

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().NotContain("old content");
        content.Should().Contain("GLYPHS");
    }

    [Fact]
    public void CreateShader_CreatesDirectory_WhenMissing()
    {
        var nestedDir = Path.Combine(_tempDir, "subdir", "shaders");
        var nestedService = new ShaderService(_logger.Object, nestedDir);
        var config = new ShaderConfig();
        nestedService.CreateShader(1, config);

        File.Exists(Path.Combine(nestedDir, "Matrix-1.hlsl")).Should().BeTrue();
    }

    // -----------------------------------------------------------------------
    // Slot isolation — writes to one shader don't affect others
    // -----------------------------------------------------------------------

    [Fact]
    public void WriteConfig_SlotIsolation()
    {
        WriteShaderFile(1, SampleShaderContent);
        WriteShaderFile(2, SampleShaderContent);

        var config = new ShaderConfig { R = 1f, G = 0f, B = 0f, Speed = 4f };
        _service.WriteConfig(1, config);

        // Slot 2 should be unchanged
        var content2 = File.ReadAllText(Path.Combine(_tempDir, "Matrix-2.hlsl"));
        content2.Should().Contain("#define RAIN_R         0.0");
        content2.Should().Contain("#define RAIN_SPEED     0.8");

        // Slot 1 should be changed
        var content1 = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content1.Should().Contain("#define RAIN_R         1.0");
        content1.Should().Contain("#define RAIN_SPEED     4.0");
    }

    [Fact]
    public void WriteDefines_SlotIsolation()
    {
        WriteShaderFile(1, SampleShaderContent);
        WriteShaderFile(2, SampleShaderContent);

        _service.WriteDefines(1, ("RAIN_SPEED", 4.0f));

        var content2 = File.ReadAllText(Path.Combine(_tempDir, "Matrix-2.hlsl"));
        content2.Should().Contain("#define RAIN_SPEED     0.8");

        var content1 = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content1.Should().Contain("#define RAIN_SPEED     4.0");
    }

    // -----------------------------------------------------------------------
    // Roundtrip — write then read back
    // -----------------------------------------------------------------------

    [Fact]
    public void WriteConfig_ThenReadConfig_Roundtrips()
    {
        WriteShaderFile(1, SampleShaderContent);
        var original = new ShaderConfig
        {
            R = 0.7f, G = 0.2f, B = 0.9f,
            Speed = 2.5f, Glow = 1.5f, Width = 12f,
            Trail = 10f, Density = 0.6f,
            Layer1 = false, Layer2 = true, Layer3 = false
        };
        _service.WriteConfig(1, original);

        var readBack = _service.ReadConfig(1);
        readBack.R.Should().BeApproximately(original.R, 0.01f);
        readBack.G.Should().BeApproximately(original.G, 0.01f);
        readBack.B.Should().BeApproximately(original.B, 0.01f);
        readBack.Speed.Should().BeApproximately(original.Speed, 0.01f);
        readBack.Glow.Should().BeApproximately(original.Glow, 0.01f);
        readBack.Width.Should().BeApproximately(original.Width, 0.01f);
        readBack.Trail.Should().BeApproximately(original.Trail, 0.01f);
        readBack.Density.Should().BeApproximately(original.Density, 0.01f);
        readBack.Layer1.Should().Be(original.Layer1);
        readBack.Layer2.Should().Be(original.Layer2);
        readBack.Layer3.Should().Be(original.Layer3);
    }

    [Fact]
    public void CreateShader_ThenReadConfig_Roundtrips()
    {
        var original = new ShaderConfig
        {
            R = 0.5f, G = 0.5f, B = 0.5f,
            Speed = 1.5f, Glow = 2.0f, Width = 15f,
            Trail = 6f, Density = 0.8f,
            Layer1 = true, Layer2 = false, Layer3 = true
        };
        _service.CreateShader(3, original);

        var readBack = _service.ReadConfig(3);
        readBack.R.Should().BeApproximately(original.R, 0.01f);
        readBack.G.Should().BeApproximately(original.G, 0.01f);
        readBack.B.Should().BeApproximately(original.B, 0.01f);
        readBack.Speed.Should().BeApproximately(original.Speed, 0.01f);
        readBack.Layer2.Should().Be(original.Layer2);
    }

    // -----------------------------------------------------------------------
    // TouchShader
    // -----------------------------------------------------------------------

    [Fact]
    public void TouchShader_UpdatesTimestamp()
    {
        WriteShaderFile(1, SampleShaderContent);
        var before = File.GetLastWriteTimeUtc(Path.Combine(_tempDir, "Matrix-1.hlsl"));

        // Small delay to ensure timestamp difference
        Thread.Sleep(50);
        _service.TouchShader(1);

        var after = File.GetLastWriteTimeUtc(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        after.Should().BeAfter(before);
    }

    [Fact]
    public void TouchShader_NoOpWhenFileMissing()
    {
        // Should not throw
        _service.TouchShader(1);
    }

    // -----------------------------------------------------------------------
    // ReplaceDefine edge cases (tested via WriteDefines)
    // -----------------------------------------------------------------------

    [Fact]
    public void WriteDefines_ArbitraryRGBValues()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1,
            ("RAIN_R", 0.7f),
            ("RAIN_G", 0.2f),
            ("RAIN_B", 0.9f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_R         0.7");
        content.Should().Contain("#define RAIN_G         0.2");
        content.Should().Contain("#define RAIN_B         0.9");
    }

    [Fact]
    public void WriteDefines_ZeroValue()
    {
        WriteShaderFile(1, SampleShaderContent);
        _service.WriteDefines(1, ("RAIN_G", 0.0f));

        var content = File.ReadAllText(Path.Combine(_tempDir, "Matrix-1.hlsl"));
        content.Should().Contain("#define RAIN_G         0.0");
    }
}
