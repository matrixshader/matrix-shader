# Roadmap: Matrix Terminal Shader C# Rebuild

## Overview

This roadmap ports the working PowerShell Matrix Terminal Shader (6,800+ lines) to native C# for instant startup (<500ms) and single-file deployment. The critical lesson from the previous failed C# attempt: core shader control MUST work before anything else. Phase order is strict - shader control, then window management, then TUI, then integration. MatrixLite fallback comes last, not first.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Shader Service Foundation** - HLSL file manipulation with #define injection
- [x] **Phase 2: State Persistence** - JSON config and atomic file writes
- [x] **Phase 3: Windows API Layer** - P/Invoke declarations and window enumeration
- [x] **Phase 4: Window Identity Service** - 4-layer identity resolution with confidence scoring
- [x] **Phase 5: Layout Service** - Pillars/Quads positioning with multi-monitor support
- [x] **Phase 6: Control Panel TUI** - Redpill interactive control panel with ANSI rendering
- [x] **Phase 7: Terminal Integration** - settings.json manipulation and profile management
- [x] **Phase 8: CLI Applications** - bluepill launcher and wakeupneo wizard
- [x] **Phase 8.1: Gap Closure** - INSERTED: Fix implementation gaps before AOT (20 gaps: 4 critical, 10 important, 6 minor)
- [x] **Phase 9: Native AOT & Polish** - Single-file compilation and Native AOT deployment
- [ ] **Phase 10: MatrixLite Fallback** - Text-based fallback for non-Windows-Terminal

## Phase Details

### Phase 1: Shader Service Foundation
**Goal**: Core shader parameter manipulation works - the heart of the application
**Depends on**: Nothing (CRITICAL: must be first, previous failure skipped this)
**Requirements**: SHDR-01, SHDR-02, SHDR-03, SHDR-04, SHDR-05, SHDR-06, SHDR-07, SHDR-08, SHDR-09, SHDR-10
**Success Criteria** (what must be TRUE):
  1. User can modify RGB color values and see shader change within 500ms
  2. User can apply any of 6 color presets and shader reflects the change
  3. User can adjust speed/glow/width/trail/density and shader reflects changes
  4. User can toggle each parallax layer independently
  5. Shader file contains correct #define statements matching parameter values
**Plans**: 3 plans in 2 waves

Plans:
- [x] 01-01-PLAN.md — Fix ShaderConfig validation ranges to match PowerShell (Wave 1)
- [x] 01-02-PLAN.md — Fix ShaderService regex patterns for HLSL parsing (Wave 2)
- [x] 01-03-PLAN.md — Fix ShaderService writing and add CreateShader method (Wave 2)

### Phase 2: State Persistence
**Goal**: Configuration persists across sessions with corruption-safe file operations
**Depends on**: Phase 1 (ShaderConfig models)
**Requirements**: STATE-01, STATE-05
**Success Criteria** (what must be TRUE):
  1. User can close and reopen application with all shader settings preserved
  2. Application crash during save does not corrupt configuration files
  3. Invalid JSON in config file results in graceful fallback to defaults
**Plans**: 2 plans in 2 waves

Plans:
- [x] 02-01-PLAN.md — Create MatrixJsonContext with source generators for AOT (Wave 1)
- [x] 02-02-PLAN.md — Update ConfigService to use source-generated context (Wave 2)

### Phase 3: Windows API Layer
**Goal**: All Windows API calls work correctly with proper marshalling
**Depends on**: Nothing (can parallel with Phase 1-2 but needed for Phase 4)
**Requirements**: WNDW-01, WNDW-06
**Success Criteria** (what must be TRUE):
  1. Application can enumerate all visible windows with correct handles
  2. Application can detect all connected monitors with correct bounds
  3. Application can reposition windows to exact pixel coordinates
**Plans**: 3 plans in 2 waves

Plans:
- [x] 03-01-PLAN.md — Add DWM P/Invoke declarations and BorderMargins model (Wave 1)
- [x] 03-02-PLAN.md — Window enumeration helpers and monitor sorting (Wave 2)
- [x] 03-03-PLAN.md — Window positioning with border compensation (Wave 2)

