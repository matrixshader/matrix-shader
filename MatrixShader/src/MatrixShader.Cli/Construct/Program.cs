using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using MatrixShader.Core.Constants;
using MatrixShader.Core.Helpers;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MatrixShader.Cli.Construct;

/// <summary>
/// construct - Enter the Construct. Pick your reality.
/// No args = white room color picker (CRT TV experience)
/// --pick = internal: run picker input loop inside WT window
/// --color = direct launch with specific color
/// </summary>
public static class Program
{
    private static readonly Dictionary<string, MatrixColor> ColorMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["green"] = ColorPresets.Green,
        ["blue"] = ColorPresets.Blue,
        ["red"] = ColorPresets.Red,
        ["purple"] = ColorPresets.Purple,
        ["gold"] = ColorPresets.Gold,
        ["teal"] = ColorPresets.Teal,
    };

    public static int Main(string[] args)
    {
        // Earliest possible window manipulation — runs before DI overhead.
        // WT's --fullscreen flag should have already handled this. F11 is only a
        // fallback if --fullscreen didn't work (otherwise F11 toggles OUT).
        if (args.Length >= 1 && args[0] == "--pick")
        {
            var wtHwnd = WindowsApi.GetForegroundWindow();
            if (wtHwnd != nint.Zero)
            {
                int screenW = WindowsApi.GetSystemMetrics(WindowsApi.SM_CXSCREEN);
                int screenH = WindowsApi.GetSystemMetrics(WindowsApi.SM_CYSCREEN);
                // Check if window is already fullscreen (--fullscreen flag worked)
                WindowsApi.GetWindowRect(wtHwnd, out var rect);
                bool alreadyFullscreen = rect.Width >= screenW && rect.Height >= screenH;
                if (!alreadyFullscreen)
                {
                    // Fallback: force fullscreen manually
                    WindowsApi.SetWindowPos(wtHwnd, WindowsApi.HWND_TOP, 0, 0, screenW, screenH, 0);
                    WindowsApi.ShowWindow(wtHwnd, WindowsApi.SW_SHOWMAXIMIZED);
                    Thread.Sleep(50);
                    WindowsApi.keybd_event(WindowsApi.VK_F11, 0, 0, 0);
                    WindowsApi.keybd_event(WindowsApi.VK_F11, 0, WindowsApi.KEYEVENTF_KEYUP, 0);
                }
            }
        }

        var services = new ServiceCollection();
        services.AddSingleton<IConfigService, ConfigService>();
        services.AddSingleton<IShaderService, ShaderService>();
        services.AddSingleton<ITerminalSettingsService, TerminalSettingsService>();
        services.AddSingleton<IIdentityService, IdentityService>();
        services.AddSingleton<ILayoutService, LayoutService>();
        services.AddLogging(b => b.SetMinimumLevel(LogLevel.Warning));
        var provider = services.BuildServiceProvider();

        var configService = provider.GetRequiredService<IConfigService>();
        var shaderService = provider.GetRequiredService<IShaderService>();
        var terminalService = provider.GetRequiredService<ITerminalSettingsService>();
        var identityService = provider.GetRequiredService<IIdentityService>();
        var layoutService = provider.GetRequiredService<ILayoutService>();

        if (args.Length >= 1 && args[0] == "--pick")
        {
            var profileArg = args.SkipWhile(a => a != "--profile").Skip(1).FirstOrDefault() ?? "Construct";
            return RunPicker(profileArg, configService, shaderService, terminalService, identityService, layoutService);
        }

        var color = ParseColor(args);
        if (color == null) { ShowHelp(); return 1; }

        if (args.Length == 0)
            return RunWhiteRoom(terminalService);

        return LaunchWithColor(color.Value, configService, shaderService, terminalService, identityService, layoutService);
    }

    private static int LaunchWithColor(
        MatrixColor color,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService,
        ILayoutService layoutService)
    {
        // Enable ANSI escape codes for colored output in cmd.exe / PowerShell
        ConsoleHelper.EnableAnsiEscapeCodes();

        var state = configService.LoadState();
        int slot = FindAndReserveSlot(shaderService, identityService);
        if (slot == -1)
        {
            Console.WriteLine("\x1b[31mAll 8 shader slots are in use. Close a Matrix window first.\x1b[0m");
            return 1;
        }

        var config = new ShaderConfig().WithColor(color.R, color.G, color.B);
        if (shaderService.ShaderExists(slot))
            shaderService.WriteConfig(slot, config);
        else
            shaderService.CreateShader(slot, config);

        var shadersDir = CliBootstrap.GetShadersDirectory();

        // Surgical upsert: only touches the ONE target profile in settings.json.
        // Preserves all other profiles, properties, and formatting untouched.
        // This prevents killing the calling tab (full deserialize+serialize was
        // stripping "source" from WSL/Azure profiles and injecting default values
        // like opacity/useAcrylic into non-Matrix profiles, causing WT to see a
        // massive diff and reload/kill all tabs).
        var profileName = $"Matrix-{slot}";
        var existingGuid = terminalService.GetProfileGuid(profileName);
        var (r, g, b) = color.ToRgb();
        var profile = new TerminalProfile
        {
            Name = profileName,
            Guid = existingGuid ?? $"{{{Guid.NewGuid()}}}",
            // Set window title to "Matrix-{slot}" for Layer 3 identity detection.
            Commandline = $"powershell.exe -NoExit -Command \"$host.UI.RawUI.WindowTitle = 'Matrix-{slot}'; Write-Host ' Matrix Terminal {slot}' -ForegroundColor Green\"",
            Hidden = true,
            Opacity = 85,
            UseAcrylic = false,
            PixelShaderPath = Path.Combine(shadersDir, $"Matrix-{slot}.hlsl"),
            TabColor = $"#{r:X2}{g:X2}{b:X2}",
            Foreground = $"#{r:X2}{g:X2}{b:X2}",
            FontFace = "Nimbus Mono PS",
            FontSize = 16,
            FontWeight = "bold",
            SuppressApplicationTitle = false  // Allow commandline to set window title
        };
        terminalService.UpsertProfileSurgical(profile);

        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);

        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
        try
        {
            // -w -1 forces a NEW WT window regardless of windowingBehavior setting.
            // Named window IDs (e.g. _matrix_{guid}) are subject to windowingBehavior
            // and can silently merge into an existing window as a tab.
            Process.Start(new ProcessStartInfo
            {
                FileName = wtPath,
                Arguments = $"-w -1 -p \"{profileName}\"",
                UseShellExecute = true
            });
            Console.WriteLine($"\x1b[38;2;{r};{g};{b}m{color.Name}\x1b[0m Matrix window launched (slot {slot}).");
            ConsoleHelper.ShowCommandBanner();

            // Wait for the new window to appear, then run the same layout pass
            // that bluepill uses — CalculateLayout distributes across monitors.
            WaitForWindowThenLayout(slot, identityService, layoutService, configService);

            // Ensure the hotkeys/Glitch system is running for ongoing management.
            EnsureHotkeyProcessRunning();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mFailed to launch Windows Terminal: {ex.Message}\x1b[0m");
            return 1;
        }
        return 0;
    }

    /// <summary>
    /// Waits for a newly launched WT window to appear, then runs the same layout
    /// pass that bluepill uses: CalculateLayout distributes windows evenly across
    /// all monitors, then ApplyLayout positions them.
    /// </summary>
    private static void WaitForWindowThenLayout(
        int slot,
        IIdentityService identityService,
        ILayoutService layoutService,
        IConfigService configService)
    {
        var targetTitle = $"Matrix-{slot}";
        var sw = Stopwatch.StartNew();
        const int maxWaitMs = 5000;
        const int pollIntervalMs = 250;

        // Poll for the new window by title
        while (sw.ElapsedMilliseconds < maxWaitMs)
        {
            Thread.Sleep(pollIntervalMs);
            var windows = identityService.FindMatrixWindows();
            foreach (var w in windows)
            {
                if (w.ShaderIndex == slot)
                {
                    // New window found — clear reservation and run layout
                    ClearReservation(slot);
                    Thread.Sleep(500); // Let window finish initializing
                    var allWindows = identityService.FindMatrixWindows()
                        .Where(mw => !mw.IsControlPanel && !mw.IsConstruct)
                        .ToList();
                    if (allWindows.Count > 0)
                    {
                        var layoutConfig = configService.LoadState().Layout;
                        var positions = layoutService.CalculateLayout(allWindows, layoutConfig);
                        layoutService.ApplyLayout(positions);
                    }
                    return;
                }
            }
        }
        // Timeout — not fatal, Glitch will handle it eventually
    }

    /// <summary>
    /// Ensures exactly one matrix-hotkeys.exe is running so the Glitch system can detect
    /// and auto-tile new Matrix windows with any existing ones.
    /// Kills duplicates if multiple instances exist (orphan cleanup).
    /// </summary>
    private static void EnsureHotkeyProcessRunning()
    {
        var existing = Process.GetProcessesByName("matrix-hotkeys");

        if (existing.Length == 1)
        {
            // Exactly one running — all good
            foreach (var p in existing) p.Dispose();
            return;
        }

        if (existing.Length > 1)
        {
            // Duplicates — kill all, will restart one fresh below
            DiagnosticLogger.Debug("CONSTRUCT", $"Found {existing.Length} hotkey processes, cleaning up");
            foreach (var p in existing)
            {
                try { p.Kill(); p.WaitForExit(3000); } catch { }
                p.Dispose();
            }
        }

        // Start one fresh instance
        var hotkeyPath = Path.Combine(AppContext.BaseDirectory, "matrix-hotkeys.exe");
        if (!File.Exists(hotkeyPath)) return;

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = hotkeyPath,
                WindowStyle = ProcessWindowStyle.Hidden,
                UseShellExecute = true
            });
        }
        catch { /* Non-fatal — window just won't auto-tile */ }
    }

    private static int RunWhiteRoom(ITerminalSettingsService terminalService)
    {
        // Clean up any stale Construct profiles from previous sessions that were
        // not properly removed (user pressed Escape without cleanup, process crashed,
        // etc.). Each construct launch creates a unique "Construct-{id}" profile,
        // and orphans accumulate over time, eventually causing GUID conflicts or bloat.
        try { terminalService.RemoveProfilesByPrefixSurgical("Construct-"); }
        catch { /* Non-fatal cleanup */ }

        var shadersDir = CliBootstrap.GetShadersDirectory();
        var whiteRoomPath = DeployWhiteRoomShader(shadersDir);
        if (whiteRoomPath == null)
        {
            Console.WriteLine("\x1b[31mFailed to deploy WhiteRoom.hlsl shader.\x1b[0m");
            return 1;
        }

        // Write initial state: STATE=1 (picking mode)
        WriteShaderState(whiteRoomPath, state: 1, stateTime: 0.0f);

        var exePath = Process.GetCurrentProcess().MainModule?.FileName
                      ?? Path.Combine(AppContext.BaseDirectory, "construct.exe");

        // Each launch gets a unique profile so it doesn't overwrite running windows.
        var instanceId = Guid.NewGuid().ToString("N")[..6];
        var profileName = $"Construct-{instanceId}";
        var constructProfile = new TerminalProfile
        {
            Name = profileName,
            Guid = $"{{{Guid.NewGuid()}}}",
            Commandline = $"\"{exePath}\" --pick --profile {profileName}",
            Hidden = true,
            Opacity = 100,
            UseAcrylic = false,
            PixelShaderPath = whiteRoomPath,  // Shader defaults to BLACK until C# writes state (R=0 guard)
            TabColor = "#000000",
            Background = "#000000",        // Pure black until shader loads
            Foreground = "#000000",        // Hide any console output
            SuppressApplicationTitle = false
        };
        terminalService.UpsertProfileSurgical(constructProfile);

        var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
        try
        {
            // -w -1 forces a NEW WT window regardless of windowingBehavior setting.
            // --fullscreen (-F) launches it directly in fullscreen mode.
            // Named window IDs (e.g. _construct_{guid}) are subject to windowingBehavior
            // and can silently merge into an existing window as a tab before --fullscreen
            // takes effect, causing the "opens as tab then resizes" bug.
            Process.Start(new ProcessStartInfo
            {
                FileName = wtPath,
                Arguments = $"-w -1 --fullscreen -p \"{profileName}\"",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mFailed to launch Windows Terminal: {ex.Message}\x1b[0m");
            return 1;
        }
        return 0;
    }

    /// <summary>
    /// Picker input loop — runs INSIDE the WT window (launched via --pick).
    /// Selection is communicated to the shader via ANSI-colored terminal output,
    /// not via file writes. The shader reads shaderTexture to determine selection.
    /// </summary>
    private static int RunPicker(
        string constructProfileName,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService,
        ILayoutService layoutService)
    {
        var shadersDir = CliBootstrap.GetShadersDirectory();
        var whiteRoomPath = Path.Combine(shadersDir, "WhiteRoom.hlsl");
        if (!File.Exists(whiteRoomPath)) return 1;

        int selected = 0;
        try { Console.CursorVisible = false; } catch { }
        try { Console.Title = "Construct"; } catch { }

        // Write picker state — this sets shaderTexture R > 0, which signals the
        // WhiteRoom shader to start rendering (it stays BLACK while R = 0).
        WritePickerState(selected, 0);
        Thread.Sleep(1500); // Hold white void before showing TV dot

        // Show tiny dot, hold briefly
        WritePickerState(selected, 1); // zoom=1/255 ≈ 0.02 (tiny speck)
        Thread.Sleep(500);

        // Quick zoom in over 1.2 seconds, ease-out curve, ~60fps
        var sw = Stopwatch.StartNew();
        const double zoomDurationMs = 1200.0;
        while (sw.ElapsedMilliseconds < zoomDurationMs)
        {
            double t = sw.ElapsedMilliseconds / zoomDurationMs;
            // Ease-out cubic: fast start, gentle arrival
            double eased = 1.0 - Math.Pow(1.0 - t, 3.0);
            int zoomByte = (int)(eased * 255.0);
            WritePickerState(selected, zoomByte);
            Thread.Sleep(16); // ~60fps
        }
        // Ensure we land exactly at full zoom
        WritePickerState(selected, 255);

        try
        {
            while (true)
            {
                var keyInfo = Console.ReadKey(intercept: true);
                switch (keyInfo.Key)
                {
                    case ConsoleKey.LeftArrow:
                        selected = (selected - 1 + 6) % 6;
                        break;
                    case ConsoleKey.RightArrow:
                        selected = (selected + 1) % 6;
                        break;
                    case ConsoleKey.UpArrow:
                    case ConsoleKey.DownArrow:
                        selected = (selected + 3) % 6;
                        break;
                    case ConsoleKey.Enter:
                        // Check slot availability BEFORE starting the irreversible animation
                        int slot = FindAndReserveSlot(shaderService, identityService);
                        if (slot == -1)
                        {
                            // All 8 slots full — flash error and continue picking
                            continue;
                        }

                        // CRT power-off animation via shaderTexture
                        AnimatePowerOff(selected);

                        // Exit fullscreen before transition (glitch needs to position the window)
                        WindowsApi.keybd_event(WindowsApi.VK_F11, 0, 0, 0);
                        WindowsApi.keybd_event(WindowsApi.VK_F11, 0, WindowsApi.KEYEVENTF_KEYUP, 0);

                        // Same-window transition (no new window!)
                        var selectedColor = ColorPresets.All[selected];
                        TransitionToRain(selectedColor, slot, constructProfileName,
                                         configService, shaderService, terminalService,
                                         identityService, layoutService, shadersDir);
                        // Restore console mode — Console.ReadKey disables LINE_INPUT and
                        // ECHO_INPUT, which makes the inherited console unusable for PowerShell.
                        try { Console.CursorVisible = true; } catch { }
                        WindowsApi.RestoreConsoleMode();

                        // Ensure hotkeys + Glitch system are running
                        EnsureHotkeyProcessRunning();

                        // Hand off to an interactive shell so the terminal is usable.
                        // PowerShell inherits our console handle (UseShellExecute=false).
                        // When the user exits the shell, construct.exe exits and WT closes the tab.
                        var shell = Process.Start(new ProcessStartInfo
                        {
                            FileName = "powershell.exe",
                            Arguments = "-NoExit",
                            UseShellExecute = false,
                        });
                        shell?.WaitForExit();
                        return 0;

                    case ConsoleKey.Escape:
                        AnimatePowerOff(selected);
                        // Clean up Construct profile — without this, the profile stays
                        // in settings.json as an orphan with a unique GUID.
                        terminalService.RemoveProfileSurgical(constructProfileName);
                        return 0;

                    default:
                        continue;
                }

                // Instant: write state to terminal — shader reads it next frame
                WritePickerState(selected, 255);
            }
        }
        finally
        {
            try { Console.CursorVisible = true; } catch { }
        }
    }

    /// <summary>
    /// Writes picker state to the terminal as ANSI-colored background blocks.
    /// The shader samples shaderTexture at the top-left to read state.
    /// Encoding:
    ///   R = (selected+1) * 40  (values: 40, 80, 120, 160, 200, 240)
    ///   G = zoom byte 0-255    (0 = far/small, 255 = close/full size)
    ///   B = power-off byte 0-255 (0 = normal, 255 = fully black)
    /// </summary>
    private static void WritePickerState(int selected, int zoomByte, int powerOffByte = 0)
    {
        int r = (selected + 1) * 40;
        int g = Math.Clamp(zoomByte, 0, 255);
        int b = Math.Clamp(powerOffByte, 0, 255);
        Console.Write($"\x1b[H\x1b[48;2;{r};{g};{b}m{new string(' ', 80)}\x1b[0m");
    }

    /// <summary>
    /// Animates CRT power-off: zoom shrinks to a point while brightness fades to black.
    /// Driven entirely via shaderTexture (G=zoom, B=brightness), no file writes needed.
    /// </summary>
    private static void AnimatePowerOff(int selected)
    {
        var sw = Stopwatch.StartNew();
        const double durationMs = 1000.0;
        while (sw.ElapsedMilliseconds < durationMs)
        {
            double t = sw.ElapsedMilliseconds / durationMs;
            // Ease-in: slow start, accelerates (CRT shrink feel)
            double eased = t * t;
            // Zoom shrinks from 255 (full) to ~20 (tiny point)
            int zoomByte = (int)(255.0 * (1.0 - eased * 0.92));
            // Brightness fades: starts fading at t=0.4, fully black by t=1.0
            double fadeT = Math.Clamp((t - 0.4) / 0.6, 0.0, 1.0);
            int powerByte = (int)(fadeT * 255.0);
            WritePickerState(selected, zoomByte, powerByte);
            Thread.Sleep(16);
        }
        // Hold black
        WritePickerState(selected, 0, 255);
        Thread.Sleep(200);
    }

    /// <summary>
    /// Performs same-window transition from Construct white room to Matrix rain.
    /// Modifies the Construct profile IN PLACE in settings.json — swapping the shader
    /// path, opacity, and tab color. WT detects the change and loads the new shader
    /// into the already-open window. The profile name stays "Construct" to avoid
    /// GUID conflicts with UpsertProfile.
    /// </summary>
    private static void TransitionToRain(
        MatrixColor color,
        int slot,
        string constructProfileName,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalService,
        IIdentityService identityService,
        ILayoutService layoutService,
        string shadersDir)
    {
        // 1. Create rain shader — identical to a normal Matrix launch (FADE_DURATION=0)
        var config = new ShaderConfig().WithColor(color.R, color.G, color.B);
        shaderService.CreateShader(slot, config);

        // 2. GUID swap via ATOMIC replace: remove the Construct profile and create
        //    the Matrix-{slot} profile in a SINGLE file write. WT follows the GUID,
        //    so the running tab seamlessly becomes a Matrix-{slot} window.
        //    Using ReplaceProfileSurgical prevents the duplicate-GUID popup that
        //    occurred when separate upsert+remove left an intermediate state where
        //    two profiles shared the same GUID and WT's file watcher detected it.
        var constructGuid = terminalService.GetProfileGuid(constructProfileName);
        var matrixProfileName = $"Matrix-{slot}";
        if (constructGuid != null)
        {
            var (r, g, b) = color.ToRgb();
            var matrixProfile = new TerminalProfile
            {
                Name = matrixProfileName,
                Guid = constructGuid,  // GUID swap: WT follows this to the new profile
                Commandline = $"powershell.exe -NoExit -Command \"$host.UI.RawUI.WindowTitle = 'Matrix-{slot}'; Write-Host ' Matrix Terminal {slot}' -ForegroundColor Green\"",
                Hidden = true,
                PixelShaderPath = Path.Combine(shadersDir, $"Matrix-{slot}.hlsl"),
                Opacity = 85,
                UseAcrylic = false,
                TabColor = $"#{r:X2}{g:X2}{b:X2}",
                Foreground = $"#{r:X2}{g:X2}{b:X2}",
                SuppressApplicationTitle = false
            };

            // Atomic: remove Construct + upsert Matrix in one write — no intermediate duplicate GUID state.
            terminalService.ReplaceProfileSurgical(constructProfileName, matrixProfile);
        }

        // 3. Persist shader state
        var state = configService.LoadState();
        state.ShaderConfigs[slot] = config;
        configService.SaveState(state);

        // 4. Register window identity so Redpill and hotkeys can find it
        var hwnd = WindowsApi.GetForegroundWindow();
        if (hwnd != nint.Zero)
        {
            identityService.RegisterWindowHandle(hwnd, $"Matrix-{slot}", slot);
        }

        // 5. Wait for WT to detect settings.json change and load new shader.
        //    Must be long enough for WT file watcher + shader compilation.
        //    Screen is held at powerOff=255 (black) so the delay is invisible.
        //    Too short → WhiteRoom shader is still active when we clear terminal,
        //    causing a flash of the small TV (zoom=0, powerOff=0).
        Thread.Sleep(1500);

        // 6. Snap into layout alongside existing Matrix windows.
        //    After F11 exit, WT uses its default restored size. Run the full layout
        //    pass so this window joins the pillar layout with others.
        Thread.Sleep(300); // Let WT settle after F11 exit
        var allWindows = identityService.FindMatrixWindows()
            .Where(w => !w.IsControlPanel && !w.IsConstruct)
            .ToList();
        if (allWindows.Count > 0)
        {
            var layoutState = configService.LoadState();
            var positions = layoutService.CalculateLayout(allWindows, layoutState.Layout);
            layoutService.ApplyLayout(positions);
        }

        // 7. Clear leftover ANSI background (prevents pink bar in shaderTexture)
        //    and set window title for Layer 3 identity detection.
        //    Safe now because Matrix rain shader is loaded (doesn't read zoom/powerOff).
        Console.Write("\x1b[0m\x1b[2J\x1b[H");
        Console.Title = $"Matrix-{slot}";
    }

    /// <summary>
    /// Write STATE and STATE_TIME to shader file (only for state transitions like power-off).
    /// Selection is handled via terminal output, not file writes.
    /// </summary>
    private static void WriteShaderState(string shaderPath, int state, float stateTime)
    {
        var content = File.ReadAllText(shaderPath);
        content = Regex.Replace(content, @"(#define\s+STATE\s+)\d+", $"${{1}}{state}");
        content = Regex.Replace(content,
            @"(#define\s+STATE_TIME\s+)[\d.]+",
            m => m.Groups[1].Value + stateTime.ToString("F2", CultureInfo.InvariantCulture));

        var tempPath = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tempPath, content, new UTF8Encoding(false));
            File.Move(tempPath, shaderPath, overwrite: true);
            File.SetLastWriteTimeUtc(shaderPath, DateTime.UtcNow);
        }
        catch
        {
            if (File.Exists(tempPath)) File.Delete(tempPath);
            throw;
        }
    }

    private static string? DeployWhiteRoomShader(string shadersDir)
    {
        var targetPath = Path.Combine(shadersDir, "WhiteRoom.hlsl");
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "shaders", "WhiteRoom.hlsl"),
            Path.Combine(CliBootstrap.GetInstalledShadersDirectory(), "WhiteRoom.hlsl"),
        };
        var sourcePath = candidates.FirstOrDefault(File.Exists);
        if (sourcePath == null)
            return File.Exists(targetPath) ? targetPath : null;
        try
        {
            if (!Directory.Exists(shadersDir)) Directory.CreateDirectory(shadersDir);
            File.Copy(sourcePath, targetPath, overwrite: true);
            return targetPath;
        }
        catch { return File.Exists(targetPath) ? targetPath : null; }
    }

    private static float GetApproxShaderTime()
    {
        foreach (var name in new[] { "WindowsTerminal", "WindowsTerminalPreview" })
        {
            var procs = Process.GetProcessesByName(name);
            if (procs.Length > 0)
                return (float)(DateTime.UtcNow - procs[0].StartTime.ToUniversalTime()).TotalSeconds;
        }
        return 0f;
    }

    /// <summary>
    /// Finds an available shader slot AND atomically reserves it via a lock file.
    /// Uses a named Mutex so concurrent construct.exe processes don't claim the same slot.
    /// Without this, rapid launches (construct --green & construct --red & ...) all see
    /// slot 1 as available because the previous window hasn't set its title yet.
    /// </summary>
    private static int FindAndReserveSlot(IShaderService shaderService, IIdentityService identityService)
    {
        using var mutex = new Mutex(false, @"Global\MatrixShader_SlotReservation");
        try { mutex.WaitOne(TimeSpan.FromSeconds(5)); }
        catch (AbandonedMutexException) { /* Previous process crashed — safe to proceed */ }

        try
        {
            var usedSlots = new HashSet<int>(identityService.FindMatrixWindows()
                .Where(w => w.ShaderIndex > 0 && !w.IsControlPanel)
                .Select(w => w.ShaderIndex));

            for (int i = 1; i <= 8; i++)
            {
                if (!usedSlots.Contains(i) && !IsSlotReserved(i))
                {
                    ReserveSlot(i);
                    return i;
                }
            }
            return -1;
        }
        finally
        {
            mutex.ReleaseMutex();
        }
    }

    private static string GetSlotLockPath(int slot)
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(localAppData, "MatrixShader", $"slot-{slot}.lock");
    }

    private static bool IsSlotReserved(int slot)
    {
        var lockPath = GetSlotLockPath(slot);
        if (!File.Exists(lockPath)) return false;
        var age = DateTime.UtcNow - File.GetLastWriteTimeUtc(lockPath);
        return age.TotalSeconds < 30;
    }

    private static void ReserveSlot(int slot)
    {
        var lockPath = GetSlotLockPath(slot);
        var dir = Path.GetDirectoryName(lockPath)!;
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        File.WriteAllText(lockPath, DateTime.UtcNow.ToString("O"));
    }

    private static void ClearReservation(int slot)
    {
        try { var p = GetSlotLockPath(slot); if (File.Exists(p)) File.Delete(p); } catch { }
    }

    private static MatrixColor? ParseColor(string[] args)
    {
        if (args.Length == 0) return ColorPresets.Green;
        if (args.Contains("--help") || args.Contains("-h") || args.Contains("/?")) return null;
        foreach (var arg in args)
        {
            if (!arg.StartsWith("--")) continue;
            var name = arg.Substring(2);
            if (ColorMap.TryGetValue(name, out var color)) return color;
        }
        Console.WriteLine($"\x1b[31mUnknown color: {args[0]}\x1b[0m");
        return null;
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        Console.WriteLine("\x1b[32m CONSTRUCT\x1b[0m \u2014 Enter the Construct. Pick your reality.");
        Console.WriteLine();
        Console.WriteLine(" Usage: construct          Launch white room color picker");
        Console.WriteLine("        construct --[color] Launch with specific color");
        Console.WriteLine();
        Console.WriteLine(" Colors:");
        foreach (var preset in ColorPresets.All)
        {
            var (r, g, b) = preset.ToRgb();
            Console.WriteLine($"   \x1b[38;2;{r};{g};{b}m--{preset.Name.ToLower(),-12}\x1b[0m {preset.Description}");
        }
        Console.WriteLine();
    }
}
