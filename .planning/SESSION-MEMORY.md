# SESSION-MEMORY.md
# Matrix Terminal Shader - Institutional Knowledge
# Last updated: 2026-02-22
# PURPOSE: Prevent context loss between Claude Code sessions. READ THIS FIRST.

---

## Critical Deployment Facts

### File Locations

| What | Path |
|------|------|
| Source code | `C:\Users\ehome\documents\matrix\MatrixShader\` |
| Build output | `C:\Users\ehome\documents\matrix\MatrixShader\publish\{component}\` |
| Installed binaries | `C:\Users\ehome\AppData\Local\Programs\MatrixShader\` |
| Shader files (runtime) | `C:\Users\ehome\AppData\Local\MatrixShader\shaders\` |
| State file | `C:\Users\ehome\AppData\Local\MatrixShader\matrix_state.json` |
| Identity registry | `C:\Users\ehome\AppData\Local\MatrixShader\identity-registry.json` |
| Debug log | `C:\Users\ehome\Documents\Matrix\debug.log` |
| WT settings.json | `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| WT settings backup | Same path with `.matrix-backup` extension |

### Build Commands

```bash
# Build hotkeys (most common rebuild target)
cd C:\Users\ehome\documents\matrix\MatrixShader
dotnet publish src/MatrixShader.Hotkeys/MatrixShader.Hotkeys.csproj -c Release -r win-x64 --self-contained -p:PublishAot=false -p:PublishTrimmed=false -o publish/hotkeys

# Build redpill (control panel TUI)
dotnet publish src/MatrixShader.Cli/Redpill/MatrixShader.Cli.Redpill.csproj -c Release -r win-x64 --self-contained -p:PublishAot=false -p:PublishTrimmed=false -o publish/redpill

# Build bluepill
dotnet publish src/MatrixShader.Cli/BluePill/MatrixShader.Cli.BluePill.csproj -c Release -r win-x64 --self-contained -p:PublishAot=false -p:PublishTrimmed=false -o publish/bluepill

# Build wakeupneo
dotnet publish src/MatrixShader.Cli/WakeupNeo/MatrixShader.Cli.WakeupNeo.csproj -c Release -r win-x64 --self-contained -p:PublishAot=false -p:PublishTrimmed=false -o publish/wakeupneo
```

### MANDATORY Post-Build Step

**AFTER EVERY BUILD you MUST copy from `publish/{component}/` to `C:\Users\ehome\AppData\Local\Programs\MatrixShader\`** or nothing changes at runtime. The installed binaries are what actually run, not the publish output.

The copy often fails because the exe is locked by a running process. Use this procedure:

```powershell
# 1. Kill the watchdog FIRST (it respawns hotkeys)
taskkill /F /IM matrix-monitor.exe 2>&1 | Out-Null
Start-Sleep -Seconds 1

# 2. Kill the hotkeys process
taskkill /F /IM matrix-hotkeys.exe 2>&1 | Out-Null
Start-Sleep -Seconds 5

# 3. Copy (with rename fallback if file is still locked)
$src = 'C:\Users\ehome\documents\matrix\MatrixShader\publish\hotkeys\matrix-hotkeys.exe'
$dst = 'C:\Users\ehome\AppData\Local\Programs\MatrixShader\matrix-hotkeys.exe'
try {
    Copy-Item $src $dst -Force -ErrorAction Stop
} catch {
    Move-Item $dst "$dst.old" -Force -ErrorAction SilentlyContinue
    Copy-Item $src $dst -Force
    Remove-Item "$dst.old" -Force -ErrorAction SilentlyContinue
}

