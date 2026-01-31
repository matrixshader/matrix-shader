# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Instant startup with full PowerShell feature parity
**Current focus:** Phase 10.5 - Global Hotkeys (CRITICAL: missing feature parity)

## Current Position

Milestone: v1.0 INCOMPLETE (gaps found + missing feature)
Phase: 10.5 - Global Hotkeys (Plan 02 complete, 3 remaining)
Status: In Progress
Last activity: 2026-01-31 — Completed 10.5-02-PLAN.md (hotkey project infrastructure)

Progress: [##############################..] 41 plans complete, 8 plans queued

## Phase 10.5 Plan Summary

**5 plans in 3 waves:**

| Wave | Plan | Objective | Status |
|------|------|-----------|--------|
| 1 | 10.5-01 | Hotkey infrastructure (P/Invoke, models, config) | COMPLETE |
| 1 | 10.5-02 | Registration service with message pump | COMPLETE |
| 2 | 10.5-03 | Redpill integration | Queued |
| 2 | 10.5-04 | Bluepill integration | Queued |
| 3 | 10.5-05 | Testing and polish | Queued |

**Key Files Created (10.5-01):**
- HotkeyApi.cs (P/Invoke declarations)
- HotkeyAction.cs, HotkeyBinding.cs, HotkeyConfig.cs (models)
- IHotkeyConfigService.cs, HotkeyConfigService.cs (persistence)
- MatrixJsonContext.cs (updated with hotkey types)

**Key Files Created (10.5-02):**
- MatrixShader.Hotkeys.csproj (new project with AOT enabled)
- HotkeyWindow.cs (message-only window for WM_HOTKEY)
- HotkeyManager.cs (registration lifecycle with conflict tracking)
- SingleInstance.cs (Global\\ mutex enforcement)

## Phase 11 Plan Summary

**5 plans in 3 waves:**

| Wave | Plan | Objective | Gaps Addressed |
|------|------|-----------|----------------|
| 1 | 11-01 | Path resolution architecture | GAP-E03, E04, E12 (Critical) |
| 1 | 11-02 | Installer completeness | GAP-E01, E02, E14 (Critical) |
| 2 | 11-03 | Installer polish | GAP-E05, E10, E11 (Minor) |
| 2 | 11-04 | Runtime safety | GAP-E07, E13 (Important) |
| 3 | 11-05 | Documentation & validation | GAP-E08, E09 (Critical) |

## Milestone Summary

**v1.0 C# Rebuild (IN PROGRESS)**
- 12 phases, 49 plans total (41 complete, 8 queued)
- Phase 10.5 inserted for global hotkeys
- 14 gaps to close in Phase 11
- 9,047+ lines of C#

## Accumulated Context

### Roadmap Evolution

- Phase 8.1 inserted after Phase 8: Gap closure before AOT (URGENT)
- Phase 10.5 inserted after Phase 10: Global Hotkeys — MISSING FROM FEATURE PARITY (CRITICAL ERROR)
  - **Root cause:** Claude deferred hotkeys to v2 on Day 1 despite "feature parity" being core value
  - **Impact:** Installer (Phase 11) blocked until hotkeys implemented

### Decisions (Phase 10.5-01)

| Decision | Rationale | Source |
|----------|-----------|--------|
| LibraryImport over DllImport | AOT compatibility; RegisterClassExW exception for function pointers | 10.5-01 |
| MOD_NOREPEAT on all bindings | Prevents continuous firing when holding key | 10.5-01 |
| LocalAppData for hotkey config | Consistent with identity-registry.json location | 10.5-01 |

### Decisions (Phase 11)

| Decision | Rationale | Source |
|----------|-----------|--------|
| LocalAppData for user data | Standard Windows pattern, avoids Documents folder issues | CONTEXT.md |
| Inno Setup installer | Keep existing approach, mature tooling | CONTEXT.md |
| winget for WT install | Microsoft's official package manager | RESEARCH.md |
| Manual testing in Sandbox | Adequate for v1.0, automated testing deferred | CONTEXT.md |

### Blockers/Concerns

1. **Inno Setup installation** — Required to build installer; winget can install it
2. **Windows Sandbox testing** — Requires Windows Pro/Enterprise; manual process

## Session Continuity

Last session: 2026-01-31
Stopped at: Completed 10.5-02-PLAN.md
Resume file: None
Next action: Execute 10.5-03-PLAN.md (config loading and action dispatch)

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-31 — Plan 10.5-02 complete (hotkey project infrastructure)*
