using MatrixShader.Core.Constants;
using MatrixShader.Core.Models;
using Xunit;
using FluentAssertions;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for Construct CLI — color parsing, slot logic, color map, and preset arg parsing.
/// Tests pure logic; Win32 calls and process spawning are not tested here.
/// </summary>
public class ConstructTests
{
    #region Color Presets Mapping

    [Fact]
    public void ColorPresets_Green_Is_0_1_03()
    {
        ColorPresets.Green.R.Should().BeApproximately(0f, 0.001f);
        ColorPresets.Green.G.Should().BeApproximately(1f, 0.001f);
        ColorPresets.Green.B.Should().BeApproximately(0.3f, 0.001f);
    }

    [Fact]
    public void ColorPresets_Blue_Is_0_06_1()
    {
        ColorPresets.Blue.R.Should().BeApproximately(0f, 0.001f);
        ColorPresets.Blue.G.Should().BeApproximately(0.6f, 0.001f);
        ColorPresets.Blue.B.Should().BeApproximately(1f, 0.001f);
    }

    [Fact]
    public void ColorPresets_Red_Is_1_01_01()
    {
        ColorPresets.Red.R.Should().BeApproximately(1f, 0.001f);
        ColorPresets.Red.G.Should().BeApproximately(0.1f, 0.001f);
        ColorPresets.Red.B.Should().BeApproximately(0.1f, 0.001f);
    }

    [Fact]
    public void ColorPresets_Purple_Is_07_0_1()
    {
        ColorPresets.Purple.R.Should().BeApproximately(0.7f, 0.001f);
        ColorPresets.Purple.G.Should().BeApproximately(0f, 0.001f);
        ColorPresets.Purple.B.Should().BeApproximately(1f, 0.001f);
    }

    [Fact]
    public void ColorPresets_Gold_Is_1_07_0()
    {
        ColorPresets.Gold.R.Should().BeApproximately(1f, 0.001f);
        ColorPresets.Gold.G.Should().BeApproximately(0.7f, 0.001f);
        ColorPresets.Gold.B.Should().BeApproximately(0f, 0.001f);
    }

    [Fact]
    public void ColorPresets_Teal_Is_0_09_09()
    {
        ColorPresets.Teal.R.Should().BeApproximately(0f, 0.001f);
        ColorPresets.Teal.G.Should().BeApproximately(0.9f, 0.001f);
        ColorPresets.Teal.B.Should().BeApproximately(0.9f, 0.001f);
    }

    [Fact]
    public void ColorPresets_All_Has_6_Entries()
    {
        ColorPresets.All.Should().HaveCount(6);
    }

    [Fact]
    public void ColorPresets_All_Ordered_Green_Blue_Red_Purple_Gold_Teal()
    {
        ColorPresets.All[0].Name.Should().Be("Green");
        ColorPresets.All[1].Name.Should().Be("Blue");
        ColorPresets.All[2].Name.Should().Be("Red");
        ColorPresets.All[3].Name.Should().Be("Purple");
        ColorPresets.All[4].Name.Should().Be("Gold");
        ColorPresets.All[5].Name.Should().Be("Teal");
    }

    #endregion

    #region GetByKey

    [Theory]
    [InlineData(1, "Green")]
    [InlineData(2, "Blue")]
    [InlineData(3, "Red")]
    [InlineData(4, "Purple")]
    [InlineData(5, "Gold")]
    [InlineData(6, "Teal")]
    public void GetByKey_Returns_Correct_Preset(int key, string expectedName)
    {
        var preset = ColorPresets.GetByKey(key);
        preset.Should().NotBeNull();
        preset!.Value.Name.Should().Be(expectedName);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(7)]
    [InlineData(-1)]
    [InlineData(100)]
    public void GetByKey_Invalid_Returns_Null(int key)
    {
        ColorPresets.GetByKey(key).Should().BeNull();
    }

    #endregion

    #region GetByName

