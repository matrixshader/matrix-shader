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
- [x] **Phase 10.5: Global Hotkeys** - INSERTED: Port matrix_hotkeys.ps1 to C#
- [x] **Phase 11: Installer & E2E Validation** - Build installer, fix paths, validate on clean system
- [ ] **Phase 12: E2E Gap Closure** - Fix all 18 bugs found in sandbox testing

## Phase Details

### Phase 10.5: Global Hotkeys (INSERTED)

**Goal:** Port matrix_hotkeys.ps1 to C# — system-wide hotkeys work when Matrix windows are minimized
**Depends on:** Phase 10 (all CLI applications exist)
**Why INSERTED:** MISSING FROM FEATURE PARITY — PowerShell version has working hotkeys, C# port deferred them to v2 in error

**Hotkeys to implement (12 actions with Ctrl+Shift modifier):**
- Swap focused window with left/right neighbor
- Cycle layout mode (Pillars/Quads/Auto)
- Toggle background transparency
- Decrease/Increase opacity (5% steps)
- Cycle through shader library
- Adjust rain speed (up/down)
- Toggle FAR/MID/NEAR layers

**Technical approach:**
- New project: `MatrixShader.Hotkeys` (background process)
- P/Invoke: `RegisterHotKey`, `UnregisterHotKey`, message pump
- Single-instance via named mutex
- Auto-exit when no Matrix windows exist
- Toast notification for conflicts
- Redpill config screen for customization

**Plans:** 5 plans in 3 waves

Plans:
- [x] 10.5-01-PLAN.md — Core infrastructure (P/Invoke, models, config service)
- [x] 10.5-02-PLAN.md — Hotkey service (project, window, manager, single-instance)
- [x] 10.5-03-PLAN.md — Hotkey actions (12 handlers, toast notifications)
- [x] 10.5-04-PLAN.md — Integration (Program.cs, monitoring, entry point launches)
- [x] 10.5-05-PLAN.md — Redpill config UI (hotkey configuration screen)

**Wave Structure:**
- Wave 1: 10.5-01, 10.5-02 (parallel - independent foundations)
- Wave 2: 10.5-03, 10.5-04 (depends on 01/02 - wiring and integration)
- Wave 3: 10.5-05 (depends on all - UI needs working hotkeys)

**Success Criteria** (what must be TRUE):
1. matrix-hotkeys.exe registers 12 global hotkeys with Ctrl+Shift modifier
2. Single-instance prevents duplicate hotkey processes
3. Background process auto-exits when no Matrix windows exist
4. Toast notification shows when hotkeys conflict
5. Hotkey actions control layout, shaders, and window swapping
6. bluepill/redpill/wakeupneo launch hotkey process automatically
7. Redpill --hotkeys opens configuration screen
8. Users can disable, remap, and reset hotkeys

---

### Phase 11: Installer & End-to-End Validation

**Goal**: User can download installer, run it, and have working Matrix shader system on fresh Windows
**Depends on**: Phase 10.5 (all executables including hotkeys)
**Requirements**: E2E-01 through E2E-07, PATH-01 through PATH-04, FRX-01 through FRX-03, BUILD-01 through BUILD-03

**Gaps to Close** (from GAP-ANALYSIS.md):

| Gap | Severity | Issue | Plan |
|-----|----------|-------|------|
| GAP-E01 | Critical | matrixlite.exe not in installer | 11-02 |
| GAP-E02 | Important | Monitor exe name mismatch | 11-02 |
| GAP-E03 | Important | Shader path priority issues | 11-01 |
| GAP-E04 | Important | Hardcoded dev path in ConfigService | 11-01 |
| GAP-E05 | Minor | Identity registry cleanup | 11-03 |
| GAP-E07 | Important | No profile creation verification | 11-04 |
| GAP-E08 | Important | README has wrong install instructions | 11-05 |
| GAP-E09 | Critical | No clean-system installer validation | 11-05, 11-06 |
| GAP-E10 | Minor | PATH change requires restart notification | 11-03 |
| GAP-E11 | Minor | No uninstall cleanup for user data | 11-03 |
| GAP-E12 | Critical | Profiles point to wrong shader location | 11-01 |
| GAP-E13 | Important | Redpill profile command path issue | 11-04 |
| GAP-E14 | Minor | Confusing self-contained flag in build | 11-02 |

**Plans:** 7 plans in 5 waves

Plans:
- [x] 11-01-PLAN.md — Path resolution architecture (GAP-E03, E04, E12)
- [x] 11-02-PLAN.md — Installer completeness (GAP-E01, E02, E14)
- [x] 11-03-PLAN.md — Installer polish (GAP-E05, E10, E11)
- [x] 11-04-PLAN.md — Runtime safety (GAP-E07, E13)
- [x] 11-05-PLAN.md — Documentation & validation (GAP-E08, E09)
- [x] 11-06-PLAN.md — BUILD installer and E2E test (GAP-E09 closure)
- [x] 11-07-PLAN.md — One-liner install script (alternative to GUI installer)

