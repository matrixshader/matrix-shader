using MatrixShader.Core.Constants;
using MatrixShader.Lite;
using Xunit;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for MatrixLite — Column, TextMatrixRenderer, FallbackMenu.
/// Reference: linux/tests/test_matrixlite.py
/// </summary>
public class MatrixLiteTests
{
    // ---------------------------------------------------------------
    // Column — initialization
    // ---------------------------------------------------------------

    [Fact]
    public void Column_Init_HeadY_IsNegative()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        Assert.InRange(col.HeadY, -20, -1);
    }

    [Fact]
    public void Column_Init_IsActive()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        Assert.True(col.IsActive);
    }

    [Fact]
    public void Column_Init_TrailLength_InRange()
    {
        for (int seed = 0; seed < 20; seed++)
        {
            var rng = new Random(seed);
            var col = new Column(0, 50, rng);
            Assert.InRange(col.TrailLength, 8, 24);
        }
    }

    [Fact]
    public void Column_Init_HeadChar_IsFromCharSet()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        Assert.Contains(col.HeadChar, KatakanaChars.CharArray);
    }

    [Fact]
    public void Column_Init_XPosition_IsPreserved()
    {
        var rng = new Random(42);
        var col = new Column(7, 50, rng);
        Assert.Equal(7, col.X);
    }

    // ---------------------------------------------------------------
    // Column — update
    // ---------------------------------------------------------------

    [Fact]
    public void Column_Update_InactiveColumn_ReturnsFalse()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        // Force inactive
        var activeField = typeof(Column).GetField("_active",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        activeField!.SetValue(col, false);

        Assert.False(col.Update());
    }

    [Fact]
    public void Column_Update_Speed1_MovesHeadDown()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        // Force speed=1 and tick counter=0 so next update moves
        var speedField = typeof(Column).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var tickField = typeof(Column).GetField("_tickCounter",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        speedField!.SetValue(col, 1);
        tickField!.SetValue(col, 0);

        var oldY = col.HeadY;
        col.Update();
        Assert.Equal(oldY + 1, col.HeadY);
    }

    [Fact]
    public void Column_Update_HighSpeed_DoesNotMoveEveryTick()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        var speedField = typeof(Column).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var tickField = typeof(Column).GetField("_tickCounter",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        speedField!.SetValue(col, 3);
        tickField!.SetValue(col, 0);

        // First update — tick 1 < speed 3 → no move
        var result = col.Update();
        Assert.False(result);
    }

    [Fact]
    public void Column_BecomesInactive_WhenOffScreen()
    {
        var rng = new Random(42);
        var col = new Column(0, 10, rng);
        var speedField = typeof(Column).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var tickField = typeof(Column).GetField("_tickCounter",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var headField = typeof(Column).GetField("_headY",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        speedField!.SetValue(col, 1);

        // Set head to just past the screen + trail length
        headField!.SetValue(col, 10 + col.TrailLength);
        tickField!.SetValue(col, 0);
        col.Update();

        Assert.False(col.IsActive);
    }

    // ---------------------------------------------------------------
    // Column — brightness
    // ---------------------------------------------------------------

    [Fact]
    public void Column_GetBrightness_Head_IsNearOne()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        Assert.True(col.GetBrightness(0) > 0.9f);
    }

    [Fact]
    public void Column_GetBrightness_Tail_IsNearZero()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        var brightness = col.GetBrightness(col.TrailLength - 1);
        Assert.True(brightness < 0.1f);
    }

    [Fact]
    public void Column_GetBrightness_NegativeIndex_ReturnsZero()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        Assert.Equal(0f, col.GetBrightness(-1));
    }

    [Fact]
    public void Column_GetBrightness_BeyondTrail_ReturnsZero()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        Assert.Equal(0f, col.GetBrightness(col.TrailLength));
    }

    [Fact]
    public void Column_GetBrightness_MonotonicallyDecreasing()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        float prev = float.MaxValue;
        for (int i = 0; i < col.TrailLength; i++)
        {
            var b = col.GetBrightness(i);
            Assert.True(b <= prev, $"Brightness at {i} ({b}) should be <= previous ({prev})");
            prev = b;
        }
    }

    // ---------------------------------------------------------------
    // Column — reset
    // ---------------------------------------------------------------

    [Fact]
    public void Column_Reset_ReactivatesColumn()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        var activeField = typeof(Column).GetField("_active",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        activeField!.SetValue(col, false);

        col.Reset();
        Assert.True(col.IsActive);
    }

    [Fact]
    public void Column_Reset_SetsNegativeHeadY()
    {
        var rng = new Random(42);
        var col = new Column(0, 50, rng);
        var headField = typeof(Column).GetField("_headY",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        headField!.SetValue(col, 999);

        col.Reset();
        Assert.InRange(col.HeadY, -20, -1);
    }

    // ---------------------------------------------------------------
    // FallbackMenu — color definitions
    // ---------------------------------------------------------------

    private static FallbackMenu? TryCreateMenu()
    {
        try { return new FallbackMenu(); }
        catch (System.IO.IOException) { return null; } // No console in test runner
    }

    [Fact]
    public void FallbackMenu_DefaultColor_IsGreen()
    {
        var menu = TryCreateMenu();
        if (menu == null) return; // Skip in non-console env
        // Verify internal color is Green by checking initial state via reflection
        var colorField = typeof(FallbackMenu).GetField("_currentColor",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var color = (MatrixColor)colorField!.GetValue(menu)!;
        Assert.Equal("Green", color.Name);
    }

    [Fact]
    public void FallbackMenu_DefaultSpeed_IsOne()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var speedField = typeof(FallbackMenu).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var speed = (float)speedField!.GetValue(menu)!;
        Assert.Equal(1.0f, speed);
    }

    [Fact]
    public void FallbackMenu_DefaultDensity_Is04()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var densityField = typeof(FallbackMenu).GetField("_density",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var density = (float)densityField!.GetValue(menu)!;
        Assert.Equal(0.4f, density);
    }

    [Fact]
    public void FallbackMenu_NotAnimating_Initially()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var animField = typeof(FallbackMenu).GetField("_animationRunning",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        Assert.False((bool)animField!.GetValue(menu)!);
    }

    [Fact]
    public void FallbackMenu_UserRequestedExit_IsFalseInitially()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        Assert.False(menu.UserRequestedExit);
    }

    // ---------------------------------------------------------------
    // FallbackMenu — AdjustSpeed/AdjustDensity clamping
    // ---------------------------------------------------------------

    [Fact]
    public void FallbackMenu_AdjustSpeed_ClampsAtMinimum()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var speedField = typeof(FallbackMenu).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        speedField!.SetValue(menu, 0.1f);

        // Invoke AdjustSpeed(-0.1f)
        var adjustMethod = typeof(FallbackMenu).GetMethod("AdjustSpeed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        adjustMethod!.Invoke(menu, new object[] { -0.1f });

        var speed = (float)speedField.GetValue(menu)!;
        Assert.True(speed >= 0.1f, $"Speed {speed} should not go below 0.1");
    }

    [Fact]
    public void FallbackMenu_AdjustSpeed_ClampsAtMaximum()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var speedField = typeof(FallbackMenu).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        speedField!.SetValue(menu, 3.0f);

        var adjustMethod = typeof(FallbackMenu).GetMethod("AdjustSpeed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        adjustMethod!.Invoke(menu, new object[] { 0.1f });

        var speed = (float)speedField.GetValue(menu)!;
        Assert.True(speed <= 3.0f, $"Speed {speed} should not exceed 3.0");
    }

    [Fact]
    public void FallbackMenu_AdjustDensity_ClampsAtMinimum()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var densityField = typeof(FallbackMenu).GetField("_density",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        densityField!.SetValue(menu, 0.1f);

        var adjustMethod = typeof(FallbackMenu).GetMethod("AdjustDensity",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        adjustMethod!.Invoke(menu, new object[] { -0.1f });

        var density = (float)densityField.GetValue(menu)!;
        Assert.True(density >= 0.1f, $"Density {density} should not go below 0.1");
    }

    [Fact]
    public void FallbackMenu_AdjustDensity_ClampsAtMaximum()
    {
        var menu = TryCreateMenu();
        if (menu == null) return;
        var densityField = typeof(FallbackMenu).GetField("_density",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        densityField!.SetValue(menu, 1.0f);

        var adjustMethod = typeof(FallbackMenu).GetMethod("AdjustDensity",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        adjustMethod!.Invoke(menu, new object[] { 0.1f });

        var density = (float)densityField.GetValue(menu)!;
        Assert.True(density <= 1.0f, $"Density {density} should not exceed 1.0");
    }

    // ---------------------------------------------------------------
    // TextMatrixRenderer — speed and density clamping
    // ---------------------------------------------------------------

    [Fact]
    public void TextMatrixRenderer_SetSpeed_ClampsMinimum()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        renderer.SetSpeed(0.01f);
        var speedField = typeof(TextMatrixRenderer).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var speed = (float)speedField!.GetValue(renderer)!;
        Assert.Equal(0.1f, speed);
    }

    [Fact]
    public void TextMatrixRenderer_SetSpeed_ClampsMaximum()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        renderer.SetSpeed(10.0f);
        var speedField = typeof(TextMatrixRenderer).GetField("_speed",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var speed = (float)speedField!.GetValue(renderer)!;
        Assert.Equal(3.0f, speed);
    }

    [Fact]
    public void TextMatrixRenderer_SetDensity_ClampsMinimum()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        renderer.SetDensity(0.01f);
        var densityField = typeof(TextMatrixRenderer).GetField("_density",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var density = (float)densityField!.GetValue(renderer)!;
        Assert.Equal(0.1f, density);
    }

    [Fact]
    public void TextMatrixRenderer_SetDensity_ClampsMaximum()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        renderer.SetDensity(5.0f);
        var densityField = typeof(TextMatrixRenderer).GetField("_density",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var density = (float)densityField!.GetValue(renderer)!;
        Assert.Equal(1.0f, density);
    }

    // ---------------------------------------------------------------
    // TextMatrixRenderer — column creation
    // ---------------------------------------------------------------

    [Fact]
    public void TextMatrixRenderer_CreatesCorrectNumberOfColumns()
    {
        var renderer = new TextMatrixRenderer(15, 10);
        var colsField = typeof(TextMatrixRenderer).GetField("_columns",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var columns = (Column[])colsField!.GetValue(renderer)!;
        Assert.Equal(15, columns.Length);
    }

    [Fact]
    public void TextMatrixRenderer_SetColor_UpdatesInternalColor()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        renderer.SetColor(ColorPresets.Red);
        var colorField = typeof(TextMatrixRenderer).GetField("_color",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var color = (MatrixColor)colorField!.GetValue(renderer)!;
        Assert.Equal("Red", color.Name);
    }

    [Fact]
    public void TextMatrixRenderer_DefaultColor_IsGreen()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        var colorField = typeof(TextMatrixRenderer).GetField("_color",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var color = (MatrixColor)colorField!.GetValue(renderer)!;
        Assert.Equal("Green", color.Name);
    }

    [Fact]
    public void TextMatrixRenderer_Dispose_DoesNotThrow()
    {
        var renderer = new TextMatrixRenderer(10, 5);
        renderer.Dispose();
        // Double-dispose should also be safe
        renderer.Dispose();
    }
}
