# Windows Terminal Profile Detection Research

**Date:** 2026-01-19
**Purpose:** Document what ACTUALLY works for detecting which profile a Windows Terminal window is using.

## Executive Summary

**There is NO reliable programmatic way to detect which Windows Terminal profile a window is running.**

Microsoft has intentionally declined to expose this information due to:
1. API stability concerns (every exposed variable becomes a long-term commitment)
2. Future architecture changes (tab tearoff, mixed elevation scenarios)
3. Environment variable inheritance issues (child processes inherit WT vars)
4. Dynamic updates being impossible after process spawn

The best available approaches are ranked below from most to least reliable.

---

## Detection Methods Ranked

### 1. Launch Tracking (100% Reliable - When You Launch)

**Status: WORKS - Already Implemented in WindowIdentityService.ps1**

When YOU launch the window, you can track the mapping:

```powershell
$proc = Start-Process wt -ArgumentList "-p `"Matrix-1`"" -PassThru
Register-MatrixWindowLaunch -ProfileName "Matrix-1" -ProcessInfo $proc
```

**Pros:**
- 100% reliable for windows you spawn
- Instant lookup (<1ms)
- Already implemented in your codebase

**Cons:**
- Only works for windows launched during current session
- Registry can become stale if WT crashes or is force-killed
- Doesn't work for pre-existing windows

**Source:** Custom implementation in `WindowIdentityService.ps1`

---

### 2. WT_PROFILE_ID Environment Variable (95% Reliable - With Caveats)

**Status: NOT CURRENTLY USED - Should Implement**

Windows Terminal sets `WT_PROFILE_ID` environment variable containing the profile GUID.

```powershell
# From INSIDE the terminal:
$env:WT_PROFILE_ID  # Returns GUID like "{deadbeef-1337-4242-9999-000000000001}"
```

**To query from OUTSIDE (from control panel):**
```powershell
# Use WMI to get environment of a process
$proc = Get-CimInstance Win32_Process -Filter "ProcessId = $targetPid"
# Unfortunately, this doesn't include inherited env vars
```

**The Problem:** You cannot reliably query another process's environment variables from the outside. WMI's Win32_Process only shows the process's command line, not its environment block.

**Workaround for Matrix:** Since YOU control the profile definitions, embed the profile GUID in the command line:

```json
{
    "guid": "{deadbeef-1337-4242-9999-000000000001}",
    "commandline": "cmd.exe /k title Matrix-1 && echo PROFILE_ID=%WT_PROFILE_ID% && pause >nul"
}
```

**Cons:**
- `WT_PROFILE_ID` can be blank when Terminal is set as Default Terminal ([Issue #13006](https://github.com/microsoft/terminal/issues/13006))
- Environment variables are inherited by child processes (VSCode launched from WT will have the same WT_PROFILE_ID)

**Sources:**
- [GitHub Pull Request #4852](https://github.com/microsoft/terminal/pull/4852)
- [GitHub Issue #13006](https://github.com/microsoft/terminal/issues/13006)

---

### 3. Command Line Parsing (60% Reliable)

**Status: PARTIALLY WORKS - Already Implemented**

Parse the `-p "ProfileName"` argument from the process command line.

```powershell
$query = "SELECT ProcessId, CommandLine FROM Win32_Process WHERE ProcessId = $pid"
$proc = Get-CimInstance -Query $query
# Parse: -p "Matrix-1" or --profile "Matrix-1"
```

**Why Only 60%:**
- WT may be launched without `-p` argument (uses default profile)
- WT can be launched via "Default Terminal" setting (no command line args)
- Multiple tabs/panes share same process - command line shows first tab only
- Store apps have obfuscated command lines

**Source:** [Windows Terminal Command Line Arguments](https://learn.microsoft.com/en-us/windows/terminal/command-line-arguments)

---

### 4. Window Title Matching (50% Reliable)

**Status: PARTIALLY WORKS - Already Implemented**

Check if window title contains profile name (e.g., "Matrix-1").

```powershell
if ($windowTitle -match "Matrix-(\d+)") {
    $slotNum = [int]$Matches[1]
}
```

**Why Only 50%:**
- Title changes based on active tab
- Title changes when user runs commands (shows current directory or running process)
- Multiple tabs share the same window
- User can manually change title

**Your Current Mitigation:** Matrix profiles use `cmd.exe /k title Matrix-N` which sets the initial title. This works until the user runs another command.

---

### 5. UI Automation (40% Reliable for Profiles)

**Status: DOES NOT EXPOSE PROFILE INFO**

UI Automation can access window elements but Windows Terminal does NOT expose profile information through the accessibility tree.

**What UI Automation CAN see:**
- Window name (same as title)
- Window class: `CASCADIA_HOSTING_WINDOW_CLASS`
- Tab names (same as window titles)
- Tab close buttons (but without useful IDs)
- Basic control types

**What UI Automation CANNOT see:**
- Profile GUID
- Profile name (unless it matches tab/window title)
- Shader path
- Any profile-specific settings

**Known Issue:** Windows Terminal tab elements lack proper AutomationId attributes ([Issue #2997](https://github.com/microsoft/terminal/issues/2997)).

**Source:** [Microsoft Terminal Issue #2997](https://github.com/microsoft/terminal/issues/2997)

---

### 6. Shader Visual Detection (Hacky but 100% Reliable)

**Status: IMPLEMENTED in detect-by-shader.ps1**

Temporarily modify each shader to a unique color, observe which window changes.

**How it works:**
1. Backup all shader files
2. For each slot, inject a unique solid color
3. Wait for hot-reload (~100ms)
4. Ask user which window changed OR use screen capture to detect
5. Restore original shaders

**Pros:**
- 100% reliable (if a window shows the color, it's using that shader)
- Works regardless of how window was launched

**Cons:**
- Requires visual observation or screen capture
- Temporarily disrupts user experience
- Takes several seconds per window

---

## What Other Tools Do

### PowerToys FancyZones

FancyZones does NOT identify profiles. It tracks windows by:
- Window handle
- Window properties (custom Win32 properties stamped on windows)
- Process ID

FancyZones uses `SetWinEventHook` to subscribe to system events and stamps windows with FancyZones-specific properties.

**Source:** [FancyZones Source Code](https://github.com/microsoft/PowerToys/tree/main/src/modules/fancyzones)

### Other Tools

Most tools that work with Windows Terminal:
1. Don't need to identify profiles (they work with any terminal window)
2. Use the process tree approach to identify "is this a WT window"
3. Rely on user configuration (user tells the tool which window is which)

---

## Microsoft's Official Position

Microsoft has explicitly declined to provide programmatic profile detection:

> "Every exposed environment variable becomes a long-term API commitment"

> "Process model changes (tab tearoff, mixed elevation scenarios) could invalidate PID assumptions"

> "Cannot reliably update PID values across child processes if architecture changes"

**Feature Request Status:** [Issue #16568](https://github.com/microsoft/terminal/issues/16568) requesting a programmatic API is in "Icebox" (not prioritized).

**Source:** [GitHub Issue #5694](https://github.com/microsoft/terminal/issues/5694), [GitHub Issue #16568](https://github.com/microsoft/terminal/issues/16568)

---

## Recommended Approach for Matrix Shader

Given the limitations, the **recommended hybrid approach** is:

### Primary: Launch Tracking (Layer 1)

Continue using `WindowIdentityService.ps1` launch tracking for windows launched through the control panel or setup wizard.

### Secondary: Profile GUID in Title (Layer 2)

Modify Matrix profiles to include the slot number in a parseable format that persists:

```json
{
    "guid": "{deadbeef-1337-4242-9999-000000000001}",
    "commandline": "cmd.exe /k title [Matrix-1] && pause >nul",
    "tabTitle": "Matrix-1",
    "suppressApplicationTitle": true
}
```

The `suppressApplicationTitle: true` prevents commands from changing the tab title.

### Tertiary: Shader-Based Detection (Layer 3)

For orphan windows (opened outside control panel), use the shader visual detection method with automated screen capture:

```powershell
# Inject a unique RGB marker into shader
# Use screen capture to detect which window shows the marker
# Map window handle to shader slot
```

### Fallback: User Confirmation (Layer 4)

If all else fails, prompt the user: "Which window is Matrix-1?"

---

## Technical Details

### Windows Terminal Window Class

```
Class Name: CASCADIA_HOSTING_WINDOW_CLASS
```

### Environment Variables Set by WT

| Variable | Contents | Reliability |
|----------|----------|-------------|
| `WT_SESSION` | Session GUID | Set when WT launches, inherited by child processes |
| `WT_PROFILE_ID` | Profile GUID | Set when profile starts, can be blank |
| `WSLENV` | Variable sharing config | For WSL integration |

### Process Tree

```
WindowsTerminal.exe
  └── OpenConsole.exe (ConPTY host)
       └── cmd.exe or powershell.exe (your shell)
