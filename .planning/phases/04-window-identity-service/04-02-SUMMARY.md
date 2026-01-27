# Phase 4 Plan 2: Batch WMI and UI Automation - Summary

**Plan:** 04-02
**Phase:** 04-window-identity-service
**Completed:** 2026-01-27
**Duration:** 10 min

## One-liner

Complete 4-layer identity resolution with batch WMI O(1) queries and UI Automation Layer 4 (TermControl -> TabItem -> Name hierarchy)

## What Was Built

### 1. UI Automation Framework References (Task 1)
- Changed target framework from `net8.0` to `net8.0-windows`
- Added `Microsoft.WindowsDesktop.App` framework reference
- Provides System.Windows.Automation for UI Automation Layer 4

### 2. IsWindow P/Invoke and Handle Validation (Task 2)
- Added `IsWindow` P/Invoke declaration to WindowsApi
- Added `IsHandleValid` helper that validates BOTH `IsWindow` AND `IsWindowVisible`
- Added `CleanStaleEntries` method to fix interface implementation (blocking issue)
- CleanStaleEntries validates processes, handles, and age thresholds

### 3. Batch WMI and UI Automation Layer 4 (Task 3)
- Added `using System.Windows.Automation;`
- Implemented `BatchQueryCommandLines` - O(1) WMI query for all PIDs vs O(n) individual calls
- Implemented `GetUIAutomationIdentity` - Layer 4 with TermControl (0.95) -> TabItem (0.85) -> Name (0.90)
- Updated `ResolveIdentity` to use `IsHandleValid` and call UI Automation
- Updated `FindMatrixWindows` to use batch WMI cache
- Updated `CreateWindowInfo` to set Confidence from `source.GetConfidence()`
- Updated `GetTerminalWindows` to use `GetAllWindows` (includes minimized)
- Added `ResolveIdentityWithCache` for batch performance
- Added `ParseCommandLineIdentity` helper for cached resolution
- Added `TryParseMatrixProfile` helper for Matrix-N pattern parsing

## Files Changed

| File | Change | Lines |
|------|--------|-------|
| MatrixShader.Core.csproj | Modified | +6 |
| Native/WindowsApi.cs | Modified | +18 |
| Services/IdentityService.cs | Modified | +202 |

## Key Code Patterns

### Batch WMI Query
```csharp
// Build WMI query: SELECT ... WHERE ProcessId=1 OR ProcessId=2...
var pidFilter = string.Join(" OR ", pidList.Select(p => $"ProcessId={p}"));
var query = $"SELECT ProcessId, CommandLine FROM Win32_Process WHERE ({pidFilter})";
```

### UI Automation Layer 4 Hierarchy
```csharp
// Priority 1: TermControl (confidence 0.95)
var classCondition = new PropertyCondition(AutomationElement.ClassNameProperty, "TermControl");
// Priority 2: TabItem (confidence 0.85)
var tabCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
// Priority 3: Window Name (confidence 0.90)
var windowName = element.Current.Name;
```

### Handle Validation
```csharp
public static bool IsHandleValid(nint hWnd)
{
    if (hWnd == nint.Zero) return false;
    return IsWindow(hWnd) && IsWindowVisible(hWnd);
}
```

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| net8.0-windows TFM | Required for Windows Desktop framework reference (UI Automation) |
| Batch WMI with OR joins | O(1) query vs O(n) individual queries for command line lookup |
| UI Automation Layer 4 order | TermControl first (most reliable), TabItem second, Name fallback |
| IsHandleValid = IsWindow + IsWindowVisible | Both checks required for valid handle - matches PowerShell behavior |
| GetAllWindows includes minimized | Matrix windows need tracking regardless of minimize state |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing CleanStaleEntries interface implementation**
- **Found during:** Task 2 build verification
- **Issue:** IIdentityService declared CleanStaleEntries but IdentityService didn't implement it
- **Fix:** Added CleanStaleEntries method with process validation, handle validation, and age threshold
- **Files modified:** IdentityService.cs
- **Commit:** 4dc72d8

## Verification Results

- [x] Build succeeds: `dotnet build MatrixShader/src/MatrixShader.Core`
- [x] csproj has FrameworkReference for Microsoft.WindowsDesktop.App
- [x] IsWindow P/Invoke declared in WindowsApi
- [x] IsHandleValid checks both IsWindow AND IsWindowVisible
- [x] BatchQueryCommandLines builds OR-joined WMI query
- [x] GetUIAutomationIdentity tries TermControl (0.95), TabItem (0.85), Name (0.90) in order
- [x] FindMatrixWindows uses batch WMI cache
- [x] All WindowInfo results have correct Confidence values

## Commits

| Hash | Message |
|------|---------|
| a2de066 | feat(04-02): add UI Automation framework references |
| 4dc72d8 | feat(04-02): add IsWindow P/Invoke and CleanStaleEntries |
| ceb0dfc | feat(04-02): implement batch WMI and UI Automation Layer 4 |

## Next Phase Readiness

### Provides
- Complete 4-layer identity resolution (Launch Tracking -> Command Line -> Title -> UI Automation)
- Batch WMI queries for O(1) performance
- Confidence scoring matching PowerShell exactly

### Ready for 04-03
- Registry persistence can now use complete identity resolution
- Confidence scores available for trust-based decision making
