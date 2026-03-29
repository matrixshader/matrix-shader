# Roadmap: Custom Shader Preset System

## Overview

Three-phase delivery of a persistent save/load system for custom shader configurations. Phase 1 builds the standalone preset_service.py module with all CRUD operations and storage logic. Phase 2 wires that service into the redpill TUI so users can interactively save, load, browse, and delete presets. Phase 3 extends presets to CLI tools (construct --preset, bluepill --preset) for scriptable and session-restore use cases.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Preset Service** - Standalone Python module with save/load/list/delete and persistent JSON storage
- [x] **Phase 2: TUI Integration** - Presets menu in redpill TUI with interactive save, load, browse, and delete
- [ ] **Phase 3: CLI Integration** - construct --preset and bluepill --preset flags for scriptable preset usage

## Phase Details

### Phase 1: Preset Service
**Goal**: A tested, importable preset_service.py that any caller can use to persist and retrieve shader configurations
**Depends on**: Nothing (first phase)
**Requirements**: STOR-01, STOR-02, STOR-03, STOR-04, INTG-01
**Success Criteria** (what must be TRUE):
  1. Calling save() with a name and 11 shader parameters creates a JSON file in ~/.config/matrix-shader/presets/
  2. Calling load() with a preset name returns all 11 parameters exactly as saved
  3. Calling list_presets() returns all saved presets with name, color info, and save date
  4. Calling delete() removes the preset file, and it no longer appears in list
  5. Presets saved by one process are immediately visible to another process (filesystem is the source of truth)
**Plans:** 1 plan

Plans:
- [x] 01-01-PLAN.md — TDD: Preset service CRUD with JSON file storage

### Phase 2: TUI Integration
**Goal**: Red Pill users can manage presets entirely from the redpill TUI without touching the filesystem
**Depends on**: Phase 1
**Requirements**: SAVE-01, SAVE-02, SAVE-03, SAVE-04, LOAD-01, LOAD-02, LOAD-03, LIST-01, LIST-02, DEL-01, DEL-02, INTG-02
**Success Criteria** (what must be TRUE):
  1. User navigates to Presets menu in redpill TUI and sees save, load, list, and delete options
  2. User saves current shader config with a name, and the preset appears in the list immediately
  3. User loads a preset and the terminal shader visually changes to the preset colors within 1 second (D-Bus reload fires)
  4. User deletes a preset with confirmation prompt, and it disappears from the list
  5. Overwriting an existing preset name shows a confirmation dialog before replacing
**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — PresetMenuScreen with list, save, load, delete flows
- [x] 02-02-PLAN.md — Wire presets into TUI (key binding, footer, help) + human verify

### Phase 3: CLI Integration
**Goal**: Presets are usable from construct and bluepill without opening the TUI
**Depends on**: Phase 2
**Requirements**: LOAD-04, LIST-03, INTG-03, INTG-04
**Success Criteria** (what must be TRUE):
  1. Running construct --preset <name> spawns a new Matrix window using that preset's shader config
  2. Running bluepill --preset <name> restores the session using the named preset instead of state.json
  3. Invalid preset names produce a clear error message listing available presets
**Plans:** 1 plan

Plans:
- [ ] 03-01-PLAN.md — construct --preset and bluepill --preset flags for scriptable preset usage

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Preset Service | 1/1 | Complete | 2026-03-29 |
| 2. TUI Integration | 2/2 | Complete | 2026-03-29 |
| 3. CLI Integration | 0/1 | Not started | - |
