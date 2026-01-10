# PRD: Matrix Shader v2 - Complete Fix

## Introduction

This PRD documents all failures from the previous implementation attempt and provides explicit solutions. The Matrix Shader system allows users to run multiple Windows Terminal windows with customizable Matrix rain effects, each potentially with different colors and settings.

**Previous Implementation Status:** FAILED - All 20 user stories were incorrectly marked as complete without functional testing.

---

## Critical Architecture Understanding

### How The System MUST Work

```
1. Windows Terminal has profiles: Matrix-1, Matrix-2, Matrix-3, etc.
2. Each profile points to its OWN shader file: shaders/Matrix-1.hlsl, shaders/Matrix-2.hlsl, etc.
3. When user picks colors for 4 windows, 4 DIFFERENT shader files are created
4. Windows Terminal settings.json is UPDATED to point each profile to its shader
5. Windows are launched and POSITIONED side-by-side with gaps (not cascaded)
```

### Key File Locations

- **Production scripts:** `C:\Users\ehome\Documents\Matrix\` (NOT the MVP folder!)
- **Shader files:** `C:\Users\ehome\Documents\Matrix\shaders\Matrix-N.hlsl`
- **Windows Terminal settings:** `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
- **User config:** `C:\Users\ehome\.matrix-shader\config.json`
- **Progress log:** `C:\Users\ehome\Documents\Matrix\progress.txt`

---

## Mistakes Made & Required Fixes

### MISTAKE 1: Edited Wrong Files
**Problem:** All edits were made to `MVP/matrix_tool.ps1` instead of the production file `matrix_tool.ps1` in the root Matrix folder.

**Solution:**
- Work ONLY in `C:\Users\ehome\Documents\Matrix\`
- The MVP folder is for demos/old versions
- Verify file paths before every edit

**Acceptance Criteria:**
- [ ] All edits target files in `C:\Users\ehome\Documents\Matrix\`
- [ ] Never edit files in MVP/ folder

---

### MISTAKE 2: All Windows Same Color
**Problem:** All 8 Matrix profiles in Windows Terminal settings.json point to the SAME shader file:
```json
"experimental.pixelShaderPath": "C:\\Users\\ehome\\Documents\\Matrix\\Matrix.hlsl"
```

**Solution:** Each profile MUST point to its own shader file:
```json
// Matrix-1 profile
"experimental.pixelShaderPath": "C:\\Users\\ehome\\Documents\\Matrix\\shaders\\Matrix-1.hlsl"

