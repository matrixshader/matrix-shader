---
phase: 06-control-panel-tui
plan: 03
subsystem: tui-state
tags: [tab-management, state, auto-save, dirty-tracking]
dependency_graph:
  requires: ["06-01", "06-02"]
  provides: ["TabManager", "CurrentSlot", "IsDirty", "SwitchToNextTab"]
  affects: ["06-04", "06-05"]
tech_stack:
  added: []
  patterns: ["dependency-injection", "dirty-tracking", "auto-save-on-switch"]
key_files:
  created:
    - path: MatrixShader/src/MatrixShader.Cli/Redpill/TabManager.cs
      purpose: Tab state management with auto-save and dirty tracking
  modified: []
decisions:
  - key: initialization-order
    choice: First open window takes priority over saved ActiveTab
    reason: Matches PowerShell behavior - show what's actually open
  - key: immediate-write
    choice: UpdateConfig writes to shader immediately (hot-reload)
    reason: Real-time feedback like PowerShell, dirty flag for state persistence
metrics:
  duration: 2 min
  completed: 2026-01-28
---

# Phase 06 Plan 03: TabManager Summary

Tab state management class with auto-save on tab switch, dirty tracking, and open-window-only cycling using FindMatrixWindows.

## What Was Built

Created `TabManager.cs` (178 lines) that manages:

1. **State Management**
   - `CurrentSlot` - active shader slot (1-8)
   - `CurrentConfig` - loaded ShaderConfig for current slot
   - `IsDirty` - whether config has unsaved changes

2. **Tab Cycling (PowerShell-exact)**
   - `SwitchToNextTab()` - cycles through OPEN windows only
   - Uses `FindMatrixWindows()` to get open slots
   - Auto-saves dirty config before switching
   - If current slot closed, goes to first open slot

3. **Config Updates**
   - `UpdateConfig()` - clamps values, writes immediately for hot-reload
   - `SaveCurrentShader()` - writes to shader file
   - `SaveState()` - persists to ConfigService

4. **Rendering Support**
   - `GetTabsForRendering()` - returns (slot, r, g, b) tuples for TuiRenderer.WriteTabBar

## Key Implementation Details

### Initialization Priority
```csharp
if (openWindows.Count > 0)
    _currentSlot = openWindows[0].ShaderIndex;  // First open window
else if (state.ActiveTab > 0)
    _currentSlot = state.ActiveTab;              // Saved state fallback
else
    _currentSlot = 1;                            // Default fallback
```

### Auto-save Before Tab Switch
```csharp
if (_dirty)
{
    SaveCurrentShader();  // Write to shader file
}
// Then switch to next tab
```

### Immediate Hot-reload on UpdateConfig
```csharp
_currentConfig = newConfig.Clamp();  // Validate ranges
_dirty = true;
_shaderService.WriteConfig(_currentSlot, _currentConfig);  // Hot-reload
```

## Commits

| Hash | Message |
|------|---------|
| 357b650 | feat(06-03): create TabManager class with state management |

## Verification Results

- [x] TabManager.cs compiles without errors
- [x] SwitchToNextTab calls SaveCurrentShader when _dirty is true
- [x] SwitchToNextTab uses FindMatrixWindows (not hardcoded 1-8)
- [x] UpdateConfig calls Clamp() then WriteConfig immediately
- [x] GetTabsForRendering returns list compatible with TuiRenderer.WriteTabBar
- [x] File has 178 lines (exceeds min_lines: 100)

## Key Links Verified

| From | To | Pattern | Status |
|------|-----|---------|--------|
| TabManager.cs | IIdentityService.FindMatrixWindows | `FindMatrixWindows` | Found at lines 31, 73, 100 |
| TabManager.cs | IShaderService.WriteConfig | `WriteConfig` | Found at lines 148, 159 |

## Deviations from Plan

None - plan executed exactly as written. Tasks 1 and 2 were implemented together since they define the same class.

## Next Phase Readiness

- **06-04 (RedpillLoop)**: Ready - TabManager provides all state management needed
- **Integration**: GetTabsForRendering returns format compatible with TuiRenderer.WriteTabBar

---
*Generated: 2026-01-28*
