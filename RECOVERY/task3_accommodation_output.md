# Task 3: Dynamic Accommodation Core - Implementation Output

**Date:** 2026-01-19
**Status:** COMPLETE
**Test Results:** 23/23 passing (100%)

## Summary

Implemented the Dynamic Accommodation Core (Phase 3 from Smart Window Management PRD) in `WindowLayoutEngine.ps1`. This adds approximately 900+ lines of code implementing the "Accommodate, Don't Deport" principle - when a user drags a window to a monitor at capacity, the least-used window is bumped to make room rather than ignoring the user's intent.

## Core Behavior Change

### OLD (Bad - Deports):
```
User drags Window-3 to Monitor-B (at capacity)
-> Window-3 snaps BACK to Monitor-A
-> User intent ignored
```

### NEW (Good - Accommodates):
```
User drags Window-3 to Monitor-B (at capacity)
-> System identifies least-used window on Monitor-B (Matrix-2)
-> Matrix-2 moves to Monitor-A (where Window-3 came from)
-> Window-3 stays on Monitor-B (user intent honored)
-> Both monitors recalculate layouts
```

## State Machine Implemented

```
IDLE
  | (movement > 50px detected)
  v
DRAG_DETECTING
  | (movement sustained > 300ms)
  v
DRAG_CONFIRMED
  | (user releases / movement stops)
  v
CALCULATING
  | (determine target monitor, check capacity)
  v
ACCOMMODATING -------------|
  | (target has room)       | (target at capacity)
  v                         v
ANIMATING              BUMP_SELECTING
  |                         | (select LRU window)
  v                         v
FINALIZING             ANIMATING (both windows)
  |                         |
  v                         v
IDLE                   FINALIZING -> IDLE
```

## Functions Implemented

### Monitor and Capacity Functions
| Function | Description | Lines |
|----------|-------------|-------|
| `Get-MonitorAtPoint` | Determine which monitor contains a point | ~25 |
| `Get-MonitorCapacity` | Get max windows for a monitor based on mode | ~25 |
| `Get-CurrentLayoutMode` | Get effective layout mode (Pillars/Quads) | ~15 |
| `Get-WindowsOnMonitor` | Get all windows assigned to a monitor | ~20 |
| `Update-WindowMonitorAssignments` | Update window-to-monitor tracking | ~40 |

### Drag Detection Functions
| Function | Description | Lines |
|----------|-------------|-------|
| `Test-DragIntention` | Enhanced drag detection with cross-monitor awareness | ~60 |
| `Test-PositionStable` | Check if window position is stable (not still dragging) | ~35 |

### Core Accommodation Functions
| Function | Description | Lines |
|----------|-------------|-------|
| `Move-WindowToMonitor` | Update tracking to move window to monitor | ~15 |
| `Recalculate-AffectedLayouts` | Recalculate and apply layouts for monitors | ~120 |
| `Invoke-DynamicAccommodation` | **THE CORE FUNCTION** - handles accommodation logic | ~80 |
| `Process-WindowDragEvents` | Main polling entry point for drag monitoring | ~70 |

### Utility Functions
| Function | Description | Lines |
|----------|-------------|-------|
| `Get-AccommodationStateSummary` | Debug summary of current state | ~25 |
| `Initialize-AccommodationSystem` | Initialize accommodation with current windows | ~30 |

## Key Design Decisions

1. **Uses existing LRU tracking from Phase 2** - `Get-LeastUsedWindow` from usage tracking is used for bump selection

2. **Stability check before accommodation** - Waits for window position to stabilize (150ms delay, 10px tolerance) to ensure user has finished dragging

3. **Only processes one drag per cycle** - Avoids race conditions when multiple windows moved simultaneously

4. **Tracking-first, position-second** - Updates window-monitor assignments first, then recalculates all affected layouts

5. **Three accommodation outcomes:**
   - `Added` - Target had room, window added directly
   - `Swapped` - Target at capacity, LRU bumped to source monitor
   - `Expanded` - All windows priority-locked, layout shrinks to fit

