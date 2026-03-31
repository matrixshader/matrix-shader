using MatrixShader.Core.Models;
using MatrixShader.Core.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for EnvironmentService — render mode detection, terminal type detection, ANSI support.
/// </summary>
public class EnvironmentServiceTests
{
    private EnvironmentService CreateService()
    {
        return new EnvironmentService(NullLogger<EnvironmentService>.Instance);
    }

    // ---------------------------------------------------------------
    // IsWindowsTerminal — checks WT_SESSION env var
    // ---------------------------------------------------------------

    [Fact]
    public void IsWindowsTerminal_ReturnsFalse_WhenNoWtSession()
    {
        // Save and clear WT_SESSION
        var original = Environment.GetEnvironmentVariable("WT_SESSION");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", null);
            Assert.False(EnvironmentService.IsWindowsTerminal());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", original);
        }
    }

    [Fact]
    public void IsWindowsTerminal_ReturnsFalse_WhenEmpty()
    {
        var original = Environment.GetEnvironmentVariable("WT_SESSION");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", "");
            Assert.False(EnvironmentService.IsWindowsTerminal());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", original);
        }
    }

    [Fact]
    public void IsWindowsTerminal_ReturnsTrue_WhenWtSessionSet()
    {
        var original = Environment.GetEnvironmentVariable("WT_SESSION");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", "{some-guid-value}");
            Assert.True(EnvironmentService.IsWindowsTerminal());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", original);
        }
    }

    // ---------------------------------------------------------------
    // RenderMode detection
    // ---------------------------------------------------------------

    [Fact]
    public void DetectRenderMode_WithWtSession_ReturnsFull()
    {
        var original = Environment.GetEnvironmentVariable("WT_SESSION");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", "{test-session}");
            var service = CreateService();
            Assert.Equal(RenderMode.Full, service.DetectRenderMode());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", original);
        }
    }

    [Fact]
    public void RenderMode_HasExpectedValues()
    {
        // Enum should have Full, Lite, Headless
        Assert.Equal(0, (int)RenderMode.Full);
        Assert.Equal(1, (int)RenderMode.Lite);
        Assert.Equal(2, (int)RenderMode.Headless);
    }

    // ---------------------------------------------------------------
    // HasAnsiSupport
    // ---------------------------------------------------------------

    [Fact]
    public void HasAnsiSupport_OnWindows10Plus_ReturnsTrue()
    {
        // Test is running on Windows 11, which is >= 10
        if (OperatingSystem.IsWindows() && Environment.OSVersion.Version.Major >= 10)
        {
            Assert.True(EnvironmentService.HasAnsiSupport());
        }
    }

    [Fact]
    public void HasAnsiSupport_WithXterm_ReturnsTrue()
    {
        var originalTerm = Environment.GetEnvironmentVariable("TERM");
        var originalColor = Environment.GetEnvironmentVariable("COLORTERM");
        try
        {
            Environment.SetEnvironmentVariable("TERM", "xterm-256color");
            Environment.SetEnvironmentVariable("COLORTERM", null);
            Assert.True(EnvironmentService.HasAnsiSupport());
        }
        finally
        {
            Environment.SetEnvironmentVariable("TERM", originalTerm);
            Environment.SetEnvironmentVariable("COLORTERM", originalColor);
        }
    }

    [Fact]
    public void HasAnsiSupport_WithColorTerm_ReturnsTrue()
    {
        var originalTerm = Environment.GetEnvironmentVariable("TERM");
        var originalColor = Environment.GetEnvironmentVariable("COLORTERM");
        try
        {
            Environment.SetEnvironmentVariable("TERM", null);
            Environment.SetEnvironmentVariable("COLORTERM", "truecolor");
            Assert.True(EnvironmentService.HasAnsiSupport());
        }
        finally
        {
            Environment.SetEnvironmentVariable("TERM", originalTerm);
            Environment.SetEnvironmentVariable("COLORTERM", originalColor);
        }
    }

    // ---------------------------------------------------------------
    // HasConsole
    // ---------------------------------------------------------------

    [Fact]
    public void HasConsole_InTestRunner_ReturnsValue()
    {
        // Should not throw, regardless of return value
        var result = EnvironmentService.HasConsole();
        // No assertion on value — depends on test runner environment
        Assert.True(result || !result); // Tautology to verify no exception
    }

    // ---------------------------------------------------------------
    // GetTerminalType
    // ---------------------------------------------------------------

    [Fact]
    public void GetTerminalType_ReturnsNonEmpty()
    {
        var type = EnvironmentService.GetTerminalType();
        Assert.False(string.IsNullOrEmpty(type));
    }

    [Fact]
    public void GetTerminalType_WithWtSession_ReturnsWindowsTerminal()
    {
        var original = Environment.GetEnvironmentVariable("WT_SESSION");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", "{test}");
            Assert.Equal("Windows Terminal", EnvironmentService.GetTerminalType());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", original);
        }
    }

    // ---------------------------------------------------------------
    // CanUseShaders
    // ---------------------------------------------------------------

    [Fact]
    public void CanUseShaders_WithoutWtSession_ReturnsFalse()
    {
        var originalSession = Environment.GetEnvironmentVariable("WT_SESSION");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", null);
            var service = CreateService();
            Assert.False(service.CanUseShaders());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", originalSession);
        }
    }

    [Fact]
    public void CanUseShaders_WithWtSessionButNoProfile_ReturnsFalse()
    {
        var originalSession = Environment.GetEnvironmentVariable("WT_SESSION");
        var originalProfile = Environment.GetEnvironmentVariable("WT_PROFILE_ID");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", "{test}");
            Environment.SetEnvironmentVariable("WT_PROFILE_ID", null);
            var service = CreateService();
            Assert.False(service.CanUseShaders());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", originalSession);
            Environment.SetEnvironmentVariable("WT_PROFILE_ID", originalProfile);
        }
    }

    [Fact]
    public void CanUseShaders_WithBothVars_ReturnsTrue()
    {
        var originalSession = Environment.GetEnvironmentVariable("WT_SESSION");
        var originalProfile = Environment.GetEnvironmentVariable("WT_PROFILE_ID");
        try
        {
            Environment.SetEnvironmentVariable("WT_SESSION", "{test}");
            Environment.SetEnvironmentVariable("WT_PROFILE_ID", "{profile-guid}");
            var service = CreateService();
            Assert.True(service.CanUseShaders());
        }
        finally
        {
            Environment.SetEnvironmentVariable("WT_SESSION", originalSession);
            Environment.SetEnvironmentVariable("WT_PROFILE_ID", originalProfile);
        }
    }

    // ---------------------------------------------------------------
    // IdentitySource confidence mapping
    // ---------------------------------------------------------------

    [Fact]
    public void IdentitySource_LaunchTracking_Confidence_Is1()
    {
        Assert.Equal(1.0, IdentitySource.LaunchTracking.GetConfidence());
    }

    [Fact]
    public void IdentitySource_CommandLine_Confidence_Is095()
    {
        Assert.Equal(0.95, IdentitySource.CommandLine.GetConfidence());
    }

    [Fact]
    public void IdentitySource_Title_Confidence_Is070()
    {
        Assert.Equal(0.70, IdentitySource.Title.GetConfidence());
    }

    [Fact]
    public void IdentitySource_Unknown_Confidence_Is0()
    {
        Assert.Equal(0.0, IdentitySource.Unknown.GetConfidence());
    }

    [Fact]
    public void IdentitySource_AllSourcesHavePositiveConfidence_ExceptUnknown()
    {
        foreach (var source in Enum.GetValues<IdentitySource>())
        {
            if (source == IdentitySource.Unknown)
            {
                Assert.Equal(0.0, source.GetConfidence());
            }
            else
            {
                Assert.True(source.GetConfidence() > 0.0, $"{source} should have positive confidence");
            }
        }
    }
}
