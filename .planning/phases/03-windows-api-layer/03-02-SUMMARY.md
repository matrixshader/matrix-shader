---
phase: 03-windows-api-layer
plan: 02
subsystem: native
tags: [p-invoke, windows-api, dwm, window-enumeration, border-detection]

# Dependency graph
requires:
  - phase: 03-01
    provides: BorderMargins model, DwmGetWindowAttribute P/Invoke
provides:
  - GetAllWindows() method for minimized window enumeration
  - GetVisibleWindowBounds() with DWM API for actual visible bounds
  - GetBorderMargins() for invisible border offset calculation
  - GetMonitors() sorted primary-first then left-to-right
affects: [04-window-identity-service, 05-layout-engine]

# Tech tracking
tech-stack:
  added: []
  patterns: [DWM-first with GetWindowRect fallback, sorted enumeration with re-indexing]

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs

key-decisions:
  - "GetAllWindows includes minimized windows for Matrix window tracking"
  - "GetMonitors sorts primary first, then left-to-right to match PowerShell"
  - "GetVisibleWindowBounds falls back to GetWindowRect when DWM unavailable"

patterns-established:
  - "DWM-first pattern: Try DWM API, fall back to standard Windows API for compatibility"
  - "Sorted enumeration: EnumXxx collects raw data, then sort+re-index for predictable ordering"

# Metrics
duration: 5min
completed: 2026-01-26
---

# Phase 03 Plan 02: Window Enumeration and Border Detection Summary

**Window enumeration helpers with DWM-based border detection for pixel-perfect positioning**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-26T19:30:00Z
- **Completed:** 2026-01-26T19:35:00Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments
- GetAllWindows() enumerates all visible windows including minimized (no IsIconic filter)
- GetVisibleWindowBounds() uses DWM API to get actual visible bounds excluding invisible borders
- GetBorderMargins() calculates invisible border offsets by comparing DWM and standard window rect
- GetMonitors() now sorts primary monitor first, then left-to-right by work area position

## Task Commits

Each task was committed atomically:

1. **Task 1: Add GetAllWindows method** - `ccf404a` (feat)
2. **Task 2: Add GetVisibleWindowBounds and GetBorderMargins** - `e6be392` (feat)
3. **Task 3: Update GetMonitors sorting** - already committed in `61d7f37` (prior session)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs` - Added GetAllWindows, GetVisibleWindowBounds, GetBorderMargins, updated GetMonitors sorting

## Decisions Made
- **GetAllWindows vs GetVisibleWindows:** GetAllWindows deliberately includes minimized windows because Matrix window tracking needs to find windows even when minimized. GetVisibleWindows remains for cases where only non-minimized windows are needed.
- **DWM fallback strategy:** GetVisibleWindowBounds tries DWM first (preferred) but falls back to GetWindowRect for rare DWM-disabled scenarios on Windows 10+.
- **Monitor sorting order:** Matches PowerShell Get-ScreenTopology behavior - primary first ensures predictable default monitor, then left-to-right for logical multi-monitor layout.

## Deviations from Plan

None - plan executed exactly as written.

Note: Task 3 (GetMonitors sorting) was found to be already committed from a previous session (commit 61d7f37). The implementation matched the plan specification exactly.

## Issues Encountered

None - all tasks completed successfully with build verification passing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- WindowsApi now provides complete window enumeration and border detection primitives
- GetAllWindows ready for Identity Service window discovery (Phase 4)
- GetBorderMargins ready for Layout Engine pixel-perfect positioning (Phase 5)
- GetMonitors sorted order ensures predictable multi-monitor calculations

---
*Phase: 03-windows-api-layer*
*Completed: 2026-01-26*
