# Feature Landscape

**Domain:** Terminal Shader Control Application (C# Port)
**Researched:** 2026-01-25
**Source:** Analysis of working PowerShell implementation

## Table Stakes

Features users expect from the C# port. Missing = regression from PowerShell version.

### Shader Parameter Control

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| RGB color adjustment | Core feature - users change rain color | Low | `matrix_control.ps1` lines 1094-1108 (Q/W/A/S/Z/X keys) |
| Color presets | Quick access to predefined colors | Low | `matrix_control.ps1` lines 1094-1100 (1-6 keys) |
| Speed control | Fundamental shader parameter | Low | `Adj 'Speed'` function |
| Glow strength | Visual impact control | Low | `Adj 'Glow'` function |
| Character width | Density appearance | Low | `Adj 'Width'` function |
| Trail length | Rain aesthetic control | Low | `Adj 'Trail'` function |
| Rain density | Column frequency | Low | `Adj 'Dens'` function |
| Layer toggles (Far/Mid/Near) | Parallax depth control | Low | Keys 7/8/9 toggle L1/L2/L3 |
| Dirty state tracking | User knows unsaved changes | Low | `$dirty` flag with `*` indicator |
| Auto-save on tab switch | Prevent lost changes | Low | `matrix_control.ps1` lines 929-943 |

### Multi-Window Management

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| Tab switching between windows | Navigate open shaders | Low | TAB key, lines 929-946 |
| Window count display | Know which windows are open | Low | `Get-OpenMatrixSlots` function |
| Launch new windows | Expand from control panel | Medium | `Launch-MatrixWindows` function |
| Slot assignment (1-8) | Predictable shader mapping | Low | `$availableSlots` logic |
| Window launch timeout handling | Graceful failure | Medium | `Wait-ForNewMatrixWindow` with 5s timeout |

### Window Layout Engine

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| Pillars layout | Vertical columns side-by-side | Medium | `Get-PillarsLayout` function |
| Quads layout | 2x2 grid with plus-gap | Medium | `Get-QuadsLayout` function |
| Layout mode cycling | Toggle between modes | Low | Shift+L hotkey |
| Gap size configuration | Spacing between windows | Low | `$config.GapSize` (default 30px) |
| Multi-monitor support | Distribute across screens | High | `Get-ScreenTopology`, `Get-WindowDistributionWithPrimary` |
| Primary monitor control | Choose window distribution | Medium | `WindowsOnPrimary` setting, `</>` keys |
| Auto-reduce columns | Handle narrow screens | Medium | `minWindowWidth = 475` constraint |
| Preserve monitors on mode change | Keep windows on current screens | Medium | `-PreserveMonitors` flag |

### Window Identity Tracking

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| Launch tracking (Layer 1) | Instant ID for spawned windows | Medium | `Register-MatrixWindowByHandle` |
| Command line parsing (Layer 2) | Profile from wt.exe args | Medium | `Get-CommandLineIdentities` WMI query |
| Title matching (Layer 3) | Pattern match window titles | Low | `Get-TitleIdentity` regex |
| UI Automation fallback (Layer 4) | TermControl element inspection | High | `Get-UIAutomationIdentity` |
| Confidence scoring | Know identity reliability | Low | `Confidence` field (0.0-1.0) |
| Registry persistence | Cross-session identity | Medium | `identity-registry.json` |

### State Persistence

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| Shader config persistence | Hot-reload mechanism | Low | HLSL file write with #define values |
| Session state save | Remember open slots | Low | `matrix_state.json` |
| Position persistence | Restore window positions | Medium | `Save-WindowPositions`, `Restore-WindowPositions` |
| Layout config persistence | Remember mode/gap settings | Low | `layout` section in state file |
| Atomic writes (temp+move) | Prevent corruption | Low | US-001 pattern throughout |

### Terminal Integration

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| Profile creation | Matrix-1 through Matrix-8 | Medium | `install.ps1` lines 164-187 |
| Shader path configuration | Profile -> .hlsl mapping | Low | `experimental.pixelShaderPath` |
| Tab color sync | Match tab to shader color | Medium | `Sync-TabColorToShader` function |
| Background transparency | See through window | Low | `opacity` profile setting, B key toggle |
| Opacity slider | Fine-tune transparency | Low | K/L keys when transparency enabled |

### User Experience

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| TUI control panel | Interactive parameter editing | Medium | `UI` function in matrix_control.ps1 |
| Color swatches | Visual color preview | Low | `Get-ColorSwatch` ANSI escape sequence |
| Progress bars | Visual slider indicators | Low | `Bar` function |
| Setup wizard | First-time configuration | Medium | `matrix_setup.ps1` |
| Blue Pill path | Quick launch | Low | `bluepill.ps1` |
| Red Pill path | Full customization | Medium | matrix_setup.ps1 -> matrix_control.ps1 |
| Restore previous session | Resume last state | Low | `Load-MatrixState` function |

### Error Handling

| Feature | Why Expected | Complexity | PowerShell Reference |
|---------|--------------|------------|----------------------|
| JSON parse error handling | Graceful degradation | Low | US-002 pattern (try-catch) |
| Settings.json lock handling | Detect WT file lock | Low | `[System.IO.IOException]` catch |
| Shader validation | Reject malformed values | Low | Regex validation in `Load-Shader` |
| Diagnostic logging | Debug support | Low | `MatrixLogging.ps1`, `$env:MATRIX_DEBUG` |

## Differentiators

Features where C# can exceed PowerShell capabilities.

### Performance Improvements

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Native Windows API | No Add-Type compilation delay | Medium | Pre-compiled P/Invoke vs. runtime Add-Type |
| Faster startup | No PowerShell interpreter overhead | Low | C# native execution |
| Efficient WMI queries | Better async/batching | Medium | System.Management direct access |
| Reduced memory footprint | No PS runtime | Low | C# is leaner for system utilities |
| Background monitoring | Proper async/await | Medium | vs. PowerShell jobs |

### Better Platform Integration

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Single executable distribution | No script execution policy issues | Medium | Self-contained deployment |
| System tray integration | Minimize to tray | Medium | NotifyIcon support |
| Global hotkeys | System-wide shortcuts | High | RegisterHotKey P/Invoke |
| Better UI Automation | Direct UIAutomation API | Medium | No assembly load overhead |
| Cross-platform potential | .NET 8 MAUI for MacOS/Linux | High | Future consideration |

### Enhanced Features

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| MatrixLite text fallback | Work without Windows Terminal | High | ASCII art Matrix rain for any terminal |
| Real-time preview | See changes before applying | Medium | Miniature shader preview |
| Undo/redo stack | Revert parameter changes | Medium | Command pattern implementation |
| Preset management | Save/load custom configurations | Low | Named presets beyond 1-6 |
| Import/export settings | Share configurations | Low | JSON/clipboard support |
| Multi-language support | Localization | Medium | Resource files |
| Plugin system | User-contributed shaders | High | Dynamic shader loading |

### Reliability Improvements

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Proper error types | Typed exceptions vs. string errors | Low | Exception hierarchy |
| Unit testable | Dependency injection | Medium | Interface-based design |
| Configuration validation | Schema validation | Low | Strong typing |
| Crash recovery | Handle-based state restoration | Medium | Registry-based recovery |
| Watchdog for window monitor | Auto-restart background monitor | Low | Process monitoring |

## Anti-Features

Features to explicitly NOT build in the C# port.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| GUI application | Defeats terminal-native aesthetic | Keep TUI/console-based interaction |
| Auto-update mechanism | Complexity, security concerns | Manual npm/release update |
| Cloud sync | Unnecessary complexity | Local file persistence only |
| Telemetry | Privacy concerns, unnecessary | None |
| Shell profile modification | Dangerous, varies by shell | Document PATH addition only |
| WT settings global modification | Can break user config | Only modify Matrix profiles |
| Admin privilege requirement | Limits accessibility | User-space only operations |
| Custom shader compilation | GPU driver dependency | Use pre-tested shaders only |
| Window focus stealing | Annoying UX | Never activate/focus windows automatically |
| Blocking UI operations | Freezes feel broken | Async for all long operations |

## Feature Dependencies

```
Core Infrastructure
├── Windows API (P/Invoke)
│   ├── Window Enumeration (EnumWindows)
│   ├── Window Positioning (SetWindowPos, GetWindowRect)
│   └── Screen Detection (EnumDisplayMonitors)
│
├── Terminal Integration
│   ├── settings.json Parser
│   │   ├── Profile Management
│   │   └── Shader Path Configuration
│   └── HLSL File Generator
│       └── Hot-Reload Mechanism
│
└── State Management
    ├── matrix_state.json
    ├── identity-registry.json
    └── window-registry.json

Feature Layers (build in order)
Phase 1: Core Infrastructure
├── P/Invoke declarations
├── Settings.json parser
└── HLSL file generation

Phase 2: Shader Control
├── Parameter adjustment
├── Color presets
└── Layer toggles

Phase 3: Window Management
├── Window identity service
├── Layout engine
└── Position persistence

Phase 4: TUI Control Panel
├── Console rendering
├── Keyboard input
└── Tab switching

Phase 5: MatrixLite Fallback (differentiator)
├── ASCII art renderer
├── ANSI color support
└── Console buffer management
```

## MVP Recommendation

For MVP C# port, prioritize:

1. **Table stakes features from PowerShell** - All shader parameter controls
2. **Window layout engine** - Pillars/Quads with multi-monitor
3. **TUI control panel** - Core interactive experience
4. **State persistence** - Session continuity

Defer to post-MVP:
- MatrixLite fallback: Complex, not required for WT users
- System tray: Nice-to-have, not core
- Global hotkeys: Nice-to-have, not core
- Plugin system: Future expansion

## Feature Parity Checklist

Before release, C# must support:

- [ ] All 6 color presets
- [ ] RGB slider controls (Q/W/A/S/Z/X equivalent)
- [ ] Speed, Glow, Width, Trail, Density controls
- [ ] Layer toggles (Far/Mid/Near)
- [ ] Tab switching between open windows
- [ ] Window launch from control panel
- [ ] Pillars and Quads layout modes
- [ ] Layout mode cycling
- [ ] Multi-monitor distribution
- [ ] Gap size configuration
- [ ] Transparency toggle
- [ ] State persistence across sessions
- [ ] Window position save/restore
- [ ] Diagnostic logging
- [ ] Atomic file writes

## Sources

- `C:\Users\ehome\documents\matrix\matrix_control.ps1` - Primary control panel implementation
- `C:\Users\ehome\documents\matrix\WindowLayoutEngine.ps1` - Layout algorithms
- `C:\Users\ehome\documents\matrix\WindowIdentityService.ps1` - 4-layer identity system
- `C:\Users\ehome\documents\matrix\MatrixUtils.ps1` - Shared utilities
- `C:\Users\ehome\documents\matrix\matrix_setup.ps1` - Setup wizard
- `C:\Users\ehome\documents\matrix\bluepill.ps1` - Quick launch
- `C:\Users\ehome\documents\matrix\install.ps1` - Installation script
