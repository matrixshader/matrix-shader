---
phase: 11-installer-e2e-validation
plan: 01
subsystem: infra
tags: [path-resolution, localappdata, installer, windows]

# Dependency graph
requires:
  - phase: 08.1-gap-closure
    provides: Core services architecture
provides:
  - Canonical path resolution using %LOCALAPPDATA%\MatrixShader
  - GetInstalledShadersDirectory() for Program Files location
  - No hardcoded developer paths in codebase
affects: [11-02, 11-03, 11-04, 11-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - LocalAppData as canonical user data location
    - Program Files for installed binaries
    - Fallback chain for path resolution

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs
    - MatrixShader/src/MatrixShader.Core/Services/ConfigService.cs
    - MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs

key-decisions:
  - "LocalAppData for user data (shaders, config) - standard Windows pattern"
  - "Program Files as fallback for installed shaders"
  - "DiagnosticLogger keeps Documents\Matrix for logs - matches PowerShell behavior"

patterns-established:
  - "Path priority: LocalAppData > Program Files > AppDir"
  - "Log shader path selection for debugging"

# Metrics
duration: 13min
completed: 2026-01-31
---

# Phase 11 Plan 01: Path Resolution Architecture Summary

**Migrated all path resolution to %LOCALAPPDATA%\MatrixShader with Program Files fallback for installed shaders**

## Performance

- **Duration:** 13 min
- **Started:** 2026-01-31T05:11:40Z
- **Completed:** 2026-01-31T05:24:12Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- CliBootstrap uses %LOCALAPPDATA%\MatrixShader as canonical location (was Documents\Matrix)
- Removed hardcoded developer path from ConfigService (C:\Users\ehome\Documents\Matrix)
- ShaderService prioritizes LocalAppData > Program Files > AppDir
- Added GetInstalledShadersDirectory() method for installer location
- Enhanced diagnostic logging for path selection debugging

## Task Commits

Each task was committed atomically:

1. **Task 1: Update CliBootstrap path resolution** - `35fd42d` (feat)
2. **Task 2: Remove hardcoded dev path from ConfigService** - `29558c9` (fix)
3. **Task 3: Update ShaderService path priority** - `852ef65` (feat)

## Files Created/Modified

- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` - Changed MatrixDir to LocalAppData, added InstalledShadersDir constant, GetInstalledShadersDirectory() method, and shader availability logging
- `MatrixShader/src/MatrixShader.Core/Services/ConfigService.cs` - Removed hardcoded ehome path, changed to LocalAppData as primary config location
- `MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs` - Updated path priority order, added diagnostic logging for selected path

## Decisions Made

1. **LocalAppData as canonical location** - Standard Windows pattern, avoids OneDrive sync issues with Documents folder
2. **Keep Program Files as fallback** - Installer places files there, wakeupneo copies to LocalAppData
3. **DiagnosticLogger keeps Documents\Matrix for logs** - Intentional: matches PowerShell behavior, easier user access to logs

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed without issues. Full solution build passed.

## Verification Results

- Full solution build: PASSED
- Grep for "Documents.*Matrix" in src: Only DiagnosticLogger (logs, intentional)
- Grep for "ehome" in src: No matches found
- winget Windows Terminal install: Exists in CliBootstrap.cs

## Gaps Closed

| Gap | Description | Resolution |
|-----|-------------|------------|
| GAP-E03 | Shader path priority wrong | ShaderService now prefers LocalAppData > Program Files |
| GAP-E04 | Hardcoded dev path | Removed C:\Users\ehome\Documents\Matrix from ConfigService |
| GAP-E12 | Profiles point to wrong location | CliBootstrap.GetShadersDirectory() returns LocalAppData path |

## Next Phase Readiness

- Path resolution architecture complete
- Ready for 11-02 (Installer completeness) - paths are now correct for installed location
- No blockers

---
*Phase: 11-installer-e2e-validation*
*Completed: 2026-01-31*
