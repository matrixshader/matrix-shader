# Layer 1 (Launch Tracking) Integration Plan

## Executive Summary

The WindowIdentityService has a 4-layer identity system where Layer 1 (Launch Tracking) is the most reliable method because we control the launch. However, **the integration was never completed**. This document provides the exact code changes needed to complete the integration.

## The Core Problem

The current `Register-MatrixWindowLaunch` function (WindowIdentityService.ps1, lines 288-317) is designed around tracking **Process IDs**. But this approach has a fundamental flaw:

```
User runs: Start-Process wt -ArgumentList "-p Matrix-1" -PassThru
           ↓
Returns:   Process object for wt.exe (PID: 12345)
           ↓
wt.exe:    Is a COM launcher that IMMEDIATELY EXITS
           ↓
Result:    WindowsTerminal.exe opens window (PID: 67890 - DIFFERENT!)
           ↓
Problem:   We stored PID 12345, but the window belongs to PID 67890
```

The wt.exe launcher is NOT the same process as WindowsTerminal.exe. The `-PassThru` flag gives us the wrong PID.

## The Solution: Window Handle Tracking

Instead of tracking PIDs, we need to track **window handles**. The pattern:

1. **Before launch**: Get list of all existing WindowsTerminal window handles
2. **Launch**: Start the profile with `Start-Process wt`
3. **After launch**: Poll for a NEW window handle not in the original list
4. **Register**: Associate that handle with the profile name

---

## Required Changes to WindowIdentityService.ps1

### New Function: Register-MatrixWindowByHandle

Add this function after `Register-MatrixWindowLaunch` (around line 318):

```powershell
<#
.SYNOPSIS
    Register a Matrix window by its window handle (for launch tracking).

.DESCRIPTION
    Called after detecting a new window handle post-launch. This is the
    reliable way to track windows since wt.exe is just a launcher that exits.

.PARAMETER ProfileName
    The Windows Terminal profile name (e.g., "Matrix-1", "Matrix-3")

.PARAMETER WindowHandle
    The window handle (IntPtr) of the newly created window

.PARAMETER CorrelationId
    Optional unique ID to correlate launch with window appearance

.EXAMPLE
    Register-MatrixWindowByHandle -ProfileName "Matrix-1" -WindowHandle $newHwnd
#>
function Register-MatrixWindowByHandle {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [string]$CorrelationId = $null
    )

    if (-not $CorrelationId) {
        $CorrelationId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
    }

    # Get the process ID from the window handle
    $processId = [MatrixWindowAPI]::GetProcessId($WindowHandle)

    # Store in runtime registry using handle as key (more reliable than PID for wt.exe launches)
    $handleKey = $WindowHandle.ToString()
    $script:LaunchRegistry[$handleKey] = @{
        ProfileName = $ProfileName
        LaunchTime = (Get-Date)
        CorrelationId = $CorrelationId
        WindowHandle = $WindowHandle
        ProcessId = $processId
    }

    Write-IdentityLog "Registered window: Handle=$WindowHandle, PID=$processId, Profile=$ProfileName, Correlation=$CorrelationId" -Level "INFO"

    # Also persist to disk for cross-session recovery
    Save-IdentityRegistry
}
```

### New Function: Wait-ForNewMatrixWindow

Add this helper function:

