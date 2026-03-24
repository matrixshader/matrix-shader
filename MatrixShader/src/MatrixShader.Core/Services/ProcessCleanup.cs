using System.Diagnostics;

namespace MatrixShader.Core.Services;

/// <summary>
/// Kills orphaned matrix-hotkeys and matrix-monitor processes before launching new ones.
/// Called by all launchers (wakeupneo, bluepill, construct) to prevent duplicate background processes.
/// </summary>
public static class ProcessCleanup
{
    private static readonly string[] BackgroundProcessNames = { "matrix-hotkeys", "matrix-monitor" };

    /// <summary>
    /// Kills all existing matrix-hotkeys and matrix-monitor processes.
    /// Safe to call even if none are running.
    /// </summary>
    public static void KillBackgroundProcesses()
    {
        var currentPid = Environment.ProcessId;

        foreach (var name in BackgroundProcessNames)
        {
            try
            {
                var processes = Process.GetProcessesByName(name);
                foreach (var proc in processes)
                {
                    if (proc.Id == currentPid)
                        continue; // don't kill ourselves

                    try
                    {
                        proc.Kill();
                        proc.WaitForExit(3000);
                        DiagnosticLogger.Debug("CLEANUP", $"Killed {name} (PID {proc.Id})");
                    }
                    catch (Exception ex)
                    {
                        DiagnosticLogger.Debug("CLEANUP", $"Failed to kill {name} PID {proc.Id}: {ex.Message}");
                    }
                    finally
                    {
                        proc.Dispose();
                    }
                }
            }
            catch (Exception ex)
            {
                DiagnosticLogger.Debug("CLEANUP", $"Error scanning for {name}: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Returns true if another process with the same name as the current process is already running.
    /// Used for single-instance enforcement without mutexes.
    /// </summary>
    public static bool IsAnotherInstanceRunning()
    {
        var currentProcess = Process.GetCurrentProcess();
        var processName = currentProcess.ProcessName;
        var currentPid = currentProcess.Id;

        try
        {
            var others = Process.GetProcessesByName(processName)
                .Where(p => p.Id != currentPid);

            var found = others.Any();

            foreach (var p in others)
                p.Dispose();

            return found;
        }
        catch
        {
            return false; // can't check, assume we're the only one
        }
    }
}
