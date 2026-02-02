# Phase 13 Plan 06: BUG-TRANS03 - Transparency Scope Summary

**One-liner:** Fixed transparency to only affect Matrix profiles (85% opacity), preserving 100% opacity for non-Matrix WT windows

## Metadata

| Field | Value |
|-------|-------|
| Phase | 13-post-e2e-polish |
| Plan | 06 |
| Status | COMPLETE |
| Duration | ~6 minutes |
| Completed | 2026-02-02 |

## What Was Done

### Task 1: Audit and fix transparency settings in profile creation

**Findings:**
- No code was modifying `profiles.defaults` (good baseline)
- However, Matrix profiles used Opacity = 95 instead of required 85
- `UseAcrylic` was set to `false` in model default - transparency requires it to be `true`

**Changes Made:**
1. **TerminalProfile.cs (model)**:
   - Changed `Opacity` default from 95 to 85
   - Changed `UseAcrylic` default from `false` to `true`
   - Added explanatory comment about per-profile vs defaults scope

2. **TerminalSettingsService.cs**:
   - Updated `CreateMatrixProfiles()`: explicit `Opacity = 85`, `UseAcrylic = true`
   - Updated `CreateRedpillProfile()`: explicit `Opacity = 85`, `UseAcrylic = true`
   - Added comments explaining per-profile scope

### Task 2: Verify wakeupneo profile creation

**Findings:**
- WakeupNeo delegates all profile creation to TerminalSettingsService
- No direct opacity manipulation in WakeupNeo/Program.cs
- Build successful after Task 1 fixes

## Files Modified

| File | Change |
|------|--------|
| `MatrixShader/src/MatrixShader.Core/Models/TerminalProfile.cs` | Updated defaults: Opacity=85, UseAcrylic=true, added scope comments |
| `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` | Explicit per-profile opacity in CreateMatrixProfiles and CreateRedpillProfile |

## Commits

| Hash | Message |
|------|---------|
| 20e1ca1 | fix(13-06): set per-profile opacity to 85% for Matrix windows only |

## Verification Results

- [x] No code modifies profiles.defaults.opacity
- [x] Matrix profiles created with Opacity = 85
- [x] UseAcrylic = true for transparency effect
- [x] Comment explains per-profile vs defaults scope
- [x] Both Core and WakeupNeo build without errors

## Bug Resolution

**BUG-TRANS03:** After installing WT, ALL new windows open 100% transparent - not just Matrix windows.

**Root Cause:** Transparency settings were not an issue at the defaults level (no code touched defaults), but the values needed adjustment:
- Opacity was 95% instead of user-required 85%
- UseAcrylic was false, preventing transparency effect

**Fix:** Set explicit per-profile opacity (85%) and enable UseAcrylic on Matrix profiles only. Non-Matrix WT windows remain unaffected at 100% opacity since we never touch profiles.defaults.

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

1. **Windows Terminal transparency behavior:**
   - `Opacity` controls window transparency (0-100)
   - `UseAcrylic = true` must be set for Opacity to take effect
   - Settings are per-profile in `profiles.list`, not in `profiles.defaults`

2. **Model defaults vs explicit values:**
   - Changed TerminalProfile model defaults for consistency
   - Also set explicit values in profile creation methods for clarity
   - Both approaches ensure 85% opacity for Matrix windows
