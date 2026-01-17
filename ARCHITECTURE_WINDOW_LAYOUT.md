# Architecture Blueprint: Robust Live Multi-Smart Window Handling

## 1. Patterns & Conventions Found

### Existing Window Management Patterns

**Current Position-MatrixWindows implementations:**
- `matrix_control.ps1:349` - Control panel positioning
- `matrix_setup.ps1:284` - Setup wizard positioning
- `bluepill.ps1:172` - Blue Pill path positioning

**Key Abstractions:**
- Windows API interop via P/Invoke (`SetWindowPos`, `EnumWindows`)
- Window handle tracking in `$global:matrixWindowHandles` hash table
- JSON state persistence in `matrix_state.json`
- Screen bounds via `[System.Windows.Forms.Screen]`

**Established Conventions:**
```powershell
# Window handle storage pattern
$global:matrixWindowHandles = @{
    "Matrix-1" = @{ Handle = 123456; ProcessId = 789 }
}

# Atomic file writes (US-001 pattern)
$temp = [System.IO.Path]::GetTempFileName()
$content | Out-File -FilePath $temp -Encoding UTF8
Move-Item -Path $temp -Destination $target -Force

# JSON error handling (US-002 pattern)
try {
    $state = Get-Content -Path "matrix_state.json" | ConvertFrom-Json
} catch {
    Write-Host "Error loading state: $_"
    $state = @{ windows = @() }
}
```

## 2. Architecture Decision

**Chosen Approach: Centralized Layout Engine with Strategy Pattern**

**Rationale:**
1. **Single Source of Truth** - One `WindowLayoutEngine` module handles all positioning logic
2. **Strategy Pattern** - Pluggable layout algorithms (Pillars, Quads, future: Cascade, Fullscreen)
3. **Live Reactivity** - Polling-based window detection triggers automatic re-layout
4. **Multi-Monitor First** - Treat single screen as special case of multi-monitor
5. **Configuration-Driven** - Layout mode stored in state, user-switchable via hotkey

**Trade-offs:**
- **Chosen:** Complexity upfront for long-term maintainability
- **Rejected:** Quick fixes to existing code (would accumulate tech debt)
- **Chosen:** Polling for window changes (simple, reliable)
- **Rejected:** Event-driven (complex Windows API hooks)

## 3. Component Design

### 3.1 WindowLayoutEngine.ps1 (NEW)

**File Path:** `C:\Users\ehome\Documents\MATRIX\WindowLayoutEngine.ps1`

**Responsibilities:**
- Calculate screen topology (detect monitors, working areas)
- Distribute windows across screens using chosen strategy
- Execute layout by calling Windows API
- Persist layout preferences to state

**Dependencies:**
- `System.Windows.Forms` assembly for screen detection
- Windows API P/Invoke functions (imports from existing code)
- `matrix_state.json` for configuration

**Public Interface:**
```powershell
# Main entry point - calculates and applies layout
function Invoke-MatrixWindowLayout {
    param(
        [Parameter(Mandatory)][hashtable]$WindowHandles,  # Key = shader name, Value = @{Handle, ProcessId}
        [ValidateSet('Pillars','Quads','Auto')][string]$Mode = 'Auto',
        [switch]$DryRun  # Calculate only, don't move windows
    )
}

# Get current layout configuration
function Get-MatrixLayoutConfig {
    # Returns: @{ Mode = 'Pillars'; MaxPillars = 4; GapSize = 60; PreferredScreen = 0 }
}

# Save layout configuration
function Set-MatrixLayoutConfig {
    param([hashtable]$Config)
}

# Calculate layout without applying
function Get-MatrixWindowLayout {
    param(
        [int]$WindowCount,
        [ValidateSet('Pillars','Quads')][string]$Mode,
        [array]$Screens  # Optional: provide screen array, else auto-detect
    )
    # Returns: Array of @{ X, Y, Width, Height, ScreenIndex }
}
```

### 3.2 Layout Strategy Functions (INTERNAL)

```powershell
# Pillars layout: vertical columns side-by-side
function Get-PillarsLayout {
    param(
        [int]$WindowCount,
        [array]$Screens,
        [int]$MaxPillarsPerScreen = 4,
        [int]$GapSize = 60
    )
    # Returns: Array of window rectangles
}

# Quads layout: 2x2 grid with plus-gap
function Get-QuadsLayout {
    param(
        [int]$WindowCount,
        [array]$Screens,
        [int]$GapSize = 60
    )
    # Returns: Array of window rectangles
}

# Distribute N windows across M screens
function Get-WindowDistribution {
    param(
        [int]$WindowCount,
        [int]$ScreenCount,
        [int]$MaxPerScreen = 4
    )
    # Returns: Array of counts per screen, e.g. @(4, 4, 2) for 10 windows on 3 screens
}
```