# 4. Start the new binary
Start-Process $dst -ArgumentList "--debug"
```

### CRITICAL: AOT and Trimming MUST Be Disabled

- `-p:PublishAot=false` -- AOT causes UiaProviderCallback marshalling errors
- `-p:PublishTrimmed=false` -- Trimming causes IL2104 errors with WPF/Toolkit assemblies
- These flags are NON-NEGOTIABLE. Do not remove them or the build will either fail or crash at runtime.

### CRITICAL: Never Use `-WindowStyle Hidden` for Hotkeys

Starting `matrix-hotkeys.exe` with `-WindowStyle Hidden` via `Start-Process` **breaks WM_HOTKEY message delivery**. The hotkeys will register successfully (13/13) but ZERO key presses will be received. This was a painful multi-hour debugging session. Always start it normally or with just `Start-Process $path`.

### MatrixShader.Core.dll is the Shared Library

`MatrixShader.Core.dll` contains ALL shared code: IdentityService, TerminalSettingsService, ConfigService, models, native API wrappers. It is compiled into EVERY executable (hotkeys, redpill, bluepill, wakeupneo). When you change Core code, you must rebuild ALL components that use it.

**Hotkeys and Redpill are SEPARATE processes with SEPARATE IdentityService instances and handle caches. They share NO in-memory state.** Both read/write to the same files on disk (settings.json, shader files, matrix_state.json).

---

## Identity Resolution System (6-Layer Hierarchy)

Windows are identified via a 6-layer cascade. Each layer is tried in order; first match wins.

### Layer 0: Handle Cache (in-memory)
- `ConcurrentDictionary<nint, WindowInfo> _handleCache`
- Once ANY layer identifies a window, the result is cached by window handle (HWND)
- Survives title changes because HWNDs do not change when shell/agent modifies the tab title
- **Lost on process restart** -- each process (hotkeys, redpill) has its own cache

### Layer 1: Launch Tracking
- In-memory `_launchRegistry` populated when WE launch `wt.exe -p "Matrix-N"`
- Persisted to `identity-registry.json` for crash recovery
- Confidence: 1.0 (fresh) / 0.95 (recovered from disk)
- **Only works for windows WE launched**, not pre-existing ones

### Layer 2: Command Line Parsing
- WMI batch query: `SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='WindowsTerminal.exe'`
- Parses `-p "Matrix-N"` from the command line
- Confidence: 0.9
- ~20ms per window, done in bulk

### Layer 3: Title Pattern Matching
- Regex: `Matrix-(\d+)` on the window title
- Confidence: 0.7
- **UNRELIABLE**: Agent processes (Claude Code) change the terminal title to their own commands
- Requires `suppressApplicationTitle: true` in WT profile, but shells can override it

### Layer 4: UI Automation (Tab Color)
- Walks the UI Automation tree to find tab color
- Maps color hex to shader index
- Confidence: 0.6
- SLOW: 100-300ms per window
- Only used as last resort

### Layer 5: Elimination (Gap Matching)
Two sub-modes:

**5a: Perfect elimination** -- When `missingIndices.Count == unidentified.Count`:
- If we identified indices [1, 2, 4] and there's exactly 1 unidentified window, it must be Matrix-3
- Assigns deterministically by screen position (left-to-right sort)

**5b: Position-based elimination** -- When `missingIndices.Count < unidentified.Count` (non-Matrix WT windows exist):
- For each missing index, interpolate expected X position from identified neighbors
- Find closest unidentified window to expected position
- **FIX APPLIED (2026-02-22)**: Previously used `Math.Max(profileCount, maxFromIdentified)` which inflated expected range from 8 profiles to actual 4 open windows. Changed to use only `maxFromIdentified`.

### Key Insight: Window Titles Are Worthless

The user runs Claude Code agents INSIDE Matrix terminal windows. These agents change the terminal title to whatever command they're running (e.g., "npm exec chrome-devtools-mcp@latest..."). **Title-based identity is fundamentally broken** for this workflow. The handle cache (Layer 0) is the real savior -- once identified by any other layer, the cache preserves identity through title changes.

---

## ForceShaderReload Mechanism

### How It Works (Current Implementation)

Windows Terminal does NOT watch `.hlsl` files for changes. It ONLY reloads shaders when `settings.json` changes AND the `pixelShaderPath` value changes.

The current implementation uses a **path toggle trick**:

```csharp
// In TerminalSettingsService.ForceShaderReload()
// Toggle between "shaders\\X" and "shaders\\.\\X"
// Both resolve to same file on disk, but WT sees different string -> reloads
```

This is a single atomic write (one File.WriteAllText call). It toggles `shaders\\` to `shaders\\.\\` and back. WT detects the path changed and re-reads the .hlsl file.

### Failed Approaches (DO NOT REPEAT)

1. **Re-saving settings.json with identical content**: WT ignores unchanged file content. Does nothing.
2. **Setting PixelShaderPath = null then restoring**: The null value serializes and WT drops ALL shaders. Restoring fails because C# model loses the property entirely on null. **THIS NUKED ALL SHADERS IN A LIVE SESSION.**
3. **Appending ".off" to .hlsl paths**: Worked for the "off" phase but the restore had timing issues.

### The Nuclear Incident (2026-02-21)

During the Color Sync session, a `ForceShaderReload` implementation that set `PixelShaderPath = null` then restored it caused ALL shader paths to be lost from settings.json. The emergency restore using PowerShell `ConvertTo-Json` further corrupted the file by:
- Changing `suppressApplicationTitle: true` to `False` (case change)
- Setting `Matrix-3 opacity` to 0 (invisible)
- Losing `tabColor` properties on Matrix-7, Matrix-8, Redpill

**Lesson**: NEVER use C# model round-trip serialization for ForceShaderReload. NEVER use PowerShell ConvertTo-Json on settings.json (it mangles property casing and types). Always use raw string manipulation.

---

## TerminalProfile Model -- Missing [JsonExtensionData]

**CRITICAL BUG (still present as of 2026-02-22)**:

The `TerminalProfile` record at `MatrixShader.Core\Models\TerminalProfile.cs` models only 8 properties:
- Name, Guid, Commandline, Hidden, Opacity, UseAcrylic, PixelShaderPath, TabColor, SuppressApplicationTitle

But WT profiles have MANY more properties (icon, font, colorScheme, backgroundImage, cursorShape, scrollbarState, padding, etc.). The `TerminalProfile` record **does NOT have `[JsonExtensionData]`**, unlike `TerminalSettings` and `ProfilesContainer` which do.

**Impact**: Any `LoadSettings() -> modify profile -> UpsertProfile() -> SaveSettings()` round-trip will LOSE all unmodeled profile properties. This destroys user customizations.

The `TerminalSettings` (top-level) and `ProfilesContainer` both correctly have `[JsonExtensionData]`, but `TerminalProfile` itself does not.

**Fix needed**: Add `[JsonExtensionData] public Dictionary<string, JsonElement>? ExtensionData { get; set; }` to `TerminalProfile`.

---

## Hotkey System

### 13 Registered Hotkeys

| # | Keys | Action | Handler Method |
|---|------|--------|---------------|
| 1 | Ctrl+Shift+Left | Rotate windows left | RotateWindows(-1) |
| 2 | Ctrl+Shift+Right | Rotate windows right | RotateWindows(1) |
| 3 | Ctrl+Shift+L | Cycle layout (Pillars/Quads) | CycleLayout() |
| 4 | Ctrl+Shift+B | Toggle transparency (85% <-> 100%) | ToggleTransparency() |
| 5 | Ctrl+Shift+J | Opacity down 5% | AdjustOpacity(-5) |
| 6 | Ctrl+Shift+K | Opacity up 5% | AdjustOpacity(5) |
| 7 | Ctrl+Shift+Down | Speed up rain (+0.5) | AdjustSpeed(+SpeedDelta) |
| 8 | Ctrl+Shift+Up | Slow down rain (-0.5) | AdjustSpeed(-SpeedDelta) |
| 9 | Ctrl+Shift+1 | Toggle Far layer | ToggleLayer(Far) |
| 10 | Ctrl+Shift+2 | Toggle Mid layer | ToggleLayer(Mid) |
| 11 | Ctrl+Shift+3 | Toggle Near layer | ToggleLayer(Near) |
| 12 | Ctrl+Shift+H | Show help overlay | ShowHelp -> SpawnOverlay() |
| 13 | Ctrl+Shift+F5 | Force shader reload | ManualReload -> ForceShaderReload() |

### Speed/Opacity Hotkey Flow

1. User presses Ctrl+Shift+Down while Matrix window focused
2. `HotkeyWindow` receives `WM_HOTKEY` message -> fires `HotkeyPressed` event
3. `Program.cs` dispatches to `AdjustSpeed(+0.5)` handler
4. `AdjustSpeed` calls `GetFocusedMatrixWindow()` to identify which Matrix window has focus
5. Reads current speed from `matrix_state.json`, adds delta, clamps to [0.1, 5.0]
6. Rewrites the .hlsl shader file with new `#define RAIN_SPEED` value
7. Calls `ForceShaderReload()` which toggles shader paths in settings.json
8. WT detects settings.json change, re-reads shader file, GPU renders new speed

