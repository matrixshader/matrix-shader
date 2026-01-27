---
phase: 03-windows-api-layer
plan: 01
completed: 2026-01-26
duration: 4 min
subsystem: windows-api
tags: [dwm, p-invoke, borders, aot]
depends_on:
  requires: [02-state-persistence]
  provides: [dwm-pinvoke, border-margins-model, window-rect-empty]
  affects: [03-02, 03-03]
tech_stack:
  added: []
  patterns: [LibraryImport, record-immutability]
key_files:
  created:
    - MatrixShader/src/MatrixShader.Core/Models/BorderMargins.cs
  modified:
    - MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs
    - MatrixShader/src/MatrixShader.Core/Models/WindowInfo.cs
decisions:
  - key: LibraryImport over DllImport
    value: Use LibraryImport for all new P/Invoke (AOT compatibility)
  - key: RECT for DWM output
    value: Reuse existing RECT struct for DwmGetWindowAttribute out parameter
---

# Phase 03 Plan 01: DWM Border Detection P/Invoke Summary

**One-liner:** DwmGetWindowAttribute P/Invoke with BorderMargins model for Windows 10/11 invisible border detection

## What Was Done

Added foundation for pixel-perfect window positioning by detecting invisible resize borders that Windows 10/11 include in GetWindowRect but aren't visible on screen.

### Commits

| Hash | Type | Description |
|------|------|-------------|
| 97f2107 | feat | Add BorderMargins model for invisible window borders |
| b690ded | feat | Add WindowRect.Empty static property |
| 7a26fb6 | feat | Add DWM P/Invoke for invisible border detection |

### Key Changes

1. **BorderMargins.cs (new)** - Immutable record with Left/Top/Right/Bottom properties and static Zero property. Captures the difference between GetWindowRect (includes invisible borders) and DwmGetWindowAttribute DWMWA_EXTENDED_FRAME_BOUNDS (visible area only).

2. **WindowInfo.cs (modified)** - Added WindowRect.Empty static property returning zero-dimension rectangle, useful for error returns without allocating new instances.

3. **WindowsApi.cs (modified)** - Added DWM Functions region with:
   - `DwmGetWindowAttribute` P/Invoke using LibraryImport (AOT-compatible)
   - `DWMWA_EXTENDED_FRAME_BOUNDS` constant (value 9)

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| LibraryImport for DWM | Native AOT requires source-generated marshalling; DllImport would require runtime reflection |
| Reuse RECT struct | DwmGetWindowAttribute returns RECT format; no need for new struct |
| BorderMargins as record | Matches WindowRect pattern; provides immutability and value equality |

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

This plan provides the P/Invoke foundation. Following plans will:
- 03-02: Add helper method to calculate border margins from window handle
- 03-03: Integrate border compensation into PositionWindow helper

## Files

**Created:**
- `C:/Users/ehome/documents/matrix/MatrixShader/src/MatrixShader.Core/Models/BorderMargins.cs`

**Modified:**
- `C:/Users/ehome/documents/matrix/MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs`
- `C:/Users/ehome/documents/matrix/MatrixShader/src/MatrixShader.Core/Models/WindowInfo.cs`
