# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Instant startup with full PowerShell feature parity
**Current focus:** Phase 11 - Installer & E2E Validation (7 plans in 5 waves)

## Current Position

Milestone: v1.0 INCOMPLETE (installer never built)
Phase: 11 - Installer & E2E Validation (IN PROGRESS)
Status: Wave 3 in progress (11-05), Wave 4 queued (11-06), Wave 5 queued (11-07)
Last activity: 2026-01-31 — Added 11-07-PLAN.md for one-liner install script

Progress: [##########################################] 48 plans complete, 3 plans queued

## Phase 11 Plan Summary (UPDATED)

**7 plans in 5 waves:**

| Wave | Plan | Objective | Status |
|------|------|-----------|--------|
| 1 | 11-01 | Path resolution architecture | COMPLETE |
| 1 | 11-02 | Installer completeness | COMPLETE |
| 2 | 11-03 | Installer polish | COMPLETE |
| 2 | 11-04 | Runtime safety | COMPLETE |
| 3 | 11-05 | Documentation & validation | IN PROGRESS |
| 4 | 11-06 | BUILD installer and E2E test | QUEUED |
| 5 | 11-07 | One-liner install script | QUEUED |

**Key insight:** Plans 11-01 through 11-04 are CODE changes. Plan 11-06 BUILDS the installer. Plan 11-07 provides an alternative one-liner install method that downloads from GitHub Releases.

## Accumulated Context

### Roadmap Evolution

- Phase 8.1 inserted after Phase 8: Gap closure before AOT (URGENT)
- Phase 10.5 inserted after Phase 10: Global Hotkeys — COMPLETE
- Phase 11 plan 06 added: Installer BUILD step was missing
- Phase 11 plan 07 added: One-liner install script for command-line users

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

### Blockers/Concerns

1. **Inno Setup installation** — Required to build installer; winget can install it
2. **Windows Sandbox testing** — Requires Windows Pro/Enterprise; manual process
3. **GitHub Releases** — One-liner install requires artifacts uploaded to Releases

## Session Continuity

Last session: 2026-01-31
Stopped at: Added 11-07-PLAN.md for one-liner install script
Resume file: None
Next action: Complete 11-05 (docs), then execute 11-06 (build + test), then 11-07 (one-liner)

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-31 — Added 11-07-PLAN.md for one-liner install script*
