# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Matrix Terminal Shader - A real-time controllable Matrix rain effect for Windows Terminal. Multi-window system with interactive control panel for managing multiple shader instances simultaneously.

## Architecture

```
User Input → matrix_control.ps1 → Regenerates shader HLSL → Windows Terminal hot-reloads → GPU renders
```

**Key mechanism:** PowerShell writes shader parameters as `#define` statements. Windows Terminal detects file timestamp change and reloads shader automatically (~100ms latency).

**Core Files:**
- `matrix_control.ps1` - Multi-window control panel TUI with tabbed interface for up to 6 shader windows
- `matrix_setup.ps1` - Interactive setup wizard (Blue Pill vs Red Pill paths)
- `shaders/Matrix-1.hlsl` through `Matrix-6.hlsl` - HLSL pixel shaders with bit-packed Katakana glyphs
- `shaders/Redpill-Neo.hlsl` - Custom 3D corridor shader with glowing "MATRIX SHADER" logo (Neo vision)
- `prd.json` - Ralph-compatible user stories for current hardening sprint
- `MVP/Matrix.hlsl` - Original single-instance shader (legacy)

## Critical Technical Details

### HLSL Glyph System
Glyphs are bit-packed: 35 bits (5×7 pixels) per character stored in uint32 constants. Lookup: `(GLYPHS[idx] >> bit_index) & 1u`

### Hot-Reload Mechanism
PowerShell regenerates entire shader file with new `#define` values, then touches file timestamp. Windows Terminal watches for changes.

### Layer System
Three parallax depth layers (FAR/MID/NEAR) rendered additively. Each can be toggled independently.

### Multi-Window System
Control panel manages up to 6 independent shader windows. Each window:
- Can use different shader from library
- Has independent parameters (speed, color, density, layers)
- Is positioned/sized via Windows API calls
- Has configuration persisted to JSON files

## File Encoding

PowerShell requires CRLF line endings. Always use Windows-native tools.

## Key Paths

- Project root: `C:\Users\ehome\Documents\Matrix\`
- Control panel: `C:\Users\ehome\Documents\Matrix\matrix_control.ps1`
- Setup wizard: `C:\Users\ehome\Documents\Matrix\matrix_setup.ps1`
- Shader library: `C:\Users\ehome\Documents\Matrix\shaders\`
- Windows Terminal settings: `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
- GitHub repo: `matrixshader/matrix-shader`

## Testing

1. Modify shader `#define` values directly in any shader file - changes appear immediately in terminal
2. Run `matrix_control.ps1` in Windows PowerShell to test TUI controls and multi-window management
3. Run `matrix_setup.ps1` to test setup wizard flow (Blue Pill vs Red Pill)
4. Verify shader compiles by checking Windows Terminal shows effect (no error = success)

## Project State

### Current Phase: Phase 14 - Final Polish & Hotkey Stability (E2E Round 1 Complete)

### Completed Phases:
- [x] MVP single-instance shader (Matrix.hlsl + matrix_tool.ps1)
- [x] Multi-window system architecture
- [x] Setup wizard with Blue/Red Pill paths
- [x] Neo vision shader (Redpill-Neo.hlsl)
- [x] Code review and PRD generation
- [x] Control Panel Hardening (US-001 through US-010)
- [x] C#/.NET Rebuild (Phases 1-13)
- [x] Phase 14 Wave 1-4 (14-01 through 14-05)
- [x] Phase 14-06 E2E Round 1 Testing

### Current Phase Checklist (Phase 14):
- [x] 14-01: Hotkey service stability (crash recovery, stay-alive timer)
- [x] 14-02: Transparency fixes (plain transparency, settings backup/restore)
- [x] 14-03: Hotkey actions (window rotation, layer toggles)
- [x] 14-04: Layout fixes (gap scaling, fullscreen exclusion)
- [x] 14-05: Remove shader cycling, rename Cyan to Blue
- [x] 14-06: E2E Round 1 - Fixed transparency toggle, Glitch cooldown, auto-continue, feedback

### Next Steps (E2E Round 2):
- [ ] Verify all Round 1 fixes in fresh Windows Sandbox
- [ ] Test Glitch in Blue Pill path
- [ ] Test opacity toggle (Ctrl+B: 85%↔100%)
- [ ] Test 5-second Glitch cooldown prevents snap-back
- [ ] Test auto-continue after WT install
- [ ] Implement hotkey help popup (Matrix-styled) - user requested

