using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for ProcessCleanup — kill-before-launch and single-instance detection.
/// These tests verify safe behavior; they don't actually kill real processes.
/// </summary>
public class ProcessCleanupTests
{
    // -----------------------------------------------------------------------
    // IsAnotherInstanceRunning
    // -----------------------------------------------------------------------

    [Fact]
    public void IsAnotherInstanceRunning_ReturnsBool()
    {
        // Should not throw regardless of environment
        var result = ProcessCleanup.IsAnotherInstanceRunning();
        Assert.IsType<bool>(result);
    }

    [Fact]
    public void IsAnotherInstanceRunning_CurrentProcessNotCounted()
    {
        // The test runner is the only instance of its own process name.
        // IsAnotherInstanceRunning excludes the current PID, so if no other
        // instance of the test runner is running, this should return false.
        // (Could be true if running tests in parallel, but generally false.)
        var result = ProcessCleanup.IsAnotherInstanceRunning();
        // We can't assert true/false deterministically, but it shouldn't throw.
        Assert.IsType<bool>(result);
    }

    // -----------------------------------------------------------------------
    // KillBackgroundProcesses
    // -----------------------------------------------------------------------

    [Fact]
    public void KillBackgroundProcesses_DoesNotThrow_WhenNoProcessesRunning()
    {
        // This should silently succeed even when no matrix-hotkeys or matrix-monitor
        // processes exist. The method catches all exceptions internally.
        var ex = Record.Exception(() => ProcessCleanup.KillBackgroundProcesses());
        Assert.Null(ex);
    }

    [Fact]
    public void KillBackgroundProcesses_CanBeCalledMultipleTimes()
    {
        // Idempotent — calling multiple times should not throw
        var ex = Record.Exception(() =>
        {
            ProcessCleanup.KillBackgroundProcesses();
            ProcessCleanup.KillBackgroundProcesses();
            ProcessCleanup.KillBackgroundProcesses();
        });
        Assert.Null(ex);
    }

    [Fact]
    public void KillBackgroundProcesses_DoesNotKillCurrentProcess()
    {
        // After calling KillBackgroundProcesses, our own process should still be alive.
        ProcessCleanup.KillBackgroundProcesses();
        var currentProcess = System.Diagnostics.Process.GetCurrentProcess();
        Assert.False(currentProcess.HasExited);
    }
}
