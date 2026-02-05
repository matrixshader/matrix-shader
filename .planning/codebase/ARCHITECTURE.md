# Architecture

**Analysis Date:** 2026-01-25

## Pattern Overview

**Overall:** Real-time shader parameter management with hot-reload mechanism and multi-window orchestration.

**Key Characteristics:**
- Shader hot-reload via file system watching (Windows Terminal detects timestamp changes)
- Multi-window system supporting 6+ independent shader instances
- Parameter persistence via JSON files (shader colors, speeds, layer visibility)
- 4-layer identity hierarchy for robust window tracking across process cycles
- Layout engine with Pillars/Quads modes and multi-monitor support
- Centralized logging with debug mode toggle via `$env:MATRIX_DEBUG`

## Layers

**Presentation Layer (TUI):**
- Purpose: Tabbed user interface in Windows PowerShell console for controlling shader windows
- Location: `C:\Users\ehome\documents\matrix\matrix_control.ps1`
- Contains: Interactive key handlers, tab rendering, parameter adjustment UI
- Depends on: WindowIdentityService, WindowLayoutEngine, MatrixUtils, MatrixLogging
- Used by: End users via terminal input

**Setup/Configuration Layer:**
- Purpose: Initial setup wizard (Blue Pill vs Red Pill paths), shader creation, window launching
- Location: `C:\Users\ehome\documents\matrix\matrix_setup.ps1`
- Contains: Interactive wizards, preset selection, shader template instantiation
- Depends on: WindowLayoutEngine, WindowIdentityService, MatrixLogging
- Used by: First-time users or when reconfiguring

**Quick Launch Layer:**
- Purpose: Restore previous session state from disk without configuration dialog
- Location: `C:\Users\ehome\documents\matrix\bluepill.ps1`
- Contains: State file loading, default window creation, layout restoration
- Depends on: WindowLayoutEngine, WindowIdentityService, MatrixLogging
- Used by: Returning users who want instant launch

**Window Management Layer:**
- Purpose: Detect, identify, position, and track Matrix Terminal windows across reboots
- Location: `C:\Users\ehome\documents\matrix\WindowLayoutEngine.ps1`, `C:\Users\ehome\documents\matrix\WindowIdentityService.ps1`
- Contains: P/Invoke window enumeration, layout algorithms (Pillars/Quads), window positioning
- Depends on: Windows API (user32.dll), System.Windows.Forms (monitor detection)
- Used by: All entry points (control, setup, bluepill)

**Shader Management Layer:**
- Purpose: Load shader parameters from HLSL files, apply parameter changes, save shader state
- Location: `C:\Users\ehome\documents\matrix\matrix_control.ps1` (functions: Load-Shader, Save-Shader)
- Contains: HLSL parameter extraction/injection via regex, template substitution
- Depends on: File system (HLSL files), MatrixLogging
- Used by: Control panel and setup wizard

**Rendering Layer (GPU):**
- Purpose: Real-time shader execution with dynamic parameter injection
- Location: `C:\Users\ehome\documents\matrix\shaders\Matrix-1.hlsl` through `Matrix-8.hlsl`, `C:\Users\ehome\documents\matrix\shaders\Redpill-Neo.hlsl`
- Contains: HLSL pixel shaders with bit-packed Katakana glyphs, 3-layer parallax rain effect
- Depends on: Windows Terminal shader system, GPU rendering
- Used by: Windows Terminal hot-reload system

**Logging/Diagnostics Layer:**
- Purpose: Centralized diagnostic output for all components, debug mode toggle
- Location: `C:\Users\ehome\documents\matrix\MatrixLogging.ps1`
- Contains: Unified Write-MatrixLog function, color-coded console output, file logging
- Depends on: File system (debug.log)
- Used by: All other layers

**State/Configuration Layer:**
- Purpose: Persist window configuration, shader parameters, session state across reboots
- Location: `C:\Users\ehome\documents\matrix\matrix_state.json`, `C:\Users\ehome\documents\matrix\window-registry.json`, `C:\Users\ehome\documents\matrix\identity-registry.json`
- Contains: JSON serialization of layout preferences, window mappings, identity tracking
- Depends on: File system (JSON files), ConvertTo-Json/ConvertFrom-Json
- Used by: All layers for state restoration

