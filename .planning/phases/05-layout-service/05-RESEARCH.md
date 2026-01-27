# Phase 5: Layout Service - Research

**Researched:** 2026-01-27
**Domain:** Window layout algorithms, multi-monitor positioning, persistence
**Confidence:** HIGH

## Summary

Phase 5 ports the WindowLayoutEngine.ps1 (1,046+ lines) to C#. The C# codebase already has a significant head start: LayoutService.cs (465 lines) implements Pillars, Quads, and Overlap layout algorithms with multi-monitor distribution. WindowsApi.cs provides PositionWindowExact() with DWM border compensation. LayoutConfig model and MatrixState persistence are in place.

The remaining work is primarily:
1. Adding missing methods to ILayoutService (gap adjustment, slot swapping, position persistence)
2. Integrating PositionWindowExact into ApplyLayout for pixel-perfect positioning
3. Adding window slot persistence (which windows go to which layout positions)
4. Ensuring all behaviors match PowerShell reference exactly

**Primary recommendation:** Extend existing LayoutService.cs with slot management, gap adjustment, and persistence methods. Use PositionWindowExact instead of PositionWindow for border-compensated positioning.

## Standard Stack

### Core (Already in Place)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| System.Runtime.InteropServices | .NET 8 | P/Invoke for Windows API | Built-in, AOT-safe with LibraryImport |
| System.Text.Json | .NET 8 | Layout config persistence | Source-generated, AOT-compatible |

### Supporting (Already in Place)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| WindowsApi.cs | Custom | EnumDisplayMonitors, SetWindowPos | All window operations |
| MatrixJsonContext | Custom | AOT-safe JSON serialization | All persistence |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom layout algorithms | WPF Grid system | WPF is heavyweight, not suitable for console app |
| Manual monitor enum | System.Windows.Forms.Screen | Forms brings large dependency, we use P/Invoke directly |

**No additional packages required** - existing stack covers all needs.

## Architecture Patterns

### Existing Project Structure
```
MatrixShader/src/MatrixShader.Core/
├── Models/
│   ├── LayoutConfig.cs      # Layout mode, gap, overlap settings
│   ├── MonitorInfo.cs       # Monitor bounds, work area, primary flag
│   └── WindowInfo.cs        # Window handle, shader index
├── Native/
│   └── WindowsApi.cs        # GetMonitors, PositionWindowExact, border compensation
├── Serialization/
│   └── MatrixJsonContext.cs # AOT-safe JSON (LayoutConfig registered)
└── Services/
    ├── ILayoutService.cs    # Interface with CalculateLayout, ApplyLayout, CycleMode
    ├── LayoutService.cs     # 465-line implementation of algorithms
    └── ConfigService.cs     # Loads/saves MatrixState (includes Layout)
```

### Pattern 1: Immutable Config with Record Types
**What:** All config objects are C# records with init-only properties
**When to use:** All layout configuration, calculated positions
**Example:**
```csharp
// Source: Existing LayoutConfig.cs pattern
public record LayoutConfig
{
    public int GapSize { get; init; } = 30;
    public string Mode { get; init; } = "Pillars";
    // ... other properties
}

// Immutable update
var newConfig = config with { GapSize = config.GapSize + 5 };
```

### Pattern 2: Separation of Calculate vs Apply
**What:** CalculateLayout returns positions, ApplyLayout moves windows
**When to use:** Allows dry-run, preview, and testing of layouts
**Example:**
```csharp
// Source: Existing ILayoutService pattern
var positions = layoutService.CalculateLayout(windows, config);
// Inspect positions, validate, then:
layoutService.ApplyLayout(positions);
```

### Pattern 3: Border Compensation on Apply
**What:** Use PositionWindowExact for pixel-perfect visible positioning
**When to use:** Any window movement to layout slot
**Example:**
```csharp
// Source: WindowsApi.cs (03-03-PLAN implementation)
// PositionWindowExact compensates for Windows 10/11 invisible borders
WindowsApi.PositionWindowExact(handle, targetVisible);
```

### Anti-Patterns to Avoid
- **Using PositionWindow instead of PositionWindowExact:** Causes 7-14px gaps between windows
- **Hardcoding gap size:** Always read from LayoutConfig, save changes immediately
- **Ignoring monitor work area:** Use WorkArea (excludes taskbar), not Bounds
- **Mixing coordinate systems:** Window rect vs visible rect - always expand for borders

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Monitor enumeration | Manual polling | WindowsApi.GetMonitors() | Handles primary-first sorting, work area |
| Border margins | Guess pixel offsets | WindowsApi.GetBorderMargins() | Uses DWM API, handles edge cases |
| Exact positioning | SetWindowPos raw | WindowsApi.PositionWindowExact() | Compensates borders automatically |
| JSON persistence | Manual serialization | ConfigService.SaveState() | Atomic writes, AOT-safe |
| Layout calculations | New algorithms | Existing LayoutService methods | Already ported from PowerShell |