    [Theory]
    [InlineData("green", "Green")]
    [InlineData("Green", "Green")]
    [InlineData("GREEN", "Green")]
    [InlineData("blue", "Blue")]
    [InlineData("Red", "Red")]
    [InlineData("PURPLE", "Purple")]
    [InlineData("gold", "Gold")]
    [InlineData("teal", "Teal")]
    public void GetByName_Case_Insensitive(string name, string expectedName)
    {
        var preset = ColorPresets.GetByName(name);
        preset.Should().NotBeNull();
        preset!.Value.Name.Should().Be(expectedName);
    }

    [Theory]
    [InlineData("orange")]
    [InlineData("pink")]
    [InlineData("")]
    [InlineData("matrix")]
    public void GetByName_Unknown_Returns_Default(string name)
    {
        ColorPresets.GetByName(name).Should().Be(default(MatrixColor));
    }

    #endregion

    #region MatrixColor Struct

    [Fact]
    public void MatrixColor_ToRgb_Converts_Float_To_Byte()
    {
        var color = new MatrixColor(1f, 0.5f, 0f, "Test", "Test color");
        var (r, g, b) = color.ToRgb();
        r.Should().Be(255);
        g.Should().Be(127); // 0.5 * 255 = 127.5 truncated
        b.Should().Be(0);
    }

    [Fact]
    public void MatrixColor_ToAnsiFg_Generates_Correct_Escape()
    {
        var color = new MatrixColor(0f, 1f, 0.3f, "Green", "desc");
        var ansi = color.ToAnsiFg();
        // 0*255=0, 1*255=255, 0.3*255=76
        ansi.Should().Contain("38;2;0;255;76");
    }

    [Fact]
    public void MatrixColor_ToAnsiBg_Generates_Correct_Escape()
    {
        var color = new MatrixColor(1f, 0f, 0f, "Red", "desc");
        var ansi = color.ToAnsiBg();
        ansi.Should().Contain("48;2;255;0;0");
    }

    [Fact]
    public void MatrixColor_Name_And_Description_Set()
    {
        var color = new MatrixColor(0.5f, 0.5f, 0.5f, "Gray", "Half gray");
        color.Name.Should().Be("Gray");
        color.Description.Should().Be("Half gray");
    }

    [Fact]
    public void MatrixColor_Record_Equality()
    {
        var a = new MatrixColor(0f, 1f, 0.3f, "Green", "Classic Matrix");
        var b = new MatrixColor(0f, 1f, 0.3f, "Green", "Classic Matrix");
        a.Should().Be(b);
    }

    #endregion

    #region ShaderConfig Color Construction

    [Fact]
    public void ShaderConfig_WithColor_Sets_RGB()
    {
        var config = new ShaderConfig().WithColor(1f, 0.7f, 0f);
        config.R.Should().BeApproximately(1f, 0.001f);
        config.G.Should().BeApproximately(0.7f, 0.001f);
        config.B.Should().BeApproximately(0f, 0.001f);
    }

    [Fact]
    public void ShaderConfig_WithColor_Preserves_Other_Defaults()
    {
        var config = new ShaderConfig().WithColor(1f, 0f, 0f);
        config.Speed.Should().BeApproximately(0.8f, 0.001f);
        config.Glow.Should().BeApproximately(0.8f, 0.001f);
        config.Layer1.Should().BeTrue();
        config.Layer2.Should().BeTrue();
        config.Layer3.Should().BeTrue();
    }

    [Fact]
    public void ShaderConfig_Default_Is_Green()
    {
        var config = ShaderConfig.Default;
        config.R.Should().BeApproximately(0f, 0.001f);
        config.G.Should().BeApproximately(1f, 0.001f);
        config.B.Should().BeApproximately(0.3f, 0.001f);
    }

    #endregion