### 3.3 Screen Topology Detection

```powershell
# Get all screens with working areas
function Get-ScreenTopology {
    # Returns: Array of @{ Index, Left, Top, Width, Height, IsPrimary }
}
```

### 3.4 Integration Points

**matrix_control.ps1 modifications:**
- Import `WindowLayoutEngine.ps1` at top
- Replace `Position-MatrixWindows` function with call to `Invoke-MatrixWindowLayout`
- Add hotkey to cycle layout modes (L: Pillars → Quads → Auto)
- Trigger re-layout on window count changes

**matrix_setup.ps1 modifications:**
- Import `WindowLayoutEngine.ps1`
- Replace inline positioning logic with `Invoke-MatrixWindowLayout`

**bluepill.ps1 modifications:**
- Same as matrix_setup.ps1

## 4. Implementation Map

### 4.1 Files to CREATE

#### C:\Users\ehome\Documents\MATRIX\WindowLayoutEngine.ps1
```
# Complete layout engine module
# Lines 1-50: Windows API P/Invoke declarations (SetWindowPos, etc)
# Lines 51-100: Get-ScreenTopology function
# Lines 101-150: Get-WindowDistribution function
# Lines 151-250: Get-PillarsLayout function (handles row overflow)
# Lines 251-350: Get-QuadsLayout function (handles plus-gap)
# Lines 351-400: Get-MatrixWindowLayout function (strategy selector)
# Lines 401-450: Get-MatrixLayoutConfig / Set-MatrixLayoutConfig
# Lines 451-500: Invoke-MatrixWindowLayout (main entry point)
```

### 4.2 Files to MODIFY

#### matrix_control.ps1

**Line 1-30 (Imports section):**
```powershell
# ADD after existing Add-Type statements
. "$PSScriptRoot\WindowLayoutEngine.ps1"
```

**Line 349 (Position-MatrixWindows function):**
```powershell
# REPLACE entire function with:
function Position-MatrixWindows {
    $config = Get-MatrixLayoutConfig
    Invoke-MatrixWindowLayout -WindowHandles $global:matrixWindowHandles -Mode $config.Mode
}
```

**Line 600-650 (Main control loop - key handlers):**
```powershell
# ADD new hotkey handler after other key handlers
'L' {
    # Cycle layout mode: Pillars → Quads → Pillars
    $config = Get-MatrixLayoutConfig
    $config.Mode = if ($config.Mode -eq 'Pillars') { 'Quads' } else { 'Pillars' }
    Set-MatrixLayoutConfig -Config $config
    Position-MatrixWindows
    $global:statusMessage = "Layout: $($config.Mode)"
}
```

#### matrix_setup.ps1

**Line 1-30:**
```powershell
# ADD import
. "$PSScriptRoot\WindowLayoutEngine.ps1"
```

**Line 284 (Position-MatrixWindows function):**
```powershell
# REPLACE entire function with call to engine
```

#### bluepill.ps1

**Same changes as matrix_setup.ps1**

#### matrix_state.json

**ADD new section:**
```json
{
  "windows": [ /* existing */ ],
  "layout": {
    "mode": "Pillars",
    "maxPillarsPerScreen": 4,
    "gapSize": 60,
    "preferredScreen": 0
  }
}
```

## 5. Data Flow

```
User Opens/Closes Window
         ↓
matrix_control.ps1: Update-MatrixWindowHandles (polling)
         ↓
Detects count change → Triggers Position-MatrixWindows
         ↓
Invoke-MatrixWindowLayout
         ↓
    ┌────┴────┐
    ↓         ↓
Get-ScreenTopology    Get-MatrixLayoutConfig
    ↓                      ↓
    └──────┬───────────────┘
           ↓
    Get-MatrixWindowLayout (strategy selector)
           ↓
    ┌──────┴──────┐
    ↓             ↓
Get-PillarsLayout  Get-QuadsLayout
    ↓             ↓
    └──────┬──────┘
           ↓
    Get-WindowDistribution (distribute across screens)
           ↓
    Calculate individual rectangles (X, Y, Width, Height)
           ↓
    SetWindowPos for each window handle
           ↓
    Windows move to new positions
```

