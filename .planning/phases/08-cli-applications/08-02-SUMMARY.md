---
phase: 08-cli-applications
plan: 02
subsystem: cli
tags: [cli, bluepill, session-restore, wt-launch, typewriter]
dependency-graph:
  requires: [08-01]
  provides: [bluepill-session-restore, window-launch-via-wt]
  affects: [08-03]
tech-stack:
  added: []
  patterns: [session-restore-pattern, poll-based-window-detection]
key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs
    - MatrixShader/src/MatrixShader.Cli/Bluepill/MatrixShader.Cli.Bluepill.csproj
decisions:
  - id: "08-02-D1"
    choice: "Use nint instead of IntPtr for window handles"
    rationale: "Consistent with Core library pattern, nint is native integer type"
  - id: "08-02-D2"
    choice: "RegisterWindowHandle signature matches interface (nint, string, int)"
    rationale: "Plan code had incorrect signature - corrected to match IIdentityService"
  - id: "08-02-D3"
    choice: "MatrixState.Layout property (not LayoutConfig)"
    rationale: "Model uses Layout property name for LayoutConfig, corrected from plan"
  - id: "08-02-D4"
    choice: "ShaderService.CreateShader requires ShaderConfig parameter"
    rationale: "Interface requires config - corrected from plan's single-parameter call"
metrics:
  duration: 5 min
  completed: 2026-01-29
---

# Phase 08 Plan 02: Bluepill Session Restore Summary

Bluepill CLI with full session restore: detects open windows, launches missing via wt.exe, positions with LayoutService, typewriter "There is no spoon..." effect.

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-29
- **Completed:** 2026-01-29
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Complete rewrite of bluepill Program.cs (377 lines, well above 200 min)
- SessionRestorer class with full session restore matching bluepill.ps1
- Window launch via wt.exe with poll-based detection (100ms intervals, 5s timeout)
- Removed Spectre.Console dependency (per CONTEXT.md - no third-party TUI)

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite Bluepill Program.cs with session restore** - `d37b269` (feat)
2. **Task 2: Update Bluepill csproj to remove Spectre.Console** - `be442aa` (chore)

## Files Created/Modified

- `MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs` - Complete rewrite with SessionRestorer class
- `MatrixShader/src/MatrixShader.Cli/Bluepill/MatrixShader.Cli.Bluepill.csproj` - Removed Spectre.Console, Logging.Console

## What Was Built

### Program.cs (377 lines)
Complete bluepill CLI with session restore:
- **Main()**: Parses args, initializes CLI bootstrap, runs session restore, typewriter effect
- **ShowHelp()**: Matrix-themed help message with all options
- **ShowMorpheusIntro()**: Easter egg philosophical typewriter sequence
- **ConfigureServices()**: DI setup for all Core services
- **RestoreResult record**: Success/failure with windows launched/already open counts

### SessionRestorer Class
Session restore matching PowerShell bluepill.ps1:
- **RestoreSessionAsync()**: Main restore orchestration
  - Loads saved state via IConfigService.LoadState()
  - Detects already-open windows via IIdentityService.FindMatrixWindows()
  - Launches missing windows via wt.exe -p "Matrix-N"
  - Positions windows via ILayoutService.CalculateLayout/ApplyLayout
  - Saves registry on completion
- **GetActiveSlots()**: Returns slots where shader files exist
- **GetExistingWindowHandles()**: Captures handles before launch for diff
- **WaitForNewWindowAsync()**: 100ms polling, 50 attempts (5s timeout)
- **TryRestoreSavedPositions()**: Uses LoadWindowSlots for saved layouts

### Key Links

```
Program.Main()
    |-- CliBootstrap.ParseArgs() [--help, --debug, --morpheus]
    |-- CliBootstrap.InitializeAsync() [ANSI, logging, directories]
    |-- SessionRestorer.RestoreSessionAsync()
    |       |-- IConfigService.LoadState()
    |       |-- IShaderService.ShaderExists() / CreateShader()
    |       |-- IIdentityService.CleanStaleEntries() / LoadRegistry()
    |       |-- IIdentityService.FindMatrixWindows()
    |       |-- Process.Start("wt.exe", "-p Matrix-N")
    |       |-- WaitForNewWindowAsync() [100ms poll, 5s timeout]
    |       |-- IIdentityService.RegisterWindowHandle()
    |       |-- ILayoutService.CalculateLayout() / ApplyLayout()
    |       |-- IIdentityService.SaveRegistry()
    |-- CliBootstrap.TypewriterAsync("There is no spoon...")
    |-- Console.ReadKey()
```

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| 08-02-D1 | Use nint instead of IntPtr | Consistent with Core library pattern |
| 08-02-D2 | RegisterWindowHandle(nint, string, int) | Match actual IIdentityService interface |
| 08-02-D3 | MatrixState.Layout property | Model uses Layout, not LayoutConfig |
| 08-02-D4 | CreateShader(int, ShaderConfig) | Interface requires config parameter |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RegisterWindowHandle signature mismatch**
- **Found during:** Task 1
- **Issue:** Plan specified `RegisterWindowHandle(IntPtr, int)` but interface is `(nint, string, int)`
- **Fix:** Corrected call to include profileName parameter
- **Files modified:** Program.cs
- **Commit:** d37b269

**2. [Rule 1 - Bug] MatrixState.LayoutConfig property does not exist**
- **Found during:** Task 1
- **Issue:** Plan used `state.LayoutConfig` but model has `state.Layout`
- **Fix:** Changed to `state.Layout`
- **Files modified:** Program.cs
- **Commit:** d37b269

**3. [Rule 1 - Bug] ShaderService.CreateShader(int) overload does not exist**
- **Found during:** Task 1
- **Issue:** Plan called `CreateShader(1)` but interface requires `CreateShader(int, ShaderConfig)`
- **Fix:** Changed to `CreateShader(1, new ShaderConfig())`
- **Files modified:** Program.cs
- **Commit:** d37b269

---

**Total deviations:** 3 auto-fixed (3 bugs from plan code)
**Impact on plan:** All fixes necessary to match actual interface signatures. No scope creep.

## Verification Results

- [x] Build succeeds with no warnings
- [x] Program.cs has CliBootstrap.InitializeAsync() call (line 29)
- [x] SessionRestorer loads state via IConfigService.LoadState() (line 173)
- [x] SessionRestorer detects open windows via IIdentityService.FindMatrixWindows() (lines 201, 277, 328, 346)
- [x] SessionRestorer launches missing windows via wt.exe (lines 233-239)
- [x] Program displays typewriter "There is no spoon..." (line 69)
- [x] Program waits for key press before exit (line 74)
- [x] Spectre.Console removed from csproj
- [x] Program.cs has 377 lines (above 200 minimum)

## Issues Encountered

None - followed plan as specified after correcting interface mismatches.

## Next Phase Readiness

- [x] Bluepill CLI complete with session restore
- [x] Ready for 08-03 (wakeupneo and redpill CLIs)
- [x] SessionRestorer pattern can be referenced for similar CLI implementations
- [x] No blockers

---
*Plan 08-02 executed: 2026-01-29*
*Duration: 5 minutes*
