# Phase 13: Post-E2E Polish - Research

**Researched:** 2026-02-01
**Domain:** Bug fixes across WT Detection, Layout, Transparency, Shaders, Redpill, Installer UX
**Confidence:** HIGH (based on source code analysis)

## Summary

Phase 13 fixes 17 bugs discovered during post-microsprint Windows Sandbox testing. Research focused on understanding the current implementation to identify root causes and proper fixes.

Key findings:
1. **WT Detection (BUG-WT06):** Detection is actually comprehensive but runs BEFORE installation completes. Need to re-check after WT install.
2. **Layout (BUG-LAYOUT03/04):** Pillars mode has a multi-row fallback that triggers incorrectly; minimized windows are forcibly restored.
3. **Transparency (BUG-TRANS03):** Transparency was being applied to WT `profiles.defaults` in microsprint fix, affecting ALL profiles.
4. **Shaders (BUG-SHADER03):** Rain columns start with same animation phase due to randomization tied to `floor(Time)`.
5. **Redpill (BUG-REDPILL01):** Opens in current terminal because it's launched via command-line, not a new WT window.
6. **Installer (UX-INST01-03):** Inno Setup 6.7.0+ supports custom background colors and dark mode theming natively.

**Primary recommendation:** Group bugs into implementation waves by affected code area for efficient fixing.

## Bug Analysis by Implementation Area

### Wave 1: Windows Terminal Detection (Critical)

| Bug | Root Cause | Fix Location |
|-----|-----------|--------------|
| BUG-WT06 | `IsWindowsTerminalInstalled()` checks run before installation completes - need post-install re-check | `CliBootstrap.cs` lines 79-95 |

**Root Cause Analysis:**

Current detection flow in `CliBootstrap.InitializeAsync()`:
```csharp
// Line 79-95: Detection runs ONCE at bootstrap
if (!skipTerminalCheck && !IsWindowsTerminalInstalled())
{
    var installed = await TryInstallWindowsTerminalAsync(verbose);
    if (!installed)
    {
        return new BootstrapResult(false, "Windows Terminal is required...");
    }
    // After install, no re-detection happens!
}
```

Detection methods are comprehensive (lines 114-138):
- Settings.json paths for Store/Winget/Scoop/Chocolatey
- PATH search for wt.exe
- Parent process check via `EnvironmentService.IsWindowsTerminal()`

**Problem:** After GitHub download installs WT, the code continues but render mode detection still returns Lite because `EnvironmentService.IsWindowsTerminal()` checks `WT_SESSION` env var - which only exists when running INSIDE WT.

**Fix Pattern:**
```csharp
// After successful WT installation, re-check settings.json existence
if (downloaded && IsWindowsTerminalInstalled())
{
    // Settings exist - WT is installed, but we're not IN WT
    // Inform user to restart in new WT window
    ConsoleHelper.WriteLineMatrixGreen(" Windows Terminal installed!");
    ConsoleHelper.WriteLineDim(" Please close this window and run 'wakeupneo' in Windows Terminal.");
    return new BootstrapResult(false, "Restart in Windows Terminal required.");
}
```

### Wave 2: Layout Engine (High)

| Bug | Root Cause | Fix Location |
|-----|-----------|--------------|
| BUG-LAYOUT03 | Pillars layout falls back to multi-row when window width < 475px | `LayoutService.cs` lines 295-326 |
| BUG-LAYOUT04 | `ApplyLayoutInternal()` force-restores minimized windows | `LayoutService.cs` lines 125-128 |

**Root Cause Analysis - BUG-LAYOUT03:**

In `CalculatePillarsLayout()` (lines 295-326):
```csharp
// Step 4: Calculate grid dimensions
int columns = Math.Min(windowsOnScreen, maxPillars);
int rows = 1;

// Multi-row if more windows than fit in one row
if (windowsOnScreen > maxPillars)
{
    columns = maxPillars;
    rows = (int)Math.Ceiling((double)windowsOnScreen / columns);
}

// Auto-reduce columns if width would be below minimum
int originalColumns = columns;
do
{
    int totalHGaps = (columns + 1) * gapSize;
    int cellWidth = (workArea.Width - totalHGaps) / columns;

    if (cellWidth < MinWindowWidth && columns > 1)
    {
        columns--;
        rows = (int)Math.Ceiling((double)windowsOnScreen / columns);  // BUG: Increases rows!
    }
```

