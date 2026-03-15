# Phase 1: Global Transparency - Research

**Researched:** 2026-03-06
**Domain:** C#/.NET global opacity control with overflow counters and Win32 OSD overlay
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Toggle interaction
- Toggle cycle stays Off -> Custom -> Full (existing order, no change)
- Overflow/underflow counters are PRESERVED across toggle cycles -- toggling to Off or Full does not reset counters
- Toggling back to Custom restores the full mix+offset (not just the base Redpill mix)
- Counters track push-past-ceiling (overflow) and push-past-floor (underflow) per window independently

#### Redpill sync
- When Redpill changes a single window's opacity (B/K/L keys), that window's overflow counter resets to 0
- The Redpill-set value becomes the new base for that window
- Other windows' counters are NOT affected -- completely independent
- Redpill is the per-window authority; hotkeys are the global authority

#### Visual feedback
- Brief OSD toast showing just the opacity percentage (e.g., "85%") on each Ctrl+Shift+J/K press
- Toast is ON by default (acts as subtle freemium nudge -- visible to all users)
- Toggleable OFF in Redpill settings menu
- Minimal aesthetic -- just the number, no progress bar

### Claude's Discretion
- OSD toast duration and fade behavior
- Toast positioning on screen
- Exact implementation of the OSD rendering (console overlay vs native window)
- How overflow counters are stored in memory (Dictionary per profile name, same pattern as existing _customOpacity)

### Deferred Ideas (OUT OF SCOPE)
- Saved transparency presets (named mix configurations that can be toggled through) -- future phase
- OSD toast for OTHER hotkey actions beyond opacity -- future consideration
</user_constraints>

## Summary

This phase transforms the existing single-window `AdjustOpacity` hotkey action (Ctrl+Shift+J/K) into a global operation across all Matrix windows, while adding overflow/underflow counters that perfectly preserve per-window opacity mixes. An OSD toast overlay provides visual feedback.

The codebase already has the foundational pattern: `ToggleTransparency()` in `HotkeyActions.cs` already iterates all Matrix windows via `GetMatrixWindowsCached()` and applies opacity to each. The new `AdjustOpacity` simply needs to follow this same pattern but add per-window overflow/underflow counter logic. The Redpill `ControlPanel.ApplyOpacityToProfile()` must be updated to reset counters on per-window changes.

The OSD toast is a new capability. The existing `ToastNotifications` class uses UWP toast notifications (`Microsoft.Toolkit.Uwp.Notifications`), but these are too slow (1-2 second delay) for real-time opacity feedback. A lightweight Win32 layered window OSD is the right approach -- fast, minimal, and uses P/Invoke patterns already established in the codebase.

**Primary recommendation:** Modify `AdjustOpacity()` to iterate all windows with overflow/underflow counters (following the `ToggleTransparency` all-windows pattern), add a lightweight Win32 layered popup window for the OSD toast, and wire Redpill's per-window opacity changes to reset the relevant counter.

## Standard Stack

This phase uses NO new external libraries. Everything is built with what is already in the project.

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| .NET 8 | 8.0 | Runtime + AOT | Already the target framework |
| user32.dll (P/Invoke) | Win32 | Window creation, layered windows | Already used extensively in WindowsApi.cs |
| dwmapi.dll (P/Invoke) | Win32 | DWM window attributes | Already used for border margins |
| Microsoft.Toolkit.Uwp.Notifications | (pinned) | Conflict toast only | Already used, NOT for OSD |

### No New Dependencies
This phase requires zero new NuGet packages. All Win32 P/Invoke functions needed for the OSD overlay are available through the existing `user32.dll` and `gdi32.dll` imports.

## Architecture Patterns

### Pattern 1: Global Window Iteration (EXISTING -- follow it)
**What:** Iterate all Matrix windows via `GetMatrixWindowsCached()`, apply changes to each profile, save once
**When to use:** Any hotkey action that should affect all windows
**Confidence:** HIGH -- this exact pattern exists in `ToggleTransparency()` (lines 251-333 of HotkeyActions.cs)

