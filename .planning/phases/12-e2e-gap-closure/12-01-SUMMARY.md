---
phase: 12-e2e-gap-closure
plan: 01
subsystem: core
tags: [regex, windows-terminal, wt.exe, shader, path-resolution]

# Dependency graph
requires:
  - phase: 11-installer-e2e-validation
    provides: Initial CLI apps and installer infrastructure
provides:
  - Fixed shader regex replacement (no more $10.0 bug)
  - Multi-path Windows Terminal detection (Store, Winget, Scoop, Chocolatey)
  - Dynamic wt.exe path discovery
  - Dynamic settings.json path resolution
affects: [12-02, 12-03, 12-04, 12-05, 12-06, 12-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - MatchEvaluator for regex replacement (avoids backreference issues)
    - Multi-path discovery pattern for cross-install compatibility

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs
    - MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs
    - MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs
    - MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs
    - MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs
    - MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs

key-decisions:
  - "Use MatchEvaluator delegate instead of replacement string for regex"
  - "Check multiple paths for WT settings in priority order"
  - "Fall back to 'wt.exe' in PATH if no explicit path found"

patterns-established:
  - "MatchEvaluator pattern: m => m.Groups[1].Value + replacement"
  - "Multi-path discovery: WtSettingsPaths.FirstOrDefault(File.Exists)"

# Metrics
duration: 18min
completed: 2026-02-01
---

# Phase 12 Plan 01: Shader and WT Detection Fixes Summary

**Fixed shader regex replacement bug (BUG-SHADER01) and comprehensive Windows Terminal detection for Store, Winget, Scoop, and Chocolatey installations (BUG-WT01-04)**

## Performance

- **Duration:** 18 min
- **Started:** 2026-02-01T09:45:00Z
- **Completed:** 2026-02-01T10:03:00Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Fixed critical shader generation bug where value=0.0 became "$10.0"
- Added multi-path Windows Terminal detection supporting all install types
- Dynamic wt.exe discovery from PATH, Scoop, Chocolatey, and WindowsApps
- Dynamic settings.json resolution for TerminalSettingsService

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix shader regex replacement bug** - `7650e56` (fix)
2. **Task 2: Comprehensive Windows Terminal detection** - `23253d1` (feat)
3. **Task 3: Dynamic wt.exe launching** - `1ede59b` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs` - Fixed ReplaceDefine to use MatchEvaluator
- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` - Added WtSettingsPaths, GetWindowsTerminalExePath()
- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` - Use CliBootstrap.GetSettingsPath()
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` - Dynamic wt.exe path (2 locations)
- `MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs` - Dynamic wt.exe path
- `MatrixShader/src/MatrixShader.Cli/Redpill/Program.cs` - Dynamic wt.exe path

## Decisions Made
- **MatchEvaluator vs Regex.Escape:** Chose MatchEvaluator delegate for clarity and to completely avoid any replacement string interpretation issues
- **Priority order for settings paths:** Store first (most common), then Winget, Scoop, Chocolatey
- **Fallback to "wt.exe":** If GetWindowsTerminalExePath() returns null, fall back to relying on PATH

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed successfully with verification passing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Shader generation now produces correct #define values
- All CLI apps work with any Windows Terminal installation method
- Ready for 12-02 (MatrixLite ANSI rendering fixes)
- No blockers identified

---
*Phase: 12-e2e-gap-closure*
*Completed: 2026-02-01*
