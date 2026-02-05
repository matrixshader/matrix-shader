# Phase 14: Final Polish & Hotkey Stability - Research

**Researched:** 2026-02-03
**Domain:** Hotkey service stability, Windows Terminal transparency, process monitoring, layout gaps
**Confidence:** HIGH

## Summary

Phase 14 fixes 12 bugs from one-liner E2E testing. Research focused on four key areas:

1. **Hotkey Service Stability (BUG-HK01-04):** The `matrix-hotkeys.exe` process dies silently, likely due to unhandled exceptions in the message pump. The matrix-monitor process needs to supervise and auto-restart it. The glitch/snap functionality must be moved from redpill dependency to background service.

2. **Transparency (BUG-TRANS04-05):** Windows Terminal has TWO transparency modes: `useAcrylic: true` creates blurred/frosted glass effect, `useAcrylic: false` creates clear transparency (Windows 11 only). Current code sets `UseAcrylic = true` which causes the "hazy" appearance user dislikes. For uninstall, need to backup original settings.json before first modification.

3. **Shader Cycling Removal (BUG-SHADER04-05):** Per user decision, shader cycling feature is being REMOVED entirely. This simplifies the codebase and eliminates the color/parameter corruption bugs.

4. **Layout Issues (BUG-LAYOUT05-07):** Gap scaling needs window count awareness. Fullscreen detection requires `IsZoomed()` check. Drag-and-snap state corruption needs investigation.

**Primary recommendation:** Implement in priority order - hotkey stability first (critical), then transparency fixes, then layout issues, then cleanup (remove shader cycling, rename cyan).

## Standard Stack

This phase uses existing project stack with no new dependencies.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| .NET 8 | 8.0 | Runtime | Already used |
| P/Invoke (user32.dll) | N/A | Window state APIs | Existing WindowsApi.cs |
| System.Diagnostics.Process | Built-in | Process monitoring | BCL, AOT-compatible |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| System.Threading.Timer | Built-in | Process health polling | Watchdog pattern |
| System.IO.File | Built-in | Settings backup | Backup/restore |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Timer-based process check | WaitForExit with callback | WaitForExit blocks thread; timer is non-blocking |
| Manual backup file | Windows Volume Shadow Copy | VSC is complex; simple file copy sufficient |
| Full process watchdog library | Built-in Process class | No need for external dependency for simple case |

## Architecture Patterns

### Recommended Changes by Component

```
MatrixShader/
├── src/
│   ├── MatrixShader.Core/
│   │   ├── Native/
│   │   │   └── WindowsApi.cs          # ADD: IsZoomed() for fullscreen detection
│   │   └── Services/
│   │       └── TerminalSettingsService.cs  # MODIFY: Backup/restore, plain transparency
│   ├── MatrixShader.Hotkeys/
│   │   ├── Program.cs                 # MODIFY: Add exception handler, stay-alive timer
│   │   ├── MatrixWindowMonitor.cs     # MODIFY: Fullscreen exclusion in glitch
│   │   └── HotkeyActions.cs           # MODIFY: Remove CycleShader, fix SwapLeft/Right
│   └── MatrixShader.Monitor/
│       └── Program.cs                 # MODIFY: Add hotkey process supervision
└── installer/
    └── uninstall.ps1                  # MODIFY: Restore original WT settings
```

### Pattern 1: Process Watchdog for Hotkey Service

**What:** matrix-monitor.exe monitors matrix-hotkeys.exe and auto-restarts on crash.
**When to use:** Always - critical for BUG-HK01 fix.
**Example:**
```csharp
// Source: .NET Process monitoring patterns
public class HotkeyProcessSupervisor : IDisposable
{
    private Process? _hotkeyProcess;
    private readonly Timer _healthCheck;
    private readonly string _hotkeyExePath;
    private readonly TimeSpan _restartDelay = TimeSpan.FromSeconds(2);

    public HotkeyProcessSupervisor(string hotkeyExePath)
    {
        _hotkeyExePath = hotkeyExePath;
        _healthCheck = new Timer(CheckHealth, null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
    }

    private void CheckHealth(object? state)
    {
        if (_hotkeyProcess == null || _hotkeyProcess.HasExited)
        {
            DiagnosticLogger.Warn("MONITOR", "Hotkey process not running, restarting...");
            StartHotkeyProcess();
        }
    }

    private void StartHotkeyProcess()
    {
        try
        {
            _hotkeyProcess = Process.Start(new ProcessStartInfo
            {
                FileName = _hotkeyExePath,
                CreateNoWindow = true,
                UseShellExecute = false
            });
            DiagnosticLogger.Info("MONITOR", $"Hotkey process started: PID {_hotkeyProcess?.Id}");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("MONITOR", $"Failed to start hotkey process: {ex.Message}");
        }
    }

    public void Dispose()
    {
        _healthCheck.Dispose();
        // Don't kill the process - let it continue running
    }
}
```