## Session History

### Session 2026-01-11: Neo Vision & Hardening PRD
**Phase:** Control Panel Hardening - PRD Creation

**Accomplishments:**
1. Created custom Redpill-Neo vision shader (`shaders/Redpill-Neo.hlsl`)
   - 3D box corridor effect with Matrix code on walls/floor/ceiling
   - SDF-based glowing "MATRIX SHADER" logo text
   - Tuned text size, thickness, spacing, and glow levels
2. Updated Red Pill path in `matrix_setup.ps1`
   - Creates shaders for configured windows
   - Launches all Matrix windows user selected
   - Opens Redpill control panel with Neo vision background
   - Deleted legacy `matrix_tool.ps1` (replaced by `matrix_control.ps1`)
3. Code review via feature-dev:code-reviewer agent
   - Found critical bugs: unsafe atomic write, missing JSON error handling, regex issues
   - Found important issues: window handle sorting, fixed delays, lost unsaved changes
   - Overall rating: 7/10 - excellent design, needs hardening
4. Generated PRD (`tasks/prd-control-panel-hardening.md`) with 10 user stories
5. Created Ralph-compatible prd.json
   - Archived previous v2 prd.json to `archive/2026-01-11-matrix-v2-fix/`
   - New prd.json has 10 hardening stories
   - Reset progress.txt for new project

**Key Decisions:**
- Neo vision shader uses SDF text rendering instead of sprite-based glyphs
- Control panel hardening takes priority over new features
- Code review identified atomic file write as highest priority fix

**Next Steps:**
- Execute hardening user stories US-001 through US-010 via Ralph loop OR manual implementation
- Start with US-001 (safe atomic file writes) as highest priority
- Consider adding unit tests after hardening complete

**Files Modified:**
- `shaders/Redpill-Neo.hlsl` (created)
- `matrix_setup.ps1` (updated Red Pill path)
- `matrix_tool.ps1` (deleted - legacy file)
- `prd.json` (new hardening stories)
- `tasks/prd-control-panel-hardening.md` (created)
- `archive/2026-01-11-matrix-v2-fix/prd.json` (archived)
- `progress.txt` (reset for new project)

### Session 2026-01-17: Window Layout Engine Implementation
**Phase:** Control Panel Hardening - Window Layout Engine

**Accomplishments:**
1. Implemented complete 8-phase Window Layout Engine (`WindowLayoutEngine.ps1` - 1046 lines)
   - Phase 1: Get-MonitorInfo (multi-monitor detection via EnumDisplayMonitors)
   - Phase 2: Calculate-PillarsLayout (side-by-side columns per monitor)
   - Phase 3: Calculate-QuadsLayout (2x2 grid per monitor)
   - Phase 4: Find-MatrixWindows (EnumWindows P/Invoke for window detection)
   - Phase 5: Match-WindowsToSlots (registry-based shader-to-window mapping)
   - Phase 6: Set-WindowLayout (SetWindowPos P/Invoke for positioning)
   - Phase 7: Invoke-MatrixLayout (orchestration with layout mode cycling)
   - Phase 8: Edge case handling (50/50 tests passing)
2. Integration across all entry points
   - `matrix_control.ps1`: Added Shift+L hotkey to cycle layout modes (Pillars/Quads/Auto)
   - `matrix_setup.ps1`: Calls WindowLayoutEngine after launching windows
   - `bluepill.ps1`: Uses WindowLayoutEngine for automatic positioning
3. Comprehensive testing suite
   - Phase-specific tests (test-layout-phase1.ps1 through test-layout-phase8.ps1)
   - Edge case tests (window detection, missing slots, non-sequential slots, etc.)
   - Multi-monitor simulation tests
4. Architecture documentation (`ARCHITECTURE_WINDOW_LAYOUT.md`)
   - Detailed phase-by-phase implementation guide
   - API reference for all public functions
   - Edge case catalog with solutions
5. Recovery documentation (RECOVERY/ folder)
   - Per-phase output markdown files
   - Agent completion logs
   - Rate-limit recovery documentation

**Key Decisions:**
- Centralized layout engine vs. inline positioning in each script
- Registry-based window-to-shader mapping for persistent identification
- Two layout modes (Pillars and Quads) with mode cycling
- P/Invoke for Windows API calls (EnumWindows, SetWindowPos, EnumDisplayMonitors)
- Edge case priority: robustness over performance

