using MatrixShader.Core.Constants;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for ColorPresets — the 6 Matrix-themed color presets.
/// </summary>
public class ColorPresetsTests
{
    // -----------------------------------------------------------------------
    // All collection
    // -----------------------------------------------------------------------

    [Fact]
    public void All_HasSixPresets()
    {
        Assert.Equal(6, ColorPresets.All.Length);
    }

    [Fact]
    public void All_ContainsGreenFirst()
    {
        Assert.Equal("Green", ColorPresets.All[0].Name);
    }

    [Fact]
    public void All_ContainsTealLast()
    {
        Assert.Equal("Teal", ColorPresets.All[5].Name);
    }

    [Fact]
    public void All_OrderIsGreenBlueRedPurpleGoldTeal()
    {
        var names = ColorPresets.All.Select(c => c.Name).ToArray();
        Assert.Equal(new[] { "Green", "Blue", "Red", "Purple", "Gold", "Teal" }, names);
    }

    [Fact]
    public void All_AllNamesAreUnique()
    {
        var names = ColorPresets.All.Select(c => c.Name).ToArray();
        Assert.Equal(names.Length, names.Distinct().Count());
    }

    [Fact]
    public void All_AllDescriptionsAreNonEmpty()
    {
        foreach (var color in ColorPresets.All)
        {
            Assert.False(string.IsNullOrWhiteSpace(color.Description),
                $"Color {color.Name} has empty description");
        }
    }

    // -----------------------------------------------------------------------
    // GetByKey (1-indexed)
    // -----------------------------------------------------------------------

    [Fact]
    public void GetByKey_1_ReturnsGreen()
    {
        var color = ColorPresets.GetByKey(1);
        Assert.NotNull(color);
        Assert.Equal("Green", color.Value.Name);
    }

    [Fact]
    public void GetByKey_2_ReturnsBlue()
    {
        var color = ColorPresets.GetByKey(2);
        Assert.NotNull(color);
        Assert.Equal("Blue", color.Value.Name);
    }

    [Fact]
    public void GetByKey_3_ReturnsRed()
    {
        var color = ColorPresets.GetByKey(3);
        Assert.NotNull(color);
        Assert.Equal("Red", color.Value.Name);
    }

    [Fact]
    public void GetByKey_4_ReturnsPurple()
    {
        var color = ColorPresets.GetByKey(4);
        Assert.NotNull(color);
        Assert.Equal("Purple", color.Value.Name);
    }

    [Fact]
    public void GetByKey_5_ReturnsGold()
    {
        var color = ColorPresets.GetByKey(5);
        Assert.NotNull(color);
        Assert.Equal("Gold", color.Value.Name);
    }

    [Fact]
    public void GetByKey_6_ReturnsTeal()
    {
        var color = ColorPresets.GetByKey(6);
        Assert.NotNull(color);
        Assert.Equal("Teal", color.Value.Name);
    }

    [Fact]
    public void GetByKey_0_ReturnsNull()
    {
        Assert.Null(ColorPresets.GetByKey(0));
    }

    [Fact]
    public void GetByKey_7_ReturnsNull()
    {
        Assert.Null(ColorPresets.GetByKey(7));
    }

    [Fact]
    public void GetByKey_Negative_ReturnsNull()
    {
        Assert.Null(ColorPresets.GetByKey(-1));
    }

    [Fact]
    public void GetByKey_LargeNumber_ReturnsNull()
    {
        Assert.Null(ColorPresets.GetByKey(100));
    }

    // -----------------------------------------------------------------------
    // GetByName (case-insensitive)
    // -----------------------------------------------------------------------

    [Fact]
    public void GetByName_ExactCase_ReturnsPreset()
    {
        var color = ColorPresets.GetByName("Green");
        Assert.NotNull(color);
        Assert.Equal("Green", color.Value.Name);
    }

    [Fact]
    public void GetByName_Lowercase_ReturnsPreset()
    {
        var color = ColorPresets.GetByName("green");
        Assert.NotNull(color);
        Assert.Equal("Green", color.Value.Name);
    }

    [Fact]
    public void GetByName_Uppercase_ReturnsPreset()
    {
        var color = ColorPresets.GetByName("GREEN");
        Assert.NotNull(color);
        Assert.Equal("Green", color.Value.Name);
    }

    [Fact]
    public void GetByName_MixedCase_ReturnsPreset()
    {
        var color = ColorPresets.GetByName("gReEn");
        Assert.NotNull(color);
        Assert.Equal("Green", color.Value.Name);
    }

    [Fact]
    public void GetByName_AllPresetsFoundByName()
    {
        foreach (var preset in ColorPresets.All)
        {
            var found = ColorPresets.GetByName(preset.Name);
            Assert.NotNull(found);
            Assert.Equal(preset.Name, found.Value.Name);
        }
    }

    [Fact]
    public void GetByName_NotFound_ReturnsDefault()
    {
        // MatrixColor is a record struct — FirstOrDefault returns default(MatrixColor),
        // not null. The default struct has null Name/Description and zeroed RGB.
        var result = ColorPresets.GetByName("Orange");
        Assert.NotNull(result);
        Assert.Null(result.Value.Name);
        Assert.Equal(0f, result.Value.R);
        Assert.Equal(0f, result.Value.G);
        Assert.Equal(0f, result.Value.B);
    }

    [Fact]
    public void GetByName_EmptyString_ReturnsDefault()
    {
        var result = ColorPresets.GetByName("");
        Assert.NotNull(result);
        Assert.Null(result.Value.Name);
    }

    // -----------------------------------------------------------------------
    // ToRgb conversion
    // -----------------------------------------------------------------------

