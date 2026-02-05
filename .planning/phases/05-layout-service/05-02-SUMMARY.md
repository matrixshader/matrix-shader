---
phase: 05-layout-service
plan: 02
subsystem: windows-api
tags: [dwm, window-positioning, p-invoke, border-compensation]

# Dependency graph
requires:
  - phase: 03-windows-api-layer
    provides: PositionWindowExact and IsHandleValid methods
provides:
  - Border-compensated window positioning via PositionWindowExact
  - Robust handle validation before positioning
  - Minimized window restore with 100ms delay
affects: [06-tui-controls, 07-hotkey-service]

# Tech tracking
tech-stack:
  added: []
  patterns: [DWM border compensation for visible bounds]

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs

key-decisions:
  - "Use PositionWindowExact over PositionWindow for pixel-perfect visible positioning"
  - "IsHandleValid combines IsWindow AND IsWindowVisible for robust validation"

patterns-established:
  - "Border compensation: Always use PositionWindowExact when target rect is desired visible bounds"

# Metrics
duration: 6min
completed: 2026-01-27
---

# Phase 5 Plan 2: Apply Border-Compensated Positioning Summary

**ApplyLayout now uses PositionWindowExact for pixel-perfect visible window positioning with DWM border compensation**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-27T17:55:50Z
- **Completed:** 2026-01-27T18:33:52Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- ApplyLayout now uses PositionWindowExact for pixel-perfect visible positioning
- Handle validation upgraded from simple null check to IsHandleValid (IsWindow AND IsWindowVisible)
- Minimized window restore logic preserved with 100ms animation delay

## Task Commits

Tasks were committed as part of a combined commit:

1. **Task 1: Update ApplyLayout to use PositionWindowExact** - `a68923a`
2. **Task 2: Add IsHandleValid check optimization** - `a68923a`

_Note: Both tasks completed in single commit due to related changes_

## Files Created/Modified

- `MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs` - ApplyLayout now uses PositionWindowExact and IsHandleValid

## Decisions Made

- **PositionWindowExact over PositionWindow:** Target rects from CalculateLayout are desired visible bounds, so border compensation is required for accurate positioning
- **IsHandleValid for validation:** Combines IsWindow AND IsWindowVisible per Phase 4 decision, more robust than simple nint.Zero check

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing interface implementations**

- **Found during:** Task 1 (Build verification)
- **Issue:** ILayoutService had 3 methods (CycleMode overload, AdjustGap, UpdateConfig) not implemented in LayoutService
- **Fix:** Added implementations for all 3 methods
- **Files modified:** MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs
- **Verification:** Build succeeded
- **Committed in:** a68923a

---

**Total deviations:** 1 auto-fixed (blocking)
**Impact on plan:** Interface implementation was necessary for build. No scope creep - these were pre-existing interface members.

## Issues Encountered

None - plan executed as specified with one blocking issue auto-fixed.

## Next Phase Readiness

- LayoutService fully implements ILayoutService interface
- Border-compensated positioning ready for TUI integration in Phase 6
- Gap calculations will be visually accurate (no invisible border offset)

---
*Phase: 05-layout-service*
*Completed: 2026-01-27*
