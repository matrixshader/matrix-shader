---
phase: 13-post-e2e-polish
plan: 01
subsystem: cli
tags: [windows-terminal, installation, ux, restart-detection]

# Dependency graph
requires:
  - phase: 12-e2e-gap-closure
    provides: WT installation fallback chain (winget/Store/GitHub)
provides:
  - Post-install WT detection with restart instructions
  - Clear user guidance instead of silent Lite fallback
affects: [installer, wakeupneo, first-run-experience]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Check EnvironmentService.IsWindowsTerminal() after install"
    - "Return false with restart message to prevent Lite fallback"

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs

key-decisions:
  - "Show restart instructions when WT installed but not inside WT"
  - "Return false from TryInstallWindowsTerminalAsync to signal restart needed"
  - "BootstrapResult distinguishes 'restart required' from 'not installed'"

patterns-established:
  - "Post-install environment check: verify both installation AND runtime context"

# Metrics
duration: 7min
completed: 2026-02-02
---

# Phase 13 Plan 01: WT Post-Install Restart Instructions Summary

**Post-install WT detection with ShowRestartInstructions() method - users see clear 3-step guidance instead of silent Lite fallback**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-02T02:23:59Z
- **Completed:** 2026-02-02T02:31:19Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added ShowRestartInstructions() method with clear 3-step user guidance
- Post-install check verifies WT installed AND running inside WT
- BootstrapResult now returns "Restart in Windows Terminal required" message
- All three install paths (winget, Store, GitHub) trigger restart check

## Task Commits

Each task was committed atomically:

1. **Task 1: Add post-install WT detection with restart instruction** - `6ca87e8` (fix)

## Files Created/Modified

- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` - Added ShowRestartInstructions() method and post-install WT/environment checks

## Decisions Made

- **Show explicit instructions instead of proceeding to Lite:** After WT installs, user needs to restart in WT for shader support. Silent Lite fallback was confusing.
- **Return false to signal restart needed:** This prevents automatic Lite mode fallback. BootstrapResult message clarifies the situation.
- **Check EnvironmentService.IsWindowsTerminal() after install:** Detects if running inside WT vs cmd/PowerShell based on WT_SESSION environment variable.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BUG-WT06 fix complete
- Ready for remaining Phase 13 bug fixes
- Users will now get actionable guidance after installing WT from any source

---
*Phase: 13-post-e2e-polish*
*Completed: 2026-02-02*
