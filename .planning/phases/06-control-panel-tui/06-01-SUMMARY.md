---
phase: 06-control-panel-tui
plan: 01
subsystem: tui-rendering
tags: [ansi, console, rendering, pixel-perfect]
dependency-graph:
  requires: []
  provides: [TuiRenderer]
  affects: [06-02, 06-03, 06-04]
tech-stack:
  added: []
  patterns: [static-class, ansi-escape-codes, raw-console-write]
key-files:
  created:
    - MatrixShader/src/MatrixShader.Cli/Redpill/TuiRenderer.cs
  modified: []
decisions:
  - id: "06-01-01"
    choice: "Raw Console.Write with ANSI escape codes instead of Spectre.Console"
    rationale: "Pixel-perfect output matching PowerShell - same spacing, bar widths, color positions"
metrics:
  duration: "2 min"
  completed: "2026-01-28"
---

# Phase 6 Plan 01: TUI Renderer Summary

Static rendering methods for pixel-perfect TUI output matching PowerShell format using raw ANSI escape codes.

## One-Liner

TuiRenderer static class with ANSI escape codes for ColorSwatch, ProgressBar, and WriteParameterRow matching PowerShell output exactly.

## What Was Built

### TuiRenderer.cs (192 lines)

Static class in `MatrixShader.Cli.Redpill` namespace with:

**ANSI Escape Code Constants:**
- ESC, RESET, GREEN, GRAY, YELLOW, CYAN, RED, WHITE, DIM

**Core Rendering Methods:**
1. `ColorSwatch(r, g, b, width)` - RGB background color blocks using `\x1b[48;2;R;G;Bm`
2. `ProgressBar(val, min, max, width)` - Green filled `===` + gray empty `---` bar
3. `WriteParameterRow(keys, label, value, val, min, max)` - Formatted row with 4-char left-padded value
4. `WriteLayerStatus(key, name, enabled)` - Color-coded ON/off toggle display
5. `WriteSectionHeader(title)` - White text section titles

**Tab and Preset Methods:**
6. `WriteTabBar(tabs, activeSlot)` - Active tab in yellow brackets, inactive in gray, with swatches
7. `WriteColorPresets()` - Numbered color swatches for preset selection
8. `WriteHeader(slot, dirty)` - Title line with dirty indicator
9. `WriteFooter(launchCount, canLaunch)` - Launch and save controls

### Key Patterns

**PowerShell Matching:**
- ColorSwatch produces `\x1b[48;2;R;G;Bm  \x1b[0m` (spaces as colored block)
- ProgressBar produces `\x1b[32m===\x1b[90m---\x1b[0m` (green/gray bar)
- Values left-padded to 4 chars: `{value,4}`
- Labels right-padded to 8 chars: `{label,-8}`

**No Dependencies:**
- Uses only `System.Console` and `System.Math`
- No Spectre.Console in TuiRenderer
- All methods static for simple usage

## Deviations from Plan

None - plan executed exactly as written.

## Must-Haves Verification

| Requirement | Status |
|-------------|--------|
| Color swatches display as colored blocks matching PowerShell | PASS - uses `\x1b[48;2;R;G;Bm` |
| Progress bars render with green filled/gray empty | PASS - uses `\x1b[32m` and `\x1b[90m` |
| Parameter values left-padded to 4 chars | PASS - uses `{value,4}` format |
| TuiRenderer.cs min 100 lines | PASS - 192 lines |
| Exports ColorSwatch, ProgressBar, WriteParameterRow, WriteLayerStatus | PASS |
| ANSI escape codes pattern `\x1b[` | PASS - 10 occurrences |

## Commits

| Hash | Message |
|------|---------|
| dc07786 | feat(06-01): add TuiRenderer with ANSI escape code rendering |

## Next Phase Readiness

Ready for 06-02 (ControlPanelState) - TuiRenderer provides all rendering primitives needed for the ControlPanel.

## Files

```
MatrixShader/src/MatrixShader.Cli/Redpill/
  TuiRenderer.cs (192 lines) - NEW
```