### The Focus Requirement

`AdjustSpeed`, `AdjustOpacity`, `ToggleLayer` all call `GetFocusedMatrixWindow()` which uses `GetForegroundWindow()` to find which window currently has keyboard focus. **If the user is focused on a non-Matrix window (e.g., this Claude Code terminal), the hotkey fires but silently does nothing** because GetFocusedMatrixWindow returns null.

### Direction Convention (Feb 21 fix)

- **Ctrl+Shift+Down = Speed UP** (rain falls faster, matches rain direction -- down)
- **Ctrl+Shift+Up = Speed DOWN** (rain falls slower)
- This was swapped from the original to match user intuition.

---

## Glitch System (Window Overlap Detection)

The `MatrixWindowMonitor` runs in the hotkeys process, polling every 2 seconds.

### What Glitch Does
- Detects when two Matrix windows overlap more than 20%
- Triggers auto-repositioning using the layout engine
- Has a **5-second cooldown** after manual hotkey rotation (Ctrl+Shift+Left/Right) to prevent the Glitch from fighting user intent

### The Watchdog
`matrix-monitor.exe` runs as a separate process and respawns `matrix-hotkeys.exe` every 5 seconds if it crashes. **When debugging hotkeys, you MUST kill matrix-monitor.exe FIRST**, otherwise it will respawn the old binary before you can copy the new one.

