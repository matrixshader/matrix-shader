# Windows Terminal Shader Reload - Research Findings

## What DOES NOT trigger shader reload on running windows:
1. Editing shader .hlsl files directly (any method - PowerShell or Claude Write tool)
2. Touching shader file timestamps
3. Atomic file replacement of shader files
4. Toggling unrelated settings in settings.json (copyOnSelect, etc.)
5. PowerShell file operations on settings.json

## What DOES affect running shaders:
1. Editing settings.json with Claude's Edit tool CAN turn shaders OFF
2. Corrupting/significantly changing settings.json structure turned all shaders OFF
3. Opening a NEW window loads the shader fresh (shader applies on window creation)

## Key Insight:
- Shaders are loaded/compiled when a terminal TAB/WINDOW is CREATED
- Windows Terminal does NOT hot-reload shader files for already-running tabs
- Settings.json changes can DISABLE shaders but don't reliably RE-ENABLE them

## Hypothesis:
Windows Terminal's `experimental.pixelShaderPath` is truly "experimental":
- Shader is compiled once at tab creation
- No file watcher on the .hlsl file for live updates
- Settings.json reload may reset/clear shader state but doesn't recompile

## Solution Options:

### Option A: Close and Reopen Windows
Control panel saves shader, then:
```powershell
# Close specific Matrix window by finding its process
# Reopen with: Start-Process wt -ArgumentList '-p "Matrix-1"'
```
Pros: Guaranteed to work
Cons: Loses terminal session/history

### Option B: Use a Wrapper Shader
Create a "loader" shader that reads parameters from an external file at runtime.
Pros: True live reload
Cons: Complex, may have performance impact, HLSL can't read external files easily

### Option C: Accept Manual Reload
User must close/reopen Matrix windows manually after changes.
Pros: Simple
Cons: Poor UX

### Option D: Investigate Further
- Does resizing window trigger shader recompile?
- Does toggling the pixelShaderPath OFF then ON in quick succession work?
- Is there a Windows Terminal command/API for shader reload?

## Confirmed Tests (2024-01):

### Test: Change shader path to different file
Result: NO RELOAD - shader stays off once disabled

### Test: Toggle copyOnSelect
Result: NO RELOAD - shader stays off

### Test: Remove then restore pixelShaderPath
Result: NO RELOAD - shader stays off

## Additional Tests (2024-01):

### Test: Complete file rewrite with Write tool (not Edit)
Result: NO RELOAD - shader stays off

### Test: Add useAcrylic to defaults
Result: NO RELOAD - but useAcrylic IS a cool feature to add!

### Test: Add experimental.retroTerminalEffect to defaults
Result: NO RELOAD

## CONCLUSION:
**Windows Terminal does NOT hot-reload shaders for running tabs/windows.**
- Shaders compile ONCE at tab/window creation
- Once disabled, NO file operation brings them back
- Tested: Edit, Write, path changes, defaults changes - NOTHING works
- New windows DO load shaders correctly

## FINAL SOLUTION:
Control panel must CLOSE and REOPEN Matrix windows to apply shader changes.

```powershell
# To apply shader changes:
# 1. Save new shader .hlsl file
# 2. Close the Matrix window (find by title, send close signal)
# 3. Reopen: Start-Process wt -ArgumentList '-p "Matrix-N"'
```

## BONUS FEATURES TO ADD:
- useAcrylic: true/false (transparency)
- acrylicOpacity: 0.0-1.0 (how transparent)
- These go in profile settings alongside the shader