```csharp
// Source: HotkeyActions.cs ToggleTransparency() - EXISTING PATTERN
var matrixWindows = GetMatrixWindowsCached();
if (matrixWindows.Count == 0)
    return;

var allSettings = _terminalSettingsService.LoadSettings();
foreach (var window in matrixWindows)
{
    if (string.IsNullOrEmpty(window.ProfileName)) continue;
    var profile = _terminalSettingsService.GetProfile(allSettings, window.ProfileName);
    if (profile == null) continue;

    // Per-window logic here
    var updatedProfile = profile with { Opacity = targetOpacity };
    _terminalSettingsService.UpsertProfile(allSettings, updatedProfile);
}
_terminalSettingsService.SaveSettings(allSettings);  // Single write to disk
```

**Critical:** Load settings ONCE, modify all profiles, save ONCE. The `SaveSettings` does an atomic write (temp file + move) and triggers Windows Terminal reload. Multiple writes would cause flicker/lag.

### Pattern 2: Overflow/Underflow Counter Dictionary (NEW -- follow existing Dictionary pattern)
**What:** Per-profile-name dictionaries tracking overflow and underflow counters
**When to use:** Tracking push-past-ceiling/floor state per window independently
**Confidence:** HIGH -- follows the exact same pattern as existing `_customOpacity` and `_transparencyStates` dictionaries in `HotkeyActions.cs`

```csharp
// EXISTING pattern (line 34 of HotkeyActions.cs):
private readonly Dictionary<string, int> _customOpacity = new();

// NEW dictionaries (same pattern):
private readonly Dictionary<string, int> _overflowCounters = new();
private readonly Dictionary<string, int> _underflowCounters = new();
```

Key: `ProfileName` (e.g., "Matrix-1", "Matrix-2")
Value: Number of 5% pushes past ceiling (overflow) or floor (underflow)

### Pattern 3: Win32 Layered Popup Window for OSD (NEW -- follows HotkeyWindow pattern)
**What:** A borderless, transparent, topmost, non-activating popup window that displays text briefly and auto-hides
**When to use:** Real-time visual feedback that must appear/disappear in <100ms
**Confidence:** HIGH -- the project already creates Win32 windows via P/Invoke in `HotkeyWindow.cs` using `CreateWindowExW`

The OSD window should use these extended styles:
- `WS_EX_LAYERED` -- enables per-pixel alpha / SetLayeredWindowAttributes
- `WS_EX_TOPMOST` -- stays above all other windows (HWND_TOPMOST already defined in WindowsApi.cs)
- `WS_EX_NOACTIVATE` -- does not steal focus when shown
- `WS_EX_TOOLWINDOW` -- does not appear in taskbar or Alt+Tab
- `WS_EX_TRANSPARENT` -- mouse clicks pass through

Window style: `WS_POPUP` (no border, no title bar)

### Pattern 4: Timer-Based Auto-Hide (NEW)
**What:** Use `System.Threading.Timer` to auto-hide the OSD after a duration
**When to use:** The OSD must dismiss itself without user interaction
**Confidence:** HIGH -- `System.Threading.Timer` works well in Win32 message loop contexts and is AOT-compatible

```csharp
// Timer pattern for auto-hide
private System.Threading.Timer? _hideTimer;

public void ShowToast(string text)
{
    // Cancel previous timer
    _hideTimer?.Dispose();

    // Update text, show window
    UpdateText(text);
    ShowWindow(_hWnd, SW_SHOWNOACTIVATE);

    // Schedule hide
    _hideTimer = new System.Threading.Timer(
        _ => HideWindow(),
        null,
        durationMs,
        Timeout.Infinite);
}
```

### Anti-Patterns to Avoid
- **UWP Toast for real-time feedback:** UWP toasts have 1-2 second latency and queue asynchronously. They are for notifications, not OSD feedback. The existing `ToastNotifications.ShowInfo()` should NOT be used for opacity display.
- **Multiple SaveSettings calls:** Loading and saving settings.json once per window would thrash the file and cause WT to reload multiple times. Load once, batch all changes, save once.
- **Resetting counters on toggle:** The user explicitly decided overflow/underflow counters are PRESERVED across toggle cycles. Toggling to Off or Full does NOT reset counters.
- **Global overflow tracking:** Each window must have INDEPENDENT overflow/underflow counters. There is no global counter.

### Recommended Code Organization

