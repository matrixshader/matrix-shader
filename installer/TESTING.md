# Matrix Shader Installer Testing Guide

Use Windows Sandbox to test the installer on a clean system.

## Prerequisites

- Windows 10 Pro/Enterprise or Windows 11 with Windows Sandbox enabled
- Built installer at `installer/output/MatrixShaderSetup.exe`
- Install script at `installer/install.ps1`

## Setup Windows Sandbox

1. Enable Windows Sandbox (Settings > Apps > Optional Features > More Windows features)
2. Create a shared folder for the installer
3. Copy MatrixShaderSetup.exe and install.ps1 to the shared folder

## Testing Checklist

### E2E-00: One-Liner Install (Primary)
- [ ] Run `irm https://matrixshader.com/install.ps1 | iex` in PowerShell
- [ ] Script downloads and extracts executables
- [ ] All 6 executables installed to correct location
- [ ] Shaders copied to `%LOCALAPPDATA%\MatrixShader\shaders\`
- [ ] PATH updated (verify with `where wakeupneo`)
- [ ] Success message shows next steps

### E2E-00a: One-Liner Install (Non-Admin)
- [ ] Run without admin privileges
- [ ] Installs to `%LOCALAPPDATA%\Programs\MatrixShader\`
- [ ] User PATH updated (not system PATH)
- [ ] All commands work from new terminal

### E2E-00b: One-Liner Uninstall
- [ ] Run `irm https://matrixshader.com/uninstall.ps1 | iex`
- [ ] All executables removed
- [ ] PATH entry removed
- [ ] User data optionally preserved or removed

### E2E-01: GUI Installer (Alternative)
- [ ] Installer runs without errors
- [ ] All 6 executables present in `C:\Program Files\MatrixShader\`:
  - [ ] wakeupneo.exe
  - [ ] bluepill.exe
  - [ ] redpill.exe
  - [ ] matrixlite.exe
  - [ ] matrix-hotkeys.exe
  - [ ] matrix-monitor.exe
- [ ] Shaders present in `C:\Program Files\MatrixShader\shaders\`
- [ ] Shaders copied to `%LOCALAPPDATA%\MatrixShader\shaders\`

### E2E-02: PATH Configuration
- [ ] Post-install message mentions "new terminal"
- [ ] Open NEW CMD window (not PowerShell - `where` works differently there)
- [ ] `where wakeupneo` shows correct path
- [ ] `where bluepill` shows correct path

### E2E-03: Windows Terminal Installation
- [ ] If WT not present, installer offers to install via winget
- [ ] After WT install, settings.json exists

### E2E-04: wakeupneo (First-Run)
- [ ] Run `wakeupneo` in new terminal
- [ ] Wizard completes without errors
- [ ] Matrix profiles created in Windows Terminal (check WT dropdown)
- [ ] Shader paths in profiles point to `%LOCALAPPDATA%\MatrixShader\shaders\`

### E2E-05: bluepill (Session Restore)
- [ ] Run `bluepill` in new terminal
- [ ] If no saved session, enters Lite mode gracefully
- [ ] If previous session exists, windows launch

### E2E-06: redpill (Control Panel)
- [ ] Run `redpill` in new terminal
- [ ] TUI displays correctly
- [ ] Can adjust shader parameters
- [ ] Changes reflect in shader windows

### E2E-07: matrixlite (Fallback Mode)
- [ ] Run `matrixlite` in CMD (not Windows Terminal)
- [ ] Text-based Matrix rain displays
- [ ] Colors work via ANSI codes
- [ ] Keyboard controls respond

### E2E-08: Uninstall
- [ ] Run uninstaller from Control Panel
- [ ] Executables removed from `C:\Program Files\MatrixShader\`
- [ ] `%LOCALAPPDATA%\MatrixShader\` removed
- [ ] PATH entry removed (check in new terminal)

## Windows Sandbox Config (.wsb)

Save as `MatrixShaderTest.wsb` and double-click to launch:

```xml
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Users\ehome\Documents\Matrix\installer\output</HostFolder>
      <SandboxFolder>C:\Installer</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