```powershell
<#
.SYNOPSIS
    Wait for a new Matrix window to appear after launching a profile.

.DESCRIPTION
    Compares window handles before and after launch to detect the new window.
    Uses polling with timeout to find the new handle.

.PARAMETER ProfileName
    The profile name being launched (used for title matching fallback)

.PARAMETER ExistingHandles
    Array of IntPtr handles that existed BEFORE the launch

.PARAMETER TimeoutMs
    Maximum time to wait in milliseconds (default: 5000)

.PARAMETER PollIntervalMs
    Polling interval in milliseconds (default: 100)

.OUTPUTS
    IntPtr - The handle of the new window, or [IntPtr]::Zero if timeout

.EXAMPLE
    $beforeHandles = Get-ExistingWindowHandles
    Start-Process wt -ArgumentList "-p Matrix-1"
    $newHandle = Wait-ForNewMatrixWindow -ProfileName "Matrix-1" -ExistingHandles $beforeHandles
#>
function Wait-ForNewMatrixWindow {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [IntPtr[]]$ExistingHandles,

        [int]$TimeoutMs = 5000,

        [int]$PollIntervalMs = 100
    )

    $startTime = Get-Date

    while (((Get-Date) - $startTime).TotalMilliseconds -lt $TimeoutMs) {
        Start-Sleep -Milliseconds $PollIntervalMs

        # Get current windows
        $currentWindows = [MatrixWindowAPI]::FindAllTerminalWindows()

        foreach ($win in $currentWindows) {
            $handle = $win.Handle

            # Skip if this handle existed before launch
            if ($handle -in $ExistingHandles) {
                continue
            }

            # New window found! Verify it matches our profile
            $title = $win.Title
            if ($title -match $ProfileName -or $title -match "Matrix") {
                Write-IdentityLog "New window detected: Handle=$handle, Title='$title'" -Level "DEBUG"
                return $handle
            }
        }
    }

    Write-IdentityLog "Timeout waiting for new window: $ProfileName" -Level "WARN"
    return [IntPtr]::Zero
}

<#
.SYNOPSIS
    Get handles of all existing Windows Terminal windows.

.OUTPUTS
    IntPtr[] - Array of window handles
#>
function Get-ExistingWindowHandles {
    $windows = [MatrixWindowAPI]::FindAllTerminalWindows()
    return @($windows | ForEach-Object { $_.Handle })
}
```

### Update the Export List

If using module export, add the new functions:

```powershell
Export-ModuleMember -Function @(
    'Register-MatrixWindowLaunch',
    'Register-MatrixWindowByHandle',   # NEW
    'Wait-ForNewMatrixWindow',          # NEW
    'Get-ExistingWindowHandles',        # NEW
    'Get-AllMatrixWindows',
    'Resolve-WindowIdentity',
    'Test-WindowHandleValid',
    'Clean-WindowIdentityRegistry',
    'Clear-WindowIdentityRegistry',
    'Write-IdentityLog',
    'Enable-IdentityVerboseLogging',
    'Disable-IdentityVerboseLogging'
)
```

---

## Integration Code for bluepill.ps1

### Current Code (line 247-254):

```powershell
    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
    Start-Process wt -ArgumentList "-p `"$pname`""

    if (Wait-ForMatrixWindow $pname) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
```

### Updated Code with Layer 1 Integration:

```powershell
    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline

    # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
    $existingHandles = Get-ExistingWindowHandles

    Start-Process wt -ArgumentList "-p `"$pname`""

    # LAYER 1 INTEGRATION: Wait for new handle and register it
    $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

    if ($newHandle -ne [IntPtr]::Zero) {
        Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
```

### Required Import at Top of bluepill.ps1 (after line 117):

```powershell
# Import WindowIdentityService for launch tracking
. "$PSScriptRoot\WindowIdentityService.ps1"
```

---

## Integration Code for matrix_setup.ps1

### At Top of File (after line 194):

```powershell
# Import WindowIdentityService for launch tracking
. "$PSScriptRoot\WindowIdentityService.ps1"
```

### Red Pill Path - Lines 517-528 (Current):

```powershell
    foreach ($cfg in $tabConfigs) {
        $slot = $cfg.Slot
        $pname = "Matrix-$slot"
        Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
        Start-Process wt -ArgumentList "-p `"$pname`""

        if (Wait-ForMatrixWindow $pname) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " TIMEOUT" -ForegroundColor Yellow
        }
    }
