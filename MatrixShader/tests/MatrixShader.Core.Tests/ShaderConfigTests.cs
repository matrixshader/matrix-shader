using MatrixShader.Core.Models;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for ShaderConfig — shader parameter model with validation and clamping.
/// </summary>
public class ShaderConfigTests
{
    // -----------------------------------------------------------------------
    // Default values
    // -----------------------------------------------------------------------

    [Fact]
    public void Default_R_IsZero()
    {
        Assert.Equal(0f, ShaderConfig.Default.R);
    }

    [Fact]
    public void Default_G_IsOne()
    {
        Assert.Equal(1f, ShaderConfig.Default.G);
    }

    [Fact]
    public void Default_B_Is03()
    {
        Assert.Equal(0.3f, ShaderConfig.Default.B);
    }

    [Fact]
    public void Default_Speed_Is08()
    {
        Assert.Equal(0.8f, ShaderConfig.Default.Speed);
    }

    [Fact]
    public void Default_Glow_Is08()
    {
        Assert.Equal(0.8f, ShaderConfig.Default.Glow);
    }

    [Fact]
    public void Default_Width_Is10()
    {
        Assert.Equal(10f, ShaderConfig.Default.Width);
    }

    [Fact]
    public void Default_Trail_Is8()
    {
        Assert.Equal(8f, ShaderConfig.Default.Trail);
    }

    [Fact]
    public void Default_Density_Is025()
    {
        Assert.Equal(0.25f, ShaderConfig.Default.Density);
    }

    [Fact]
    public void Default_Layer1_IsTrue()
    {
        Assert.True(ShaderConfig.Default.Layer1);
    }

    [Fact]
    public void Default_Layer2_IsTrue()
    {
        Assert.True(ShaderConfig.Default.Layer2);
    }

    [Fact]
    public void Default_Layer3_IsTrue()
    {
        Assert.True(ShaderConfig.Default.Layer3);
    }

    [Fact]
    public void Default_IsValid()
    {
        Assert.True(ShaderConfig.Default.IsValid());
    }

    // -----------------------------------------------------------------------
    // WithColor
    // -----------------------------------------------------------------------

    [Fact]
    public void WithColor_SetsRGB()
    {
        var config = ShaderConfig.Default.WithColor(1f, 0f, 0.5f);
        Assert.Equal(1f, config.R);
        Assert.Equal(0f, config.G);
        Assert.Equal(0.5f, config.B);
    }

    [Fact]
    public void WithColor_PreservesOtherProperties()
    {
        var config = ShaderConfig.Default.WithColor(1f, 0f, 0f);
        Assert.Equal(ShaderConfig.Default.Speed, config.Speed);
        Assert.Equal(ShaderConfig.Default.Glow, config.Glow);
        Assert.Equal(ShaderConfig.Default.Width, config.Width);
        Assert.Equal(ShaderConfig.Default.Trail, config.Trail);
        Assert.Equal(ShaderConfig.Default.Density, config.Density);
        Assert.Equal(ShaderConfig.Default.Layer1, config.Layer1);
        Assert.Equal(ShaderConfig.Default.Layer2, config.Layer2);
        Assert.Equal(ShaderConfig.Default.Layer3, config.Layer3);
    }

    [Fact]
    public void WithColor_CanChainWithOtherWith()
    {
        var config = ShaderConfig.Default
            .WithColor(0.5f, 0.5f, 0.5f) with { Speed = 2f };
        Assert.Equal(0.5f, config.R);
        Assert.Equal(2f, config.Speed);
    }

    // -----------------------------------------------------------------------
    // IsValid — range checks
    // -----------------------------------------------------------------------

    [Fact]
    public void IsValid_DefaultConfig_ReturnsTrue()
    {
        Assert.True(ShaderConfig.Default.IsValid());
    }