</Configuration>
```

Update `HostFolder` to your actual path if different.

## Reporting Issues

If any check fails:
1. Note which step failed
2. Copy error messages
3. Check `%LOCALAPPDATA%\MatrixShader\debug.log` if MATRIX_DEBUG=1 was set
4. Report in GitHub issues with Windows version and WT version

## Quick Verification Commands

Run these in PowerShell after installation:

```powershell
# Check executables
ls "C:\Program Files\MatrixShader\*.exe"

# Check PATH
$env:PATH -split ';' | Where-Object { $_ -match 'MatrixShader' }

# Check shaders
ls "$env:LOCALAPPDATA\MatrixShader\shaders\*.hlsl"

# Test command availability
where wakeupneo
where bluepill
where redpill
where matrixlite
```

---

## Test Session: 2026-01-31 (Windows Sandbox)

### Environment
- Windows Sandbox (minimal environment)
- No winget pre-installed
- No Microsoft Store available
- Networking enabled, vGPU enabled

### Results

#### E2E-01: GUI Installer ✅ PASS
- [x] Installer runs without errors
- [x] Installation completes successfully
- [x] Success message shows command list

#### E2E-02: PATH Configuration ⚠️ NOT TESTED
- Could not test - WT not available

#### E2E-03: Windows Terminal Installation ❌ ISSUES FOUND
- [x] wakeupneo detects WT not installed
- [x] Offers fallback to matrixlite
- [x] Attempts winget install (fails - winget not in sandbox)
- [x] Falls back to Microsoft Store (fails - Store not in sandbox)
- **GAP-E03a:** No detection of missing winget before attempting install
- **GAP-E03b:** No direct download fallback when both winget and Store fail
- **GAP-E03c:** Should offer GitHub releases as last resort

#### E2E-04: wakeupneo (First-Run) ⚠️ PARTIAL
- [x] Runs without crashing
- [x] Detects missing WT correctly
- [ ] Could not test profile creation (no WT)

#### E2E-07: matrixlite (Fallback Mode) ❌ CRITICAL ISSUES
- [x] Loads and displays menu
- [x] Katakana characters DO appear (ｬ ﾍ ｳ ｵ ﾋ ﾙ ｩ etc.)
- **BUG-ML01:** ANSI escape codes print as raw text instead of being interpreted. The color codes (e.g., `38;2;0;255;0`) appear as literal characters in the rain instead of coloring the Katakana.
  - **ROOT CAUSE FOUND:** `TextMatrixRenderer.Initialize()` never enables Virtual Terminal Processing. Windows cmd.exe requires `SetConsoleMode` with `ENABLE_VIRTUAL_TERMINAL_PROCESSING` flag (0x0004) before ANSI codes are interpreted. Without this P/Invoke call, cmd just prints raw escape sequences.
  - **FIX:** Add kernel32.dll P/Invoke for GetStdHandle + SetConsoleMode, call in Initialize() before any ANSI output.
- **BUG-ML02:** Terminal is blocked while running (cannot use terminal)
- **BUG-ML03:** Missing "bluepill" option that existed in older version
- **BUG-ML04:** Menu is broken (same issue as previous version)
- **BUG-ML05:** Color is BLUE (rgb 0,132,221) instead of GREEN - not Matrix-themed!
- **BUG-ML06:** Some characters render WHITE (rgb 255,255,255) instead of green

### Gaps Identified

| ID | Severity | Description |
|----|----------|-------------|
| GAP-E03a | Medium | wakeupneo doesn't detect missing winget before attempting install |
| GAP-E03b | Medium | No direct download fallback for WT when winget/Store fail |
| GAP-E03c | **Critical** | Should offer GitHub direct download as last resort - current flow is a DEAD END when winget and Store both fail |
| BUG-ML01 | Critical | matrixlite shows numbers instead of Katakana characters |
| BUG-ML02 | Critical | matrixlite blocks terminal - can't run other commands |
| BUG-ML03 | Medium | matrixlite missing bluepill/background mode option |
| BUG-ML04 | High | matrixlite menu is broken |
| BUG-ML05 | Medium | matrixlite text is white in cmd.exe (missing VT Processing) but works in WT |
| BUG-WT01 | **Critical** | Windows Terminal detection broken - TWO issues: (1) `EnvironmentService.IsWindowsTerminal()` only checks `WT_SESSION` env var; (2) `CliBootstrap.IsWindowsTerminalInstalled()` only checks ONE hardcoded Store path. Should check ALL install locations: Store, Scoop (`%USERPROFILE%\scoop\apps\windows-terminal`), Chocolatey, Portable (`<exe>\settings\`), GitHub zip. Also check `wt.exe` in PATH, parent process name. |
| BUG-WT02 | High | Can't test wakeupneo/redpill/bluepill because WT detection fails - they all fall back to Lite mode |
| BUG-FRX01 | Medium | Fresh install shows "Previous sessions found 8 window slots" - should show nothing on first run. First-run detection is broken. |
| BUG-WT03 | High | Window launching uses hardcoded `wt.exe` - fails for portable installs not in PATH. Should find WT executable dynamically or allow user to specify path. |
| BUG-WT04 | High | Profile/settings written to Store path even for portable WT. Portable WT uses `<exe>\settings\settings.json`, not `%LOCALAPPDATA%\Packages\...`. Profiles never applied. |
| BUG-SHADER01 | **CRITICAL** | Shader #define generation is broken. Top of shader shows `$10.0` instead of `#define RAIN_R 0.0`. Looks like regex replacement bug - `$1` is a regex backreference that's not being processed correctly. The bulk of HLSL code is valid, just the parameter defines are garbage. |
| GAP-INST01 | Medium | Re-running installer should detect existing install and offer Update/Repair/Uninstall options instead of blindly overwriting. |
| BUG-UNINST01 | High | Uninstall error message is useless: "Some elements could not be removed. These can be removed manually. OK" - doesn't say WHAT files, WHERE they are, WHY removal failed, or HOW to remove manually. Must provide actionable details. |
| BUG-UNINST02 | **CRITICAL** | Uninstaller leaves entire Program Files installation behind (54+ DLLs, all executables). Removes user data from %LOCALAPPDATA% and removes from PATH, but leaves ~50MB of orphaned files in Program Files. |

