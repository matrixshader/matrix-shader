using MatrixShader.Cli.Redpill;
using MatrixShader.Core.Models;
using Xunit;
using FluentAssertions;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for Redpill TUI — KeyHandler key-to-action mapping and ShaderConfig parameter ranges.
/// </summary>
public class RedpillTests
{
    #region Helper

    private static ConsoleKeyInfo MakeKey(char keyChar, ConsoleKey key = 0, bool shift = false, bool ctrl = false, bool alt = false)
    {
        return new ConsoleKeyInfo(keyChar, key, shift, alt, ctrl);
    }

    #endregion

    #region Special Keys

    [Fact]
    public void Tab_Maps_To_Tab()
    {
        var result = KeyHandler.ProcessKey(MakeKey('\t', ConsoleKey.Tab));
        result.Should().Be(KeyAction.Tab);
    }

    [Fact]
    public void Enter_Maps_To_Launch()
    {
        var result = KeyHandler.ProcessKey(MakeKey('\r', ConsoleKey.Enter));
        result.Should().Be(KeyAction.Launch);
    }

    [Fact]
    public void Escape_Maps_To_Quit()
    {
        var result = KeyHandler.ProcessKey(MakeKey('\x1b', ConsoleKey.Escape));
        result.Should().Be(KeyAction.Quit);
    }

    #endregion

    #region Shift Combinations (Before Lowercase Normalization)

    [Fact]
    public void ShiftL_Maps_To_LayoutCycle()
    {
        var result = KeyHandler.ProcessKey(MakeKey('L', ConsoleKey.L, shift: true));
        result.Should().Be(KeyAction.LayoutCycle);
    }

    [Fact]
    public void Lowercase_l_Maps_To_OpacityIncrease()
    {
        var result = KeyHandler.ProcessKey(MakeKey('l', ConsoleKey.L));
        result.Should().Be(KeyAction.OpacityIncrease);
    }

    [Fact]
    public void ShiftS_Maps_To_SnapbackSave()
    {
        var result = KeyHandler.ProcessKey(MakeKey('S', ConsoleKey.S, shift: true));
        result.Should().Be(KeyAction.SnapbackSave);
    }

    [Fact]
    public void Lowercase_s_Maps_To_GreenIncrease()
    {
        var result = KeyHandler.ProcessKey(MakeKey('s', ConsoleKey.S));
        result.Should().Be(KeyAction.GreenIncrease);
    }

    [Fact]
    public void ShiftR_Maps_To_SnapbackRestore()
    {
        var result = KeyHandler.ProcessKey(MakeKey('R', ConsoleKey.R, shift: true));
        result.Should().Be(KeyAction.SnapbackRestore);
    }

    [Fact]
    public void ShiftP_Maps_To_PresetMenu()
    {
        var result = KeyHandler.ProcessKey(MakeKey('P', ConsoleKey.P, shift: true));
        result.Should().Be(KeyAction.PresetMenu);
    }

    [Fact]
    public void ShiftG_Maps_To_GlitchToggle()
    {
        var result = KeyHandler.ProcessKey(MakeKey('G', ConsoleKey.G, shift: true));
        result.Should().Be(KeyAction.GlitchToggle);
    }

    [Fact]
    public void ShiftM_Maps_To_MonitorChange()
    {
        var result = KeyHandler.ProcessKey(MakeKey('M', ConsoleKey.M, shift: true));
        result.Should().Be(KeyAction.MonitorChange);
    }

    [Fact]
    public void ShiftH_Maps_To_HotkeyConfig()
    {
        var result = KeyHandler.ProcessKey(MakeKey('H', ConsoleKey.H, shift: true));
        result.Should().Be(KeyAction.HotkeyConfig);
    }

    [Fact]
    public void QuestionMark_Maps_To_Help()
    {
        var result = KeyHandler.ProcessKey(MakeKey('?', ConsoleKey.Oem2, shift: true));
        result.Should().Be(KeyAction.Help);
    }

    #endregion

    #region Color Presets (1-6)

    [Theory]
    [InlineData('1', KeyAction.PresetGreen)]
    [InlineData('2', KeyAction.PresetBlue)]
    [InlineData('3', KeyAction.PresetRed)]
    [InlineData('4', KeyAction.PresetPurple)]
    [InlineData('5', KeyAction.PresetGold)]
    [InlineData('6', KeyAction.PresetTeal)]
    public void NumberKey_Maps_To_ColorPreset(char ch, KeyAction expected)
    {
        var result = KeyHandler.ProcessKey(MakeKey(ch));
        result.Should().Be(expected);
    }

