using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for LayoutService — layout calculations, gap scaling, mode cycling.
/// Reference: linux/tests/test_layout_engine.py
///
/// NOTE: LayoutService.CalculateLayout/ApplyLayout depend on WindowsApi.GetMonitors()
/// (P/Invoke) which can't be mocked without an interface extraction.
/// We test the testable surface: gap adjustment, mode cycling, config persistence,
/// and model validation. Layout math is covered indirectly via integration tests.
/// </summary>
public class LayoutServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ConfigService _configService;
    private readonly LayoutService _layoutService;
    private readonly Mock<ILogger<ConfigService>> _configLogger;

    public LayoutServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "MatrixShaderTests_Layout_" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(_tempDir);
        _configLogger = new Mock<ILogger<ConfigService>>();
        _configService = new ConfigService(_configLogger.Object, _tempDir);
        _layoutService = new LayoutService(_configService);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, recursive: true); } catch { }
    }

    // -----------------------------------------------------------------------
    // LayoutConfig model
    // -----------------------------------------------------------------------

    [Fact]
    public void LayoutConfig_Defaults()
    {
        var config = new LayoutConfig();
        config.Mode.Should().Be("Pillars");
        config.GapSize.Should().Be(120);
        config.GlitchEnabled.Should().BeTrue();
        config.OverlapPercent.Should().Be(5);
        config.MaxWindowsPerMonitor.Should().Be(4);
        config.MonitorCount.Should().Be(1);
    }

    [Fact]
    public void LayoutConfig_IsValid_Default()
    {
        new LayoutConfig().IsValid().Should().BeTrue();
    }

    [Fact]
    public void LayoutConfig_IsValid_InvalidGap()
    {
        var config = new LayoutConfig { GapSize = -1 };
        config.IsValid().Should().BeFalse();
    }

    [Fact]
    public void LayoutConfig_IsValid_GapTooLarge()
    {
        var config = new LayoutConfig { GapSize = 201 };
        config.IsValid().Should().BeFalse();
    }

    [Fact]
    public void LayoutConfig_IsValid_InvalidOverlap()
    {
        var config = new LayoutConfig { OverlapPercent = 25 };
        config.IsValid().Should().BeFalse();
    }

    [Fact]
    public void LayoutConfig_IsValid_EmptyMode()
    {
        var config = new LayoutConfig { Mode = "" };
        config.IsValid().Should().BeFalse();
    }

    // -----------------------------------------------------------------------
    // CycleMode
    // -----------------------------------------------------------------------

    [Fact]
    public void CycleMode_PillarsToQuads()
    {
        _layoutService.CycleMode(LayoutMode.Pillars).Should().Be(LayoutMode.Quads);
    }

    [Fact]
    public void CycleMode_QuadsToOverlap()
    {
        _layoutService.CycleMode(LayoutMode.Quads).Should().Be(LayoutMode.Overlap);
    }

    [Fact]
    public void CycleMode_OverlapToAuto()
    {
        _layoutService.CycleMode(LayoutMode.Overlap).Should().Be(LayoutMode.Auto);
    }

    [Fact]
    public void CycleMode_AutoToPillars()
    {
        _layoutService.CycleMode(LayoutMode.Auto).Should().Be(LayoutMode.Pillars);
    }

    [Fact]
    public void CycleMode_FullCycle()
    {
        var mode = LayoutMode.Pillars;
        mode = _layoutService.CycleMode(mode); // Quads
        mode = _layoutService.CycleMode(mode); // Overlap
        mode = _layoutService.CycleMode(mode); // Auto
        mode = _layoutService.CycleMode(mode); // Pillars
        mode.Should().Be(LayoutMode.Pillars);
    }

    [Fact]
    public void CycleMode_Config_UpdatesModeString()
    {
        var config = new LayoutConfig { Mode = "Pillars" };
        var next = _layoutService.CycleMode(config);
        next.Mode.Should().Be("quads");
    }

    [Fact]
    public void CycleMode_Config_PreservesOtherSettings()
    {
        var config = new LayoutConfig { Mode = "Pillars", GapSize = 80, GlitchEnabled = false };
        var next = _layoutService.CycleMode(config);
        next.GapSize.Should().Be(80);
        next.GlitchEnabled.Should().BeFalse();
    }

    // -----------------------------------------------------------------------
    // AdjustGap
    // -----------------------------------------------------------------------

    [Fact]
    public void AdjustGap_IncreasesGap()
    {
        var config = new LayoutConfig { GapSize = 40 };
        var adjusted = _layoutService.AdjustGap(config, 5);
        adjusted.GapSize.Should().Be(45);
    }

    [Fact]
    public void AdjustGap_DecreasesGap()
    {
        var config = new LayoutConfig { GapSize = 40 };
        var adjusted = _layoutService.AdjustGap(config, -5);
        adjusted.GapSize.Should().Be(35);
    }

    [Fact]
    public void AdjustGap_ClampsAtZero()
    {
        var config = new LayoutConfig { GapSize = 3 };
        var adjusted = _layoutService.AdjustGap(config, -10);
        adjusted.GapSize.Should().Be(0);
    }

    [Fact]
    public void AdjustGap_ClampsAt200()
    {
        var config = new LayoutConfig { GapSize = 198 };
        var adjusted = _layoutService.AdjustGap(config, 10);
        adjusted.GapSize.Should().Be(200);
    }

    [Fact]
    public void AdjustGap_PreservesOtherSettings()
    {
        var config = new LayoutConfig { GapSize = 40, Mode = "Quads", GlitchEnabled = false };
        var adjusted = _layoutService.AdjustGap(config, 5);
        adjusted.Mode.Should().Be("Quads");
        adjusted.GlitchEnabled.Should().BeFalse();
    }

    [Fact]
    public void AdjustGap_ZeroDelta_NoChange()
    {
        var config = new LayoutConfig { GapSize = 50 };
        _layoutService.AdjustGap(config, 0).GapSize.Should().Be(50);
    }

    // -----------------------------------------------------------------------
    // UpdateConfig — persists layout to state
    // -----------------------------------------------------------------------

    [Fact]
    public void UpdateConfig_PersistsLayout()
    {
        var config = new LayoutConfig { Mode = "Quads", GapSize = 60, GlitchEnabled = false };
        _layoutService.UpdateConfig(config);

        var loaded = _configService.LoadState();
        loaded.Layout.Mode.Should().Be("Quads");
        loaded.Layout.GapSize.Should().Be(60);
        loaded.Layout.GlitchEnabled.Should().BeFalse();
    }

    [Fact]
    public void UpdateConfig_PreservesOtherState()
    {
        // First save some state
        _configService.SaveState(new MatrixState { ActiveTab = 5, DebugEnabled = true });

        // Update layout
        var config = new LayoutConfig { Mode = "Overlap" };
        _layoutService.UpdateConfig(config);

        // Other state should be preserved
        var loaded = _configService.LoadState();
        loaded.ActiveTab.Should().Be(5);
        loaded.DebugEnabled.Should().BeTrue();
        loaded.Layout.Mode.Should().Be("Overlap");
    }

    // -----------------------------------------------------------------------
    // CalculateLayout — empty inputs
    // -----------------------------------------------------------------------

    [Fact]
    public void CalculateLayout_EmptyWindows_ReturnsEmpty()
    {
        var result = _layoutService.CalculateLayout(
            Array.Empty<WindowInfo>(),
            new LayoutConfig());
        result.Should().BeEmpty();
    }

    // -----------------------------------------------------------------------
    // AssignSlot
    // -----------------------------------------------------------------------

    [Fact]
    public void AssignSlot_FirstWindow_GetsSlot0()
    {
        var window = new WindowInfo { ShaderIndex = 1 };
        _layoutService.AssignSlot(window).Should().Be(0);
    }

    [Fact]
    public void AssignSlot_WithExistingSlots_GetsNextAvailable()
    {
        // Save state with slot 0 occupied
        var state = new MatrixState
        {
            WindowSlots = new Dictionary<string, WindowSlot>
            {
                ["Matrix-1"] = new WindowSlot { ShaderIndex = 1, SlotPosition = 0 },
            }
        };
        _configService.SaveState(state);

        var window = new WindowInfo { ShaderIndex = 2 };
        _layoutService.AssignSlot(window).Should().Be(1);
    }

    // -----------------------------------------------------------------------
    // LayoutMode enum
    // -----------------------------------------------------------------------

    [Fact]
    public void LayoutMode_HasAllExpectedValues()
    {
        Enum.GetValues<LayoutMode>().Should().HaveCount(4);
        Enum.IsDefined(LayoutMode.Pillars).Should().BeTrue();
        Enum.IsDefined(LayoutMode.Quads).Should().BeTrue();
        Enum.IsDefined(LayoutMode.Overlap).Should().BeTrue();
        Enum.IsDefined(LayoutMode.Auto).Should().BeTrue();
    }

    // -----------------------------------------------------------------------
    // WindowRect model
    // -----------------------------------------------------------------------

    [Fact]
    public void WindowRect_RightAndBottom()
    {
        var rect = new WindowRect { Left = 100, Top = 50, Width = 800, Height = 600 };
        rect.Right.Should().Be(900);
        rect.Bottom.Should().Be(650);
    }

    [Fact]
    public void WindowRect_FromLTRB()
    {
        var rect = WindowRect.FromLTRB(10, 20, 810, 620);
        rect.Left.Should().Be(10);
        rect.Top.Should().Be(20);
        rect.Width.Should().Be(800);
        rect.Height.Should().Be(600);
    }

    [Fact]
    public void WindowRect_Empty()
    {
        var empty = WindowRect.Empty;
        empty.Left.Should().Be(0);
        empty.Top.Should().Be(0);
        empty.Width.Should().Be(0);
        empty.Height.Should().Be(0);
    }

    // -----------------------------------------------------------------------
    // MonitorInfo model
    // -----------------------------------------------------------------------

    [Fact]
    public void MonitorInfo_Defaults()
    {
        var monitor = new MonitorInfo();
        monitor.Index.Should().Be(0);
        monitor.IsPrimary.Should().BeFalse();
        monitor.DpiScale.Should().Be(1f);
        monitor.DeviceName.Should().BeEmpty();
    }

    // -----------------------------------------------------------------------
    // WindowInfo model
    // -----------------------------------------------------------------------

    [Fact]
    public void WindowInfo_Defaults()
    {
        var info = new WindowInfo();
        info.ShaderIndex.Should().Be(0);
        info.ProcessId.Should().Be(0);
        info.Title.Should().BeEmpty();
        info.Source.Should().Be(IdentitySource.Unknown);
        info.Confidence.Should().Be(0);
        info.IsControlPanel.Should().BeFalse();
        info.IsConstruct.Should().BeFalse();
    }

    [Fact]
    public void IdentitySource_Confidence_LaunchTracking()
    {
        IdentitySource.LaunchTracking.GetConfidence().Should().Be(1.0);
    }

    [Fact]
    public void IdentitySource_Confidence_Title()
    {
        IdentitySource.Title.GetConfidence().Should().Be(0.70);
    }

    [Fact]
    public void IdentitySource_Confidence_Unknown()
    {
        IdentitySource.Unknown.GetConfidence().Should().Be(0.0);
    }

    // -----------------------------------------------------------------------
    // WindowSlot model
    // -----------------------------------------------------------------------

    [Fact]
    public void WindowSlot_Defaults()
    {
        var slot = new WindowSlot();
        slot.ShaderIndex.Should().Be(0);
        slot.SlotPosition.Should().Be(0);
        slot.MonitorIndex.Should().Be(0);
        slot.LastPosition.Should().BeNull();
        slot.WorkingDirectory.Should().BeNull();
    }

    // -----------------------------------------------------------------------
    // Layout config persistence roundtrip
    // -----------------------------------------------------------------------

    [Fact]
    public void LayoutConfig_SaveAndLoad_Roundtrip()
    {
        var config = new LayoutConfig
        {
            Mode = "Quads",
            GapSize = 60,
            GlitchEnabled = false,
            OverlapPercent = 10,
            MaxWindowsPerMonitor = 6,
        };
        _layoutService.UpdateConfig(config);

        var loaded = _configService.LoadState().Layout;
        loaded.Mode.Should().Be("Quads");
        loaded.GapSize.Should().Be(60);
        loaded.GlitchEnabled.Should().BeFalse();
        loaded.OverlapPercent.Should().Be(10);
        loaded.MaxWindowsPerMonitor.Should().Be(6);
    }

    [Fact]
    public void LayoutConfig_DefaultsWhenNoFile()
    {
        var state = _configService.LoadState();
        state.Layout.Mode.Should().Be("Pillars");
        state.Layout.GapSize.Should().Be(120);
        state.Layout.GlitchEnabled.Should().BeTrue();
        state.Layout.OverlapPercent.Should().Be(5);
    }
}
