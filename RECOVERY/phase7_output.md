# Phase 7: WindowLayoutEngine Integration

## Summary
Successfully integrated WindowLayoutEngine.ps1 with matrix_setup.ps1 and bluepill.ps1.

## Changes Made

### 1. matrix_setup.ps1

**Import added (line 189-190):**
```powershell
# Import WindowLayoutEngine for centralized positioning
. "$PSScriptRoot\WindowLayoutEngine.ps1"
```

**Position-MatrixWindows function replaced (lines 287-314):**
```powershell
function Position-MatrixWindows([int]$WindowCount) {
    # Wait for windows to fully initialize
    Start-Sleep -Milliseconds 500

    # Find all Matrix windows and detect their slots via UI Automation
    $windows = Get-AllTerminalWindows
    $windowHandles = @{}

    foreach ($win in $windows) {
        # Skip Redpill window
        if ($win.Value -match "Redpill") { continue }

        $slot = Get-ProfileFromUIAutomation $win.Key
        if ($slot) {
            $windowHandles["Matrix-$slot"] = @{ Handle = $win.Key }
        }
    }

    if ($windowHandles.Count -eq 0) {
        Write-Host "   No Matrix windows detected" -ForegroundColor Yellow
        return
    }

    # Use WindowLayoutEngine for positioning
    $result = Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode 'Auto'

    Write-Host "   Positioned $($windowHandles.Count) windows by slot order" -ForegroundColor DarkGray
}
```

### 2. bluepill.ps1

**Import added (line 116-117):**
```powershell
# Import WindowLayoutEngine for centralized positioning
. "$PSScriptRoot\WindowLayoutEngine.ps1"
```

**Position-MatrixWindows function replaced (lines 175-198):**
```powershell
function Position-MatrixWindows {
    Start-Sleep -Milliseconds 500

    $windows = [BluepillAPI]::FindAllTerminalWindows()
    $windowHandles = @{}

    foreach ($win in $windows) {
        if ($win.Value -match "Redpill") { continue }
        $slot = Get-ProfileFromUIAutomation $win.Key
        if ($slot) {
            $windowHandles["Matrix-$slot"] = @{ Handle = $win.Key }
        }
    }

    if ($windowHandles.Count -eq 0) {
        Write-Host "   No Matrix windows detected" -ForegroundColor Yellow
        return
    }

    # Use WindowLayoutEngine for positioning
    $result = Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode 'Auto'

    Write-Host "   Positioned $($windowHandles.Count) windows by slot order" -ForegroundColor Green
}
```

## Integration Pattern

Both scripts now follow this pattern:
1. **Import**: Dot-source WindowLayoutEngine.ps1 after the P/Invoke type definitions
2. **Window Detection**: Use existing APIs (WindowPositioning/BluepillAPI) to find terminal windows
3. **Slot Mapping**: Use Get-ProfileFromUIAutomation to detect slot numbers
4. **Build Hashtable**: Create `$windowHandles` with `Matrix-N` keys and `@{ Handle = $hwnd }` values
5. **Layout**: Call `Invoke-MatrixWindowLayout -WindowHandles $windowHandles -Mode 'Auto'`

## Verification

### Syntax Check Results:
- `matrix_setup.ps1` - NO SYNTAX ERRORS
- `bluepill.ps1` - NO SYNTAX ERRORS

### Runtime Test:
The matrix_setup.ps1 script was executed and successfully positioned 4 windows using the new layout engine:
```
 Positioning windows...
   Positioned 4 windows by slot order
```

## Files Modified
- `C:\Users\ehome\Documents\MATRIX\matrix_setup.ps1`
- `C:\Users\ehome\Documents\MATRIX\bluepill.ps1`

## Dependencies
- `C:\Users\ehome\Documents\MATRIX\WindowLayoutEngine.ps1` (must exist in same directory)

## Notes
- Both scripts preserve their existing window detection logic (UI Automation for slot detection)
- The WindowLayoutEngine handles:
  - Screen topology detection (multi-monitor support)
  - Pillars/Quads layout strategies
  - Gap sizing from configuration
  - SetWindowPos API calls
- The `Mode 'Auto'` parameter uses Pillars for 1-4 windows, Quads for 5+ windows
- Configuration can be customized via matrix_state.json layout section
