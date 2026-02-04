# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Instant startup with full PowerShell feature parity
**Current focus:** Phase 14 - Final Polish & Hotkey Stability (IN PROGRESS)

## Current Position

Milestone: v1.0 IN PROGRESS
Phase: 14 - Final Polish & Hotkey Stability (IN PROGRESS)
Plan: 04 of 06
Status: Plan 14-04 complete (BUG-LAYOUT05, BUG-LAYOUT06, BUG-LAYOUT07 - layout gaps + fullscreen)
Last activity: 2026-02-04 - Completed 14-04 (scaled gaps + fullscreen exclusion)

Progress: [################################################################] 64 plans complete

## Phase 12 Plan Summary (IN PROGRESS)

**7+ plans in 4 waves:**

| Wave | Plan | Objective | Status |
|------|------|-----------|--------|
| 1 | 12-01 | Critical bugs (WT detection, shader regex) | COMPLETE |
| 1 | 12-02 | MatrixLite ANSI rendering | COMPLETE |
| 2 | 12-03 | MatrixLite usability (terminal blocking, menu) | COMPLETE |
| 2 | 12-04 | WT installation fallback chain | COMPLETE |
| 3 | 12-05 | Uninstaller fixes + re-run detection | COMPLETE |
| 3 | 12-06 | First-run detection fix (BUG-FRX01) | COMPLETE |
| 4 | 12-07 | Final E2E verification | PENDING |

**Bugs fixed so far:**
- BUG-WT01/02: Windows Terminal detection (12-01)
- BUG-SHADER01: Shader regex replacement (12-01)
- BUG-ML01: VT Processing for cmd.exe (12-02)
- BUG-ML05/06: Color synchronization (12-02)
- BUG-UNINST01: Useless uninstall error messages (12-05)
- BUG-UNINST02: 54+ DLLs left behind on uninstall (12-05)
- GAP-INST01: Installer blindly overwrites existing install (12-05)
- GAP-E03a/b/c: WT installation dead ends (12-04)
- BUG-ML02: Terminal blocking - background mode added (12-03)
- BUG-ML03: Missing bluepill option - Blue Pill intro choice (12-03)
- BUG-ML04: Broken menu loop - fixed state machine (12-03)
- BUG-FRX01: False "Previous sessions found" on fresh install (12-06)

## Accumulated Context

### Roadmap Evolution

- Phase 8.1 inserted after Phase 8: Gap closure before AOT (URGENT)
- Phase 10.5 inserted after Phase 10: Global Hotkeys - COMPLETE
- Phase 11 plan 06 added: Installer BUILD step was missing
- Phase 11 plan 07 added: One-liner install script for command-line users
- Phase 12 added: E2E Gap Closure - Fix all 18 bugs from Windows Sandbox testing
- Phase 13 added: Post-E2E Polish - Fix 17 NEW bugs from post-microsprint testing (WT detection, MatrixLite, layout, transparency, redpill UX, installer theming)
- Phase 14 added: Final Polish & Hotkey Stability - Fix 12 bugs from one-liner E2E testing (hotkey service crashes, acrylic haze, transparency persistence, shader cycling, layout gaps)

### Decisions (Phase 12)

| Decision | Rationale | Source |
|----------|-----------|--------|
| MatchEvaluator for regex replacement | Avoids $1 backreference interpretation issues | 12-01 |
| Multi-path WT settings detection | Support Store, Winget, Scoop, Chocolatey installs | 12-01 |
| wt.exe fallback to PATH | Works with portable/custom installations | 12-01 |
| P/Invoke in TextMatrixRenderer | Reduce coupling, local implementation | 12-02 |
| Both VT flags (0x0004 + 0x0001) | Maximum Windows compatibility | 12-02 |
| Defensive state sync | Prevent future state divergence bugs | 12-02 |
| filesandordirs for {app} cleanup | Complete removal of all installed files | 12-05 |
| WHAT/WHERE/WHY/HOW error pattern | Actionable error messages for users | 12-05 |
| YESNOCANCEL for re-run detection | Clear user choices: Update/Uninstall/Cancel | 12-05 |
| winget --version with 5s timeout | Detect winget availability before install | 12-04 |
| GitHub releases API regex parsing | Avoid JSON library dependency | 12-04 |
| 4-method fallback chain | winget -> Store -> GitHub -> Manual | 12-04 |
| ASCII box characters for menu | Better cmd.exe compatibility than Unicode | 12-03 |
| Blue Pill as Enter default | Quick start experience for users | 12-03 |
| Async menu handler naming | Consistency with async/await pattern | 12-03 |
| IsFirstRun checks state file existence | Bundled shaders in Program Files should not trigger false session detection | 12-06 |

### Decisions (Phase 11)

| Decision | Rationale | Source |
|----------|-----------|--------|
| LocalAppData for user data | Standard Windows pattern, avoids Documents folder issues | CONTEXT.md |
| Inno Setup installer | Keep existing approach, mature tooling | CONTEXT.md |
| winget for WT install | Microsoft's official package manager | RESEARCH.md |
| Manual testing in Sandbox | Adequate for v1.0, automated testing deferred | CONTEXT.md |
| Explicit --self-contained true | Clearer than --no-self-contained:false, avoids confusion | 11-02 |
| Primary lookup matrix-monitor.exe | Matches installed name, legacy fallback for dev | 11-02 |
| CMD xcopy over Pascal FileCopy | Simpler, fewer lines, works reliably | 11-03 |
| Full LocalAppData cleanup | Clean slate on reinstall, users run wakeupneo again | 11-03 |
| Message box for PATH notification | More visible than finish label, PATH issues common | 11-03 |
| Optional controlPanelPath | Simplifies API, auto-finds redpill.exe in installed or local location | 11-04 |
| Tuple return for CanUseShaders | Provides both result and reason in single call | 11-04 |
| Verify after SaveSettings | Catches issues early, before confusing runtime errors | 11-04 |
| Separate build plan (11-06) | Code changes and build step were incorrectly conflated | planning fix |
| One-liner as primary install | Developer-friendly, faster than GUI installer | 11-07 |
| Admin vs non-admin paths | Program Files for admin, LocalAppData for non-admin | 11-07 |
| GitHub Releases for distribution | Standard pattern, works with one-liner script | 11-07 |

### Decisions (Phase 13)

| Decision | Rationale | Source |
|----------|-----------|--------|
| ShowRestartInstructions after WT install | Users need clear guidance, not silent Lite fallback | 13-01 |
| Return false to signal restart needed | Prevents automatic Lite mode, BootstrapResult clarifies | 13-01 |
| Check IsWindowsTerminal() after install | Detects if running inside WT vs cmd/PowerShell | 13-01 |
| MinWindowWidth = 200 for narrow pillars | Allow 4+ columns in Pillars mode | 13-02 |
| Gap reduction before row addition | Preserve Pillars single-row layout intent | 13-02 |
| Skip minimized windows (continue) | Respect user's intentional window state | 13-02 |
| Console.CancelKeyPress with e.Cancel = true | Prevents process termination, signals return to menu | 13-08 |
| Menu loop pattern for iterative choices | Allows re-choosing Blue Pill / Red Pill after effect | 13-08 |
| Exit option [Q] in pill choice menu | Provides clean way to exit program entirely | 13-08 |
| High-frequency sine hash for col_hash | Different from random() to ensure independent variation | 13-03 |
| 2.5x screen height phase offset | Sufficient stagger without excessive offset | 13-03 |
| $000000 black + $001100 green tint | Matrix aesthetic with dark background and green accents | 13-05 |
| MB_YESNO instead of MB_YESNOCANCEL | Simplify re-run dialog, close window to cancel | 13-05 |
| Per-profile opacity (85%) vs defaults | Keeps non-Matrix WT windows 100% opaque | 13-06 |
| WT_PROFILE_ID for profile detection | Reliable detection of named profile | 13-04 |
| ClearWidth=80 for line padding | Prevents menu content overlap | 13-04 |
| '?' key for hotkey help | Easy discovery of all key bindings | 13-04 |

### Decisions (Phase 14)

| Decision | Rationale | Source |
|----------|-----------|--------|
| 30-second stay-alive timer | Allow window reopening without hotkey service restart | 14-01 |
| 5-second watchdog health check | Balance responsiveness with CPU overhead | 14-01 |
| HotkeyWatchdog in Monitor service | Centralized supervision vs self-healing process | 14-01 |
| NoWindowThreshold = 15 | 15 * 2s intervals = 30 seconds for stay-alive | 14-01 |
| UseAcrylic = false | Plain transparency without blur/haze on Windows 11 | 14-02 |
| Preserve FIRST original only | Prevents overwriting user's true original settings | 14-02 |
| Check both WT paths on uninstall | Support Store and Winget installations | 14-02 |
| Scale formula: 100%/80%/60% for 1-2/3/4+ windows | Progressive gap reduction maintains usability | 14-04 |
| Minimum gap 20px | Ensures clickable space between windows | 14-04 |
| IsZoomed filters fullscreen before overlap | Prevents F11 snap-back | 14-04 |
| Cooldown reset after manual layout | Prevents snap-back after layout changes | 14-04 |

### Blockers/Concerns

1. **GitHub Releases setup required** - Need to upload MatrixShader.zip to Releases for one-liner to work
2. **Domain redirect** - Need matrixshader.com/install.ps1 to redirect to raw GitHub URL

### Phase 12 Microsprint Results (2026-02-01)

During lunch break microsprint, GSD agents fixed 6 bugs:
- BUG-WT05: XAML dependency added to GitHub fallback (FIXED)
- BUG-DEFAULT01: Lowered default density from 0.4 to 0.25 (FIXED)
- BUG-TRANS01: Removed profiles.defaults modification (FIXED)
- BUG-SHADER02: Added CreateRedpillProfile() call (FIXED)
- BUG-LAYOUT01/02: Added WM_DISPLAYCHANGE handling + overlap detection (FIXED)
- BUG-CRASH01: CPU freeze INCONCLUSIVE - likely WMI/sandbox contention

## Session Continuity

Last session: 2026-02-04
Stopped at: Completed 14-04-PLAN.md
Resume file: None
Next action: Continue with 14-05 or 14-06 (remaining phase 14 plans)

---
*State initialized: 2026-01-25*
*Last updated: 2026-02-04 - Completed 14-04 (BUG-LAYOUT05, BUG-LAYOUT06, BUG-LAYOUT07 - layout gaps + fullscreen)*
