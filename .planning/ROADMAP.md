# Roadmap: Matrix Shader — Linux & Mac Port

## Overview

Starting from a 25%-complete Linux port (shaders render, 4 hotkeys work, wizard exists), this roadmap delivers full Windows parity on Linux and a functional Mac port in time for the MacBook Neo launch (March 11, 2026). The critical path runs through shader hot-reload (Phase 1), which unblocks the control panel, hotkeys, and layout engine. The Mac port (Phase 8) can begin in parallel after Phase 2 establishes the patterns. Every Windows feature maps to exactly one phase. There is no spoon.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Shader Hot-Reload** - Verify/patch Ghostty shader reload; implement #define rewrite for all parameters
- [ ] **Phase 2: Full Hotkey System** - All 13 hotkeys, config persistence, conflict detection
- [ ] **Phase 3: Control Panel Core** - Red Pill TUI with live parameter adjustment and tab management
- [ ] **Phase 4: Control Panel Polish** - Layout controls, hotkey config screen, help, reset, auto-save
- [ ] **Phase 5: Window Positioning** - Patch Ghostty for position/size control; compositor IPC fallbacks
- [ ] **Phase 6: Layout Engine** - Pillars/Quads/Overlap/Auto modes, multi-monitor, glitch, snapback
- [ ] **Phase 7: Window & Session Management** - State persistence, bluepill, watchdog, single-instance
- [ ] **Phase 8: Mac Port** - Metal/GLSL shaders, macOS hotkeys, terminal integration, installers
- [ ] **Phase 9: Wizard Polish & Easter Eggs** - Splash, quotes, Morpheus/Smith modes, Redpill-Neo shader
- [ ] **Phase 10: MatrixLite & Installer Completion** - Text-mode fallback, uninstaller, update detection

## Phase Details

### Phase 1: Shader Hot-Reload
**Goal**: Users can modify any shader parameter (speed, glow, width, trail, density, layers, RGB) and see the change applied in Ghostty within seconds — without restarting
**Depends on**: Nothing (existing Ghostty patching capability)
**Requirements**: SHDR-01, SHDR-02, SHDR-03, SHDR-04, SHDR-05, SHDR-06
**Success Criteria** (what must be TRUE):
  1. Changing a #define value in a GLSL shader file causes Ghostty to visually update within ~2 seconds
  2. A Python script can rewrite #define parameters (speed, glow, width, trail, density, R/G/B) in any slot's shader file
  3. Each Ghostty window reads from its own independent shader file — changing slot 1's speed does not affect slot 2
  4. Layer toggles (far/mid/near) can be set per window via #define rewrite
  5. RGB color values can be set to arbitrary float values (not just 6 presets) per window
  6. A force-reload hotkey action triggers Ghostty config reload for the target window
**Plans:** 3 plans
Plans:
- [ ] 01-01-PLAN.md — Patch Ghostty changeConfig() for shader hot-reload (SHDR-02)
- [ ] 01-02-PLAN.md — Build shader_service.py with TDD (SHDR-01, SHDR-03, SHDR-04, SHDR-05, SHDR-06)
- [ ] 01-03-PLAN.md — Wire wakeupneo.sh integration + visual verification (all SHDR)

### Phase 2: Full Hotkey System
**Goal**: All 13 Windows hotkeys work globally on Linux via evdev, are configurable by the user, and persisted to a JSON config file
**Depends on**: Phase 1 (speed/layer hotkeys require shader parameter rewrite)
**Requirements**: HKEY-01, HKEY-02, HKEY-03, HKEY-04, HKEY-05, HKEY-06, HKEY-07, HKEY-08
**Success Criteria** (what must be TRUE):
  1. Pressing Ctrl+Shift+Up/Down changes rain speed on all Matrix windows within 2 seconds
  2. Pressing Ctrl+Shift+1/2/3 toggles the far/mid/near rain layers on all windows
  3. Pressing Ctrl+Shift+L cycles through layout modes (action fires; layout engine wired in Phase 6)
  4. Pressing Ctrl+Shift+Left/Right rotates window assignments between slots
  5. Pressing Ctrl+Shift+F5 forces all Matrix windows to reload their shaders
  6. User can edit ~/.config/matrix-shader/hotkeys.json to rebind any of the 13 hotkeys
  7. If a requested hotkey conflicts with a system binding, a desktop notification appears
**Plans:** 3 plans
Plans:
- [ ] 02-01-PLAN.md — Config model + conflict detection (HKEY-07, HKEY-08)
- [ ] 02-02-PLAN.md — All 13 action handlers with toast notifications (HKEY-02, HKEY-03, HKEY-04, HKEY-05, HKEY-06)
- [ ] 02-03-PLAN.md — Wire into matrix-keys.py + end-to-end verification (HKEY-01)