```
MatrixShader.Hotkeys/
  HotkeyActions.cs          # Modified: AdjustOpacity becomes global with overflow
  OsdOverlay.cs             # NEW: Lightweight Win32 layered window OSD
  Program.cs                # Modified: Initialize/cleanup OSD

MatrixShader.Core/
  Native/WindowsApi.cs      # Modified: Add GDI/text drawing P/Invoke if needed
  Models/MatrixState.cs     # Modified: Add OsdToastEnabled bool

MatrixShader.Cli/Redpill/
  Program.cs                # Modified: ApplyOpacityToProfile resets overflow counter
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OSD rendering | GDI+ bitmap pipeline | Direct GDI TextOut on layered window | Simpler, faster, AOT-compatible, no System.Drawing dependency |
| Focus management | Custom focus restoration | WS_EX_NOACTIVATE + SWP_NOACTIVATE | Win32 handles this natively -- the OSD never takes focus in the first place |
| Timer management | Custom tick loop | System.Threading.Timer | Standard .NET, single callback, disposable |
| Window enumeration | New enumeration logic | Existing GetMatrixWindowsCached() | Already cached with 3s TTL, tested, handles control panel exclusion |

**Key insight:** The hardest part of this phase (finding all Matrix windows, modifying their profiles, writing WT settings atomically) is ALREADY SOLVED by the existing `ToggleTransparency()` code. The overflow counter logic is pure arithmetic. The OSD is the only genuinely new capability.

## Common Pitfalls

### Pitfall 1: File Contention on settings.json
**What goes wrong:** Windows Terminal and the hotkey process both read/write settings.json. If WT is mid-write when hotkeys try to read, you get IOException or corrupt reads.
**Why it happens:** WT hot-reloads on file change, and the hotkey process writes on every key press.
**How to avoid:** The existing `SaveSettings` already uses atomic write (write to .tmp, then File.Move with overwrite). The `LoadSettings` has three-layer error recovery. Just follow the existing pattern -- do NOT add a second save call.
**Warning signs:** IOException in logs mentioning "file in use" or "being used by another process"

### Pitfall 2: Overflow Counter Drift from Redpill
**What goes wrong:** User adjusts a single window's opacity in Redpill (B/K/L keys), but the hotkey process doesn't know the base changed. On next global J/K press, the overflow math is wrong.
**Why it happens:** The Redpill ControlPanel and the Hotkeys process are SEPARATE PROCESSES. They share no memory.
**How to avoid:** On each global adjust, read the CURRENT opacity from settings.json for each profile. The overflow counter only tracks "how many pushes past ceiling/floor" -- it doesn't store the base opacity. The base is always the live value from settings.json (or settings.json value minus (overflow * 5), depending on direction).
**Warning signs:** After Redpill per-window change, global hotkeys produce wrong values.

**CRITICAL INSIGHT:** Because Redpill and Hotkeys are separate processes, the "reset overflow on Redpill change" requirement needs careful thought. Options:
1. **Read-from-source pattern:** On every global press, read current opacity from settings.json. The counter is relative to the "would-be" opacity. If a window is at 100% and overflow is 3, the "effective" target is 115% but displayed is 100%. If Redpill changes it to 80%, next time Hotkeys reads it, it sees 80% and the overflow still says 3 -- but that's wrong because Redpill reset the base.
2. **Recommended: Track base_opacity per window.** Store `Dictionary<string, int> _baseOpacity`. When the read opacity differs from the stored base AND the user didn't just push J/K, we know Redpill changed it -- reset overflow to 0 and update base.

### Pitfall 3: OSD Window Not Appearing
**What goes wrong:** The OSD window is created but never visible.
**Why it happens:** `WS_EX_LAYERED` windows start fully transparent until `SetLayeredWindowAttributes` is called. Or the window is created on a different thread than the message loop.
**How to avoid:** Call `SetLayeredWindowAttributes` immediately after creating the window with alpha=255. Create the OSD window on the SAME thread as `HotkeyWindow` (the message loop thread).
**Warning signs:** `ShowWindow` returns true but nothing appears on screen.

### Pitfall 4: Stale Cached Windows
**What goes wrong:** GetMatrixWindowsCached() returns a closed window, causing profile updates for a window that no longer exists.
**Why it happens:** The cache has a 3-second TTL. Window could close between cache refresh and use.
**How to avoid:** This is benign -- updating a profile for a closed window in settings.json has no visual effect and WT ignores it. Don't add extra validation.
**Warning signs:** None -- this is safe to ignore.

### Pitfall 5: AOT Incompatibility
**What goes wrong:** New code uses reflection-based JSON serialization or dynamic code generation, breaking Native AOT.
**Why it happens:** The project has `<PublishAot>true</PublishAot>` and `<IsAotCompatible>true</IsAotCompatible>`.
**How to avoid:** If any new model needs JSON serialization (e.g., persisting toast-enabled setting), add it to `MatrixJsonContext.cs`. Use `[JsonSerializable(typeof(...))]` attribute. The `MatrixState` record is already in the context.
**Warning signs:** Trimming warnings during build. Runtime `TypeInitializationException`.

### Pitfall 6: OSD Steals Focus from Matrix Window
**What goes wrong:** When the OSD appears, it takes keyboard focus away from the Matrix window that was focused.
**Why it happens:** Default window creation activates the new window.
**How to avoid:** Use `WS_EX_NOACTIVATE` extended style AND show with `ShowWindow(hWnd, SW_SHOWNOACTIVATE)` (value 8) rather than `SW_SHOWNORMAL`. Also use `SWP_NOACTIVATE` in any `SetWindowPos` calls.
**Warning signs:** After pressing Ctrl+Shift+J, the next keypress doesn't go to the expected window.

## Code Examples

### Example 1: New AdjustOpacity with Overflow (Core Logic)

```csharp
// Source: Synthesized from existing ToggleTransparency pattern + overflow counter design
private void AdjustOpacity(int delta)
{
    var matrixWindows = GetMatrixWindowsCached();
    if (matrixWindows.Count == 0)
        return;

    // Check if ALL windows are at ceiling (delta > 0) or floor (delta < 0)
    bool allCapped = true;

    var allSettings = _terminalSettingsService.LoadSettings();

    foreach (var window in matrixWindows)
    {
        if (string.IsNullOrEmpty(window.ProfileName)) continue;
        var profile = _terminalSettingsService.GetProfile(allSettings, window.ProfileName);
        if (profile == null) continue;

        var profileName = window.ProfileName;
        int currentOpacity = profile.Opacity;

        // Detect Redpill base change: if current opacity != expected, reset counters
        DetectBaseChange(profileName, currentOpacity);

        if (!_overflowCounters.TryGetValue(profileName, out var overflow))
            overflow = 0;
        if (!_underflowCounters.TryGetValue(profileName, out var underflow))
            underflow = 0;

        int newOpacity = currentOpacity;

        if (delta > 0) // Increasing opacity (K key)
        {
            if (underflow > 0)
            {
                // Drain underflow first
                _underflowCounters[profileName] = underflow - 1;
                // Opacity stays the same (draining virtual debt)
                allCapped = false;
            }
            else if (currentOpacity < MaxOpacity)
            {
                newOpacity = Math.Min(currentOpacity + OpacityDelta, MaxOpacity);
                allCapped = false;
            }
            else
            {
                // At ceiling, increment overflow
                _overflowCounters[profileName] = overflow + 1;
                // allCapped stays true if ALL windows reach here
            }
        }
        else // Decreasing opacity (J key)
        {
            if (overflow > 0)
            {
                // Drain overflow first
                _overflowCounters[profileName] = overflow - 1;
                allCapped = false;
            }
            else if (currentOpacity > MinOpacity)
            {
                newOpacity = Math.Max(currentOpacity + delta, MinOpacity); // delta is negative
                allCapped = false;
            }
            else
            {
                // At floor, increment underflow
                _underflowCounters[profileName] = underflow + 1;
            }
        }

        if (newOpacity != currentOpacity)
        {
            var updatedProfile = profile with { Opacity = newOpacity };
            _terminalSettingsService.UpsertProfile(allSettings, updatedProfile);
        }

        // Track what we set as the base
        _baseOpacity[profileName] = newOpacity;

        // Update custom opacity and transparency state for toggle cycle
        _customOpacity[profileName] = newOpacity;
        _transparencyStates[profileName] = TransparencyState.Custom;
    }

    _terminalSettingsService.SaveSettings(allSettings);

    // Show OSD toast (unless all capped in the push direction)
    if (!allCapped || /* some window changed */)
    {
        // Show representative opacity (e.g., first window's value)
        var firstProfile = matrixWindows[0].ProfileName;
        if (firstProfile != null)
        {
            var finalProfile = _terminalSettingsService.GetProfile(allSettings, firstProfile);
            _osdOverlay?.ShowToast($"{finalProfile?.Opacity ?? 0}%");
        }
    }
}
```

### Example 2: OSD Overlay Window Creation (Win32 P/Invoke)

```csharp
// Source: Win32 API patterns already used in HotkeyWindow.cs
// Extended styles for a non-interactive, topmost, transparent overlay
const uint WS_EX_LAYERED = 0x00080000;
const uint WS_EX_TOPMOST = 0x00000008;
const uint WS_EX_NOACTIVATE = 0x08000000;
const uint WS_EX_TOOLWINDOW = 0x00000080;
const uint WS_EX_TRANSPARENT = 0x00000020;
const uint WS_POPUP = 0x80000000;

