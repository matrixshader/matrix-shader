---
phase: 01-shader-service-foundation
plan: 03
subsystem: core
tags: [shaderservice, hlsl, template, csharp, file-io]

# Dependency graph
requires:
  - phase: 01-01
    provides: ShaderConfig with correct validation ranges
provides:
  - ShaderTemplate.Template with complete HLSL code
  - WriteConfig with correct #define names (RAIN_R, RAIN_SPEED, etc.)
  - CreateShader for generating new shader files from template
  - Auto-creation of missing shader files in WriteConfig
affects: [01-02, 02-layout-engine, all shader consumers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Template-based shader generation with placeholder substitution"
    - "Atomic file writes with temp file + move pattern"
    - "UTF-8 without BOM for HLSL compatibility"
    - "InvariantCulture for float formatting (locale-independent)"

key-files:
  created:
    - MatrixShader/src/MatrixShader.Core/Constants/ShaderTemplate.cs
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs
    - MatrixShader/src/MatrixShader.Core/Services/IShaderService.cs

key-decisions:
  - "F1 format (one decimal place) for shader values, matching PowerShell output"
  - "Layer values written as floats (1.0/0.0) not integers to match HLSL"
  - "WriteConfig auto-creates missing files via CreateShader (no FileNotFoundException)"
  - "Simplified ReplaceDefine to use direct regex replacement instead of GeneratedRegex"

patterns-established:
  - "Template interpolation: ShaderTemplate.Template.Replace(\"{PLACEHOLDER}\", value)"
  - "Atomic writes: Path.GetTempFileName() + File.Move(overwrite: true)"
  - "UTF8Encoding(false) for files that need no BOM"

# Metrics
duration: 8min
completed: 2026-01-26
---

# Phase 1 Plan 3: ShaderService WriteConfig and CreateShader Summary

**Fixed WriteConfig to use correct HLSL #define names (RAIN_R, RAIN_SPEED, GLOW_STRENGTH) and added CreateShader method for generating new shader files from template**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-26T00:29:56Z
- **Completed:** 2026-01-26T00:38:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Created ShaderTemplate.cs with complete HLSL shader template (81 lines of GPU rendering code)
- Fixed WriteConfig to use correct #define names: RAIN_R, RAIN_G, RAIN_B, RAIN_SPEED, GLOW_STRENGTH, CHAR_WIDTH, TRAIL_POWER, RAIN_DENSITY, SHOW_L1, SHOW_L2, SHOW_L3
- Added CreateShader method to generate new shader files from template with proper placeholder substitution
- WriteConfig now auto-creates missing shader files instead of throwing FileNotFoundException
- All file writes use UTF-8 without BOM and atomic temp+move pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ShaderTemplate constant** - `4857554` (feat)
2. **Task 2: Fix WriteConfig #define names and format** - `5b16583` (fix)
3. **Task 3: Add CreateShader to interface** - `51e78a1` (feat)

## Files Created/Modified

- `MatrixShader/src/MatrixShader.Core/Constants/ShaderTemplate.cs` - Complete HLSL template with 12 placeholders for parameter injection
- `MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs` - Fixed WriteConfig, added CreateShader and GenerateShaderContent methods
- `MatrixShader/src/MatrixShader.Core/Services/IShaderService.cs` - Added CreateShader method declaration

## Decisions Made

- **F1 format:** One decimal place for all float values, matching PowerShell's output format
- **Float layers:** Layer toggles written as 1.0/0.0 floats instead of 1/0 integers to match HLSL semantics
- **Auto-create:** WriteConfig calls CreateShader when file doesn't exist, eliminating need for separate file creation step
- **Simplified regex:** ReplaceDefine uses direct Regex.Replace pattern instead of passing GeneratedRegex instances

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed without issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ShaderService now fully functional for both reading and writing shader files
- ReadConfig (from 01-02) + WriteConfig (this plan) + CreateShader provide complete shader I/O
- Ready for Phase 2 (Layout Engine) to use shader services
- End-to-end testing recommended: delete shader file, call CreateShader, verify Windows Terminal renders it

---
*Phase: 01-shader-service-foundation*
*Completed: 2026-01-26*
