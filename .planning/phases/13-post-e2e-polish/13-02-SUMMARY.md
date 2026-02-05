---
phase: 13-post-e2e-polish
plan: 02
subsystem: layout
tags: [windows-api, layout-engine, pillars, minimized-windows]

# Dependency graph
requires:
  - phase: 12-e2e-gap-closure
    provides: LayoutService with WM_DISPLAYCHANGE handling
provides:
  - Fixed Pillars layout always single-row columns
  - Minimized window skip in layout operations
affects: [layout, window-management, user-experience]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Gap reduction before row addition in Pillars"
    - "Respect user window state (minimized stays minimized)"

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs

key-decisions:
  - "MinWindowWidth reduced to 200 for narrow pillars"
  - "Pillars never adds rows - gaps reduced instead"
  - "Minimized windows skipped with continue, not restored"

patterns-established:
  - "Layout modes preserve user intent (minimized state)"
  - "Gap adjustment before layout reconfiguration"

# Metrics
duration: 8min
completed: 2026-02-02
---

# Phase 13 Plan 02: Layout Bug Fixes Summary

**Pillars layout fixed to always display side-by-side columns, minimized windows now stay minimized during layout operations**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-02T02:24:42Z
- **Completed:** 2026-02-02T02:32:10Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Fixed BUG-LAYOUT03: 4 pillars now correctly display as 4 side-by-side columns
- Fixed BUG-LAYOUT04: Minimized windows stay minimized during layout application
- Reduced MinWindowWidth from 475 to 200 for narrow pillar support
- Changed gap reduction strategy: reduce gaps before adding rows (rows never added in Pillars)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix Pillars layout to always use single row** - `6533f91` (fix)
2. **Task 2: Skip minimized windows in layout application** - `e1d21db` (fix)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs` - Fixed CalculatePillarsLayout and ApplyLayoutInternal

## Decisions Made
- **MinWindowWidth = 200:** Lowered from 475 to allow narrow pillar columns for 4+ windows
- **Gap reduction first:** When windows would be too narrow, reduce gaps by 5px increments before resorting to zero gaps
- **Never add rows in Pillars:** Pillars mode is strictly single-row; multi-row layouts belong in Quads mode
- **Skip vs restore:** Minimized windows are skipped (continue) rather than restored (SW_RESTORE) to respect user intent

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both tasks completed successfully on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Layout service bug fixes complete
- Ready for remaining Phase 13 bug fixes (transparency, profile, MatrixLite)
- No blockers or concerns

---
*Phase: 13-post-e2e-polish*
*Completed: 2026-02-02*