// Matrix-2 profile
"experimental.pixelShaderPath": "C:\\Users\\ehome\\Documents\\Matrix\\shaders\\Matrix-2.hlsl"
```

**Acceptance Criteria:**
- [ ] Matrix-1 profile points to `shaders/Matrix-1.hlsl`
- [ ] Matrix-2 profile points to `shaders/Matrix-2.hlsl`
- [ ] Matrix-3 profile points to `shaders/Matrix-3.hlsl`
- [ ] Matrix-4 profile points to `shaders/Matrix-4.hlsl`
- [ ] Matrix-5 through Matrix-8 follow same pattern
- [ ] Opening 4 windows with different colors shows 4 different colors

---

### MISTAKE 3: matrix_setup.ps1 Doesn't Update Profiles
**Problem:** `matrix_setup.ps1` creates shader files in `shaders/` directory but NEVER updates Windows Terminal settings.json to point to them.

**Solution:** Add function to update Windows Terminal profiles:
```powershell
function Update-ProfileShaderPath {
    param([int]$Slot)
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $content = Get-Content $wtSettingsPath -Raw
    $settings = $content | ConvertFrom-Json

    $shaderPath = "$env:USERPROFILE\Documents\Matrix\shaders\Matrix-$Slot.hlsl"

    for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
        if ($settings.profiles.list[$i].name -eq "Matrix-$Slot") {
            $settings.profiles.list[$i].'experimental.pixelShaderPath' = $shaderPath
            break
        }
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
}
```

**Acceptance Criteria:**
- [ ] `Update-ProfileShaderPath` function exists in matrix_setup.ps1
- [ ] Function is called for each slot after creating shader
- [ ] After running wakeupneo, each Matrix-N profile points to shaders/Matrix-N.hlsl
- [ ] Verified by reading settings.json after setup completes

---

### MISTAKE 4: Windows Cascade Instead of Positioning
**Problem:** Windows open in default cascade position instead of side-by-side with gaps.

**Solution:** The window positioning code exists but is never called, or is called before windows exist. Must:
1. Launch window
2. Wait for window to appear (use Get-Process and window handle detection)
3. THEN call SetWindowPos

```powershell
function Position-MatrixWindows {
    param([int]$WindowCount)

    $monitors = Get-DetectedMonitors
    $totalWidth = ($monitors | Measure-Object -Property Width -Sum).Sum
    $height = $monitors[0].Height

    # Calculate window width with gaps
    $gapSize = Get-SmartGapSize -WindowsPerMonitor ([Math]::Ceiling($WindowCount / $monitors.Count))
    $windowWidth = [int](($totalWidth - ($gapSize * ($WindowCount + 1))) / $WindowCount)

    # Get all Matrix terminal windows
    Start-Sleep -Milliseconds 2000  # Wait for windows to fully open

    $wtProcesses = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
    # ... position each window using SetWindowPos API
}
```

**Acceptance Criteria:**
- [ ] 2 windows: positioned side-by-side with 150px gap in center
- [ ] 4 windows: positioned with appropriate gaps
- [ ] Windows span full height of monitor
- [ ] Windows do NOT overlap
- [ ] Verified visually after launch

---

### MISTAKE 5: Removed Tab Switching from TUI
**Problem:** Original `matrix_control.ps1` had TAB key to cycle between Matrix-1, Matrix-2, etc. for editing. This was completely removed.

**Solution:** Add tab switching to the TUI:
```powershell
$script:currentSlot = 1

# In the key handler:
if ($vk -eq 9) {  # TAB key
    $slots = Get-ExistingSlots
    $idx = [array]::IndexOf($slots, $script:currentSlot)
    $idx = ($idx + 1) % $slots.Count
    $script:currentSlot = $slots[$idx]
    $s = Load-ShaderForSlot $script:currentSlot
}
```

**Acceptance Criteria:**
- [ ] TAB key cycles through existing Matrix slots
- [ ] Current slot displayed in header: "RED PILL - Tab 2"
- [ ] Tab selector shows all available slots with color swatches
- [ ] Editing a value only affects the current slot's shader
- [ ] Changes save to the correct slot's shader file

---

### MISTAKE 6: Removed Visual Progress Bars
**Problem:** Original had visual bars showing parameter values. These were removed.

**Solution:** Add Bar function and display bars for all adjustable values:
```powershell
function Get-Bar($val, $min, $max, $width) {
    $pct = ([float]$val - $min) / ($max - $min)
    $filled = [int]($pct * $width)
    $empty = $width - $filled
    "$([char]27)[32m$('█' * $filled)$([char]27)[90m$('░' * $empty)$([char]27)[0m"
}

# Display:
Write-Host " [S] Speed   $($s.Speed.PadLeft(4)) $(Get-Bar $s.Speed 0.1 3.0 15)"
Write-Host " [R] Red     $($s.R.PadLeft(4)) $(Get-Bar $s.R 0 1 15)"
```

**Acceptance Criteria:**
- [ ] Every adjustable parameter shows a visual bar
- [ ] Bar updates in real-time when value changes
- [ ] Bar uses filled/empty characters for clear visualization
- [ ] RGB values each have their own bar

---

### MISTAKE 7: Removed Fine-Grained RGB Control
**Problem:** Original had Q/W for Red, A/S for Green, Z/X for Blue with 0.01 or 0.05 increments. I reduced to only 0.1 increments with r/R, g/G, b/B keys.

**Solution:**
- Add RGB as a selectable section in the TUI
- Support finer increments (0.01 for precise control, 0.1 for quick adjustment)
- Keep both key schemes: letter keys AND arrow key adjustment

```powershell
# Sections: 0=RGB, 1=Parameters, 2=Layers, 3=Transparency
$script:rgbItems = @("R", "G", "B")

