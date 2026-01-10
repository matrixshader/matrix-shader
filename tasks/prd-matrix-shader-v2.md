# PRD: Matrix Shader v2 - Stability, Startup & UX Improvements

## Introduction

This PRD addresses critical bugs in the Matrix Terminal Shader's transparency/opacity system, streamlines the startup experience with a "Red Pill / Blue Pill" flow, adds intelligent multi-monitor window positioning, and improves navigation UX with arrow key selection. The current implementation has inconsistent transparency behavior across tabs and color presets, a confusing CRT toggle conflict, and a startup flow with too many prompts.

## Goals

- Fix transparency/opacity bugs so settings apply consistently across all windows and tabs
- Remove non-functional CRT effect that conflicts with Windows Terminal's built-in effect
- Streamline startup to a fast "Blue Pill" (instant launch) or "Red Pill" (full customization) choice
- Add "Knock, Knock, Neo" instant-launch option using last saved settings
- Implement intelligent multi-monitor window positioning with user customization
- Add arrow key navigation for selecting and adjusting settings while preserving existing hotkeys
- Ensure windows open at user's home directory, not system32

## User Stories

---

### Phase 1: Transparency/Opacity Bug Fixes (Priority: Critical)

---

### US-001: Audit and document current transparency behavior
**Description:** As a developer, I need to understand exactly what triggers transparency reloads and what doesn't, so I can fix the inconsistent behavior.

**Acceptance Criteria:**
- [ ] Document current transparency-related variables in shader and PowerShell
- [ ] Test and record behavior matrix: Tab1 vs Tab2, each color preset, transparency on/off, opacity values
- [ ] Identify which actions trigger shader reload vs which don't
- [ ] Document findings in a test report
- [ ] Identify root cause of "can't return to black background" bug

---

### US-002: Normalize transparency value range
**Description:** As a user, I want transparency values to be consistent (0-100 integer) so the controls are predictable.

**Acceptance Criteria:**
- [ ] Transparency/opacity uses 0-100 integer range (not 0.0-1.0 decimal)
- [ ] All presets updated to use integer values
- [ ] Shader correctly interprets integer values
- [ ] UI displays values as integers
- [ ] Typecheck/lint passes

---

### US-003: Fix transparency toggle (on/off)
**Description:** As a user, I want the transparency toggle to reliably switch between transparent and solid black background.

**Acceptance Criteria:**
- [ ] Transparency OFF = solid black background (opacity 100%, no transparency)
- [ ] Transparency ON = user-defined opacity level applies
- [ ] Toggle works consistently regardless of current tab or color preset
- [ ] State persists correctly when switching between tabs
- [ ] Shader regenerates correctly on toggle

---

### US-004: Fix color preset transparency defaults
**Description:** As a user, I want all color presets to start with solid black backgrounds unless I explicitly enable transparency.

**Acceptance Criteria:**
- [ ] Green preset: solid black background by default
- [ ] Cyan preset: solid black background by default (currently has unwanted transparency)
- [ ] Gold preset: solid black background by default
- [ ] All other presets: solid black background by default
- [ ] Transparency only activates when user explicitly enables it

---

### US-005: Ensure consistent transparency across all tabs/windows
**Description:** As a user, I want all Matrix windows to have identical transparency settings when I configure them.

**Acceptance Criteria:**
- [ ] Tab 1 and Tab 2 show identical transparency when same settings applied
- [ ] Windows Terminal settings.json updated correctly for all profiles
- [ ] Opacity value applies identically across all spawned windows
- [ ] No phantom transparency on tabs that should be solid

---

### US-006: Remove CRT effect entirely
**Description:** As a user, I don't want the broken CRT effect that conflicts with Windows Terminal's built-in effect.

**Acceptance Criteria:**
- [ ] Remove CRT_ENABLED parameter from shader
- [ ] Remove CRT toggle (Shift+F10) from PowerShell controller
- [ ] Remove CRT-related UI elements from TUI
- [ ] Shift+F10 no longer triggers any effect swap
- [ ] Shader compiles and runs without CRT code
- [ ] Remove any "Note about reloading" since settings reload automatically

---

### Phase 2: Startup & Window Positioning (Priority: High)

---

### US-007: Add "Knock, Knock, Neo" instant launch
**Description:** As a user, I want to instantly launch Matrix with my last settings by selecting "Knock, Knock, Neo" at startup.

**Acceptance Criteria:**
- [ ] "Knock, Knock, Neo" appears as first option after Wake Up Neo banner
- [ ] Selecting it loads last saved settings from config file
- [ ] Windows spawn immediately with saved settings (no confirmation, no further prompts)
- [ ] Launch begins instantly upon selection - no "Loading..." message or delay
- [ ] If no saved settings exist, falls back to defaults and launches immediately
- [ ] Settings file persists between sessions

---

### US-008: Implement Red Pill / Blue Pill startup flow
**Description:** As a user, I want a streamlined startup with "Blue Pill" (quick launch with defaults) or "Red Pill" (full customization wizard).