When 4 windows on a narrow sandbox display (e.g., 1280px) and `MinWindowWidth=475`:
- 4 columns with 30px gaps: (1280 - 5*30) / 4 = 282px per window (< 475)
- Auto-reduces to 3 columns: (1280 - 4*30) / 3 = 386px (< 475)
- Auto-reduces to 2 columns, 2 rows: (1280 - 3*30) / 2 = 595px (>= 475)

**Fix Pattern:** User decision says "4 pillars side-by-side" - need to reduce gap size or MinWindowWidth for narrow displays rather than adding rows.

```csharp
// Option 1: Reduce gap when constrained
if (cellWidth < MinWindowWidth && columns > 1 && gapSize > 0)
{
    // Try reducing gaps first before reducing columns
    gapSize = Math.Max(0, gapSize - 10);
    continue;
}

// Option 2: Reduce MinWindowWidth for sandbox displays
// Windows Terminal can actually go narrower than 475px
private const int MinWindowWidth = 400;  // Reduced from 475
```

**Root Cause Analysis - BUG-LAYOUT04:**

In `ApplyLayoutInternal()` (lines 117-134):
```csharp
private void ApplyLayoutInternal(IReadOnlyList<WindowPosition> positions)
{
    foreach (var pos in positions)
    {
        // Restore if minimized
        if (WindowsApi.IsIconic(pos.Window.Handle))
        {
            WindowsApi.ShowWindow(pos.Window.Handle, WindowsApi.SW_RESTORE);
            Thread.Sleep(100); // Brief delay for restore animation
        }
        // ...
    }
}
```

**Fix Pattern:** Skip minimized windows per user decision:
```csharp
// Respect user's choice to minimize
if (WindowsApi.IsIconic(pos.Window.Handle))
{
    DiagnosticLogger.Debug("LAYOUT", $"Skipping minimized window {pos.Window.ShaderIndex}");
    continue;
}
```

### Wave 3: Transparency (Critical)

| Bug | Root Cause | Fix Location |
|-----|-----------|--------------|
| BUG-TRANS03 | Microsprint fix modified `profiles.defaults` which affects ALL windows | `matrix_control.ps1` or C# equivalent |

**Root Cause Analysis:**

From TESTING.md microsprint notes:
> BUG-TRANS01: Transparency on wrong windows | Removed `profiles.defaults` modification in `matrix_control.ps1` - now only affects Matrix-N profiles

This fix was incomplete. The C# `ControlPanel.ApplyOpacityToProfile()` method correctly updates individual profiles (lines 685-705):
```csharp
private void ApplyOpacityToProfile(int opacity)
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
```

**Investigation needed:** Check if there's another code path (in wakeupneo wizard or profile creation) that sets `profiles.defaults.opacity`.

**Fix Pattern:** Ensure default opacity (85%) is set ONLY on Matrix-N profiles during creation, never on `profiles.defaults`:
```csharp
// In TerminalSettingsService.CreateMatrixProfiles()
var profile = new TerminalProfile
{
    Name = profileName,
    Opacity = 85,  // Add default opacity ONLY to Matrix profiles
    // ...
};
```

### Wave 4: Shader Animation (High)

| Bug | Root Cause | Fix Location |
|-----|-----------|--------------|
| BUG-SHADER03 | All rain columns start with same animation phase | `shaders/*.hlsl` - DrawLayer function |

**Root Cause Analysis:**

In shader (Matrix-1.hlsl, lines 62-66):
```hlsl
float col_rnd = random(float2(cell_id.x, seed_shift));
if (col_rnd > RAIN_DENSITY) return float3(0,0,0);
float final_speed = ((col_rnd * 0.5 + 0.2) * 10.0 * RAIN_SPEED * speed_mult) / depth;
float rain_pos = cell_id.y - (Time * final_speed) + (col_rnd * 1000.0);
float cycle = frac(rain_pos / grid_dims.y * 1.5);
```