    [Fact]
    public void All_6_Presets_Have_Correct_Keys()
    {
        KeyHandler.ProcessKey(MakeKey('1')).Should().Be(KeyAction.PresetGreen);
        KeyHandler.ProcessKey(MakeKey('2')).Should().Be(KeyAction.PresetBlue);
        KeyHandler.ProcessKey(MakeKey('3')).Should().Be(KeyAction.PresetRed);
        KeyHandler.ProcessKey(MakeKey('4')).Should().Be(KeyAction.PresetPurple);
        KeyHandler.ProcessKey(MakeKey('5')).Should().Be(KeyAction.PresetGold);
        KeyHandler.ProcessKey(MakeKey('6')).Should().Be(KeyAction.PresetTeal);
    }

    #endregion

    #region RGB Keys

    [Fact]
    public void Q_Maps_To_RedDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('q')).Should().Be(KeyAction.RedDecrease);
    }

    [Fact]
    public void W_Maps_To_RedIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('w')).Should().Be(KeyAction.RedIncrease);
    }

    [Fact]
    public void A_Maps_To_GreenDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('a')).Should().Be(KeyAction.GreenDecrease);
    }

    [Fact]
    public void S_Lowercase_Maps_To_GreenIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('s')).Should().Be(KeyAction.GreenIncrease);
    }

    [Fact]
    public void Z_Maps_To_BlueDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('z')).Should().Be(KeyAction.BlueDecrease);
    }

    [Fact]
    public void X_Maps_To_BlueIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('x')).Should().Be(KeyAction.BlueIncrease);
    }

    #endregion

    #region Parameter Keys

    [Fact]
    public void E_Maps_To_SpeedDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('e')).Should().Be(KeyAction.SpeedDecrease);
    }

    [Fact]
    public void R_Lowercase_Maps_To_SpeedIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('r')).Should().Be(KeyAction.SpeedIncrease);
    }

    [Fact]
    public void D_Maps_To_GlowDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('d')).Should().Be(KeyAction.GlowDecrease);
    }

    [Fact]
    public void F_Maps_To_GlowIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('f')).Should().Be(KeyAction.GlowIncrease);
    }

    [Fact]
    public void C_Maps_To_WidthDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('c')).Should().Be(KeyAction.WidthDecrease);
    }

    [Fact]
    public void V_Maps_To_WidthIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('v')).Should().Be(KeyAction.WidthIncrease);
    }

    [Fact]
    public void T_Maps_To_TrailDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('t')).Should().Be(KeyAction.TrailDecrease);
    }

    [Fact]
    public void Y_Maps_To_TrailIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('y')).Should().Be(KeyAction.TrailIncrease);
    }

    [Fact]
    public void G_Lowercase_Maps_To_DensityDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('g')).Should().Be(KeyAction.DensityDecrease);
    }

    [Fact]
    public void H_Lowercase_Maps_To_DensityIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('h')).Should().Be(KeyAction.DensityIncrease);
    }

    #endregion

    #region Layer Toggles

    [Fact]
    public void Key7_Maps_To_Layer1Toggle()
    {
        KeyHandler.ProcessKey(MakeKey('7')).Should().Be(KeyAction.Layer1Toggle);
    }

    [Fact]
    public void Key8_Maps_To_Layer2Toggle()
    {
        KeyHandler.ProcessKey(MakeKey('8')).Should().Be(KeyAction.Layer2Toggle);
    }

    [Fact]
    public void Key9_Maps_To_Layer3Toggle()
    {
        KeyHandler.ProcessKey(MakeKey('9')).Should().Be(KeyAction.Layer3Toggle);
    }

    #endregion

    #region Opacity Keys

    [Fact]
    public void B_Maps_To_TransparencyToggle()
    {
        KeyHandler.ProcessKey(MakeKey('b')).Should().Be(KeyAction.TransparencyToggle);
    }

    [Fact]
    public void K_Maps_To_OpacityDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('k')).Should().Be(KeyAction.OpacityDecrease);
    }

    [Fact]
    public void L_Lowercase_Maps_To_OpacityIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('l')).Should().Be(KeyAction.OpacityIncrease);
    }

    #endregion

    #region Deploy Keys

    [Fact]
    public void Minus_Maps_To_LaunchDecrease()
    {
        KeyHandler.ProcessKey(MakeKey('-')).Should().Be(KeyAction.LaunchDecrease);
    }

    [Fact]
    public void Plus_Maps_To_LaunchIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('+')).Should().Be(KeyAction.LaunchIncrease);
    }

    [Fact]
    public void Equals_Maps_To_LaunchIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('=')).Should().Be(KeyAction.LaunchIncrease);
    }

    #endregion

    #region Primary Monitor Controls

    [Fact]
    public void Comma_Maps_To_PrimaryDecrease()
    {
        KeyHandler.ProcessKey(MakeKey(',')).Should().Be(KeyAction.PrimaryDecrease);
    }

    [Fact]
    public void Period_Maps_To_PrimaryIncrease()
    {
        KeyHandler.ProcessKey(MakeKey('.')).Should().Be(KeyAction.PrimaryIncrease);
    }

    [Fact]
    public void RightParen_Maps_To_PrimaryReset()
    {
        // Shift+0 produces ')' on US keyboard layout
        KeyHandler.ProcessKey(MakeKey(')')).Should().Be(KeyAction.PrimaryReset);
    }

    #endregion

    #region Reset and Save

    [Fact]
    public void Key0_Maps_To_Reset()
    {
        KeyHandler.ProcessKey(MakeKey('0')).Should().Be(KeyAction.Reset);
    }

    #endregion

    #region Unknown Keys

    [Theory]
    [InlineData(' ')]
    [InlineData('~')]
    [InlineData(';')]
    [InlineData('[')]
    [InlineData(']')]
    [InlineData('\\')]
    [InlineData('`')]
    [InlineData('/')]
    public void Unknown_Keys_Return_None(char ch)
    {
        KeyHandler.ProcessKey(MakeKey(ch)).Should().Be(KeyAction.None);
    }

    #endregion

    #region ShaderConfig Parameter Ranges

    [Fact]
    public void ShaderConfig_Speed_Range_0_1_To_5()
    {
        // ShaderConfig.IsValid checks Speed 0.1-5.0 for Redpill TUI validation
        new ShaderConfig { Speed = 0.1f }.IsValid().Should().BeTrue();
        new ShaderConfig { Speed = 5.0f }.IsValid().Should().BeTrue();
        new ShaderConfig { Speed = 0.09f }.IsValid().Should().BeFalse();
        new ShaderConfig { Speed = 5.1f }.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Glow_Range_0_2_To_3()
    {
        new ShaderConfig { Glow = 0.2f }.IsValid().Should().BeTrue();
        new ShaderConfig { Glow = 3.0f }.IsValid().Should().BeTrue();
        new ShaderConfig { Glow = 0.1f }.IsValid().Should().BeFalse();
        new ShaderConfig { Glow = 3.1f }.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Density_Range_0_2_To_1()
    {
        new ShaderConfig { Density = 0.2f }.IsValid().Should().BeTrue();
        new ShaderConfig { Density = 1.0f }.IsValid().Should().BeTrue();
        new ShaderConfig { Density = 0.1f }.IsValid().Should().BeFalse();
        new ShaderConfig { Density = 1.1f }.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Width_Range_6_To_20()
    {
        new ShaderConfig { Width = 6f }.IsValid().Should().BeTrue();
        new ShaderConfig { Width = 20f }.IsValid().Should().BeTrue();
        new ShaderConfig { Width = 5f }.IsValid().Should().BeFalse();
        new ShaderConfig { Width = 21f }.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Trail_Range_4_To_15()
    {
        new ShaderConfig { Trail = 4f }.IsValid().Should().BeTrue();
        new ShaderConfig { Trail = 15f }.IsValid().Should().BeTrue();
        new ShaderConfig { Trail = 3f }.IsValid().Should().BeFalse();
        new ShaderConfig { Trail = 16f }.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_RGB_Range_0_To_1()
    {
        new ShaderConfig { R = 0f, G = 0f, B = 0f }.IsValid().Should().BeTrue();
        new ShaderConfig { R = 1f, G = 1f, B = 1f }.IsValid().Should().BeTrue();
        new ShaderConfig { R = -0.1f }.IsValid().Should().BeFalse();
        new ShaderConfig { R = 1.1f }.IsValid().Should().BeFalse();
    }

    #endregion

    #region KeyAction Enum Coverage

    [Fact]
    public void KeyAction_Enum_Has_All_Expected_Actions()
    {
        // Ensure no action was accidentally removed
        var actions = Enum.GetValues<KeyAction>();
        actions.Should().Contain(KeyAction.PresetMenu, "Shift+P for preset management");
        actions.Should().Contain(KeyAction.GlitchToggle, "Shift+G for glitch mode");
        actions.Should().Contain(KeyAction.MonitorChange, "Shift+M for monitor change");
        actions.Should().Contain(KeyAction.HotkeyConfig, "Shift+H for hotkey config");
        actions.Should().Contain(KeyAction.LayoutCycle, "Shift+L for layout cycle");
        actions.Should().Contain(KeyAction.SnapbackSave, "Shift+S for snapback save");
        actions.Should().Contain(KeyAction.SnapbackRestore, "Shift+R for snapback restore");
        actions.Should().Contain(KeyAction.Help, "? for help");
    }

    [Fact]
    public void All_Lowercase_Letter_Keys_Are_Mapped()
    {
        // Every lowercase letter used in the TUI should map to something
        var mappedChars = "qwaszxerdftgyhcvbkl";
        foreach (var ch in mappedChars)
        {
            KeyHandler.ProcessKey(MakeKey(ch)).Should().NotBe(KeyAction.None,
                $"'{ch}' should be mapped to an action");
        }
    }

    #endregion
}
