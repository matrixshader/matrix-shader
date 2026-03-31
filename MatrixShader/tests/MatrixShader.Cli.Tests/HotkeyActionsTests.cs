using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using MatrixShader.Hotkeys;
using Moq;
using Xunit;
using FluentAssertions;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for HotkeyActions — speed, layer, opacity, and transparency action handlers.
/// Windows-specific Win32 calls are mocked via service interfaces.
/// </summary>
public class HotkeyActionsTests
{
    private readonly Mock<IIdentityService> _identityService = new();
    private readonly Mock<ILayoutService> _layoutService = new();
    private readonly Mock<IConfigService> _configService = new();
    private readonly Mock<IShaderService> _shaderService = new();
    private readonly Mock<ITerminalSettingsService> _terminalSettingsService = new();

    private HotkeyActions CreateActions()
    {
        return new HotkeyActions(
            _identityService.Object,
            _layoutService.Object,
            _configService.Object,
            _shaderService.Object,
            _terminalSettingsService.Object);
    }

    #region Speed Constants

    [Fact]
    public void SpeedDelta_Is_0_5()
    {
        // Speed delta verified through integration behavior:
        // HotkeyActions uses private const SpeedDelta = 0.5f
        // We verify by mocking a speed adjustment and checking the result
        var actions = CreateActions();
        var window = new WindowInfo
        {
            Handle = (nint)1,
            ShaderIndex = 1,
            ProfileName = "Matrix-1"
        };
        _identityService.Setup(s => s.FindMatrixWindows())
            .Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 1.0f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Length == 1 && a[0].Item1 == "RAIN_SPEED" && Math.Abs(a[0].Item2 - 1.5f) < 0.001f)));
    }

    [Fact]
    public void SpeedUp_Clamps_At_Max_20()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows())
            .Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 19.8f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Length == 1 && a[0].Item1 == "RAIN_SPEED" && Math.Abs(a[0].Item2 - 20.0f) < 0.001f)));
    }

    [Fact]
    public void SpeedDown_Clamps_At_Min_0_1()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows())
            .Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 0.3f });

        var handler = actions.GetHandler(HotkeyAction.SpeedDown);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Length == 1 && a[0].Item1 == "RAIN_SPEED" && Math.Abs(a[0].Item2 - 0.1f) < 0.001f)));
    }

    [Fact]
    public void SpeedDown_Decreases_By_Delta()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows())
            .Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 2.0f });

        var handler = actions.GetHandler(HotkeyAction.SpeedDown);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Length == 1 && a[0].Item1 == "RAIN_SPEED" && Math.Abs(a[0].Item2 - 1.5f) < 0.001f)));
    }

    #endregion

    #region AdjustSpeed Global Behavior

    [Fact]
    public void AdjustSpeed_Changes_All_Windows()
    {
        var actions = CreateActions();
        var windows = new List<WindowInfo>
        {
            new() { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" },
            new() { Handle = (nint)2, ShaderIndex = 2, ProfileName = "Matrix-2" },
            new() { Handle = (nint)3, ShaderIndex = 3, ProfileName = "Matrix-3" }
        };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(windows);

        var state = new MatrixState
        {
            ShaderConfigs = new Dictionary<int, ShaderConfig>
            {
                [1] = new ShaderConfig(),
                [2] = new ShaderConfig(),
                [3] = new ShaderConfig()
            }
        };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(It.IsAny<int>())).Returns(new ShaderConfig { Speed = 1.0f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.IsAny<(string, float)[]>()), Times.Once);
        _shaderService.Verify(s => s.WriteDefines(2, It.IsAny<(string, float)[]>()), Times.Once);
        _shaderService.Verify(s => s.WriteDefines(3, It.IsAny<(string, float)[]>()), Times.Once);
    }

    [Fact]
    public void AdjustSpeed_NoWindows_NoOp()
    {
        var actions = CreateActions();
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo>());

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _shaderService.Verify(s => s.WriteDefines(It.IsAny<int>(), It.IsAny<(string, float)[]>()), Times.Never);
    }

    [Fact]
    public void AdjustSpeed_Forces_Shader_Reload()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 1.0f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _terminalSettingsService.Verify(s => s.ForceShaderReload(), Times.Once);
    }

    [Fact]
    public void AdjustSpeed_Saves_State_When_Config_Changed()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 1.0f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _configService.Verify(s => s.SaveState(It.IsAny<MatrixState>()), Times.Once);
    }

    [Fact]
    public void AdjustSpeed_Only_Writes_RAIN_SPEED_Never_Color()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 1.0f, R = 0.5f, G = 0.5f, B = 0.5f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        // Must only write RAIN_SPEED, never RAIN_R/G/B
        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Length == 1 && a[0].Item1 == "RAIN_SPEED")));
    }

    [Fact]
    public void SpeedUp_Skips_Window_With_ShaderIndex_Zero()
    {
        var actions = CreateActions();
        var windows = new List<WindowInfo>
        {
            new() { Handle = (nint)1, ShaderIndex = 0, ProfileName = "Matrix-0" },
            new() { Handle = (nint)2, ShaderIndex = 1, ProfileName = "Matrix-1" }
        };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(windows);

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Speed = 1.0f });

        var handler = actions.GetHandler(HotkeyAction.SpeedUp);
        handler();

        _shaderService.Verify(s => s.WriteDefines(0, It.IsAny<(string, float)[]>()), Times.Never);
        _shaderService.Verify(s => s.WriteDefines(1, It.IsAny<(string, float)[]>()), Times.Once);
    }

    #endregion

    #region Layer Toggle Tests

    [Fact]
    public void ToggleFar_Flips_Layer1_From_On_To_Off()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Layer1 = true });

        var handler = actions.GetHandler(HotkeyAction.ToggleFar);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Any(x => x.Item1 == "SHOW_L1" && x.Item2 == 0.0f))));
    }

    [Fact]
    public void ToggleFar_Flips_Layer1_From_Off_To_On()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Layer1 = false });

        var handler = actions.GetHandler(HotkeyAction.ToggleFar);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Any(x => x.Item1 == "SHOW_L1" && x.Item2 == 1.0f))));
    }

    [Fact]
    public void ToggleMid_Writes_SHOW_L2()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Layer2 = true });

        var handler = actions.GetHandler(HotkeyAction.ToggleMid);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Any(x => x.Item1 == "SHOW_L2" && x.Item2 == 0.0f))));
    }

    [Fact]
    public void ToggleNear_Writes_SHOW_L3()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig { Layer3 = true });

        var handler = actions.GetHandler(HotkeyAction.ToggleNear);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.Any(x => x.Item1 == "SHOW_L3" && x.Item2 == 0.0f))));
    }

    [Fact]
    public void ToggleLayer_Broadcasts_To_All_Windows()
    {
        var actions = CreateActions();
        var windows = new List<WindowInfo>
        {
            new() { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" },
            new() { Handle = (nint)2, ShaderIndex = 2, ProfileName = "Matrix-2" }
        };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(windows);

        var state = new MatrixState
        {
            ShaderConfigs = new Dictionary<int, ShaderConfig>
            {
                [1] = new ShaderConfig(),
                [2] = new ShaderConfig()
            }
        };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(It.IsAny<int>())).Returns(new ShaderConfig { Layer1 = true });

        var handler = actions.GetHandler(HotkeyAction.ToggleFar);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.IsAny<(string, float)[]>()), Times.Once);
        _shaderService.Verify(s => s.WriteDefines(2, It.IsAny<(string, float)[]>()), Times.Once);
    }

    [Fact]
    public void ToggleLayer_NoWindows_NoOp()
    {
        var actions = CreateActions();
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo>());

        var handler = actions.GetHandler(HotkeyAction.ToggleFar);
        handler();

        _shaderService.Verify(s => s.WriteDefines(It.IsAny<int>(), It.IsAny<(string, float)[]>()), Times.Never);
    }

    [Fact]
    public void ToggleLayer_Only_Writes_SHOW_L_Defines_Never_Color()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig());

        var handler = actions.GetHandler(HotkeyAction.ToggleFar);
        handler();

        _shaderService.Verify(s => s.WriteDefines(1, It.Is<(string, float)[]>(
            a => a.All(x => x.Item1.StartsWith("SHOW_L")))));
    }

    [Fact]
    public void ToggleLayer_Forces_Shader_Reload()
    {
        var actions = CreateActions();
        var window = new WindowInfo { Handle = (nint)1, ShaderIndex = 1, ProfileName = "Matrix-1" };
        _identityService.Setup(s => s.FindMatrixWindows()).Returns(new List<WindowInfo> { window });

        var state = new MatrixState { ShaderConfigs = new Dictionary<int, ShaderConfig> { [1] = new ShaderConfig() } };
        _configService.Setup(s => s.LoadState()).Returns(state);
        _shaderService.Setup(s => s.ReadConfig(1)).Returns(new ShaderConfig());

        var handler = actions.GetHandler(HotkeyAction.ToggleFar);
        handler();

        _terminalSettingsService.Verify(s => s.ForceShaderReload(), Times.Once);
    }

    #endregion

    #region GetHandler Mapping

    [Theory]
    [InlineData(HotkeyAction.SwapLeft)]
    [InlineData(HotkeyAction.SwapRight)]
    [InlineData(HotkeyAction.CycleLayout)]
    [InlineData(HotkeyAction.ToggleTransparency)]
    [InlineData(HotkeyAction.OpacityDown)]
    [InlineData(HotkeyAction.OpacityUp)]
    [InlineData(HotkeyAction.SpeedUp)]
    [InlineData(HotkeyAction.SpeedDown)]
    [InlineData(HotkeyAction.ToggleFar)]
    [InlineData(HotkeyAction.ToggleMid)]
    [InlineData(HotkeyAction.ToggleNear)]
    [InlineData(HotkeyAction.ShowHelp)]
    [InlineData(HotkeyAction.ManualReload)]
    public void GetHandler_Returns_NonNull_For_All_Actions(HotkeyAction action)
    {
        var actions = CreateActions();
        var handler = actions.GetHandler(action);
        handler.Should().NotBeNull();
    }

    [Fact]
    public void GetHandler_Unknown_Action_Returns_NoOp()
    {
        var actions = CreateActions();
        var handler = actions.GetHandler((HotkeyAction)999);
        // Should not throw
        handler();
    }

    [Fact]
    public void ManualReload_Calls_ForceShaderReload()
    {
        var actions = CreateActions();
        var handler = actions.GetHandler(HotkeyAction.ManualReload);
        handler();

        _terminalSettingsService.Verify(s => s.ForceShaderReload(), Times.Once);
    }

    #endregion
}