### Notes
- Windows Sandbox is very minimal - no winget, no Store
- Real fresh Windows 10/11 installs should have winget available
- matrixlite needs significant work before release
- GUI installer itself works perfectly

### Process Failure: Phase 10 Verification
- Phase 10 (matrixlite-fallback) was marked "PASSED 4/4" by gsd-verifier
- Verification was CODE-LEVEL ONLY - checked files exist, methods exist, wiring exists
- 5 HUMAN VERIFICATION TESTS were listed as "required" but NEVER PERFORMED:
  1. Visual Appearance Test
  2. Graceful Degradation Test
  3. Terminal Resize Handling Test
  4. Non-Windows-Terminal Compatibility Test
  5. Standalone MatrixLite Operation Test
- Phase was marked "Ready to proceed to installer integration" without running in cmd.exe
- Result: Critical bug (missing VT Processing) shipped to installer phase

### Next Steps
1. Fix matrixlite critical bugs before release (VT Processing)
2. Fix WT detection to work with portable installs (BUG-WT01)
3. Add winget detection to wakeupneo
4. Add GitHub direct download fallback for WT
5. Test on real fresh Windows install (VM or spare machine)

### Future Vision (v2.0+)
- Support ANY shader-capable terminal, not just Windows Terminal
- Port shaders from HLSL (DirectX) to GLSL for Mac/Linux
- Target: Alacritty, Kitty, other GPU-accelerated terminals
- Detection should ask "does this terminal support shaders?" not "is this WT?"

---