# In arrow key handler for RGB section:
$increment = 0.05  # Finer control
$newVal = [float]$s.R + ($direction * $increment)
```

**Acceptance Criteria:**
- [ ] RGB is a selectable section with arrow keys
- [ ] Left/Right arrows adjust RGB in 0.05 increments
- [ ] +/- keys also work for RGB adjustment
- [ ] Q/W, A/S, Z/X keys work as alternatives (like original)
- [ ] Visual bars update for R, G, B values

---

### MISTAKE 8: Wrong Default Values
**Problem:** Defaults were too bright: `Glow=1.5, Dens=1.0, L2=1.0`

**Solution:** Use correct defaults matching matrix_setup.ps1:
```powershell
$defaults = @{
    R="0.0"; G="1.0"; B="0.3"
    Speed="0.8"; Glow="0.8"; Scale="1.0"
    Width="10.0"; Trail="8.0"; Dens="0.4"
    L1="1.0"; L2="0.0"; L3="1.0"  # L2 OFF for depth
}
```

**Acceptance Criteria:**
- [ ] Glow default is 0.8 (not 1.5)
- [ ] Dens default is 0.4 (not 1.0)
- [ ] L2 default is 0.0 (OFF for better depth perception)
- [ ] Verified by resetting to defaults and checking values

---

### MISTAKE 9: y/n Prompt Still Present
**Problem:** "Fine tune? (y/N)" prompt was supposed to be removed from setup flow but remained.

**Solution:** Already fixed, but verify:
- matrix_setup.ps1 asks for # windows, colors, then ONLY at end: Red Pill or Blue Pill
- No intermediate y/n prompts

**Acceptance Criteria:**
- [ ] No "y/n" prompts anywhere in matrix_setup.ps1
- [ ] Flow: # windows → colors for each → Red Pill/Blue Pill choice at end
- [ ] Verified by running wakeupneo start to finish

---

### MISTAKE 10: Launchers Pointed to Wrong Scripts
**Problem:** wakeupneo.cmd and redpill.cmd pointed to wrong files at various times.

**Solution:** Correct launcher configuration:
```batch
:: wakeupneo.cmd - Setup wizard
@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0matrix_setup.ps1"

:: redpill.cmd - Full TUI with per-window editing
@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0matrix_control.ps1"

:: bluepill.cmd - Instant launch with last settings
@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0bluepill.ps1"
```

**Acceptance Criteria:**
- [ ] `wakeupneo` runs matrix_setup.ps1 (setup wizard)
- [ ] `redpill` runs matrix_control.ps1 (full TUI with tab switching)
- [ ] `bluepill` runs bluepill.ps1 (instant launch, no prompts)
- [ ] Each command works when typed at command prompt

---

### MISTAKE 11: No Launch Option from TUI
**Problem:** After customizing in Red Pill TUI, no way to launch the Matrix windows.

**Solution:** Add Enter key to launch:
```powershell
# In control loop:
if ($vk -eq 13) {  # Enter key
    Save-Shader $currentSlot $s
    Launch-MatrixWindows -WindowCount $script:windowCount
    return
}
```

**Acceptance Criteria:**
- [ ] Enter key in TUI launches Matrix windows
- [ ] Shader is saved before launching
- [ ] Help screen documents Enter = Launch

---

### MISTAKE 12: Opacity Wrong in Profiles
**Problem:** Profiles had opacity: 30 (very transparent) instead of 100 (solid black).

**Solution:** matrix_setup.ps1 must set opacity to 100 for all profiles:
```powershell
$settings.profiles.list[$i] | Add-Member -NotePropertyName 'opacity' -NotePropertyValue 100 -Force
```

**Acceptance Criteria:**
- [ ] All Matrix profiles have opacity: 100 after setup
- [ ] Windows have solid black background by default
- [ ] Transparency only activates when user explicitly enables it

---

### MISTAKE 13: Never Wrote to progress.txt
**Problem:** The Ralph loop requires documenting progress per iteration. Zero entries were made.

**Solution:** After completing each user story, append to progress.txt:
```powershell
$logEntry = @"