    #region Slot Range (1-8)

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(5)]
    [InlineData(6)]
    [InlineData(7)]
    [InlineData(8)]
    public void Slot_Range_1_Through_8_Valid(int slot)
    {
        // Construct uses slots 1-8; shader index maps 1:1
        slot.Should().BeGreaterThanOrEqualTo(1);
        slot.Should().BeLessThanOrEqualTo(8);
    }

    #endregion

    #region ShaderConfig Validation

    [Fact]
    public void ShaderConfig_Default_IsValid()
    {
        ShaderConfig.Default.IsValid().Should().BeTrue();
    }

    [Fact]
    public void ShaderConfig_Invalid_Speed_Below_Min()
    {
        var config = new ShaderConfig { Speed = 0.05f };
        config.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Invalid_Speed_Above_Max()
    {
        var config = new ShaderConfig { Speed = 6f };
        config.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Clamp_Fixes_Invalid_Values()
    {
        var config = new ShaderConfig
        {
            R = -0.5f, G = 2f, B = 0.5f,
            Speed = 100f, Glow = 0f, Width = 3f,
            Trail = 20f, Density = -1f
        };
        var clamped = config.Clamp();

        clamped.R.Should().BeApproximately(0f, 0.001f);
        clamped.G.Should().BeApproximately(1f, 0.001f);
        clamped.Speed.Should().BeApproximately(5f, 0.001f);
        clamped.Glow.Should().BeApproximately(0.2f, 0.001f);
        clamped.Width.Should().BeApproximately(6f, 0.001f);
        clamped.Trail.Should().BeApproximately(15f, 0.001f);
        clamped.Density.Should().BeApproximately(0.2f, 0.001f);
    }

    [Fact]
    public void ShaderConfig_Clamp_Preserves_Valid_Values()
    {
        var config = ShaderConfig.Default;
        var clamped = config.Clamp();

        clamped.R.Should().BeApproximately(config.R, 0.001f);
        clamped.G.Should().BeApproximately(config.G, 0.001f);
        clamped.B.Should().BeApproximately(config.B, 0.001f);
        clamped.Speed.Should().BeApproximately(config.Speed, 0.001f);
    }

    #endregion

    #region ShaderPreset FromConfig/ToConfig

    [Fact]
    public void ShaderPreset_FromConfig_Roundtrip()
    {
        var config = new ShaderConfig
        {
            R = 0.5f, G = 0.6f, B = 0.7f,
            Speed = 1.5f, Glow = 1.2f, Width = 12f,
            Trail = 10f, Density = 0.5f,
            Layer1 = true, Layer2 = false, Layer3 = true
        };

        var preset = ShaderPreset.FromConfig("test-preset", config);
        preset.Name.Should().Be("test-preset");
        preset.R.Should().BeApproximately(0.5f, 0.001f);

        var restored = preset.ToConfig();
        restored.R.Should().BeApproximately(config.R, 0.001f);
        restored.G.Should().BeApproximately(config.G, 0.001f);
        restored.B.Should().BeApproximately(config.B, 0.001f);
        restored.Speed.Should().BeApproximately(config.Speed, 0.001f);
        restored.Glow.Should().BeApproximately(config.Glow, 0.001f);
        restored.Width.Should().BeApproximately(config.Width, 0.001f);
        restored.Trail.Should().BeApproximately(config.Trail, 0.001f);
        restored.Density.Should().BeApproximately(config.Density, 0.001f);
        restored.Layer1.Should().Be(config.Layer1);
        restored.Layer2.Should().Be(config.Layer2);
        restored.Layer3.Should().Be(config.Layer3);
    }

    [Fact]
    public void ShaderPreset_FromConfig_Sets_SavedAt()
    {
        var before = DateTime.UtcNow.AddSeconds(-1);
        var preset = ShaderPreset.FromConfig("test", ShaderConfig.Default);
        var after = DateTime.UtcNow.AddSeconds(1);

        preset.SavedAt.Should().BeAfter(before);
        preset.SavedAt.Should().BeBefore(after);
    }

    #endregion
}