## Test Session: 2026-02-01 (Phase 12 Gap Closure Verification)

### Environment
- Windows Sandbox (minimal environment)
- Testing: Phase 12 bug fixes (plans 12-01 through 12-06)

### Bug Fix Verification Checklist

#### E2E-01: GUI Installer
- [ ] Run MatrixShaderSetup.exe from `C:\Installer`
- [ ] Installation completes without errors
- [ ] All 6 executables in `C:\Program Files\MatrixShader`:
  - [ ] wakeupneo.exe
  - [ ] bluepill.exe
  - [ ] redpill.exe
  - [ ] matrixlite.exe
  - [ ] matrix-hotkeys.exe
  - [ ] matrix-monitor.exe
- [ ] Shaders in `%LOCALAPPDATA%\MatrixShader\shaders`

#### BUG-SHADER01: Shader generation (CRITICAL)
- [ ] Run wakeupneo, create one window
- [ ] Check shader: `type %LOCALAPPDATA%\MatrixShader\shaders\Matrix-1.hlsl | findstr "RAIN_R"`
- [ ] Should show `#define RAIN_R 0.0` NOT `$10.0`

#### BUG-ML01/05/06: MatrixLite in cmd.exe (CRITICAL)
- [ ] Open CMD (not PowerShell, not Windows Terminal)
- [ ] Run `matrixlite`
- [ ] See intro animation (not raw escape codes)
- [ ] See Red/Blue Pill choice
- [ ] Press B for Blue Pill - rain starts immediately
- [ ] Characters are GREEN (not blue, not all white)
- [ ] Head characters white, trail fades to dim green
- [ ] Press Q to return to menu

#### BUG-ML02/03/04: MatrixLite UX
- [ ] Menu responds to all keys
- [ ] [B] Blue Pill option exists (background mode)
- [ ] Terminal is NOT blocked while running

#### BUG-WT01/02: WT Detection (without WT installed)
- [ ] Run `wakeupneo` without WT installed
- [ ] Should detect WT missing and offer install options
- [ ] Should NOT silently fail or crash

#### GAP-E03a/b/c: WT Installation flow (no dead ends)
- [ ] winget detection: Shows "winget not available" (not crash)
- [ ] Store option offered
- [ ] GitHub download option offered
- [ ] Manual instructions shown as last resort
- [ ] No dead ends - always shows a path forward

#### BUG-FRX01: First-run detection
- [ ] Fresh sandbox shows normal intro
- [ ] Does NOT show "Previous sessions found 8 window slots"

#### GAP-INST01: Installer re-run detection
- [ ] Run installer again (with previous install)
- [ ] See Update/Uninstall/Cancel dialog
- [ ] Select Update - proceeds with installation

#### BUG-UNINST01/02: Uninstaller (CRITICAL)
- [ ] Uninstall via Control Panel
- [ ] `C:\Program Files\MatrixShader` folder is EMPTY or GONE
- [ ] No 54+ DLLs left behind
- [ ] If any files remain, error message is actionable (WHAT/WHERE/WHY/HOW)

### Skipped Phase 10 Tests (NOW REQUIRED)
These were marked "passed" but never actually performed:

- [ ] Visual Appearance Test - MatrixLite looks correct (green, not blue/white)
- [ ] Graceful Degradation Test - Falls back properly when WT unavailable
- [ ] Terminal Resize Handling - Handles window resize without crash
- [ ] Non-Windows-Terminal Compatibility - Works in cmd.exe (ANSI codes interpreted)
- [ ] Standalone MatrixLite Operation - Full standalone functionality works

### Results Summary - Phase 12 Bug Fixes

