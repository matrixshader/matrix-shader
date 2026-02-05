# Layer 2 Fix: Command Line Parsing via Child Processes

## Summary

Fixed Layer 2 window identity resolution in `WindowIdentityService.ps1` to query child processes instead of WindowsTerminal.exe parent process.

**Problem:** WindowsTerminal.exe has no command line arguments with profile information because wt.exe is a COM launcher that exits immediately.

**Solution:** Query child shell processes (cmd.exe, pwsh.exe, etc.) which contain `title Matrix-N` in their command lines.

## Files Modified

### WindowIdentityService.ps1
- **Function:** `Get-CommandLineIdentities` (lines 633-697)
- **Change:** Query child processes via WMI ParentProcessId filter
- **Pattern:** Changed from `-p "Matrix-N"` to `title Matrix-N`
- **Result:** Keyed by parent PID (WindowsTerminal.exe)

### New Test Files
- `test-layer2-fix.ps1` - Direct function test with debug output
- `test-layer2-integration.ps1` - Full identity resolution integration test
- `verify-layer2-children.ps1` - Process tree visualization

### Documentation
- `LAYER2_FIX_SUMMARY.md` - Complete technical explanation

## Technical Details

### Before
```powershell
# Query WindowsTerminal.exe directly (NO profile info)
$query = "SELECT ProcessId, CommandLine FROM Win32_Process WHERE ProcessId=$pid"
if ($cmdLine -match '(?:-p|--profile)\s+"([^"]+)"') { ... }
```

### After
```powershell
# Query child processes (HAS profile info in title command)
$childQuery = "SELECT ProcessId, CommandLine, ParentProcessId FROM Win32_Process WHERE ParentProcessId IN ($pidList)"
$children = Get-CimInstance -Query $childQuery
foreach ($child in $children) {
    if ($child.CommandLine -match 'title\s+Matrix-(\d+)') {
        # Key by PARENT PID (the WindowsTerminal.exe process)
        $results[$child.ParentProcessId.ToString()] = @{
            ProfileName = "Matrix-$slotNum"
            ShaderFile = "Matrix-$slotNum.hlsl"
            Slot = $slotNum
            IdentitySource = "CommandLine"
            Confidence = 0.95
            CommandLine = $child.CommandLine
            ChildPid = $child.ProcessId
        }
    }
}
```

## Testing

### Quick Verification
```powershell
# Show process tree and child command lines
.\verify-layer2-children.ps1
```

### Function Test
```powershell
# Test Get-CommandLineIdentities directly with debug output
.\test-layer2-fix.ps1
```

### Integration Test
```powershell
# Test full identity resolution with Layer 2 priority
.\test-layer2-integration.ps1 -Verbose
```

## Expected Results

**Before fix:**
- Layer 2 always returns 0 matches
- System falls back to Layer 3 (title matching)
- Less reliable identification

**After fix:**
- Layer 2 returns matches for all Matrix windows
- 95% confidence score
- Faster than Layer 1, more reliable than Layer 3

## Impact on Identity Resolution Priority

Layer priority (unchanged):
1. **Layer 1**: UI Automation (100% accurate, slow ~200ms)
2. **Layer 2**: Command Line (95% accurate, fast ~50ms) ← NOW WORKS
3. **Layer 3**: Title Matching (70% accurate, very fast ~5ms)

With Layer 2 working, most windows will be identified quickly and reliably without needing slow UI Automation queries.

## Notes

- Assumes Matrix profiles use `cmd.exe /k title Matrix-N && pause >nul`
- If profile command changes, update regex pattern in line 664
- Added `ChildPid` to result object for debugging
- Debug logging shows child process discovery for troubleshooting
