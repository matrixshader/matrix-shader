---
phase: 07-terminal-integration
plan: 02
subsystem: terminal
tags: [windows-terminal, settings-json, atomic-write, json-serialization, error-recovery]

# Dependency graph
requires:
  - phase: 07-01
    provides: TerminalSettings and TerminalProfile models with AOT serialization
  - phase: 02-02
    provides: Atomic write pattern (temp file + File.Move)
provides:
  - ITerminalSettingsService interface for settings.json operations
  - TerminalSettingsService with three-layer error recovery
  - Atomic writes for corruption safety
  - Profile upsert with Matrix profiles at top
affects: [07-03, 07-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Three-layer error recovery (parse -> regex recovery -> fresh defaults)
    - Backup before recovery attempt

key-files:
  created:
    - MatrixShader/src/MatrixShader.Core/Services/ITerminalSettingsService.cs
    - MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs
  modified: []

key-decisions:
  - "Regex-based profile extraction for malformed JSON recovery (handles trailing commas)"
  - "UpsertProfile inserts at beginning so Matrix profiles appear at top of list"
  - "Backup path uses .matrix-backup suffix for easy identification"

patterns-established:
  - "Three-layer error recovery: (1) normal parse, (2) backup + lenient recovery, (3) fresh defaults"
  - "Preserve unknown JSON properties via JsonExtensionData on models (done in 07-01)"

# Metrics
duration: 7min
completed: 2026-01-29
---

# Phase 7 Plan 2: Terminal Settings Service Summary

**TerminalSettingsService with atomic writes and three-layer error recovery for safe settings.json manipulation**

## Performance

- **Duration:** 7 min
- **Started:** 2026-01-29T01:13:59Z
- **Completed:** 2026-01-29T01:21:00Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments
- Created ITerminalSettingsService interface with LoadSettings, SaveSettings, CreateBackup, GetProfile, UpsertProfile
- Implemented TerminalSettingsService (239 lines) with three-layer error recovery
- Atomic write pattern matches existing ConfigService (temp file + File.Move)
- AOT-safe serialization using MatrixJsonContext.Default.TerminalSettings

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ITerminalSettingsService interface** - `5ab5641` (feat)
2. **Task 2: Implement TerminalSettingsService with error recovery** - `5963362` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/ITerminalSettingsService.cs` - Interface defining settings operations
- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` - Implementation with error recovery

## Decisions Made
- Used MatrixJsonContext.Default.TerminalSettings directly (no custom JsonSerializerOptions) for AOT compatibility
- Regex pattern matches profile objects with name and guid for lenient recovery
- UpsertProfile inserts new profiles at index 0 so Matrix profiles appear at top

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed AOT serialization warning**
- **Found during:** Task 2 (TerminalSettingsService implementation)
- **Issue:** Plan used `JsonSerializer.Serialize(settings, typeof(TerminalSettings), options)` which triggers IL2026 AOT warning
- **Fix:** Changed to `JsonSerializer.Serialize(settings, MatrixJsonContext.Default.TerminalSettings)` for AOT-safe serialization
- **Files modified:** TerminalSettingsService.cs line 108
- **Verification:** Build succeeds with 0 warnings
- **Committed in:** 5963362 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix necessary for AOT compatibility. No scope creep.

## Issues Encountered
None - implementation followed plan structure

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- TerminalSettingsService ready for ProfileManagerService in 07-03
- Can read/write settings.json with full error recovery
- Profile upsert ready for Matrix profile management

---
*Phase: 07-terminal-integration*
*Completed: 2026-01-29*
