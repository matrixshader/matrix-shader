using System.Reflection;
using MatrixShader.Core.Helpers;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for ConsoleHelper — ANSI escape codes and Matrix brand constants.
/// </summary>
public class ConsoleHelperTests
{
    // -----------------------------------------------------------------------
    // Brand green constant — #6EDCAA (RGB 110,220,170)
    // -----------------------------------------------------------------------

    [Fact]
    public void MatrixGreen_IsCorrectAnsiSequence()
    {
        // MATRIX_GREEN should be \x1b[38;2;110;220;170m (truecolor #6EDCAA)
        var field = typeof(ConsoleHelper)
            .GetField("MATRIX_GREEN", BindingFlags.NonPublic | BindingFlags.Static);
        Assert.NotNull(field);

        var value = (string)field!.GetValue(null)!;
        Assert.Equal("\x1b[38;2;110;220;170m", value);
    }

    [Fact]
    public void MatrixBrightGreen_IsCorrectAnsiSequence()
    {
        var field = typeof(ConsoleHelper)
            .GetField("MATRIX_BRIGHT_GREEN", BindingFlags.NonPublic | BindingFlags.Static);
        Assert.NotNull(field);

        var value = (string)field!.GetValue(null)!;
        Assert.Equal("\x1b[38;2;110;220;170m", value);
    }

    [Fact]
    public void MatrixGreen_MatchesHex6EDCAA()
    {
        // #6EDCAA = RGB(110, 220, 170)
        // ANSI truecolor: \x1b[38;2;110;220;170m
        var field = typeof(ConsoleHelper)
            .GetField("MATRIX_GREEN", BindingFlags.NonPublic | BindingFlags.Static);
        var value = (string)field!.GetValue(null)!;

        Assert.Contains("110", value);  // R = 0x6E = 110
        Assert.Contains("220", value);  // G = 0xDC = 220
        Assert.Contains("170", value);  // B = 0xAA = 170
    }

    [Fact]
    public void Reset_IsStandardAnsiReset()
    {
        var field = typeof(ConsoleHelper)
            .GetField("RESET", BindingFlags.NonPublic | BindingFlags.Static);
        Assert.NotNull(field);

        var value = (string)field!.GetValue(null)!;
        Assert.Equal("\x1b[0m", value);
    }

    [Fact]
    public void Dim_IsGrayAnsiCode()
    {
        var field = typeof(ConsoleHelper)
            .GetField("DIM", BindingFlags.NonPublic | BindingFlags.Static);
        Assert.NotNull(field);

        var value = (string)field!.GetValue(null)!;
        Assert.Equal("\x1b[90m", value);
    }

    [Fact]
    public void WarningYellow_IsYellowAnsiCode()
    {
        var field = typeof(ConsoleHelper)
            .GetField("WARNING_YELLOW", BindingFlags.NonPublic | BindingFlags.Static);
        Assert.NotNull(field);

        var value = (string)field!.GetValue(null)!;
        Assert.Equal("\x1b[33m", value);
    }

    // -----------------------------------------------------------------------
    // EnableAnsiEscapeCodes — doesn't crash
    // -----------------------------------------------------------------------

    [Fact]
    public void EnableAnsiEscapeCodes_DoesNotThrow()
    {
        var ex = Record.Exception(() => ConsoleHelper.EnableAnsiEscapeCodes());
        Assert.Null(ex);
    }

    [Fact]
    public void EnableAnsiEscapeCodes_ReturnsBool()
    {
        var result = ConsoleHelper.EnableAnsiEscapeCodes();
        Assert.IsType<bool>(result);
    }

    // -----------------------------------------------------------------------
    // Static method existence
    // -----------------------------------------------------------------------

    [Fact]
    public void HasWriteMatrixGreenMethod()
    {
        var method = typeof(ConsoleHelper).GetMethod("WriteMatrixGreen",
            BindingFlags.Public | BindingFlags.Static);
        Assert.NotNull(method);
    }

    [Fact]
    public void HasWriteLineMatrixGreenMethod()
    {
        var method = typeof(ConsoleHelper).GetMethod("WriteLineMatrixGreen",
            BindingFlags.Public | BindingFlags.Static);
        Assert.NotNull(method);
    }

    [Fact]
    public void HasShowCommandBannerMethod()
    {
        var method = typeof(ConsoleHelper).GetMethod("ShowCommandBanner",
            BindingFlags.Public | BindingFlags.Static);
        Assert.NotNull(method);
    }

    [Fact]
    public void HasClearScreenMethod()
    {
        var method = typeof(ConsoleHelper).GetMethod("ClearScreen",
            BindingFlags.Public | BindingFlags.Static);
        Assert.NotNull(method);
    }
}