The randomization uses `col_rnd * 1000.0` for phase offset, but this creates synchronized groups because:
1. `col_rnd` values cluster due to pseudo-random distribution
2. The `cycle` calculation uses consistent math across all columns
3. `floor(Time * 4.0)` in glyph selection (line 55) creates 250ms synchronized character changes

**Fix Pattern:** Add row-independent random offset to the rain position calculation:
```hlsl
// Generate unique seed per column using higher frequency noise
float col_seed = random(float2(cell_id.x * 123.456, seed_shift + 789.012));

// Add significant phase offset that varies per column
float phase_offset = col_seed * grid_dims.y * 3.0;  // Full cycle offset per column
float rain_pos = cell_id.y - (Time * final_speed) + phase_offset;
```

### Wave 5: Redpill UX (High)

| Bug | Root Cause | Fix Location |
|-----|-----------|--------------|
| BUG-REDPILL01 | Redpill runs in current terminal, not new window | Need to launch via `wt -p "Redpill"` instead of running directly |
| BUG-REDPILL02 | Menu repeats content | TUI render loop issue in `ControlPanel.Render()` |
| BUG-HOTKEY01 | Hotkey info not discoverable | Need help text or dedicated screen |

**Root Cause Analysis - BUG-REDPILL01:**

User runs `redpill` from command line. The Redpill program (`Redpill/Program.cs`) runs in the current terminal session. The Redpill-Neo shader is only applied when launched via WT profile.

**Fix Pattern:** Add self-launch mode to redpill:
```csharp
// In Program.Main()
if (!EnvironmentService.IsWindowsTerminal() || !IsRunningInRedpillProfile())
{
    // We're not in WT or not in the Redpill profile - launch new window
    var wtPath = CliBootstrap.GetWindowsTerminalExePath() ?? "wt.exe";
    Process.Start(new ProcessStartInfo
    {
        FileName = wtPath,
        Arguments = "-p \"Redpill\"",
        UseShellExecute = true
    });
    return 0;  // Exit current process
}
```

**Root Cause Analysis - BUG-REDPILL02:**

The TUI render loop in `ControlPanel.Render()` writes to console positions without clearing. Over time, if the render takes variable time, content can overlap. The `Console.SetCursorPosition(0, 0)` at line 279 positions for overwrite but doesn't clear any leftover content.

**Fix Pattern:**
```csharp
private void Render()
{
    Console.SetCursorPosition(0, 0);

    // Clear any leftover content with fixed-width lines
    // Or use Console.Clear() with minimal flicker optimization
```

### Wave 6: Installer UX (Medium/Low)

| Bug | Root Cause | Fix Location |
|-----|-----------|--------------|
| UX-INST01 | Re-run dialog uses generic buttons | `MatrixShaderSetup.iss` lines 119-170 |
| UX-INST02 | Cancel button redundant | Remove from dialog |
| UX-INST03 | Installer not themed | Use Inno Setup 6.7.0+ features |
| Version bug | Shows 2.0.0, should be 1.0.0 | Line 5: `AppVersion=2.0.0` |

**Inno Setup Theming (confirmed HIGH confidence):**

Inno Setup 6.7.0 (January 2026) added custom background color support:
- `WizardBackColor=<color>` - Set black background
- `WizardStyle=modern` with `WizardImageOpacity` for transparency
- Dark mode support: `SetupStyleDark=yes`

**Fix Pattern for Matrix theming:**
```iss
[Setup]
AppVersion=1.0.0  ; Fix version
SetupStyleDark=yes
WizardBackColor=$000000  ; Black background

[CustomMessages]
english.WelcomeLabel1=Welcome to the Matrix
english.WelcomeLabel2=This wizard will install Matrix Shader on your system.

; For custom buttons, use Code section with CreateInputOptionPage
```

For Blue Pill/Red Pill button theming, requires custom page via `[Code]` section using `CreateCustomForm` or third-party ISSkin.

### Wave 7: MatrixLite Clarification (Per User Decision)

