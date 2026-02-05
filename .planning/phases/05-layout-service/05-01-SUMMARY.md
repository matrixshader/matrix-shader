---
phase: 05-layout-service
plan: 01
status: complete
subsystem: layout
tags: [layout-service, gap-adjustment, persistence, dependency-injection]
dependencies:
  requires: [02-state-persistence]
  provides: [gap-adjustment, mode-cycling, layout-persistence]
  affects: [06-tui-core]
tech-stack:
  added: []
  patterns: [dependency-injection, immutable-records]
key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/ILayoutService.cs
    - MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs
decisions:
  - "UpdateConfig calls LoadState/SaveState immediately for real-time persistence"
  - "AdjustGap clamps to 0-200 range matching PowerShell behavior"
  - "CycleMode is pure function - caller must call UpdateConfig to persist"
metrics:
  duration: "34 min"
  completed: "2026-01-27"
---

# Phase 05 Plan 01: Gap Adjustment and Mode Persistence Summary

Gap adjustment with +/-5 increments and immediate ConfigService persistence via UpdateConfig.

## What Was Built

Extended LayoutService with gap adjustment and immediate persistence:

1. **ILayoutService interface additions:**
   - `AdjustGap(LayoutConfig, int)` - adjusts gap by delta, clamped to 0-200
   - `UpdateConfig(LayoutConfig)` - persists immediately via ConfigService
   - `CycleMode(LayoutConfig)` - overload returning config with next mode

2. **LayoutService implementation:**
   - Constructor injection of `IConfigService` for state persistence
   - `AdjustGap` uses `Math.Clamp` for safe clamping (immutable record pattern)
   - `UpdateConfig` loads state, updates Layout, calls `SaveState` immediately
   - Added `MinGapSize`/`MaxGapSize` constants for clarity

## Key Implementation Details

```csharp
// AdjustGap: Pure function returning clamped config
public LayoutConfig AdjustGap(LayoutConfig current, int delta)
{
    var newGap = Math.Clamp(current.GapSize + delta, 0, 200);
    return current with { GapSize = newGap };
}

// UpdateConfig: Immediate persistence
public void UpdateConfig(LayoutConfig config)
{
    var state = _configService.LoadState();
    state = state with { Layout = config };
    _configService.SaveState(state);
}
```

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| UpdateConfig persists immediately | Context decision: "immediately on any change" |
| CycleMode is pure | Caller controls when to persist (matches TUI pattern) |
| Gap range 0-200 | Matches LayoutConfig.IsValid() constraints |
| Constructor DI for ConfigService | Standard DI pattern for testability |

## Deviations from Plan

None - plan executed exactly as written.

## Files Modified

| File | Changes |
|------|---------|
| `ILayoutService.cs` | +21 lines: 3 new method signatures with XML docs |
| `LayoutService.cs` | +45 lines: constructor, constants, 3 method implementations |

## Commits

| Hash | Message |
|------|---------|
| dfebee5 | feat(05-01): add AdjustGap and UpdateConfig to ILayoutService |
| a68923a | feat(05-01): implement AdjustGap, UpdateConfig with ConfigService DI |

## Verification Results

- [x] `dotnet build MatrixShader/src/MatrixShader.Core` succeeds
- [x] ILayoutService.cs contains AdjustGap and UpdateConfig
- [x] LayoutService.cs injects IConfigService and calls SaveState
- [x] AdjustGap clamps to 0-200 range

## Next Phase Readiness

Phase 6 TUI can now:
- Call `AdjustGap(config, +5)` or `AdjustGap(config, -5)` on key press
- Call `CycleMode(config)` on mode toggle key
- Call `UpdateConfig(newConfig)` to persist immediately
- All layout changes will survive application restart