## 6. Build Sequence

### Phase 1: Core Layout Engine (US-007 prerequisite)
- [ ] Create `WindowLayoutEngine.ps1` file
- [ ] Implement Windows API P/Invoke declarations (copy from existing code)
- [ ] Implement `Get-ScreenTopology` function
- [ ] Test screen detection on single/dual monitor setups
- [ ] Implement `Get-WindowDistribution` algorithm
- [ ] Write unit tests for distribution (1-10 windows, 1-3 screens)

### Phase 2: Pillars Layout Algorithm
- [ ] Implement `Get-PillarsLayout` for single screen, single row
- [ ] Test with 1, 2, 3, 4 windows
- [ ] Add row overflow logic (5+ windows → second row)
- [ ] Test with 5, 6, 7, 8 windows on 1080p screen
- [ ] Add multi-screen distribution
- [ ] Test 8 windows on dual monitors (4 per screen)

### Phase 3: Quads Layout Algorithm
- [ ] Implement `Get-QuadsLayout` for 2x2 grid
- [ ] Calculate plus-gap (horizontal and vertical center gaps)
- [ ] Test with 1, 2, 3, 4 windows
- [ ] Add overflow to second screen or second quad
- [ ] Test with 5-8 windows

### Phase 4: Configuration & State Management
- [ ] Implement `Get-MatrixLayoutConfig` (read from matrix_state.json)
- [ ] Implement `Set-MatrixLayoutConfig` (atomic write using US-001 pattern)
- [ ] Add layout config to default state structure
- [ ] Test config persistence across script restarts

### Phase 5: Main Entry Point
- [ ] Implement `Invoke-MatrixWindowLayout` (orchestrates all pieces)
- [ ] Add strategy selection logic (Auto mode: 1-4 windows=Pillars, else Quads)
- [ ] Add DryRun mode for testing
- [ ] Test end-to-end with real windows

### Phase 6: Integration with Control Panel
- [ ] Add import statement to `matrix_control.ps1`
- [ ] Replace `Position-MatrixWindows` function
- [ ] Add 'L' key handler for mode cycling
- [ ] Modify window polling to trigger re-layout
- [ ] Test live window addition/removal
- [ ] Test mode switching while windows are open

### Phase 7: Integration with Setup Scripts
- [ ] Modify `matrix_setup.ps1` Position-MatrixWindows
- [ ] Modify `bluepill.ps1` Position-MatrixWindows
- [ ] Test Red Pill path with 1, 3, 6 windows
- [ ] Test Blue Pill path with 1, 2 windows

### Phase 8: Edge Case Hardening
- [ ] Handle zero windows (no-op)
- [ ] Handle 10+ windows (graceful overflow)
- [ ] Handle screen disconnect (re-layout to remaining screens)
- [ ] Handle invalid window handles (skip and continue)
- [ ] Add verbose logging (integrates with US-009)

## 7. Critical Details

### 7.1 Pillars Layout Algorithm

```powershell
function Get-PillarsLayout {
    param(
        [int]$WindowCount,
        [array]$Screens,
        [int]$MaxPillarsPerScreen = 4,
        [int]$GapSize = 60
    )

    # Step 1: Distribute windows across screens
    $distribution = Get-WindowDistribution -WindowCount $WindowCount `
                                          -ScreenCount $Screens.Count `
                                          -MaxPerScreen $MaxPillarsPerScreen

    $rectangles = @()
    $windowIndex = 0

    # Step 2: For each screen, layout its assigned windows
    for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
        $screen = $Screens[$screenIdx]
        $windowsOnScreen = $distribution[$screenIdx]

        if ($windowsOnScreen -eq 0) { continue }

        # Step 3: Determine if single row or multi-row
        if ($windowsOnScreen -le $MaxPillarsPerScreen) {
            $columns = $windowsOnScreen
            $rows = 1
        } else {
            $columns = $MaxPillarsPerScreen
            $rows = [Math]::Ceiling($windowsOnScreen / $columns)
        }

        # Step 4: Calculate cell dimensions
        $totalHGaps = ($columns + 1) * $GapSize
        $totalVGaps = ($rows + 1) * $GapSize
        $cellWidth = [int](($screen.Width - $totalHGaps) / $columns)
        $cellHeight = [int](($screen.Height - $totalVGaps) / $rows)

        # Step 5: Place each window in grid
        for ($i = 0; $i -lt $windowsOnScreen; $i++) {
            $col = $i % $columns
            $row = [Math]::Floor($i / $columns)

            $x = $screen.Left + $GapSize + ($col * ($cellWidth + $GapSize))
            $y = $screen.Top + $GapSize + ($row * ($cellHeight + $GapSize))

            $rectangles += @{
                X = $x
                Y = $y
                Width = $cellWidth
                Height = $cellHeight
                ScreenIndex = $screenIdx
                WindowIndex = $windowIndex++
            }
        }
    }

    return $rectangles
}
```