## Data Flow

**Shader Parameter Update Flow:**

1. User presses key in control panel (e.g., `W` to increase speed)
2. Key handler calls `Adj()` function to modify in-memory shader config `$s`
3. Control panel marks dirty flag: `$dirty = $true`
4. On next Tab press or save trigger, `Save-Shader $slot $s` is called
5. `Save-Shader` performs template substitution on `$shaderTemplate`
6. Result written to `shaders/Matrix-{slot}.hlsl` via atomic write (temp + move)
7. Windows Terminal file watcher detects timestamp change
8. Windows Terminal reloads shader from disk (~100ms latency)
9. GPU executes new shader code with updated parameters
10. User sees visual change in terminal

**Multi-Window Launch Flow:**

1. User runs `matrix_setup.ps1` (Blue Pill or Red Pill path)
2. Setup wizard collects parameters (colors, count, layout mode)
3. For each window: `Write-Shader` creates shader file with injected parameters
4. Setup launches Windows Terminal with new profiles (via settings.json injection)
5. Profile names follow pattern: `Matrix-{slot}` (e.g., `Matrix-1`, `Matrix-2`)
6. Terminals launch as new processes with unique window handles
7. `WindowIdentityService.Get-AllMatrixWindows` finds all launched windows (4-layer identity hierarchy)
8. `WindowLayoutEngine.Invoke-MatrixWindowLayout` positions windows based on mode
9. Window handles mapped to shader files in `window-registry.json` for future reference
10. Control panel loads and persists this registry for next session

**Window Identity Hierarchy (4 Layers):**

1. **Launch Tracking** (fastest, <1ms): If window PID stored in runtime registry during launch
2. **Command Line** (fast, ~20ms): If process command line matches known Matrix profile pattern
3. **Title Matching** (medium, ~5ms): If window title contains shader slot number
4. **UI Automation** (slowest, 100-300ms): If all above fail, enumerate window controls to find shader path

**State Restoration Flow (bluepill.ps1):**

1. User runs `bluepill.ps1` (instant launch)
2. Reads `matrix_state.json` for `lastSlots` array
3. Creates or loads `shaders/Matrix-{slot}.hlsl` files
4. Launches Windows Terminal with stored slots
5. `WindowIdentityService` finds launched windows using identity hierarchy
6. `WindowLayoutEngine` applies saved layout mode (Pillars/Quads) with saved gap/monitor settings
7. Control panel ready with all previous parameters restored

## Key Abstractions

**Shader Template Substitution:**
- Purpose: Inject parameters into HLSL shader code at generation time
- Examples: `shaderTemplate` variable in `matrix_control.ps1`, `matrix_setup.ps1`, `bluepill.ps1`
- Pattern: String.Replace() with `{PLACEHOLDER}` tokens mapped to shader #define statements
- Used for: Dynamic parameter injection without hardcoding values

**Window Registry (Handle -> Shader File Mapping):**
- Purpose: Persistent identification of which shader controls which window handle
- Examples: `window-registry.json` (PID as key), `identity-registry.json` (profile name as key)
- Pattern: JSON hashtable serialization, updated on each window detection pass
- Used for: Fast shader-to-window lookup across sessions

**Identity Hierarchy (4-Layer Fallback):**
- Purpose: Robust window detection across process lifecycle (spawn, reboot, handle reuse)
- Examples: `Get-AllMatrixWindows` in `WindowIdentityService.ps1`
- Pattern: Try layer 1 (launch registry), fall back to layer 2 (command line), etc.
- Used for: Multi-window control when PIDs/handles change but logical identity persists

**Layout Mode Abstraction:**
- Purpose: Pluggable window positioning algorithms (Pillars, Quads, Auto)
- Examples: `Calculate-PillarsLayout`, `Calculate-QuadsLayout` in `WindowLayoutEngine.ps1`
- Pattern: Per-mode function returns array of positioning slots, `Invoke-MatrixWindowLayout` orchestrates
- Used for: Flexible multi-monitor layout without hardcoding coordinates

