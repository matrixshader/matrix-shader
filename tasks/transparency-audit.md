# Transparency Behavior Audit

## Root Cause Identified from Screenshots

### Error Messages from Windows Terminal

**Screenshot 1:**
```
Failed to reload settings
Settings could not be reloaded from file. Check for syntax errors, including trailing commas.
* Line 62, Column 51 (opacity)
  Have: 0.6999999999999996
  Expected: number (>= 0, <=100)
Temporarily using the Windows Terminal default settings.
```

**Screenshot 2:**
```
Failed to reload settings
Settings could not be reloaded from file. Check for syntax errors, including trailing commas.
* Line 56, Column 51 (opacity)
  Have: 0.10000000000000001
  Expected: number (>= 0, <=100)
Temporarily using the Windows Terminal default settings.
```

## Key Findings

### 1. Windows Terminal expects opacity as INTEGER 0-100, NOT decimal 0.0-1.0

The error messages clearly show:
- **Expected:** `number (>= 0, <=100)` - Windows Terminal wants INTEGER values
- **Have:** `0.6999999999999996` and `0.10000000000000001` - Code is writing DECIMAL values

### 2. Floating point precision errors

The values show classic floating-point precision issues:
- `0.6999999999999996` instead of `0.7`
- `0.10000000000000001` instead of `0.1`

This happens when doing arithmetic on floating-point numbers in PowerShell.

### 3. "Can't return to black background" bug explained

When Windows Terminal fails to parse settings.json due to invalid opacity values:
- It falls back to "Windows Terminal default settings"
- This means the Matrix shader settings are lost
- Transparency state becomes unpredictable
- The terminal may show unexpected transparency behavior

### 4. Startup at C:\Windows\System32

Both screenshots show `PS C:\Windows\System32>` prompt, confirming US-008 (fix startup directory to user home).

## Required Fixes

### Fix 1: Change opacity to integer 0-100 (US-003)

**Current (WRONG):**
```json
"opacity": 0.7
```

**Required (CORRECT):**
```json
"opacity": 70
```

### Fix 2: Avoid floating-point arithmetic for opacity

When adjusting opacity, use integer math:
```powershell
# WRONG - causes precision errors
$opacity = [float]$opacity + 0.1

# CORRECT - use integers
$opacity = [int]$opacity + 10  # Where opacity is 0-100
```

### Fix 3: Validate opacity before writing to settings.json

```powershell
# Ensure opacity is valid integer between 0 and 100
$opacity = [Math]::Max(0, [Math]::Min(100, [int]$opacity))
```

## Files to Modify

1. **matrix_tool.ps1** - Change all opacity handling to use 0-100 integers
2. **Windows Terminal settings.json updates** - Ensure opacity written as integer

## Test Cases for Verification

1. Set opacity to 70 → settings.json should have `"opacity": 70`
2. Set opacity to 10 → settings.json should have `"opacity": 10`
3. Toggle transparency off → settings.json should have `"opacity": 100`
4. Adjust opacity up/down multiple times → no floating point drift
5. All tabs should show identical opacity after setting

## Related User Stories

- **US-002:** This audit document ✓
- **US-003:** Normalize transparency to 0-100 integer range
- **US-004:** Fix transparency toggle on/off
- **US-005:** Fix color preset transparency defaults
- **US-006:** Ensure consistent transparency across tabs/windows
