# Phase 06 Plan 04: ControlPanel Integration Summary

Complete ControlPanel rewrite integrating all services from Phases 1-5 with new TUI components.

## Frontmatter

```yaml
phase: 06
plan: 04
subsystem: control-panel-tui
tags: [control-panel, tui, integration, di, services]
status: complete

requires:
  - 06-01 (TuiRenderer)
  - 06-02 (KeyHandler)
  - 06-03 (TabManager)
  - 01-* (ShaderService)
  - 02-* (ConfigService)
  - 04-* (IdentityService)
  - 05-* (LayoutService)

provides:
  - Complete ControlPanel with all services integrated
  - Blocking input loop matching PowerShell
  - Pixel-perfect TUI rendering
  - Full keyboard shortcut support

affects:
  - 07-* (Window Launcher)
  - 08-* (Terminal Integration)

tech-stack:
  added: []
  patterns:
    - Dependency Injection with Microsoft.Extensions.DependencyInjection
    - Service abstraction via interfaces
    - Blocking input loop (Console.ReadKey)
    - ANSI escape codes for TUI rendering

key-files:
  modified:
    - MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs (383 lines)

decisions:
  - id: 06-04-01
    choice: Remove Spectre.Console from Program.cs
    rationale: Use raw Console.Write with ANSI for pixel-perfect PowerShell matching
  - id: 06-04-02
    choice: Blocking Console.ReadKey (not polling with KeyAvailable)
    rationale: Matches PowerShell RawUI.ReadKey behavior, simpler and more responsive
  - id: 06-04-03
    choice: LayoutConfig.Mode is string (not enum)
    rationale: JSON serialization compatibility, matches LayoutService implementation
  - id: 06-04-04
    choice: Deferred actions to Phase 7/8
    rationale: Launch, Snapback, Priority, Glitch require terminal integration

metrics:
  duration: 5 min
  completed: 2026-01-28
  tasks: 4/4
  lines_added: 219
  lines_removed: 206
```

## What Was Done

### Task 1: DI Registration Updates
- Removed Spectre.Console using statement
- Registered IIdentityService, ILayoutService in ConfigureServices
- Registered TabManager as singleton for DI
- Replaced AnsiConsole error output with raw ANSI codes

### Task 2: ControlPanel Constructor and RunAsync
- Rewrote constructor to take 6 dependencies (5 services + TabManager)
- Added identity registry cleanup on startup (CleanStaleEntries, LoadRegistry)
- Changed from polling (KeyAvailable + Delay) to blocking Console.ReadKey
- Added finally block for cleanup (SaveState, SaveRegistry, restore cursor)

### Task 3: Render Method
- Uses TuiRenderer for all output (ColorSwatch, ProgressBar, WriteParameterRow, etc.)
- Gets config from TabManager.CurrentConfig
- Displays tab bar with color swatches
- Shows RGB controls, Rain Effects, Layers sections
- Shows Window Effects (transparency/opacity)
- Shows Layout mode from state.Layout.Mode
- Shows Launch section with open window count

### Task 4: HandleKey Implementation
- Uses KeyHandler.ProcessKey to get KeyAction
- All parameter changes route through TabManager.UpdateConfig
- Color presets use correct RGB values matching PowerShell
- RGB adjustments: 0.05f increments
- Effects adjustments: 0.1f, 0.5f, 1f increments
- Layer toggles flip boolean
- Shift+L cycles layout mode and applies immediately
- Deferred actions (Snapback, Priority, Glitch, Monitor) marked with TODO

## Verification Results

- [x] Program.cs compiles without errors
- [x] All services registered in DI (IIdentityService, ILayoutService)
- [x] TabManager registered in DI
- [x] ControlPanel uses blocking Console.ReadKey
- [x] Render method uses TuiRenderer for all output
- [x] HandleKey processes all KeyAction values
- [x] Color presets match PowerShell exactly (0,1,0.3 for green, etc.)
- [x] Shift+L cycles layout mode and repositions windows
- [x] State saved on quit (finally block)
- [x] File has 383 lines (exceeds 300 minimum)

## Key Integration Points

### TuiRenderer Usage
```csharp
TuiRenderer.WriteHeader(_tabManager.CurrentSlot, _tabManager.IsDirty);
TuiRenderer.WriteTabBar(tabs, _tabManager.CurrentSlot);
TuiRenderer.WriteSectionHeader("COLOR PRESETS");
TuiRenderer.WriteColorPresets();
TuiRenderer.WriteParameterRow("Q/W", "Red", config.R.ToString("F1"), config.R, 0, 1);
TuiRenderer.WriteLayerStatus("7", "Far", config.Layer1);
TuiRenderer.WriteFooter(_launchCount, _launchCount > 0);
```

### KeyHandler Usage
```csharp
var action = KeyHandler.ProcessKey(key);
switch (action)
{
    case KeyAction.PresetGreen:
        _tabManager.UpdateConfig(config.WithColor(0f, 1f, 0.3f));
        break;
    // ... all other actions
}
```

### TabManager Usage
```csharp
var config = _tabManager.CurrentConfig;
_tabManager.SwitchToNextTab();
_tabManager.UpdateConfig(config with { R = config.R + 0.05f });
_tabManager.SaveCurrentShader();
_tabManager.SaveState();
```

### LayoutService Usage
```csharp
case KeyAction.LayoutCycle:
    var currentState = _configService.LoadState();
    var newConfig = _layoutService.CycleMode(currentState.Layout);
    _layoutService.UpdateConfig(newConfig);
    var windows = _identityService.FindMatrixWindows();
    var positions = _layoutService.CalculateLayout(windows, newConfig);
    _layoutService.ApplyLayout(positions);
    break;
```

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Hash | Message |
|------|---------|
| 595712c | feat(06-04): rewrite ControlPanel with all services integrated |

## Next Steps

Phase 06 is now complete. All TUI components are integrated:
- TuiRenderer (06-01)
- KeyHandler (06-02)
- TabManager (06-03)
- ControlPanel integration (06-04)

Ready for Phase 07 (Window Launcher) to implement:
- KeyAction.Launch (window spawning)
- KeyAction.SnapbackSave/Restore
- KeyAction.PriorityToggle
- KeyAction.GlitchToggle
- KeyAction.MonitorChange
- KeyAction.PrimaryDecrease/Increase/Reset
