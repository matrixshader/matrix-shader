---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 02-01-PLAN.md
last_updated: "2026-03-08T17:26:36.828Z"
last_activity: 2026-03-08 — Completed hotkey action handlers (plan 02-02)
progress:
  total_phases: 10
  completed_phases: 1
  total_plans: 6
  completed_plans: 5
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-05)

**Core value:** Full platform parity — every Windows feature works on Linux and Mac. No compromises.
**Current focus:** Phase 2 — Full Hotkey System

## Current Position

Phase: 11 of 11 (Platform Sync v1.0.4 Features)
Plan: 3 of 4 in current phase
Status: Executing
Last activity: 2026-03-14 — Completed v1.0.4 small features (plan 11-02)

Progress: [████████░░] 83%

## Performance Metrics

**Velocity:**
- Total plans completed: 2
- Average duration: 10min
- Total execution time: 0.35 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-shader-hot-reload | 2/3 | 21min | 10min |

**Recent Trend:**
- Last 5 plans: 01-02 (5min), 01-01 (16min)
- Trend: Starting

*Updated after each plan completion*
| Phase 01 P01 | 16min | 2 tasks | 1 files |
| Phase 02 P02 | 8min | 1 tasks | 2 files |
| Phase 02 P01 | 10min | 2 tasks | 4 files |
| Phase 11 P02 | 6min | 3 tasks | 10 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: evdev confirmed working for Linux hotkeys — extend matrix-keys.py for all 13
- [Init]: Python with textual/curses for Red Pill TUI — already used for hotkeys
- [Init]: Patch Ghostty for window positioning — we own the binary, no Wayland excuses
- [Init]: Mac port parallelizable after Phase 2 — start Phase 8 while Phase 6-7 run
- [01-02]: Single-file shader_service.py module -- simpler for Phase 1, refactorable to package for Phase 2+
- [01-02]: Green preset as template source for create_slot_shader -- no separate template file needed
- [01-02]: Float formatting always f"{value:.1f}" -- prevents GLSL compilation errors from missing decimals
- [Phase 01]: Always reload shaders on config change (no content diffing) -- user-triggered, ~10-50ms negligible
- [Phase 01]: Zig 0.13.0 required for Ghostty v1.1.3 builds -- download to /tmp, use explicit PATH
- [02-02]: Opacity ported from matrix-opacity.sh to Python -- eliminates subprocess overhead, enables direct D-Bus reload
- [02-02]: Shared _toggle_layer() and _rotate_shaders() helpers -- DRY pattern for similar actions
- [02-02]: CycleLayout writes state.json only -- actual positioning deferred to Phase 6 per user decision
- [02-02]: Shader rotation reads all contents first then writes all -- prevents data loss during swap
- [Phase 02]: Opacity ported from matrix-opacity.sh to Python -- eliminates subprocess overhead
- [Phase 02]: Red Pill status via file existence (~/.config/matrix-shader/redpill.json) -- simple, mockable, licensing deferred
- [Phase 02]: InotifyWatcher watches directory not file for atomic write compatibility
- [11-02]: Opacity overflow/underflow uses module-level dicts keyed by config path -- matches Windows per-window state
- [11-02]: Removed _run_opacity() shell delegation -- inline Python is faster and supports counters
- [11-02]: Command banner uses 24-bit ANSI #35B381 for command names -- exact Windows match
- [11-02]: Non-shader window filtering already correct via get_ghostty_bus_names() -- added regression tests

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1 RESOLVED]: Ghostty v1.1.3 does NOT hot-reload shaders on file change. Patched changeConfig() in OpenGL.zig to re-compile shaders on D-Bus reload-config. Binary rebuilt and verified (01-01-PLAN.md).
- [Phase 5 RISK]: Wayland window positioning is the hardest feature. Compositor-specific IPC (GNOME Mutter D-Bus, swaymsg, KWin) may require separate code paths. Ghostty patch is the clean solution.
- [Phase 8 DEADLINE]: Mac port must be functional by March 11, 2026. Start planning Phase 8 no later than completion of Phase 2. CGEvent tap for hotkeys and terminal selection (Ghostty preferred) are the first decisions to resolve.

## Accumulated Context

### Roadmap Evolution
- Phase 11 added: Platform Sync — v1.0.4 Features (construct CLI, bonus shaders, OSD toast, opacity counters, command banner, TransitionToRain)
- Phases 1-10 all COMPLETE as of 2026-03-13 (roadmap progress table is stale)

## Session Continuity

Last session: 2026-03-14
Stopped at: Completed 11-02-PLAN.md
Resume file: None
