using System.Text.Json;
using System.Text.Json.Nodes;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for TerminalSettingsService — profile CRUD, JSON object building, ForceShaderReload.
/// </summary>
public class TerminalSettingsTests
{
    private TerminalSettingsService CreateService(string settingsPath)
    {
        var logger = NullLogger<TerminalSettingsService>.Instance;
        return new TerminalSettingsService(logger, settingsPath);
    }

    // ---------------------------------------------------------------
    // BuildProfileJsonObject — via UpsertProfileSurgical round-trip
    // ---------------------------------------------------------------

    [Fact]
    public void BuildProfileJsonObject_IncludesNameAndGuid()
    {
        var profile = new TerminalProfile
        {
            Name = "Matrix-1",
            Guid = "{12345678-1234-1234-1234-123456789012}"
        };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Equal("Matrix-1", obj["name"]?.GetValue<string>());
        Assert.Equal("{12345678-1234-1234-1234-123456789012}", obj["guid"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesHiddenField()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", Hidden = true };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.True(obj["hidden"]?.GetValue<bool>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesOpacity()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", Opacity = 85 };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Equal(85, obj["opacity"]?.GetValue<int>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesUseAcrylic()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", UseAcrylic = false };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.False(obj["useAcrylic"]?.GetValue<bool>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesCommandline()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", Commandline = "powershell.exe" };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Equal("powershell.exe", obj["commandline"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesPixelShaderPath()
    {
        var profile = new TerminalProfile
        {
            Name = "Test", Guid = "{guid}",
            PixelShaderPath = @"C:\shaders\Matrix-1.hlsl"
        };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Equal(@"C:\shaders\Matrix-1.hlsl", obj["experimental.pixelShaderPath"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesTabColor()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", TabColor = "#00FF4C" };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Equal("#00FF4C", obj["tabColor"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesForeground()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", Foreground = "#00FF4C" };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Equal("#00FF4C", obj["foreground"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_IncludesSuppressApplicationTitle()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}" };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.True(obj["suppressApplicationTitle"]?.GetValue<bool>());
    }

    // ---------------------------------------------------------------
    // Font properties in JSON output
    // ---------------------------------------------------------------

    [Fact]
    public void BuildProfileJsonObject_FontFace_CreatesNestedFontObject()
    {
        var profile = new TerminalProfile
        {
            Name = "Test", Guid = "{guid}",
            FontFace = "Nimbus Mono PS"
        };
        var obj = InvokeBuildProfileJsonObject(profile);
        var font = obj["font"] as JsonObject;
        Assert.NotNull(font);
        Assert.Equal("Nimbus Mono PS", font!["face"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_FontWeight_InFontObject()
    {
        var profile = new TerminalProfile
        {
            Name = "Test", Guid = "{guid}",
            FontWeight = "bold"
        };
        var obj = InvokeBuildProfileJsonObject(profile);
        var font = obj["font"] as JsonObject;
        Assert.NotNull(font);
        Assert.Equal("bold", font!["weight"]?.GetValue<string>());
    }

    [Fact]
    public void BuildProfileJsonObject_FontSize_InFontObject()
    {
        var profile = new TerminalProfile
        {
            Name = "Test", Guid = "{guid}",
            FontSize = 14
        };
        var obj = InvokeBuildProfileJsonObject(profile);
        var font = obj["font"] as JsonObject;
        Assert.NotNull(font);
        Assert.Equal(14, font!["size"]?.GetValue<int>());
    }

    [Fact]
    public void BuildProfileJsonObject_NoFont_DoesNotCreateFontObject()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}" };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.Null(obj["font"]);
    }

    [Fact]
    public void BuildProfileJsonObject_NullCommandline_OmitsField()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", Commandline = null };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.False(obj.ContainsKey("commandline"));
    }

    [Fact]
    public void BuildProfileJsonObject_NullPixelShaderPath_OmitsField()
    {
        var profile = new TerminalProfile { Name = "Test", Guid = "{guid}", PixelShaderPath = null };
        var obj = InvokeBuildProfileJsonObject(profile);
        Assert.False(obj.ContainsKey("experimental.pixelShaderPath"));
    }

    // ---------------------------------------------------------------
    // UpsertProfile
    // ---------------------------------------------------------------

    [Fact]
    public void UpsertProfile_AddNew_InsertsAtBeginning()
    {
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>
                {
                    new TerminalProfile { Name = "Existing", Guid = "{existing}" }
                }
            }
        };

        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent-settings.json"));
        var profile = new TerminalProfile { Name = "Matrix-1", Guid = "{matrix1}" };
        service.UpsertProfile(settings, profile);

        Assert.Equal(2, settings.Profiles.List.Count);
        Assert.Equal("Matrix-1", settings.Profiles.List[0].Name);
    }

    [Fact]
    public void UpsertProfile_UpdateExisting_ReplacesInPlace()
    {
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>
                {
                    new TerminalProfile { Name = "Matrix-1", Guid = "{old}", Opacity = 50 }
                }
            }
        };

        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent-settings.json"));
        var updated = new TerminalProfile { Name = "Matrix-1", Guid = "{new}", Opacity = 85 };
        service.UpsertProfile(settings, updated);

        Assert.Single(settings.Profiles.List);
        Assert.Equal(85, settings.Profiles.List[0].Opacity);
        Assert.Equal("{new}", settings.Profiles.List[0].Guid);
    }

    [Fact]
    public void UpsertProfile_CaseInsensitive_FindsByName()
    {
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>
                {
                    new TerminalProfile { Name = "matrix-1", Guid = "{old}" }
                }
            }
        };

        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent-settings.json"));
        var updated = new TerminalProfile { Name = "Matrix-1", Guid = "{new}" };
        service.UpsertProfile(settings, updated);

        Assert.Single(settings.Profiles.List);
        Assert.Equal("{new}", settings.Profiles.List[0].Guid);
    }

