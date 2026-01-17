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

### Current Phase: COMPLETE - Control Panel Hardening

### Completed Phases:
- [x] MVP single-instance shader (Matrix.hlsl + matrix_tool.ps1)
- [x] Multi-window system architecture
- [x] Setup wizard with Blue/Red Pill paths
- [x] Neo vision shader (Redpill-Neo.hlsl)
- [x] Code review and PRD generation
- [x] Control Panel Hardening (US-001 through US-010)

### Current Phase Checklist:
- [x] US-001: Safe atomic file writes (Move-Item -Force instead of delete+rename)
- [x] US-002: JSON error handling (try-catch around all JSON ops)
- [x] US-003: Shader value validation (fix regex to reject invalid values)
- [x] US-004: Auto-save on tab switch (save dirty shader before switching)
- [x] US-005: Remove dead code (space key handler)
- [x] US-006: Robust window detection (match by title+process)
- [x] US-007: Robust window positioning (UI Automation for profile detection)
- [x] US-008: Poll-based window launch (100ms polling, 5s timeout)
- [x] US-009: Diagnostic logging ($env:MATRIX_DEBUG=1 to debug.log)
- [x] US-010: Consolidate key handlers (ToLower normalization, no duplicates)

### Next Phase:
After hardening: Feature expansion (additional shaders, advanced effects, performance optimizations)

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
