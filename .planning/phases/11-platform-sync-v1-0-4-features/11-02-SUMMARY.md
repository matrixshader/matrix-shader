---
phase: 11-platform-sync-v1-0-4-features
plan: 02
subsystem: hotkeys, cli, tui
tags: [opacity, overflow-counters, command-banner, window-filtering, ansi]

# Dependency graph
requires:
  - phase: 02-full-hotkey-system
    provides: hotkey_actions.py opacity action handlers
  - phase: 03-redpill-tui
    provides: redpill_tui.py with tab discovery
provides:
  - Opacity overflow/underflow counters in hotkey_actions.py (matching Windows v1.0.4)
  - Command reference banner (command_banner.py) shown on CLI exit
  - Non-shader window filtering regression tests for redpill TUI
affects: [mac-port, construct-cli]

# Tech tracking
tech-stack:
  added: []
  patterns: [overflow-counter-state, atomic-config-write, ansi-banner]

key-files:
  created:
    - linux/command_banner.py
    - linux/tests/test_command_banner.py
  modified:
    - linux/hotkey_actions.py
    - linux/redpill_tui.py
    - linux/wakeupneo.sh
    - linux/bluepill.sh
    - linux/redpill.sh
    - linux/build-release.sh
    - linux/tests/test_hotkey_actions.py
    - linux/tests/test_redpill_tui.py

key-decisions:
  - "Opacity overflow/underflow uses module-level dicts keyed by config path -- matches Windows per-window state"
  - "Removed _run_opacity() shell delegation entirely -- inline Python is faster and supports counters"
  - "action_toggle_transparency resets overflow/underflow counters on toggle -- matches Windows behavior"
  - "Command banner uses 24-bit ANSI color #35B381 for command names -- exact Windows match"
  - "Non-shader window filtering already works via get_ghostty_bus_names() config pattern -- added regression tests"

patterns-established:
  - "Overflow counter pattern: _overflow_counters dict + _base_opacity for external change detection"
  - "Command banner as shared Python module callable from shell scripts via python3 -B"

requirements-completed: [SYNC-03, SYNC-04, SYNC-05, SYNC-07]

# Metrics
duration: 6min
completed: 2026-03-14
---

# Phase 11 Plan 02: v1.0.4 Small Features Summary

**Opacity overflow/underflow counters, command reference banner on CLI exit, and non-shader window filtering regression guards**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-14T01:27:18Z
- **Completed:** 2026-03-14T01:33:46Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- Opacity overflow/underflow counters match Windows C# AdjustOpacity exactly -- pressing up at 100% accumulates counter that must drain before visual change
- Command reference banner shows 5 commands in Matrix green with dim descriptions on exit of wakeupneo, bluepill, redpill
- Redpill TUI tab list verified to only show Matrix shader windows -- 6 regression tests lock the filtering behavior
- Shell delegation to matrix-opacity.sh completely removed from hotkey actions -- all opacity logic is now inline Python

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace opacity shell delegation with overflow/underflow counters** - `178574e` (feat)
2. **Task 2: Add command reference banner to CLI exit points** - `04fe5ef` (feat)
3. **Task 3: Filter non-shader windows in redpill TUI tab list** - `f4759ef` (feat)

**Plan metadata:** [pending] (docs: complete plan)

## Files Created/Modified
- `linux/hotkey_actions.py` - Added _overflow_counters, _underflow_counters, _base_opacity state; _adjust_opacity_with_counters(); _write_opacity_to_config(); removed _run_opacity()
- `linux/command_banner.py` - New shared module with show_command_banner() matching Windows format
- `linux/redpill_tui.py` - Added docstring documenting config-file pattern filtering in refresh_tabs()
- `linux/wakeupneo.sh` - Added command banner call before sleep infinity
- `linux/bluepill.sh` - Added command banner call before sleep infinity
- `linux/redpill.sh` - Changed exec to regular call, added command banner after TUI exits
- `linux/build-release.sh` - Added command_banner.py to pymod copy list
- `linux/tests/test_hotkey_actions.py` - 10 new TestOpacityOverflow tests, 5 updated TestOpacityActions tests
- `linux/tests/test_command_banner.py` - 7 new tests for banner output format
- `linux/tests/test_redpill_tui.py` - 6 new TestWindowFiltering regression tests

## Decisions Made
- Opacity overflow/underflow uses module-level dicts keyed by config path (matches Windows per-window state)
- Removed _run_opacity() shell delegation entirely -- inline Python is faster and supports counters
- action_toggle_transparency resets overflow/underflow counters on toggle
- Command banner uses 24-bit ANSI color #35B381 for command names
- Non-shader window filtering already works correctly -- added regression tests rather than new filtering code

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated existing TestOpacityActions tests**
- **Found during:** Task 1
- **Issue:** Old tests tested shell delegation pattern (_run_opacity), which was removed
- **Fix:** Rewrote TestOpacityActions to test inline opacity logic with real temp config files
- **Files modified:** linux/tests/test_hotkey_actions.py
- **Verification:** All 49 test_hotkey_actions tests pass
- **Committed in:** 178574e (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary test update for removed code. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Opacity counters ready for Mac port (same logic, different config paths)
- Command banner ready for Mac port (same Python module)
- construct.sh (Plan 03) will natively include banner call
- SYNC-03 (OSD toast) acknowledged as already complete via matrix_toast.py

## Self-Check: PASSED

All 11 files verified present. All 3 task commits verified in git log. 637 tests pass (0 regressions).

---
*Phase: 11-platform-sync-v1-0-4-features*
*Completed: 2026-03-14*