---

## Known Bugs (as of 2026-02-22)

### OPEN BUGS

1. **TerminalProfile missing [JsonExtensionData]** -- Unmodeled profile properties lost on round-trip. Any hotkey that calls `UpsertProfile() -> SaveSettings()` (opacity change, transparency toggle) will strip custom profile properties. **High impact, not yet fixed.**

2. **Tab color not syncing with shader color** -- User reported that tab colors don't change when rain color is changed via hotkeys. The `SyncTabColorToShader` method exists but may not be wired up correctly in all code paths.

3. **Redpill TUI not picking up Matrix-3** -- The redpill process has its own IdentityService instance. When hotkeys identifies a window via elimination, redpill doesn't know about it because they share no in-memory state. Requires restarting redpill after hotkeys identifies new windows.

4. **Speed change visible lag** -- There's noticeable delay between pressing the speed hotkey and seeing the visual change. The ForceShaderReload path-toggle is a double-write (two File.WriteAllText calls with a Thread.Sleep between them). Could be optimized.

5. **Help overlay references removed features** -- The help screen previously referenced "Cycle shader in library" which was removed in Phase 14-05. Confirmed fixed in current code.

### FIXED BUGS (Reference)

| Bug ID | Description | Fix Applied | Session |
|--------|-------------|-------------|---------|
| BUG-TRANS04 | Transparency toggle changed acrylic instead of opacity | Changed to toggle Opacity 85% <-> 100% | 2026-02-05 |
| BUG-GLITCH01 | Glitch snap-back fights manual hotkey rotation | Added 5-second cooldown after manual rotation | 2026-02-05 |
| BUG-SHADER06 | Shader phase offsets wrong | Copied correct staggered shaders | 2026-02-05 |
| BUG-ELIM01 | Elimination used profile count (8) instead of open window count (4) | Changed to use max(identifiedIndices) | 2026-02-22 |
| BUG-ELIM02 | Elimination failed when non-Matrix WT windows exist | Added position-based gap matching | 2026-02-22 |
| BUG-RELOAD01 | PixelShaderPath=null nuked all shaders from settings.json | Changed to path-toggle (.\ trick) with raw string manipulation | 2026-02-21 |
| BUG-RELOAD02 | Re-saving identical settings.json doesn't trigger WT reload | Use path toggle instead of content re-save | 2026-02-21 |
| BUG-WMHOTKEY01 | Hotkeys register but WM_HOTKEY never delivered | Don't use -WindowStyle Hidden with Start-Process | 2026-02-21 |
| BUG-DIAG01 | DiagnosticLogger never initialized in hotkeys process | Added DiagnosticLogger.Initialize() to Program.Main() | 2026-02-21 |
| BUG-ZOMBIE01 | matrix-monitor.exe respawns killed hotkeys process | Must kill monitor before hotkeys when debugging | 2026-02-21 |
| BUG-COPY01 | Can't copy new binary over locked running exe | Use rename-trick: move old to .old, copy new, delete .old | 2026-02-21 |

