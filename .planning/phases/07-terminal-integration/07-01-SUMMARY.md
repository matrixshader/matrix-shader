---
phase: 07-terminal-integration
plan: 01
subsystem: terminal
tags: [windows-terminal, json, aot, source-generators, settings]

# Dependency graph
requires:
  - phase: 02-state-persistence
    provides: MatrixJsonContext with AOT-compatible JSON serialization pattern
provides:
  - TerminalProfile model for profile representation
  - TerminalSettings model for settings.json structure
  - ProfilesContainer model for profiles.list
  - AOT-compatible serialization for all terminal types
affects: [07-02-terminal-service, 07-03-profile-management]

# Tech tracking
tech-stack:
  added: []
  patterns: [JsonExtensionData for unknown property preservation, JsonPropertyName for dotted properties]

key-files:
  created:
    - MatrixShader/src/MatrixShader.Core/Models/TerminalProfile.cs
    - MatrixShader/src/MatrixShader.Core/Models/TerminalSettings.cs
  modified:
    - MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs

key-decisions:
  - "Record type for TerminalProfile (immutable, pattern matching)"
  - "Class type for TerminalSettings/ProfilesContainer (mutated during updates)"
  - "JsonExtensionData preserves unknown settings.json properties during round-trip"
  - "JsonPropertyName handles dotted 'experimental.pixelShaderPath' property"

patterns-established:
  - "JsonExtensionData pattern: Partial models with extension data preserve full file structure"
  - "Dotted property names: Use JsonPropertyName attribute for nested-looking JSON keys"

# Metrics
duration: 3min
completed: 2026-01-29
---

# Phase 7 Plan 1: Terminal Settings Models Summary

**TerminalProfile and TerminalSettings models with JsonExtensionData for round-trip property preservation and AOT-compatible serialization**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-29T01:02:28Z
- **Completed:** 2026-01-29T01:05:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created TerminalProfile record with all Matrix-specific profile properties
- Created TerminalSettings and ProfilesContainer classes with JsonExtensionData
- Registered all terminal types in MatrixJsonContext for AOT serialization
- Used JsonPropertyName for "experimental.pixelShaderPath" dotted property

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TerminalProfile and TerminalSettings models** - `70b361c` (feat)
2. **Task 2: Register models in MatrixJsonContext for AOT** - `0efbd22` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Models/TerminalProfile.cs` - Profile model with Name, Guid, Commandline, Hidden, Opacity, PixelShaderPath, TabColor
- `MatrixShader/src/MatrixShader.Core/Models/TerminalSettings.cs` - Settings container with Profiles property and JsonExtensionData
- `MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs` - Added [JsonSerializable] for TerminalSettings, TerminalProfile, ProfilesContainer, List<TerminalProfile>

## Decisions Made
- **Record vs Class:** TerminalProfile uses record (immutable, good for pattern matching); TerminalSettings/ProfilesContainer use class (mutated during profile updates)
- **JsonExtensionData:** Critical for preserving unknown properties - settings.json has many fields we don't model, must not lose them during round-trip
- **JsonPropertyName:** Required for "experimental.pixelShaderPath" since C# properties can't have dots in names

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Terminal models ready for TerminalService implementation (07-02)
- JsonExtensionData pattern established for safe settings.json manipulation
- All types registered in AOT context for profile read/write operations

---
*Phase: 07-terminal-integration*
*Completed: 2026-01-29*