**Acceptance Criteria:**
- [ ] After Wake Up Neo banner, show three options:
  1. "Knock, Knock, Neo" (instant launch with last settings)
  2. "Blue Pill" (launch with defaults or quick preset selection)
  3. "Red Pill" (full customization wizard)
- [ ] Blue Pill: Pick color preset → Pick transparency mode (Solid/Transparent/Custom opacity) → Launch
- [ ] Red Pill: Full wizard with all settings (colors, effects, layers, transparency, window layout)
- [ ] Remove intermediate "Do you want to edit? y/n" prompts
- [ ] Single decision point at end of Blue Pill: "Edit more? (Red Pill) or Enter Matrix?"

---

### US-009: Fix startup directory
**Description:** As a user, I want Matrix windows to open at my home directory, not system32.

**Acceptance Criteria:**
- [ ] Windows open at `C:\Users\<username>` (dynamic based on signed-in user)
- [ ] Works correctly regardless of where matrix_tool.ps1 is launched from
- [ ] Uses `$env:USERPROFILE` or equivalent for portability
- [ ] All spawned windows start at user home directory

---

### US-010: Detect monitors and suggest optimal layout
**Description:** As a user, I want the system to detect my monitors and suggest an optimal window layout.

**Acceptance Criteria:**
- [ ] Detect number of connected monitors
- [ ] Detect resolution/dimensions of each monitor
- [ ] Calculate optimal window count and positioning
- [ ] Default suggestion: full-height windows, side-by-side, with small center gap
- [ ] Display detected configuration to user: "Detected: 2 monitors (1920x1080 each). Suggested: 2 windows per monitor"

---

### US-011: Implement window positioning system
**Description:** As a user, I want Matrix windows positioned automatically based on my chosen layout.

**Acceptance Criteria:**
- [ ] Windows spawn at full screen height (top to bottom)
- [ ] Windows positioned side-by-side on each monitor
- [ ] Smart center gap sizing based on window count per monitor:
  - 2 windows per monitor: ~150px gap
  - 3 windows per monitor: ~75px gap
  - Scale proportionally to avoid excessive gaps
