# Post-Mortem: WindowIdentityService.ps1 Failure

**Date:** 2026-01-19
**Author:** System Architecture Expert
**Status:** ROOT CAUSE IDENTIFIED

---

## Executive Summary

The WindowIdentityService.ps1 was designed to identify Matrix windows through a 4-layer hierarchy. In production, only 1 of 3 Matrix windows was detected. The failure stems from **fundamental misunderstandings about Windows Terminal's architecture**.

---

## 1. What Assumptions Were Made

### Assumption 1: Command Line Contains Profile Argument
**The Design Assumed:**
> "When you launch `wt.exe -p "Matrix-1"`, the process command line will contain `-p Matrix-1`, which we can parse via WMI."

**Evidence from WindowIdentityService.ps1 (lines 462-475):**
```powershell
# Parse for profile argument: -p "Matrix-N" or --profile "Matrix-N"
# Also handles: wt.exe -p Matrix-1 (without quotes)
if ($cmdLine -match '(?:-p|--profile)\s+"([^"]+)"') {
    $profileMatch = $Matches[1]
}
elseif ($cmdLine -match '(?:-p|--profile)\s+(\S+)') {
    $profileMatch = $Matches[1]
}
```

### Assumption 2: Each Window Has a Separate Process
**The Design Assumed:**
> "Each Windows Terminal window will have its own process with a unique PID."

### Assumption 3: UI Automation Exposes Profile Name
**The Design Assumed:**
> "The tab title in Windows Terminal's UI Automation tree will contain the profile name."

**Evidence from WindowIdentityService.ps1 (lines 657-679):**
```powershell
# Try walking the tree to find tab elements
$tabCondition = New-Object System.Windows.Automation.PropertyCondition(...)
$tabs = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCondition)

foreach ($tab in $tabs) {
    $tabName = $tab.Current.Name
    if ($tabName -match "Matrix-(\d+)") {  # EXPECTING PROFILE NAME HERE
        ...
    }
}
```

---

## 2. Why Each Assumption Was Wrong

### Why Command Line Parsing Fails

**Debug Log Evidence:**
```
[DEBUG] PID 14532 cmdline: "C:\Program Files\WindowsApps\...\WindowsTerminal.exe"
[DEBUG] Command line resolution: 0 matches from 1 PIDs
```

**Root Cause:** Windows Terminal uses a **single-process architecture** with a **broker pattern**.

