---
phase: 09-native-aot-polish
plan: 03
subsystem: cli
tags: [integration, startup, error-handling, bluepill, redpill, wakeupneo]

# Dependency graph
requires:
  - phase: 09-native-aot-polish
    plan: 02
    provides: MatrixSplash and MatrixErrorHandler components
  - phase: 08-cli-applications
    provides: CLI entry points (Bluepill, Redpill, WakeupNeo)
provides:
  - Matrix splash on all CLI startup
  - Themed error handling on all CLI exceptions
affects: [user-experience, first-run, error-recovery]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Entry-level MatrixSplash.ShowAsync before DI setup
    - Top-level try-catch with MatrixErrorHandler.ShowError
    - --help flag skips splash animation

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs
    - MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs
    - MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs

key-decisions:
  - "Splash appears before ParseArgs and all DI setup"
  - "Skip splash if --help is in args (immediate help display)"
  - "MatrixErrorHandler supplements (not replaces) existing error logging"

patterns-established:
  - "Consistent CLI entry pattern: splash → parse → bootstrap → try/catch with themed errors"
  - "Redpill keeps logger.LogError alongside MatrixErrorHandler for diagnostics"

# Metrics
duration: 7min
completed: 2026-01-30
---

# Phase 9 Plan 3: CLI Integration Summary

**Matrix splash and error handler integrated into all three CLI entry points (Bluepill, Redpill, WakeupNeo)**

## Performance

- **Duration:** 7 min
- **Started:** 2026-01-30T04:39:52Z
- **Completed:** 2026-01-30T04:46:28Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- All three CLI executables now show Matrix cascading animation on startup
- --help flag bypasses splash for immediate help display
- Themed "SYSTEM FAILURE" error display on unhandled exceptions
- Consistent branded experience across Bluepill, Redpill, and WakeupNeo

## Task Commits

Each task was committed atomically:

1. **Task 1: Add splash to Bluepill entry point** - `d6d4ae7` (feat)
2. **Task 2: Add splash to Redpill entry point** - `571202c` (feat)
3. **Task 3: Add splash to WakeupNeo entry point** - `5ff5cc2` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs` - Splash at entry, themed error handler
- `MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs` - Splash at entry, themed error handler
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` - Splash at entry, themed error handler

## Integration Pattern

All three CLIs follow this structure:
1. Check `--help` flag before splash (skip animation for immediate help)
2. Show `MatrixSplash.ShowAsync()` before any other initialization
3. Wrap entire Main body in try-catch
4. On exception: log diagnostics, call `MatrixErrorHandler.ShowError(ex.Message)`, return 1

## Decisions Made
- Splash precedes ParseArgs for branded startup experience
- --help check happens before splash (users want immediate help, not animation)
- Redpill maintains logger.LogError for diagnostic logging alongside user-facing error display
- WakeupNeo splash precedes wizard's "Wake up, Neo..." intro (brand first, then drama)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - integration was straightforward. Build succeeded on first attempt.

## User Setup Required
None - changes are internal to CLI startup flow.

## Next Phase Readiness
- All CLI entry points have consistent branded startup experience
- Ready for Phase 9 Plan 4 (final phase plan - likely packaging/AOT compilation)
- No blockers

## Verification

All verification criteria met:
- ✅ Bluepill: MatrixSplash.ShowAsync called before ParseArgs
- ✅ Bluepill: MatrixErrorHandler.ShowError in catch block
- ✅ Redpill: MatrixSplash.ShowAsync called before ParseArgs
- ✅ Redpill: MatrixErrorHandler.ShowError in catch block
- ✅ WakeupNeo: MatrixSplash.ShowAsync called before ParseArgs
- ✅ WakeupNeo: MatrixErrorHandler.ShowError in catch block
- ✅ All three skip splash when --help is passed
- ✅ `dotnet build` succeeds for all CLI projects

---
*Phase: 09-native-aot-polish*
*Completed: 2026-01-30*
