---
phase: 03-cli-integration
plan: 01
subsystem: cli
tags: [construct, bluepill, preset, argparse, bash]

# Dependency graph
requires:
  - phase: 01-preset-service
    provides: preset_service.py with load_preset/list_presets/save_preset
provides:
  - quick_launch_from_preset() function in construct_service.py
  - --preset flag in construct.sh for scriptable preset launching
  - --preset flag in bluepill.sh for preset-based session restore
  - _get_session_opacity() extracted helper for opacity inheritance
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [preset_service import in construct_service, RGB-derived foreground hex]

key-files:
  created: []
  modified:
    - linux/construct_service.py
    - linux/construct.sh
    - linux/bluepill.sh
    - linux/tests/test_preset_service.py

key-decisions:
  - "Foreground color derived from preset RAIN_R/G/B (not PRESET_FOREGROUNDS lookup) for arbitrary custom colors"
  - "Extracted _get_session_opacity() from quick_launch to avoid code duplication"
  - "bluepill --preset launches single window (not multi-window restore) matching construct behavior"

patterns-established:
  - "Preset launch pattern: load_preset -> create_slot_shader(r,g,b) -> replace_define non-RGB -> write config"
  - "Shell --preset arg parsing with both --preset=name and --preset name forms"

requirements-completed: [LOAD-04, LIST-03, INTG-03, INTG-04]

# Metrics
duration: 6min
completed: 2026-03-29
---

# Phase 3 Plan 01: CLI Preset Integration Summary

**construct --preset and bluepill --preset flags with RGB-derived foreground, full shader param bake-in, and session state persistence**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-29T13:33:15Z
- **Completed:** 2026-03-29T13:39:21Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- construct --preset <name> creates shader with all 11 params from saved preset, derives foreground from RGB, launches Ghostty window
- bluepill --preset <name> launches single window from preset with full CSS, config, state.json persistence, hotkeys, and watchdog
- Invalid preset names produce clear error listing available presets (both tools)
- Extracted _get_session_opacity() helper to eliminate code duplication between quick_launch and quick_launch_from_preset

## Task Commits

Each task was committed atomically:

1. **Task 1: Add quick_launch_from_preset + --preset to construct.sh** (TDD)
   - `0ec4c43` (test): add failing tests for quick_launch_from_preset
   - `69bad12` (feat): implement quick_launch_from_preset, _get_session_opacity, CLI subcommand, shell flag
2. **Task 2: Add --preset flag to bluepill.sh** - `3ad138a` (feat)

## Files Created/Modified
- `linux/construct_service.py` - Added quick_launch_from_preset(), _get_session_opacity(), quick-launch-preset CLI, updated help
- `linux/construct.sh` - Added --preset flag parsing and Ghostty launch block
- `linux/bluepill.sh` - Added --preset parsing, forwarding, and full preset launch flow with state persistence
- `linux/tests/test_preset_service.py` - 3 new tests in TestConstructPresetIntegration class

## Decisions Made
- Foreground color derived from preset RAIN_R/G/B values (not from PRESET_FOREGROUNDS index lookup) so custom colors outside the 6 standard presets display correctly
- Extracted _get_session_opacity() from quick_launch to avoid duplicating the 20-line opacity inheritance logic
- bluepill --preset launches a single window (matching construct --preset behavior) rather than multi-window restore

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Test assertions initially used exact string match (`#define RAIN_R 0.5`) but shader template uses padded whitespace (`#define RAIN_R         0.5`). Fixed by using regex assertions with `\s+` for whitespace matching.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All three phases of the preset system are complete
- Presets are usable from TUI (Phase 2) and CLI tools (Phase 3)
- No blockers or concerns

## Self-Check: PASSED

All 5 files found. All 3 commits verified.

---
*Phase: 03-cli-integration*
*Completed: 2026-03-29*
