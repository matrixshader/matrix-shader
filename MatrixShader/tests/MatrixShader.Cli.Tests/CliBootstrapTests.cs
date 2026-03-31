using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for CliBootstrap — argument parsing, directory paths, Matrix quotes.
/// Reference: linux/tests/test_installer.py
/// </summary>
public class CliBootstrapTests
{
    // ---------------------------------------------------------------
    // ParseArgs — CLI argument parsing
    // ---------------------------------------------------------------

    [Fact]
    public void ParseArgs_Help_LongFlag()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--help" });
        Assert.True(opts.ShowHelp);
    }

    [Fact]
    public void ParseArgs_Help_ShortFlag()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "-h" });
        Assert.True(opts.ShowHelp);
    }

    [Fact]
    public void ParseArgs_Debug_LongFlag()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--debug" });
        Assert.True(opts.Debug);
    }

    [Fact]
    public void ParseArgs_Morpheus_Flag()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--morpheus" });
        Assert.True(opts.Morpheus);
    }

    [Fact]
    public void ParseArgs_AgentSmith_Flag()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--agent-smith" });
        Assert.True(opts.AgentSmith);
    }

    [Fact]
    public void ParseArgs_NoArgs_AllFalse()
    {
        var opts = CliBootstrap.ParseArgs(Array.Empty<string>());
        Assert.False(opts.ShowHelp);
        Assert.False(opts.Debug);
        Assert.False(opts.Morpheus);
        Assert.False(opts.AgentSmith);
    }

    [Fact]
    public void ParseArgs_MultipleFlags()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--debug", "--morpheus" });
        Assert.True(opts.Debug);
        Assert.True(opts.Morpheus);
        Assert.False(opts.ShowHelp);
        Assert.False(opts.AgentSmith);
    }

    [Fact]
    public void ParseArgs_UnrecognizedFlags_AreIgnored()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--unknown", "--foobar" });
        Assert.False(opts.ShowHelp);
        Assert.False(opts.Debug);
        Assert.False(opts.Morpheus);
        Assert.False(opts.AgentSmith);
    }

    [Fact]
    public void ParseArgs_AllFlags()
    {
        var opts = CliBootstrap.ParseArgs(new[] { "--help", "--debug", "--morpheus", "--agent-smith" });
        Assert.True(opts.ShowHelp);
        Assert.True(opts.Debug);
        Assert.True(opts.Morpheus);
        Assert.True(opts.AgentSmith);
    }

    // ---------------------------------------------------------------
    // GetShadersDirectory
    // ---------------------------------------------------------------

    [Fact]
    public void GetShadersDirectory_ReturnsNonEmptyPath()
    {
        var path = CliBootstrap.GetShadersDirectory();
        Assert.False(string.IsNullOrEmpty(path));
    }

    [Fact]
    public void GetShadersDirectory_ContainsMatrixShader()
    {
        var path = CliBootstrap.GetShadersDirectory();
        Assert.Contains("MatrixShader", path);
    }

    [Fact]
    public void GetShadersDirectory_ContainsShaders()
    {
        var path = CliBootstrap.GetShadersDirectory();
        Assert.Contains("shaders", path, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetShadersDirectory_IsAbsolutePath()
    {
        var path = CliBootstrap.GetShadersDirectory();
        Assert.True(Path.IsPathRooted(path));
    }

    // ---------------------------------------------------------------
    // GetMatrixDirectory
    // ---------------------------------------------------------------

    [Fact]
    public void GetMatrixDirectory_ReturnsNonEmptyPath()
    {
        var path = CliBootstrap.GetMatrixDirectory();
        Assert.False(string.IsNullOrEmpty(path));
    }

    [Fact]
    public void GetMatrixDirectory_ContainsMatrixShader()
    {
        var path = CliBootstrap.GetMatrixDirectory();
        Assert.Contains("MatrixShader", path);
    }

    [Fact]
    public void GetMatrixDirectory_IsAbsolutePath()
    {
        var path = CliBootstrap.GetMatrixDirectory();
        Assert.True(Path.IsPathRooted(path));
    }

    [Fact]
    public void GetMatrixDirectory_IsParentOfShadersDirectory()
    {
        var matrixDir = CliBootstrap.GetMatrixDirectory();
        var shadersDir = CliBootstrap.GetShadersDirectory();
        Assert.StartsWith(matrixDir, shadersDir);
    }

    // ---------------------------------------------------------------
    // GetInstalledShadersDirectory
    // ---------------------------------------------------------------

    [Fact]
    public void GetInstalledShadersDirectory_ContainsProgramFiles()
    {
        var path = CliBootstrap.GetInstalledShadersDirectory();
        // Should be under Program Files
        Assert.Contains("Program Files", path, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetInstalledShadersDirectory_ContainsMatrixShader()
    {
        var path = CliBootstrap.GetInstalledShadersDirectory();
        Assert.Contains("MatrixShader", path);
    }

    // ---------------------------------------------------------------
    // GetSettingsPath
    // ---------------------------------------------------------------

    [Fact]
    public void GetSettingsPath_ReturnsNonEmptyPath()
    {
        var path = CliBootstrap.GetSettingsPath();
        Assert.False(string.IsNullOrEmpty(path));
    }

    [Fact]
    public void GetSettingsPath_EndsWithSettingsJson()
    {
        var path = CliBootstrap.GetSettingsPath();
        Assert.EndsWith("settings.json", path);
    }

    // ---------------------------------------------------------------
    // CliOptions record
    // ---------------------------------------------------------------

    [Fact]
    public void CliOptions_DefaultValues_AreFalse()
    {
        var opts = new CliOptions();
        Assert.False(opts.ShowHelp);
        Assert.False(opts.Debug);
        Assert.False(opts.Morpheus);
        Assert.False(opts.AgentSmith);
    }

    [Fact]
    public void CliOptions_WithInit_SetsValues()
    {
        var opts = new CliOptions { ShowHelp = true, AgentSmith = true };
        Assert.True(opts.ShowHelp);
        Assert.True(opts.AgentSmith);
        Assert.False(opts.Debug);
        Assert.False(opts.Morpheus);
    }

    // ---------------------------------------------------------------
    // BootstrapResult record
    // ---------------------------------------------------------------

    [Fact]
    public void BootstrapResult_Success_CreatedCorrectly()
    {
        var result = new BootstrapResult(true, WasFirstRun: true, ProfilesCreated: 6);
        Assert.True(result.Success);
        Assert.True(result.WasFirstRun);
        Assert.Equal(6, result.ProfilesCreated);
        Assert.Null(result.ErrorMessage);
    }

    [Fact]
    public void BootstrapResult_Failure_HasErrorMessage()
    {
        var result = new BootstrapResult(false, ErrorMessage: "Windows Terminal required");
        Assert.False(result.Success);
        Assert.Equal("Windows Terminal required", result.ErrorMessage);
    }

    // ---------------------------------------------------------------
    // Matrix Quotes
    // ---------------------------------------------------------------

    [Fact]
    public void MatrixQuotes_Has14Quotes()
    {
        Assert.Equal(14, Core.Constants.MatrixQuotes.All.Count);
    }

    [Fact]
    public void MatrixQuotes_GetRandom_ReturnsNonEmpty()
    {
        var quote = Core.Constants.MatrixQuotes.GetRandom();
        Assert.False(string.IsNullOrEmpty(quote));
    }

    [Fact]
    public void MatrixQuotes_ContainsIconicQuotes()
    {
        var all = Core.Constants.MatrixQuotes.All;
        Assert.Contains("The Matrix has you...", all);
        Assert.Contains("Follow the white rabbit.", all);
        Assert.Contains("There is no spoon.", all);
        Assert.Contains("Free your mind.", all);
        Assert.Contains("I know kung fu.", all);
    }

    [Fact]
    public void MatrixQuotes_GetRandom_ReturnsFromKnownList()
    {
        var all = Core.Constants.MatrixQuotes.All;
        for (int i = 0; i < 50; i++)
        {
            var quote = Core.Constants.MatrixQuotes.GetRandom();
            Assert.Contains(quote, all);
        }
    }
}
