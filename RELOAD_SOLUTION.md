# Windows Terminal Shader Hot-Reload Solution

## Investigation Summary

### Observed Behavior
1. **PATH CHANGE triggers reload**: When `experimental.pixelShaderPath` values in settings.json were changed from old paths to new paths, ALL open Matrix terminal windows immediately reloaded.

2. **FILE CONTENT changes do NOT trigger reload**: Editing the .hlsl file at the same path (even with timestamp updates) does NOT cause Windows Terminal to reload the shader.

3. **Other settings changes**: Editing settings.json without changing shader paths does not trigger shader reload.

### Hypothesis (Confirmed by Observation)
Windows Terminal watches the `experimental.pixelShaderPath` VALUE in settings.json, not the file content at that path. The reload is triggered when:
- settings.json is modified AND
- The `experimental.pixelShaderPath` value for a profile changes to a DIFFERENT string

---

## Current Configuration

### settings.json Location
```
C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

### Current Profile-to-Shader Mapping
| Profile | GUID | Current Shader Path |
|---------|------|---------------------|
| Matrix-1 | {17ce5bfe-17ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-1.hlsl` |
| Matrix-2 | {27ce5bfe-27ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-2.hlsl` |
| Matrix-3 | {37ce5bfe-37ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-3.hlsl` |
| Matrix-4 | {47ce5bfe-47ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-4.hlsl` |
| Matrix-5 | {57ce5bfe-57ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-5.hlsl` |
| Matrix-6 | {67ce5bfe-67ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-6.hlsl` |
| Matrix-7 | {77ce5bfe-77ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-7.hlsl` |
| Matrix-8 | {87ce5bfe-87ed-5f3a-ab15-5cd5baafed5b} | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-8.hlsl` |

### Existing Shader Files
```
C:\Users\ehome\Documents\Matrix\shaders\Matrix-1.hlsl  (exists)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-2.hlsl  (exists)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-3.hlsl  (exists)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-4.hlsl  (needs creation)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-5.hlsl  (needs creation)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-6.hlsl  (needs creation)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-7.hlsl  (needs creation)
C:\Users\ehome\Documents\Matrix\shaders\Matrix-8.hlsl  (needs creation)
```

---

## Proposed Experiment

### Controlled Test Protocol
1. **Create alternate file**: Copy `Matrix-1.hlsl` to `Matrix-1-alt.hlsl`
2. **Open Matrix-1 terminal window**: Launch a new terminal with Matrix-1 profile
3. **Verify shader is active**: Confirm Matrix rain effect is visible
4. **Modify settings.json**: Change the Matrix-1 profile's `experimental.pixelShaderPath` from:
   ```
   "C:\\Users\\ehome\\Documents\\Matrix\\shaders\\Matrix-1.hlsl"
   ```
   to:
   ```
   "C:\\Users\\ehome\\Documents\\Matrix\\shaders\\Matrix-1-alt.hlsl"
   ```
5. **Observe**: If shader reloads immediately, hypothesis confirmed

### Expected Result
The terminal window should immediately reload and display the shader from the new path.

---

## Proposed Solution: Path-Swap Reload Mechanism

### Option A: Dual-File Swap (Recommended)
Each shader slot maintains TWO files with identical content. Reload is triggered by swapping which file is referenced in settings.json.

**File Structure:**
```
shaders/
  Matrix-1.hlsl       <-- Primary file
  Matrix-1-swap.hlsl  <-- Swap file (identical content)
  Matrix-2.hlsl
  Matrix-2-swap.hlsl
  ... etc
```

**Reload Algorithm:**
```powershell
function Trigger-ShaderReload($slotNumber) {
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $shaderDir = "C:\Users\ehome\Documents\Matrix\shaders"

    # Read current settings
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

    # Find the Matrix-N profile
    $profile = $settings.profiles.list | Where-Object { $_.name -eq "Matrix-$slotNumber" }
    $currentPath = $profile.'experimental.pixelShaderPath'

    # Determine swap target
    if ($currentPath -match '-swap\.hlsl$') {
        $newPath = $currentPath -replace '-swap\.hlsl$', '.hlsl'
    } else {
        $newPath = $currentPath -replace '\.hlsl$', '-swap.hlsl'
    }

    # Ensure both files have identical content (copy current to swap target)
    Copy-Item -Path $currentPath -Destination $newPath -Force

    # Update settings.json with new path
    $profile.'experimental.pixelShaderPath' = $newPath
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath

    # Terminal auto-detects settings.json change and reloads shader
}
```

**Advantages:**
- Simple and reliable
- Files can be pre-created at startup
- No temporary file cleanup needed

**Disadvantages:**
- Doubles the number of shader files
- Slight increase in disk usage (negligible - ~4KB per slot)

---

### Option B: Single Temp-File Swap
Use a temporary file path, swap to it, then swap back.

**Reload Algorithm:**
```powershell
function Trigger-ShaderReload($slotNumber) {
    $settingsPath = "..."
    $shaderDir = "..."
    $primaryPath = "$shaderDir\Matrix-$slotNumber.hlsl"
    $tempPath = "$shaderDir\.Matrix-$slotNumber-temp.hlsl"

    # Copy current shader to temp location
    Copy-Item -Path $primaryPath -Destination $tempPath -Force

    # Read settings
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $profile = $settings.profiles.list | Where-Object { $_.name -eq "Matrix-$slotNumber" }

    # Swap to temp path
    $profile.'experimental.pixelShaderPath' = $tempPath
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath

    # Brief delay to ensure reload triggers
    Start-Sleep -Milliseconds 100

    # Swap back to primary path
    $profile.'experimental.pixelShaderPath' = $primaryPath
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath

    # Cleanup temp file
    Remove-Item $tempPath -Force
}
```

**Advantages:**
- Only one shader file per slot
- Cleaner directory structure

**Disadvantages:**
- Requires two settings.json writes per reload
- Potential race condition if reload is very fast
- Hidden temp files may be visible briefly

---

### Option C: Version Suffix Rotation
Append incrementing version numbers to file paths.

**Example:**
```
Matrix-1-v1.hlsl -> Matrix-1-v2.hlsl -> Matrix-1-v3.hlsl -> (cycle back)
```

**Disadvantages:**
- More complex state tracking
- Could accumulate many files over time

---

## Recommendation

**Use Option A (Dual-File Swap)** for these reasons:

1. **Simplicity**: One write to settings.json per reload
2. **Reliability**: No timing/race conditions
3. **Cleanliness**: Both files are "real" shader files, not temp files
4. **State tracking**: Current state is implicit in which path is active

---

## Implementation Checklist

### Phase 1: Setup
- [ ] Create swap files for all 8 slots: `Matrix-N-swap.hlsl`
- [ ] Ensure primary and swap files are initially identical

### Phase 2: Control Panel Integration
- [ ] Add `Trigger-ShaderReload` function to control panel
- [ ] Call after parameter changes are written to shader file
- [ ] Ensure swap file is also updated before triggering reload

### Phase 3: Testing
- [ ] Test single slot reload
- [ ] Test multiple slots simultaneously
- [ ] Verify terminal stability across reload cycles

---

## Additional Findings

### Shader OFF Switch
To turn shaders OFF for a profile, the solution would be:
- Set `experimental.pixelShaderPath` to empty string (`""`)
- Or remove the property entirely from the profile

This should immediately disable the shader effect.

### All-Profiles Reload
To reload ALL Matrix profiles at once:
- Modify all 8 `experimental.pixelShaderPath` values in a single settings.json write
- Windows Terminal should reload all active shader windows

---

## Files Referenced

| File | Path |
|------|------|
| Windows Terminal Settings | `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| Matrix Shader 1 | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-1.hlsl` |
| Matrix Shader 2 | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-2.hlsl` |
| Matrix Shader 3 | `C:\Users\ehome\Documents\Matrix\shaders\Matrix-3.hlsl` |

---

*Document created: 2026-01-08*
*Investigation status: Experiment designed, awaiting execution*