**Key insight:** Most of the work is already done. Phase 5 extends, not rebuilds.

## Common Pitfalls

### Pitfall 1: Invisible Border Gaps
**What goes wrong:** Windows appear with 7-14px gaps even with gap=0
**Why it happens:** Windows 10/11 have invisible borders for resizing. GetWindowRect includes them, visible area doesn't.
**How to avoid:** Use PositionWindowExact which calls GetBorderMargins and expands the window rect.
**Warning signs:** Visual gaps between windows that don't match configured gap size.

### Pitfall 2: Monitor Index Mismatch
**What goes wrong:** Windows appear on wrong monitors after restart
**Why it happens:** Monitor order can change between sessions. Persisting by index fails.
**How to avoid:** Persist by monitor characteristics (size, position) not index. PowerShell uses primary-first, left-to-right sorting.
**Warning signs:** Multi-monitor layouts scrambled after display config change.

### Pitfall 3: Work Area vs Bounds
**What goes wrong:** Windows overlap taskbar or extend off-screen
**Why it happens:** Using monitor Bounds instead of WorkArea
**How to avoid:** Always use MonitorInfo.WorkArea for layout calculations
**Warning signs:** Windows partially hidden behind taskbar.

### Pitfall 4: Lost State on Mode Change
**What goes wrong:** Gap size or slot assignments lost when cycling modes
**Why it happens:** Not persisting LayoutConfig immediately on change
**How to avoid:** Save MatrixState immediately when mode, gap, or slots change (context decision: "immediately on any change")
**Warning signs:** Settings revert after restart.

### Pitfall 5: Thread.Sleep in ApplyLayout
**What goes wrong:** UI freezes during window positioning
**Why it happens:** Using Thread.Sleep(100) after ShowWindow for minimized restore
**How to avoid:** Keep the delay minimal (100ms is acceptable per PowerShell reference), but don't increase it.
**Warning signs:** Noticeable lag when layout is applied.

## Code Examples

Verified patterns from existing codebase:

### Gap Adjustment
```csharp
// Based on CONTEXT.md: "Match PowerShell gap adjustment behavior"
// PowerShell uses +/- 5 for gap adjustment increments
public LayoutConfig AdjustGap(LayoutConfig current, int delta)
{
    var newGap = Math.Clamp(current.GapSize + delta, 0, 200);
    return current with { GapSize = newGap };
}
```

### Window Distribution (Already Implemented)
```csharp
// Source: LayoutService.cs line 407-434
// Matches PowerShell Get-WindowDistributionWithPrimary
private int[] DistributeWindows(int windowCount, int screenCount, int maxPerScreen)
{
    var distribution = new int[screenCount];
    // ... balanced distribution with remainder to first screens
    return distribution;
}
```

### Position Persistence (Pattern from ConfigService)
```csharp
// Based on ConfigService.SaveState() atomic write pattern
// Apply to window positions - save to MatrixState.WindowPositions
public void SaveWindowPositions(IReadOnlyList<WindowPosition> positions)
{
    var state = _configService.LoadState();
    state = state with {
        WindowPositions = positions.ToDictionary(
            p => $"Matrix-{p.Window.ShaderIndex}",
            p => new SavedPosition { X = p.Target.Left, Y = p.Target.Top, ... })
    };
    _configService.SaveState(state);
}
```

