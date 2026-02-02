---
phase: 13-post-e2e-polish
plan: 04
subsystem: cli
tags: [redpill, tui, hotkeys, self-launch, windows-terminal, ux]

# Dependency graph
requires:
  - phase: 13-01
    provides: WT detection and installation handling
  - phase: 10.5-global-hotkeys
    provides: Hotkey infrastructure and config service
provides:
  - Self-launch logic for Redpill in dedicated WT profile
  - IsRunningInRedpillProfile detection method
  - Clean TUI rendering with line padding
  - Hotkey help screen accessible via [?] key
  - Footer hint for hotkey discoverability
affects: [installer, documentation, user-guide]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Self-launch via Process.Start with wt.exe -p profile
    - WT_PROFILE_ID environment variable detection
    - PadRight for clean TUI rendering

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs
    - MatrixShader/src/MatrixShader.Cli/Redpill/KeyHandler.cs
    - MatrixShader/src/MatrixShader.Cli/Redpill/TuiRenderer.cs

key-decisions:
  - "Self-launch uses WT_PROFILE_ID env var for profile detection"
  - "Fallback to Console.Title check for profile detection"
  - "--no-relaunch flag for developers to skip self-launch"
  - "ClearWidth=80 constant for consistent line padding"
  - "Clear opacity line when transparency toggled off"
  - "'?' key bound to Help action for hotkey help"

patterns-established:
  - "Self-launch pattern: detect profile -> launch new instance -> exit"
  - "TUI line padding pattern: PadRight(ClearWidth) for all variable lines"

# Metrics
duration: 10min
completed: 2026-02-02
---

# Phase 13 Plan 04: Redpill UX Fixes Summary

**Self-launch in dedicated WT window with Redpill shader, clean menu rendering, and discoverable hotkey help via [?] key**

## Performance

- **Duration:** 10 min
- **Started:** 2026-02-02T02:40:02Z
- **Completed:** 2026-02-02T02:50:03Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Running `redpill` now opens a new WT window with the Redpill profile and shader
- Menu content no longer repeats when left open (line padding with ClearWidth)
- Hotkey help discoverable via [?] key and noted in footer
- Added `--no-relaunch` flag for developers

## Task Commits

Each task was committed atomically:

1. **Task 1: Add self-launch to open Redpill in new WT window** - `bbc5c65` (feat)
2. **Task 2: Fix menu content repeat and add hotkey help** - `fd3d7d6` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs` - Added IsRunningInRedpillProfile(), self-launch logic, ShowHotkeyHelp(), Render() line padding
- `MatrixShader/src/MatrixShader.Cli/Redpill/KeyHandler.cs` - Added Help action and '?' key binding
- `MatrixShader/src/MatrixShader.Cli/Redpill/TuiRenderer.cs` - Added ClearWidth constant, hotkey hint in footer

## Decisions Made
- **WT_PROFILE_ID detection:** Windows Terminal sets this env var when running in a named profile, reliable primary detection
- **Console.Title fallback:** Secondary check if env var not available
- **ClearWidth=80:** Standard terminal width, sufficient for most scenarios
- **Opacity line clearing:** When transparency toggled off, write empty padded line to clear residual content

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Redpill UX issues fixed
- Ready for remaining Phase 13 plans (installer theming, etc.)
- Hotkey help comprehensive and discoverable

---
*Phase: 13-post-e2e-polish*
*Completed: 2026-02-02*