### 7.2 Quads Layout Algorithm

```powershell
function Get-QuadsLayout {
    param(
        [int]$WindowCount,
        [array]$Screens,
        [int]$GapSize = 60
    )

    $rectangles = @()
    $windowIndex = 0
    $windowsPerQuad = 4

    # Calculate how many quads needed
    $quadsNeeded = [Math]::Ceiling($WindowCount / $windowsPerQuad)
    $quadsPerScreen = [Math]::Ceiling($quadsNeeded / $Screens.Count)

    for ($screenIdx = 0; $screenIdx -lt $Screens.Count; $screenIdx++) {
        $screen = $Screens[$screenIdx]

        # Plus-gap: horizontal gap in middle, vertical gap in middle
        $halfWidth = [int](($screen.Width - (3 * $GapSize)) / 2)
        $halfHeight = [int](($screen.Height - (3 * $GapSize)) / 2)

        # Positions: TL, TR, BL, BR
        $quadPositions = @(
            @{ X = $screen.Left + $GapSize; Y = $screen.Top + $GapSize },
            @{ X = $screen.Left + (2*$GapSize) + $halfWidth; Y = $screen.Top + $GapSize },
            @{ X = $screen.Left + $GapSize; Y = $screen.Top + (2*$GapSize) + $halfHeight },
            @{ X = $screen.Left + (2*$GapSize) + $halfWidth; Y = $screen.Top + (2*$GapSize) + $halfHeight }
        )

        for ($posIdx = 0; $posIdx -lt 4; $posIdx++) {
            if ($windowIndex -ge $WindowCount) { break }

            $rectangles += @{
                X = $quadPositions[$posIdx].X
                Y = $quadPositions[$posIdx].Y
                Width = $halfWidth
                Height = $halfHeight
                ScreenIndex = $screenIdx
                WindowIndex = $windowIndex++
            }
        }
    }

    return $rectangles
}
```

### 7.3 Window Distribution Algorithm

```powershell
function Get-WindowDistribution {
    param(
        [int]$WindowCount,
        [int]$ScreenCount,
        [int]$MaxPerScreen = 4
    )

    $distribution = @(0) * $ScreenCount
    $windowsPerScreen = [Math]::Floor($WindowCount / $ScreenCount)
    $remainder = $WindowCount % $ScreenCount

    for ($i = 0; $i -lt $ScreenCount; $i++) {
        $distribution[$i] = [Math]::Min($windowsPerScreen, $MaxPerScreen)
    }

    # Distribute remainder
    for ($i = 0; $i -lt $remainder; $i++) {
        if ($distribution[$i] -lt $MaxPerScreen) {
            $distribution[$i]++
        }
    }

    return $distribution
}
```

## 8. UI Controls for Control Panel

### Hotkey: L (Layout Mode)
- Press L to cycle: Pillars → Quads → Pillars
- Status bar shows current mode: "Layout: Pillars" or "Layout: Quads"
- Immediate re-layout on mode change

### UI Display Update
Add to control panel header:
```
┌─ REDPILL CONTROL ─────────────────────────────┐
│ Windows: 4  │  Layout: PILLARS  │  Screen: 1  │
└───────────────────────────────────────────────┘
```

### Help Text Update
```
[L] Layout mode (Pillars/Quads)
[P] Position windows
```

## 9. Next Steps

1. **Implement Phase 1-2** (Core engine + Pillars layout) - provides immediate improvement
2. **Test with real windows** - validate on 1080p single screen
3. **Implement Phase 3** (Quads layout) - adds user choice
4. **Implement Phase 6** (Control panel integration) - makes it interactive
5. **Implement Phase 7** (Setup script integration) - completes rollout
6. **Implement Phase 8** (Edge cases) - final hardening

This satisfies US-007 (robust window positioning) and provides foundation for future enhancements.