---

## Architecture Gotchas

### settings.json Is Sacred

Windows Terminal's `settings.json` is the SINGLE SOURCE OF TRUTH for:
- Profile definitions (names, GUIDs, shader paths, colors, opacity)
- Which shader file each window uses
- Tab colors

**Rules for settings.json**:
1. NEVER use C# model round-trip if you can avoid it (use raw string manipulation)
2. NEVER use PowerShell `ConvertTo-Json` (it mangles casing and types)
3. The ForceShaderReload path-toggle is safe because it only does string.Replace on the raw JSON
4. When you MUST use LoadSettings/SaveSettings, be aware that `TerminalProfile` loses unmodeled properties

### Process Architecture

```
User sees:
  [Matrix-1 window] [Matrix-2 window] [Matrix-3 window] [Matrix-4 window]

Running processes:
  matrix-hotkeys.exe   -- Background, handles 13 global hotkeys + Glitch monitor
  matrix-monitor.exe   -- Watchdog, respawns hotkeys if it crashes
  redpill.exe          -- Control panel TUI (optional, user launches manually)
  wt.exe (x4)          -- Windows Terminal instances showing shader rain

Shared state (disk):
  settings.json        -- WT profiles, shader paths, tab colors
  matrix_state.json    -- Per-shader configs (speed, color, layers)
  identity-registry.json -- Persisted window identity mappings
  Matrix-{1..8}.hlsl   -- Shader source files with #define parameters
```

### Shader Parameter Flow

```
User presses Ctrl+Shift+Down (speed up)
  -> matrix-hotkeys.exe receives WM_HOTKEY
  -> GetFocusedMatrixWindow() identifies which Matrix window
  -> Reads current speed from matrix_state.json
  -> Writes new #define RAIN_SPEED in Matrix-N.hlsl
  -> Saves updated speed to matrix_state.json
  -> ForceShaderReload() toggles paths in settings.json
  -> WT detects settings.json change
  -> WT re-reads Matrix-N.hlsl
  -> GPU compiles and renders new speed
```

### The .hlsl File Format

Each shader file starts with `#define` parameters that control the visual:

```hlsl
// MATRIX SHADER - SLOT 3
#define RAIN_R         0.0
#define RAIN_G         0.6
#define RAIN_B         1.0
#define RAIN_SPEED     0.8
#define RAIN_DENSITY   0.7
#define LAYER_FAR      1
#define LAYER_MID      1
#define LAYER_NEAR     1
```

These are followed by ~400 lines of HLSL shader code including the bit-packed Katakana glyph system.

---

## Window Layout System

### Layout Modes
- **Pillars**: Side-by-side columns, equal width per monitor
- **Quads**: 2x2 grid per monitor
- **Auto**: System chooses based on window count