### Phase 3: Control Panel Core
**Goal**: Running `redpill` opens a full-screen TUI where users can select any Matrix window tab and live-adjust all visual parameters, with changes rendering in real time
**Depends on**: Phase 1 (shader hot-reload), Phase 2 (hotkeys running)
**Requirements**: CTRL-01, CTRL-02, CTRL-03, CTRL-04, CTRL-05, CTRL-06
**Success Criteria** (what must be TRUE):
  1. `redpill` launches a full-screen TUI control panel in a Ghostty window
  2. Tab bar at top shows all open Matrix windows (slots 1-8) with color indicators; Tab/Shift+Tab cycles between them
  3. Pressing 1-6 changes the active window's color preset; Q/W/A/S/Z/X fine-tune RGB by ±0.05
  4. Pressing E/R/D/F/C/V/T/Y/G/H adjusts speed, glow, width, trail, density — change appears in the target window within 2 seconds
  5. Pressing 7/8/9 toggles far/mid/near rain layers on the active window
  6. Pressing B cycles opacity, K/L adjust opacity up/down; +/- and Enter deploy/remove windows
**Plans**: TBD

### Phase 4: Control Panel Polish
**Goal**: The Red Pill TUI is complete — layout controls, hotkey configuration, help screen, reset-to-defaults, dirty tracking, and auto-save all work
**Depends on**: Phase 3 (control panel core), Phase 5 (window positioning, for layout controls)
**Requirements**: CTRL-07, CTRL-08, CTRL-09, CTRL-10
**Success Criteria** (what must be TRUE):
  1. Shift+L cycles layout mode in the TUI and repositions windows; Shift+G toggles glitch mode
  2. Shift+S saves current window positions; Shift+R restores them
  3. Pressing ? shows a full help screen listing every keybinding
  4. Pressing 0 resets the active window's shader parameters to defaults
  5. An asterisk or indicator appears when a tab has unsaved changes; switching tabs auto-saves
**Plans:** 3 plans
Plans:
- [ ] 04-01-PLAN.md — Layout controls integration + COMBAT TRAINING TUI section (CTRL-07)
- [ ] 04-02-PLAN.md — Hotkey configuration screen (CTRL-08)
- [ ] 04-03-PLAN.md — Help screen, reset, dirty tracking, auto-save (CTRL-09, CTRL-10)

### Phase 5: Window Positioning
**Goal**: Matrix windows can be programmatically moved and sized to exact pixel coordinates on Linux — achieved by patching Ghostty or using compositor IPC
**Depends on**: Phase 1 (Ghostty familiarity from shader work)
**Requirements**: LAYO-05, LAYO-11, WNDW-01
**Success Criteria** (what must be TRUE):
  1. A Matrix window can be moved to an exact screen position (x, y, width, height) via a single command or IPC call
  2. Window identity is tracked by slot number — the system knows which PID/window corresponds to slot 1, slot 2, etc.
  3. Border/decoration offsets are measured and compensated so windows are pixel-perfect flush to edges
  4. Positioning works on at least GNOME Wayland; X11/XWayland also supported as fallback
**Plans:** 3 plans
Plans:
- [ ] 05-01-PLAN.md — GNOME Shell Extension with D-Bus window management API (LAYO-05, WNDW-01)
- [ ] 05-02-PLAN.md — Python window_service.py client with slot mapping + XWayland fallback (LAYO-05, LAYO-11, WNDW-01)
- [ ] 05-03-PLAN.md — Wire into wakeupneo.sh + install.sh + end-to-end verification (all reqs)

### Phase 6: Layout Engine
**Goal**: Users can arrange Matrix windows into Pillars, Quads, Overlap, or Auto layouts across one or more monitors, with glitch auto-correction and snapback save/restore
**Depends on**: Phase 5 (window positioning), Phase 2 (layout hotkeys fire)
**Requirements**: LAYO-01, LAYO-02, LAYO-03, LAYO-04, LAYO-06, LAYO-07, LAYO-08, LAYO-09, LAYO-10
**Success Criteria** (what must be TRUE):
  1. Pressing Ctrl+Shift+L cycles through Pillars, Quads, Overlap, and Auto layouts — windows reposition accordingly
  2. In Pillars mode, windows tile side-by-side spanning full screen height with scaled gaps
  3. In Quads mode, windows form a 2x2 grid with centered gutters
  4. In Overlap mode, windows stack with configurable overlap percentage creating layered depth
  5. With multiple monitors, windows distribute across screens (primary gets priority)
  6. Ctrl+Shift+S saves current window positions; Ctrl+Shift+R restores them
  7. Glitch mode auto-snaps windows back to formation when drift is detected
**Plans**: TBD