### Border-Compensated Apply
```csharp
// Source: WindowsApi.cs PositionWindowExact (03-03-PLAN)
public void ApplyLayout(IReadOnlyList<WindowPosition> positions)
{
    foreach (var pos in positions)
    {
        if (pos.Window.Handle == nint.Zero) continue;

        // Restore if minimized
        if (WindowsApi.IsIconic(pos.Window.Handle))
        {
            WindowsApi.ShowWindow(pos.Window.Handle, WindowsApi.SW_RESTORE);
            Thread.Sleep(100);
        }

        // Use PositionWindowExact for pixel-perfect positioning
        WindowsApi.PositionWindowExact(pos.Window.Handle, pos.Target);
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GetWindowRect only | DwmGetWindowAttribute for visible bounds | Windows 10+ | Required for accurate gaps |
| SetWindowPos raw | PositionWindowExact with border compensation | Phase 3 | Pixel-perfect layouts |
| Reflection JSON | Source-generated JsonSerializerContext | .NET 8 | AOT-safe persistence |

**Deprecated/outdated:**
- PositionWindow() without border compensation - still exists but should not be used for layouts
- Screen.AllScreens from WinForms - replaced by P/Invoke EnumDisplayMonitors

## Open Questions

Things that couldn't be fully resolved:

1. **Window slot persistence format**
   - What we know: PowerShell uses matrix_state.json with windowPositions object
   - What's unclear: Exact property names in C# model (use camelCase for JSON)
   - Recommendation: Add WindowPositions dictionary to MatrixState, serialize slot->position

2. **Glitch setting behavior**
   - What we know: PowerShell has GlitchEnabled that skips auto-positioning when disabled
   - What's unclear: Is this needed in C# phase 5 or phase 6 (TUI)?
   - Recommendation: Include in LayoutConfig, check in ApplyLayout (matches CONTEXT.md "auto-apply")

3. **PreserveMonitors mode**
   - What we know: PowerShell Invoke-MatrixWindowLayout has -PreserveMonitors switch
   - What's unclear: When to use it (seems for re-layout without moving across monitors)
   - Recommendation: Add as parameter to ApplyLayout for session restore

## Sources

### Primary (HIGH confidence)
- `LayoutService.cs` - Existing C# implementation (465 lines)
- `WindowsApi.cs` - P/Invoke declarations with PositionWindowExact
- `WindowLayoutEngine.ps1` - PowerShell reference (1,046+ lines)
- `.planning/phases/03-windows-api-layer/03-03-PLAN.md` - Border compensation design

### Secondary (MEDIUM confidence)
- `ConfigService.cs` - Atomic write patterns for persistence
- `MatrixState.cs` - Existing state model with Layout property
- `.planning/STATE.md` - Prior decisions on monitor sorting, border expansion

### Tertiary (LOW confidence)
- None - all research based on existing codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, no new dependencies
- Architecture: HIGH - Patterns established in phases 1-4, extend don't rebuild
- Pitfalls: HIGH - Based on actual Phase 3 border compensation work and PowerShell reference

**Research date:** 2026-01-27
**Valid until:** Indefinite (stable, internal codebase reference)

---

## Gap Analysis: What Phase 5 Actually Needs to Implement

Based on research, here's what exists vs. what's needed:

### Already Complete (from prior phases)
- [x] LayoutService.CalculatePillarsLayout()
- [x] LayoutService.CalculateQuadsLayout()
- [x] LayoutService.CalculateOverlapLayout()
- [x] LayoutService.DistributeWindows()
- [x] LayoutService.CycleMode()
- [x] WindowsApi.GetMonitors() with primary-first sorting
- [x] WindowsApi.PositionWindowExact() with border compensation
- [x] LayoutConfig model with GapSize, Mode, MaxWindowsPerMonitor
- [x] MatrixState with Layout property
- [x] ConfigService.SaveState() atomic writes

### Missing for Phase 5 Success Criteria

**Success Criterion 1:** "User can cycle through Pillars/Quads/Auto layout modes with Shift+L"
- [x] CycleMode() exists
- [ ] Need: Method to persist mode change immediately
- [ ] Note: Hotkey registration is Phase 6 scope

**Success Criterion 2:** "Windows distribute evenly across all connected monitors"
- [x] DistributeWindows() exists
- [x] GetMonitors() with sorting exists
- [ ] Need: Verify multi-monitor behavior matches PowerShell exactly

**Success Criterion 3:** "Gap size between windows is configurable and persists"
- [x] GapSize in LayoutConfig
- [ ] Need: AdjustGap method (+/- 5 increments)
- [ ] Need: Immediate persistence on change

**Success Criterion 4:** "Layout preferences persist across application restarts"
- [x] LayoutConfig in MatrixState
- [x] ConfigService.SaveState()
- [ ] Need: Window slot persistence (which window -> which position)
- [ ] Need: Auto-apply layout to new Matrix windows

### Recommended Plan Structure

1. **05-01: Gap adjustment and mode cycling persistence**
   - Add AdjustGap(delta) method to ILayoutService
   - Add UpdateAndSave(config) method for immediate persistence
   - Verify CycleMode persists correctly

2. **05-02: Apply layout with border compensation**
   - Update ApplyLayout to use PositionWindowExact
   - Add RestoreMinimized logic
   - Add DryRun parameter for preview

3. **05-03: Window slot persistence and auto-apply**
   - Add WindowPositions to MatrixState
   - Add SaveWindowPositions / LoadWindowPositions
   - Add auto-apply logic for new Matrix windows