### Pattern 2: Stay-Alive Timer (30 seconds after last window closes)

**What:** Hotkey service waits 30 seconds after all Matrix windows close before exiting.
**When to use:** BUG-HK01 - allows window recreation without service restart.
**Example:**
```csharp
// In MatrixWindowMonitor.cs - modify CheckWindows()
private DateTime _lastWindowSeen = DateTime.Now;
private const int StayAliveSeconds = 30;

private void CheckWindows(object? state)
{
    var windows = _identityService.FindMatrixWindows()
        .Where(w => !w.IsControlPanel)
        .ToList();

    if (windows.Count > 0)
    {
        _lastWindowSeen = DateTime.Now;
        _noWindowCount = 0;
        CheckForOverlap(windows);
    }
    else
    {
        // Check if stay-alive period has elapsed
        var elapsed = DateTime.Now - _lastWindowSeen;
        if (elapsed.TotalSeconds >= StayAliveSeconds)
        {
            DiagnosticLogger.Info("HOTKEYS", $"No Matrix windows for {StayAliveSeconds}s, exiting");
            _onNoWindows();
        }
        else
        {
            DiagnosticLogger.Debug("HOTKEYS",
                $"No windows, stay-alive: {StayAliveSeconds - (int)elapsed.TotalSeconds}s remaining");
        }
    }
}
```

### Pattern 3: Plain Transparency (No Acrylic Blur)

**What:** Set `useAcrylic: false` for clear transparency without frosted glass effect.
**When to use:** BUG-TRANS04 - user explicitly wants no blur.
**Critical Note:** Windows 11 only for unblurred transparency. Windows 10 requires acrylic for any transparency.
**Example:**
```csharp
// In TerminalSettingsService.CreateMatrixProfiles() - line 197
var profile = new TerminalProfile
{
    Name = profileName,
    Guid = $"{{{Guid.NewGuid()}}}",
    Commandline = $"powershell.exe -NoExit -Command \"Write-Host ' Matrix Terminal {i}' -ForegroundColor Green\"",
    Hidden = true,
    Opacity = 85,  // 85% opacity for Matrix windows only
    UseAcrylic = false,  // CHANGED: Plain transparency, no blur
    PixelShaderPath = Path.Combine(shadersDirectory, $"Matrix-{i}.hlsl")
};
```

### Pattern 4: Settings Backup and Restore

**What:** Backup original settings.json before Matrix modifies it, restore on uninstall.
**When to use:** BUG-TRANS05 - persistence fix.
**Example:**
```csharp
// In TerminalSettingsService - add backup methods
public string OriginalBackupPath => SettingsPath + ".matrix-original";

public bool CreateOriginalBackup()
{
    // Only create if it doesn't exist (preserve FIRST original state)
    if (File.Exists(OriginalBackupPath))
    {
        DiagnosticLogger.Debug("TERMINAL", "Original backup already exists, preserving");
        return true;
    }

    if (!SettingsExist)
        return false;

    try
    {
        File.Copy(SettingsPath, OriginalBackupPath);
        DiagnosticLogger.Info("TERMINAL", $"Created original backup: {OriginalBackupPath}");
        return true;
    }
    catch (Exception ex)
    {
        DiagnosticLogger.Warn("TERMINAL", $"Failed to create original backup: {ex.Message}");
        return false;
    }
}

public bool RestoreOriginalSettings()
{
    if (!File.Exists(OriginalBackupPath))
    {
        DiagnosticLogger.Warn("TERMINAL", "No original backup to restore");
        return false;
    }

    try
    {
        File.Copy(OriginalBackupPath, SettingsPath, overwrite: true);
        DiagnosticLogger.Info("TERMINAL", "Restored original settings");
        return true;
    }
    catch (Exception ex)
    {
        DiagnosticLogger.Error("TERMINAL", $"Failed to restore settings: {ex.Message}");
        return false;
    }
}
```

### Pattern 5: Fullscreen Window Detection