### Phase 4: Window Identity Service
**Goal**: System reliably identifies Matrix shader windows across sessions
**Depends on**: Phase 3 (Windows API layer)
**Requirements**: WNDW-02, WNDW-08, STATE-02, STATE-03
**Success Criteria** (what must be TRUE):
  1. Application distinguishes Matrix windows from other Windows Terminal instances
  2. Application tracks window identity through minimize/restore/move operations
  3. Application assigns confidence scores to identity matches (high/medium/low)
  4. Window-to-shader mappings persist and restore correctly after restart
**Plans**: 3 plans in 2 waves

Plans:
- [x] 04-01-PLAN.md — Identity models and confidence scoring (Wave 1)
- [x] 04-02-PLAN.md — Core 4-layer identity resolution with batch WMI and UI Automation (Wave 2)
- [x] 04-03-PLAN.md — Registry persistence with LocalAppData path and 24-hour cleanup (Wave 2)

### Phase 5: Layout Service
**Goal**: Windows position automatically in organized layouts across monitors
**Depends on**: Phase 4 (window identity)
**Requirements**: WNDW-03, WNDW-04, WNDW-05, WNDW-07, STATE-04
**Success Criteria** (what must be TRUE):
  1. User can cycle through Pillars/Quads/Auto layout modes with Shift+L
  2. Windows distribute evenly across all connected monitors
  3. Gap size between windows is configurable and persists
  4. Layout preferences persist across application restarts
**Plans**: 3 plans in 2 waves

Plans:
- [x] 05-01-PLAN.md — Gap adjustment and mode cycling with immediate persistence (Wave 1)
- [x] 05-02-PLAN.md — ApplyLayout with border compensation via PositionWindowExact (Wave 1)
- [x] 05-03-PLAN.md — Window slot persistence for layout restoration (Wave 2)

### Phase 6: Control Panel TUI
**Goal**: Interactive control panel matching PowerShell functionality
**Depends on**: Phase 1, Phase 4, Phase 5 (all services)
**Requirements**: CLI-01, UX-01, UX-03, UX-04, UX-05
**Success Criteria** (what must be TRUE):
  1. User can adjust all shader parameters via keyboard shortcuts matching PowerShell version
  2. User can switch between shader windows via Tab key with tabbed interface
  3. User sees dirty state indicator when changes are unsaved
  4. Changes auto-save when switching tabs (no lost work)
  5. Color swatches display for visual feedback on parameter changes
**Plans**: 4 plans in 3 waves

Plans:
- [x] 06-01-PLAN.md — TuiRenderer with pixel-perfect ANSI output (Wave 1)
- [x] 06-02-PLAN.md — KeyHandler with shift-key detection (Wave 1)
- [x] 06-03-PLAN.md — TabManager with auto-save and dirty tracking (Wave 2)
- [x] 06-04-PLAN.md — ControlPanel main loop integrating all services (Wave 3)

### Phase 7: Terminal Integration
**Goal**: Application manages Windows Terminal configuration
**Depends on**: Phase 6 (control panel exists)
**Requirements**: TERM-01, TERM-02, TERM-03, TERM-04
**Success Criteria** (what must be TRUE):
  1. Application can read and parse Windows Terminal settings.json
  2. Application can create Matrix-1 through Matrix-8 profiles
  3. Pixel shader paths are set correctly in profile configuration
  4. Diagnostic logging activates with MATRIX_DEBUG=1 environment variable
**Plans**: 4 plans in 3 waves

Plans:
- [x] 07-01-PLAN.md — Terminal models (TerminalProfile, TerminalSettings) with AOT serialization (Wave 1)
- [x] 07-02-PLAN.md — TerminalSettingsService with three-layer error recovery (Wave 2)
- [x] 07-03-PLAN.md — DiagnosticLogger for MATRIX_DEBUG=1 and --debug flag (Wave 2)
- [x] 07-04-PLAN.md — Profile creation and shader path auto-update (Wave 3)

### Phase 8: CLI Applications
**Goal**: All three executables work as standalone tools
**Depends on**: Phase 6, Phase 7 (TUI and terminal integration)
**Requirements**: CLI-02, CLI-03, UX-02
**Success Criteria** (what must be TRUE):
  1. bluepill.exe restores previous session state and exits
  2. wakeupneo.exe provides Blue Pill (simple) and Red Pill (advanced) setup paths
  3. All executables can be invoked from any directory
