---
phase: 01-global-transparency
plan: 02
subsystem: osd-overlay
tags: [osd, toast, win32, layered-window, gdi, opacity-feedback]

# Dependency graph
requires:
  - phase: 01-global-transparency
    plan: 01
    provides: "Global AdjustOpacity with overflow/underflow counters and OsdToastEnabled property"
provides:
  - "OSD toast overlay showing opacity percentage on J/K presses"
  - "OSD toast on B toggle showing cycle state percentage"
  - "Win32 layered popup with color-key transparency (floating text, no box)"
  - "Fade-out animation via SetTimer/WM_TIMER alpha ramp"
affects: [redpill-osd-toggle]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Win32 layered window with LWA_COLORKEY for transparent background (floating text)"
    - "GDI text rendering via BeginPaint/CreateFontW/ExtTextOutW on message loop thread"
    - "SetTimer/WM_TIMER for fade animation (avoids cross-thread issues)"
    - "Null-conditional OSD call pattern (_osdOverlay?.ShowToast) for optional overlay"

key-files:
  created:
    - "MatrixShader/src/MatrixShader.Hotkeys/OsdOverlay.cs"
  modified:
    - "MatrixShader/src/MatrixShader.Core/Native/HotkeyApi.cs"
    - "MatrixShader/src/MatrixShader.Hotkeys/HotkeyActions.cs"
    - "MatrixShader/src/MatrixShader.Hotkeys/Program.cs"

key-decisions:
  - "Color-key transparency (LWA_COLORKEY) instead of solid dark background — text floats with no visible box"
  - "Green #2c6e49 text in Nimbus Mono PS font per user preference"
  - "Toggle (Ctrl+Shift+B) shows actual percentage, not state name"
  - "OsdToastEnabled read fresh from state file on each keypress (no caching) for instant Redpill toggle effect"
  - "OSD created on message loop thread (same as HotkeyWindow) to avoid cross-thread Win32 issues"

patterns-established:
  - "Win32 layered popup: register class, create with WS_EX_LAYERED|TOPMOST|NOACTIVATE|TOOLWINDOW|TRANSPARENT, color key for transparent bg"
  - "GDI paint cycle: BeginPaint → FillRect(key color) → CreateFontW → SetBkMode(TRANSPARENT) → ExtTextOutW → EndPaint"
  - "Timer-based fade: display timer → kill → start fade timer → decrement alpha → hide at zero"

# Metrics
duration: 25min
completed: 2026-03-06
---

# Phase 1 Plan 2: OSD Toast Overlay Summary

**Win32 layered popup window displaying floating green opacity percentage on hotkey presses**

## Performance

- **Duration:** 25 min (including human verification and style iteration)
- **Started:** 2026-03-06
- **Completed:** 2026-03-06
- **Tasks:** 3 (2 auto + 1 human checkpoint)
- **Files created:** 1
- **Files modified:** 3

## Accomplishments
- Created OsdOverlay.cs: Win32 layered popup with color-key transparency for floating text
- Added 15+ P/Invoke declarations to HotkeyApi.cs (SetLayeredWindowAttributes, SetTimer, GDI text functions)
- Wired OSD into AdjustOpacity flow (J/K hotkeys) gated by OsdToastEnabled
- Added OSD toast to ToggleTransparency (B hotkey) showing actual percentage
- Styled with green #2c6e49 text in Nimbus Mono PS (no background box)
- Fade-out animation: 1.2s display + 300ms alpha ramp to zero
- Fixed OsdToastEnabled default issue (existing state files had false from JSON deserialization)

## Task Commits

1. **Task 1: OsdOverlay Win32 layered window + P/Invoke declarations** - `c4facb2` (feat)
2. **Task 2: Wire OSD into hotkey flow and Program.cs lifecycle** - `5327355` (feat)
3. **Task 3: Visual verification + style fixes** - `311119f` (fix)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Hotkeys/OsdOverlay.cs` — NEW: Win32 layered popup, GDI rendering, timer-based fade
- `MatrixShader/src/MatrixShader.Core/Native/HotkeyApi.cs` — Added P/Invoke: SetLayeredWindowAttributes, SetTimer, KillTimer, CreateFontW, GDI functions, LWA_COLORKEY
- `MatrixShader/src/MatrixShader.Hotkeys/HotkeyActions.cs` — ShowToast calls in AdjustOpacity and ToggleTransparency
- `MatrixShader/src/MatrixShader.Hotkeys/Program.cs` — OsdOverlay creation and lifecycle

## Decisions Made
- Color-key transparency gives floating text effect (user preferred over grey box)
- Green #2c6e49 in Nimbus Mono PS font (user specified)
- Toggle shows "80%" not "Custom" (user feedback during checkpoint)
- OsdToastEnabled checked fresh each keypress (instant Redpill toggle without restart)

## Deviations from Plan
- Style changed from dark grey box with white Segoe UI text to transparent floating green Nimbus Mono PS (user feedback)
- Added toast to ToggleTransparency (B hotkey) — not in original plan but consistent UX
- Fixed OsdToastEnabled default: existing state files had `false` from JSON deserialization missing-field behavior

## Issues Encountered
- OsdToastEnabled was `false` in existing state file (JSON deserializer gives `default(bool)` for missing fields, not the C# `init` default)
- Build requires killing running matrix-hotkeys.exe first (DLL lock)

## User Setup Required
None.

## Next Phase Readiness
- Phase 1 complete: global transparency + OSD toast both verified working
- OsdToastEnabled toggle ready for Redpill settings UI integration
- Feature ideas captured for future phases: color-matched terminal text, wakeupneo self-launch, SaaS licensing

## Self-Check: PASSED

---
*Phase: 01-global-transparency*
*Completed: 2026-03-06*