When you run:
```powershell
Start-Process wt -ArgumentList "-p `"Matrix-1`""
```

What actually happens:
1. `wt.exe` is launched with the `-p "Matrix-1"` argument
2. This `wt.exe` is a **launcher stub** that sends an IPC message to the Windows Terminal COM server
3. The launcher stub **immediately exits** (process dies)
4. The **real WindowsTerminal.exe** process (the COM server) creates a new window/tab
5. The COM server process was started **without any arguments** (just the bare executable)

**This is by design.** Windows Terminal follows the Windows App SDK pattern where:
- A thin launcher (`wt.exe`) handles command-line parsing
- A long-running COM server (`WindowsTerminal.exe`) manages all windows
- The launcher communicates the profile selection via COM/IPC, NOT command-line args

### Why Only 1 Process for 3 Windows

**Debug Log Evidence:**
```
[DEBUG] Found 3 terminal windows
[DEBUG] Querying command lines for 1 processes  <-- ALL 3 WINDOWS SHARE 1 PID!
```

**Root Cause:** Windows Terminal's multi-window architecture uses **one process for all windows**.

This is intentional:
- Single process reduces memory footprint
- Shared GPU context for all shader effects
- Unified settings management
- Better tab restoration on crash

The debug log shows 3 windows but only 1 unique PID (14532). All three windows are tabs/windows managed by the same `WindowsTerminal.exe` instance.

### Why UI Automation Fails to Find Profile Names

**Debug Log Evidence:**
```
[DEBUG] Found tab: '? Testing Components'
[DEBUG] Found tab: 'Settings'
[DEBUG] Found tab: 'Command Prompt'
[DEBUG] -> No identity resolved for Handle=1705974
```

**Root Cause:** The tab name in UI Automation shows the **shell's title**, NOT the profile name.

Windows Terminal's tab title priority:
1. **Shell-set title** (via `title` command or ANSI escape sequences)
2. **tabTitle** from profile settings (if set)
3. **Shell executable name** (e.g., "Command Prompt", "PowerShell")
4. **Profile name** (last resort, if nothing else sets it)

Our Matrix profiles use this commandline:
```json
"commandline": "cmd.exe /k title Matrix-1 && pause >nul"
```

This **should** work because we're setting the title to "Matrix-1". BUT the debug log shows:
- "? Testing Components" - User opened a different profile/shell
- "Settings" - Windows Terminal settings page
- "Command Prompt" - Generic cmd.exe without custom title

**The Matrix windows weren't even open during the test** - the user had different tabs open. The ONE window that did work:
```
[DEBUG] Title match: 'Matrix-3 ' -> Matrix-3
```
This worked because it still had the "Matrix-3" title from the `title` command.

---

## 3. What Actually Works for Windows Terminal Profile Detection

### Working Method: Title Matching (Layer 3)

The debug log shows title matching DID work:
```
[DEBUG] Resolving identity: Handle=4196144, PID=14532, Title='Matrix-3 '
[DEBUG] Title match: 'Matrix-3 ' -> Matrix-3
[DEBUG]   -> Layer 3 (Title Match): Matrix-3
```

**Why it works:** The profile's `commandline` includes `title Matrix-N` which sets the window title.

**Limitation:** If the user changes the tab title (e.g., `cd` to another directory can change it), matching fails.

### Working Method: Launch Tracking (Layer 1)

**This was never used in the test.** The debug log shows:
```
[DEBUG] Identity registry loaded (0 entries)
```

Layer 1 (Register-MatrixWindowLaunch) requires the launcher to register the window. The integration was not complete - bluepill.ps1 and matrix_setup.ps1 do launch windows but the test was run with pre-existing windows.

### What Actually Identifies Windows Terminal Profiles

**Option A: Window Title Convention (Currently Implemented)**
- Works when profile sets `title Matrix-N`
- Fragile: titles can change

**Option B: Active Profile via Settings (Not Currently Used)**
- Windows Terminal stores state in a file: `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_...\LocalState\`
- The `state.json` file contains window state including profile GUIDs
- Could correlate window by matching GUID to profile

**Option C: Shell Environment Variable**
- Set a unique env var in the profile's commandline
- Child shells inherit it
- Query via `[Environment]::GetEnvironmentVariable`

**Option D: WM_COPYDATA / Custom IPC**
- Terminal exposes limited WMI/COM interfaces
- Could potentially use Windows Runtime APIs

**Option E: Hardware ID + Position (Current WindowLayoutEngine approach)**
- Match windows by position on screen
- Works for the layout engine because it controls positioning

---

## 4. Recommended Fix

### Immediate Fix: Make Title Matching More Robust

The profile commandlines already set titles:
```json
"commandline": "cmd.exe /k title Matrix-1 && pause >nul"
```

**Problem:** The `title` command runs once at startup. If the user interacts with the shell, the title can change.

**Solution:** Add a persistent title enforcement:
```json
"commandline": "cmd.exe /k (title Matrix-1 & for /L %i in (0,0,1) do (timeout /t 5 >nul & title Matrix-1 >nul)) || pause >nul"
```

This loops in background, re-setting the title every 5 seconds.

**Better Solution:** Use PowerShell with $Host.UI.RawUI.WindowTitle:
```json
"commandline": "powershell.exe -NoProfile -Command \"while($true){$host.UI.RawUI.WindowTitle='Matrix-1';Start-Sleep -Seconds 5}\""
```

### Medium-term Fix: Launch Tracking Integration

Complete the integration that was started but not finished:

1. **In bluepill.ps1** (line ~248):
```powershell
$proc = Start-Process wt -ArgumentList "-p `"$pname`"" -PassThru
# ADD THIS:
. "$PSScriptRoot\WindowIdentityService.ps1"
Register-MatrixWindowLaunch -ProfileName $pname -ProcessInfo $proc
```

2. **In matrix_setup.ps1** (similar pattern)

3. **Track the window handle correlation:**
   - After launching, poll for new Windows Terminal windows
   - The newest window is likely the one we just launched
   - Register it with the correct profile

**Problem:** The PID from `Start-Process wt` is the **launcher stub PID**, NOT the WindowsTerminal.exe PID. The launcher exits immediately.