**Plans**: 3 plans in 2 waves

Plans:
- [x] 08-01-PLAN.md — Shared CLI bootstrap infrastructure (CliBootstrap, MatrixQuotes, ConsoleHelper) (Wave 1)
- [x] 08-02-PLAN.md — bluepill.exe session restore with typewriter effect (Wave 2)
- [x] 08-03-PLAN.md — wakeupneo.exe setup wizard with Blue/Red Pill paths (Wave 2)

### Phase 8.1: Gap Closure (INSERTED)
**Goal**: Fix implementation gaps identified between C# port and PowerShell reference
**Depends on**: Phase 8 (all CLIs complete)
**Requirements**: Derived from GAP-ANALYSIS.md (20 gaps total)
**Success Criteria** (what must be TRUE):
  1. Redpill has full CliBootstrap integration (--help, --debug, quotes)
  2. All TODO features implemented (Launch, Snapback, Glitch, Monitor, Primary)
  3. No unused packages in any csproj (Spectre.Console removed)
  4. REQUIREMENTS.md accurately reflects implementation status
  5. Transparency/opacity applies to Windows Terminal settings.json
  6. Tab colors sync to shader RGB values
  7. All P/Invoke uses LibraryImport (AOT ready)
  8. All serialized types registered in MatrixJsonContext
**Plans**: 5 plans in 2 waves

Plans:
- [x] 08.1-01-PLAN.md — Critical gaps: CliBootstrap integration, Spectre.Console removal, REQUIREMENTS.md update (Wave 1)
- [x] 08.1-02-PLAN.md — TODO features: Launch, Snapback, Glitch, Monitor, Primary actions (Wave 1)
- [x] 08.1-03-PLAN.md — Terminal integration: Transparency/opacity to settings.json, tab color sync (Wave 2)
- [x] 08.1-04-PLAN.md — AOT preparation: LibraryImport conversion, JSON context types (Wave 1)
- [x] 08.1-05-PLAN.md — Consistency fixes: GetActiveSlots, dev paths, Monitor service (Wave 2)

### Phase 9: Native AOT & Polish
**Goal**: Single-file executables with instant startup
**Depends on**: Phase 8.1 (gap closure complete)
**Requirements**: CLI-04, CLI-05
**Success Criteria** (what must be TRUE):
  1. All three executables compile to single-file Native AOT binaries
  2. Startup time is under 500ms (verified in Windows Sandbox)
  3. No runtime installation required on target machine
  4. Executables work in fresh Windows Sandbox environment
**Plans**: 5 plans in 3 waves

Plans:
- [x] 09-01-PLAN.md — AOT csproj configuration with PublishAot (Wave 1)
- [x] 09-02-PLAN.md — Matrix splash animation and error handler in Core (Wave 1)
- [x] 09-03-PLAN.md — Integrate splash into all CLI entry points (Wave 2)
- [x] 09-04-PLAN.md — Inno Setup installer with PATH integration (Wave 2)
- [x] 09-05-PLAN.md — Windows Sandbox clean-room validation (Wave 3)

### Phase 10: MatrixLite Fallback
**Goal**: Text-based Matrix rain for non-Windows-Terminal environments
**Depends on**: Phase 9 (CRITICAL: only after core is complete and tested)
**Requirements**: LITE-01, LITE-02, LITE-03, LITE-04
**Success Criteria** (what must be TRUE):
  1. MatrixLite renders text-based Matrix rain in standard console
  2. Katakana character set matches movie-accurate appearance
  3. All 6 color presets work via ANSI color codes
  4. Application gracefully falls back to MatrixLite when GPU shaders unavailable
**Plans**: TBD

Plans:
- [ ] 10-01: Text-based Matrix rain renderer
- [ ] 10-02: Katakana character set and ANSI color support
- [ ] 10-03: Environment detection and graceful degradation

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10

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
| 9. Native AOT & Polish | 5/5 | Complete | 2026-01-30 |
| 10. MatrixLite Fallback | 0/3 | Not started | - |

---
*Roadmap created: 2026-01-25*
*Total requirements: 38 | Phases: 10 | Depth: comprehensive*