### Layout Engine Entry Points
- `WindowLayoutEngine.ps1` (PowerShell, legacy)
- `ILayoutService` / `LayoutService` (C#, current)

### Glitch Auto-Repositioning
When overlap > 20% is detected between Matrix windows, the layout engine recalculates and repositions. Has a 5-second cooldown after manual rotation to prevent fighting.

---

## Debug Logging

### Enabling Debug Mode

```bash
# Start hotkeys with debug logging
Start-Process 'C:\Users\ehome\AppData\Local\Programs\MatrixShader\matrix-hotkeys.exe' -ArgumentList '--debug'
```

Or set environment variable `MATRIX_DEBUG=1` before starting.

### Log Location
`C:\Users\ehome\Documents\Matrix\debug.log`

### Log Format
```
[2026-02-21 16:06:49.943] [HOTKEYS] [DEBUG] AdjustSpeed(0.1): focused window = shader=3, profile=Matrix-3
```

### Key Log Messages to Look For
- `Registered X/13 hotkeys` -- Startup confirmation
- `WM_HOTKEY received: id=N` -- Key press detected
- `Dispatching hotkey id=N` -- Handler about to fire
- `Handler completed for id=N` -- Handler finished
- `AdjustSpeed(X): focused window = null` -- User wasn't focused on Matrix window
- `Elimination check: identified=[...]` -- Identity resolution running
- `Position-based elimination: N gaps, M unidentified` -- Fallback identity mode
- `Forced shader reload via path toggle` -- ForceShaderReload succeeded
- `ForceShaderReload: no shader paths found to toggle` -- No .hlsl paths in settings.json

---

## Common Session Workflows

### "Hotkeys stopped working"

1. Check if process is running: `Get-Process -Name 'matrix-hotkeys'`
2. Check if watchdog is respawning old binary: `Get-Process -Name 'matrix-monitor'`
3. Kill BOTH, copy new binary, restart without monitor: see Build Commands above
4. Verify with debug log: look for "Registered 13/13 hotkeys"
5. If hotkeys register but no WM_HOTKEY: check if started with `-WindowStyle Hidden`

### "Shaders went blue/blank"

1. Check settings.json for pixelShaderPath: are paths present or null?
2. If paths are missing: restore from the .matrix-backup file
3. If paths have ".off" suffix: the ForceShaderReload failed mid-toggle, just remove the suffix
4. If paths look correct but rain is blue: the .hlsl file content may be wrong, check #define values

### "Can't identify Matrix window N"

1. Check debug log for "Elimination check" lines
2. Verify how many Matrix windows are actually open vs how many profiles exist
3. Window title changes (from Claude Code agents) break Layer 3 title matching
4. Handle cache (Layer 0) preserves identity after first identification
5. Restarting hotkeys clears the handle cache -- all windows must be re-identified

### "Build succeeded but nothing changed"

You forgot to copy from `publish/` to `AppData\Local\Programs\MatrixShader\`. See MANDATORY Post-Build Step above.

---

## Session History Summary

| Date | Key Work | Critical Discovery |
|------|----------|-------------------|
| 2026-01-11 | Neo vision shader, PRD creation | Code review found atomic write bug |
| 2026-01-17 | Window Layout Engine (1046 lines) | P/Invoke multi-monitor support |
| 2026-01-20 | Window Identity System design | 4-layer hierarchy, agent-proof identification |
| 2026-02-05 | Phase 14 E2E testing, AOT disabled | -WindowStyle Hidden breaks WM_HOTKEY |
| 2026-02-12 | (Fail.txt - trademark research, not project-related) | N/A |
| 2026-02-18 | Phase 15 Analytics Dashboard | Vercel deployment, Redis tracking |
| 2026-02-21 | Color sync, ForceShaderReload fix | null PixelShaderPath nuked all shaders, path-toggle fix |
| 2026-02-22 | Elimination logic fix, position-based matching | profileCount vs maxFromIdentified, position interpolation |

---

## Files Modified Across Sessions (Frequently Changed)

These files are the most commonly edited. When investigating bugs, start here:

- `MatrixShader.Core\Services\TerminalSettingsService.cs` -- ForceShaderReload, LoadSettings, SaveSettings
- `MatrixShader.Core\Services\IdentityService.cs` -- 6-layer identity resolution
- `MatrixShader.Hotkeys\HotkeyActions.cs` -- All 13 hotkey action handlers
- `MatrixShader.Hotkeys\Program.cs` -- Hotkey registration, dispatch loop
- `MatrixShader.Hotkeys\HotkeyWindow.cs` -- WM_HOTKEY message pump
- `MatrixShader.Hotkeys\MatrixWindowMonitor.cs` -- Glitch detection, auto-exit
- `MatrixShader.Core\Models\TerminalProfile.cs` -- WT profile model (MISSING JsonExtensionData!)
- `MatrixShader.Core\Models\MatrixState.cs` -- Application state persistence

---

## User Frustration Points (Context for Tone)

The user has experienced repeated cycles of:
1. Feature works in one session
2. Next session loses context
3. "Fix" breaks something else
4. Emergency restoration of settings.json
5. More debugging, more lost time

Key quotes that reflect expectations:
- "fix one thing, lose context, break 2 more things"
- "whatever WAS the way it was before was working originally"
- "will that work with redpill too or just hotkeys?" (always consider ALL consumers of shared code)
- "the name of the window gets changed by the agent operating inside of it" (title-based ID is useless)

**Rules to prevent frustration**:
1. Read this file FIRST in every session
2. Test BEFORE claiming something works
3. When fixing one thing, verify you haven't broken adjacent features
4. Always rebuild ALL affected components (hotkeys AND redpill if Core changed)
5. Always copy to installed location after build
6. Never use destructive approaches on settings.json
