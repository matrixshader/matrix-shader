using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Xunit;
using FluentAssertions;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for PresetService — name validation, save/load/delete flows, and listing.
/// PresetScreen UI interactions require Console and are tested conceptually through the service.
/// </summary>
public class PresetScreenTests
{
    #region Name Sanitization (tested through Save/Load roundtrip)

    private static PresetService CreateTempService(out string tempDir)
    {
        tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
        return new PresetService(logger, tempDir);
    }

    [Fact]
    public void Save_Lowercases_Name()
    {
        var service = CreateTempService(out var dir);
        try
        {
            service.Save("MyPreset", ShaderConfig.Default);
            service.Load("mypreset").Should().NotBeNull();
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Converts_Spaces_To_Dashes()
    {
        var service = CreateTempService(out var dir);
        try
        {
            service.Save("my cool preset", ShaderConfig.Default);
            service.Load("my-cool-preset").Should().NotBeNull();
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Strips_Special_Chars()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("test!@#preset", ShaderConfig.Default);
            preset.Name.Should().Be("testpreset");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Collapses_Multiple_Dashes()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("test---preset", ShaderConfig.Default);
            preset.Name.Should().Be("test-preset");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Trims_Dashes()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("---test---", ShaderConfig.Default);
            preset.Name.Should().Be("test");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Trims_Whitespace()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("  my preset  ", ShaderConfig.Default);
            preset.Name.Should().Be("my-preset");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Empty_Name_Throws()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var act = () => service.Save("", ShaderConfig.Default);
            act.Should().Throw<ArgumentException>();
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Whitespace_Only_Throws()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var act = () => service.Save("   ", ShaderConfig.Default);
            act.Should().Throw<ArgumentException>();
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Only_Special_Chars_Throws()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var act = () => service.Save("!@#$%", ShaderConfig.Default);
            act.Should().Throw<ArgumentException>();
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Numbers_Preserved_In_Name()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("preset123", ShaderConfig.Default);
            preset.Name.Should().Be("preset123");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Mixed_Case_Symbols_Sanitized()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("Blood Rain! v2", ShaderConfig.Default);
            preset.Name.Should().Be("blood-rain-v2");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    [Fact]
    public void Save_Already_Clean_Name_Unchanged()
    {
        var service = CreateTempService(out var dir);
        try
        {
            var preset = service.Save("blood-rain", ShaderConfig.Default);
            preset.Name.Should().Be("blood-rain");
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }

    #endregion

    #region PresetService Save/Load/Delete (File-System Integration)

    [Fact]
    public void Save_Creates_File()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            var config = ShaderConfig.Default;
            var preset = service.Save("test-preset", config);

            preset.Name.Should().Be("test-preset");
            File.Exists(Path.Combine(tempDir, "test-preset.json")).Should().BeTrue();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Save_Load_Roundtrip()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            var config = new ShaderConfig
            {
                R = 0.5f, G = 0.6f, B = 0.7f,
                Speed = 2.0f, Glow = 1.5f
            };
            service.Save("roundtrip", config);

            var loaded = service.Load("roundtrip");
            loaded.Should().NotBeNull();
            loaded!.R.Should().BeApproximately(0.5f, 0.001f);
            loaded.G.Should().BeApproximately(0.6f, 0.001f);
            loaded.B.Should().BeApproximately(0.7f, 0.001f);
            loaded.Speed.Should().BeApproximately(2.0f, 0.001f);
            loaded.Glow.Should().BeApproximately(1.5f, 0.001f);
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Load_Missing_Returns_Null()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            var result = service.Load("nonexistent");
            result.Should().BeNull();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Delete_Returns_True_When_Exists()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("to-delete", ShaderConfig.Default);
            service.Delete("to-delete").Should().BeTrue();
            service.Load("to-delete").Should().BeNull();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Delete_Returns_False_When_Not_Found()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Delete("nonexistent").Should().BeFalse();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ListPresets_Empty_Directory()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.ListPresets().Should().BeEmpty();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ListPresets_Returns_All_Saved()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("alpha", ShaderConfig.Default);
            service.Save("bravo", ShaderConfig.Default);
            service.Save("charlie", ShaderConfig.Default);

            var list = service.ListPresets();
            list.Should().HaveCount(3);
            list.Select(p => p.Name).Should().Contain("alpha");
            list.Select(p => p.Name).Should().Contain("bravo");
            list.Select(p => p.Name).Should().Contain("charlie");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ListPresets_Sorted_By_Date_Descending()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("first", ShaderConfig.Default);
            Thread.Sleep(50); // Ensure different SavedAt
            service.Save("second", ShaderConfig.Default);
            Thread.Sleep(50);
            service.Save("third", ShaderConfig.Default);

            var list = service.ListPresets();
            list.Should().HaveCount(3);
            list[0].Name.Should().Be("third"); // Most recent first
            list[2].Name.Should().Be("first"); // Oldest last
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void PresetExists_True_When_Saved()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("exists-test", ShaderConfig.Default);
            service.PresetExists("exists-test").Should().BeTrue();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void PresetExists_False_When_Not_Saved()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.PresetExists("nope").Should().BeFalse();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Save_Overwrites_Existing()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("overwrite-test", new ShaderConfig { Speed = 1.0f });
            service.Save("overwrite-test", new ShaderConfig { Speed = 2.5f });

            var loaded = service.Load("overwrite-test");
            loaded!.Speed.Should().BeApproximately(2.5f, 0.001f);

            // Should still be just one file
            service.ListPresets().Should().HaveCount(1);
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Save_Name_Gets_Sanitized()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("My Cool Preset!", ShaderConfig.Default);

            // Should be saved as "my-cool-preset"
            service.PresetExists("my-cool-preset").Should().BeTrue();
            service.Load("My Cool Preset!")!.Name.Should().Be("my-cool-preset");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Delete_After_Save_Removes_From_List()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("to-remove", ShaderConfig.Default);
            service.Save("to-keep", ShaderConfig.Default);

            service.ListPresets().Should().HaveCount(2);
            service.Delete("to-remove");
            service.ListPresets().Should().HaveCount(1);
            service.ListPresets()[0].Name.Should().Be("to-keep");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Load_Corrupt_File_Returns_Null()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            Directory.CreateDirectory(tempDir);
            File.WriteAllText(Path.Combine(tempDir, "corrupt.json"), "{invalid json!!!}");

            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Load("corrupt").Should().BeNull();
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ListPresets_Skips_Corrupt_Files()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_presets_{Guid.NewGuid():N}");
        try
        {
            var logger = new Microsoft.Extensions.Logging.Abstractions.NullLogger<PresetService>();
            var service = new PresetService(logger, tempDir);

            service.Save("valid-one", ShaderConfig.Default);
            // Manually create a corrupt file
            File.WriteAllText(Path.Combine(tempDir, "corrupt-entry.json"), "not json");

            var list = service.ListPresets();
            list.Should().HaveCount(1);
            list[0].Name.Should().Be("valid-one");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    #endregion

    #region ShaderPreset Model

    [Fact]
    public void ShaderPreset_Default_Values()
    {
        var preset = new ShaderPreset();
        preset.Name.Should().BeEmpty();
        preset.G.Should().BeApproximately(1f, 0.001f);
        preset.B.Should().BeApproximately(0.3f, 0.001f);
        preset.Speed.Should().BeApproximately(0.8f, 0.001f);
        preset.Layer1.Should().BeTrue();
        preset.Layer2.Should().BeTrue();
        preset.Layer3.Should().BeTrue();
    }

    [Fact]
    public void ShaderPreset_ToConfig_Preserves_All_Fields()
    {
        var preset = new ShaderPreset
        {
            Name = "test",
            R = 0.1f, G = 0.2f, B = 0.3f,
            Speed = 1.5f, Glow = 2.0f,
            Width = 15f, Trail = 10f, Density = 0.8f,
            Layer1 = false, Layer2 = true, Layer3 = false
        };

        var config = preset.ToConfig();
        config.R.Should().BeApproximately(0.1f, 0.001f);
        config.G.Should().BeApproximately(0.2f, 0.001f);
        config.B.Should().BeApproximately(0.3f, 0.001f);
        config.Speed.Should().BeApproximately(1.5f, 0.001f);
        config.Glow.Should().BeApproximately(2.0f, 0.001f);
        config.Width.Should().BeApproximately(15f, 0.001f);
        config.Trail.Should().BeApproximately(10f, 0.001f);
        config.Density.Should().BeApproximately(0.8f, 0.001f);
        config.Layer1.Should().BeFalse();
        config.Layer2.Should().BeTrue();
        config.Layer3.Should().BeFalse();
    }

    #endregion
}
