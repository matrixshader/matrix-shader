---
phase: 03-windows-api-layer
plan: 03
completed: 2026-01-27
duration: 6 min
subsystem: windows-api
tags: [positioning, borders, dwm, setwindowpos]
depends_on:
  requires: [03-01, 03-02]
  provides: [pixel-perfect-positioning, border-compensation]
  affects: [04-identity-service, 05-layout-engine]
tech_stack:
  added: []
  patterns: [border-expansion, z-order-preservation]
key_files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs
decisions:
  - key: Border expansion direction
    value: Expand window rect outward by margins so visible area matches target
  - key: Z-order preservation
    value: SWP_NOZORDER to not bring window to top during positioning
  - key: Activation preservation
    value: SWP_NOACTIVATE to not steal focus during positioning
---

# Phase 03 Plan 03: Pixel-Perfect Positioning Summary

**One-liner:** PositionWindowExact method with invisible border compensation for gap-perfect window layouts

## What Was Done

Implemented pixel-perfect window positioning that compensates for Windows 10/11 invisible resize borders. Windows can now be positioned to exact visible pixel coordinates, eliminating the 7-14px gaps that occur when using standard SetWindowPos.

### Commits

| Hash | Type | Description |
|------|------|-------------|
| 61d7f37 | feat | Add PositionWindowExact method with border compensation |
| 4c2fd0f | docs | Clarify PositionWindow doesn't compensate for borders |

### Key Changes

1. **PositionWindowExact() method** - Takes target visible bounds (what user sees) and expands them by border margins before calling SetWindowPos. This ensures the VISIBLE area matches the target exactly.

2. **Updated PositionWindow() documentation** - Clarifies that existing method positions by window rect (including invisible borders), guiding developers to use PositionWindowExact() for pixel-perfect visible positioning.

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Expand window rect by margins | Visible area = window rect minus borders, so window rect = visible area plus borders |
| SWP_NOZORDER flag | Preserve z-order - don't bring window to top when repositioning |
| SWP_NOACTIVATE flag | Preserve focus - don't activate window when repositioning |
| SWP_SHOWWINDOW flag | Ensure visibility - handles case where window was minimized |

## Algorithm

```
targetVisible = what user wants to see
margins = GetBorderMargins(hWnd)   // e.g., {7, 0, 7, 7}

windowRect = {
    Left: targetVisible.Left - margins.Left,
    Top: targetVisible.Top - margins.Top,
    Width: targetVisible.Width + margins.Left + margins.Right,
    Height: targetVisible.Height + margins.Top + margins.Bottom
}

SetWindowPos(hWnd, windowRect, SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW)
```

## Verification Results

```
dotnet build MatrixShader/src/MatrixShader.Core
Build succeeded.
5 Warning(s) - all pre-existing in IdentityService.cs
0 Error(s)
```

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

This plan completes the pixel-perfect positioning capability. The Layout Engine (Phase 5) will use PositionWindowExact() to:
- Position Matrix windows with exact gaps
- Create gap-perfect multi-window layouts
- Handle multi-monitor spanning scenarios

## Files

**Modified:**
- `C:/Users/ehome/documents/matrix/MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs`
