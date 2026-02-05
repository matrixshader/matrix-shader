# External Integrations

**Analysis Date:** 2026-01-25

## APIs & External Services

**GitHub:**
- Repository: `github.com/matrixshader/matrix-shader`
- Issue tracking integration (referenced in package.json)

**Windows Terminal:**
- Shader hot-reload via file timestamp monitoring
- Direct3D shader compilation and GPU rendering
- Windows Terminal settings.json modification for shader integration
- Profile detection via UI Automation (Terminal window profile name)

## Data Storage

**Databases:**
- Not applicable - No remote database integration

**File Storage:**
- Local filesystem only
  - Project root: `C:\Users\ehome\Documents\Matrix\`
  - Shader files: `C:\Users\ehome\Documents\Matrix\shaders\`
  - State persistence: JSON files in project directory

**Configuration Files (JSON):**
- `matrix_state.json` - Multi-window state (slots, layout mode, monitor config)
  - Format: `{ lastSaved, lastSlots[], layout{} }`
- `window-registry.json` - Shader-to-window instance mapping
  - Format: Registry of window handles → shader assignments
- `identity-registry.json` - Window identity cache for launch tracking
  - Format: `{ LaunchRegistry with ProcessId → ProfileName, LaunchTime, CorrelationId }`
- `config/slots.json` - Slot configuration storage

**Caching:**
- In-memory cache for identity resolution (Launch Tracking Registry)
- No external cache service

## Authentication & Identity

**Auth Provider:**
- None - Standalone desktop application
- No user authentication required

**Window Identity Resolution:**
4-layer hierarchy (implemented in `WindowIdentityService.ps1`):
1. Launch Tracking - ProcessId correlation (< 1ms, instant)
2. Command Line Analysis - WMI query for window process arguments (~20ms)
3. Title Matching - EnumWindows title pattern (Matrix-N) (~5ms)
4. UI Automation Fallback - Direct profile detection from Terminal element (100-300ms)

## Monitoring & Observability

**Error Tracking:**
- Not integrated with external service
- Local diagnostic logging only

**Logs:**
- Unified logging via `MatrixLogging.ps1`
- File: `debug.log` in project root
- Activation: `$env:MATRIX_DEBUG=1`
- Sources tracked: CONTROL, LAYOUT, IDENTITY, HOTKEY, SETUP, GENERAL
- Levels: DEBUG, INFO, WARN, ERROR
- Format: Timestamped, color-coded, component-tagged

## Windows API Integration

**Windows User32.dll Functions:**
- `EnumWindows()` - Window enumeration for detection and positioning
- `SetWindowPos()` - Window positioning (P/Invoke in `WindowLayoutEngine.ps1`)
- `GetWindowText()` - Window title retrieval
- `GetWindowRect()` - Window boundary detection
- `SetWindowLong()` - Window style manipulation
- `ShowWindow()` / `IsIconic()` - Window state management
- `GetWindowThreadProcessId()` - Process identification

**Windows Shell Integration:**
- `EnumDisplayMonitors()` - Multi-monitor detection (P/Invoke)
- System.Windows.Forms.Screen - Monitor topology detection

**Windows Registry:**
- Registry-based shader-to-window mapping persistence
- P/Invoke declarations in `MatrixAPI.dll` or inline C# type definitions

**UI Automation:**
- UIAutomationCore for Windows Terminal profile detection
- Reads TermControl element properties to identify active shader profile
- Implemented in `WindowIdentityService.ps1`: `Get-ProfileFromUIAutomation()`

## Windows Terminal Integration

**File Integration:**
- Settings file: `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
- Read/Write operations with atomic safety (Move-Item -Force)
- JSON error handling with try-catch blocks

**Shader Path Configuration:**
- Windows Terminal profiles configured with shader paths pointing to:
  - `C:\Users\ehome\Documents\Matrix\shaders\Matrix-1.hlsl` through Matrix-8.hlsl
  - `C:\Users\ehome\Documents\Matrix\shaders\Redpill-Neo.hlsl`

**Hot-Reload Mechanism:**
- PowerShell modifies shader `#define` constants
- Touches file timestamp → Windows Terminal detects change
- Auto-reloads shader (~100ms latency)
- No explicit API call needed

## Inter-Process Communication

**Multi-Window Control:**
- Window detection via EnumWindows P/Invoke
- Window positioning via SetWindowPos P/Invoke
- Process identification via GetWindowThreadProcessId

**Hotkey System:**
- Global hotkey registration (implemented in `matrix_hotkeys.ps1`)
- Hotkeys:
  - `Win+Alt+Left/Right` - Swap windows
  - `Win+Alt+L` - Change layout (Pillars/Quads/Auto)
  - `Win+Alt+B` - Toggle transparency
  - `Win+Alt+J/K` - Adjust opacity
  - `Shift+S/R/P` - Smart window management (in control panel)

## Webhooks & Callbacks

**Incoming:**
- None - Standalone desktop application

**Outgoing:**
- None - No external service calls

## Build & Release Pipeline

**Hosting:**
- npm registry - npm install -g matrix-shader
- GitHub - Source distribution

**CI Pipeline:**
- Not detected
- Manual release process via npm publish

## Entry Points & Distribution

**CLI Commands:**
- `wakeupneo` - Setup wizard (spawns bin/native/wakeupneo.exe)
- `bluepill` - Instant launch (spawns bin/native/bluepill.exe)
- `redpill` - Control panel (spawns bin/native/redpill.exe)
- `matrix-hotkeys` - Global hotkey manager (background service)

**JavaScript Wrapper Pattern:**
All commands follow the same pattern (`bin/*.js`):
```javascript
const { spawn } = require('child_process');
const path = require('path');
const exe = path.join(__dirname, 'native', '[command].exe');
const child = spawn(exe, process.argv.slice(2), { stdio: 'inherit' });
child.on('exit', (code) => process.exit(code || 0));
```

## Environment Requirements

**Required Environment Variables:**
- `$env:USERPROFILE` - User home directory
- `$env:LOCALAPPDATA` - Windows Terminal settings location

**Optional Environment Variables:**
- `$env:MATRIX_DEBUG=1` - Enable diagnostic logging to `debug.log`

**Secrets Storage:**
- Not applicable - No API keys or credentials required
- All configuration is file-based in user's Documents

## Multi-Monitor Support

**Detection Method:**
- System.Windows.Forms.Screen enumeration
- P/Invoke EnumDisplayMonitors for advanced topology

**Layout Modes:**
- Pillars Layout - Side-by-side columns per monitor
- Quads Layout - 2x2 grid per monitor
- Auto Layout - Intelligent fallback based on monitor count

**State Persistence:**
- Monitor count saved to `matrix_state.json`
- Gap size configuration: 30px default
- Max pillars per screen: 4 (configurable)

---

*Integration audit: 2026-01-25*