**What:** Detect if window is maximized/fullscreen using IsZoomed().
**When to use:** BUG-LAYOUT06-07 - exclude fullscreen windows from glitch/snap.
**Example:**
```csharp
// Add to WindowsApi.cs
/// <summary>
/// Determines whether the specified window is maximized.
/// </summary>
[LibraryImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static partial bool IsZoomed(nint hWnd);

// In MatrixWindowMonitor.CheckForOverlap() - filter fullscreen
private void CheckForOverlap(List<WindowInfo> windows)
{
    // Filter out fullscreen windows - they should not participate in glitch
    var tiledWindows = windows
        .Where(w => !WindowsApi.IsZoomed(w.Handle))
        .ToList();

    if (tiledWindows.Count < 2)
        return;

    // ... rest of overlap detection on tiledWindows only
}
```

### Pattern 6: Window Position Rotation (Not Swap)

**What:** Ctrl+Shift+Left/Right rotates focused window through ALL positions (1->2->3->4->1).
**When to use:** BUG-HK02 - user wants rotation, not just neighbor swap.
**Example:**
```csharp
// Replace SwapLeft/SwapRight in HotkeyActions.cs
private void RotateLeft()
{
    try
    {
        var windows = _identityService.FindMatrixWindows()
            .Where(w => !w.IsControlPanel && !WindowsApi.IsZoomed(w.Handle))
            .OrderBy(w => w.Position.Left)
            .ToList();

        if (windows.Count < 2)
            return;

        var foreground = WindowsApi.GetForegroundWindow();
        var currentIdx = windows.FindIndex(w => w.Handle == foreground);

        if (currentIdx < 0)
            return;

        // Calculate previous position index (wrap around)
        var targetIdx = (currentIdx - 1 + windows.Count) % windows.Count;

        // Move current window to target position
        var targetPos = windows[targetIdx].Position;
        WindowsApi.PositionWindowExact(windows[currentIdx].Handle, targetPos);

        // Shift all windows between target and current to the right
        for (int i = targetIdx; i != currentIdx; i = (i + 1) % windows.Count)
        {
            var nextIdx = (i + 1) % windows.Count;
            if (nextIdx == currentIdx) break;
            WindowsApi.PositionWindowExact(windows[i].Handle, windows[nextIdx].Position);
        }
    }
    catch
    {
        // Fail silently
    }
}
```

### Pattern 7: Scaled Gap Size by Window Count

**What:** Gap size scales inversely with window count, minimum 20px.
**When to use:** BUG-LAYOUT05 - 4 pillars need larger gaps.
**Example:**
```csharp
// In LayoutService.CalculatePillarsLayout() - after line 276
private int CalculateScaledGap(int baseGap, int windowCount)
{
    // Formula: More windows = smaller gaps, but minimum 20px
    // 1-2 windows: full gap
    // 3 windows: 80% of gap
    // 4+ windows: 60% of gap, minimum 20px

    double scaleFactor = windowCount switch
    {
        <= 2 => 1.0,
        3 => 0.8,
        _ => 0.6
    };

    int scaledGap = (int)(baseGap * scaleFactor);
    return Math.Max(scaledGap, 20); // Never below 20px
}
```

### Anti-Patterns to Avoid

- **Killing hotkey process on monitor exit:** Let it keep running - user may restart monitor later.
- **Using acrylic for "clear" transparency:** On Windows 11, `useAcrylic: false` with `opacity` gives clear transparency.
- **Restoring settings.json from most recent backup:** Need ORIGINAL backup from before Matrix touched it.
- **Swapping only adjacent windows:** User wants rotation through ALL positions.
- **Zero gaps for 4+ windows:** Minimum 20px gap to allow clicking between windows.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Process monitoring | Custom WMI queries | Process.HasExited | Simple, reliable, built-in |
| Window maximize detection | GetWindowPlacement parsing | IsZoomed() | Single API call, correct semantics |
| Settings backup | Complex versioning | Simple file copy with timestamp | Original state is what matters |
| Gap scaling | Complex formula | Linear scale with floor | Simple, predictable |

**Key insight:** Most fixes are small modifications to existing code, not new systems. The architecture is sound; bugs are in edge case handling.

## Common Pitfalls

### Pitfall 1: Hotkey Process Silently Dies

**What goes wrong:** matrix-hotkeys.exe crashes with unhandled exception, user sees no hotkeys.
**Why it happens:** Exception in WndProc or action handler crashes entire process.
**How to avoid:**
1. Add top-level try-catch in Program.Main()
2. Use AppDomain.CurrentDomain.UnhandledException handler
3. Have matrix-monitor supervise and restart
**Warning signs:** Hotkeys work initially, then stop, only work again with redpill open.

### Pitfall 2: Windows 10 vs 11 Transparency

**What goes wrong:** Setting `useAcrylic: false` on Windows 10 gives no transparency at all.
**Why it happens:** Unblurred transparency (`useAcrylic: false` with `opacity < 100`) only works on Windows 11.
**How to avoid:** Either detect Windows version and adjust, or document Windows 11 requirement for "clear" transparency. For Windows 10, acrylic with high opacity (95%) gives less blur.
**Warning signs:** Transparency works in testing (Windows 11) but not for Windows 10 users.