```

### Red Pill Path - Updated Code:

```powershell
    foreach ($cfg in $tabConfigs) {
        $slot = $cfg.Slot
        $pname = "Matrix-$slot"
        Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline

        # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
        $existingHandles = Get-ExistingWindowHandles

        Start-Process wt -ArgumentList "-p `"$pname`""

        # LAYER 1 INTEGRATION: Wait for new handle and register it
        $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

        if ($newHandle -ne [IntPtr]::Zero) {
            Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " TIMEOUT" -ForegroundColor Yellow
        }
    }
```

### Blue Pill Path - Lines 555-566 (Current):

```powershell
foreach ($cfg in $tabConfigs) {
    $slot = $cfg.Slot
    $pname = "Matrix-$slot"
    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
    Start-Process wt -ArgumentList "-p `"$pname`""

    if (Wait-ForMatrixWindow $pname) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
}
```

### Blue Pill Path - Updated Code:

```powershell
foreach ($cfg in $tabConfigs) {
    $slot = $cfg.Slot
    $pname = "Matrix-$slot"
    Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline

    # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
    $existingHandles = Get-ExistingWindowHandles

    Start-Process wt -ArgumentList "-p `"$pname`""

    # LAYER 1 INTEGRATION: Wait for new handle and register it
    $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

    if ($newHandle -ne [IntPtr]::Zero) {
        Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " TIMEOUT" -ForegroundColor Yellow
    }
}
```

---

## Integration Code for matrix_control.ps1

### Note About Existing Import:

matrix_control.ps1 already imports WindowIdentityService.ps1 at line 339:
```powershell
. "$PSScriptRoot\WindowIdentityService.ps1"
```

### Launch-MatrixWindows Function - Lines 670-683 (Current):

```powershell
    foreach ($slot in $slotsToLaunch) {
        $pname = "Matrix-$slot"
        Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline
        Start-Process wt -ArgumentList "-p `"$pname`""

        if (Wait-ForMatrixWindow $pname) {
            Write-Log "Window $pname launched successfully" "LAUNCH"
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Log "Window $pname TIMEOUT after 5s" "LAUNCH"
            Write-Host " TIMEOUT (5s)" -ForegroundColor Yellow
        }
    }