### $(Get-Date -Format "yyyy-MM-dd HH:mm") - US-XXX: [Title]
- Status: COMPLETE
- Files modified: [list]
- Testing: [what was tested and how]
- Notes: [any issues or observations]
"@
Add-Content -Path "C:\Users\ehome\Documents\Matrix\progress.txt" -Value $logEntry
```

**Acceptance Criteria:**
- [ ] Every completed story has an entry in progress.txt
- [ ] Entry includes date, story ID, files modified, testing performed
- [ ] Log is human-readable and useful for debugging

---

### MISTAKE 14: Marked Stories Complete Without Testing
**Problem:** All 20 stories marked "passes": true based on syntax checks only, not functional testing.

**Solution:** For each story, must verify:
1. Code compiles/runs without errors
2. Feature actually works as described
3. Test by actually using the feature
4. Document test in progress.txt

**Acceptance Criteria:**
- [ ] No story marked complete without functional verification
- [ ] Testing documented for each story
- [ ] "passes": true only after real testing

---

### MISTAKE 15: bluepill.cmd Doesn't Work
**Problem:** bluepill was supposed to instant-launch with last saved settings. It didn't exist or work.

**Solution:** Create bluepill.ps1:
```powershell
# bluepill.ps1 - Instant launch with last settings
$configPath = "$env:USERPROFILE\.matrix-shader\config.json"

