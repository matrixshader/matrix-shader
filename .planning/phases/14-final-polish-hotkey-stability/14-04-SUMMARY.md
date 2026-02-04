---
phase: 14
plan: 04
subsystem: layout-service
tags: [layout, gaps, fullscreen, glitch]
completed: 2026-02-04
duration: ~10 minutes
requires:
  - phase-14-01 (hotkey watchdog)
provides:
  - Scaled gap calculation with minimum 20px
  - Fullscreen exclusion from glitch/snap
affects:
  - Future layout modes (Overlap, extended grid)
  - Window management interactions
tech-stack:
  added: []
  patterns:
    - Scale factor pattern for progressive value adjustment
    - Filter-before-process pattern for window state handling
key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs
    - MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs
decisions:
  - "Scale formula: 100% (1-2), 80% (3), 60% (4+)"
  - "Minimum gap 20px ensures clickable space"
  - "IsZoomed filters fullscreen before overlap check"
  - "Cooldown reset after manual layout prevents snap-back"
---

# Phase 14 Plan 04: Layout Bug Fixes Summary

Scaled gap calculation with 20px minimum for 4+ pillar layouts, fullscreen window exclusion from glitch/snap detection.

## Bugs Fixed

| Bug | Description | Fix |
|-----|-------------|-----|
| BUG-LAYOUT05 | 4+ pillar gaps too tight to click | Scaled gaps with 20px minimum |
| BUG-LAYOUT06 | F11 fullscreen snaps back immediately | Exclude fullscreen via IsZoomed |
| BUG-LAYOUT07 | Drag/snap stops after layout changes | Cooldown reset after manual layout |

## Commits

| Commit | Description | Files |
|--------|-------------|-------|
| 9adc6c5 | Implement scaled gap calculation | LayoutService.cs |
| c9bcd4c | Exclude fullscreen from glitch detection | MatrixWindowMonitor.cs |

## Implementation Details

### Task 1: Scaled Gap Calculation

Added `CalculateScaledGap` helper method to LayoutService:

```csharp
private static int CalculateScaledGap(int baseGap, int windowCount)
{
    double scaleFactor = windowCount switch
    {
        <= 2 => 1.0,
        3 => 0.8,
        _ => 0.6
    };
    int scaledGap = (int)(baseGap * scaleFactor);
    return Math.Max(scaledGap, MinScaledGap); // MinScaledGap = 20
}
```

All layout methods updated:
- CalculatePillarsLayout
- CalculateQuadsLayout
- CalculateOverlapLayout

### Task 2: Fullscreen Exclusion

Modified MatrixWindowMonitor to filter fullscreen windows:

```csharp
var tiledWindows = new List<WindowInfo>();
foreach (var window in windows)
{
    if (!WindowsApi.IsZoomed(window.Handle))
    {
        tiledWindows.Add(window);
    }
}
```

Key behaviors:
- F11 fullscreen windows no longer trigger snap-back
- Only tiled windows participate in overlap detection
- Manual layout refresh resets cooldown to prevent immediate snap-back
- Diagnostic logging shows fullscreen exclusion count

## Verification

- [x] Build both projects successfully
- [x] CalculateScaledGap method exists with 20px minimum
- [x] All three layout methods use CalculateScaledGap
- [x] MatrixWindowMonitor filters out fullscreen windows with IsZoomed
- [x] Diagnostic logging present for fullscreen exclusion
- [x] Cooldown reset after TriggerLayoutRefresh

## Files Modified

1. **MatrixShader/src/MatrixShader.Core/Services/LayoutService.cs**
   - Added MinScaledGap constant (20)
   - Added CalculateScaledGap helper method
   - Updated CalculatePillarsLayout to use scaled gaps
   - Updated CalculateQuadsLayout to use scaled gaps
   - Updated CalculateOverlapLayout to use scaled gaps

2. **MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs**
   - Added using MatrixShader.Core.Native
   - Modified CheckForOverlap to filter fullscreen windows
   - Modified TriggerLayoutRefresh to filter fullscreen windows
   - Added cooldown reset after manual layout refresh

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

Phase 14-04 complete. Ready for:
- 14-05: Installer theming fixes (if planned)
- 14-06: Final E2E verification (if planned)

All three layout bugs (BUG-LAYOUT05, BUG-LAYOUT06, BUG-LAYOUT07) are now fixed.
