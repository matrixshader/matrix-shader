# Roadmap: Matrix Terminal Shader C# Rebuild

## Overview

This roadmap ports the working PowerShell Matrix Terminal Shader (6,800+ lines) to native C# for instant startup (<500ms) and single-file deployment.

**STATUS: v1.0 INCOMPLETE** — Critical gaps found in installer and end-to-end validation. Phase 11 added to address.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Shader Service Foundation** - HLSL file manipulation with #define injection
- [x] **Phase 2: State Persistence** - JSON config and atomic file writes
- [x] **Phase 3: Windows API Layer** - P/Invoke declarations and window enumeration
- [x] **Phase 4: Window Identity Service** - 4-layer identity resolution with confidence scoring
- [x] **Phase 5: Layout Service** - Pillars/Quads positioning with multi-monitor support
- [x] **Phase 6: Control Panel TUI** - Redpill interactive control panel with ANSI rendering
- [x] **Phase 7: Terminal Integration** - settings.json manipulation and profile management
- [x] **Phase 8: CLI Applications** - bluepill launcher and wakeupneo wizard
- [x] **Phase 8.1: Gap Closure** - INSERTED: Fix implementation gaps before AOT
- [x] **Phase 9: Native AOT & Polish** - Single-file compilation (INCOMPLETE: installer not built)
- [x] **Phase 10: MatrixLite Fallback** - Text-based fallback for non-Windows-Terminal
- [ ] **Phase 11: Installer & E2E Validation** - Build installer, fix paths, validate on clean system

## Phase Details

### Phase 11: Installer & End-to-End Validation

**Goal**: User can download installer, run it, and have working Matrix shader system on fresh Windows
**Depends on**: Phase 10 (all executables exist)
**Requirements**: E2E-01 through E2E-07 (see REQUIREMENTS.md)

**Gaps to Close** (from GAP-ANALYSIS.md):

| Gap | Severity | Issue |
|-----|----------|-------|
| GAP-E01 | Critical | matrixlite.exe not in installer |
| GAP-E02 | Important | Monitor exe name mismatch |
| GAP-E03 | Important | Shader path priority issues |
| GAP-E04 | Important | Hardcoded dev path in ConfigService |
| GAP-E06 | Important | No WT version/shader support check |
| GAP-E07 | Important | No profile creation verification |
| GAP-E08 | Important | README has wrong install instructions |
| GAP-E09 | Critical | No clean-system installer validation |
| GAP-E10 | Minor | PATH change requires restart notification |
| GAP-E11 | Minor | No uninstall cleanup for user data |
| GAP-E12 | Critical | Profiles point to wrong shader location |
| GAP-E13 | Important | Redpill profile command path issue |
| GAP-E14 | Minor | Confusing self-contained flag in build |

**Success Criteria** (what must be TRUE):
1. Installer builds successfully with all 5 executables (including matrixlite.exe)
2. Shader paths resolve correctly from installed location
3. Fresh Windows Sandbox install completes without errors
4. wakeupneo.exe creates profiles pointing to correct shader paths
5. bluepill.exe finds and starts matrix-monitor correctly
6. matrixlite.exe works standalone in non-WT terminal
7. User documentation is accurate and helpful

**Plans**: TBD after discussion

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Shader Service Foundation | 3/3 | Complete | 2026-01-25 |
| 2. State Persistence | 2/2 | Complete | 2026-01-26 |
| 3. Windows API Layer | 3/3 | Complete | 2026-01-26 |
| 4. Window Identity Service | 3/3 | Complete | 2026-01-27 |
| 5. Layout Service | 3/3 | Complete | 2026-01-27 |
| 6. Control Panel TUI | 4/4 | Complete | 2026-01-28 |
| 7. Terminal Integration | 4/4 | Complete | 2026-01-29 |
| 8. CLI Applications | 3/3 | Complete | 2026-01-29 |
| 8.1 Gap Closure (INSERTED) | 5/5 | Complete | 2026-01-29 |
| 9. Native AOT & Polish | 5/5 | INCOMPLETE | — |
| 10. MatrixLite Fallback | 4/4 | Complete | 2026-01-30 |
| 11. Installer & E2E Validation | 0/? | Discussion | — |

---
*Roadmap created: 2026-01-25*
*Updated: 2026-01-30 — Phase 11 added after discovering installer/E2E gaps*
