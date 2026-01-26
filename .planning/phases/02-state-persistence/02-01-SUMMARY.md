---
phase: 02-state-persistence
plan: 01
subsystem: serialization
tags: [json, aot, source-generator, native-aot, system-text-json]

# Dependency graph
requires:
  - phase: 01-shader-service-foundation
    provides: Model types (MatrixState, ShaderConfig, LayoutConfig)
provides:
  - MatrixJsonContext source-generated JSON serializer
  - AOT-safe enum serialization via UseStringEnumConverter
  - Build-time detection of reflection-based serialization
affects: [02-state-persistence, 03-window-lifecycle, config-loading, state-persistence]

# Tech tracking
tech-stack:
  added: []
  patterns: [source-generated-json, aot-safe-serialization]

key-files:
  created:
    - MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs
  modified:
    - MatrixShader/src/MatrixShader.Core/Models/MatrixState.cs
    - MatrixShader/src/MatrixShader.Core/MatrixShader.Core.csproj

key-decisions:
  - "UseStringEnumConverter in context for AOT-safe enum handling (not per-property JsonConverter)"
  - "JsonSerializerIsReflectionEnabledByDefault=false for build-time AOT safety"
  - "Dictionary<int, ShaderConfig> explicitly registered (required for nested collections)"

patterns-established:
  - "AOT-safe JSON: Use MatrixJsonContext.Default for all serialization"
  - "Enum handling: UseStringEnumConverter in context, not [JsonConverter] on properties"

# Metrics
duration: 6min
completed: 2026-01-26
---

# Phase 02 Plan 01: AOT JSON Context Summary

**Source-generated MatrixJsonContext with AOT-safe enum handling and build-time reflection detection**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-26T15:37:30Z
- **Completed:** 2026-01-26T15:43:03Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Created MatrixJsonContext with source-generated serialization for all model types
- Removed non-generic JsonStringEnumConverter from MatrixState (SYSLIB1034 warning fixed)
- Enabled JsonSerializerIsReflectionEnabledByDefault=false for build-time AOT safety
- IL2026 warnings now visible for ConfigService/IdentityService (to be fixed in 02-02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MatrixJsonContext** - `f574af1` (feat)
2. **Task 2: Remove non-generic enum converter** - `3afe7f5` (refactor)
3. **Task 3: Add AOT safety settings** - `0eed0c7` (chore)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs` - Source-generated JSON context with all model types
- `MatrixShader/src/MatrixShader.Core/Models/MatrixState.cs` - Removed [JsonConverter] attribute, cleaned imports
- `MatrixShader/src/MatrixShader.Core/MatrixShader.Core.csproj` - Added JsonSerializerIsReflectionEnabledByDefault=false

## Decisions Made
- **UseStringEnumConverter in context:** Rather than per-property `[JsonConverter(typeof(JsonStringEnumConverter))]`, use context-level `UseStringEnumConverter = true` which is AOT-safe
- **Explicit Dictionary registration:** `Dictionary<int, ShaderConfig>` must be explicitly registered for source generators to handle nested collections
- **Build-time safety:** `JsonSerializerIsReflectionEnabledByDefault=false` ensures any reflection-based serialization is caught at compile time, not runtime

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed as specified.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- MatrixJsonContext ready for use in ConfigService and IdentityService
- Plan 02-02 will migrate existing services to use the new AOT-safe context
- IL2026 warnings in ConfigService.cs and IdentityService.cs are expected and will be resolved in 02-02

---
*Phase: 02-state-persistence*
*Completed: 2026-01-26*
