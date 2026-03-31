using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for PresetService — preset CRUD with JSON file storage.
/// Reference: linux/tests/test_preset_service.py
/// </summary>
public class PresetServiceTests : IDisposable
{
    private readonly string _presetsDir;
    private readonly PresetService _service;
    private readonly Mock<ILogger<PresetService>> _logger;

    public PresetServiceTests()
    {
        _presetsDir = Path.Combine(Path.GetTempPath(), "MatrixShaderTests_Preset_" + Guid.NewGuid().ToString("N")[..8]);
        _logger = new Mock<ILogger<PresetService>>();
        _service = new PresetService(_logger.Object, _presetsDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_presetsDir, recursive: true); } catch { }
    }

    // -----------------------------------------------------------------------
    // SanitizeName
    // -----------------------------------------------------------------------

    [Fact]
    public void SanitizeName_SpacesToDashes()
    {
        PresetService.SanitizeName("My Cool Preset").Should().Be("my-cool-preset");
    }

    [Fact]
    public void SanitizeName_StripAndCollapse()
    {
        PresetService.SanitizeName("  spaces  ").Should().Be("spaces");
    }

    [Fact]
    public void SanitizeName_UppercaseToLowercase()
    {
        PresetService.SanitizeName("UPPER Case").Should().Be("upper-case");
    }

    [Fact]
    public void SanitizeName_RemoveSpecialChars()
    {
        PresetService.SanitizeName("special!@#chars").Should().Be("specialchars");
    }

    [Fact]
    public void SanitizeName_EmptyThrows()
    {
        var act = () => PresetService.SanitizeName("");
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void SanitizeName_WhitespaceOnlyThrows()
    {
        var act = () => PresetService.SanitizeName("   ");
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void SanitizeName_AllStrippedThrows()
    {
        var act = () => PresetService.SanitizeName("---");
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void SanitizeName_AlreadyCleanPassthrough()
    {
        PresetService.SanitizeName("my-preset").Should().Be("my-preset");
    }

    [Fact]
    public void SanitizeName_MultipleSpacesCollapseToSingleDash()
    {
        PresetService.SanitizeName("foo   bar   baz").Should().Be("foo-bar-baz");
    }

    [Fact]
    public void SanitizeName_LeadingTrailingDashesStripped()
    {
        PresetService.SanitizeName("--hello--").Should().Be("hello");
    }

    // -----------------------------------------------------------------------
    // Save
    // -----------------------------------------------------------------------

    [Fact]
    public void Save_CreatesJsonFile()
    {
        var config = new ShaderConfig { R = 0.1f, G = 0.2f, B = 0.9f };
        _service.Save("night-mode", config);

        var path = Path.Combine(_presetsDir, "night-mode.json");
        File.Exists(path).Should().BeTrue();
    }

    [Fact]
    public void Save_ReturnsPresetWithCorrectName()
    {
        var config = new ShaderConfig { R = 0.5f };
        var preset = _service.Save("test", config);

        preset.Name.Should().Be("test");
        preset.R.Should().Be(0.5f);
        preset.SavedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
    }

    [Fact]
    public void Save_PreservesAllParams()
    {
        var config = new ShaderConfig
        {
            R = 0.7f, G = 0f, B = 1f,
            Speed = 1.5f, Glow = 2f, Width = 12f,
            Trail = 10f, Density = 0.6f,
            Layer1 = false, Layer2 = true, Layer3 = false
        };
        _service.Save("full", config);

        var loaded = _service.Load("full");
        loaded.Should().NotBeNull();
        loaded!.R.Should().Be(0.7f);
        loaded.G.Should().Be(0f);
        loaded.B.Should().Be(1f);
        loaded.Speed.Should().Be(1.5f);
        loaded.Glow.Should().Be(2f);
        loaded.Width.Should().Be(12f);
        loaded.Trail.Should().Be(10f);
        loaded.Density.Should().Be(0.6f);
        loaded.Layer1.Should().BeFalse();
        loaded.Layer2.Should().BeTrue();
        loaded.Layer3.Should().BeFalse();
    }

    [Fact]
    public void Save_OverwritesExistingPreset()
    {
        _service.Save("dup", new ShaderConfig { R = 0.1f });
        _service.Save("dup", new ShaderConfig { R = 0.9f });

        var loaded = _service.Load("dup");
        loaded.Should().NotBeNull();
        loaded!.R.Should().Be(0.9f);
    }

    [Fact]
    public void Save_SanitizesName()
    {
        _service.Save("My Cool Preset", new ShaderConfig { R = 0.1f });

        var path = Path.Combine(_presetsDir, "my-cool-preset.json");
        File.Exists(path).Should().BeTrue();
    }

    [Fact]
    public void Save_CreatesDirectory()
    {
        var nestedDir = Path.Combine(_presetsDir, "deep", "nested", "presets");
        var nestedService = new PresetService(_logger.Object, nestedDir);
        nestedService.Save("test", new ShaderConfig());

        Directory.Exists(nestedDir).Should().BeTrue();
    }

    [Fact]
    public void Save_ThenLoad_Roundtrip()
    {
        var config = new ShaderConfig
        {
            R = 0.7f, G = 0f, B = 1f,
            Speed = 1.5f, Glow = 2f, Width = 12f,
            Trail = 10f, Density = 0.6f,
            Layer1 = false, Layer2 = true, Layer3 = false
        };
        _service.Save("full", config);
        var loaded = _service.Load("full");

        loaded.Should().NotBeNull();
        var loadedConfig = loaded!.ToConfig();
        loadedConfig.R.Should().Be(config.R);
        loadedConfig.G.Should().Be(config.G);
        loadedConfig.B.Should().Be(config.B);
        loadedConfig.Speed.Should().Be(config.Speed);
        loadedConfig.Glow.Should().Be(config.Glow);
        loadedConfig.Width.Should().Be(config.Width);
        loadedConfig.Trail.Should().Be(config.Trail);
        loadedConfig.Density.Should().Be(config.Density);
        loadedConfig.Layer1.Should().Be(config.Layer1);
        loadedConfig.Layer2.Should().Be(config.Layer2);
        loadedConfig.Layer3.Should().Be(config.Layer3);
    }

    // -----------------------------------------------------------------------
    // Load
    // -----------------------------------------------------------------------

    [Fact]
    public void Load_ReturnsPresetWithParams()
    {
        _service.Save("test", new ShaderConfig { R = 0.3f, G = 0.4f });
        var preset = _service.Load("test");

        preset.Should().NotBeNull();
        preset!.R.Should().Be(0.3f);
        preset.G.Should().Be(0.4f);
    }

    [Fact]
    public void Load_ReturnsNull_ForNonexistent()
    {
        Directory.CreateDirectory(_presetsDir);
        var preset = _service.Load("nonexistent");
        preset.Should().BeNull();
    }

    [Fact]
    public void Load_ReturnsNull_ForCorruptJson()
    {
        Directory.CreateDirectory(_presetsDir);
        File.WriteAllText(Path.Combine(_presetsDir, "corrupt.json"), "{{{not valid json!!!");
        var preset = _service.Load("corrupt");
        preset.Should().BeNull();
    }

    [Fact]
    public void Load_ByUnsanitizedName()
    {
        _service.Save("night-mode", new ShaderConfig { R = 0.1f });
        var preset = _service.Load("Night Mode");
        preset.Should().NotBeNull();
        preset!.R.Should().Be(0.1f);
    }

    // -----------------------------------------------------------------------
    // ListPresets
    // -----------------------------------------------------------------------

    [Fact]
    public void ListPresets_ReturnsSavedPresets()
    {
        _service.Save("alpha", new ShaderConfig { R = 0.1f });
        Thread.Sleep(50); // Ensure different SavedAt timestamps
        _service.Save("beta", new ShaderConfig { R = 0.2f });

        var result = _service.ListPresets();
        result.Should().HaveCount(2);
    }

    [Fact]
    public void ListPresets_SortedByDateDescending()
    {
        _service.Save("alpha", new ShaderConfig { R = 0.1f });
        Thread.Sleep(50);
        _service.Save("beta", new ShaderConfig { R = 0.2f });

        var result = _service.ListPresets();
        result[0].Name.Should().Be("beta"); // newest first
        result[1].Name.Should().Be("alpha");
    }

    [Fact]
    public void ListPresets_EmptyDir_ReturnsEmptyList()
    {
        Directory.CreateDirectory(_presetsDir);
        _service.ListPresets().Should().BeEmpty();
    }

    [Fact]
    public void ListPresets_NonexistentDir_ReturnsEmptyList()
    {
        // Don't create the directory
        _service.ListPresets().Should().BeEmpty();
    }

    [Fact]
    public void ListPresets_IgnoresNonJsonFiles()
    {
        Directory.CreateDirectory(_presetsDir);
        File.WriteAllText(Path.Combine(_presetsDir, "readme.txt"), "not a preset");
        _service.Save("real", new ShaderConfig { R = 0.5f });

        _service.ListPresets().Should().HaveCount(1);
        _service.ListPresets()[0].Name.Should().Be("real");
    }

    [Fact]
    public void ListPresets_SkipsCorruptJson()
    {
        Directory.CreateDirectory(_presetsDir);
        File.WriteAllText(Path.Combine(_presetsDir, "bad.json"), "{{{garbage");
        _service.Save("good", new ShaderConfig { R = 0.5f });

        var result = _service.ListPresets();
        result.Should().HaveCount(1);
        result[0].Name.Should().Be("good");
    }

    [Fact]
    public void ListPresets_IncludesColorInfo()
    {
        _service.Save("colorful", new ShaderConfig { R = 0.7f, G = 0f, B = 1f });
        var result = _service.ListPresets();

        result.Should().HaveCount(1);
        result[0].R.Should().Be(0.7f);
        result[0].G.Should().Be(0f);
        result[0].B.Should().Be(1f);
    }

    [Fact]
    public void ListPresets_IncludesSavedAt()
    {
        _service.Save("timed", new ShaderConfig { R = 0.1f });
        var result = _service.ListPresets();
        result[0].SavedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
    }

    // -----------------------------------------------------------------------
    // Delete
    // -----------------------------------------------------------------------

    [Fact]
    public void Delete_RemovesFile()
    {
        _service.Save("doomed", new ShaderConfig { R = 0.1f });
        var path = Path.Combine(_presetsDir, "doomed.json");
        File.Exists(path).Should().BeTrue();

        _service.Delete("doomed").Should().BeTrue();
        File.Exists(path).Should().BeFalse();
    }

    [Fact]
    public void Delete_ReturnsFalse_ForNonexistent()
    {
        Directory.CreateDirectory(_presetsDir);
        _service.Delete("ghost").Should().BeFalse();
    }

    [Fact]
    public void Delete_ByUnsanitizedName()
    {
        _service.Save("night-mode", new ShaderConfig { R = 0.1f });
        _service.Delete("Night Mode").Should().BeTrue();
        File.Exists(Path.Combine(_presetsDir, "night-mode.json")).Should().BeFalse();
    }

    [Fact]
    public void Delete_ThenListEmpty()
    {
        _service.Save("only", new ShaderConfig { R = 0.1f });
        _service.Delete("only");

        _service.ListPresets().Should().BeEmpty();
    }

    // -----------------------------------------------------------------------
    // PresetExists
    // -----------------------------------------------------------------------

    [Fact]
    public void PresetExists_True_WhenSaved()
    {
        _service.Save("exists", new ShaderConfig());
        _service.PresetExists("exists").Should().BeTrue();
    }

    [Fact]
    public void PresetExists_False_WhenMissing()
    {
        Directory.CreateDirectory(_presetsDir);
        _service.PresetExists("missing").Should().BeFalse();
    }

    [Fact]
    public void PresetExists_ByUnsanitizedName()
    {
        _service.Save("my-preset", new ShaderConfig());
        _service.PresetExists("My Preset").Should().BeTrue();
    }

    [Fact]
    public void PresetExists_False_AfterDelete()
    {
        _service.Save("temp", new ShaderConfig());
        _service.Delete("temp");
        _service.PresetExists("temp").Should().BeFalse();
    }

    // -----------------------------------------------------------------------
    // Cross-process simulation
    // -----------------------------------------------------------------------

    [Fact]
    public void CrossProcess_SeparateSaveLoadSeeSameData()
    {
        var config = new ShaderConfig { R = 0.42f, Speed = 3f };
        _service.Save("shared", config);

        // Simulate second process — create a new service pointing at same dir
        var service2 = new PresetService(_logger.Object, _presetsDir);
        var loaded = service2.Load("shared");

        loaded.Should().NotBeNull();
        loaded!.R.Should().Be(0.42f);
        loaded.Speed.Should().Be(3f);
    }

    [Fact]
    public void NoCaching_SeesUpdates()
    {
        _service.Save("evolving", new ShaderConfig { R = 0.1f });
        var first = _service.Load("evolving");
        first!.R.Should().Be(0.1f);

        _service.Save("evolving", new ShaderConfig { R = 0.9f });
        var second = _service.Load("evolving");
        second!.R.Should().Be(0.9f);
    }
}