    [Fact]
    public void UpsertProfile_NullProfilesList_CreatesIt()
    {
        var settings = new TerminalSettings();
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent-settings.json"));
        var profile = new TerminalProfile { Name = "Matrix-1", Guid = "{guid}" };
        service.UpsertProfile(settings, profile);

        Assert.NotNull(settings.Profiles);
        Assert.NotNull(settings.Profiles.List);
        Assert.Single(settings.Profiles.List);
    }

    // ---------------------------------------------------------------
    // CreateMatrixProfiles
    // ---------------------------------------------------------------

    [Fact]
    public void CreateMatrixProfiles_Creates6Profiles()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, "{}");

        try
        {
            var service = CreateService(settingsPath);
            var settings = new TerminalSettings
            {
                Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
            };
            var count = service.CreateMatrixProfiles(settings, 6, @"C:\shaders");

            Assert.Equal(6, count);
            Assert.Equal(6, settings.Profiles.List.Count);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void CreateMatrixProfiles_NamesFollowMatrixNPattern()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, "{}");

        try
        {
            var service = CreateService(settingsPath);
            var settings = new TerminalSettings
            {
                Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
            };
            service.CreateMatrixProfiles(settings, 3, @"C:\shaders");

            var names = settings.Profiles.List.Select(p => p.Name).ToHashSet();
            Assert.Contains("Matrix-1", names);
            Assert.Contains("Matrix-2", names);
            Assert.Contains("Matrix-3", names);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void CreateMatrixProfiles_CountTooLow_Throws()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
        };
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            service.CreateMatrixProfiles(settings, 0, @"C:\shaders"));
    }

    [Fact]
    public void CreateMatrixProfiles_CountTooHigh_Throws()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
        };
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            service.CreateMatrixProfiles(settings, 9, @"C:\shaders"));
    }

    [Fact]
    public void CreateMatrixProfiles_SetsOpacityTo85()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, "{}");

        try
        {
            var service = CreateService(settingsPath);
            var settings = new TerminalSettings
            {
                Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
            };
            service.CreateMatrixProfiles(settings, 1, @"C:\shaders");

            Assert.Equal(85, settings.Profiles.List[0].Opacity);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void CreateMatrixProfiles_SetsHiddenTrue()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, "{}");

        try
        {
            var service = CreateService(settingsPath);
            var settings = new TerminalSettings
            {
                Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
            };
            service.CreateMatrixProfiles(settings, 1, @"C:\shaders");

            Assert.True(settings.Profiles.List[0].Hidden);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void CreateMatrixProfiles_SetsTabColorFromPreset()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, "{}");

        try
        {
            var service = CreateService(settingsPath);
            var settings = new TerminalSettings
            {
                Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
            };
            service.CreateMatrixProfiles(settings, 1, @"C:\shaders");

            // First preset is Green (0, 255, 77) -> #00FF4D
            Assert.NotNull(settings.Profiles.List[0].TabColor);
            Assert.StartsWith("#", settings.Profiles.List[0].TabColor!);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    // ---------------------------------------------------------------
    // ForceShaderReload
    // ---------------------------------------------------------------

    [Fact]
    public void ForceShaderReload_TogglesPathForward()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, """{"profiles":{"list":[{"experimental.pixelShaderPath":"C:\\shaders\\Matrix-1.hlsl"}]}}""");

        try
        {
            var service = CreateService(settingsPath);
            service.ForceShaderReload();

            var result = File.ReadAllText(settingsPath);
            Assert.Contains("shaders\\\\.\\\\Matrix-1", result);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ForceShaderReload_TogglesPathBack()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(tempDir);
        var settingsPath = Path.Combine(tempDir, "settings.json");
        File.WriteAllText(settingsPath, """{"profiles":{"list":[{"experimental.pixelShaderPath":"C:\\shaders\\.\\Matrix-1.hlsl"}]}}""");

        try
        {
            var service = CreateService(settingsPath);
            service.ForceShaderReload();

            var result = File.ReadAllText(settingsPath);
            Assert.DoesNotContain("shaders\\\\.\\\\", result);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void ForceShaderReload_NoSettings_DoesNotThrow()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        service.ForceShaderReload(); // Should not throw
    }

    // ---------------------------------------------------------------
    // GetProfile
    // ---------------------------------------------------------------

    [Fact]
    public void GetProfile_FindsByName()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>
                {
                    new TerminalProfile { Name = "Matrix-1", Guid = "{guid1}" },
                    new TerminalProfile { Name = "Matrix-2", Guid = "{guid2}" }
                }
            }
        };

        var profile = service.GetProfile(settings, "Matrix-2");
        Assert.NotNull(profile);
        Assert.Equal("{guid2}", profile!.Guid);
    }

    [Fact]
    public void GetProfile_ReturnsNull_WhenNotFound()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
        };

        Assert.Null(service.GetProfile(settings, "Nonexistent"));
    }

    // ---------------------------------------------------------------
    // GetMatrixProfileCount / HasMatrixProfiles
    // ---------------------------------------------------------------

    [Fact]
    public void GetMatrixProfileCount_CountsMatrixProfiles()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>
                {
                    new TerminalProfile { Name = "Matrix-1" },
                    new TerminalProfile { Name = "Matrix-2" },
                    new TerminalProfile { Name = "PowerShell" },
                    new TerminalProfile { Name = "Redpill" },
                }
            }
        };

        var count = service.GetMatrixProfileCount(settings);
        // Matrix-1, Matrix-2, and Redpill should be counted as Matrix profiles
        Assert.True(count >= 2);
    }

    [Fact]
    public void HasMatrixProfiles_ReturnsTrueWhenPresent()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer
            {
                List = new List<TerminalProfile>
                {
                    new TerminalProfile { Name = "Matrix-1" }
                }
            }
        };
        Assert.True(service.HasMatrixProfiles(settings));
    }

    [Fact]
    public void HasMatrixProfiles_ReturnsFalseWhenEmpty()
    {
        var service = CreateService(Path.Combine(Path.GetTempPath(), "nonexistent.json"));
        var settings = new TerminalSettings
        {
            Profiles = new ProfilesContainer { List = new List<TerminalProfile>() }
        };
        Assert.False(service.HasMatrixProfiles(settings));
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    private static JsonObject InvokeBuildProfileJsonObject(TerminalProfile profile)
    {
        var method = typeof(TerminalSettingsService).GetMethod("BuildProfileJsonObject",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        Assert.NotNull(method);
        return (JsonObject)method!.Invoke(null, new object[] { profile })!;
    }
}
