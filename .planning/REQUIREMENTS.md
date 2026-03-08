# Requirements: Matrix Shader — Linux & Mac Port

**Defined:** 2026-03-05
**Core Value:** Full platform parity — every Windows feature works on Linux and Mac. No compromises.

## v1 Requirements

### Shader System

- [x] **SHDR-01**: Shader parameters (speed, glow, width, trail, density) modifiable at runtime via #define rewrite
- [x] **SHDR-02**: Ghostty hot-reloads shader when file changes (verify or patch)
- [x] **SHDR-03**: Per-window shader parameterization (each window has independent settings)
- [x] **SHDR-04**: Layer toggles (far/mid/near) per window
- [x] **SHDR-05**: RGB color fine-tuning per window (not just presets)
- [x] **SHDR-06**: Force shader reload hotkey
- [ ] **SHDR-07**: Redpill-Neo 3D corridor shader ported from HLSL to GLSL

### Control Panel

- [ ] **CTRL-01**: Red Pill TUI control panel (Python, full-screen terminal UI)
- [ ] **CTRL-02**: Tab management — cycle through open Matrix windows
- [ ] **CTRL-03**: Color controls — 6 presets + fine RGB adjustment
- [ ] **CTRL-04**: Rain parameter controls — speed/glow/width/trail/density with live preview
- [ ] **CTRL-05**: Layer toggle controls (7/8/9 keys)
- [ ] **CTRL-06**: Window controls — opacity, deploy count, launch new windows
- [ ] **CTRL-07**: Layout controls — cycle mode, glitch toggle, snapback save/restore
- [ ] **CTRL-08**: Help screen showing all keybindings
- [ ] **CTRL-09**: Reset to defaults per window
- [ ] **CTRL-10**: Dirty indicator and auto-save on tab switch

### Hotkeys

- [ ] **HKEY-01**: All 13 Windows hotkeys ported to evdev listener
- [x] **HKEY-02**: Speed up/down (Ctrl+Shift+Up/Down)
- [x] **HKEY-03**: Layer toggles (Ctrl+Shift+1/2/3)
- [x] **HKEY-04**: Cycle layout (Ctrl+Shift+L)
- [x] **HKEY-05**: Rotate windows left/right (Ctrl+Shift+Left/Right)
- [x] **HKEY-06**: Force shader reload (Ctrl+Shift+F5)
- [x] **HKEY-07**: Hotkey configuration and persistence (JSON config file)
- [x] **HKEY-08**: Conflict detection and notification

### Layout Engine

- [ ] **LAYO-01**: Pillars layout mode (side-by-side vertical columns)
- [ ] **LAYO-02**: Quads layout mode (2x2 grid with gutters)
- [ ] **LAYO-03**: Overlap layout mode (windows overlap by configurable %)
- [ ] **LAYO-04**: Auto layout mode (smart default based on window count)
- [ ] **LAYO-05**: Window positioning via patched Ghostty or compositor IPC
- [ ] **LAYO-06**: Multi-monitor distribution
- [ ] **LAYO-07**: Multi-desktop (workspace) distribution
- [ ] **LAYO-08**: Split pane layouts (mixed modes — half quads, half panels, etc.)
- [ ] **LAYO-09**: Glitch mode — auto-snap windows to formation
- [ ] **LAYO-10**: Snapback — save/restore window positions
- [ ] **LAYO-11**: Border compensation for pixel-perfect positioning

### Window Management

- [ ] **WNDW-01**: Window identity tracking (slot-based, config file convention)
- [ ] **WNDW-02**: Per-window state persistence (shader config, position, slot)
- [ ] **WNDW-03**: Rich state.json (full shader configs, layout config, active tab)
- [ ] **WNDW-04**: Monitor/watchdog process — restart crashed hotkey listener
- [ ] **WNDW-05**: Single-instance enforcement for hotkey listener

### Session Management

- [ ] **SESS-01**: Bluepill quick restore (launch saved windows without wizard)
- [ ] **SESS-02**: Full session state save/restore including shader parameters
- [ ] **SESS-03**: Detect and skip already-open windows on restore

### Wizard & UX

- [ ] **WIZD-01**: Matrix splash animation on startup
- [ ] **WIZD-02**: Random Matrix movie quotes
- [ ] **WIZD-03**: Arrow-key menu for pill choice (not just 1/2 input)
- [ ] **WIZD-04**: Update checker (GitHub releases API)
- [ ] **WIZD-05**: Morpheus mode (--morpheus flag, philosophical intro)
- [ ] **WIZD-06**: Agent Smith mode (--agent-smith flag, chaos randomization)

### Installer

- [ ] **INST-01**: Clean uninstaller script
- [ ] **INST-02**: Update detection (existing install check)
- [ ] **INST-03**: Desktop notification integration (notify-send)

