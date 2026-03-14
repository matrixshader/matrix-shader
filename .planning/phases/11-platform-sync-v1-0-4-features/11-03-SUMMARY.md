---
phase: 11-platform-sync-v1-0-4-features
plan: 03
subsystem: cli
tags: [construct, ghostty, shader, quick-launch, white-room, transition-to-rain, dbus]

# Dependency graph
requires:
  - phase: 11-platform-sync-v1-0-4-features
    provides: "Bonus GLSL shaders (aurora, fireplace, codevision, ultra, rain-on-glass) and white-room shader from plan 01; command_banner.py from plan 02"
provides:
  - "construct CLI command (construct.sh + construct_service.py)"
  - "Quick launch: construct --green/--red/--blue/--purple/--gold/--teal"
  - "Bonus shader launch: construct --aurora/--aurora-rain/--fireplace/--codevision/--ultra/--rain-on-glass"
  - "White room CRT picker with TransitionToRain (same-window shader swap)"
  - "Build + install pipeline integration for construct command"
affects: [mac-construct-port, installer-testing]

# Tech tracking
tech-stack:
  added: []
  patterns: [construct-quick-launch, transition-to-rain, bonus-shader-slot-copy]

key-files:
  created:
    - linux/construct.sh
    - linux/construct_service.py
    - linux/tests/test_construct.py
  modified:
    - linux/build-release.sh
    - linux/install.sh

key-decisions:
  - "Bonus shaders copied to slot dir as matrix-{slot}.glsl for consistent slot naming (per RESEARCH.md Pitfall 6)"
  - "White room self-relaunch uses --pick flag and ghostty-construct-{slot}.conf naming"
  - "TransitionToRain uses atomic config rewrite + D-Bus reload for same-window shader swap"
  - "find_next_slot uses _get_occupied_slots helper with pgrep + /proc/exe readlink filtering"

patterns-established:
  - "Construct quick launch: shell flag -> python3 construct_service.py quick-launch -> create shader + config -> spawn Ghostty"
  - "Bonus shader slot copy: copy from shaders-glsl/ to ~/.config/matrix-shader/shaders/matrix-{slot}.glsl"
  - "TransitionToRain: rewrite Ghostty config (shader path + opacity) + D-Bus reload in same window"

requirements-completed: [SYNC-01, SYNC-06]

# Metrics
duration: 6min
completed: 2026-03-14
---

# Phase 11 Plan 03: Construct CLI Summary

**Construct CLI with quick-launch (6 colors + 6 bonus shaders), white room CRT picker, and TransitionToRain same-window shader swap**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-14T01:53:17Z
- **Completed:** 2026-03-14T01:59:30Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Created construct.sh bash entry point with self-relaunch pattern for white room mode and quick launch for 12 shader options
- Created construct_service.py with find_next_slot, quick_launch, transition_to_rain, white_room_picker, and show_help
- Wired construct into build-release.sh (staging) and install.sh (install + path patching)
- 35 new tests covering all color/bonus mappings, slot management, config generation, transition logic, and help output

## Task Commits

Each task was committed atomically:

1. **Task 1: Create construct.sh + construct_service.py with quick launch and white room** - `3187e4d` (test: RED), `2725a05` (feat: GREEN)
2. **Task 2: Wire construct into build-release.sh and install.sh** - `5732126` (feat)

## Files Created/Modified
- `linux/construct.sh` - Bash entry point: self-relaunch, flag parsing, Ghostty spawn
- `linux/construct_service.py` - Python service: slot management, quick launch, TransitionToRain, white room picker, help
- `linux/tests/test_construct.py` - 35 unit tests for construct functionality
- `linux/build-release.sh` - Added construct.sh and construct_service.py staging
- `linux/install.sh` - Added construct install, path patching, pylib modules, PYTHONPATH injection

## Decisions Made
- Bonus shaders are copied to slot directory as matrix-{slot}.glsl (not referenced directly) to maintain consistent slot naming for hotkeys, redpill TUI, and bluepill compatibility
- White room mode uses --pick flag (not --in-ghostty) to distinguish from regular self-relaunch
- Construct configs use ghostty-construct-{slot}.conf naming during picker, renamed to ghostty-matrix-{slot}.conf on transition
- find_next_slot delegates to _get_occupied_slots helper for testability

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test_returns_2_when_slot_1_occupied test mock approach**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** Test used low-level subprocess.run + /proc mocking that didn't match actual implementation's _get_occupied_slots helper
- **Fix:** Changed test to mock _get_occupied_slots directly (same pattern as other slot tests)
- **Files modified:** linux/tests/test_construct.py
- **Verification:** All 35 tests pass
- **Committed in:** 2725a05 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor test-level fix, no functional impact.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Construct CLI ready for Mac port (plan 04)
- All 12 shader options (6 standard + 6 bonus) accessible via construct command
- Build and install pipelines updated; no manual steps needed

---
*Phase: 11-platform-sync-v1-0-4-features*
*Completed: 2026-03-14*

## Self-Check: PASSED
- All 3 created files exist
- All 3 commits verified in git history