### Phase 7: Window & Session Management
**Goal**: Per-window shader configs, positions, and slot assignments persist across reboots; `bluepill` restores the full session instantly; the hotkey listener is monitored and auto-restarted
**Depends on**: Phase 6 (layout positions to persist), Phase 3 (shader configs to persist)
**Requirements**: WNDW-02, WNDW-03, WNDW-04, WNDW-05, SESS-01, SESS-02, SESS-03
**Success Criteria** (what must be TRUE):
  1. After closing and reopening Matrix, all windows reappear with exactly the same colors, speed, glow, and positions as before
  2. `bluepill` restores the last saved session in under 3 seconds, skipping any already-open slots
  3. state.json contains full shader configs (all 9 parameters), layout config, and active tab — not just color presets
  4. The watchdog detects a crashed hotkey listener and restarts it within 5 seconds
  5. Running `matrix-keys.py` a second time exits cleanly without creating a duplicate listener
**Plans:** 3 plans
Plans:
- [ ] 07-01-PLAN.md — State persistence module (state_service.py) with full schema, migration, debounced saves (WNDW-02, WNDW-03, SESS-02, SESS-03)
- [ ] 07-02-PLAN.md — bluepill session restore command (SESS-01, SESS-02)
- [ ] 07-03-PLAN.md — Single-instance guard + watchdog process (WNDW-04, WNDW-05)

### Phase 8: Mac Port
**Goal**: Matrix Shader runs on macOS — shaders render in a terminal, all 13 hotkeys work system-wide, WakeupNeo wizard launches windows, and installation is available via Homebrew or DMG
**Depends on**: Phase 1 (GLSL shader patterns), Phase 2 (hotkey architecture patterns)
**Requirements**: MAC-01, MAC-02, MAC-03, MAC-04, MAC-05, MAC-06, MAC-07, MAC-08
**Success Criteria** (what must be TRUE):
  1. Running `wakeupneo` on macOS opens Matrix rain shader windows in a supported terminal (Ghostty, iTerm2, or native)
  2. All 13 hotkeys respond system-wide on macOS via CGEvent tap or equivalent mechanism
  3. Matrix windows can be positioned to exact coordinates using macOS Accessibility API or AppleScript
  4. `brew install matrixshader` or the DMG installer successfully installs and runs `wakeupneo`
  5. The WakeupNeo wizard flow (color picker, window launch, hotkey start) completes without errors on macOS
**Plans**: TBD

### Phase 9: Wizard Polish & Easter Eggs
**Goal**: WakeupNeo has the same theatrical quality as Windows — splash animation, movie quotes, arrow-key menus, Morpheus/Agent Smith modes, and the Redpill-Neo 3D corridor shader
**Depends on**: Phase 7 (session management complete), Phase 1 (shader system for Redpill-Neo)
**Requirements**: WIZD-01, WIZD-02, WIZD-03, WIZD-04, WIZD-05, WIZD-06, SHDR-07
**Success Criteria** (what must be TRUE):
  1. WakeupNeo shows a cascading green numbers splash animation (~1.5s) on startup
  2. A random Matrix movie quote appears below the splash before the typewriter intro
  3. The Blue Pill / Red Pill choice uses an arrow-key navigable menu, not a 1/2 prompt
  4. `wakeupneo --morpheus` shows an extended philosophical intro; `--agent-smith` randomizes all window colors and speeds
  5. `wakeupneo --update` (or automatic check) reports if a newer version is available via GitHub releases API
  6. The Redpill-Neo 3D corridor shader renders in GLSL and is selectable as a color preset
**Plans**: TBD

### Phase 10: MatrixLite & Installer Completion
**Goal**: MatrixLite provides text-mode Matrix rain in any terminal; the installer gains clean uninstall and update detection; desktop notifications work
**Depends on**: Phase 7 (state management patterns complete)
**Requirements**: LITE-01, LITE-02, LITE-03, INST-01, INST-02, INST-03
**Success Criteria** (what must be TRUE):
  1. `matrixlite` command launches animated Matrix rain in any terminal (no Ghostty required)
  2. Inside MatrixLite, pressing 1-6 changes color, E/R changes speed, D/F changes density, Enter toggles full-screen, B toggles background mode
  3. Running `uninstall-matrix` removes all Matrix files, PATH entries, and background processes cleanly
  4. Re-running `install.sh` on an existing installation detects the current version and offers update or reinstall
  5. After launching windows, a desktop notification appears via `notify-send` confirming Matrix is running
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order. Phase 8 (Mac) can begin in parallel with Phase 6-7 once Phase 2 patterns are established.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Shader Hot-Reload | 0/3 | Planning complete | - |
| 2. Full Hotkey System | 0/3 | Planning complete | - |
| 3. Control Panel Core | 0/TBD | Not started | - |
| 4. Control Panel Polish | 0/3 | Planning complete | - |
| 5. Window Positioning | 0/3 | Planning complete | - |
| 6. Layout Engine | 0/TBD | Not started | - |
| 7. Window & Session Management | 0/3 | Planning complete | - |
| 8. Mac Port | 0/TBD | Not started | - |
| 9. Wizard Polish & Easter Eggs | 0/TBD | Not started | - |
| 10. MatrixLite & Installer Completion | 0/TBD | Not started | - |
