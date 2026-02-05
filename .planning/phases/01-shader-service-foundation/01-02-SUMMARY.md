---
phase: 01-shader-service-foundation
plan: 02
subsystem: core
tags: [shaderservice, regex, hlsl, parsing, csharp]

# Dependency graph
requires:
  - phase: 01-01
    provides: ShaderConfig with correct validation ranges
provides:
  - ShaderService with correct HLSL regex patterns
  - Float-based layer parsing (> 0.5 threshold)
  - CultureInfo.InvariantCulture for locale-safe parsing
affects: [01-03, all shader reading/writing operations]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HLSL #define names as source of truth for regex patterns"
    - "Float comparison (> 0.5) for boolean toggles in HLSL"
    - "InvariantCulture for float parsing (locale safety)"

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs

key-decisions:
  - "Layer toggles parsed as float > 0.5, not int == 1"
  - "All regex patterns renamed to match HLSL exactly (e.g., RainRRegex not ColorRRegex)"
  - "Removed ParseBool/ReplaceBoolDefine (layers written as floats)"

patterns-established:
  - "HLSL file is source of truth for #define names"
  - "ParseFloat validates input format before parsing"
  - "InvariantCulture ensures consistent parsing across locales"

# Metrics
duration: 5min
completed: 2026-01-26
---

# Phase 01 Plan 02: ShaderService Regex Fix Summary

**Fixed all 11 ShaderService regex patterns to match actual HLSL #define names (RAIN_R, GLOW_STRENGTH, SHOW_L1, etc.)**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-26T00:29:05Z
- **Completed:** 2026-01-26T00:33:48Z
- **Tasks:** 3 (combined into single commit)
- **Files modified:** 1

## Accomplishments

- Fixed all 11 regex patterns to match actual HLSL #define names in shaders/Matrix-1.hlsl
- Changed layer parsing from int comparison ("1"/"0") to float comparison (> 0.5)
- Added input validation and InvariantCulture to ParseFloat for locale-safe, robust parsing
- Removed dead code (ParseBool, ReplaceBoolDefine methods)

## Task Commits

All tasks logically connected and committed together:

1. **Tasks 1-3: Fix regex patterns, layer parsing, and ParseFloat validation** - `94beab1` (fix)

Pattern mapping fixed:
| Wrong Pattern | Correct Pattern | Actual HLSL |
|---------------|-----------------|-------------|
| COLOR_R | RAIN_R | #define RAIN_R 0.0 |
| COLOR_G | RAIN_G | #define RAIN_G 1.0 |
| COLOR_B | RAIN_B | #define RAIN_B 0.3 |
| SPEED | RAIN_SPEED | #define RAIN_SPEED 0.8 |
| GLOW | GLOW_STRENGTH | #define GLOW_STRENGTH 0.8 |
| WIDTH | CHAR_WIDTH | #define CHAR_WIDTH 10.0 |
| TRAIL | TRAIL_POWER | #define TRAIL_POWER 8.0 |
| DENSITY | RAIN_DENSITY | #define RAIN_DENSITY 0.4 |
| LAYER1 | SHOW_L1 | #define SHOW_L1 1.0 |
| LAYER2 | SHOW_L2 | #define SHOW_L2 1.0 |
| LAYER3 | SHOW_L3 | #define SHOW_L3 1.0 |

## Files Created/Modified

- `MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs` - Fixed regex patterns, layer parsing, ParseFloat validation

## Decisions Made

- **Layer parsing as float > 0.5:** HLSL uses 1.0/0.0 for toggle layers, not integers. Threshold 0.5 distinguishes on/off.
- **InvariantCulture for parsing:** Some locales use comma as decimal separator, which would break float parsing. InvariantCulture ensures consistent behavior.
- **Combined tasks into single commit:** All three tasks modify the same code paths and are logically connected (regex patterns, their usage in ParseConfig, and the helper method).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - straightforward regex pattern and parsing updates.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ShaderService can now correctly read actual shader parameters from existing HLSL files
- Plan 01-03 (ShaderService.CreateShaderFile) is unblocked
- Integration testing can verify ReadConfig returns actual values (not always defaults)

---
*Phase: 01-shader-service-foundation*
*Completed: 2026-01-26*
