---
phase: 04-window-identity-service
plan: 03
subsystem: services
tags: [identity, registry, json, persistence, atomic-write, aot]

# Dependency graph
requires:
  - phase: 04-01
    provides: IdentityRegistry/IdentityEntry models, IdentitySource enum
  - phase: 02-02
    provides: Atomic write pattern, UTF8Encoding(false)
provides:
  - Registry persistence at LocalAppData\MatrixShader\identity-registry.json
  - Atomic writes preventing corruption on crash
  - CleanStaleEntries for startup cleanup
  - Fresh vs recovered tracking for confidence scoring
affects: [04-control-panel, 05-profile-management, window-launch]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Atomic file write with temp + File.Move
    - HashSet tracking for recovered vs fresh entries

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/IIdentityService.cs
    - MatrixShader/src/MatrixShader.Core/Services/IdentityService.cs

key-decisions:
  - "Registry path uses LocalApplicationData (AppData\\Local\\MatrixShader)"
  - "Atomic writes: temp file in same directory (.tmp) + File.Move"
  - "CleanStaleEntries checks process existence, handle validity, and 24h age"
  - "_recoveredKeys HashSet distinguishes fresh (1.0) from recovered (0.95) confidence"

patterns-established:
  - "LaunchEntry internal record mirrors IdentityEntry but uses nint for WindowHandle"
  - "SaveRegistryAtomic called from SaveRegistry (public lock wrapper)"

# Metrics
duration: 16min
completed: 2026-01-27
---

# Phase 04 Plan 03: Registry Persistence Summary

**Registry persistence with LocalAppData path, atomic writes via MatrixJsonContext, and stale entry cleanup with 24-hour max age**

## Performance

- **Duration:** 16 min
- **Started:** 2026-01-27T09:52:46Z
- **Completed:** 2026-01-27T10:08:46Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- CleanStaleEntries and RegisterWindowHandle added to IIdentityService interface
- LaunchEntry record defined with all identity properties (ProfileName, ShaderIndex, ProcessId, WindowHandle, LaunchTime, CorrelationId)
- Registry path changed from Documents\Matrix to LocalAppData\MatrixShader per context decision
- SaveRegistryAtomic with temp file + File.Move pattern for crash safety
- LoadRegistry using MatrixJsonContext.Default.IdentityRegistry for AOT compatibility
- CleanStaleEntries validates process existence, handle validity, and entry age
- Fresh vs recovered tracking via _recoveredKeys HashSet for correct confidence scores

## Task Commits

Each task was committed atomically:

1. **Task 1: Add CleanStaleEntries to IIdentityService interface** - `f0349ad` (feat)
2. **Task 2: Define LaunchEntry and implement atomic persistence** - `f0e047d` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/IIdentityService.cs` - Added CleanStaleEntries and RegisterWindowHandle interface methods
- `MatrixShader/src/MatrixShader.Core/Services/IdentityService.cs` - Full persistence implementation with atomic writes

## Decisions Made
- Registry path: LocalAppData\MatrixShader (not Documents\Matrix) per phase context decision
- Atomic writes use temp file in same directory (_registryPath + ".tmp") for cross-drive safety
- CleanStaleEntries validates: dead processes, invalid handles, 24h age cutoff
- _recoveredKeys HashSet tracks which entries were loaded from disk vs registered fresh this session
- Fresh registrations get LaunchTracking (1.0 confidence), recovered get LaunchTrackingRecovered (0.95)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Linter simplified CleanStaleEntries to age-only check; restored full implementation (process + handle + age)
- Duplicate CleanStaleEntries method from earlier edit preserved; removed duplicate

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- IdentityService complete with all registry persistence features
- Phase 04 (Window Identity Service) complete
- Ready for Phase 05 (Profile Management) or control panel integration

---
*Phase: 04-window-identity-service*
*Completed: 2026-01-27*
