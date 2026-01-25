# Requirements: Matrix Terminal Shader C# Rebuild

**Defined:** 2026-01-25
**Core Value:** The C# version must work exactly like the PowerShell version does today

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Shader Control

- [ ] **SHDR-01**: User can adjust RGB color values (0.0-1.0 range)
- [ ] **SHDR-02**: User can select from 6 color presets (Green, Cyan, Red, Purple, Gold, Teal)
- [ ] **SHDR-03**: User can adjust animation speed
- [ ] **SHDR-04**: User can adjust glow intensity
- [ ] **SHDR-05**: User can adjust character width
- [ ] **SHDR-06**: User can adjust trail length
- [ ] **SHDR-07**: User can adjust character density
- [ ] **SHDR-08**: User can toggle each of 3 parallax layers independently
- [ ] **SHDR-09**: Shader file regenerates with #define injection on parameter change
- [ ] **SHDR-10**: Windows Terminal hot-reloads shader within ~100ms of file change

### Window Management

- [ ] **WNDW-01**: System can detect all Windows Terminal windows
- [ ] **WNDW-02**: System can identify Matrix shader windows via 4-layer resolution
- [ ] **WNDW-03**: User can manage up to 8 shader windows via tabbed interface
- [ ] **WNDW-04**: User can cycle through Pillars/Quads/Auto layout modes
- [ ] **WNDW-05**: System positions windows with configurable gap size
- [ ] **WNDW-06**: System handles multi-monitor configurations
- [ ] **WNDW-07**: Window-to-shader mapping persists across sessions
- [ ] **WNDW-08**: System tracks window identity with confidence scoring

### CLI Applications

- [ ] **CLI-01**: redpill.exe provides interactive control panel TUI
- [ ] **CLI-02**: bluepill.exe provides quick session restore
- [ ] **CLI-03**: wakeupneo.exe provides setup wizard with Blue/Red Pill paths
- [ ] **CLI-04**: All CLIs compile to Native AOT single-file executables
- [ ] **CLI-05**: Startup time under 500ms (vs 60+ seconds PowerShell)

### State Persistence

- [ ] **STATE-01**: Shader configuration persists to JSON
- [ ] **STATE-02**: Window registry persists handle-to-shader mapping
- [ ] **STATE-03**: Identity registry persists profile-to-window mapping
- [ ] **STATE-04**: Layout preferences persist (mode, gap size, slots)
- [ ] **STATE-05**: Atomic file writes prevent corruption

### Terminal Integration

- [ ] **TERM-01**: System can read/modify Windows Terminal settings.json
- [ ] **TERM-02**: System can create Matrix-1 through Matrix-8 profiles
- [ ] **TERM-03**: System sets pixel shader paths in profiles
- [ ] **TERM-04**: Diagnostic logging available via MATRIX_DEBUG=1

### User Experience

- [ ] **UX-01**: TUI displays color swatches for visual feedback
- [ ] **UX-02**: Setup wizard offers Blue Pill (simple) and Red Pill (advanced) paths
- [ ] **UX-03**: Keyboard shortcuts match PowerShell version
- [ ] **UX-04**: Dirty state indicator shows unsaved changes
- [ ] **UX-05**: Auto-save on tab switch prevents lost changes

### MatrixLite Fallback

- [ ] **LITE-01**: Text-based Matrix rain renders in non-WT terminals
- [ ] **LITE-02**: Uses movie-accurate Katakana character set
- [ ] **LITE-03**: Supports same 6 color presets via ANSI codes
- [ ] **LITE-04**: Graceful degradation when GPU shaders unavailable

## v2 Requirements

Deferred to future release.

### Enhanced Features

- **ENH-01**: Undo/redo for parameter changes
- **ENH-02**: Custom preset management (save/load)
- **ENH-03**: System tray integration
- **ENH-04**: Global hotkeys when minimized
- **ENH-05**: Crash recovery with auto-restore

## Out of Scope

| Feature | Reason |
|---------|--------|
| GUI application | Terminal-native experience is core identity |
| Cross-platform GPU shaders | Windows Terminal specific |
| Cloud sync | Unnecessary complexity |
| Telemetry | Privacy concerns |
| New shader effects | Feature parity first |
| Rewriting HLSL shaders | They work perfectly already |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHDR-01 | Phase 1 | Pending |
| SHDR-02 | Phase 1 | Pending |
| SHDR-03 | Phase 1 | Pending |
| SHDR-04 | Phase 1 | Pending |
| SHDR-05 | Phase 1 | Pending |
| SHDR-06 | Phase 1 | Pending |
| SHDR-07 | Phase 1 | Pending |
| SHDR-08 | Phase 1 | Pending |
| SHDR-09 | Phase 1 | Pending |
| SHDR-10 | Phase 1 | Pending |
| STATE-01 | Phase 2 | Pending |
| STATE-05 | Phase 2 | Pending |
| WNDW-01 | Phase 3 | Pending |
| WNDW-06 | Phase 3 | Pending |
| WNDW-02 | Phase 4 | Pending |
| WNDW-08 | Phase 4 | Pending |
| STATE-02 | Phase 4 | Pending |
| STATE-03 | Phase 4 | Pending |
| WNDW-03 | Phase 5 | Pending |
| WNDW-04 | Phase 5 | Pending |
| WNDW-05 | Phase 5 | Pending |
| WNDW-07 | Phase 5 | Pending |
| STATE-04 | Phase 5 | Pending |
| CLI-01 | Phase 6 | Pending |
| UX-01 | Phase 6 | Pending |
| UX-03 | Phase 6 | Pending |
| UX-04 | Phase 6 | Pending |
| UX-05 | Phase 6 | Pending |
| TERM-01 | Phase 7 | Pending |
| TERM-02 | Phase 7 | Pending |
| TERM-03 | Phase 7 | Pending |
| TERM-04 | Phase 7 | Pending |
| CLI-02 | Phase 8 | Pending |
| CLI-03 | Phase 8 | Pending |
| UX-02 | Phase 8 | Pending |
| CLI-04 | Phase 9 | Pending |
| CLI-05 | Phase 9 | Pending |
| LITE-01 | Phase 10 | Pending |
| LITE-02 | Phase 10 | Pending |
| LITE-03 | Phase 10 | Pending |
| LITE-04 | Phase 10 | Pending |

**Coverage:**
- v1 requirements: 38 total
- Mapped to phases: 38
- Unmapped: 0

---
*Requirements defined: 2026-01-25*
*Last updated: 2026-01-25 after roadmap creation (10-phase structure)*