| Bug ID | Description | Status | Notes |
|--------|-------------|--------|-------|
| BUG-SHADER01 | Regex replacement bug | **UNTESTED** | Need to check shader file |
| BUG-ML01 | VT Processing missing | **UNTESTED** | Skipped matrixlite for now |
| BUG-ML02 | Terminal blocked | **UNTESTED** | |
| BUG-ML03 | Missing background mode | **UNTESTED** | |
| BUG-ML04 | Menu broken | **UNTESTED** | |
| BUG-ML05 | Blue instead of green | **UNTESTED** | |
| BUG-ML06 | White characters | **UNTESTED** | |
| BUG-WT01 | WT detection broken | **PASS** ✅ | Detected WT missing correctly |
| BUG-WT02 | Can't test WT apps | **PASS** ✅ | After WT installed, wakeupneo worked |
| BUG-WT03 | Hardcoded wt.exe | **UNTESTED** | |
| BUG-WT04 | Wrong settings.json | **UNTESTED** | |
| GAP-E03a | No winget detection | **PASS** ✅ | Shows "winget not available" |
| GAP-E03b | No download fallback | **PASS** ✅ | GitHub download works |
| GAP-E03c | Dead end flow | **PARTIAL** ⚠️ | Downloads but doesn't auto-install deps |
| BUG-FRX01 | False previous sessions | **PASS** ✅ | No false "Previous sessions found" |
| GAP-INST01 | Blind overwrite | **UNTESTED** | |
| BUG-UNINST01 | Useless error | **UNTESTED** | |
| BUG-UNINST02 | Files left behind | **UNTESTED** | |