**Next Steps:**
- Complete remaining hardening stories (US-009 diagnostic logging, US-010 consolidate key handlers)
- Enhance registry system for shader-to-window persistence
- Add additional layout modes (cascade, fullscreen, custom)
- Performance optimization for large window counts

**Files Modified:**
- `WindowLayoutEngine.ps1` (created - 1046 lines)
- `ARCHITECTURE_WINDOW_LAYOUT.md` (created)
- `matrix_control.ps1` (added Shift+L layout cycling)
- `matrix_setup.ps1` (integrated WindowLayoutEngine)
- `bluepill.ps1` (integrated WindowLayoutEngine)
- `CLAUDE.md` (updated project state)
- `README.md` (updated current status)
- `prd.json` (marked US-001 through US-008 complete)
- Test files: test-layout-phase1.ps1 through test-layout-phase8.ps1
- RECOVERY/phase1-8_output.md (phase documentation)
- RECOVERY/agent logs (completion tracking)

### Session 2026-02-05: Phase 14 E2E Testing and Bug Fixes
**Phase:** Final Polish & Hotkey Stability - E2E Round 1

**Accomplishments:**
1. Executed Phase 14 (6 plans across 4 waves):
   - 14-01: Hotkey service stability with crash recovery and stay-alive timer
   - 14-02: Transparency fixes (plain transparency instead of acrylic blur, settings backup/restore)
   - 14-03: Hotkey action fixes (window rotation instead of swap, layer toggle actions)
   - 14-04: Layout fixes (gap scaling, fullscreen window exclusion from Glitch)
   - 14-05: Removed shader cycling feature, renamed Cyan preset to Blue
   - 14-06: E2E verification and bug fixes from testing

2. Fixed AOT Build Issues:
   - Disabled AOT compilation to avoid UiaProviderCallback marshalling errors
   - Rebuild all executables with `/p:PublishAot=false` flag

3. E2E Bug Fixes from Round 1 Testing:
   - **BUG-TRANS04**: ToggleTransparency (Ctrl+B) changed from UseAcrylic toggle to Opacity 85%↔100% toggle
   - **BUG-GLITCH01**: Added 5-second cooldown after manual hotkey rotation to prevent Glitch snap-back fighting
   - **UX-FEEDBACK01**: WakeupNeo now shows "Starting hotkeys & Glitch... OK" for both Blue/Red pill paths
   - **UX-FLOW01**: Auto-continue after WT install - launches `wt.exe wakeupneo` instead of manual steps
   - **BUG-SHADER06**: Fixed shader phase offsets - copied correct shaders with staggered rain column timing

4. Documentation Created:
   - `installer/LOCAL-TESTING.md` - CLI one-liner test setup documentation
   - `MatrixShaderTest.wsb` - Windows Sandbox config for E2E testing

**Key Decisions:**
- Disable AOT compilation to avoid UI Automation marshalling errors (trade startup time for stability)
- Change transparency toggle from acrylic to opacity for plain see-through effect
- Add Glitch cooldown to prevent hotkey/monitor fighting
- Auto-continue after WT install improves UX flow
- Use Windows Sandbox for E2E testing with HTTP server on Default Switch

**Next Steps (Round 2 Testing):**
- Verify Glitch works in Blue Pill path (wakeupneo and bluepill.exe)
- Verify Ctrl+B toggles opacity correctly (85%↔100%)
- Verify hotkey rotation doesn't trigger Glitch snap-back (5s cooldown)
- Verify auto-continue after WT install works
- Implement hotkey help popup (Matrix-styled) - user requested feature

**Files Modified:**
- `MatrixShader/src/MatrixShader.Hotkeys/HotkeyActions.cs` (opacity toggle)
- `MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs` (5s cooldown)
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` (feedback, auto-continue)
- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` (auto-continue)
- `installer/LOCAL-TESTING.md` (created)
- `MatrixShaderTest.wsb` (created)

**Technical Notes:**
- Build uses AOT disabled: `/p:PublishAot=false`
- Local testing uses HTTP server on port 9090 with IP 172.21.80.1 (Default Switch)
- `installer/output` is gitignored - rebuild required for each test
- Branch `feature/smart-window-management` merged to `master` and pushed