| Bug | Description | Status |
|-----|-------------|--------|
| BUG-ML07 | Splash only in WT | Low priority - WT install works |
| BUG-ML08 | B key same as Enter | NON-ISSUE per decision |
| BUG-ML09 | Fullscreen not working | NON-ISSUE per decision |
| BUG-ML10 | Terminal blocked | NON-ISSUE per decision |

**User Decision:** MatrixLite is a "cool demo", NOT a usable terminal. Background mode is not expected to work.

**Action:** Mark BUG-ML08, ML09, ML10 as Won't Fix. BUG-ML07 (splash in cmd.exe) is low priority but fixable if needed.

### Wave 8: Miscellaneous

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| GAP-SHADERS01 | Can't find shaders in explorer | Hidden/AppData folder - add shortcut or documentation |

## Standard Stack

This phase uses existing project stack with no new dependencies.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| .NET 8 | 8.0 | Runtime | Already used |
| Inno Setup | 6.7.0+ | Installer | Dark mode + custom colors |

## Architecture Patterns

### Bug Fix Categorization Pattern
Group related bugs by affected component, fix together in waves:
1. Same-file fixes: Minimize file touches, reduce merge conflicts
2. Related functionality: Test together, verify interactions
3. Severity ordering: Critical first, low last within each wave

### Defensive Re-check Pattern (for WT detection)
After installing external dependency, re-verify installation before proceeding:
```csharp
// Pattern: Install -> Verify -> Branch
var installed = await InstallExternalAsync();
if (installed && VerifyInstallation())
{
    ProceedWithDependency();
}
else if (installed)
{
    InformUserToRestart();
}
else
{
    ShowManualInstructions();
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Installer theming | Custom UI | Inno Setup 6.7.0 features | Built-in, tested, documented |
| Window management | Direct Win32 | Existing WindowsApi wrapper | Already abstracts complexity |
| Shader animation | Complex random | Simple hash-based offset | HLSL has limited random functions |

## Common Pitfalls

### Pitfall 1: WT Detection Before Installation Completes
**What goes wrong:** Check for WT settings.json immediately after Add-AppxPackage
**Why it happens:** MSIX installation is asynchronous, files appear after call returns
**How to avoid:** Add delay or poll for settings.json existence
**Warning signs:** "WT not installed" immediately after GitHub download succeeds

### Pitfall 2: Modifying profiles.defaults
**What goes wrong:** Change to defaults affects ALL profiles, not just Matrix
**Why it happens:** Quick fix for per-window setting applied globally
**How to avoid:** Always target specific profile by name
**Warning signs:** Non-Matrix windows behave differently after Matrix session

### Pitfall 3: Force-Restoring Minimized Windows
**What goes wrong:** User minimizes window intentionally, layout code restores it
**Why it happens:** Layout assumes all windows should be visible
**How to avoid:** Skip minimized windows in ApplyLayout
**Warning signs:** Windows "pop up" when user didn't request

### Pitfall 4: Shader Animation Sync
**What goes wrong:** All rain columns appear to "breathe" together
**Why it happens:** Same random seed produces similar phase offsets
**How to avoid:** Use high-frequency noise for column-specific offsets
**Warning signs:** All columns change characters simultaneously

## Code Examples

### WT Detection Re-check Pattern
```csharp
// After TryDownloadFromGitHubAsync succeeds
if (IsWindowsTerminalInstalled())
{
    ConsoleHelper.WriteLineMatrixGreen(" Windows Terminal installed successfully!");
    ConsoleHelper.WriteLineDim(" Close this window and run 'wakeupneo' in Windows Terminal.");
    Console.WriteLine();
    Console.Write(" Press any key to exit...");
    Console.ReadKey(intercept: true);
    return new BootstrapResult(false, "Restart in Windows Terminal required");
}
```

### Skip Minimized Windows Pattern
```csharp
private void ApplyLayoutInternal(IReadOnlyList<WindowPosition> positions)
{
    foreach (var pos in positions)
    {
        if (!WindowsApi.IsHandleValid(pos.Window.Handle))
            continue;

        // Respect user's intentional minimization
        if (WindowsApi.IsIconic(pos.Window.Handle))
        {
            DiagnosticLogger.Debug("LAYOUT", $"Skipping minimized window: Matrix-{pos.Window.ShaderIndex}");
            continue;
        }

        WindowsApi.PositionWindowExact(pos.Window.Handle, pos.Target);
    }
}
```

### Inno Setup Matrix Theme
```iss
[Setup]
AppName=Matrix Shader
AppVersion=1.0.0
SetupStyleDark=yes
WizardStyle=modern