### NEW Bugs Found During This Test Session

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-WT05 | High | GitHub fallback downloads msixbundle but doesn't install XAML dependency - needs 4-line install sequence |
| BUG-TRANS01 | Critical | Transparency applied to WRONG windows (wakeupneo, redpill) instead of Matrix windows |
| BUG-SHADER02 | High | Redpill-Neo custom shader not applied to redpill window |
| BUG-LAYOUT01 | High | No auto-reposition when monitor/sandbox resizes |
| BUG-LAYOUT02 | High | Glitch system not working - no auto-reposition on window overlap |
| BUG-DEFAULT01 | Medium | Default rain density too high (should match user's current system levels) |
| BUG-CRASH01 | Critical | Sandbox froze/white screen - CPU pegged at 100% |

### Working WT Installation Commands (CRITICAL - Save These!)

When GitHub msixbundle download fails due to missing dependencies, use these 4 commands:

```cmd
REM Line 1 - Download XAML dependency from official NuGet
curl -L -o %TEMP%\xaml.zip https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6

REM Line 2 - Extract it
powershell Expand-Archive -Path $env:TEMP\xaml.zip -DestinationPath $env:TEMP\xaml -Force

REM Line 3 - Install the XAML framework
powershell Add-AppxPackage -Path $env:TEMP\xaml\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx

REM Line 4 - NOW install Windows Terminal
powershell Add-AppxPackage (Get-ChildItem $env:TEMP -Filter '*WindowsTerminal*.msixbundle' -Recurse)[0].FullName
```

**These commands MUST be integrated into wakeupneo's GitHub fallback path (BUG-WT05 fix).**

### Test Session Progress

**E2E-01: GUI Installer** - PASS ✅
- Installer ran without errors
- All 6 executables present in Program Files

**E2E-02: PATH Configuration** - PASS ✅
- `where wakeupneo` and `where bluepill` work in CMD

**BUG-FRX01: First-run detection** - PASS ✅
- No false "Previous sessions found" message

**GAP-E03a/b/c: WT Installation flow** - PARTIAL ⚠️
- winget detection: PASS
- Store fallback: PASS (offered)
- GitHub download: PASS (100%)
- Auto-install: FAIL (missing dependency handling)
- Manual fallback message: Shows but incomplete

**wakeupneo wizard (after manual WT install)** - PARTIAL ⚠️
- Green text UI: PASS
- Created 4 windows: PASS
- Positioned as quads: PASS
- Rain shader runs: PASS
- Transparency: FAIL (applied to wrong windows)
- Redpill-Neo shader: FAIL (not applied)
- Layout resize: FAIL (no auto-reposition)
- Glitch system: FAIL (no overlap detection)
- Default density: FAIL (too dense)
- Stability: FAIL (froze, CPU 100%)

### Conclusion
Testing interrupted by sandbox freeze (CPU 100%). Multiple Phase 12 fixes verified working, but NEW critical bugs discovered in transparency, layout, and shader assignment.

---

## Microsprint: 2026-02-01 (Bug Fixes During Lunch Break)

### Bugs Fixed

| Bug ID | Description | Fix Applied |
|--------|-------------|-------------|
| BUG-WT05 | GitHub fallback doesn't install XAML dependency | Added `TryInstallXamlDependencyAsync` - downloads XAML 2.8.6 from NuGet, extracts, and installs before WT |
| BUG-DEFAULT01 | Default rain density too high | Lowered default from 0.4 to 0.25 in `ShaderConfig.cs` |
| BUG-TRANS01 | Transparency on wrong windows | Removed `profiles.defaults` modification in `matrix_control.ps1` - now only affects Matrix-N profiles |
| BUG-SHADER02 | Redpill-Neo shader not applied | Added `CreateRedpillProfile()` call in `WakeupNeo/Program.cs` |
| BUG-LAYOUT01 | No auto-reposition on monitor resize | Added `WM_DISPLAYCHANGE` handling in `HotkeyWindow.cs` |
| BUG-LAYOUT02 | Glitch system not working | Added overlap detection in `MatrixWindowMonitor.cs` with 2-second polling |
| BUG-CRASH01 | CPU 100% freeze | INCONCLUSIVE - likely WMI/UI Automation contention in sandbox, no infinite loop found |

### Files Modified

- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` - XAML dependency install
- `MatrixShader/src/MatrixShader.Core/Models/ShaderConfig.cs` - Default density
- `matrix_control.ps1` - Transparency fix
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` - Redpill profile creation
- `MatrixShader/src/MatrixShader.Core/Native/HotkeyApi.cs` - WM_DISPLAYCHANGE constant
- `MatrixShader/src/MatrixShader.Hotkeys/HotkeyWindow.cs` - Display change events
- `MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs` - Overlap detection
- `MatrixShader/src/MatrixShader.Hotkeys/Program.cs` - Layout service integration

### Working WT Installation Commands (CRITICAL - Save These!)

When GitHub msixbundle download fails due to missing dependencies, use these 4 commands:

```cmd
REM Line 1 - Download XAML dependency from official NuGet
curl -L -o %TEMP%\xaml.zip https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6

REM Line 2 - Extract it
powershell Expand-Archive -Path $env:TEMP\xaml.zip -DestinationPath $env:TEMP\xaml -Force

REM Line 3 - Install the XAML framework
powershell Add-AppxPackage -Path $env:TEMP\xaml\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx

REM Line 4 - NOW install Windows Terminal
powershell Add-AppxPackage (Get-ChildItem $env:TEMP -Filter '*WindowsTerminal*.msixbundle' -Recurse)[0].FullName
```

**These commands are now integrated into wakeupneo's GitHub fallback path.**

### Installer Rebuilt

- **File:** `installer/output/MatrixShaderSetup.exe`
- **Size:** 52.63 MB
- **Contains:** All 7 bug fixes above

### Ready for Retest

Dark-mode sandbox launched with new installer. Continue testing from where we left off.

---

## Test Session: 2026-02-01 (Post-Microsprint Retest)

### Environment
- Windows Sandbox with dark mode (manually set)
- Installer with 6 bug fixes from microsprint

### PASSED ✅

| Test | Result | Notes |
|------|--------|-------|
| BUG-WT05 XAML install | ✅ PASS | Installer DID install WT from GitHub automatically! |
| MatrixLite in WT | ✅ PASS | Colors work, runs in WT |
| Redpill-Neo shader | ✅ PASS | Shows up, looks badass |
| Hotkeys | ✅ PASS | Ctrl+Shift+L cycles Pillars/Quads/Tiles |
| Transparency per-window | ✅ PASS | Only affects selected window |
| Bluepill restore | ✅ PASS | Restores closed 4th window correctly |
| Auto-resize on close | ✅ PASS | 3 windows repositioned correctly when 4th closed |
| Drag and snap | ✅ PASS | Works |
| Uninstall error message | ✅ PASS | WHAT/WHERE/WHY/HOW format - beautifully helpful |
| Clean uninstall | ✅ PASS | Second attempt (after closing windows) removed everything |

### BUGS/ISSUES FOUND

#### WT Detection (Still Broken)

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-WT06 | Critical | After installing WT, wakeupneo STILL thought WT wasn't installed and ran Lite. Only after manually typing `wt` to open WT, THEN running wakeupneo inside it, did it finally recognize WT. Detection check not exhaustive enough. |
| GAP-CMD01 | Medium | After installing WT, can't open CMD outside of it - all terminals open in WT |

#### MatrixLite Issues

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-ML07 | Medium | Splash screen only works in WT, not in naked PowerShell/CMD |
| BUG-ML08 | Critical | Pressing B (background mode) doesn't work - same as Enter, just visual, can't type commands |
| BUG-ML09 | High | Enter supposed to make fullscreen but just makes full-window, same as B |
| BUG-ML10 | Critical | MatrixLite takes over entire terminal - supposed to allow typing commands behind the effect |

#### Shader Issues

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-SHADER03 | High | Shaders not running correctly - don't start at top, "bleed out everywhere", every row falls at same time, too in sync, not accurate looking |

#### Layout Issues

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-LAYOUT03 | High | 4 pillars layout wrong - showed 3 on top + 1 below (tiles) instead of 4 pillars side by side |
| BUG-LAYOUT04 | Medium | Minimized windows pop back up - should respect user minimizing, only reposition others if dragged or closed |

#### Transparency Issues

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-TRANS02 | FEATURE | wakeupneo window becomes 100% transparent when shader windows launch - USER LIKES THIS, KEEP IT |
| BUG-TRANS03 | Critical | After installing WT, ALL new windows open 100% transparent - not just Matrix windows. WT transparency stuck. |

#### Redpill Issues

| Bug ID | Severity | Description |
|--------|----------|-------------|
| BUG-REDPILL01 | High | Redpill opens in same window typed in, not in its own window with special shader |
| BUG-REDPILL02 | Medium | Redpill menu repeating things the longer it's open - looks strange |
| BUG-HOTKEY01 | Medium | Can't find where to learn about hotkeys or change them in redpill menu |

#### Installer UX

| Bug ID | Severity | Description |
|--------|----------|-------------|
| UX-INST01 | Medium | Re-run dialog should use Matrix theming: "Blue Pill (Update/Repair)" and "Red Pill (Uninstall)" then "Jack Back In (Clean Reinstall)" |
| UX-INST02 | Low | Cancel button unnecessary - there's an X in the corner |
| UX-INST03 | Low | Installer should look cooler overall |

#### Miscellaneous

| Bug ID | Severity | Description |
|--------|----------|-------------|
| GAP-SHADERS01 | Low | Can't find shaders in localappdata folder in sandbox explorer |
| REQUEST-CMATRIX | Research | Research cmatrix for features our lite version should have |

### Feature Requests

1. **Default transparency**: Shaders should default to ~85% transparency when launched from wakeupneo
2. **Keep wakeupneo transparency**: The 100% transparent wakeupneo window effect is cool - intentionalize it

### Summary

**Microsprint fixes verified:**
- ✅ BUG-WT05: XAML dependency install WORKS
- ✅ BUG-SHADER02: Redpill-Neo shader WORKS
- ⚠️ BUG-TRANS01: Partially fixed (but new issues BUG-TRANS03)
- ✅ BUG-LAYOUT01/02: Auto-reposition WORKS (but new issues BUG-LAYOUT03/04)
- ✅ BUG-DEFAULT01: Density lower (but shader sync issue BUG-SHADER03)

**New bugs found: 17**
**Phase 13 needed to address these issues.**
