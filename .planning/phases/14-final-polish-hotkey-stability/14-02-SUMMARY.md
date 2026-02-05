---
phase: 14
plan: 02
subsystem: terminal-settings
tags: [transparency, settings-backup, uninstall, windows-terminal]
dependency-graph:
  requires: [13-06]
  provides: [plain-transparency, settings-restoration]
  affects: [installer, uninstaller]
tech-stack:
  patterns: [backup-restore, settings-preservation]
key-files:
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs
    - installer/uninstall.ps1
decisions:
  - "UseAcrylic = false for plain transparency (no blur/haze)"
  - "CreateOriginalBackup() preserves FIRST original state only"
  - "Uninstall restores from .matrix-original and removes backup"
metrics:
  duration: ~5 minutes
  completed: 2026-02-04
---

# Phase 14 Plan 02: Transparency Persistence Summary

**One-liner:** Plain transparency (no acrylic blur) and original settings restoration on uninstall.

## Objective

Fix transparency appearance bugs (BUG-TRANS04, BUG-TRANS05). User explicitly dislikes the "hazy" acrylic blur effect. Plain transparency shows the desktop clearly without frosted glass look. Settings also need to persist after uninstall because original state was never restored.

## Changes Made

### Task 1: Add backup/restore methods and fix profile creation for plain transparency

**Files:** `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs`

1. Added `OriginalBackupPath` property pointing to `settings.json.matrix-original`
2. Added `CreateOriginalBackup()` method:
   - Only creates backup if it doesn't exist (preserves FIRST original state)
   - Called at start of CreateMatrixProfiles and CreateRedpillProfile
3. Added `RestoreOriginalSettings()` method:
   - Copies backup back to settings.json
   - Used by uninstall process
4. Changed `UseAcrylic = true` to `UseAcrylic = false` in both:
   - CreateMatrixProfiles (line 259)
   - CreateRedpillProfile (line 303)
5. Windows 11 plain transparency shows desktop clearly without blur

**Commit:** `e23db9b fix(14-02): plain transparency and original settings backup`

### Task 2: Add WT settings restoration to uninstall script

**Files:** `installer/uninstall.ps1`

1. Added step 2.5 "Restoring Windows Terminal settings" after executables removal
2. Checks both WT install paths:
   - Store: `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
   - Winget: `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json`
3. For each path with `.matrix-original` backup:
   - Copies backup to settings.json
   - Removes backup file
4. Updated final message to reflect settings restoration

**Commit:** `839abf9 fix(14-02): restore WT settings on uninstall`

## Bugs Fixed

| Bug ID | Description | Fix |
|--------|-------------|-----|
| BUG-TRANS04 | Acrylic blur causes hazy appearance | UseAcrylic = false gives plain transparency |
| BUG-TRANS05 | WT settings persist after uninstall | Restore from .matrix-original backup |

## Verification

1. Build succeeds: `dotnet build MatrixShader/src/MatrixShader.Core/`
2. PowerShell script syntax is valid (tested with `powershell.exe`)
3. UseAcrylic = false in both CreateMatrixProfiles and CreateRedpillProfile
4. OriginalBackupPath property and backup/restore methods exist
5. uninstall.ps1 has matrix-original backup restoration logic

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| UseAcrylic = false | Plain transparency without blur/haze on Windows 11 |
| Preserve FIRST original only | Prevents overwriting user's true original settings |
| Check both WT paths | Support Store and Winget installations |
| Remove backup after restore | Clean uninstall leaves no Matrix artifacts |

## Next Phase Readiness

- Phase 14 wave 2 continues with 14-03 through 14-05
- Transparency settings now correct for Windows 11 users
- Uninstall is now truly clean (restores original settings)