// Create window -- same pattern as HotkeyWindow.Create()
_hWnd = CreateWindowExW(
    WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_NOACTIVATE |
    WS_EX_TOOLWINDOW | WS_EX_TRANSPARENT,
    className,
    "MatrixOSD",
    WS_POPUP,
    x, y, width, height,
    nint.Zero,      // No parent (not HWND_MESSAGE -- needs to be visible)
    nint.Zero,
    hInstance,
    nint.Zero
);

// Set initial opacity
SetLayeredWindowAttributes(_hWnd, 0, 220, LWA_ALPHA); // Slightly transparent
```

### Example 3: Redpill Counter Reset on Per-Window Change

```csharp
// In Redpill ControlPanel.ApplyOpacityToProfile (line 930-950)
// After applying per-window opacity change, signal to hotkeys process
// Option: Write a small marker file that hotkeys process watches
// Better option: Just let the base-change detection handle it (Pitfall 2)
private void ApplyOpacityToProfile(int opacity)
{
    try
    {
        var settings = _terminalSettingsService.LoadSettings();
        var profileName = $"Matrix-{_tabManager.CurrentSlot}";
        var profile = _terminalSettingsService.GetProfile(settings, profileName);

        if (profile != null)
        {
            var updatedProfile = profile with { Opacity = opacity };
            _terminalSettingsService.UpsertProfile(settings, updatedProfile);
            _terminalSettingsService.SaveSettings(settings);
        }
    }
    catch (Exception ex)
    {
        _logger.LogWarning(ex, "Failed to apply opacity to profile");
    }
}
// NOTE: No explicit IPC needed. The Hotkeys process detects the base change
// by comparing current opacity to its tracked _baseOpacity on next J/K press.
```

## OSD Implementation Recommendation (Claude's Discretion)

### Recommended: Lightweight Win32 Layered Popup Window
**Duration:** 1200ms display, 300ms fade-out (total ~1.5s visible)
**Position:** Bottom-center of primary monitor, 80px from bottom edge
**Size:** ~120x50px (just enough for "100%" text)
**Font:** System default (via GDI ExtTextOut), white text, ~24pt equivalent
**Background:** Semi-transparent dark (#1A1A1A at 85% opacity)
**Fade:** Use SetLayeredWindowAttributes alpha ramp via timer (220 -> 0 over 300ms)

**Why not UWP toast:** UWP toasts (`ToastNotifications.ShowInfo`) have 1-2 second delivery latency and persist in Action Center. They are designed for notifications the user might miss. For real-time "I pressed a button, show me the result" feedback, a Win32 overlay is the only option that feels instant.

**Why not console overlay:** The hotkeys process has NO console (runs as invisible background process with `CreateNoWindow = true`). Spawning a conhost window (like `HotkeyHelpOverlay.SpawnOverlay`) would be heavyweight and visually jarring for a brief number display.

**Rendering approach:** Use GDI (ExtTextOutW or TextOutW) rather than GDI+ or WPF. GDI is:
- Available via P/Invoke with no additional dependencies
- AOT-compatible (no reflection)
- Fast for simple text rendering
- Already used implicitly through Win32 window painting

**Alternative considered: UpdateLayeredWindow with BLENDFUNCTION** for per-pixel alpha. This gives smoother rendering but is significantly more complex (requires creating a DIB section, drawing to it, then calling UpdateLayeredWindow). For a simple text overlay, SetLayeredWindowAttributes with LWA_ALPHA is sufficient.

### OSD Toast Toggle Persistence
Add `OsdToastEnabled` boolean to `MatrixState` record. Default: `true`. The `MatrixState` is already registered in `MatrixJsonContext` for AOT serialization. The Redpill settings menu can toggle this, and the Hotkeys process reads it via `IConfigService.LoadState()`.

### Overflow Counter Storage
Use `Dictionary<string, int>` per profile name -- exactly matching the existing `_customOpacity` pattern in `HotkeyActions.cs` (line 34). These are in-memory only (not persisted). On process restart, counters reset to 0, which is correct behavior (the user restarts, mix is whatever was last written to settings.json).

Additionally, track `Dictionary<string, int> _baseOpacity` to detect when Redpill changes a window's opacity. On each global adjust, if `currentOpacity != _baseOpacity[profileName]` and we didn't just change it, we know an external change occurred and reset that window's overflow/underflow to 0.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-window opacity (AdjustOpacity targets focused window) | Global opacity with overflow counters (all windows) | This phase | Preserves per-window mix perfectly |
| No OSD feedback | Win32 layered window OSD toast | This phase | User sees opacity % on each press |
| UWP toasts for all notifications | UWP for conflicts, Win32 for real-time OSD | This phase | Sub-100ms feedback vs 1-2s UWP delay |

## Cross-Process Communication Analysis

### Redpill <-> Hotkeys IPC
**Status:** These are separate processes. Redpill is the TUI control panel; Hotkeys is the background global hotkey listener.
**Shared state:** Both read/write `settings.json` (Windows Terminal profiles). Both use `ConfigService` to read/write `MatrixState` (to `%LOCALAPPDATA%/MatrixShader/matrix-state.json`).
**For this phase:** No explicit IPC is needed. The Hotkeys process detects Redpill's per-window opacity changes by reading current opacity from `settings.json` on each global J/K press and comparing against its tracked base. This is a polling-at-use-time approach, not a watch/event approach.

## Open Questions

1. **OSD on multi-monitor: which monitor?**
   - What we know: The project already has `WindowsApi.GetMonitors()` that returns sorted monitors (primary first). The primary monitor is a safe default.
   - What's unclear: Should the OSD appear on the monitor with the most Matrix windows? Or always primary?
   - Recommendation: Show on primary monitor. Simple, predictable. Users rarely look at a specific monitor when pressing a global hotkey.

2. **OSD text content when windows have different opacities**
   - What we know: After a global adjust, windows at different base opacities will show different final values (e.g., one at 85%, another at 70%).
   - What's unclear: Should the OSD show one number? A range? Just the first window's value?
   - Recommendation: Show the first (non-capped) window's opacity. The mixing-board metaphor means the user thinks in terms of "pushing the overall level" not individual values. Showing one representative number is sufficient.

3. **Thread safety for OSD updates**
   - What we know: The hotkey callback fires on the message loop thread (same thread as HotkeyWindow). The OSD window should also be created on this thread.
   - What's unclear: Does `System.Threading.Timer` callback execute on a thread pool thread? (Yes, it does.)
   - Recommendation: Use `PostMessage` to marshal the hide operation back to the message loop thread, or use `SetTimer` (Win32 timer that fires WM_TIMER on the window's thread).

## Sources

### Primary (HIGH confidence)
- `HotkeyActions.cs` (lines 251-399) -- existing ToggleTransparency and AdjustOpacity patterns
- `TerminalSettingsService.cs` (lines 34-128) -- LoadSettings/SaveSettings atomic write pattern
- `HotkeyWindow.cs` -- Win32 message-only window creation via P/Invoke
- `WindowsApi.cs` -- existing P/Invoke declarations (SetWindowPos, HWND_TOPMOST, etc.)
- `MatrixState.cs` -- existing application state model for persistence
- `ToastNotifications.cs` -- existing UWP toast (confirms WHY not to use it for OSD)
- `WindowInfo.cs` -- per-window ProfileName used as dictionary key
- `ControlPanel.ApplyOpacityToProfile()` (lines 930-950) -- Redpill per-window opacity
- `MatrixJsonContext.cs` -- AOT-compatible JSON serialization registry
- [SetLayeredWindowAttributes - Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setlayeredwindowattributes)
- [Window Features - Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features)

### Secondary (MEDIUM confidence)
- Win32 layered window OSD pattern (well-established Win32 technique, multiple community implementations confirm approach)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing code
- Architecture: HIGH -- follows established patterns in the codebase (ToggleTransparency, HotkeyWindow)
- Overflow counter logic: HIGH -- pure arithmetic, user spec is unambiguous
- OSD implementation: HIGH -- Win32 layered windows are well-documented, project already uses P/Invoke extensively
- Cross-process sync: MEDIUM -- base-change detection is sound but untested pattern

**Research date:** 2026-03-06
**Valid until:** 2026-04-06 (stable -- no external dependencies changing)
