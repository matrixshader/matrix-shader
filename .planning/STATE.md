# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Instant startup with full PowerShell feature parity
**Current focus:** Phase 12 - E2E Gap Closure (IN PROGRESS)

## Current Position

Milestone: v1.0 IN PROGRESS (18 bugs found in E2E testing)
Phase: 12 - E2E Gap Closure (IN PROGRESS)
Plan: 05 of 7+ (Installer uninstall and re-run detection)
Status: Plan 12-05 complete
Last activity: 2026-02-01 - Completed 12-05-PLAN.md (Uninstaller fixes + re-run detection)

Progress: [#####################################################] 53 plans complete

## Phase 12 Plan Summary (IN PROGRESS)

**7+ plans in 4 waves:**

| Wave | Plan | Objective | Status |
|------|------|-----------|--------|
| 1 | 12-01 | Critical bugs (WT detection, shader regex) | COMPLETE |
| 1 | 12-02 | MatrixLite ANSI rendering | COMPLETE |
| 2 | 12-03 | MatrixLite usability (terminal blocking, menu) | PENDING |
| 2 | 12-04 | First-run detection | PENDING |
| 3 | 12-05 | Uninstaller fixes + re-run detection | COMPLETE |
| 3 | 12-06 | WT installation flow | PENDING |
| 4 | 12-07 | Final E2E verification | PENDING |

**Bugs fixed so far:**
- BUG-WT01/02: Windows Terminal detection (12-01)
- BUG-SHADER01: Shader regex replacement (12-01)
- BUG-ML01: VT Processing for cmd.exe (12-02)
- BUG-ML05/06: Color synchronization (12-02)
- BUG-UNINST01: Useless uninstall error messages (12-05)
- BUG-UNINST02: 54+ DLLs left behind on uninstall (12-05)
- GAP-INST01: Installer blindly overwrites existing install (12-05)

## Accumulated Context

### Roadmap Evolution

- Phase 8.1 inserted after Phase 8: Gap closure before AOT (URGENT)
- Phase 10.5 inserted after Phase 10: Global Hotkeys - COMPLETE
- Phase 11 plan 06 added: Installer BUILD step was missing
- Phase 11 plan 07 added: One-liner install script for command-line users
- Phase 12 added: E2E Gap Closure - Fix all 18 bugs from Windows Sandbox testing

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

### Blockers/Concerns

1. **GitHub Releases setup required** - Need to upload MatrixShader.zip to Releases for one-liner to work
2. **Domain redirect** - Need matrixshader.com/install.ps1 to redirect to raw GitHub URL
3. **Remaining bugs** - 10 more bugs to fix in Phase 12 (BUG-ML02/03/04, BUG-FRX01, remaining GAPs)

## Session Continuity

Last session: 2026-02-01
Stopped at: Completed 12-05-PLAN.md (Uninstaller fixes + re-run detection)
Resume file: None
Next action: Execute remaining Phase 12 plans (12-03, 12-04, 12-06, 12-07)

---
*State initialized: 2026-01-25*
*Last updated: 2026-02-01 - Phase 12 plan 05 complete*
