# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Instant startup with full PowerShell feature parity
**Current focus:** Phase 11 - Installer & E2E Validation (Phase 10.5 complete!)

## Current Position

Milestone: v1.0 INCOMPLETE (gaps found + missing feature)
Phase: 11 - Installer & E2E Validation (IN PROGRESS)
Status: Wave 1 complete (11-01, 11-02)
Last activity: 2026-01-31 — Completed 11-02-PLAN.md (installer completeness)

Progress: [######################################] 46 plans complete, 3 plans queued

## Phase 10.5 Plan Summary (COMPLETE)

**5 plans in 3 waves:**

| Wave | Plan | Objective | Status |
|------|------|-----------|--------|
| 1 | 10.5-01 | Hotkey infrastructure (P/Invoke, models, config) | COMPLETE |
| 1 | 10.5-02 | Registration service with message pump | COMPLETE |
| 2 | 10.5-03 | Hotkey actions and toast notifications | COMPLETE |
| 2 | 10.5-04 | Redpill integration | COMPLETE |
| 3 | 10.5-05 | Hotkey configuration screen | COMPLETE |

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

**Key Files Created (10.5-03):**
- HotkeyActions.cs (12 action handlers with service integration)
- ToastNotifications.cs (conflict warnings via Windows toast)
- TerminalProfile.cs (added UseAcrylic property)

**Key Files Created (10.5-05):**
- HotkeyConfigScreen.cs (TUI for hotkey configuration)

## Phase 11 Plan Summary

**5 plans in 3 waves:**

| Wave | Plan | Objective | Gaps Addressed | Status |
|------|------|-----------|----------------|--------|
| 1 | 11-01 | Path resolution architecture | GAP-E03, E04, E12 (Critical) | COMPLETE |
| 1 | 11-02 | Installer completeness | GAP-E01, E02, E14 (Critical) | COMPLETE |
| 2 | 11-03 | Installer polish | GAP-E05, E10, E11 (Minor) | QUEUED |
| 2 | 11-04 | Runtime safety | GAP-E07, E13 (Important) | QUEUED |
| 3 | 11-05 | Documentation & validation | GAP-E08, E09 (Critical) | QUEUED |

## Milestone Summary

**v1.0 C# Rebuild (IN PROGRESS)**
- 12 phases, 49 plans total (44 complete, 5 queued)
- Phase 10.5 COMPLETE (global hotkeys feature parity achieved)
- 14 gaps to close in Phase 11
- 9,400+ lines of C#

## Accumulated Context

### Roadmap Evolution

- Phase 8.1 inserted after Phase 8: Gap closure before AOT (URGENT)
- Phase 10.5 inserted after Phase 10: Global Hotkeys — NOW COMPLETE
  - **Root cause:** Claude deferred hotkeys to v2 on Day 1 despite "feature parity" being core value
  - **Resolution:** 5-plan phase implemented all hotkey features

### Decisions (Phase 10.5-01)

| Decision | Rationale | Source |
|----------|-----------|--------|
| LibraryImport over DllImport | AOT compatibility; RegisterClassExW exception for function pointers | 10.5-01 |
| MOD_NOREPEAT on all bindings | Prevents continuous firing when holding key | 10.5-01 |
| LocalAppData for hotkey config | Consistent with identity-registry.json location | 10.5-01 |

### Decisions (Phase 10.5-03)

| Decision | Rationale | Source |
|----------|-----------|--------|
| Silent failure for all actions | Per CONTEXT.md - if action can't complete, do nothing | plan |
| Service injection for actions | Testability and separation of concerns | implementation |
| Toast limit 5 hotkeys | Avoid toast overflow, keep UI clean | implementation |

### Decisions (Phase 10.5-05)

| Decision | Rationale | Source |
|----------|-----------|--------|
| Cubase-style validation | Test RegisterHotKey/UnregisterHotKey to check availability | CONTEXT.md |

### Decisions (Phase 11)

| Decision | Rationale | Source |
|----------|-----------|--------|
| LocalAppData for user data | Standard Windows pattern, avoids Documents folder issues | CONTEXT.md |
| Inno Setup installer | Keep existing approach, mature tooling | CONTEXT.md |
| winget for WT install | Microsoft's official package manager | RESEARCH.md |
| Manual testing in Sandbox | Adequate for v1.0, automated testing deferred | CONTEXT.md |
| Explicit --self-contained true | Clearer than --no-self-contained:false, avoids confusion | 11-02 |
| Primary lookup matrix-monitor.exe | Matches installed name, legacy fallback for dev | 11-02 |

### Blockers/Concerns

1. **Inno Setup installation** — Required to build installer; winget can install it
2. **Windows Sandbox testing** — Requires Windows Pro/Enterprise; manual process

## Session Continuity

Last session: 2026-01-31
Stopped at: Completed 11-02-PLAN.md (installer completeness)
Resume file: None
Next action: Execute 11-03-PLAN.md (Installer polish)

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-31 — Completed 11-02 (Wave 1 of Phase 11 complete)*
