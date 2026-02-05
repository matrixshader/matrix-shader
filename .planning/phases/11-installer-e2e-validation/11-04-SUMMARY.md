---
phase: 11-installer-e2e-validation
plan: 04
subsystem: runtime-safety
tags: [profile-verification, shader-support, path-resolution, wt-detection]

dependency-graph:
  requires: ["11-01"]
  provides:
    - profile-verification
    - shader-support-detection
    - redpill-path-resolution
  affects: []

tech-stack:
  added: []
  patterns:
    - tuple-return-values
    - optional-parameter-fallback

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs
    - MatrixShader/src/MatrixShader.Core/Services/ITerminalSettingsService.cs
    - MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs
    - MatrixShader/src/MatrixShader.Core/Helpers/ConsoleHelper.cs
    - MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs

decisions:
  - id: optional-controlpanelpath
    choice: "Make controlPanelPath optional with auto-resolution"
    rationale: "Simplifies API, auto-finds redpill.exe in installed or local location"
  - id: tuple-return-for-canuse
    choice: "Return (bool, string) tuple from CanUseShaders()"
    rationale: "Provides both result and reason in single call, clearer than out parameters"
  - id: verify-after-save
    choice: "Verify profiles immediately after SaveSettings"
    rationale: "Catches issues early, before user sees confusing errors at runtime"

metrics:
  duration: "20 minutes"
  completed: 2026-01-31
---

# Phase 11 Plan 04: Runtime Safety Summary

Runtime safety checks for Windows Terminal profile creation, path resolution, and shader support verification.

**One-liner:** Profile verification, Redpill path auto-resolution, and CanUseShaders() for graceful WT detection.

## What Was Done

### Task 1: Profile Verification (38df489)
Added `VerifyProfiles()` method to TerminalSettingsService:
- Checks that expected Matrix-N profiles exist in settings
- Validates shader paths point to existing files
- Returns `ProfileVerificationResult` with MissingProfiles and InvalidShaderPaths lists
- Added diagnostic logging of shader path in CreateMatrixProfiles

**Key code:**
```csharp
public ProfileVerificationResult VerifyProfiles(int profileCount)
{
    var settings = LoadSettings();
    var profiles = settings.Profiles?.List ?? new List<TerminalProfile>();
    // Check each Matrix-N profile exists and has valid shader path
    // Return detailed result
}
```

### Task 2: Redpill Path Resolution (e5a879b)
Fixed GAP-E13 (redpill profile path issue):
- Added `GetRedpillExecutablePath()` helper method
- Priority order: Program Files (installed) -> AppContext.BaseDirectory (local)
- Made controlPanelPath parameter optional with auto-resolution
- Updated interface signature to match

**Key code:**
```csharp
private static string GetRedpillExecutablePath()
{
    var programFilesPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
        "MatrixShader", "redpill.exe");
    if (File.Exists(programFilesPath)) return programFilesPath;
    // Fallback to local, then return expected path
}
```

### Task 3: CanUseShaders Check (187e1c6)
Added shader support verification to ShaderService:
- Static `CanUseShaders()` returns (bool CanUse, string Reason) tuple
- Checks both Store and unpackaged (winget/scoop) WT installations
- Verifies Windows 10 1903+ (build 18362) for shader support
- Returns helpful message suggesting matrixlite fallback
- Added `GetWindowsTerminalVersion()` for diagnostics (best-effort)

**Key code:**
```csharp
public static (bool CanUse, string Reason) CanUseShaders()
{
    // Check Store WT: LocalAppData/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json
    // Check unpackaged WT: LocalAppData/Microsoft/Windows Terminal/settings.json
    // Check Windows version >= 10.0.18362
    // Return true with reason, or false with helpful fallback message
}
```

### Task 4: WakeupNeo Integration (0a2d19f)
Integrated runtime safety checks into WakeupNeo wizard:
- Shader support check at startup with continue/exit prompt
- Profile verification after creation with warning display
- Added `WriteLineWarning()` and `WriteWarning()` to ConsoleHelper for yellow output
- Diagnostic logging of verification success

**Key flow:**
```
1. Check ShaderService.CanUseShaders()
   - If false: Show warning, offer matrixlite fallback
2. Run normal wizard flow
3. Create profiles and shaders
4. Call VerifyProfiles(profileCount)
   - If issues: Display warnings about missing/invalid profiles
5. Continue with window launch
```

## Gaps Closed

| Gap ID | Description | Resolution |
|--------|-------------|------------|
| GAP-E06 | No WT shader support verification | CanUseShaders() checks WT installation and Windows version |
| GAP-E07 | No profile verification after creation | VerifyProfiles() validates profiles and shader paths |
| GAP-E13 | Redpill profile may have wrong exe path | GetRedpillExecutablePath() auto-resolves correct location |

## FRX Requirements Satisfied

| Requirement | Description | Status |
|-------------|-------------|--------|
| FRX-01 | wakeupneo works on fresh WT installation | CanUseShaders() returns true when WT installed |
| FRX-03 | Graceful error when WT not installed | Returns false with "Use 'matrixlite'" message |

## Commits

| Hash | Description |
|------|-------------|
| 38df489 | feat(11-04): add profile verification to TerminalSettingsService |
| e5a879b | feat(11-04): add reliable Redpill executable path resolution |
| 187e1c6 | feat(11-04): add CanUseShaders() and GetWindowsTerminalVersion() checks |
| 0a2d19f | feat(11-04): add shader check and profile verification to WakeupNeo |

## Files Modified

- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` - VerifyProfiles, GetRedpillExecutablePath
- `MatrixShader/src/MatrixShader.Core/Services/ITerminalSettingsService.cs` - Interface updates
- `MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs` - CanUseShaders, GetWindowsTerminalVersion
- `MatrixShader/src/MatrixShader.Core/Helpers/ConsoleHelper.cs` - WriteLineWarning, WriteWarning
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` - Startup check, verification display

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added WriteLineWarning() to ConsoleHelper**
- **Found during:** Task 4
- **Issue:** ConsoleHelper lacked yellow/warning output capability
- **Fix:** Added WARNING_YELLOW constant and WriteLineWarning/WriteWarning methods
- **Files modified:** ConsoleHelper.cs
- **Commit:** 0a2d19f

## Verification Results

All verification checks passed:
- Full solution builds without errors
- `VerifyProfiles` method exists in TerminalSettingsService
- `GetRedpillExecutablePath` helper exists
- `CanUseShaders` method exists in ShaderService
- Profile verification code exists in WakeupNeo

## Next Phase Readiness

Phase 11 Wave 2 (plans 11-03 and 11-04) complete. Ready for Wave 3:
- 11-05: Documentation & validation (GAP-E08, E09)