- [ ] 2 monitors + 4 windows = 2 windows per monitor
- [ ] Windows don't overlap the center gap
- [ ] YouTube/videos behind transparent windows remain "visible" to the system (don't auto-pause)
- [ ] Mixed monitor sizes: scale windows proportionally for uniform appearance
- [ ] Example: 4K monitor windows are proportionally larger than 1080p monitor windows

---

### US-012: Add window layout customization to Red Pill wizard
**Description:** As a user taking the Red Pill, I want to customize window layout beyond the suggested default.

**Acceptance Criteria:**
- [ ] Option to change number of windows
- [ ] Option to change gap size (or disable gap)
- [ ] Option to select which monitors to use
- [ ] Option to choose full-screen (no gap) vs side-by-side layout
- [ ] Preview of layout before launching (ASCII diagram or description)
- [ ] "Reset to Defaults" option to restore all settings to factory defaults
- [ ] Settings saved for "Knock, Knock, Neo" instant launch

---

### Phase 3: Navigation UX Improvements (Priority: Medium)

---

### US-013: Add cursor/selection highlight to settings lists
**Description:** As a user, I want to see which setting is currently selected with a visual highlight, and immediately be able to adjust it.

**Acceptance Criteria:**
- [ ] Current Color section: selected line highlighted in different color
- [ ] Main Effects Settings: selected line highlighted
- [ ] Layers section: selected line highlighted
- [ ] Only one line highlighted at a time per section
- [ ] Highlight color is distinct and visible (e.g., inverse or cyan background)
- [ ] Selection is automatic - no Enter key needed to "activate" a setting
- [ ] Arrow left/right immediately adjusts the currently highlighted setting
- [ ] Selected text must be obviously visually distinct from unselected text

---

### US-014: Implement Up/Down arrow navigation
**Description:** As a user, I want to move selection up and down through settings using arrow keys.

**Acceptance Criteria:**
- [ ] Up arrow moves selection to previous item in current section
- [ ] Down arrow moves selection to next item in current section
- [ ] Selection wraps at top/bottom of section (or stops at boundary)
- [ ] Works in Current Color section
- [ ] Works in Main Effects Settings section
- [ ] Works in Layers section

---

### US-015: Implement Left/Right arrow value adjustment
**Description:** As a user, I want to adjust the selected setting's value using left/right arrows.

**Acceptance Criteria:**
- [ ] Left arrow decreases value (like current key bindings)
- [ ] Right arrow increases value (like current key bindings)
- [ ] Visual bar/slider updates in real-time
- [ ] Shader regenerates on value change
- [ ] Works for all adjustable parameters (speed, density, glow, opacity, etc.)

---

### US-016: Add +/- keys as alternative adjustment
**Description:** As a user, I want Plus and Minus keys to work the same as the current letter key bindings.

**Acceptance Criteria:**
- [ ] Plus (+) key increases selected value (same as E, D, C, etc.)
- [ ] Minus (-) key decreases selected value (same as R, F, V, etc.)
- [ ] Works on currently highlighted/selected setting
- [ ] Consistent increment/decrement amounts with existing bindings

---

### US-017: Preserve existing key bindings alongside new navigation
**Description:** As a power user, I want to keep using the existing letter key bindings (E/R, D/F, C/V) for quick adjustments.

**Acceptance Criteria:**
- [ ] All existing key bindings continue to work
- [ ] E/R, D/F, C/V still adjust their respective parameters directly
- [ ] Tab still cycles through tabs
- [ ] Layer toggles (1, 2, 3) still work
- [ ] No conflicts between arrow navigation and existing bindings
- [ ] Help/legend updated to show both control schemes

---

### US-018: Keep Tab key for tab/preset navigation
**Description:** As a user, I want Tab to continue cycling through tabs and color presets.

**Acceptance Criteria:**
- [ ] Tab cycles through main tabs (Effects, Colors, etc.)
- [ ] Tab works for color preset selection
- [ ] Arrow keys don't interfere with Tab behavior
- [ ] Clear visual indication of current tab

---

## Functional Requirements

### Transparency/Opacity
- FR-1: Transparency values must be integers 0-100, not decimals
- FR-2: Transparency OFF must result in solid black background (opacity 100)
- FR-3: All color presets must default to solid black background
- FR-4: Transparency settings must apply identically to all tabs and windows
- FR-5: Shader must regenerate correctly on any transparency change

### CRT Removal
- FR-6: Remove all CRT-related code from shader and PowerShell
- FR-7: Shift+F10 must not trigger any effect toggle

### Startup Flow
- FR-8: Display three options after banner: Knock Knock Neo, Blue Pill, Red Pill
- FR-9: "Knock, Knock, Neo" loads and launches with last saved settings
- FR-10: "Blue Pill" provides quick preset selection then launches
- FR-11: "Red Pill" opens full customization wizard
- FR-12: Settings must persist to config file for future sessions
- FR-13: All windows must open at user's home directory (`$env:USERPROFILE`)

### Window Positioning
- FR-14: Detect connected monitors and their resolutions
- FR-15: Calculate and suggest optimal window layout
- FR-16: Default layout: full-height, side-by-side, with center gap per monitor
- FR-17: Center gap must scale with window count (150px for 2 windows, 75px for 3, etc.)
- FR-18: Support customization of window count, gap size, monitor selection
- FR-19: Save layout preferences for instant launch
- FR-20: Windows must scale proportionally across mixed-size monitors for uniform appearance

### Navigation
- FR-21: Up/Down arrows navigate between settings in a section
- FR-22: Left/Right arrows adjust selected setting's value (automatic, no Enter required)
- FR-23: Plus/Minus keys adjust selected setting's value
- FR-24: Selected setting must be visually highlighted with distinct color
- FR-25: All existing key bindings must continue to function
- FR-26: Tab must continue to work for tab/preset cycling
- FR-27: Red Pill wizard must include "Reset to Defaults" option

## Non-Goals (Out of Scope)

- No CRT shader effect (removed entirely, not fixed)
- No Windows Terminal built-in CRT integration
- No automatic video detection/handling (gap is manual workaround)
- No per-window individual settings (all windows share same settings)
- No Linux/macOS support in this version (Ghostty port is separate future work)
- No animated startup sequence beyond text prompts
- No sound effects

## Technical Considerations

### Transparency Bug Investigation Areas
- Windows Terminal `settings.json` opacity values (acrylic vs standard opacity)
- Shader `#define` regeneration timing
- Profile-specific vs global transparency settings
- Potential race condition between PowerShell file write and Terminal reload

### Window Positioning Implementation
- Use PowerShell `Add-Type` with Windows API for window positioning
- `GetMonitorInfo`, `EnumDisplayMonitors` for monitor detection
- `SetWindowPos` for positioning spawned windows
- May need small delay after spawn before positioning

### Settings Persistence
- JSON config file at `$env:USERPROFILE\.matrix-shader\config.json`
- Store: color preset, transparency mode, opacity value, window layout, custom colors

### Existing Code to Preserve
- All current key bindings in `matrix_tool.ps1`
- Shader glyph system and layer rendering
- Hot-reload mechanism via file timestamp

## Success Metrics

- Transparency toggle works 100% of the time (on→off→on cycle)
- All color presets launch with identical solid black backgrounds
- "Knock, Knock, Neo" launches in under 2 seconds
- Window positioning works correctly on 1, 2, and 3+ monitor setups
- Zero reports of "stuck transparent" or "can't return to black" bugs
- Startup flow reduced from 4+ prompts to maximum 2 decisions

## Resolved Questions

1. **Center gap width:** Smart scaling - 150px for 2 windows per monitor, 75px for 3 windows, proportionally scaled
2. **"Knock, Knock, Neo" confirmation:** No confirmation - launches immediately
3. **Arrow navigation activation:** Selection is automatic - no Enter key needed, arrow left/right immediately adjusts
4. **Reset to Defaults:** Yes, included in Red Pill wizard
5. **Mixed monitor sizes:** Proportional scaling for uniform appearance across different resolutions