### MatrixLite

- [ ] **LITE-01**: Text-mode Matrix rain for non-Ghostty terminals
- [ ] **LITE-02**: Interactive menu: color presets, speed, density
- [ ] **LITE-03**: Full-screen and background modes

### Mac Port

- [ ] **MAC-01**: Metal shader port of Matrix rain (or GLSL via compatible terminal)
- [ ] **MAC-02**: macOS hotkey mechanism (CGEvent tap or similar)
- [ ] **MAC-03**: macOS terminal integration (patched Ghostty, iTerm2, or native)
- [ ] **MAC-04**: Homebrew installer formula
- [ ] **MAC-05**: DMG installer package
- [ ] **MAC-06**: macOS window positioning (Accessibility API or AppleScript)
- [ ] **MAC-07**: WakeupNeo wizard working on macOS
- [ ] **MAC-08**: All hotkeys working on macOS

## v2 Requirements

- **LICENSE-01**: License/payment system on Linux/Mac
- **THEME-01**: User-created color theme sharing
- **REMOTE-01**: Remote control via mobile app

## Out of Scope

| Feature | Reason |
|---------|--------|
| Windows bug fixes | Separate project, separate Claude |
| Website changes | Already deployed, separate repo planned |
| License system | Business decision deferred to v2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHDR-01 | Phase 1 | Complete |
| SHDR-02 | Phase 1 | Complete |
| SHDR-03 | Phase 1 | Complete |
| SHDR-04 | Phase 1 | Complete |
| SHDR-05 | Phase 1 | Complete |
| SHDR-06 | Phase 1 | Complete |
| SHDR-07 | Phase 9 | Pending |
| CTRL-01 | Phase 3 | Pending |
| CTRL-02 | Phase 3 | Pending |
| CTRL-03 | Phase 3 | Pending |
| CTRL-04 | Phase 3 | Pending |
| CTRL-05 | Phase 3 | Pending |
| CTRL-06 | Phase 3 | Pending |
| CTRL-07 | Phase 4 | Pending |
| CTRL-08 | Phase 4 | Pending |
| CTRL-09 | Phase 4 | Pending |
| CTRL-10 | Phase 4 | Pending |
| HKEY-01 | Phase 2 | Pending |
| HKEY-02 | Phase 2 | Complete |
| HKEY-03 | Phase 2 | Complete |
| HKEY-04 | Phase 2 | Complete |
| HKEY-05 | Phase 2 | Complete |
| HKEY-06 | Phase 2 | Complete |
| HKEY-07 | Phase 2 | Complete |
| HKEY-08 | Phase 2 | Complete |
| LAYO-01 | Phase 6 | Pending |
| LAYO-02 | Phase 6 | Pending |
| LAYO-03 | Phase 6 | Pending |
| LAYO-04 | Phase 6 | Pending |
| LAYO-05 | Phase 5 | Pending |
| LAYO-06 | Phase 6 | Pending |
| LAYO-07 | Phase 6 | Pending |
| LAYO-08 | Phase 6 | Pending |
| LAYO-09 | Phase 6 | Pending |
| LAYO-10 | Phase 6 | Pending |
| LAYO-11 | Phase 5 | Pending |
| WNDW-01 | Phase 5 | Pending |
| WNDW-02 | Phase 7 | Pending |
| WNDW-03 | Phase 7 | Pending |
| WNDW-04 | Phase 7 | Pending |
| WNDW-05 | Phase 7 | Pending |
| SESS-01 | Phase 7 | Pending |
| SESS-02 | Phase 7 | Pending |
| SESS-03 | Phase 7 | Pending |
| WIZD-01 | Phase 9 | Pending |
| WIZD-02 | Phase 9 | Pending |
| WIZD-03 | Phase 9 | Pending |
| WIZD-04 | Phase 9 | Pending |
| WIZD-05 | Phase 9 | Pending |
| WIZD-06 | Phase 9 | Pending |
| INST-01 | Phase 10 | Pending |
| INST-02 | Phase 10 | Pending |
| INST-03 | Phase 10 | Pending |
| LITE-01 | Phase 10 | Pending |
| LITE-02 | Phase 10 | Pending |
| LITE-03 | Phase 10 | Pending |
| MAC-01 | Phase 8 | Pending |
| MAC-02 | Phase 8 | Pending |
| MAC-03 | Phase 8 | Pending |
| MAC-04 | Phase 8 | Pending |
| MAC-05 | Phase 8 | Pending |
| MAC-06 | Phase 8 | Pending |
| MAC-07 | Phase 8 | Pending |
| MAC-08 | Phase 8 | Pending |

---
*Requirements defined: 2026-03-05*
*Traceability updated: 2026-03-05*