### Pitfall 3: Backup File Overwritten

**What goes wrong:** Running wakeupneo multiple times overwrites original backup with already-modified settings.
**Why it happens:** Backup created unconditionally on each run.
**How to avoid:** Check if original backup exists before creating; only create once.
**Warning signs:** Uninstall doesn't restore original state; Matrix profiles still exist.

### Pitfall 4: Fullscreen Detection with Snapped Windows

**What goes wrong:** Windows snapped to half-screen trigger fullscreen detection.
**Why it happens:** Some implementations check window size vs screen size.
**How to avoid:** Use `IsZoomed()` which specifically checks the maximized window state, not snapped state.
**Warning signs:** Half-screen windows excluded from layout incorrectly.

### Pitfall 5: Glitch Triggers During Window Rotation

**What goes wrong:** Rotating window positions triggers glitch detection which snaps them back.
**Why it happens:** Rotation temporarily creates overlap during transition.
**How to avoid:** Add cooldown period after hotkey-triggered position changes, or disable glitch briefly.
**Warning signs:** Window rotation seems to "fight" itself.

### Pitfall 6: Layer Toggle Hotkeys Not Working

**What goes wrong:** Ctrl+Shift+1/2/3 don't toggle layers.
**Why it happens:** Virtual key codes for number row (VK_1 = 0x31) may conflict with NumPad or other hotkeys, or the handler mapping is incorrect.
**How to avoid:** Verify hotkey registration success in logs, check for conflicts.
**Warning signs:** Other hotkeys work, layer toggles don't.

## Code Examples

Verified patterns from official sources and existing codebase:

### Complete Process Supervision
```csharp
// Source: .NET Process class documentation + existing patterns
public class HotkeyWatchdog
{
    private readonly string _exePath;
    private Process? _process;
    private readonly Timer _timer;

    public HotkeyWatchdog(string exePath)
    {
        _exePath = exePath;
        _timer = new Timer(_ => EnsureRunning(), null,
            TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5));
    }

    private void EnsureRunning()
    {
        try
        {
            if (_process == null || _process.HasExited)
            {
                _process = Process.Start(new ProcessStartInfo(_exePath)
                {
                    CreateNoWindow = true,
                    UseShellExecute = false
                });
                DiagnosticLogger.Info("WATCHDOG", $"Started hotkey service (PID: {_process?.Id})");
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("WATCHDOG", $"Failed to start: {ex.Message}");
        }
    }
}
```

### Uninstall Settings Restoration
```powershell
# Add to uninstall.ps1 - Step 3.5: Restore original WT settings
Write-Host "[3.5/4] Restoring Windows Terminal settings..." -ForegroundColor Cyan

$WTSettings = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

foreach ($SettingsPath in $WTSettings) {
    $OriginalBackup = "$SettingsPath.matrix-original"
    if (Test-Path $OriginalBackup) {
        try {
            Copy-Item $OriginalBackup $SettingsPath -Force
            Remove-Item $OriginalBackup -Force
            Write-Host "  Restored original settings: $SettingsPath" -ForegroundColor Gray
        }
        catch {
            Write-Host "  WARNING: Could not restore $SettingsPath" -ForegroundColor Yellow
        }
    }
}
```

### Profile Creation with Plain Transparency
```csharp
// Updated CreateMatrixProfiles in TerminalSettingsService.cs
var profile = new TerminalProfile
{
    Name = profileName,
    Guid = $"{{{Guid.NewGuid()}}}",
    Commandline = $"powershell.exe -NoExit -Command \"Write-Host ' Matrix Terminal {i}' -ForegroundColor Green\"",
    Hidden = true,
    Opacity = 85,
    UseAcrylic = false,  // Plain transparency - no acrylic blur
    PixelShaderPath = Path.Combine(shadersDirectory, $"Matrix-{i}.hlsl")
};
```

### Color Preset Rename
```csharp
// In ColorPresets.cs - line 12
// Change "Cyan" to "Blue" for user clarity
public static readonly MatrixColor Blue = new(0f, 0.6f, 1f, "Blue", "Electric blue");

// Update All array
public static readonly MatrixColor[] All = [Green, Blue, Red, Purple, Gold, Teal];
```

## Bug-to-Fix Mapping

