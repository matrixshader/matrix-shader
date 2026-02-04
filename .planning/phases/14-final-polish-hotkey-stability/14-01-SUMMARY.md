---
phase: 14-final-polish-hotkey-stability
plan: 01
subsystem: hotkeys
tags: [c#, process-supervision, exception-handling, background-service]

# Dependency graph
requires:
  - phase: 10.5-global-hotkeys
    provides: matrix-hotkeys.exe hotkey service
provides:
  - Top-level exception handling for crash logging
  - 30-second stay-alive timer for service persistence
  - HotkeyWatchdog for automatic process restart on crash
affects: [14-02, installer, one-liner]

# Tech tracking
tech-stack:
  added: []
  patterns: [process-supervision-watchdog, stay-alive-timer]

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Hotkeys/Program.cs
    - MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs
    - MatrixShader/src/MatrixShader.Monitor/Program.cs

key-decisions:
  - "30-second stay-alive to allow window reopening without service restart"
  - "5-second health check interval for watchdog balance"
  - "HotkeyWatchdog lives in Monitor service for unified supervision"

patterns-established:
  - "AppDomain.UnhandledException for crash logging"
  - "Stay-alive timer pattern for background services"
  - "Process supervision via watchdog with health check timer"

# Metrics
duration: 8min
completed: 2026-02-03
---

# Phase 14 Plan 01: Hotkey Service Stability Summary

**Exception handling and 30-second stay-alive in matrix-hotkeys.exe, plus HotkeyWatchdog in matrix-monitor for auto-restart on crash**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-03T~15:00:00Z
- **Completed:** 2026-02-03T~15:08:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- matrix-hotkeys.exe now logs crashes via AppDomain.UnhandledException handler
- Stay-alive timer keeps hotkey service running 30 seconds after last Matrix window closes
- HotkeyWatchdog in matrix-monitor auto-restarts matrix-hotkeys.exe on crash (5-second health checks)
- Path resolution for hotkey executable supports dev, Program Files, and LocalAppData locations

## Task Commits

Each task was committed atomically:

1. **Task 1: Add exception handling and stay-alive timer** - `b105722` (feat)
2. **Task 2: Add hotkey process watchdog** - `27520e5` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Hotkeys/Program.cs` - Added AppDomain.UnhandledException handler and try-catch around Run()
- `MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs` - Added _lastWindowSeen field, StayAliveSeconds constant, updated CheckWindows for 30s stay-alive
- `MatrixShader/src/MatrixShader.Monitor/Program.cs` - Added HotkeyWatchdog class with 5-second health check, integrated into MonitorService lifecycle

## Decisions Made
- **30-second stay-alive:** Gives users time to reopen Matrix windows without losing hotkey functionality
- **5-second watchdog interval:** Balances responsiveness with CPU overhead
- **Watchdog in Monitor service:** Centralized supervision rather than self-healing hotkey process
- **NoWindowThreshold = 15:** At 2-second intervals, this equals 30 seconds for stay-alive

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - builds passed on first attempt for both tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Hotkey service stability foundation complete
- matrix-hotkeys.exe now resilient to crashes with auto-restart
- Ready for 14-02 (transparency persistence), 14-03 (shader cycling), etc.
- Full solution builds successfully

---
*Phase: 14-final-polish-hotkey-stability*
*Completed: 2026-02-03*
