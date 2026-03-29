# Requirements: Custom Shader Preset System

**Defined:** 2026-03-28
**Core Value:** Custom shader configs must never be lost

## v1 Requirements

### Storage

- [x] **STOR-01**: Presets stored as individual JSON files in ~/.config/matrix-shader/presets/
- [x] **STOR-02**: Each preset file contains all 11 shader parameters
- [x] **STOR-03**: Preset filename derived from sanitized preset name (spaces→dashes, lowercase)
- [x] **STOR-04**: Presets survive across sessions, reboots, and reinstalls

### Save

- [x] **SAVE-01**: User can save current shader config as a named preset from redpill TUI
- [x] **SAVE-02**: Save prompts for preset name with validation (no empty, no duplicates without confirm)
- [x] **SAVE-03**: Save captures all 11 shader parameters from the active slot
- [x] **SAVE-04**: Overwrite existing preset prompts for confirmation

### Load

- [x] **LOAD-01**: User can load a preset by name from redpill TUI
- [x] **LOAD-02**: Load applies all 11 parameters to the active shader slot
- [x] **LOAD-03**: Load triggers D-Bus reload so changes are visible immediately
- [ ] **LOAD-04**: construct supports --preset flag to launch with a saved preset

### List

- [x] **LIST-01**: User can list all saved presets from redpill TUI
- [x] **LIST-02**: List shows preset name, RGB color swatch, and save date
- [ ] **LIST-03**: bluepill can restore from a named preset instead of state.json

### Delete

- [x] **DEL-01**: User can delete a preset by name from redpill TUI
- [x] **DEL-02**: Delete prompts for confirmation

### Integration

- [x] **INTG-01**: preset_service.py module with save/load/list/delete functions
- [ ] **INTG-02**: Redpill TUI has Presets menu section (save, load, list, delete)
- [ ] **INTG-03**: construct --preset <name> launches window with preset config
- [ ] **INTG-04**: bluepill --preset <name> restores session using preset

## v2 Requirements

- **EXPORT-01**: Export preset as shareable file
- **IMPORT-01**: Import preset from file
- **PREVIEW-01**: Preview preset colors before loading

## Out of Scope

| Feature | Reason |
|---------|--------|
| Windows implementation | Windows Claude handles separately |
| Preset sharing between machines | Future feature |
| Preset marketplace | Future feature |
| Format migration | Keep simple, get right first |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STOR-01 | Phase 1 | Complete |
| STOR-02 | Phase 1 | Complete |
| STOR-03 | Phase 1 | Complete |
| STOR-04 | Phase 1 | Complete |
| SAVE-01 | Phase 2 | Complete |
| SAVE-02 | Phase 2 | Complete |
| SAVE-03 | Phase 2 | Complete |
| SAVE-04 | Phase 2 | Complete |
| LOAD-01 | Phase 2 | Complete |
| LOAD-02 | Phase 2 | Complete |
| LOAD-03 | Phase 2 | Complete |
| LOAD-04 | Phase 3 | Pending |
| LIST-01 | Phase 2 | Complete |
| LIST-02 | Phase 2 | Complete |
| LIST-03 | Phase 3 | Pending |
| DEL-01 | Phase 2 | Complete |
| DEL-02 | Phase 2 | Complete |
| INTG-01 | Phase 1 | Complete |
| INTG-02 | Phase 2 | Pending |
| INTG-03 | Phase 3 | Pending |
| INTG-04 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-03-28*
