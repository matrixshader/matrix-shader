# Layer 2 Fix Verification Checklist

## Pre-Flight Checks

- [x] Modified `Get-CommandLineIdentities` function in WindowIdentityService.ps1
- [x] Changed WMI query from ProcessId to ParentProcessId
- [x] Updated pattern matching from `-p "Matrix-N"` to `title Matrix-N`
- [x] Results keyed by parent PID (not child PID)
- [x] Added ChildPid to result object for debugging
- [x] Syntax validated (PowerShell loads without errors)

## Test Scripts Created

- [x] `verify-layer2-children.ps1` - Show process tree and why fix is needed
- [x] `test-layer2-fix.ps1` - Test Get-CommandLineIdentities directly
- [x] `test-layer2-integration.ps1` - Test full identity resolution flow

## Documentation Created

- [x] `LAYER2_FIX_SUMMARY.md` - Technical explanation
- [x] `LAYER2_FIX_COMMIT.md` - Commit message and impact
- [x] `LAYER2_FIX_CHECKLIST.md` - This file

## Manual Testing Steps

### Step 1: Verify Process Tree
```powershell
.\verify-layer2-children.ps1
```

**Expected:**
- Shows WindowsTerminal.exe parent processes (no command line or generic)
- Shows child cmd.exe processes with "title Matrix-N" in command line
- Highlights where Matrix patterns are found (in children, not parents)

### Step 2: Test Function Directly
```powershell
.\test-layer2-fix.ps1
```

**Expected:**
- Finds child processes for each WindowsTerminal.exe PID
- Parses "title Matrix-N" from child command lines
- Returns identity objects keyed by parent PID
- Shows ProfileName, ShaderFile, Slot, ChildPid for each match
- Match count equals number of Matrix windows

### Step 3: Test Integration
```powershell
.\test-layer2-integration.ps1 -Verbose
```

**Expected:**
- All windows identified via Layer 2 (IdentitySource = "CommandLine")
- No fallback to Layer 3 (title matching)
- Success rate = 100%
- Test result = PASS

### Step 4: Test in Control Panel
```powershell
.\matrix_control.ps1
```

**Expected:**
- All Matrix windows detected and listed in tabs
- Window positions update correctly when cycling layouts (Shift+L)
- No identity resolution warnings in debug.log

### Step 5: Test in Setup Wizard
```powershell
.\matrix_setup.ps1
```

**Expected:**
- Blue Pill path launches windows and positions them correctly
- Red Pill path launches windows with correct shader assignments
- WindowLayoutEngine correctly matches windows to slots

## Debug Verification

### Enable Debug Logging
```powershell
$env:MATRIX_DEBUG = 1
.\test-layer2-integration.ps1 -Verbose
```

### Check debug.log
Look for:
- "Querying child processes with ParentProcessId IN (...)"
- "Found X child processes"
- "Child PID XXXX (parent=YYYY) cmdline: cmd.exe /k title Matrix-N && pause >nul"
- "Command line match: Parent PID=YYYY, Child PID=XXXX -> Matrix-N (Slot N)"
- "Command line resolution: X matches from Y PIDs"

### Expected Pattern in debug.log
```
[DEBUG] Querying command lines for 3 processes
[DEBUG]   Querying child processes with ParentProcessId IN (12345, 67890, 54321)
[DEBUG]   Found 3 child processes
[DEBUG]   Child PID 11111 (parent=12345) cmdline: cmd.exe /k title Matrix-1 && pause >nul
[DEBUG]   Command line match: Parent PID=12345, Child PID=11111 -> Matrix-1 (Slot 1)
[DEBUG]   Child PID 22222 (parent=67890) cmdline: cmd.exe /k title Matrix-2 && pause >nul
[DEBUG]   Command line match: Parent PID=67890, Child PID=22222 -> Matrix-2 (Slot 2)
[DEBUG]   Child PID 33333 (parent=54321) cmdline: cmd.exe /k title Matrix-3 && pause >nul
[DEBUG]   Command line match: Parent PID=54321, Child PID=33333 -> Matrix-3 (Slot 3)
[DEBUG] Command line resolution: 3 matches from 3 PIDs
```

## Edge Cases to Test

### Multiple Children per Window
If a WindowsTerminal.exe has multiple child processes:
- Only the one with "title Matrix-N" should be matched
- Others should be ignored

### No Children
If a WindowsTerminal.exe has no children yet (window just launched):
- Layer 2 should return no match
- System should fall back to Layer 3 (title matching)

### Non-Matrix Children
If a WindowsTerminal.exe has children without "title Matrix-N":
- Layer 2 should return no match
- System should fall back to Layer 3 or Layer 1

## Success Criteria

- [ ] `verify-layer2-children.ps1` shows Matrix patterns in child processes
- [ ] `test-layer2-fix.ps1` returns 100% matches for all Matrix windows
- [ ] `test-layer2-integration.ps1` shows all windows identified via Layer 2
- [ ] debug.log shows child process queries and successful pattern matches
- [ ] `matrix_control.ps1` correctly identifies and manages all windows
- [ ] `matrix_setup.ps1` correctly positions windows after launch

## Rollback Plan

If fix causes issues:
1. Revert WindowIdentityService.ps1 to previous version
2. System will fall back to Layer 3 (title matching)
3. Investigate why child process parsing failed

## Next Steps After Verification

1. Commit changes with descriptive message
2. Update prd.json to mark identity resolution improvements complete
3. Consider adding unit tests for child process parsing
4. Document child process pattern assumptions in code comments
