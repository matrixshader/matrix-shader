---
phase: 11-platform-sync-v1-0-4-features
plan: 04
subsystem: platform-port
tags: [mac, construct, command-banner, build-pipeline, cross-platform]

# Dependency graph
requires:
  - phase: 11-platform-sync-v1-0-4-features
    provides: "Linux construct CLI (plan 03), command banner + opacity counters (plan 02), bonus shaders (plan 01)"
provides:
  - "Mac construct CLI (construct_mac.sh + construct_service_mac.py)"
  - "Command banner on exit of all Mac CLI tools"
  - "Mac build pipeline staging construct + command_banner"
  - "Full cross-platform parity for Phase 11 features"
affects: [release, installer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mac construct_service_mac.py wraps Linux construct_service.py with SIGHUP reload"
    - "Mac slot discovery uses ps -eo pid,args instead of /proc/PID/exe"
    - "Mac Ghostty config uses macos-titlebar-style instead of gtk-titlebar"

key-files:
  created:
    - mac/construct_mac.sh
    - mac/construct_service_mac.py
    - mac/tests/test_construct_mac.py
  modified:
    - mac/wakeupneo_mac.sh
    - mac/bluepill_mac.sh
    - mac/redpill_mac.sh
    - mac/build-release.sh
    - mac/shader_service_mac.py
    - mac/tests/test_scripts_mac.py

key-decisions:
  - "Mac construct uses find_next_slot_mac with ps-based process discovery instead of Linux /proc approach"
  - "Mac Ghostty config uses macos-titlebar-style=hidden and SF Mono font defaults"
  - "Command banner shared from linux/command_banner.py via relative path -- no Mac-specific copy"
  - "get_all_ghostty_configs added to shader_service_mac.py for Mac opacity counter support"

patterns-established:
  - "Mac CLI wrappers follow established port pattern: Mac .sh scripts call Mac Python services that wrap Linux Python modules"
  - "Shared Linux Python modules (command_banner.py, construct_service.py) referenced via ../linux/ relative path"

requirements-completed: [SYNC-01, SYNC-02, SYNC-03, SYNC-04, SYNC-05, SYNC-06, SYNC-07]

# Metrics
duration: 1min
completed: 2026-03-14
---

# Phase 11 Plan 04: Mac Port Summary

**Mac construct CLI + command banner + build pipeline update for full cross-platform parity of all Phase 11 features**

## Performance

- **Duration:** 1 min (verification-only -- code already committed by previous agent)
- **Started:** 2026-03-14T02:10:12Z
- **Completed:** 2026-03-14T02:11:19Z
- **Tasks:** 2 (TDD + auto)
- **Files modified:** 9

## Accomplishments
- Mac construct CLI (construct_mac.sh + construct_service_mac.py) with quick launch, white room picker, and SIGHUP reload
- Command banner shows on exit of all 3 Mac CLI tools (wakeupneo, bluepill, redpill)
- Mac build-release.sh stages construct_mac.sh, construct_service_mac.py, construct_service.py, and command_banner.py
- Opacity counters and window filtering work on Mac via shared Linux modules (no Mac-specific code needed)
- 30 Mac construct tests pass, 258 total Mac tests pass, 708 Linux tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1 (TDD RED): Mac construct tests** - `465cda2` (test)
2. **Task 1 (TDD GREEN): Mac construct CLI and service** - `e0b85ee` (feat)
3. **Task 2: Command banner + build pipeline** - `1ec0c8e` (feat)

## Files Created/Modified
- `mac/construct_mac.sh` - Mac construct CLI entry point with 3-way Ghostty detection, SF Mono font, macOS titlebar
- `mac/construct_service_mac.py` - Mac construct service wrapping Linux with ps-based slot discovery and SIGHUP reload
- `mac/tests/test_construct_mac.py` - 30 tests covering imports, color mappings, slot discovery, quick launch, transition, config format, and shell script flags
- `mac/wakeupneo_mac.sh` - Added command banner call at script exit
- `mac/bluepill_mac.sh` - Added command banner call after restore flow
- `mac/redpill_mac.sh` - Added command banner call after TUI exits
- `mac/build-release.sh` - Added construct_mac.sh, construct_service_mac.py to Mac scripts staging; construct_service.py, command_banner.py to shared Linux modules staging
- `mac/shader_service_mac.py` - Added get_all_ghostty_configs() for Mac opacity counter support
- `mac/tests/test_scripts_mac.py` - Added construct_mac.sh to shell syntax validation list

## Decisions Made
- Mac construct uses find_next_slot_mac with ps-based process discovery instead of Linux /proc approach
- Mac Ghostty config uses macos-titlebar-style=hidden and SF Mono font defaults (vs gtk-titlebar and Nimbus Mono PS on Linux)
- Command banner shared from linux/command_banner.py via relative path -- no Mac-specific copy needed
- get_all_ghostty_configs added to shader_service_mac.py for Mac opacity counter support
- SYNC-03 (OSD toast) acknowledged as already complete via matrix_toast_mac.py

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Phase 11 features now have full cross-platform parity (Linux + Mac)
- Phase 11 is complete: all 4 plans executed successfully
- Ready for release packaging and v1.0.4 deployment

## Self-Check: PASSED

- All 3 key files exist (construct_mac.sh, construct_service_mac.py, test_construct_mac.py)
- All 3 commits verified (465cda2, e0b85ee, 1ec0c8e)
- SUMMARY.md created

---
*Phase: 11-platform-sync-v1-0-4-features*
*Completed: 2026-03-14*