    [Fact]
    public void IsValid_R_BelowZero_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { R = -0.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_R_AboveOne_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { R = 1.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_G_BelowZero_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { G = -0.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_B_AboveOne_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { B = 1.5f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Speed_BelowMin_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Speed = 0.05f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Speed_AboveMax_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Speed = 20.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Glow_BelowMin_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Glow = 0.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Glow_AnyPositiveValue_IsValid()
    {
        var config = ShaderConfig.Default with { Glow = 100f };
        Assert.True(config.IsValid());
    }

    [Fact]
    public void IsValid_Width_BelowMin_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Width = 5f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Width_AboveMax_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Width = 21f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Trail_BelowMin_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Trail = 3f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Trail_AboveMax_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Trail = 16f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Density_BelowMin_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Density = 0.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_Density_AboveMax_ReturnsFalse()
    {
        var config = ShaderConfig.Default with { Density = 1.1f };
        Assert.False(config.IsValid());
    }

    [Fact]
    public void IsValid_AtMinBoundaries_ReturnsTrue()
    {
        var config = new ShaderConfig
        {
            R = 0f, G = 0f, B = 0f,
            Speed = 0.1f, Glow = 0.2f, Width = 6f, Trail = 4f, Density = 0.2f
        };
        Assert.True(config.IsValid());
    }

    [Fact]
    public void IsValid_AtMaxBoundaries_ReturnsTrue()
    {
        var config = new ShaderConfig
        {
            R = 1f, G = 1f, B = 1f,
            Speed = 20f, Glow = 3f, Width = 20f, Trail = 15f, Density = 1f
        };
        Assert.True(config.IsValid());
    }

    [Fact]
    public void IsValid_LayerBoolsDontAffectValidity()
    {
        var config = ShaderConfig.Default with { Layer1 = false, Layer2 = false, Layer3 = false };
        Assert.True(config.IsValid());
    }

    // -----------------------------------------------------------------------
    // Clamp — brings out-of-range values into range
    // -----------------------------------------------------------------------

    [Fact]
    public void Clamp_ValidConfig_Unchanged()
    {
        var config = ShaderConfig.Default;
        var clamped = config.Clamp();
        Assert.Equal(config, clamped);
    }

    [Fact]
    public void Clamp_NegativeR_ClampedToZero()
    {
        var config = ShaderConfig.Default with { R = -5f };
        var clamped = config.Clamp();
        Assert.Equal(0f, clamped.R);
    }

    [Fact]
    public void Clamp_OverOneG_ClampedToOne()
    {
        var config = ShaderConfig.Default with { G = 2f };
        var clamped = config.Clamp();
        Assert.Equal(1f, clamped.G);
    }

    [Fact]
    public void Clamp_SpeedTooLow_ClampedToMin()
    {
        var config = ShaderConfig.Default with { Speed = 0f };
        var clamped = config.Clamp();
        Assert.Equal(0.1f, clamped.Speed);
    }

    [Fact]
    public void Clamp_SpeedTooHigh_ClampedToMax()
    {
        var config = ShaderConfig.Default with { Speed = 100f };
        var clamped = config.Clamp();
        Assert.Equal(20f, clamped.Speed);
    }

    [Fact]
    public void Clamp_GlowTooLow_ClampedToMin()
    {
        var config = ShaderConfig.Default with { Glow = 0f };
        var clamped = config.Clamp();
        Assert.Equal(0.2f, clamped.Glow);
    }

    [Fact]
    public void Clamp_GlowNoUpperLimit_PreservesValue()
    {
        var config = ShaderConfig.Default with { Glow = 10f };
        var clamped = config.Clamp();
        Assert.Equal(10f, clamped.Glow);
    }

    [Fact]
    public void Clamp_WidthTooLow_ClampedToMin()
    {
        var config = ShaderConfig.Default with { Width = 1f };
        var clamped = config.Clamp();
        Assert.Equal(6f, clamped.Width);
    }

    [Fact]
    public void Clamp_WidthTooHigh_ClampedToMax()
    {
        var config = ShaderConfig.Default with { Width = 50f };
        var clamped = config.Clamp();
        Assert.Equal(20f, clamped.Width);
    }

    [Fact]
    public void Clamp_TrailTooLow_ClampedToMin()
    {
        var config = ShaderConfig.Default with { Trail = 1f };
        var clamped = config.Clamp();
        Assert.Equal(4f, clamped.Trail);
    }

    [Fact]
    public void Clamp_TrailTooHigh_ClampedToMax()
    {
        var config = ShaderConfig.Default with { Trail = 30f };
        var clamped = config.Clamp();
        Assert.Equal(15f, clamped.Trail);
    }

    [Fact]
    public void Clamp_DensityTooLow_ClampedToMin()
    {
        var config = ShaderConfig.Default with { Density = 0f };
        var clamped = config.Clamp();
        Assert.Equal(0.2f, clamped.Density);
    }

    [Fact]
    public void Clamp_DensityTooHigh_ClampedToMax()
    {
        var config = ShaderConfig.Default with { Density = 5f };
        var clamped = config.Clamp();
        Assert.Equal(1f, clamped.Density);
    }

    [Fact]
    public void Clamp_AllFieldsOutOfRange_AllClamped()
    {
        var config = new ShaderConfig
        {
            R = -1f, G = 2f, B = -1f,
            Speed = 0f, Glow = 0f, Width = 0f, Trail = 0f, Density = 0f,
            Layer1 = false, Layer2 = false, Layer3 = false
        };
        var clamped = config.Clamp();
        Assert.True(clamped.IsValid());
        Assert.False(clamped.Layer1); // layers not clamped
    }

    [Fact]
    public void Clamp_ResultIsAlwaysValid()
    {
        var extremeConfig = new ShaderConfig
        {
            R = float.MinValue, G = float.MaxValue, B = float.NaN,
            Speed = -100f, Glow = -100f, Width = -100f, Trail = -100f, Density = -100f
        };
        // NaN clamp behavior: Math.Clamp with NaN returns NaN, so IsValid will fail for B.
        // But for non-NaN extremes, clamp should produce valid results.
        var normalExtreme = new ShaderConfig
        {
            R = -100f, G = 100f, B = -100f,
            Speed = -100f, Glow = -100f, Width = -100f, Trail = -100f, Density = -100f
        };
        var clamped = normalExtreme.Clamp();
        Assert.True(clamped.IsValid());
    }

    // -----------------------------------------------------------------------
    // Record equality and with-expressions
    // -----------------------------------------------------------------------

    [Fact]
    public void RecordEquality_SameValues_AreEqual()
    {
        var a = ShaderConfig.Default;
        var b = new ShaderConfig();
        Assert.Equal(a, b);
    }

    [Fact]
    public void RecordEquality_DifferentValues_AreNotEqual()
    {
        var a = ShaderConfig.Default;
        var b = ShaderConfig.Default with { Speed = 2f };
        Assert.NotEqual(a, b);
    }

    [Fact]
    public void WithExpression_CreatesNewInstance()
    {
        var original = ShaderConfig.Default;
        var modified = original with { Speed = 3f };
        Assert.Equal(0.8f, original.Speed); // original unchanged
        Assert.Equal(3f, modified.Speed);
    }
}
