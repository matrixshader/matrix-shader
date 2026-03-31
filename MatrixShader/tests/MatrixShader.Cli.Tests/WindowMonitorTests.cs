using MatrixShader.Core.Models;
using MatrixShader.Monitor;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace MatrixShader.Cli.Tests;

/// <summary>
/// Tests for Monitor service — watchdog, auto-exit, window movement detection.
/// Reference: linux/tests/test_watchdog.py
/// </summary>
public class WindowMonitorTests
{
    // ---------------------------------------------------------------
    // MonitorService constants
    // ---------------------------------------------------------------

    [Fact]
    public void MonitorService_PollIntervalMs_Is500()
    {
        // MonitorService polls windows every 500ms
        // Verified from: private const int PollIntervalMs = 500;
        var field = typeof(MonitorService).GetField("PollIntervalMs",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        Assert.NotNull(field);
        Assert.Equal(500, (int)field!.GetValue(null)!);
    }

    [Fact]
    public void MonitorService_AutoExitSeconds_Is30()
    {
        // Auto-exit when no Matrix windows for 30 seconds
        var field = typeof(MonitorService).GetField("AutoExitSeconds",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        Assert.NotNull(field);
        Assert.Equal(30, (int)field!.GetValue(null)!);
    }

    // ---------------------------------------------------------------
    // HotkeyWatchdog constants
    // ---------------------------------------------------------------

    [Fact]
    public void HotkeyWatchdog_HealthCheckIntervalMs_Is5000()
    {
        var field = typeof(HotkeyWatchdog).GetField("HealthCheckIntervalMs",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        Assert.NotNull(field);
        Assert.Equal(5000, (int)field!.GetValue(null)!);
    }

    // ---------------------------------------------------------------
    // Window movement detection (HasMoved)
    // ---------------------------------------------------------------

    [Fact]
    public void HasMoved_NoMovement_ReturnsFalse()
    {
        var result = InvokeHasMoved(
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 },
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 });
        Assert.False(result);
    }

    [Fact]
    public void HasMoved_SmallMovement_BelowThreshold_ReturnsFalse()
    {
        // Threshold is 5 pixels — 3px move should not trigger
        var result = InvokeHasMoved(
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 },
            new WindowRect { Left = 103, Top = 102, Width = 800, Height = 600 });
        Assert.False(result);
    }

