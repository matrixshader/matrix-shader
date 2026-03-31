using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using FluentAssertions;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for HotkeyConfig model and HotkeyConfigService persistence.
/// </summary>
public class HotkeyConfigTests
{
    #region DefaultBindings

    [Fact]
    public void DefaultBindings_Returns_13_Actions()
    {
        var config = HotkeyConfig.DefaultBindings();
        config.Bindings.Should().HaveCount(13);
    }

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
    public void DefaultBindings_Contains_Expected_Action(HotkeyAction action)
    {
        var config = HotkeyConfig.DefaultBindings();
        config.Bindings.Should().ContainKey(action);
    }

    [Fact]
    public void DefaultBindings_All_Have_DisplayNames()
    {
        var config = HotkeyConfig.DefaultBindings();
        foreach (var binding in config.Bindings.Values)
        {
            binding.DisplayName.Should().NotBeNullOrEmpty(
                $"Binding for {binding.Action} should have a display name");
        }
    }

    [Fact]
    public void DefaultBindings_All_Enabled()
    {
        var config = HotkeyConfig.DefaultBindings();
        foreach (var binding in config.Bindings.Values)
        {
            binding.Enabled.Should().BeTrue(
                $"Binding for {binding.Action} should be enabled by default");
        }
    }

    [Fact]
    public void DefaultBindings_All_Have_CtrlShift_Modifier()
    {
        var config = HotkeyConfig.DefaultBindings();
        foreach (var binding in config.Bindings.Values)
        {
            binding.DisplayName.Should().StartWith("Ctrl+Shift+",
                $"Binding for {binding.Action} should use Ctrl+Shift modifier");
        }
    }

    [Fact]
    public void DefaultBindings_Does_Not_Contain_CycleShader()
    {
        var config = HotkeyConfig.DefaultBindings();
        // CycleShader was removed due to BUG-SHADER04/05
        var names = Enum.GetNames(typeof(HotkeyAction));
        names.Should().NotContain("CycleShader");
    }

    [Fact]
    public void DefaultBindings_All_Have_NonZero_VirtualKey()
    {
        var config = HotkeyConfig.DefaultBindings();
        foreach (var binding in config.Bindings.Values)
        {
            binding.VirtualKey.Should().BeGreaterThan(0,
                $"Binding for {binding.Action} should have a virtual key code");
        }
    }

    #endregion

    #region HotkeyConfig Model Methods

    [Fact]
    public void GetBinding_Returns_Binding_For_Known_Action()
    {
        var config = HotkeyConfig.DefaultBindings();
        var binding = config.GetBinding(HotkeyAction.SpeedUp);
        binding.Should().NotBeNull();
        binding!.Action.Should().Be(HotkeyAction.SpeedUp);
    }

    [Fact]
    public void GetBinding_Returns_Null_For_Unknown_Action()
    {
        var config = HotkeyConfig.DefaultBindings();
        var binding = config.GetBinding((HotkeyAction)999);
        binding.Should().BeNull();
    }

    [Fact]
    public void GetEnabledBindings_Returns_All_When_All_Enabled()
    {
        var config = HotkeyConfig.DefaultBindings();
        config.GetEnabledBindings().Should().HaveCount(13);
    }

    [Fact]
    public void WithEnabled_Disables_Binding()
    {
        var config = HotkeyConfig.DefaultBindings();
        var updated = config.WithEnabled(HotkeyAction.SpeedUp, false);

        updated.GetBinding(HotkeyAction.SpeedUp)!.Enabled.Should().BeFalse();
        updated.GetEnabledBindings().Should().HaveCount(12);
    }

    [Fact]
    public void WithEnabled_Enables_Disabled_Binding()
    {
        var config = HotkeyConfig.DefaultBindings()
            .WithEnabled(HotkeyAction.SpeedUp, false);

        var updated = config.WithEnabled(HotkeyAction.SpeedUp, true);
        updated.GetBinding(HotkeyAction.SpeedUp)!.Enabled.Should().BeTrue();
    }

    [Fact]
    public void WithBinding_Updates_Specific_Binding()
    {
        var config = HotkeyConfig.DefaultBindings();
        var newBinding = new HotkeyBinding(HotkeyAction.SpeedUp, "Alt+F4", 0x0001, 0x73, true);
        var updated = config.WithBinding(HotkeyAction.SpeedUp, newBinding);

        updated.GetBinding(HotkeyAction.SpeedUp)!.DisplayName.Should().Be("Alt+F4");
    }

    [Fact]
    public void WithBinding_Does_Not_Modify_Original()
    {
        var config = HotkeyConfig.DefaultBindings();
        var originalDisplay = config.GetBinding(HotkeyAction.SpeedUp)!.DisplayName;

        var newBinding = new HotkeyBinding(HotkeyAction.SpeedUp, "Alt+F4", 0x0001, 0x73, true);
        _ = config.WithBinding(HotkeyAction.SpeedUp, newBinding);

        config.GetBinding(HotkeyAction.SpeedUp)!.DisplayName.Should().Be(originalDisplay);
    }

    #endregion

    #region HotkeyBinding Model

    [Fact]
    public void HotkeyBinding_CtrlShift_Creates_Correct_DisplayName()
    {
        var binding = HotkeyBinding.CtrlShift(HotkeyAction.SpeedUp, 0x28, "Down");
        binding.DisplayName.Should().Be("Ctrl+Shift+Down");
    }

