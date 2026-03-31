using MatrixShader.Core.Constants;
using Xunit;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for WakeupNeo wizard flow — color presets, ANSI output, character sets.
/// Reference: linux/tests/test_wizard_polish.py
/// </summary>
public class WakeupNeoFlowTests
{
    // ---------------------------------------------------------------
    // Color preset definitions (6 presets, correct RGB values)
    // ---------------------------------------------------------------

    [Fact]
    public void ColorPresets_HasExactly6Presets()
    {
        Assert.Equal(6, ColorPresets.All.Length);
    }

    [Fact]
    public void ColorPresets_Green_CorrectRgb()
    {
        var (r, g, b) = ColorPresets.Green.ToRgb();
        Assert.Equal(0, r);
        Assert.Equal(255, g);
        Assert.Equal(76, b); // 0.3f * 255 = 76.5 -> 76
    }

    [Fact]
    public void ColorPresets_Blue_CorrectRgb()
    {
        var (r, g, b) = ColorPresets.Blue.ToRgb();
        Assert.Equal(0, r);
        Assert.Equal(153, g);
        Assert.Equal(255, b);
    }

    [Fact]
    public void ColorPresets_Red_CorrectRgb()
    {
        var (r, g, b) = ColorPresets.Red.ToRgb();
        Assert.Equal(255, r);
        Assert.Equal(25, g); // 0.1f * 255 = 25.5 -> 25
        Assert.Equal(25, b);
    }

    [Fact]
    public void ColorPresets_Purple_CorrectRgb()
    {
        var (r, g, b) = ColorPresets.Purple.ToRgb();
        Assert.Equal(178, r); // 0.7f * 255 = 178.5 -> 178
        Assert.Equal(0, g);
        Assert.Equal(255, b);
    }

    [Fact]
    public void ColorPresets_Gold_CorrectRgb()
    {
        var (r, g, b) = ColorPresets.Gold.ToRgb();
        Assert.Equal(255, r);
        Assert.Equal(178, g); // 0.7f * 255 = 178.5 -> 178
        Assert.Equal(0, b);
    }

    [Fact]
    public void ColorPresets_Teal_CorrectRgb()
    {
        var (r, g, b) = ColorPresets.Teal.ToRgb();
        Assert.Equal(0, r);
        Assert.Equal(229, g); // 0.9f * 255 = 229.5 -> 229
        Assert.Equal(229, b);
    }

    // ---------------------------------------------------------------
    // GetByName matches presets
    // ---------------------------------------------------------------

    [Theory]
    [InlineData("Green")]
    [InlineData("Blue")]
    [InlineData("Red")]
    [InlineData("Purple")]
    [InlineData("Gold")]
    [InlineData("Teal")]
    public void GetByName_FindsAllPresets(string name)
    {
        var preset = ColorPresets.GetByName(name);
        Assert.NotNull(preset);
        Assert.Equal(name, preset!.Value.Name);
    }

    [Fact]
    public void GetByName_CaseInsensitive()
    {
        Assert.NotNull(ColorPresets.GetByName("green"));
        Assert.NotNull(ColorPresets.GetByName("GREEN"));
        Assert.NotNull(ColorPresets.GetByName("gReEn"));
    }

    [Fact]
    public void GetByName_UnknownColor_ReturnsDefault()
    {
        Assert.Equal(default(MatrixColor), ColorPresets.GetByName("pink"));
        Assert.Equal(default(MatrixColor), ColorPresets.GetByName(""));
    }

    // ---------------------------------------------------------------
    // GetByKey matches presets (1-based indexing)
    // ---------------------------------------------------------------

    [Fact]
    public void GetByKey_1_ReturnsGreen()
    {
        var preset = ColorPresets.GetByKey(1);
        Assert.NotNull(preset);
        Assert.Equal("Green", preset!.Value.Name);
    }

    [Fact]
    public void GetByKey_2_ReturnsBlue()
    {
        var preset = ColorPresets.GetByKey(2);
        Assert.NotNull(preset);
        Assert.Equal("Blue", preset!.Value.Name);
    }

    [Fact]
    public void GetByKey_3_ReturnsRed()
    {
        var preset = ColorPresets.GetByKey(3);
        Assert.NotNull(preset);
        Assert.Equal("Red", preset!.Value.Name);
    }

    [Fact]
    public void GetByKey_4_ReturnsPurple()
    {
        var preset = ColorPresets.GetByKey(4);
        Assert.NotNull(preset);
        Assert.Equal("Purple", preset!.Value.Name);
    }