## Integration Points

The accommodation system integrates with existing code:

- **Get-LeastUsedWindow** (Phase 2) - Used for bump selection
- **Get-ScreenTopology** - Monitor detection
- **Get-MatrixLayoutConfig** - Layout mode and gap settings
- **$script:LastKnownPositions** - Drag detection tracking
- **WindowLayoutAPI** - P/Invoke for SetWindowPos

## Test Coverage

Created `test-dynamic-accommodation.ps1` with 23 tests across 11 groups:

1. **Get-MonitorAtPoint Tests** (3 tests)
   - Valid point returns integer
   - Primary monitor center returns 0
   - Out-of-bounds defaults to 0

2. **Get-MonitorCapacity Tests** (3 tests)
   - Quads mode returns 4
   - Pillars mode uses MaxPillarsPerScreen
   - Auto mode resolves correctly

3. **Get-CurrentLayoutMode Tests** (1 test)
   - Returns valid mode string

4. **Window Monitor Assignments Tests** (2 tests)
   - Get-WindowsOnMonitor returns array
   - Update handles empty hashtable

5. **Test-DragIntention Tests** (2 tests)
   - Returns correct structure
   - Returns false for no prior position

6. **Move-WindowToMonitor Tests** (2 tests)
   - Handles non-existent window gracefully
   - Updates assignment correctly

7. **Invoke-DynamicAccommodation Tests** (3 tests)
   - Returns correct structure
   - Action='Added' when room available
   - Handles at-capacity scenario (swaps with LRU)

8. **Test-PositionStable Tests** (1 test)
   - Returns false for invalid handle

9. **Process-WindowDragEvents Tests** (2 tests)
   - Returns correct structure
   - Handles invalid handles

10. **Initialize-AccommodationSystem Tests** (2 tests)
    - Sets state to IDLE
    - Clears stale assignments

11. **Get-AccommodationStateSummary Tests** (2 tests)
    - Returns non-empty string
    - Includes 'State:' in output

## Files Modified

1. **WindowLayoutEngine.ps1** (+900 lines)
   - Added state machine and module-level variables
   - Added 14 new functions for dynamic accommodation
   - Added [AllowEmptyCollection()] to existing position tracking functions

2. **test-dynamic-accommodation.ps1** (created, ~430 lines)
   - Comprehensive test suite with 23 tests
   - Tests all public functions
   - Validates accommodation behavior

## Usage Example

```powershell
# Initialize the accommodation system
Initialize-AccommodationSystem -WindowHandles $global:matrixWindowHandles

# In a polling loop (e.g., every 200ms):
$result = Process-WindowDragEvents -WindowHandles $global:matrixWindowHandles
if ($result.DragDetected) {
    Write-Host "Accommodated $($result.ProcessedWindow) via $($result.AccommodationResult.Action)"
    if ($result.AccommodationResult.BumpedWindow) {
        Write-Host "Bumped: $($result.AccommodationResult.BumpedWindow)"
    }
}

# Or manually trigger accommodation:
$result = Invoke-DynamicAccommodation -DraggedWindow @{
    ProfileName = "Matrix-3"
    SourceMonitor = 0
} -TargetMonitor 1 -WindowHandles $handles
```

## Next Steps

1. **Task 4: Position Presets** - Save/restore named position configurations
2. **Task 5: Background Monitor Enhancement** - Rewrite matrix_monitor.ps1 with new logic
3. **Task 6: UI Integration** - Add hotkeys and status display to Redpill

## Commit Information

Ready to commit with message:
```
feat: implement Dynamic Accommodation Core (Task 3)

Adds "Accommodate, Don't Deport" behavior - when dragging a window
to a monitor at capacity, the least-used window is bumped to make
room rather than ignoring user intent.

Key additions:
- State machine for accommodation flow
- Cross-monitor drag detection
- LRU bump selection using usage tracking from Phase 2
- Stability check before triggering accommodation
- Layout recalculation for affected monitors

23/23 tests passing.
```
