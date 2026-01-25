# Roadmap: Matrix Terminal Shader C# Rebuild

## Overview

This roadmap ports the working PowerShell Matrix Terminal Shader (6,800+ lines) to native C# for instant startup (<500ms) and single-file deployment. The critical lesson from the previous failed C# attempt: core shader control MUST work before anything else. Phase order is strict - shader control, then window management, then TUI, then integration. MatrixLite fallback comes last, not first.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Shader Service Foundation** - HLSL file manipulation with #define injection
- [ ] **Phase 2: State Persistence** - JSON config and atomic file writes
- [ ] **Phase 3: Windows API Layer** - P/Invoke declarations and window enumeration
- [ ] **Phase 4: Window Identity Service** - 4-layer identity resolution with confidence scoring
- [ ] **Phase 5: Layout Service** - Pillars/Quads positioning with multi-monitor support
- [ ] **Phase 6: Control Panel TUI** - Redpill interactive control panel with Spectre.Console
- [ ] **Phase 7: Terminal Integration** - settings.json manipulation and profile management
- [ ] **Phase 8: CLI Applications** - bluepill launcher and wakeupneo wizard
- [ ] **Phase 9: Native AOT & Polish** - Single-file compilation and <500ms startup
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
**Plans**: TBD

Plans:
- [ ] 01-01: Shader configuration models and color presets
- [ ] 01-02: HLSL file parser and #define regex extraction
- [ ] 01-03: Shader file writer with #define injection and hot-reload trigger

### Phase 2: State Persistence
**Goal**: Configuration persists across sessions with corruption-safe file operations
**Depends on**: Phase 1 (ShaderConfig models)
**Requirements**: STATE-01, STATE-05
**Success Criteria** (what must be TRUE):
  1. User can close and reopen application with all shader settings preserved
  2. Application crash during save does not corrupt configuration files
  3. Invalid JSON in config file results in graceful fallback to defaults
**Plans**: TBD

Plans:
- [ ] 02-01: ConfigService with JSON serialization and source generators
- [ ] 02-02: Atomic file write implementation (temp + move pattern)

### Phase 3: Windows API Layer
**Goal**: All Windows API calls work correctly with proper marshalling
**Depends on**: Nothing (can parallel with Phase 1-2 but needed for Phase 4)
**Requirements**: WNDW-01, WNDW-06
**Success Criteria** (what must be TRUE):
  1. Application can enumerate all visible windows with correct handles
  2. Application can detect all connected monitors with correct bounds
  3. Application can reposition windows to exact pixel coordinates
**Plans**: TBD

Plans:
- [ ] 03-01: WindowsApi P/Invoke declarations (EnumWindows, SetWindowPos, GetMonitorInfo)
- [ ] 03-02: Window enumeration and monitor detection implementation
- [ ] 03-03: Window positioning with Windows 10/11 border compensation

### Phase 4: Window Identity Service
**Goal**: System reliably identifies Matrix shader windows across sessions
**Depends on**: Phase 3 (Windows API layer)
**Requirements**: WNDW-02, WNDW-08, STATE-02, STATE-03
**Success Criteria** (what must be TRUE):
  1. Application distinguishes Matrix windows from other Windows Terminal instances
  2. Application tracks window identity through minimize/restore/move operations
  3. Application assigns confidence scores to identity matches (high/medium/low)
  4. Window-to-shader mappings persist and restore correctly after restart
**Plans**: TBD

Plans:
- [ ] 04-01: 4-layer identity resolution (launch tracking, command line, title, UI Automation)
- [ ] 04-02: Confidence scoring system with fallback hierarchy
- [ ] 04-03: Identity registry persistence and restoration

### Phase 5: Layout Service
**Goal**: Windows position automatically in organized layouts across monitors
**Depends on**: Phase 4 (window identity)
**Requirements**: WNDW-03, WNDW-04, WNDW-05, WNDW-07, STATE-04
**Success Criteria** (what must be TRUE):
  1. User can cycle through Pillars/Quads/Auto layout modes with Shift+L
  2. Windows distribute evenly across all connected monitors
  3. Gap size between windows is configurable and persists
  4. Layout preferences persist across application restarts
**Plans**: TBD

Plans:
- [ ] 05-01: Pillars layout algorithm (side-by-side columns)
- [ ] 05-02: Quads layout algorithm (2x2 grid per monitor)
- [ ] 05-03: Multi-monitor distribution with gap configuration

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
**Plans**: TBD

Plans:
- [ ] 06-01: Spectre.Console rendering layer (tables, colors, swatches)
- [ ] 06-02: Keyboard input handling with Console.ReadKey loop
- [ ] 06-03: Tab management and dirty state tracking
- [ ] 06-04: Main control loop integrating all services

### Phase 7: Terminal Integration
**Goal**: Application manages Windows Terminal configuration
**Depends on**: Phase 6 (control panel exists)
**Requirements**: TERM-01, TERM-02, TERM-03, TERM-04
**Success Criteria** (what must be TRUE):
  1. Application can read and parse Windows Terminal settings.json
  2. Application can create Matrix-1 through Matrix-8 profiles
  3. Pixel shader paths are set correctly in profile configuration
  4. Diagnostic logging activates with MATRIX_DEBUG=1 environment variable
**Plans**: TBD

Plans:
- [ ] 07-01: TerminalSettingsService for settings.json read/write
- [ ] 07-02: Profile creation and shader path configuration
- [ ] 07-03: Diagnostic logging infrastructure

### Phase 8: CLI Applications
**Goal**: All three executables work as standalone tools
**Depends on**: Phase 6, Phase 7 (TUI and terminal integration)
**Requirements**: CLI-02, CLI-03, UX-02
**Success Criteria** (what must be TRUE):
  1. bluepill.exe restores previous session state and exits
  2. wakeupneo.exe provides Blue Pill (simple) and Red Pill (advanced) setup paths
  3. All executables can be invoked from any directory
**Plans**: TBD

Plans:
- [ ] 08-01: bluepill.exe quick session restore
- [ ] 08-02: wakeupneo.exe setup wizard with Blue/Red Pill paths
- [ ] 08-03: Entry point consolidation and shared bootstrap

### Phase 9: Native AOT & Polish
**Goal**: Single-file executables with instant startup
**Depends on**: Phase 8 (all CLIs complete)
**Requirements**: CLI-04, CLI-05
**Success Criteria** (what must be TRUE):
  1. All three executables compile to single-file Native AOT binaries
  2. Startup time is under 500ms (verified in Windows Sandbox)
  3. No runtime installation required on target machine
  4. Executables work in fresh Windows Sandbox environment
**Plans**: TBD

Plans:
- [ ] 09-01: Native AOT configuration and trim warnings resolution
- [ ] 09-02: Clean environment testing in Windows Sandbox
- [ ] 09-03: Performance profiling and startup optimization

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
| 1. Shader Service Foundation | 0/3 | Not started | - |
| 2. State Persistence | 0/2 | Not started | - |
| 3. Windows API Layer | 0/3 | Not started | - |
| 4. Window Identity Service | 0/3 | Not started | - |
| 5. Layout Service | 0/3 | Not started | - |
| 6. Control Panel TUI | 0/4 | Not started | - |
| 7. Terminal Integration | 0/3 | Not started | - |
| 8. CLI Applications | 0/3 | Not started | - |
| 9. Native AOT & Polish | 0/3 | Not started | - |
| 10. MatrixLite Fallback | 0/3 | Not started | - |

---
*Roadmap created: 2026-01-25*
*Total requirements: 38 | Phases: 10 | Depth: comprehensive*
