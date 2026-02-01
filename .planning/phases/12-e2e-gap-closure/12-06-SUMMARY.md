---
phase: 12-e2e-gap-closure
plan: 06
subsystem: cli
tags: [first-run-detection, session-restore, configservice, wakeupneo, bluepill]

# Dependency graph
requires:
  - phase: 11-installer-e2e-validation
    provides: Installer bundles shaders in Program Files
provides:
  - IsFirstRun property on IConfigService interface
  - Correct first-run detection based on state file existence
  - Fix for BUG-FRX01 false "Previous sessions found" message
affects: [future CLI tools, session management]

# Tech tracking
tech-stack:
  added: []
  patterns: ["State file existence as source of truth for first-run"]

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/IConfigService.cs
    - MatrixShader/src/MatrixShader.Core/Services/ConfigService.cs
    - MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs
    - MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs

key-decisions:
  - "IsFirstRun checks state file existence, not ShaderConfigs.Count"
  - "Bundled shaders in Program Files should not trigger false session detection"
  - "Applied fix to both WakeupNeo and Bluepill for consistency"

patterns-established:
  - "First-run detection: Always use IsFirstRun before GetActiveSlots()"

# Metrics
duration: 13min
completed: 2026-02-01
---

# Phase 12 Plan 06: Fix False Session Detection Summary

**IsFirstRun property added to ConfigService to fix false "Previous sessions found 8 window slots" on fresh install**

## Performance

- **Duration:** 13 min
- **Started:** 2026-02-01T05:59:52Z
- **Completed:** 2026-02-01T06:13:13Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Fixed BUG-FRX01: Fresh install no longer shows "Previous sessions found 8 window slots"
- Added `IsFirstRun` property to `IConfigService` interface and `ConfigService` implementation
- Applied fix to both WakeupNeo and Bluepill CLI tools for consistency
- Added diagnostic logging for first-run detection debugging

## Task Commits

Each task was committed atomically:

1. **Task 1: Add IsFirstRun check to prevent false session detection** - `62ce59e` (fix)
2. **Task 2: Apply IsFirstRun check to Bluepill session restore** - `c2cfc16` (fix)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/IConfigService.cs` - Added IsFirstRun property to interface
- `MatrixShader/src/MatrixShader.Core/Services/ConfigService.cs` - Implemented IsFirstRun property
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` - Use IsFirstRun before GetActiveSlots()
- `MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs` - Use IsFirstRun before GetActiveSlots()

## Root Cause Analysis

**The Bug:** Fresh install showed "Previous sessions found 8 window slots" when no previous session existed.

**Root Cause:** Three factors combined:
1. `MatrixState` default constructor creates 8 `ShaderConfigs` entries (slots 1-8)
2. `LoadState()` returns `new MatrixState()` when no state file exists
3. `GetActiveSlots()` iterates through all 8 slots and checks `ShaderExists()` which finds bundled shaders in Program Files from the installer

**The Fix:** Added `IsFirstRun` property that checks if the state file exists. If no state file exists, we treat it as first run regardless of what shaders exist in Program Files.

## Decisions Made
- **IsFirstRun checks state file existence:** The state file (`matrix_state.json`) is the source of truth for whether the user has previously run the wizard, not the existence of shader files
- **Bundled shaders are not "previous sessions":** Shaders in Program Files are installed by the installer, not created by user running the wizard
- **Fix applied to both entry points:** Both WakeupNeo (setup wizard) and Bluepill (quick session restore) need the same fix for consistency

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Extended fix to Bluepill**
- **Found during:** Task 2 (verification)
- **Issue:** Bluepill has identical bug - would launch 8 windows on fresh install instead of 1
- **Fix:** Applied same IsFirstRun check to SessionRestorer.RestoreSessionAsync()
- **Files modified:** MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs
- **Verification:** Build succeeds, both entry points now check IsFirstRun
- **Committed in:** c2cfc16 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (missing critical)
**Impact on plan:** Essential fix for correct behavior across all CLI entry points. No scope creep.

## Issues Encountered
None - plan executed as written with logical extension to Bluepill.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- BUG-FRX01 fully resolved
- First-run detection now reliable across all CLI tools
- Ready for remaining Phase 12 plans (WT installation flow, uninstaller fixes, final verification)

---
*Phase: 12-e2e-gap-closure*
*Completed: 2026-02-01*
