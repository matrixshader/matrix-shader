---
phase: 11-platform-sync-v1-0-4-features
plan: 01
subsystem: shaders
tags: [glsl, hlsl, spirv, msl, ghostty, shadertoy]

# Dependency graph
requires:
  - phase: none
    provides: n/a
provides:
  - 6 GLSL bonus shader ports (aurora-borealis, aurora-rain, fireplace, matrix-codevision, matrix-ultra, rain-on-glass)
  - White-room CRT picker shader for construct command
  - SPIR-V pipeline test suite for all 7 shaders
affects: [11-02, 11-03, construct CLI, redpill TUI background]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HLSL-to-GLSL port pattern: systematic substitution table (float2->vec2, lerp->mix, saturate->clamp, frac->fract, static const->const with constructor syntax)"
    - "CRT shader state machine: #define STATE/SELECTED/STATE_TIME for power-on/picking/power-off"

key-files:
  created:
    - shaders-glsl/aurora-borealis-ghostty.glsl
    - shaders-glsl/aurora-rain-ghostty.glsl
    - shaders-glsl/fireplace-ghostty.glsl
    - shaders-glsl/matrix-codevision-ghostty.glsl
    - shaders-glsl/matrix-ultra-ghostty.glsl
    - shaders-glsl/rain-on-glass-ghostty.glsl
    - shaders-glsl/white-room-ghostty.glsl
    - linux/tests/test_bonus_shaders.py
  modified: []

key-decisions:
  - "Manual HLSL-to-GLSL port over automated transpiler -- proven approach from Matrix rain + Redpill-Neo, only 6 shaders"
  - "White-room shader created from scratch -- WhiteRoom.hlsl not in git history, CRT aesthetic per CONTEXT.md discretion"
  - "GLSL modulo for MatrixCodeVision uses manual formula (idx - (idx/6)*6) instead of % operator to avoid GLSL int mod issues"
  - "glslangValidator requires -S frag flag when input filename doesn't end in .frag -- tests use tempfile with .frag extension"

patterns-established:
  - "SPIR-V pipeline test pattern: prepend Ghostty prefix, compile GLSL->SPIR-V, cross-compile to MSL, skip if tools unavailable"

requirements-completed: [SYNC-02]

# Metrics
duration: 16min
completed: 2026-03-14
---

# Phase 11 Plan 01: Bonus Shader Ports Summary

**7 GLSL shaders ported/created (6 HLSL ports + white-room CRT), all verified through SPIR-V->MSL cross-compilation pipeline, 35 tests passing**

## Performance

- **Duration:** 16 min
- **Started:** 2026-03-14T01:27:06Z
- **Completed:** 2026-03-14T01:43:06Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- Ported all 6 Windows HLSL bonus shaders to GLSL Shadertoy API for Ghostty: Aurora Borealis (northern lights), Aurora Rain (aurora + rain on glass), Fireplace (flames/sparks/embers), Matrix CodeVision (3D code city flythrough), Matrix Ultra (10-layer parallax showcase), Rain on Glass (raindrops with refraction)
- Created original white-room CRT picker shader with power-on/picking/power-off state machine and scanlines/curvature/phosphor glow
- Built comprehensive test suite: 35 tests covering file existence, mainImage entry point, no HLSL syntax, GLSL->SPIR-V compilation, and SPIR-V->MSL cross-compilation

## Task Commits

Each task was committed atomically:

1. **Task 1: Port all 6 HLSL bonus shaders to GLSL** - `6791ade` (feat)
2. **Task 2: Create white-room CRT picker shader** - `1761cd4` (feat)
3. **Task 3: Verify all 7 shaders via SPIR-V pipeline** - `24cbdbf` (test)

## Files Created/Modified
- `shaders-glsl/aurora-borealis-ghostty.glsl` - Northern lights with curtains, stars, color cycling
- `shaders-glsl/aurora-rain-ghostty.glsl` - Aurora through rain-streaked glass with lightning
- `shaders-glsl/fireplace-ghostty.glsl` - Crackling fire with sparks, embers, heat haze distortion
- `shaders-glsl/matrix-codevision-ghostty.glsl` - 3D code city flythrough with color-cycling presets
- `shaders-glsl/matrix-ultra-ghostty.glsl` - 10 parallax layers, bloom, DOF, god rays, reflections
- `shaders-glsl/rain-on-glass-ghostty.glsl` - Raindrops on window with refraction, background rain
- `shaders-glsl/white-room-ghostty.glsl` - CRT construct picker with state machine animations
- `linux/tests/test_bonus_shaders.py` - 35 tests for SPIR-V pipeline verification

## Decisions Made
- Manual HLSL-to-GLSL port chosen over automated transpiler (proven approach, only 6 shaders)
- White-room shader created from scratch since WhiteRoom.hlsl was not in Windows git history
- MatrixCodeVision modulo uses manual formula to avoid GLSL integer modulo edge cases
- Test suite uses `.frag` extension in temp files since glslangValidator requires stage detection

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Rebuilt SPIRV-Cross from source**
- **Found during:** Task 3 (SPIR-V pipeline verification)
- **Issue:** spirv-cross binary not found at /tmp/SPIRV-Cross/build/spirv-cross -- /tmp doesn't persist across reboots
- **Fix:** Cloned KhronosGroup/SPIRV-Cross and built from source with cmake
- **Files modified:** None (external tool at /tmp/SPIRV-Cross/)
- **Verification:** All 7 shaders cross-compile to MSL successfully
- **Committed in:** N/A (build tool, not project file)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required to complete Task 3 verification. No scope creep.

## Issues Encountered
- glslangValidator cannot auto-detect shader stage from `.glsl` filename -- required explicit `-S frag` flag. Tests updated to use `.frag` temp file extension.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 7 bonus GLSL shaders ready for construct CLI integration (Plan 03)
- MatrixCodeVision ready for redpill TUI background integration
- White-room shader ready for construct color picker

## Self-Check: PASSED

All 8 created files verified present. All 3 task commits verified in git log.

---
*Phase: 11-platform-sync-v1-0-4-features*
*Completed: 2026-03-14*