**Wave Structure:**
- Wave 1: 11-01, 11-02 (parallel - independent fixes)
- Wave 2: 11-03, 11-04 (depends on 11-01/11-02)
- Wave 3: 11-05 (documentation - can run while building)
- Wave 4: 11-06 (BUILD + TEST - requires all code changes complete)
- Wave 5: 11-07 (one-liner install - requires built artifacts for GitHub Releases)

**CRITICAL NOTE:** Plans 11-01 through 11-04 updated CODE and SCRIPTS. Plan 11-06 actually BUILDS the installer. Plan 11-07 provides an alternative one-liner install method.

**Success Criteria** (what must be TRUE):
1. Installer builds successfully with all 6 executables (including matrixlite.exe, matrix-hotkeys.exe)
2. Shader paths resolve correctly from installed location
3. Fresh Windows Sandbox install completes without errors
4. wakeupneo.exe creates profiles pointing to correct shader paths
5. bluepill.exe finds and starts matrix-monitor correctly
6. matrixlite.exe works standalone in non-WT terminal
7. User documentation is accurate and helpful
8. One-liner install (`irm matrixshader.com/install.ps1 | iex`) works for admin and non-admin users

---

### Phase 12: E2E Gap Closure

**Goal:** Fix all 18 bugs discovered during Windows Sandbox E2E testing
**Depends on:** Phase 11 (installer built and tested)
**Source:** `installer/TESTING.md` test session 2026-01-31

**Bugs to Fix (18 total):**

| Severity | Count | IDs |
|----------|-------|-----|
| Critical | 5 | BUG-SHADER01, BUG-ML01, BUG-WT01, BUG-UNINST02, GAP-E03c |
| High | 6 | BUG-ML02, BUG-ML04, BUG-WT02, BUG-WT03, BUG-WT04, BUG-UNINST01 |
| Medium | 7 | BUG-ML03, BUG-ML05, BUG-ML06, GAP-E03a, GAP-E03b, BUG-FRX01, GAP-INST01 |

**Plans:** 7 plans in 3 waves

Plans:
- [ ] 12-01-PLAN.md — Critical shader and WT detection fixes (BUG-SHADER01, BUG-WT01/02/03/04)
- [ ] 12-02-PLAN.md — MatrixLite ANSI and color fixes (BUG-ML01, BUG-ML05, BUG-ML06)
- [ ] 12-03-PLAN.md — MatrixLite UX and intro flow (BUG-ML02/03/04, pill choice)
- [ ] 12-04-PLAN.md — WT installation flow with fallbacks (GAP-E03a/b/c)
- [ ] 12-05-PLAN.md — Installer uninstall and re-run fixes (BUG-UNINST01/02, GAP-INST01)
- [ ] 12-06-PLAN.md — First-run detection fix (BUG-FRX01)
- [ ] 12-07-PLAN.md — Build installer and full E2E verification

**Wave Structure:**
- Wave 1: 12-01, 12-02 (parallel - independent fixes)
- Wave 2: 12-03, 12-04, 12-05, 12-06 (parallel - dependent on Wave 1 for some)
- Wave 3: 12-07 (BUILD + E2E TEST - requires all fixes complete)

**Bug-to-Plan Mapping:**

| Bug ID | Description | Plan |
|--------|-------------|------|
| BUG-SHADER01 | Regex `$1` replacement bug | 12-01 |
| BUG-WT01 | WT detection only checks Store path | 12-01 |
| BUG-WT02 | Apps fall back to Lite incorrectly | 12-01 |
| BUG-WT03 | Hardcoded wt.exe path | 12-01 |
| BUG-WT04 | Wrong settings.json for portable WT | 12-01 |
| BUG-ML01 | Missing VT Processing P/Invoke | 12-02 |
| BUG-ML05 | Blue instead of green color | 12-02 |
| BUG-ML06 | White characters in trail | 12-02 |
| BUG-ML02 | Terminal blocked (no background mode) | 12-03 |
| BUG-ML03 | Missing bluepill/background option | 12-03 |
| BUG-ML04 | Menu broken | 12-03 |
| GAP-E03a | No winget detection | 12-04 |
| GAP-E03b | No download fallback | 12-04 |
| GAP-E03c | Dead end when Store fails | 12-04 |
| BUG-UNINST01 | Useless uninstall error | 12-05 |
| BUG-UNINST02 | Files left in Program Files | 12-05 |
| GAP-INST01 | Blind overwrite on re-run | 12-05 |
| BUG-FRX01 | False "previous sessions" | 12-06 |

**Success Criteria** (what must be TRUE):
1. All 18 bugs from TESTING.md are fixed
2. Local testing passes before sandbox rebuild
3. Rebuilt installer passes full E2E test in Windows Sandbox
4. matrixlite displays green in cmd.exe (not raw ANSI codes)
5. WT detection works for Store, Scoop, Chocolatey, and portable installs
6. Uninstaller removes ALL files from Program Files
7. No dead ends in WT installation flow

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
| 10.5 Global Hotkeys (INSERTED) | 5/5 | Complete | 2026-01-31 |
| 11. Installer & E2E Validation | 7/7 | Complete | 2026-01-31 |
| 12. E2E Gap Closure | 0/7 | Not Started | — |

---
*Roadmap created: 2026-01-25*
*Updated: 2026-01-31 — Phase 12 plans created (7 plans in 3 waves)*
