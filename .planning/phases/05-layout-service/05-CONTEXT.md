# Phase 5: Layout Service - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Automatic window positioning in organized layouts across monitors. Users can cycle layout modes (Pillars/Quads/Auto), windows distribute across multiple monitors, gaps are configurable, and layout state persists. This phase provides the LayoutService methods that the Control Panel TUI (Phase 6) will call via hotkeys.

</domain>

<decisions>
## Implementation Decisions

### Layout Modes
- **Pillars algorithm**: Match PowerShell WindowLayoutEngine.ps1 exactly
- **Quads algorithm**: Match PowerShell WindowLayoutEngine.ps1 exactly
- **Auto mode logic**: Match PowerShell WindowLayoutEngine.ps1 exactly
- **Slot assignment**: Match PowerShell Match-WindowsToSlots algorithm exactly

### Multi-monitor Distribution
- **Window distribution**: Match PowerShell WindowLayoutEngine.ps1 exactly
- **Monitor ordering**: Match PowerShell Get-MonitorInfo sorting (primary first, then left-to-right)
- **Overflow handling**: Match PowerShell WindowLayoutEngine.ps1 exactly
- **Taskbar handling**: Match PowerShell bounds handling (work area vs full bounds)

### Gap and Spacing
- **Default gap size**: Match PowerShell WindowLayoutEngine.ps1 default
- **Edge margins**: Match PowerShell WindowLayoutEngine.ps1 edge margin handling
- **Gap adjustment controls**: Match PowerShell gap adjustment behavior
- **DWM border compensation**: Yes, account for invisible borders (expand window rects outward) — builds on Phase 3 work

### Persistence Behavior
- **What persists**: Match PowerShell model (mode + gap + window slots)
- **Storage location**: Whatever is fastest and best (Claude's discretion on file structure)
- **Auto-apply**: Yes, automatically position new Matrix windows when detected
- **Save timing**: Immediately on any change (mode, gap, or slot)

### Window Movement/Swapping
- **Swap behavior**: Match PowerShell control panel exactly
- **Slot change persistence**: Save immediately when any slot changes
- **Move hotkeys**: Match PowerShell control panel key bindings

### Hotkey Scope
- **Phase 5 scope**: Expose methods (CycleMode, SwapSlots, AdjustGap, etc.) — not hotkey handlers
- **Hotkey registration**: Phase 6 (Control Panel TUI) calls these methods via its keyboard input loop

</decisions>

<specifics>
## Specific Ideas

- Port from WindowLayoutEngine.ps1 (1046 lines) — this is the reference implementation
- PowerShell version uses window-registry.json for slot persistence
- The C# version should feel identical to the PowerShell behavior from a user perspective
- Border compensation work from Phase 3 (03-03-PLAN) should be reused

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-layout-service*
*Context gathered: 2026-01-27*
