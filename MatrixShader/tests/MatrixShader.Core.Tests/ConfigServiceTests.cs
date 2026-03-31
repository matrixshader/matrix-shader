using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for ConfigService — state persistence, first-run detection.
/// Reference: linux/tests/test_state_service.py
/// </summary>
public class ConfigServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ConfigService _service;
    private readonly Mock<ILogger<ConfigService>> _logger;

    public ConfigServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "MatrixShaderTests_Config_" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(_tempDir);
        _logger = new Mock<ILogger<ConfigService>>();
        _service = new ConfigService(_logger.Object, _tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, recursive: true); } catch { }
    }

    // -----------------------------------------------------------------------
    // LoadState — returns defaults when no file
    // -----------------------------------------------------------------------

    [Fact]
    public void LoadState_ReturnsDefaults_WhenNoFile()
    {
        var state = _service.LoadState();

        state.ActiveTab.Should().Be(1);
        state.ShaderConfigs.Should().HaveCount(8);
        state.Layout.Should().NotBeNull();
        state.RenderMode.Should().Be(RenderMode.Full);
        state.DebugEnabled.Should().BeFalse();
    }

    [Fact]
    public void LoadState_DefaultShaderConfigs_AreInitialized()
    {
        var state = _service.LoadState();

        // Default constructor creates 8 empty slots
        for (int i = 1; i <= 8; i++)
        {
            state.ShaderConfigs.Should().ContainKey(i);
            state.ShaderConfigs[i].G.Should().Be(1f); // ShaderConfig default G=1
        }
    }

    [Fact]
    public void LoadState_DefaultLayoutConfig()
    {
        var state = _service.LoadState();

        state.Layout.Mode.Should().Be("Pillars");
        state.Layout.GlitchEnabled.Should().BeTrue();
        state.Layout.GapSize.Should().Be(120);
    }

    // -----------------------------------------------------------------------
    // SaveState + LoadState — roundtrip
    // -----------------------------------------------------------------------

    [Fact]
    public void SaveState_ThenLoadState_Roundtrips()
    {
        var original = new MatrixState
        {
            ActiveTab = 3,
            ShaderConfigs = new Dictionary<int, ShaderConfig>
            {
                [1] = new ShaderConfig { R = 0.5f, G = 0.5f, B = 0.5f },
                [2] = new ShaderConfig(),
                [3] = new ShaderConfig(),
                [4] = new ShaderConfig(),
                [5] = new ShaderConfig(),
                [6] = new ShaderConfig(),
                [7] = new ShaderConfig(),
                [8] = new ShaderConfig(),
            },
            Layout = new LayoutConfig { Mode = "Quads", GapSize = 60 },
            RenderMode = RenderMode.Lite,
            DebugEnabled = true,
        };
        _service.SaveState(original);

        var loaded = _service.LoadState();
        loaded.ActiveTab.Should().Be(3);
        loaded.ShaderConfigs[1].R.Should().Be(0.5f);
        loaded.Layout.Mode.Should().Be("Quads");
        loaded.Layout.GapSize.Should().Be(60);
        loaded.RenderMode.Should().Be(RenderMode.Lite);
        loaded.DebugEnabled.Should().BeTrue();
    }

    [Fact]
    public void SaveState_CreatesDirectory_WhenMissing()
    {
        var nestedDir = Path.Combine(_tempDir, "deep", "nested");
        var nestedService = new ConfigService(_logger.Object, nestedDir);

        nestedService.SaveState(new MatrixState());

        File.Exists(nestedService.StatePath).Should().BeTrue();
    }

    [Fact]
    public void SaveState_UpdatesLastModifiedTimestamp()
    {
        var state = new MatrixState();
        var beforeSave = DateTime.UtcNow.AddSeconds(-1);
        _service.SaveState(state);

        var loaded = _service.LoadState();
        loaded.LastModified.Should().BeAfter(beforeSave);
    }

    // -----------------------------------------------------------------------
    // Corrupt file handling
    // -----------------------------------------------------------------------

    [Fact]
    public void LoadState_ReturnsDefaults_ForCorruptJson()
    {
        File.WriteAllText(_service.StatePath, "{{{{not json!!");
        var state = _service.LoadState();

        state.ActiveTab.Should().Be(1);
        state.ShaderConfigs.Should().HaveCount(8);
    }

    [Fact]
    public void LoadState_ReturnsDefaults_ForEmptyFile()
    {
        File.WriteAllText(_service.StatePath, "");
        var state = _service.LoadState();

        state.ActiveTab.Should().Be(1);
    }

    // -----------------------------------------------------------------------
    // IsFirstRun
    // -----------------------------------------------------------------------

    [Fact]
    public void IsFirstRun_True_WhenNoStateFile()
    {
        _service.IsFirstRun.Should().BeTrue();
    }

    [Fact]
    public void IsFirstRun_False_AfterSave()
    {
        _service.SaveState(new MatrixState());
        _service.IsFirstRun.Should().BeFalse();
    }

    // -----------------------------------------------------------------------
    // StateExists
    // -----------------------------------------------------------------------

    [Fact]
    public void StateExists_False_Initially()
    {
        _service.StateExists.Should().BeFalse();
    }

    [Fact]
    public void StateExists_True_AfterSave()
    {
        _service.SaveState(new MatrixState());
        _service.StateExists.Should().BeTrue();
    }

    // -----------------------------------------------------------------------
    // StatePath
    // -----------------------------------------------------------------------

    [Fact]
    public void StatePath_EndsWithExpectedFilename()
    {
        _service.StatePath.Should().EndWith("matrix_state.json");
    }

    [Fact]
    public void StatePath_IsInConfigDir()
    {
        _service.StatePath.Should().StartWith(_tempDir);
    }

    // -----------------------------------------------------------------------
    // ResetState
    // -----------------------------------------------------------------------

    [Fact]
    public void ResetState_OverwritesSavedState()
    {
        var modified = new MatrixState { ActiveTab = 5, DebugEnabled = true };
        _service.SaveState(modified);

        var reset = _service.ResetState();
        reset.ActiveTab.Should().Be(1);
        reset.DebugEnabled.Should().BeFalse();

        // Verify it persisted
        var loaded = _service.LoadState();
        loaded.ActiveTab.Should().Be(1);
    }

    [Fact]
    public void ResetState_SetsIsFirstRunFalse()
    {
        _service.ResetState();
        _service.IsFirstRun.Should().BeFalse();
    }

    // -----------------------------------------------------------------------
    // ShaderConfig defaults
    // -----------------------------------------------------------------------

    [Fact]
    public void ShaderConfig_DefaultValues()
    {
        var config = new ShaderConfig();
        config.R.Should().Be(0f);
        config.G.Should().Be(1f);
        config.B.Should().BeApproximately(0.3f, 0.001f);
        config.Speed.Should().BeApproximately(0.8f, 0.001f);
        config.Glow.Should().BeApproximately(0.8f, 0.001f);
        config.Width.Should().Be(10f);
        config.Trail.Should().Be(8f);
        config.Density.Should().BeApproximately(0.25f, 0.001f);
        config.Layer1.Should().BeTrue();
        config.Layer2.Should().BeTrue();
        config.Layer3.Should().BeTrue();
    }

    [Fact]
    public void ShaderConfig_WithColor_CreatesNew()
    {
        var original = new ShaderConfig();
        var colored = original.WithColor(1f, 0f, 0f);

        colored.R.Should().Be(1f);
        colored.G.Should().Be(0f);
        colored.B.Should().Be(0f);
        // Other params preserved
        colored.Speed.Should().Be(original.Speed);
    }

    [Fact]
    public void ShaderConfig_IsValid_Default()
    {
        new ShaderConfig().IsValid().Should().BeTrue();
    }

    [Fact]
    public void ShaderConfig_IsValid_OutOfRange()
    {
        var bad = new ShaderConfig { R = 2f }; // Out of range
        bad.IsValid().Should().BeFalse();
    }

    [Fact]
    public void ShaderConfig_Clamp_BringsIntoRange()
    {
        var bad = new ShaderConfig { R = 2f, Speed = 100f, Width = 0f };
        var clamped = bad.Clamp();
        clamped.R.Should().Be(1f);
        clamped.Speed.Should().Be(5f);
        clamped.Width.Should().Be(6f);
        clamped.IsValid().Should().BeTrue();
    }

    // -----------------------------------------------------------------------
    // MatrixState record semantics
    // -----------------------------------------------------------------------

    [Fact]
    public void MatrixState_DefaultOsdToastEnabled()
    {
        new MatrixState().OsdToastEnabled.Should().BeTrue();
    }

    [Fact]
    public void MatrixState_WithModification()
    {
        var original = new MatrixState();
        var modified = original with { ActiveTab = 5, DebugEnabled = true };
        modified.ActiveTab.Should().Be(5);
        modified.DebugEnabled.Should().BeTrue();
        // Original unchanged (record semantics)
        original.ActiveTab.Should().Be(1);
    }

    // -----------------------------------------------------------------------
    // Multiple saves — latest wins
    // -----------------------------------------------------------------------

    [Fact]
    public void MultipleSaves_LatestWins()
    {
        _service.SaveState(new MatrixState { ActiveTab = 1 });
        _service.SaveState(new MatrixState { ActiveTab = 3 });
        _service.SaveState(new MatrixState { ActiveTab = 7 });

        _service.LoadState().ActiveTab.Should().Be(7);
    }

    [Fact]
    public void SaveState_WithWindowSlots_Roundtrips()
    {
        var state = new MatrixState
        {
            WindowSlots = new Dictionary<string, WindowSlot>
            {
                ["Matrix-1"] = new WindowSlot { ShaderIndex = 1, SlotPosition = 0, MonitorIndex = 0 },
                ["Matrix-2"] = new WindowSlot { ShaderIndex = 2, SlotPosition = 1, MonitorIndex = 0 },
            }
        };
        _service.SaveState(state);

        var loaded = _service.LoadState();
        loaded.WindowSlots.Should().HaveCount(2);
        loaded.WindowSlots["Matrix-1"].SlotPosition.Should().Be(0);
        loaded.WindowSlots["Matrix-2"].SlotPosition.Should().Be(1);
    }
}
