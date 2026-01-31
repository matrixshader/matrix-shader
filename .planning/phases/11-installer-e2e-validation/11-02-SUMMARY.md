---
phase: 11-installer-e2e-validation
plan: 02
subsystem: installer
tags: [installer, build, inno-setup, executable-naming]
dependency-graph:
  requires: []
  provides: [complete-installer, correct-naming]
  affects: [11-03, 11-05]
tech-stack:
  added: []
  patterns: [self-contained-publish, fallback-lookup]
key-files:
  created: []
  modified:
    - installer/build-installer.ps1
    - installer/MatrixShaderSetup.iss
    - MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs
decisions:
  - id: explicit-self-contained
    choice: Use --self-contained true instead of --no-self-contained:false
    rationale: Clearer intent, avoids confusion with double-negative
  - id: primary-installed-name
    choice: Look for matrix-monitor.exe first, legacy name as fallback
    rationale: Installed name is primary use case, dev name is secondary
metrics:
  duration: 5m
  completed: 2026-01-31
---

# Phase 11 Plan 02: Installer Completeness Summary

**One-liner:** Build script and installer now include all 6 executables with correct naming conventions.

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Add matrixlite to build script and fix build flags | 50e1e75 | Added MatrixLite and Hotkeys projects, changed to explicit --self-contained true |
| 2 | Add matrixlite to Inno Setup installer | f45974c | Added matrixlite.exe and matrix-hotkeys.exe to [Files] section |
| 3 | Fix monitor executable name in Bluepill | 1b004aa | Changed lookup from MatrixShader.Monitor.exe to matrix-monitor.exe |

## Gaps Closed

| Gap ID | Description | Resolution |
|--------|-------------|------------|
| GAP-E01 | matrixlite.exe missing from installer | Added to both build script and Inno Setup |
| GAP-E02 | Monitor name mismatch | Bluepill now looks for matrix-monitor.exe first |
| GAP-E14 | Confusing --no-self-contained:false | Changed to explicit --self-contained true -r win-x64 |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

1. Full solution build: PASS (0 warnings, 0 errors)
2. `grep "MatrixLite" installer/build-installer.ps1`: Found project entry
3. `grep "matrixlite.exe" installer/MatrixShaderSetup.iss`: Found [Files] entry
4. `grep "matrix-monitor.exe" MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs`: Found lookup line

## Files Modified

### installer/build-installer.ps1
- Added `MatrixShader.Cli\MatrixLite` and `MatrixShader.Hotkeys` to projects array
- Changed `--no-self-contained:false` to `--self-contained true -r win-x64`
- Added matrixlite.exe and matrix-hotkeys.exe to verification list
- Added comment explaining self-contained deployment choice

### installer/MatrixShaderSetup.iss
- Added `Source: "publish\matrixlite.exe"` line
- Added `Source: "publish\matrix-hotkeys.exe"` line
- [Files] section now lists all 6 executables

### MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs
- Changed primary lookup to `matrix-monitor.exe` (matches installer)
- Kept `MatrixShader.Monitor.exe` as legacy fallback
- Added diagnostic log showing lookup path

## Next Phase Readiness

**Ready for 11-03 (Installer Polish):**
- Installer is now complete with all executables
- Build script produces self-contained deployment
- Naming conventions are consistent

**Ready for 11-05 (Documentation & Validation):**
- All 6 executables will be present in installed package
- Bluepill will correctly find matrix-monitor.exe
