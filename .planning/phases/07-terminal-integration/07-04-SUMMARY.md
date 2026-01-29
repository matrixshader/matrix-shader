---
phase: 07-terminal-integration
plan: 04
subsystem: terminal
tags: [windows-terminal, profile-creation, shader-paths, settings.json]

# Dependency graph
requires:
  - phase: 07-02
    provides: TerminalSettingsService with LoadSettings, SaveSettings, UpsertProfile
provides:
  - CreateMatrixProfiles (1-8 profiles with shader paths)
  - CreateRedpillProfile (control panel profile)
  - UpdateShaderPaths (auto-fix when Matrix folder moves)
  - GetMatrixProfileCount and HasMatrixProfiles (profile detection)
affects: [07-terminal-integration, 08-test-infrastructure, 09-installer-rewrite]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Profile GUID with braces", "hidden=true opacity=95 profile defaults"]

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/ITerminalSettingsService.cs
    - MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs

key-decisions:
  - "Profile GUID format with braces matching PowerShell: {guid}"
  - "hidden=true, opacity=95 matching install.ps1 defaults"
  - "Regex pattern ^Matrix-\\d+$ for Matrix-N profile detection"

patterns-established:
  - "Profile creation skips existing profiles (idempotent)"
  - "UpdateShaderPaths compares directory paths case-insensitively"

# Metrics
duration: 3min
completed: 2026-01-29
---

# Phase 7 Plan 4: Profile Creation Summary

**Profile creation and shader path management for Matrix-1 through Matrix-8 and Redpill control panel profiles with auto-path correction**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-29T01:28:22Z
- **Completed:** 2026-01-29T01:31:45Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Extended ITerminalSettingsService with 5 new profile management methods
- Implemented CreateMatrixProfiles for up to 8 profiles with shader paths
- Implemented CreateRedpillProfile for control panel with Redpill-Neo.hlsl
- Added UpdateShaderPaths for auto-fixing when Matrix folder moves
- Added GetMatrixProfileCount and HasMatrixProfiles for detection
- DiagnosticLogger integration for MATRIX_DEBUG=1 output

## Task Commits

Tasks committed atomically:

1. **Tasks 1+2: Interface extension and implementation** - `835510a` (feat)
   - Interface and implementation committed together (interface cannot compile without implementation)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/ITerminalSettingsService.cs` - Added 5 profile management method signatures (39 lines added)
- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` - Implementation of profile creation and path management (128 lines added, now 367 total)

## Decisions Made
- Profile GUID format uses braces `{guid}` matching PowerShell format
- Profiles created with hidden=true, opacity=95 matching install.ps1
- Regex pattern `^Matrix-\d+$` for Matrix-N profile detection
- UpdateShaderPaths uses case-insensitive directory comparison
- CreateMatrixProfiles skips existing profiles (idempotent operation)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Profile creation methods ready for use by installer
- UpdateShaderPaths ready for runtime path correction
- Phase 07-terminal-integration complete after this plan
- Ready for Phase 08-test-infrastructure

---
*Phase: 07-terminal-integration*
*Completed: 2026-01-29*
