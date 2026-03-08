---
phase: 02-full-hotkey-system
plan: 01
subsystem: hotkeys
tags: [evdev, inotify, json-config, gsettings, kde, notify-send, ctypes]

# Dependency graph
requires:
  - phase: 01-shader-hot-reload
    provides: shader_service.py atomic_write pattern and PARAM_DEFAULTS reference
provides:
  - DEFAULT_BINDINGS dict with all 13 action-keyed hotkey definitions
  - KEY_NAME_TO_EVDEV and MODIFIER_NAME_TO_EVDEV translation maps
  - load_config / save_config with atomic write and fallback-to-defaults
  - build_hotkey_table converting config to evdev (frozenset, keycode) lookup
  - InotifyWatcher class for config file change detection via select.select()
  - is_redpill gate for upgrade status check
  - GNOME gsettings and KDE kglobalshortcutsrc conflict detection
  - notify_conflicts single-notification summary via notify-send
affects: [02-full-hotkey-system, 04-red-pill-tui]

# Tech tracking
tech-stack:
  added: [ctypes inotify wrapper, configparser for KDE INI]
  patterns: [action-keyed config dict, evdev lookup table with frozenset keys, directory-level inotify watch for atomic writes, GDK accelerator format parsing]

key-files:
  created:
    - linux/hotkey_config.py
    - linux/hotkey_conflicts.py
    - linux/tests/test_hotkey_config.py
    - linux/tests/test_hotkey_conflicts.py

key-decisions:
  - "Red Pill status checked via file existence (~/.config/matrix-shader/redpill.json) -- simple, mockable, licensing deferred"
  - "InotifyWatcher watches directory not file for atomic write (temp + os.replace) compatibility"
  - "build_hotkey_table uses frozenset of all left+right modifier codes as lookup key -- matches any physical modifier key"
  - "KDE shortcuts parsed via configparser for INI format -- first comma-separated field is active shortcut"

patterns-established:
  - "Action-keyed config dict: {action_name: {key, modifiers, enabled}} matching Windows HotkeyConfig.cs"
  - "evdev lookup table: {(frozenset(mod_codes), key_code): action_name} for O(1) dispatch"
  - "Directory inotify watch: IN_CLOSE_WRITE | IN_MOVED_TO on config dir, filter by filename"
  - "Conflict detection once on config load, not per-keypress"

requirements-completed: [HKEY-07, HKEY-08]

# Metrics
duration: 10min
completed: 2026-03-08
---

# Phase 2 Plan 1: Hotkey Config and Conflict Detection Summary

**Action-keyed hotkey config with 13 defaults, inotify live-reload, Red Pill gate, and GNOME/KDE system shortcut conflict detection via gsettings and kglobalshortcutsrc**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-08T17:14:47Z
- **Completed:** 2026-03-08T17:25:06Z
- **Tasks:** 2 (both TDD: RED -> GREEN)
- **Files created:** 4

## Accomplishments
- hotkey_config.py with 13 DEFAULT_BINDINGS, load/save with atomic write, build_hotkey_table producing evdev O(1) lookup, InotifyWatcher using ctypes inotify, and is_redpill file-existence gate
- hotkey_conflicts.py with GDK accelerator parsing, GNOME gsettings querying (4 schemas), KDE kglobalshortcutsrc INI parsing, case-insensitive conflict detection, and single summary notify-send notification
- 60 total tests covering all behaviors including edge cases (corrupt JSON, missing gsettings, timeouts, empty bindings)

## Task Commits

Each task was committed atomically (TDD: test then implementation):

1. **Task 1: Hotkey config model** - `5ec7975` (test) -> `ed68a80` (feat) -- 37 tests
2. **Task 2: Conflict detection** - `4380ac5` (test) -> `15ce823` (feat) -- 23 tests

## Files Created/Modified
- `linux/hotkey_config.py` - Config model, defaults, load/save, inotify watcher, Red Pill gate
- `linux/hotkey_conflicts.py` - GNOME/KDE conflict detection, notification
- `linux/tests/test_hotkey_config.py` - 37 tests for config module
- `linux/tests/test_hotkey_conflicts.py` - 23 tests for conflict detection

## Decisions Made
- Red Pill status checked via `os.path.exists(~/.config/matrix-shader/redpill.json)` -- simplest gate, mockable in tests, actual licensing deferred to Phase 4
- InotifyWatcher watches the directory (not the file) because atomic writes (temp + os.replace) replace the inode, invalidating direct file watches
- Modifier lookup uses frozenset of all left+right evdev codes -- when checking held keys, any physical Ctrl/Shift matches
- KDE shortcuts parsed via stdlib configparser (INI format) -- avoids external dependencies

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test_skips_disabled_bindings assertion**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** Test called build_hotkey_table(config) without is_redpill=True, so the function ignored the custom config with disabled SpeedUp and used DEFAULT_BINDINGS instead
- **Fix:** Added is_redpill=True to the test call so custom config (with disabled binding) is actually used
- **Files modified:** linux/tests/test_hotkey_config.py
- **Verification:** All 37 tests pass
- **Committed in:** ed68a80 (part of Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug in test logic)
**Impact on plan:** Test correction only, no impact on implementation scope.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- hotkey_config.py and hotkey_conflicts.py are ready for consumption by matrix-keys.py (Plan 03)
- build_hotkey_table output maps directly to evdev event loop dispatch
- InotifyWatcher.fileno() integrates with select.select() alongside evdev keyboard fd
- detect_conflicts + notify_conflicts ready to be called on config load and reload

## Self-Check: PASSED

All 4 created files verified on disk. All 4 commit hashes found in git log.

---
*Phase: 02-full-hotkey-system*
*Completed: 2026-03-08*
