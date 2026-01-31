# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Instant startup with full PowerShell feature parity
**Current focus:** Phase 11 - Installer & E2E Validation (COMPLETE)

## Current Position

Milestone: v1.0 COMPLETE (all code, installer, and scripts done)
Phase: 11 - Installer & E2E Validation (COMPLETE)
Status: All 7 plans complete across 5 waves
Last activity: 2026-01-31 — Completed 11-07 (one-liner install script)

Progress: [##################################################] 51 plans complete

## Phase 11 Plan Summary (COMPLETE)

**7 plans in 5 waves:**

| Wave | Plan | Objective | Status |
|------|------|-----------|--------|
| 1 | 11-01 | Path resolution architecture | COMPLETE |
| 1 | 11-02 | Installer completeness | COMPLETE |
| 2 | 11-03 | Installer polish | COMPLETE |
| 2 | 11-04 | Runtime safety | COMPLETE |
| 3 | 11-05 | Documentation & validation | COMPLETE |
| 4 | 11-06 | BUILD installer and E2E test | COMPLETE |
| 5 | 11-07 | One-liner install script | COMPLETE |

**Deliverables:**
- GUI installer: `installer/output/MatrixShaderSetup.exe` (55MB)
- One-liner install: `irm https://matrixshader.com/install.ps1 | iex`
- Testing guide: `installer/TESTING.md`

## Accumulated Context

### Roadmap Evolution

- Phase 8.1 inserted after Phase 8: Gap closure before AOT (URGENT)
- Phase 10.5 inserted after Phase 10: Global Hotkeys - COMPLETE
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
| GitHub Releases for distribution | Standard pattern, works with one-liner script | 11-07 |

### Blockers/Concerns

1. **GitHub Releases setup required** - Need to upload MatrixShader.zip to Releases for one-liner to work
2. **Domain redirect** - Need matrixshader.com/install.ps1 to redirect to raw GitHub URL
3. **Windows Sandbox testing** - Manual E2E testing recommended before release

## Session Continuity

Last session: 2026-01-31
Stopped at: Completed 11-07-PLAN.md (one-liner install script)
Resume file: None
Next action: Upload release artifacts to GitHub, then test in Windows Sandbox

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-31 - Phase 11 complete (all 7 plans done)*