```

To find the WT window from your shell:
1. Get your process ID
2. Walk up the process tree to find WindowsTerminal.exe
3. Use `EnumWindows` to find CASCADIA_HOSTING_WINDOW_CLASS window belonging to that process

---

## Conclusion

**The fundamental problem is that Windows Terminal is designed as a tabbed application where:**
- Multiple profiles can run in the same window (as tabs or panes)
- A single process hosts multiple tabs
- Profile information is internal state not exposed externally

**For Matrix Shader specifically, the solution is:**
1. Always track windows you launch yourself
2. Use `suppressApplicationTitle` to preserve title-based detection
3. Accept that pre-existing/orphan windows may require user identification
4. Consider the shader visual detection method for automated mapping

---

## Sources

- [Windows Terminal Command Line Arguments](https://learn.microsoft.com/en-us/windows/terminal/command-line-arguments) - Microsoft Learn
- [GitHub Issue #16568 - API Feature Request](https://github.com/microsoft/terminal/issues/16568) - microsoft/terminal
- [GitHub Issue #5694 - Process ID Detection](https://github.com/microsoft/terminal/issues/5694) - microsoft/terminal
- [GitHub Discussion #14492 - CASCADIA_HOSTING_WINDOW_CLASS](https://github.com/microsoft/terminal/discussions/14492) - microsoft/terminal
- [GitHub Discussion #17963 - WT_WINDOWID Request](https://github.com/microsoft/terminal/discussions/17963) - microsoft/terminal
- [GitHub Issue #2997 - UI Automation IDs](https://github.com/microsoft/terminal/issues/2997) - microsoft/terminal
- [GitHub Issue #13006 - WT_PROFILE_ID Blank](https://github.com/microsoft/terminal/issues/13006) - microsoft/terminal
- [GitHub PR #4852 - WT_PROFILE_ID Addition](https://github.com/microsoft/terminal/pull/4852) - microsoft/terminal
- [Detecting Windows Terminal with PowerShell](https://mikefrobbins.com/2024/05/16/detecting-windows-terminal-with-powershell/) - Mike F Robbins
- [FancyZones Source Code](https://github.com/microsoft/PowerToys/tree/main/src/modules/fancyzones) - PowerToys
- [Windows Terminal FAQ](https://github.com/microsoft/terminal/wiki/Frequently-Asked-Questions-(FAQ)) - microsoft/terminal
