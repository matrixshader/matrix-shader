# Matrix Shader Installer Testing Guide

Use Windows Sandbox to test the installer on a clean system.

## Prerequisites

- Windows 10 Pro/Enterprise or Windows 11 with Windows Sandbox enabled
- Built installer at `installer/output/MatrixShaderSetup.exe`

## Setup Windows Sandbox

1. Enable Windows Sandbox (Settings > Apps > Optional Features > More Windows features)
2. Create a shared folder for the installer
3. Copy MatrixShaderSetup.exe to the shared folder

## Testing Checklist

### E2E-01: Installation
- [ ] Installer runs without errors
- [ ] All 6 executables present in `C:\Program Files\MatrixShader\`:
  - [ ] wakeupneo.exe
  - [ ] bluepill.exe
  - [ ] redpill.exe
  - [ ] matrixlite.exe
  - [ ] matrix-hotkeys.exe
  - [ ] matrix-monitor.exe
- [ ] Shaders present in `C:\Program Files\MatrixShader\shaders\`
- [ ] Shaders copied to `%LOCALAPPDATA%\MatrixShader\shaders\`

### E2E-02: PATH Configuration
- [ ] Post-install message mentions "new terminal"
- [ ] Open NEW PowerShell window
- [ ] `where wakeupneo` shows correct path
- [ ] `where bluepill` shows correct path

### E2E-03: Windows Terminal Installation
- [ ] If WT not present, installer offers to install via winget
- [ ] After WT install, settings.json exists

### E2E-04: wakeupneo (First-Run)
- [ ] Run `wakeupneo` in new terminal
- [ ] Wizard completes without errors
- [ ] Matrix profiles created in Windows Terminal (check WT dropdown)
- [ ] Shader paths in profiles point to `%LOCALAPPDATA%\MatrixShader\shaders\`

### E2E-05: bluepill (Session Restore)
- [ ] Run `bluepill` in new terminal
- [ ] If no saved session, enters Lite mode gracefully
- [ ] If previous session exists, windows launch

### E2E-06: redpill (Control Panel)
- [ ] Run `redpill` in new terminal
- [ ] TUI displays correctly
- [ ] Can adjust shader parameters
- [ ] Changes reflect in shader windows

### E2E-07: matrixlite (Fallback Mode)
- [ ] Run `matrixlite` in CMD (not Windows Terminal)
- [ ] Text-based Matrix rain displays
- [ ] Colors work via ANSI codes
- [ ] Keyboard controls respond

### E2E-08: Uninstall
- [ ] Run uninstaller from Control Panel
- [ ] Executables removed from `C:\Program Files\MatrixShader\`
- [ ] `%LOCALAPPDATA%\MatrixShader\` removed
- [ ] PATH entry removed (check in new terminal)

## Windows Sandbox Config (.wsb)

Save as `MatrixShaderTest.wsb` and double-click to launch:

```xml
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Users\ehome\Documents\Matrix\installer\output</HostFolder>
      <SandboxFolder>C:\Installer</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
</Configuration>
```

Update `HostFolder` to your actual path if different.

## Reporting Issues

If any check fails:
1. Note which step failed
2. Copy error messages
3. Check `%LOCALAPPDATA%\MatrixShader\debug.log` if MATRIX_DEBUG=1 was set
4. Report in GitHub issues with Windows version and WT version

## Quick Verification Commands

Run these in PowerShell after installation:

```powershell
# Check executables
ls "C:\Program Files\MatrixShader\*.exe"

# Check PATH
$env:PATH -split ';' | Where-Object { $_ -match 'MatrixShader' }

# Check shaders
ls "$env:LOCALAPPDATA\MatrixShader\shaders\*.hlsl"

# Test command availability
where wakeupneo
where bluepill
where redpill
where matrixlite
```
