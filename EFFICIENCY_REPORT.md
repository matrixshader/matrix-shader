# MATRIX Efficiency Report

**Generated:** January 2026
**Issue:** High CPU usage from background scripts

---

## Problem Summary

The MATRIX system has background PowerShell scripts that accumulate excessive CPU time. One instance of `matrix_monitor.ps1` burned **61,158 CPU seconds (~17 hours)** in just 2 days of runtime.

If shipped to customers, this will:
- Drain laptop batteries
- Make fans spin constantly
- Cause users to uninstall and leave negative reviews
- Get flagged by system monitoring tools as problematic

---

## Issues To Investigate

### 1. Polling Loops

Look for patterns like:
```powershell
while ($true) {
    # do work
    Start-Sleep -Milliseconds 50  # or any small number
}
```

**Problem:** Polling 20x/sec (50ms) is overkill for UI work. This burns CPU even when nothing is happening.

**Fix:**
- Increase interval to 250-500ms for UI monitoring (4-2x/sec is plenty)
- Better: Replace polling with Windows event hooks that fire only when something changes

### 2. Multiple Instances

Found 3 instances of `matrix_hotkeys.ps1` running simultaneously.

**Check:**
- Is there instance management preventing duplicate launches?
- Is there a mutex or lock file?

**Fix:** Add single-instance enforcement:
```powershell
$mutex = New-Object System.Threading.Mutex($false, "Global\MATRIX_Hotkeys")
if (-not $mutex.WaitOne(0)) {
    exit  # Already running
}
```

### 3. Cleanup On Exit

Hidden PowerShell windows (`-WindowStyle Hidden`) run forever even after the main app closes.

**Check:**
- What launches these scripts?
- Is there cleanup code when the parent exits?
- Are child process PIDs tracked?

**Fix:** The parent process must:
1. Track all child process PIDs
2. Register an exit handler that kills children
3. Use job objects or process groups if possible

### 4. Event-Based vs Polling

For hotkey detection specifically, Windows provides `RegisterHotKey` API which is event-based and uses zero CPU when idle.

For window monitoring, `SetWinEventHook` fires callbacks only when windows change.

**Recommendation:** Audit each polling loop and determine if an event-based alternative exists.

---

## Performance Targets

| Metric | Current (Bad) | Target (Good) |
|--------|---------------|---------------|
| CPU at idle | High | <1% |
| CPU seconds per hour (idle) | ~500+ | <10 |
| Background processes | Multiple duplicates | Single instance each |
| Cleanup on exit | None | All children terminated |

---

## Testing Checklist

Before shipping:

- [ ] Start MATRIX, let it idle for 5 minutes
- [ ] Check CPU usage in Task Manager — should be near 0%
- [ ] Run `Get-Process powershell` — note the count
- [ ] Close MATRIX completely
- [ ] Run `Get-Process powershell` again — count should return to original
- [ ] No orphaned hidden PowerShell windows

---

## Resources

- `SetWinEventHook` for window events: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwineventhook
- `RegisterHotKey` for hotkeys: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey
- PowerShell job objects for child process management

---

**Priority:** HIGH — This is a ship-blocker for any public release.