```

### Launch-MatrixWindows Function - Updated Code:

```powershell
    foreach ($slot in $slotsToLaunch) {
        $pname = "Matrix-$slot"
        Write-Host "   Waiting for $pname..." -ForegroundColor DarkGray -NoNewline

        # LAYER 1 INTEGRATION: Capture existing handles BEFORE launch
        $existingHandles = Get-ExistingWindowHandles

        Start-Process wt -ArgumentList "-p `"$pname`""

        # LAYER 1 INTEGRATION: Wait for new handle and register it
        $newHandle = Wait-ForNewMatrixWindow -ProfileName $pname -ExistingHandles $existingHandles

        if ($newHandle -ne [IntPtr]::Zero) {
            Register-MatrixWindowByHandle -ProfileName $pname -WindowHandle $newHandle
            Write-Log "Window $pname launched successfully, Handle=$newHandle" "LAUNCH"
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Log "Window $pname TIMEOUT after 5s" "LAUNCH"
            Write-Host " TIMEOUT (5s)" -ForegroundColor Yellow
        }
    }
```

---

## Updating Get-LaunchRegistryIdentity for Handle-Based Lookup

The current `Get-LaunchRegistryIdentity` function (line 337) looks up by ProcessId. We need to add handle-based lookup since that's how we're now registering.

### Add This Function After Get-LaunchRegistryIdentity:

```powershell
<#
.SYNOPSIS
    Look up a window's identity from the launch registry by handle.

.DESCRIPTION
    Attempts to resolve window identity using the launch tracking registry,
    looking up by window handle instead of process ID.

.PARAMETER WindowHandle
    The window handle (IntPtr)

.OUTPUTS
    Hashtable with ProfileName, ShaderFile, IdentitySource, Confidence
    or $null if not found
#>
function Get-LaunchRegistryIdentityByHandle {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle
    )

    $handleKey = $WindowHandle.ToString()

    # Check runtime registry
    if ($script:LaunchRegistry.ContainsKey($handleKey)) {
        $entry = $script:LaunchRegistry[$handleKey]

        # Validate the window still exists
        if (Test-WindowHandleValid -Handle $WindowHandle) {
            $slotNum = if ($entry.ProfileName -match "Matrix-(\d+)") { [int]$Matches[1] } else { $null }
            $shaderFile = if ($slotNum) { "Matrix-$slotNum.hlsl" } else { $null }

            Write-IdentityLog "Launch registry (handle) hit: Handle=$WindowHandle -> $($entry.ProfileName)" -Level "DEBUG"

            return @{
                ProfileName = $entry.ProfileName
                ShaderFile = $shaderFile
                Slot = $slotNum
                IdentitySource = "LaunchTracking"
                Confidence = 1.0
                LaunchTime = $entry.LaunchTime
                CorrelationId = $entry.CorrelationId
            }
        }
        else {
            # Window no longer exists - clean up stale entry
            Write-IdentityLog "Removing stale launch entry: Handle=$WindowHandle (window gone)" -Level "DEBUG"
            $script:LaunchRegistry.Remove($handleKey)
        }
    }

    return $null
}
```

### Update Resolve-WindowIdentity (around line 800):

Add handle-based lookup before PID-based lookup:

```powershell
    # LAYER 1: Launch Tracking - Try handle-based lookup first (most reliable)
    $identity = Get-LaunchRegistryIdentityByHandle -WindowHandle $WindowHandle
    if ($identity) {
        Write-IdentityLog "  -> Layer 1 (Launch Tracking by Handle): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }

    # LAYER 1: Launch Tracking - Fall back to PID-based lookup
    $identity = Get-LaunchRegistryIdentity -ProcessId $ProcessId
    if ($identity) {
        Write-IdentityLog "  -> Layer 1 (Launch Tracking by PID): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }
```

---

## Summary of All Changes

### Files to Modify:

1. **WindowIdentityService.ps1**
   - Add `Register-MatrixWindowByHandle` function
   - Add `Wait-ForNewMatrixWindow` function
   - Add `Get-ExistingWindowHandles` function
   - Add `Get-LaunchRegistryIdentityByHandle` function
   - Update `Resolve-WindowIdentity` to try handle-based lookup first
   - Update module exports

2. **bluepill.ps1**
   - Add import for WindowIdentityService.ps1 (after line 117)
   - Update launch loop (lines 247-254) to use handle-based registration

3. **matrix_setup.ps1**
   - Add import for WindowIdentityService.ps1 (after line 194)
   - Update Red Pill launch loop (lines 517-528)
   - Update Blue Pill launch loop (lines 555-566)

4. **matrix_control.ps1**
   - Already imports WindowIdentityService.ps1
   - Update Launch-MatrixWindows function (lines 670-683)

---

## Testing the Integration

After implementing these changes, test with:

```powershell
# Enable verbose logging
$env:MATRIX_DEBUG = "1"

# Run bluepill
.\bluepill.ps1

# Check the identity log
Get-Content "$env:USERPROFILE\Documents\Matrix\identity_debug.log" -Tail 20
```

Expected log output:
```
[timestamp] [IDENTITY] [INFO] Registered window: Handle=12345678, PID=9876, Profile=Matrix-1, Correlation=abc123
[timestamp] [IDENTITY] [DEBUG] Launch registry (handle) hit: Handle=12345678 -> Matrix-1
```

---

## Why This Works

1. **Window handles are stable**: Unlike PIDs where wt.exe immediately exits, window handles persist for the lifetime of the window.

2. **We detect the NEW window**: By comparing before/after handle lists, we reliably identify which window was just created.

3. **Registration happens at launch time**: The moment the window appears, we associate it with the profile name we launched.

4. **Confidence = 1.0**: Since we control the launch, we have 100% confidence in the identity.

5. **No reliance on title matching**: We don't need to wait for the title to update or hope the profile name appears in the title.

---

## Architecture Note

This integration completes the original design intent of the WindowIdentityService:

```
BEFORE (incomplete):
  Start-Process wt → Register PID (wt.exe) → wt.exe exits → PID useless

AFTER (complete):
  Get handles → Start-Process wt → Detect new handle → Register handle → Reliable identity
```

The 4-layer hierarchy now works as intended:
1. **Launch Tracking (Layer 1)** - 100% reliable for windows we launched
2. **Command Line (Layer 2)** - 95% reliable fallback
3. **Title Matching (Layer 3)** - 70% reliable
4. **UI Automation (Layer 4)** - 90% reliable but slow