    [Fact]
    public void HasMoved_LargeMovement_ReturnsTrue()
    {
        var result = InvokeHasMoved(
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 },
            new WindowRect { Left = 200, Top = 100, Width = 800, Height = 600 });
        Assert.True(result);
    }

    [Fact]
    public void HasMoved_ResizeDetected_ReturnsTrue()
    {
        var result = InvokeHasMoved(
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 },
            new WindowRect { Left = 100, Top = 100, Width = 1000, Height = 600 });
        Assert.True(result);
    }

    [Fact]
    public void HasMoved_ExactlyAtThreshold_ReturnsFalse()
    {
        // Threshold is > 5, so exactly 5 should return false
        var result = InvokeHasMoved(
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 },
            new WindowRect { Left = 105, Top = 100, Width = 800, Height = 600 });
        Assert.False(result);
    }

    [Fact]
    public void HasMoved_JustOverThreshold_ReturnsTrue()
    {
        var result = InvokeHasMoved(
            new WindowRect { Left = 100, Top = 100, Width = 800, Height = 600 },
            new WindowRect { Left = 106, Top = 100, Width = 800, Height = 600 });
        Assert.True(result);
    }

    [Fact]
    public void HasMoved_NegativeMovement_ReturnsTrue()
    {
        var result = InvokeHasMoved(
            new WindowRect { Left = 200, Top = 200, Width = 800, Height = 600 },
            new WindowRect { Left = 100, Top = 200, Width = 800, Height = 600 });
        Assert.True(result);
    }

    // ---------------------------------------------------------------
    // Snap edge detection (IsNearEdge)
    // ---------------------------------------------------------------

    [Fact]
    public void IsNearEdge_ExactlyOnEdge_ReturnsTrue()
    {
        var result = InvokeIsNearEdge(100, 100);
        Assert.True(result);
    }

    [Fact]
    public void IsNearEdge_Within19Pixels_ReturnsTrue()
    {
        // SnapThreshold is 20 — 19px away should be near
        var result = InvokeIsNearEdge(119, 100);
        Assert.True(result);
    }

    [Fact]
    public void IsNearEdge_FarFromEdge_ReturnsFalse()
    {
        var result = InvokeIsNearEdge(200, 100);
        Assert.False(result);
    }

    [Fact]
    public void IsNearEdge_ExactlyAtThreshold_ReturnsFalse()
    {
        // Threshold is < 20, so exactly 20 should be false
        var result = InvokeIsNearEdge(120, 100);
        Assert.False(result);
    }

    // ---------------------------------------------------------------
    // WindowRect model
    // ---------------------------------------------------------------

    [Fact]
    public void WindowRect_Right_CalculatedCorrectly()
    {
        var rect = new WindowRect { Left = 100, Top = 50, Width = 800, Height = 600 };
        Assert.Equal(900, rect.Right);
    }

    [Fact]
    public void WindowRect_Bottom_CalculatedCorrectly()
    {
        var rect = new WindowRect { Left = 100, Top = 50, Width = 800, Height = 600 };
        Assert.Equal(650, rect.Bottom);
    }

    [Fact]
    public void WindowRect_FromLTRB_CalculatesWidthAndHeight()
    {
        var rect = WindowRect.FromLTRB(100, 50, 900, 650);
        Assert.Equal(100, rect.Left);
        Assert.Equal(50, rect.Top);
        Assert.Equal(800, rect.Width);
        Assert.Equal(600, rect.Height);
    }

    [Fact]
    public void WindowRect_Empty_IsAllZeros()
    {
        var empty = WindowRect.Empty;
        Assert.Equal(0, empty.Left);
        Assert.Equal(0, empty.Top);
        Assert.Equal(0, empty.Width);
        Assert.Equal(0, empty.Height);
    }

    // ---------------------------------------------------------------
    // Overlap area calculation for multi-monitor detection
    // ---------------------------------------------------------------

    [Fact]
    public void OverlapArea_FullyContained_ReturnsInnerArea()
    {
        var outer = WindowRect.FromLTRB(0, 0, 1920, 1080);
        var inner = WindowRect.FromLTRB(100, 100, 500, 400);
        var overlap = CalculateOverlapArea(outer, inner);
        Assert.Equal(400 * 300, overlap);
    }

    [Fact]
    public void OverlapArea_NoOverlap_ReturnsZero()
    {
        var a = WindowRect.FromLTRB(0, 0, 100, 100);
        var b = WindowRect.FromLTRB(200, 200, 300, 300);
        Assert.Equal(0, CalculateOverlapArea(a, b));
    }

    [Fact]
    public void OverlapArea_PartialOverlap_ReturnsCorrectArea()
    {
        var a = WindowRect.FromLTRB(0, 0, 200, 200);
        var b = WindowRect.FromLTRB(100, 100, 300, 300);
        // Overlap: 100x100
        Assert.Equal(10000, CalculateOverlapArea(a, b));
    }

    [Fact]
    public void OverlapArea_TouchingEdge_ReturnsZero()
    {
        var a = WindowRect.FromLTRB(0, 0, 100, 100);
        var b = WindowRect.FromLTRB(100, 0, 200, 100);
        Assert.Equal(0, CalculateOverlapArea(a, b));
    }

    // ---------------------------------------------------------------
    // HotkeyWatchdog construction and disposal
    // ---------------------------------------------------------------

    [Fact]
    public void HotkeyWatchdog_Dispose_DoesNotThrow()
    {
        var logger = NullLogger.Instance;
        var watchdog = new HotkeyWatchdog("nonexistent.exe", logger);
        watchdog.Dispose();
        // Double-dispose should also not throw
        watchdog.Dispose();
    }

    [Fact]
    public void HotkeyWatchdog_StopWithoutStart_DoesNotThrow()
    {
        var logger = NullLogger.Instance;
        var watchdog = new HotkeyWatchdog("nonexistent.exe", logger);
        watchdog.Stop();
        watchdog.Dispose();
    }

    // ---------------------------------------------------------------
    // ManualActionPause equivalent — movement threshold
    // ---------------------------------------------------------------

    [Fact]
    public void MovementThreshold_Is5Pixels()
    {
        // The HasMoved method uses const int Threshold = 5
        // Verify by testing boundary: 5 = no move, 6 = move
        Assert.False(InvokeHasMoved(
            new WindowRect { Left = 0, Top = 0, Width = 100, Height = 100 },
            new WindowRect { Left = 5, Top = 0, Width = 100, Height = 100 }));
        Assert.True(InvokeHasMoved(
            new WindowRect { Left = 0, Top = 0, Width = 100, Height = 100 },
            new WindowRect { Left = 6, Top = 0, Width = 100, Height = 100 }));
    }

    [Fact]
    public void SnapThreshold_Is20Pixels()
    {
        // IsNearEdge uses const int SnapThreshold = 20
        Assert.True(InvokeIsNearEdge(119, 100));  // 19 < 20
        Assert.False(InvokeIsNearEdge(120, 100)); // 20 is NOT < 20
        Assert.False(InvokeIsNearEdge(121, 100)); // 21 > 20
    }

    // ---------------------------------------------------------------
    // Helpers — invoke private static methods via reflection
    // ---------------------------------------------------------------

    private static bool InvokeHasMoved(WindowRect old, WindowRect current)
    {
        var method = typeof(MonitorService).GetMethod("HasMoved",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        Assert.NotNull(method);
        return (bool)method!.Invoke(null, new object[] { old, current })!;
    }

    private static bool InvokeIsNearEdge(int position, int edge)
    {
        var method = typeof(MonitorService).GetMethod("IsNearEdge",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        Assert.NotNull(method);
        return (bool)method!.Invoke(null, new object[] { position, edge })!;
    }

    /// <summary>
    /// Calculate overlap area between two rectangles (same logic the monitor could use).
    /// </summary>
    private static int CalculateOverlapArea(WindowRect a, WindowRect b)
    {
        int overlapLeft = Math.Max(a.Left, b.Left);
        int overlapTop = Math.Max(a.Top, b.Top);
        int overlapRight = Math.Min(a.Right, b.Right);
        int overlapBottom = Math.Min(a.Bottom, b.Bottom);

        int width = Math.Max(0, overlapRight - overlapLeft);
        int height = Math.Max(0, overlapBottom - overlapTop);

        return width * height;
    }
}