    [Fact]
    public void GetByKey_5_ReturnsGold()
    {
        var preset = ColorPresets.GetByKey(5);
        Assert.NotNull(preset);
        Assert.Equal("Gold", preset!.Value.Name);
    }

    [Fact]
    public void GetByKey_6_ReturnsTeal()
    {
        var preset = ColorPresets.GetByKey(6);
        Assert.NotNull(preset);
        Assert.Equal("Teal", preset!.Value.Name);
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

    // ---------------------------------------------------------------
    // MatrixColor ANSI output helpers
    // ---------------------------------------------------------------

    [Fact]
    public void MatrixColor_ToAnsiFg_ReturnsCorrectEscapeCode()
    {
        var fg = ColorPresets.Green.ToAnsiFg();
        // Green: R=0, G=255, B=76
        Assert.Contains("38;2;0;255;76", fg);
        Assert.StartsWith("\x1b[", fg);
        Assert.EndsWith("m", fg);
    }

    [Fact]
    public void MatrixColor_ToAnsiBg_ReturnsCorrectEscapeCode()
    {
        var bg = ColorPresets.Red.ToAnsiBg();
        // Red: R=255, G=25, B=25
        Assert.Contains("48;2;255;25;25", bg);
        Assert.StartsWith("\x1b[", bg);
        Assert.EndsWith("m", bg);
    }

    // ---------------------------------------------------------------
    // MatrixColor record struct
    // ---------------------------------------------------------------

    [Fact]
    public void MatrixColor_HasName()
    {
        Assert.Equal("Green", ColorPresets.Green.Name);
        Assert.Equal("Blue", ColorPresets.Blue.Name);
    }

    [Fact]
    public void MatrixColor_HasDescription()
    {
        Assert.Equal("Classic Matrix", ColorPresets.Green.Description);
        Assert.Equal("Sentinel alert", ColorPresets.Red.Description);
    }

    [Fact]
    public void MatrixColor_PresetNames_InCorrectOrder()
    {
        var names = ColorPresets.All.Select(c => c.Name).ToArray();
        Assert.Equal(new[] { "Green", "Blue", "Red", "Purple", "Gold", "Teal" }, names);
    }

    // ---------------------------------------------------------------
    // Katakana character set
    // ---------------------------------------------------------------

    [Fact]
    public void KatakanaChars_HasKatakana()
    {
        // Half-width katakana starts at U+FF66
        Assert.Equal('\uFF66', KatakanaChars.Katakana[0]);
    }

    [Fact]
    public void KatakanaChars_KatakanaLength_Is56()
    {
        Assert.Equal(56, KatakanaChars.Katakana.Length);
    }

    [Fact]
    public void KatakanaChars_LastKatakana_IsN()
    {
        Assert.Equal('\uFF9D', KatakanaChars.Katakana[^1]);
    }

    [Fact]
    public void KatakanaChars_Digits_Has10()
    {
        Assert.Equal("0123456789", KatakanaChars.Digits);
    }

    [Fact]
    public void KatakanaChars_Symbols_Has9()
    {
        Assert.Equal(9, KatakanaChars.Symbols.Length);
    }

    [Fact]
    public void KatakanaChars_AllCharacters_CombinesAll()
    {
        Assert.Equal(KatakanaChars.Katakana + KatakanaChars.Digits + KatakanaChars.Symbols,
            KatakanaChars.AllCharacters);
    }

    [Fact]
    public void KatakanaChars_TotalCount_Is75()
    {
        // 56 katakana + 10 digits + 9 symbols
        Assert.Equal(75, KatakanaChars.CharCount);
    }

    [Fact]
    public void KatakanaChars_GetRandom_ReturnsFromCharArray()
    {
        var rng = new Random(42);
        for (int i = 0; i < 100; i++)
        {
            var c = KatakanaChars.GetRandom(rng);
            Assert.Contains(c, KatakanaChars.CharArray);
        }
    }

    [Fact]
    public void KatakanaChars_GetAt_WrapsAround()
    {
        // Index 0 and CharCount should return the same character
        Assert.Equal(KatakanaChars.GetAt(0), KatakanaChars.GetAt(KatakanaChars.CharCount));
    }

    [Fact]
    public void KatakanaChars_CharArray_MatchesAllCharacters()
    {
        Assert.Equal(KatakanaChars.AllCharacters.ToCharArray(), KatakanaChars.CharArray);
    }
}