if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $windowCount = $config.windowLayout.windowCount

    # Regenerate shaders from saved config
    # ... apply config to shaders ...

    # Launch and position windows
    Launch-MatrixWindows -WindowCount $windowCount
} else {
    Write-Host "No saved config. Run wakeupneo first." -ForegroundColor Red
}
```

**Acceptance Criteria:**
- [ ] `bluepill` command launches immediately with no prompts
- [ ] Uses last saved settings from config.json
- [ ] Windows positioned correctly (not cascaded)
- [ ] If no config exists, shows helpful error message

---

## User Stories (Corrected)

### US-001: Fix Windows Terminal Profile Shader Paths
**Description:** As a user, I want each Matrix window to have its own shader so they can have different colors.

**Acceptance Criteria:**
- [ ] Matrix-1 profile pixelShaderPath = "shaders/Matrix-1.hlsl"
- [ ] Matrix-2 profile pixelShaderPath = "shaders/Matrix-2.hlsl"
- [ ] Matrix-3 through Matrix-8 follow same pattern
- [ ] Script exists to update these paths
- [ ] Verified by opening settings.json after running setup

---

### US-002: matrix_setup.ps1 Updates Profile Paths
**Description:** As a user running wakeupneo, I want the setup to automatically configure Windows Terminal to use the correct shader files.

**Acceptance Criteria:**
- [ ] After choosing colors, settings.json is updated
- [ ] Each Matrix-N profile points to shaders/Matrix-N.hlsl
- [ ] Shader files are created in shaders/ directory
- [ ] Verified: 4 windows with different colors show 4 different colors

---

### US-003: Window Positioning Works
**Description:** As a user, I want windows positioned side-by-side with gaps, not cascaded.

**Acceptance Criteria:**
- [ ] 2 windows: side-by-side with 150px center gap
- [ ] 4 windows: evenly distributed with gaps
- [ ] Windows span full monitor height
- [ ] Verified visually after launch

---

### US-004: TUI Has Tab Switching
**Description:** As a user in redpill TUI, I want to switch between windows to edit each one's settings.

**Acceptance Criteria:**
- [ ] TAB key cycles through Matrix-1, Matrix-2, etc.
- [ ] Header shows current slot: "RED PILL - Tab 2"
- [ ] Tab bar shows all slots with color swatches
- [ ] Editing saves to correct slot's shader file

---

### US-005: TUI Has Visual Bars
**Description:** As a user, I want to see visual progress bars for all adjustable values.

**Acceptance Criteria:**
- [ ] Speed, Glow, Width, Trail, Dens each have bars
- [ ] R, G, B each have bars
- [ ] Bars update in real-time when values change
- [ ] Bars clearly show min/max range

---

### US-006: Fine RGB Control
**Description:** As a user, I want precise control over RGB values with small increments.

**Acceptance Criteria:**
- [ ] Arrow keys adjust RGB in 0.05 increments
- [ ] Q/W, A/S, Z/X keys work for RGB (like original)
- [ ] RGB is a navigable section with up/down arrows
- [ ] Visual bars show R, G, B values

---

### US-007: Correct Defaults
**Description:** As a user, I want sensible default values that look good.

**Acceptance Criteria:**
- [ ] Glow default = 0.8
- [ ] Dens default = 0.4
- [ ] L2 default = OFF (0.0)
- [ ] Reset (0 key) restores these values

---

### US-008: bluepill Instant Launch
**Description:** As a user, I want to type "bluepill" and have Matrix windows launch instantly with my last settings.

**Acceptance Criteria:**
- [ ] bluepill.cmd exists and runs bluepill.ps1
- [ ] No prompts - launches immediately
- [ ] Uses settings from config.json
- [ ] Windows positioned correctly
- [ ] Shows error if no saved config

---

### US-009: TUI Can Launch Windows
**Description:** As a user in the TUI, I want to launch Matrix windows after customizing.

**Acceptance Criteria:**
- [ ] Enter key launches windows
- [ ] Shader saved before launch
- [ ] Windows positioned correctly
- [ ] Help screen documents this

---

### US-010: Progress Logging
**Description:** As a developer, I need progress documented for debugging and continuity.

**Acceptance Criteria:**
- [ ] Each completed story logged in progress.txt
- [ ] Log includes: date, story ID, files changed, testing done
- [ ] Log is appended, not overwritten

---

## Functional Requirements

- FR-1: Each Matrix-N profile MUST have its own pixelShaderPath pointing to shaders/Matrix-N.hlsl
- FR-2: matrix_setup.ps1 MUST update Windows Terminal settings.json when creating shaders
- FR-3: Window launching MUST position windows side-by-side with calculated gaps
- FR-4: TUI MUST support TAB key to switch between window slots
- FR-5: TUI MUST display visual progress bars for all adjustable parameters
- FR-6: RGB MUST be adjustable in 0.05 increments via arrow keys
- FR-7: Default Glow MUST be 0.8, Dens MUST be 0.4, L2 MUST be OFF
- FR-8: bluepill command MUST launch immediately with no prompts using saved config
- FR-9: TUI MUST support Enter key to launch windows
- FR-10: Every completed story MUST be logged in progress.txt with testing details

---

## Non-Goals

- Do NOT edit files in MVP/ folder
- Do NOT mark stories complete without functional testing
- Do NOT remove existing working features when adding new ones
- Do NOT use syntax-only validation as proof of completion

---

## Testing Requirements

For EVERY user story:
1. Run the actual command (wakeupneo, redpill, bluepill)
2. Verify the feature works visually/functionally
3. Document what was tested in progress.txt
4. Only then mark as complete

---

## Open Questions

None - all requirements are explicit based on documented failures.

---

## Implementation Order

1. US-001: Fix profile shader paths in settings.json (CRITICAL - blocks everything)
2. US-002: Update matrix_setup.ps1 to modify profiles
3. US-003: Fix window positioning
4. US-004: Add tab switching to TUI
5. US-005: Add visual bars
6. US-006: Add fine RGB control
7. US-007: Fix defaults
8. US-008: Create bluepill.ps1
9. US-009: Add Enter to launch from TUI
10. US-010: Implement progress logging (do this DURING all other work)
