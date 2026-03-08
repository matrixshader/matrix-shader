---
phase: 02-full-hotkey-system
plan: 02
subsystem: hotkeys
tags: [evdev, notify-send, dbus, opacity, shader-params, python]

# Dependency graph
requires:
  - phase: 01-shader-hot-reload
    provides: "shader_service.py API (read/write/reload/bus_names)"
provides:
  - "13 hotkey action handler functions in hotkey_actions.py"
  - "ACTION_MAP dispatch table for event loop integration"
  - "Toast notification helper with dunst stack tag"
  - "Opacity control ported from bash to Python"
  - "Layout cycle state persistence"
  - "Shader slot rotation (swap left/right)"
affects: [02-full-hotkey-system, 06-layout-engine]

# Tech tracking
tech-stack:
  added: []
  patterns: ["all-slots broadcast for global hotkeys", "opacity via config file regex not shader defines", "atomic write for state.json", "dunst stack tag for toast replacement"]

key-files:
  created: [linux/hotkey_actions.py, linux/tests/test_hotkey_actions.py]
  modified: []

key-decisions:
  - "Opacity ported from matrix-opacity.sh to Python — eliminates subprocess overhead, enables direct D-Bus reload"
  - "Shared _toggle_layer() helper for all 3 layer toggles — DRY, consistent toast messages"
  - "Shared _rotate_shaders() helper for swap left/right — read-all-then-write-all avoids data loss during rotation"
  - "CycleLayout writes state.json only — actual positioning deferred to Phase 6 per user decision"

patterns-established:
  - "All-slots broadcast: every shader action iterates get_ghostty_bus_names() and applies to all slots"
  - "Toast fire-and-forget: show_toast() via subprocess.Popen, silently handles missing notify-send"
  - "Opacity path: regex replace in config files + D-Bus reload (separate from shader #define path)"

requirements-completed: [HKEY-02, HKEY-03, HKEY-04, HKEY-05, HKEY-06]

# Metrics
duration: 8min
completed: 2026-03-08
---

# Phase 2 Plan 02: Hotkey Actions Summary

**13 action handlers with ACTION_MAP dispatch, toast notifications via notify-send, opacity ported from bash to Python, all broadcasting to all active Matrix windows**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-08T17:14:51Z
- **Completed:** 2026-03-08T17:23:34Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments
- All 13 hotkey action functions implemented and tested (48 tests)
- Opacity control fully ported from matrix-opacity.sh to Python with config file modification + D-Bus reload
- ACTION_MAP dispatch table ready for matrix-keys.py event loop integration (Plan 03)
- Toast notifications with dunst stack tag for rapid-keypress replacement

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Failing tests for all 13 actions** - `d83dc9b` (test)
2. **Task 1 (GREEN): Implement hotkey_actions.py** - `e2ecff9` (feat)

_TDD task: RED wrote 48 failing tests, GREEN implemented all 13 handlers to pass._

## Files Created/Modified
- `linux/hotkey_actions.py` - All 13 action handlers, toast helper, ACTION_MAP dispatch table (406 lines)
- `linux/tests/test_hotkey_actions.py` - 48 unit tests across 9 test classes (731 lines)

## Decisions Made
- Opacity ported from bash (matrix-opacity.sh) to Python: eliminates subprocess overhead, enables direct D-Bus reload integration
- Shared helper functions (_toggle_layer, _rotate_shaders) reduce duplication across similar actions
- CycleLayout writes to state.json only per user decision -- actual window repositioning deferred to Phase 6
- Shader rotation reads all contents first then writes all -- prevents data loss during swap

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- ACTION_MAP is ready for import by matrix-keys.py refactor (Plan 03)
- All 13 actions handle empty slot mappings gracefully (no errors when no windows are running)
- Opacity actions correctly modify both /tmp/ghostty-matrix-*.conf AND ~/.config/ghostty/config
- Full test suite (125 tests) remains green

## Self-Check: PASSED

- linux/hotkey_actions.py: FOUND
- linux/tests/test_hotkey_actions.py: FOUND
- 02-02-SUMMARY.md: FOUND
- Commit d83dc9b (RED): FOUND
- Commit e2ecff9 (GREEN): FOUND

---
*Phase: 02-full-hotkey-system*
*Completed: 2026-03-08*