    [Fact]
    public void Green_ToRgb_IsCorrect()
    {
        var (r, g, b) = ColorPresets.Green.ToRgb();
        Assert.Equal(0, r);     // 0.0 * 255 = 0
        Assert.Equal(255, g);   // 1.0 * 255 = 255
        Assert.Equal(76, b);    // 0.3 * 255 = 76 (truncated to byte)
    }

    [Fact]
    public void Blue_ToRgb_IsCorrect()
    {
        var (r, g, b) = ColorPresets.Blue.ToRgb();
        Assert.Equal(0, r);     // 0.0 * 255 = 0
        Assert.Equal(153, g);   // 0.6 * 255 = 153
        Assert.Equal(255, b);   // 1.0 * 255 = 255
    }

    [Fact]
    public void Red_ToRgb_IsCorrect()
    {
        var (r, g, b) = ColorPresets.Red.ToRgb();
        Assert.Equal(255, r);   // 1.0 * 255 = 255
        Assert.Equal(25, g);    // 0.1 * 255 = 25
        Assert.Equal(25, b);    // 0.1 * 255 = 25
    }

    [Fact]
    public void Purple_ToRgb_IsCorrect()
    {
        var (r, g, b) = ColorPresets.Purple.ToRgb();
        Assert.Equal(178, r);   // 0.7 * 255 = 178
        Assert.Equal(0, g);     // 0.0 * 255 = 0
        Assert.Equal(255, b);   // 1.0 * 255 = 255
    }

    [Fact]
    public void Gold_ToRgb_IsCorrect()
    {
        var (r, g, b) = ColorPresets.Gold.ToRgb();
        Assert.Equal(255, r);   // 1.0 * 255 = 255
        Assert.Equal(178, g);   // 0.7 * 255 = 178
        Assert.Equal(0, b);     // 0.0 * 255 = 0
    }

    [Fact]
    public void Teal_ToRgb_IsCorrect()
    {
        var (r, g, b) = ColorPresets.Teal.ToRgb();
        Assert.Equal(0, r);     // 0.0 * 255 = 0
        Assert.Equal(229, g);   // 0.9 * 255 = 229
        Assert.Equal(229, b);   // 0.9 * 255 = 229
    }

    [Fact]
    public void ToRgb_AllComponentsInByteRange()
    {
        foreach (var color in ColorPresets.All)
        {
            var (r, g, b) = color.ToRgb();
            Assert.InRange(r, (byte)0, (byte)255);
            Assert.InRange(g, (byte)0, (byte)255);
            Assert.InRange(b, (byte)0, (byte)255);
        }
    }

    // -----------------------------------------------------------------------
    // ToAnsiFg format
    // -----------------------------------------------------------------------

    [Fact]
    public void Green_ToAnsiFg_CorrectFormat()
    {
        var ansi = ColorPresets.Green.ToAnsiFg();
        Assert.Equal("\x1b[38;2;0;255;76m", ansi);
    }

    [Fact]
    public void Blue_ToAnsiFg_CorrectFormat()
    {
        var ansi = ColorPresets.Blue.ToAnsiFg();
        Assert.Equal("\x1b[38;2;0;153;255m", ansi);
    }

    [Fact]
    public void Red_ToAnsiFg_CorrectFormat()
    {
        var ansi = ColorPresets.Red.ToAnsiFg();
        Assert.Equal("\x1b[38;2;255;25;25m", ansi);
    }

    [Fact]
    public void ToAnsiFg_StartsWithEscapeSequence()
    {
        foreach (var color in ColorPresets.All)
        {
            var ansi = color.ToAnsiFg();
            Assert.StartsWith("\x1b[38;2;", ansi);
            Assert.EndsWith("m", ansi);
        }
    }

    [Fact]
    public void ToAnsiBg_StartsWithEscapeSequence()
    {
        foreach (var color in ColorPresets.All)
        {
            var ansi = color.ToAnsiBg();
            Assert.StartsWith("\x1b[48;2;", ansi);
            Assert.EndsWith("m", ansi);
        }
    }

    // -----------------------------------------------------------------------
    // MatrixColor record struct
    // -----------------------------------------------------------------------

    [Fact]
    public void MatrixColor_RecordEquality()
    {
        var a = new MatrixColor(0f, 1f, 0.3f, "Green", "Classic Matrix");
        var b = new MatrixColor(0f, 1f, 0.3f, "Green", "Classic Matrix");
        Assert.Equal(a, b);
    }

    [Fact]
    public void MatrixColor_DifferentColors_NotEqual()
    {
        Assert.NotEqual(ColorPresets.Green, ColorPresets.Blue);
    }

    // -----------------------------------------------------------------------
    // Individual preset RGB values
    // -----------------------------------------------------------------------

    [Fact]
    public void Green_RgbFloats_AreCorrect()
    {
        Assert.Equal(0f, ColorPresets.Green.R);
        Assert.Equal(1f, ColorPresets.Green.G);
        Assert.Equal(0.3f, ColorPresets.Green.B);
    }

    [Fact]
    public void Blue_RgbFloats_AreCorrect()
    {
        Assert.Equal(0f, ColorPresets.Blue.R);
        Assert.Equal(0.6f, ColorPresets.Blue.G);
        Assert.Equal(1f, ColorPresets.Blue.B);
    }

    [Fact]
    public void Red_RgbFloats_AreCorrect()
    {
        Assert.Equal(1f, ColorPresets.Red.R);
        Assert.Equal(0.1f, ColorPresets.Red.G);
        Assert.Equal(0.1f, ColorPresets.Red.B);
    }

    [Fact]
    public void AllFloatValues_InZeroToOneRange()
    {
        foreach (var color in ColorPresets.All)
        {
            Assert.InRange(color.R, 0f, 1f);
            Assert.InRange(color.G, 0f, 1f);
            Assert.InRange(color.B, 0f, 1f);
        }
    }
}