**Workaround:**
```powershell
$beforeHandles = Get-AllMatrixWindows | Select -Expand Handle
Start-Process wt -ArgumentList "-p `"Matrix-1`""
Start-Sleep -Milliseconds 1000
$afterHandles = Get-AllMatrixWindows | Select -Expand Handle
$newHandle = $afterHandles | Where-Object { $_ -notin $beforeHandles }
# Register $newHandle with "Matrix-1"
```

### Long-term Fix: State File Correlation

Read Windows Terminal's state file to get authoritative profile information:

**File:** `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\state.json`

This file contains:
- Window layouts
- Tab configurations
- Profile GUIDs for each tab

Match the profile GUID to our known Matrix profile GUIDs:
```json
"{deadbeef-1337-4242-9999-000000000001}" -> "Matrix-1"
"{deadbeef-1337-4242-9999-000000000002}" -> "Matrix-2"
```

---

## 5. Architectural Lessons Learned

### Lesson 1: Modern Windows Apps Don't Follow Traditional Process Models

The assumption that "one window = one process = one command line" is from Win32 era. Modern UWP/WinRT apps use:
- COM-based activation
- Single-process multi-window
- Broker patterns for privilege separation

### Lesson 2: UI Automation Trees Reflect Runtime State, Not Configuration

The UI Automation tree shows what's currently displayed (shell title, tab content), NOT the underlying profile configuration. We assumed the profile name would be exposed - it isn't.

### Lesson 3: Launch Tracking is the Only Reliable Method We Control

Since we can't reliably introspect Windows Terminal's internals, the only source of truth is **what we know at launch time**. The Window Identity Service's Layer 1 (Launch Tracking) is the right approach, but it wasn't integrated or tested with real launches.

### Lesson 4: Title-Based Matching is Fragile But Works

The current profile configuration DOES set titles via the commandline. This works when:
- The user doesn't change the tab
- The shell doesn't auto-update the title
- The profile is actually running (not just open to Settings)

---

## 6. Summary of Findings

| Layer | Design Assumption | Reality | Status |
|-------|-------------------|---------|--------|
| 1 - Launch Tracking | We register at launch | Integration incomplete | NOT TESTED |
| 2 - Command Line | `-p Profile` in cmdline | Launcher stub exits, COM server has no args | FAILED |
| 3 - Title Match | Tab shows profile name | Tab shows shell title (which we SET) | PARTIAL |
| 4 - UI Automation | Tree has profile info | Tree has shell/tab titles only | FAILED |

**Detection Results:**
- 3 Windows Terminal windows found
- 1 correctly identified (via title match)
- 2 unidentified (different shells open, no "Matrix-N" in title)
- Layer 2 (Command Line): 0% success
- Layer 4 (UI Automation): 0% success (found tabs, none matched pattern)

---

## 7. Action Items

1. **[IMMEDIATE]** Update profile commandlines to maintain titles persistently
2. **[SHORT-TERM]** Complete Launch Tracking integration in bluepill.ps1 and matrix_setup.ps1
3. **[MEDIUM-TERM]** Implement window-handle-correlation at launch time (before/after diff)
4. **[LONG-TERM]** Investigate Windows Terminal state.json parsing for authoritative profile info

---

## Appendix: Debug Log Analysis

Key log entries showing the failure:

```
# All 3 windows share ONE PID
[DEBUG] Found 3 terminal windows
[DEBUG] Querying command lines for 1 processes

# Command line has NO profile argument
[DEBUG] PID 14532 cmdline: "C:\Program Files\WindowsApps\...\WindowsTerminal.exe"
[DEBUG] Command line resolution: 0 matches from 1 PIDs

# Only 1 window has Matrix title
[DEBUG] Resolving identity: Handle=4196144, PID=14532, Title='Matrix-3 '
[DEBUG] Title match: 'Matrix-3 ' -> Matrix-3  # SUCCESS

# Other windows have non-Matrix titles
[DEBUG] Resolving identity: Handle=1705974, PID=14532, Title='? Testing Components'
[DEBUG] Found tab: '? Testing Components'
[DEBUG] Found tab: 'Settings'
[DEBUG] Found tab: 'Command Prompt'
[DEBUG] -> No identity resolved for Handle=1705974  # FAILURE

# Final result
[INFO] Get-AllMatrixWindows complete: 9 windows in 5809.2634ms
[DEBUG]   : 1 windows  # Only 1 of 3 identified
```
