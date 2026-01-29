---
phase: "08"
plan: "03"
subsystem: cli-applications
tags: ["wakeupneo", "setup-wizard", "cli", "blue-pill", "red-pill", "typewriter", "arrow-menu"]

dependency-graph:
  requires: ["08-01"]
  provides:
    - "wakeupneo.exe setup wizard"
    - "Dramatic intro with typewriter effect"
    - "Blue Pill / Red Pill choice"
    - "Color preset selection"
    - "Window launch and positioning"
  affects: ["09-packaging"]

tech-stack:
  added: []
  removed: ["Spectre.Console"]
  patterns:
    - "CliBootstrap shared utilities"
    - "Arrow-key menu selection"
    - "ANSI 24-bit color swatches"

file-tracking:
  key-files:
    created: []
    modified:
      - MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs
      - MatrixShader/src/MatrixShader.Cli/WakeupNeo/MatrixShader.Cli.WakeupNeo.csproj

decisions: []

metrics:
  duration: "12 min"
  completed: "2026-01-29"
---

# Phase 08 Plan 03: WakeupNeo Setup Wizard Summary

**One-liner:** Complete setup wizard with dramatic intro, Blue Pill / Red Pill choice, color presets, window launch, and positioning matching PowerShell matrix_setup.ps1.

## What Was Built

### 1. Dramatic Intro with Typewriter Effect
The wizard starts with the iconic Matrix intro sequence:
- "Wake up, Neo..." (100ms per character)
- "The Matrix has you..." (80ms per character)
- "Follow the white rabbit." (80ms per character)

Uses `CliBootstrap.TypewriterAsync()` with Matrix green ANSI coloring.

### 2. Previous Session Restore
Checks for existing MatrixState and offers to restore:
- Detects slots with non-default shader configs
- Displays previous window count and slot numbers
- Y/N prompt for restore vs. new configuration

### 3. Slot Collision Detection
Before new window setup:
- Calls `IIdentityService.FindMatrixWindows()` to detect open windows
- Calculates available slots (1-8 minus occupied)
- Prevents creating windows for slots already in use

### 4. Window Count and Color Selection
Interactive configuration flow:
- Asks how many NEW tabs (1 to available max)
- Per-tab color selection from 6 presets
- ANSI 24-bit color swatches rendered inline
- Color presets: Classic Green, Cyber Blue, Blood Red, Purple, Gold, Teal

### 5. Blue Pill / Red Pill Choice
Arrow-key menu using `CliBootstrap.ArrowKeyMenu()`:
- BLUE PILL: Creates shaders, launches windows, positions them
- RED PILL: Same as Blue Pill PLUS opens control panel (Redpill profile)

### 6. Shader and Profile Creation
For each configured tab:
- Creates shader via `IShaderService.WriteConfig()`
- Ensures Matrix-1 through Matrix-8 profiles exist via `ITerminalSettingsService.CreateMatrixProfiles()`
- Saves state via `IConfigService.SaveState()`

### 7. Window Launch with Identity Tracking
Poll-based launch pattern (matching PowerShell):
- Captures existing window handles before launch
- Starts `wt.exe -p "Matrix-N"` via Process.Start
- Polls for new window handle (50 attempts, 100ms interval)
- Registers new handle via `IIdentityService.RegisterWindowHandle()`

### 8. Window Positioning
After all windows launch:
- Calls `IIdentityService.FindMatrixWindows()` to get all windows
- Calculates layout via `ILayoutService.CalculateLayout()`
- Applies positions via `ILayoutService.ApplyLayout()`

### 9. Easter Eggs
Two special modes via CLI arguments:
- `--morpheus`: Additional philosophical quotes during intro
- `--agent-smith`: Chaos mode - randomizes all existing window colors and speeds

## Key Implementation Details

### Service Integration
The wizard uses full DI for services:
- IConfigService: State persistence
- IShaderService: Shader file creation
- IIdentityService: Window discovery and registration
- ILayoutService: Window positioning
- ITerminalSettingsService: Profile creation

### Removed Dependencies
Removed Spectre.Console per CONTEXT.md constraint. Using raw Console API with ANSI escape codes instead:
- `\x1b[32m` for Matrix green text
- `\x1b[48;2;R;G;Bm` for 24-bit background color swatches
- `\x1b[0m` for reset

### Error Handling
- Bootstrap failure returns exit code 1
- User cancel (Escape) returns exit code 2
- Window launch timeout shows "TIMEOUT" but continues
- All slots occupied shows message and exits gracefully

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 19ed7e3 | feat | Rewrite WakeupNeo with setup wizard |
| 648f696 | chore | Remove Spectre.Console from WakeupNeo |

## Verification Results

- [x] Build succeeds without Spectre.Console
- [x] Program.cs has 602 lines (min: 400)
- [x] Uses CliBootstrap (13 usages)
- [x] Uses IShaderService.WriteConfig (2 usages)
- [x] Uses ITerminalSettingsService.CreateMatrixProfiles (1 usage)
- [x] Uses ILayoutService.ApplyLayout (1 usage)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DiagnosticLogger.Initialize parameter name**
- **Found during:** Task 1
- **Issue:** Plan used `DiagnosticLogger.Initialize(enabled: true)` but actual API is `DiagnosticLogger.Initialize(bool)`
- **Fix:** Changed to positional parameter `DiagnosticLogger.Initialize(true)`
- **Files modified:** Program.cs
- **Commit:** 19ed7e3

**2. [Rule 1 - Bug] State property name**
- **Found during:** Task 1
- **Issue:** Plan used `state.LayoutConfig` but actual property is `state.Layout`
- **Fix:** Used correct property name `state.Layout`
- **Files modified:** Program.cs
- **Commit:** 19ed7e3

**3. [Rule 1 - Bug] RegisterWindowHandle signature**
- **Found during:** Task 1
- **Issue:** Plan implied `RegisterWindowHandle(handle, slot)` but actual signature is `RegisterWindowHandle(hwnd, profileName, shaderIndex)`
- **Fix:** Used full 3-parameter signature
- **Files modified:** Program.cs
- **Commit:** 19ed7e3

## Next Phase Readiness

Plan 08-03 complete. Dependencies for next plans:
- Plan 08-02 (bluepill.exe) already completed
- WakeupNeo ready for packaging phase
- All 3 CLI entry points (bluepill, redpill, wakeupneo) now implemented
