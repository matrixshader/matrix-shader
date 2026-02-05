# Phase 6: Control Panel TUI - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Interactive control panel (Redpill) matching PowerShell `matrix_control.ps1` functionality exactly. Keyboard-driven TUI for adjusting shader parameters, switching between windows, and managing state. This is a port, not a redesign.

</domain>

<decisions>
## Implementation Decisions

### Visual Fidelity
- Pixel-perfect match to PowerShell output required
- Same spacing, bar widths, color positions
- May need to bypass Spectre.Console for raw Console.Write where necessary
- `UI()` function in `matrix_control.ps1` (lines 739-890) is the visual specification

### Keyboard Shortcuts
- Match PowerShell exactly — no changes, no additions, no removals
- Key mapping from `matrix_control.ps1` switch block (lines 1093-1215):
  - Tab (VK 9): next tab with auto-save
  - Enter (VK 13): launch windows
  - Escape (VK 27): quit with state save
  - 1-6: color presets
  - Q/W, A/S, Z/X: RGB controls (-0.05/+0.05)
  - E/R, D/F, C/V, T/Y, G/H: effects controls
  - 7/8/9: layer toggles
  - B: transparency toggle, K/L: opacity adjust
  - P: save shader (lowercase)
  - 0: reset to defaults
  - -/+/=: launch count controls
  - Shift+L: layout mode cycle
  - Shift+G: glitch toggle
  - Shift+M: monitor count
  - Shift+S: save snapback
  - Shift+R: restore snapback
  - Shift+P: priority lock
  - ,/./): windows on primary controls

### Tab Interface
- Shows all detected Matrix windows (not all existing slots)
- Format: `[slot]` + color swatch for active, `slot` + swatch for inactive
- Tab key cycles through OPEN windows only
- Auto-save dirty shader before switching tabs

### Dirty State
- `$dirty` flag tracks unsaved changes
- Display as `*` after "RED PILL" in title line
- Auto-clear on save, tab switch, or quit

### Auto-Save Behavior
- Save on tab switch (before loading new tab)
- Save window positions on quit
- Save current state (open slots) on quit for Blue Pill

### Visual Components
- Color swatches: `Swatch` function — colored block characters
- Progress bars: `Bar` function — `=` filled, `-` empty, 15-char width
- Section headers: WHITE for categories (COLOR PRESETS, RAIN EFFECTS, etc.)
- Values: left-padded to 4 chars for alignment

### Console Input
- PowerShell uses `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")`
- C# equivalent: `Console.ReadKey(true)` with `ConsoleKeyInfo`
- Must handle both `VirtualKeyCode` and `Character` properties
- Case-sensitive for Shift+ combinations (check before ToLower normalization)

### Claude's Discretion
- Spectre.Console vs raw Console.Write decisions for achieving pixel-perfect output
- Internal code organization (but external behavior must match)
- Error message wording (but must show same information)

</decisions>

<specifics>
## Specific Ideas

- "The PowerShell version IS the specification" — every visual element, every key binding, every behavior is already defined in `matrix_control.ps1`
- The UI() function output is the exact visual target — replicate it character-for-character
- Key handling must preserve case sensitivity for Shift+ combinations (check `$k -ceq 'L'` pattern)
- Tab display shows color swatch from cached shader colors

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-control-panel-tui*
*Context gathered: 2026-01-27*
