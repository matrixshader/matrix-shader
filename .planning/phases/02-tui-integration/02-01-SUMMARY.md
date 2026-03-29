---
phase: 02-tui-integration
plan: 01
subsystem: ui
tags: [tui, ansi, preset, curses-free, raw-terminal]

# Dependency graph
requires:
  - phase: 01-preset-service
    provides: "save_preset, load_preset, list_presets, delete_preset CRUD functions"
provides:
  - "PresetMenuScreen class with interactive save/load/delete/list UI"
  - "Raw ANSI rendered preset list with color swatches and dates"
  - "Char-by-char name input with backspace, ESC cancel"
  - "Duplicate name overwrite confirmation (Y/N)"
affects: [02-tui-integration, 03-cli-tools]

# Tech tracking
tech-stack:
  added: []
  patterns: [module-level mock injection for sub-screen testing, raw char input loop with backspace]

key-files:
  created: [linux/preset_menu_screen.py, linux/tests/test_preset_menu_screen.py]
  modified: []

key-decisions:
  - "Followed _show_help screen lifecycle pattern: clear on entry, cursor home render loop, clear on exit"
  - "Key dispatch returns bool (False=exit) rather than using exceptions or sentinels"
  - "Load writes params even when no Ghostty bus name found (window may have closed between list and load)"

patterns-established:
  - "Sub-screen pattern: class with run() method, _render()/_draw()/_handle_key() internal structure"
  - "Module-level mock injection for testing interactive screens (same as test_redpill_tui.py)"

requirements-completed: [SAVE-01, SAVE-02, SAVE-03, SAVE-04, LOAD-01, LOAD-02, LOAD-03, LIST-01, LIST-02, DEL-01, DEL-02]

# Metrics
duration: 4min
completed: 2026-03-29
---

# Phase 2 Plan 1: Preset Menu Screen Summary

**Interactive ANSI preset menu with save (char input + overwrite confirm), load (params + D-Bus reload), delete (Y/N), and scrollable list with color swatches**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-29T02:51:20Z
- **Completed:** 2026-03-29T02:55:46Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files created:** 2

## Accomplishments
- PresetMenuScreen renders scrollable preset list with name, RGB color swatch, and formatted save date
- Save flow reads name char-by-char in raw mode (backspace, ESC cancel, Enter confirm), checks duplicates with Y/N overwrite
- Load flow applies all 11 shader params to active slot and triggers D-Bus reload
- Delete flow prompts Y/N, adjusts selection index after removal
- Empty list shows helpful "No presets saved yet. Press [S]" message
- 32 tests covering all flows and edge cases

## Task Commits

Each task was committed atomically (TDD):

1. **Task 1 RED: Failing tests** - `bb83aac` (test)
2. **Task 1 GREEN: PresetMenuScreen implementation** - `2f6a3bf` (feat)

## Files Created/Modified
- `linux/preset_menu_screen.py` - Interactive preset management screen (328 lines)
- `linux/tests/test_preset_menu_screen.py` - Tests for all preset menu flows (443 lines)

## Decisions Made
- Followed _show_help screen lifecycle pattern from redpill_tui.py: clear on entry, cursor-home render loop, clear on exit
- Key dispatch uses bool return (False=exit) for clean loop integration
- Load writes shader params even when no Ghostty bus name found -- graceful degradation if window closed between list and load
- Mock side_effect must be explicitly cleared in _reset_mocks to prevent test pollution across test classes

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed mock side_effect leaking between tests**
- **Found during:** Task 1 GREEN (running tests)
- **Issue:** _load_preset.side_effect set to FileNotFoundError in one test persisted to the next test, causing false failure
- **Fix:** Added explicit `side_effect = None` reset for all mocks in _reset_mocks()
- **Files modified:** linux/tests/test_preset_menu_screen.py
- **Verification:** All 32 tests pass in sequence
- **Committed in:** 2f6a3bf (part of GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Test infrastructure fix, no scope creep.

## Issues Encountered
None beyond the mock side_effect leak (documented above).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PresetMenuScreen ready for integration into RedpillTUI main menu (Plan 02-02)
- All preset_service functions exercised through the UI layer
- Pattern established for future sub-screens (e.g., preset import/export)

---
*Phase: 02-tui-integration*
*Completed: 2026-03-29*
