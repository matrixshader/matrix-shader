---
phase: 11
plan: 03
subsystem: installer
tags: [inno-setup, localappdata, uninstall, path]

dependency-graph:
  requires: [11-01, 11-02]
  provides: [complete-installer, shader-copy, uninstall-cleanup, path-notification]
  affects: [11-05]

tech-stack:
  added: []
  patterns: [inno-setup-run-section, inno-setup-uninstalldelete, pascal-curStepChanged]

key-files:
  created: []
  modified:
    - installer/MatrixShaderSetup.iss

decisions:
  - id: cmd-over-pascal
    choice: "CMD xcopy for shader copy instead of Pascal FileCopy"
    reason: "Simpler, fewer lines, works reliably"
  - id: full-cleanup
    choice: "Remove entire LocalAppData\\MatrixShader on uninstall"
    reason: "Clean slate on reinstall, users run wakeupneo again anyway"
  - id: msgbox-over-label
    choice: "Message box for PATH notification instead of finish page label"
    reason: "More visible, PATH issues are common pain point for users"

metrics:
  duration: "~5 minutes"
  completed: "2026-01-31"
---

# Phase 11 Plan 03: Installer Polish Summary

Installer now copies shaders to LocalAppData, cleans up on uninstall, and notifies user about PATH.

## What Was Done

### Task 1: Add shader copy to LocalAppData during install
- Added `[Run]` section with cmd.exe xcopy command
- Creates `%LOCALAPPDATA%\MatrixShader\shaders` directory
- Copies all `.hlsl` files from `{app}\shaders` to LocalAppData
- Runs hidden with status message during install
- Commit: `8367e87`

### Task 2: Add uninstall cleanup for LocalAppData
- Added `[UninstallDelete]` section
- Removes entire `%LOCALAPPDATA%\MatrixShader` directory on uninstall
- Cleans up shaders, identity-registry.json, matrix_state.json, and any runtime files
- Commit: `5fd351f`

### Task 3: Add post-install message about PATH
- Added `CurStepChanged` procedure with `ssDone` callback
- Shows message box informing user to open new terminal window
- Lists all available commands: wakeupneo, bluepill, redpill, matrixlite
- Commit: `8776af7`

## Verification Results

All required elements present in MatrixShaderSetup.iss:
- [Run] section at line 31 - shader copy
- [UninstallDelete] section at line 73 - cleanup
- CurStepChanged procedure at line 57 - PATH notification
- ChangesEnvironment=yes at line 14 - WM_SETTINGCHANGE broadcast
- LocalAppData references for both copy and cleanup operations

Inno Setup compiler not available for syntax compilation test. Syntax reviewed manually - balanced brackets and semicolons.

## Gaps Closed

| Gap | Description | Resolution |
|-----|-------------|------------|
| GAP-E05 | Identity registry cleanup | [UninstallDelete] removes entire LocalAppData\MatrixShader |
| GAP-E10 | PATH requires restart | MsgBox informs user to open NEW terminal |
| GAP-E11 | No uninstall cleanup | [UninstallDelete] cleans up all user data |

## Deviations from Plan

None - plan executed exactly as written.

## Final Installer Structure

```ini
[Setup]         - App metadata, ChangesEnvironment=yes
[Languages]     - English messages
[Files]         - Executables and shaders to {app}
[Run]           - Copy shaders to LocalAppData
[Registry]      - PATH modification
[Code]          - NeedsAddPath() and CurStepChanged()
[UninstallRegistry] - Default PATH cleanup
[UninstallDelete]   - LocalAppData cleanup
```

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 8367e87 | feat | Add shader copy to LocalAppData during install |
| 5fd351f | feat | Add uninstall cleanup for LocalAppData |
| 8776af7 | feat | Add post-install PATH notification message |

## Next Phase Readiness

Plan 11-04 (Runtime safety) can proceed. All installer polish complete.