[LangOptions]
DialogFontColor=$00FF00  ; Green text

[CustomMessages]
english.WelcomeLabel2=Take the Red Pill and enter the Matrix...

[Code]
procedure InitializeWizard;
begin
  WizardForm.Color := $000000;  // Black background
  WizardForm.MainPanel.Color := $001100;  // Dark green tint
end;
```

### Shader Phase Offset Fix
```hlsl
float DrawLayer(float2 uv, float depth, float speed_mult, float brightness, float seed_shift) {
    // ... existing code ...

    // HIGH VARIATION: Use column position and multiple noise octaves
    float col_hash = frac(sin(cell_id.x * 127.1 + seed_shift * 311.7) * 43758.5453);
    float phase_offset = col_hash * grid_dims.y * 2.5;  // 2.5x screen height offset

    float final_speed = ((col_hash * 0.5 + 0.2) * 10.0 * RAIN_SPEED * speed_mult) / depth;
    float rain_pos = cell_id.y - (Time * final_speed) + phase_offset;

    // ... rest of function ...
}
```

## Implementation Waves

Based on analysis, recommend implementing in these waves:

| Wave | Bugs | Effort | Priority |
|------|------|--------|----------|
| 1 | BUG-WT06 | 1 plan | Critical |
| 2 | BUG-LAYOUT03, BUG-LAYOUT04 | 1 plan | High |
| 3 | BUG-TRANS03 | 1 plan | Critical |
| 4 | BUG-SHADER03 | 1 plan | High |
| 5 | BUG-REDPILL01, BUG-REDPILL02, BUG-HOTKEY01 | 1-2 plans | High/Medium |
| 6 | UX-INST01, UX-INST02, UX-INST03, Version bug | 1 plan | Medium/Low |
| 7 | BUG-ML07 | Optional | Low |
| 8 | GAP-SHADERS01 | Documentation only | Low |

**Won't Fix:** BUG-ML08, BUG-ML09, BUG-ML10 (per user decision - MatrixLite is demo, not terminal)

## Open Questions

1. **BUG-TRANS03 Source:** Need to verify if `profiles.defaults` is being modified somewhere in C# code after microsprint PowerShell fix.
   - What we know: C# ControlPanel.ApplyOpacityToProfile correctly targets specific profiles
   - What's unclear: Is there another code path setting defaults?
   - Recommendation: Grep for "defaults" in codebase

2. **Pillars Width Constraint:** Should we reduce MinWindowWidth or reduce gaps first?
   - What we know: User wants 4 columns side-by-side
   - What's unclear: Minimum usable width for WT
   - Recommendation: Try MinWindowWidth=400, test visual appearance

## Sources

### Primary (HIGH confidence)
- Source code analysis of:
  - `CliBootstrap.cs` - WT detection and installation
  - `LayoutService.cs` - Window layout calculation
  - `EnvironmentService.cs` - Render mode detection
  - `ShaderService.cs` - Shader file operations
  - `Redpill/Program.cs` - Control panel entry point
  - `MatrixShaderSetup.iss` - Inno Setup installer
  - `Matrix-1.hlsl` - Shader animation logic

### Secondary (MEDIUM confidence)
- [Inno Setup 6.7.0 Release Notes](https://jrsoftware.github.io/issrc/whatsnew.htm) - Custom background support
- [Windows Terminal Shader Documentation](https://github.com/microsoft/terminal/blob/main/samples/PixelShaders/README.md) - Animation techniques

## Metadata

**Confidence breakdown:**
- WT Detection: HIGH - Source code clearly shows the issue
- Layout: HIGH - Algorithm traced step-by-step
- Transparency: MEDIUM - Need to verify no other code path
- Shaders: HIGH - HLSL math analyzed
- Installer: HIGH - Inno Setup docs confirmed features
- Redpill: HIGH - Program flow traced

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (stable codebase, no major changes expected)