| Bug ID | Root Cause | Fix Location | Pattern |
|--------|-----------|--------------|---------|
| BUG-HK01 | Hotkey process dies | MatrixShader.Monitor + Hotkeys | Watchdog + Stay-alive |
| BUG-HK02 | SwapLeft/Right wrong implementation | HotkeyActions.cs | Window rotation |
| BUG-HK03 | Layer toggles not firing | HotkeyActions.cs | Verify registration |
| BUG-HK04 | Glitch needs redpill | MatrixWindowMonitor.cs | Already in hotkeys, verify |
| BUG-TRANS04 | Acrylic blur | TerminalSettingsService.cs | UseAcrylic = false |
| BUG-TRANS05 | Settings persist | TerminalSettingsService.cs + uninstall.ps1 | Original backup |
| BUG-SHADER04 | Shader cycling corrupt | HotkeyActions.cs | Remove feature |
| BUG-SHADER05 | One-direction only | HotkeyActions.cs | Remove feature |
| BUG-LAYOUT05 | 4-pillar gaps too tight | LayoutService.cs | Scaled gap formula |
| BUG-LAYOUT06 | F11 fullscreen snaps back | MatrixWindowMonitor.cs | IsZoomed exclusion |
| BUG-LAYOUT07 | Drag/snap state corruption | MatrixWindowMonitor.cs | Investigate state |
| UX-COLOR01 | "Cyan" confusing | ColorPresets.cs | Rename to "Blue" |

## Implementation Waves

Based on dependencies and priority:

| Wave | Bugs | Files Changed | Effort |
|------|------|---------------|--------|
| 1 | BUG-HK01, BUG-HK04 | Program.cs (both), MatrixWindowMonitor.cs | High |
| 2 | BUG-TRANS04, BUG-TRANS05 | TerminalSettingsService.cs, uninstall.ps1 | Medium |
| 3 | BUG-HK02, BUG-HK03 | HotkeyActions.cs | Medium |
| 4 | BUG-LAYOUT05, BUG-LAYOUT06, BUG-LAYOUT07 | LayoutService.cs, MatrixWindowMonitor.cs | Medium |
| 5 | BUG-SHADER04, BUG-SHADER05 | HotkeyActions.cs, HotkeyConfig.cs | Low (removal) |
| 6 | UX-COLOR01 | ColorPresets.cs | Low |

## Open Questions

Things that couldn't be fully resolved:

1. **Windows 10 transparency behavior**
   - What we know: `useAcrylic: false` with opacity only works on Windows 11
   - What's unclear: Best fallback for Windows 10 users who want less blur
   - Recommendation: Accept Windows 11 requirement or use high opacity (95%) with acrylic on Win10

2. **BUG-LAYOUT07 root cause**
   - What we know: Drag and snap stops working after layout changes
   - What's unclear: Whether it's state corruption or concurrent access issue
   - Recommendation: Add detailed diagnostic logging, investigate during implementation

3. **F11 fullscreen "cool borderless" effect**
   - What we know: User mentioned F11 snap-back leaves "borderless look which was cool"
   - What's unclear: Whether this is desired behavior or side effect
   - Recommendation: Focus on fixing snap-back; borderless investigation as separate enhancement

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn: Windows Terminal Appearance Settings](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance) - useAcrylic vs opacity behavior
- [Microsoft Learn: IsZoomed function](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-iszoomed) - Maximize detection API
- Existing codebase analysis:
  - `MatrixShader.Hotkeys/Program.cs` - Current hotkey architecture
  - `MatrixShader.Monitor/Program.cs` - Current monitor service
  - `TerminalSettingsService.cs` - Profile creation patterns
  - `WindowsApi.cs` - Existing P/Invoke patterns

### Secondary (MEDIUM confidence)
- [Windows Terminal GitHub Issue #12623](https://github.com/microsoft/terminal/issues/12623) - Transparent without blur discussion
- [How to Detect and Restart a Crashed .NET Application](https://www.codegenes.net/blog/detecting-and-restarting-my-crashed-net-application/) - Watchdog patterns
- [GitHub: thijse/Watchdog](https://github.com/thijse/Watchdog) - Process watchdog patterns

### Tertiary (LOW confidence)
- Stack Overflow discussions on Windows 10 vs 11 transparency differences
- Community feedback from testing (user-reported bug symptoms)

## Metadata

**Confidence breakdown:**
- Hotkey stability patterns: HIGH - Based on existing architecture and standard .NET patterns
- Transparency settings: HIGH - Microsoft documentation confirms useAcrylic behavior
- Layout fixes: HIGH - Existing LayoutService code clearly shows gap calculation
- Process supervision: HIGH - Standard .NET Process class usage

**Research date:** 2026-02-03
**Valid until:** 2026-04-03 (60 days - patterns are stable)
