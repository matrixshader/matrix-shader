# Task 5: Background Monitor Enhancement

## Summary

Rewrote `matrix_monitor.ps1` to integrate with the new dynamic accommodation system instead of simple snap-back behavior.

## Changes Made

### Old Behavior (v1)
- Used custom `MonitorAPI` class for window detection
- Simple regex-based title matching (`Matrix-N`)
- Snap-back: When drag detected, repositioned ALL windows to original layout
- No integration with WindowIdentityService or WindowLayoutEngine

### New Behavior (v2)
- Uses `WindowIdentityService` for reliable 4-layer identity resolution
- Uses `WindowLayoutEngine` for dynamic accommodation
- Cross-monitor drag detection with intelligent repositioning
- Only repositions affected windows (not all windows)
- Single instance check to prevent multiple monitors running
- Periodic identity registry cleanup

## Key Components

### 1. Single Instance Check
```powershell
function Test-AlreadyRunning {
    $currentPid = $PID
    $monitorProcesses = Get-Process powershell | Where-Object {
        $_.Id -ne $currentPid -and
        (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -match 'matrix_monitor\.ps1'
    }
    return ($null -ne $monitorProcesses -and $monitorProcesses.Count -gt 0)
}
```

### 2. Module Imports
- `WindowLayoutEngine.ps1` - Provides `Process-WindowDragEvents`, `Initialize-AccommodationSystem`
- `WindowIdentityService.ps1` - Provides `Get-AllMatrixWindows`, `Clean-WindowIdentityRegistry`

### 3. Data Format Conversion
The `WindowIdentityService` returns an array of window objects:
```powershell
@(
    @{ Handle; ProfileName; ShaderFile; Slot; ProcessId; Title; IdentitySource; Confidence }
)
```

The `WindowLayoutEngine` expects a hashtable keyed by profile name:
```powershell
@{
    "Matrix-1" = @{ Handle; Slot; ProcessId }
    "Matrix-2" = @{ Handle; Slot; ProcessId }
}
```

The `ConvertTo-WindowHandles` function bridges this gap.

### 4. Main Loop Flow
```
1. Get-AllMatrixWindows (WindowIdentityService)
2. ConvertTo-WindowHandles (format conversion)
3. Initialize-AccommodationSystem (if needed)
4. Process-WindowDragEvents (detect drags, trigger accommodation)
5. Update-UsageTracking (future smart positioning)
6. Clean-WindowIdentityRegistry (periodic cleanup)
7. Sleep 200ms, repeat
```

### 5. Accommodation vs Snap-Back
| Feature | Old (Snap-Back) | New (Accommodation) |
|---------|-----------------|---------------------|
| Detection | Title regex only | 4-layer identity hierarchy |
| Response | Reposition ALL windows | Reposition affected only |
| Cross-monitor | Not tracked | Triggers accommodation |
| Intelligence | None | Position stability check |

## Settings

| Setting | Value | Description |
|---------|-------|-------------|
| `$pollIntervalMs` | 200 | Check every 200ms for drag events |
| `$noWindowsTimeout` | 5000 | Exit after 5s with no Matrix windows |
| `$cleanupIntervalMs` | 60000 | Clean identity registry every 60s |

## Debug Mode

Enable verbose logging via:
- `-Debug` or `-Verbose` parameter
- `$env:MATRIX_DEBUG=1` environment variable

Log file: `%USERPROFILE%\Documents\Matrix\monitor_debug.log`

## Integration Points

### Started From
- `bluepill.ps1` (line ~270)
- `matrix_setup.ps1` (after launching windows)
- `matrix_control.ps1` (when launching shaders)

### Uses
- `WindowLayoutEngine.ps1` - Layout and accommodation
- `WindowIdentityService.ps1` - Window detection

## File Info

- **Path:** `C:\Users\ehome\Documents\MATRIX\matrix_monitor.ps1`
- **Lines:** ~256 lines (vs ~134 in original)
- **Version:** 2.0

## Functions

| Function | Description |
|----------|-------------|
| `Test-AlreadyRunning` | Check for existing monitor instance |
| `Write-MonitorLog` | Debug logging with file output |
| `ConvertTo-WindowHandles` | Convert array to hashtable format |
| `Update-UsageTracking` | Track active window usage |

## Testing

To test the new monitor:
```powershell
# Start in debug mode
.\matrix_monitor.ps1 -Debug

# Or with environment variable
$env:MATRIX_DEBUG=1
.\matrix_monitor.ps1
```

Expected output:
```
Matrix Window Monitor v2.0 started
  - Using WindowIdentityService for reliable window detection
  - Using WindowLayoutEngine for dynamic accommodation
  - Poll interval: 200ms
  - No-windows timeout: 5s
  - Debug logging: ENABLED
Monitoring for window drags... (Ctrl+C to stop)
```

When dragging a window across monitors:
```
Drag detected: Matrix-2
  Accommodation: SameMonitor (1 monitors)
```

## Date Completed

2026-01-19