**P/Invoke Wrapper Classes:**
- Purpose: Safe wrapper around Windows API calls with error handling
- Examples: `WindowLayoutAPI` class in `WindowLayoutEngine.ps1`, `MatrixWindowAPI` in `WindowIdentityService.ps1`
- Pattern: Static C# class definition compiled in PowerShell via `Add-Type`
- Used for: Window enumeration (EnumWindows), positioning (SetWindowPos), property queries

## Entry Points

**matrix_control.ps1 (Control Panel):**
- Location: `C:\Users\ehome\documents\matrix\matrix_control.ps1`
- Triggers: User runs from PowerShell console
- Responsibilities: Render tabbed TUI, handle user input (arrow keys, number keys, hotkeys), update shader parameters, manage multi-window state, cycle layout modes (Shift+L)

**matrix_setup.ps1 (Setup Wizard):**
- Location: `C:\Users\ehome\documents\matrix\matrix_setup.ps1`
- Triggers: Initial setup or reconfiguration by user
- Responsibilities: Present Blue Pill vs Red Pill choice, collect parameters via wizard dialogs, create shader files, launch Windows Terminal windows, position via WindowLayoutEngine

**bluepill.ps1 (Quick Launch):**
- Location: `C:\Users\ehome\documents\matrix\bluepill.ps1`
- Triggers: User runs after first setup to restore previous session
- Responsibilities: Load `matrix_state.json`, create default shader if first run, launch terminals, restore layout settings, display Matrix banner

**bin/redpill.js (NPM Entry Point):**
- Location: `C:\Users\ehome\documents\matrix\bin\redpill.js`
- Triggers: When installed via npm: `npm install -g matrix-shader` then `redpill`
- Responsibilities: Delegate to native redpill.exe (C# application)

## Error Handling

**Strategy:** Try-catch blocks around all file I/O and JSON operations with degraded-mode fallback.

**Patterns:**
- **File Read Failures:** Catch IOException (file locked), ArgumentException (JSON malformed), generic exceptions. Log to debug.log if MATRIX_DEBUG=1, display warning to user, continue with defaults (e.g., Load-Shader returns default colors).
- **JSON Parse Errors:** Wrap `ConvertFrom-Json` in try-catch, provide defaults (e.g., Load-TerminalEffects returns opacity=100 if parse fails).
- **Window Detection Failures:** If WindowIdentityService cannot find windows, log warning but don't block. Control panel displays "0 windows" and allows manual shader editing.
- **Atomic Write Failures:** Temp file + Move-Item pattern used in Get-MatrixWindowInfo and Save-Shader. If move fails, original file untouched. Temp file cleaned up on catch.
- **Windows API Errors:** P/Invoke calls check return values and log [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() if available.

## Cross-Cutting Concerns

**Logging:**
- Framework: `Write-MatrixLog` in `MatrixLogging.ps1`
- Master switch: `$env:MATRIX_DEBUG = "1"` to enable diagnostic output
- Output: Color-coded console + file (debug.log) when enabled
- Sources: CONTROL, LAYOUT, IDENTITY, HOTKEY, SETUP, GENERAL
- Levels: DEBUG, INFO, WARN, ERROR

**Validation:**
- Shader Parameters: Regex validation in `Load-Shader` (`^\d+\.?\d*$` for floats)
- Color Values: Range clamping in `Get-ColorSwatch` (0.0-1.0 mapped to 0-255)
- Window Handles: Checked via `IsWindow()` P/Invoke before positioning

**Authentication:**
- Not applicable (local desktop application)

**Performance Optimization:**
- UI Cache: `$script:cachedWindowInfo`, `$script:cachedLayoutConfig`, `$script:cachedShaderColors` invalidated on state changes
- Multi-DLL Support: If `MatrixAPI.dll` exists, loaded instead of compiling P/Invoke class (100ms saved)
- Identity Hierarchy: Try fast layers first (launch registry, command line) before expensive UI Automation
- Batch WMI Queries: `Get-WmiObject` called once with filter instead of per-window in `WindowIdentityService`

---

*Architecture analysis: 2026-01-25*
