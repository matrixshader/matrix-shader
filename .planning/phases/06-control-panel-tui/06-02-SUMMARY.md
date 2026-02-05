---
phase: "06"
plan: "02"
subsystem: control-panel-tui
tags: [keyboard, input, key-handler, console]
dependency_graph:
  requires: []
  provides: [KeyHandler, KeyAction, ProcessKey]
  affects: [06-03, 06-04]
tech_stack:
  added: []
  patterns: [ConsoleKeyInfo processing, shift-key detection before normalization]
files:
  created:
    - MatrixShader/src/MatrixShader.Cli/Redpill/KeyHandler.cs
  modified:
    - MatrixShader/src/MatrixShader.Cli/Redpill/MatrixShader.Cli.Redpill.csproj
    - MatrixShader/src/MatrixShader.Lite/MatrixShader.Lite.csproj
decisions:
  - id: "06-02-01"
    choice: "Check uppercase KeyChar before ToLower for shift detection"
    rationale: "Matches PowerShell behavior exactly - shift combinations detected first"
    alternatives: ["Check Modifiers flag", "Use separate dictionary"]
  - id: "06-02-02"
    choice: "net8.0-windows TFM for all CLI projects"
    rationale: "Required for MatrixShader.Core compatibility (uses Windows Desktop framework)"
    alternatives: ["Multi-targeting", "Abstract Windows-specific code"]
metrics:
  duration: 7 min
  completed: 2026-01-28
---

# Phase 06 Plan 02: Key Handler Implementation Summary

KeyHandler.cs with 40+ key bindings matching PowerShell exactly, shift detection before lowercase normalization.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| ef98dfb | feat | add KeyHandler with complete key bindings |

## What Was Built

### KeyAction Enum (40+ Actions)
Complete enumeration of all Control Panel actions:
- Navigation: Tab, Quit
- Color presets: PresetGreen, PresetCyan, PresetRed, PresetPurple, PresetGold, PresetTeal
- RGB adjustments: Red/Green/Blue Increase/Decrease
- Effects: Speed, Glow, Width, Trail, Density controls
- Layer toggles: Layer1/2/3Toggle
- Window effects: TransparencyToggle, OpacityIncrease/Decrease
- Launch controls: LaunchIncrease/Decrease, Launch
- Shift combinations: LayoutCycle, SnapbackSave/Restore, PriorityToggle, GlitchToggle, MonitorChange
- Primary monitor: PrimaryIncrease/Decrease/Reset

### ProcessKey Method
Static method that processes ConsoleKeyInfo and returns KeyAction:
1. Special keys (Tab, Enter, Escape) via ConsoleKey enum
2. Shift combinations via case-sensitive KeyChar check (uppercase before ToLower)
3. All other keys via lowercase-normalized KeyChar switch expression

### Key Behavioral Match
Exactly matches PowerShell matrix_control.ps1:
- `Shift+L` -> LayoutCycle (line 174: `case 'L'`)
- `lowercase l` -> OpacityIncrease (line 225: `'l' => KeyAction.OpacityIncrease`)
- `Shift+P` -> PriorityToggle vs `lowercase p` -> Save
- All 6 shift combinations (L, S, R, P, G, M) handled before normalization

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed TFM mismatch in csproj files**
- **Found during:** Task 1 build verification
- **Issue:** MatrixShader.Cli.Redpill.csproj and MatrixShader.Lite.csproj used net8.0 TFM but MatrixShader.Core uses net8.0-windows
- **Fix:** Changed both to net8.0-windows
- **Files modified:** MatrixShader.Cli.Redpill.csproj, MatrixShader.Lite.csproj
- **Commit:** ef98dfb

## Verification

All verification criteria passed:
- [x] KeyHandler.cs compiles without errors
- [x] ProcessKey('L') returns LayoutCycle (shift+L)
- [x] ProcessKey('l') returns OpacityIncrease (lowercase l)
- [x] ProcessKey(ConsoleKey.Tab) returns Tab
- [x] All color preset keys (1-6) return correct preset action
- [x] File has 245 lines (exceeds 200 minimum)
- [x] Exports: KeyAction enum, KeyHandler class, ProcessKey method

## Success Criteria Status

- [x] KeyHandler.cs created in MatrixShader/src/MatrixShader.Cli/Redpill/
- [x] KeyAction enum has all action types (40+)
- [x] Shift+L detected before lowercase normalization
- [x] All shift combinations: L, S, R, P, G, M handled correctly
- [x] All lowercase letter keys mapped to correct actions
- [x] Special keys (Tab, Enter, Escape) handled via ConsoleKey enum

## Next Phase Readiness

Ready for 06-03 (ActionProcessor):
- KeyHandler.ProcessKey provides structured KeyAction output
- ActionProcessor can switch on KeyAction enum to execute commands
- All parameter adjustments have corresponding actions

## Key Artifacts

| Artifact | Location | Lines | Purpose |
|----------|----------|-------|---------|
| KeyHandler.cs | MatrixShader/src/MatrixShader.Cli/Redpill/ | 245 | Keyboard input to action mapping |