    [Fact]
    public void HotkeyBinding_CtrlShift_Sets_Action()
    {
        var binding = HotkeyBinding.CtrlShift(HotkeyAction.ToggleFar, 0x31, "1");
        binding.Action.Should().Be(HotkeyAction.ToggleFar);
    }

    [Fact]
    public void HotkeyBinding_CtrlShift_Enabled_By_Default()
    {
        var binding = HotkeyBinding.CtrlShift(HotkeyAction.SpeedUp, 0x28, "Down");
        binding.Enabled.Should().BeTrue();
    }

    [Fact]
    public void HotkeyBinding_Record_With_Expression_Works()
    {
        var binding = HotkeyBinding.CtrlShift(HotkeyAction.SpeedUp, 0x28, "Down");
        var disabled = binding with { Enabled = false };
        disabled.Enabled.Should().BeFalse();
        disabled.DisplayName.Should().Be("Ctrl+Shift+Down");
    }

    #endregion

    #region HotkeyConfigService Save/Load Roundtrip

    [Fact]
    public void SaveConfig_LoadConfig_Roundtrip()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_test_{Guid.NewGuid():N}");
        var configPath = Path.Combine(tempDir, "hotkey-config.json");

        try
        {
            var logger = Mock.Of<ILogger<HotkeyConfigService>>();
            var service = new HotkeyConfigService(logger, configPath);

            var config = HotkeyConfig.DefaultBindings();
            service.SaveConfig(config);

            service.ConfigExists.Should().BeTrue();

            var loaded = service.LoadConfig();
            loaded.Bindings.Should().HaveCount(config.Bindings.Count);

            foreach (var action in config.Bindings.Keys)
            {
                loaded.Bindings.Should().ContainKey(action);
                loaded.Bindings[action].Enabled.Should().Be(config.Bindings[action].Enabled);
            }
        }
        finally
        {
            if (Directory.Exists(tempDir))
                Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void LoadConfig_Missing_File_Returns_Defaults()
    {
        var configPath = Path.Combine(Path.GetTempPath(), $"nonexistent_{Guid.NewGuid():N}", "hotkey-config.json");

        var logger = Mock.Of<ILogger<HotkeyConfigService>>();
        var service = new HotkeyConfigService(logger, configPath);

        var config = service.LoadConfig();
        config.Bindings.Should().HaveCount(13);
    }

    [Fact]
    public void LoadConfig_Corrupt_Json_Returns_Defaults()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_test_{Guid.NewGuid():N}");
        var configPath = Path.Combine(tempDir, "hotkey-config.json");

        try
        {
            Directory.CreateDirectory(tempDir);
            File.WriteAllText(configPath, "{broken json!!!}");

            var logger = Mock.Of<ILogger<HotkeyConfigService>>();
            var service = new HotkeyConfigService(logger, configPath);

            var config = service.LoadConfig();
            config.Bindings.Should().HaveCount(13);
        }
        finally
        {
            if (Directory.Exists(tempDir))
                Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ResetToDefaults_Returns_Defaults_And_Deletes_File()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_test_{Guid.NewGuid():N}");
        var configPath = Path.Combine(tempDir, "hotkey-config.json");

        try
        {
            var logger = Mock.Of<ILogger<HotkeyConfigService>>();
            var service = new HotkeyConfigService(logger, configPath);

            // Save something first
            service.SaveConfig(HotkeyConfig.DefaultBindings());
            File.Exists(configPath).Should().BeTrue();

            // Reset
            var defaults = service.ResetToDefaults();
            defaults.Bindings.Should().HaveCount(13);
            File.Exists(configPath).Should().BeFalse();
        }
        finally
        {
            if (Directory.Exists(tempDir))
                Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void SaveConfig_Creates_Directory_If_Missing()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_test_{Guid.NewGuid():N}", "deep", "nested");
        var configPath = Path.Combine(tempDir, "hotkey-config.json");

        try
        {
            var logger = Mock.Of<ILogger<HotkeyConfigService>>();
            var service = new HotkeyConfigService(logger, configPath);

            service.SaveConfig(HotkeyConfig.DefaultBindings());
            File.Exists(configPath).Should().BeTrue();
        }
        finally
        {
            var root = Path.Combine(Path.GetTempPath(), Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(tempDir))!)!);
            if (Directory.Exists(root))
                Directory.Delete(root, true);
        }
    }

    [Fact]
    public void ConfigExists_False_When_No_File()
    {
        var configPath = Path.Combine(Path.GetTempPath(), $"nonexistent_{Guid.NewGuid():N}", "config.json");
        var logger = Mock.Of<ILogger<HotkeyConfigService>>();
        var service = new HotkeyConfigService(logger, configPath);

        service.ConfigExists.Should().BeFalse();
    }

    [Fact]
    public void SaveConfig_Then_LoadConfig_Preserves_Disabled_Binding()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"matrixshader_test_{Guid.NewGuid():N}");
        var configPath = Path.Combine(tempDir, "hotkey-config.json");

        try
        {
            var logger = Mock.Of<ILogger<HotkeyConfigService>>();
            var service = new HotkeyConfigService(logger, configPath);

            var config = HotkeyConfig.DefaultBindings().WithEnabled(HotkeyAction.SpeedUp, false);
            service.SaveConfig(config);

            var loaded = service.LoadConfig();
            loaded.GetBinding(HotkeyAction.SpeedUp)!.Enabled.Should().BeFalse();
        }
        finally
        {
            if (Directory.Exists(tempDir))
                Directory.Delete(tempDir, true);
        }
    }

    #endregion
}
