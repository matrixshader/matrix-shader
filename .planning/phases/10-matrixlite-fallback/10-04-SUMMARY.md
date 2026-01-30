---
phase: 10-matrixlite-fallback
plan: 04
subsystem: cli
tags: [matrixlite, standalone, native-aot, text-renderer, fallback]

# Dependency graph
requires:
  - phase: 10-01
    provides: Lite mode detection pattern
  - phase: 10-02
    provides: WakeupNeo Lite mode integration
  - phase: 09-native-aot-polish
    provides: MatrixShader.Lite library with FallbackMenu
provides:
  - matrixlite.exe standalone CLI
  - Direct text-based Matrix rain without environment detection
  - Native AOT single-file deployment
affects: [installation, user-experience, distribution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Standalone CLI entry point launching directly into library component
    - Theatrical typewriter intro animation

key-files:
  created:
    - MatrixShader/src/MatrixShader.Cli/MatrixLite/Program.cs
    - MatrixShader/src/MatrixShader.Cli/MatrixLite/MatrixShader.Cli.MatrixLite.csproj
  modified:
    - MatrixShader/MatrixShader.sln

key-decisions:
  - "Minimal Program.cs without DI - just FallbackMenu instantiation"
  - "Theatrical intro with Wake up Neo typewriter effect"
  - "--quiet flag to skip intro for scripting/automation"
  - "matrixlite.exe at 1.7MB (vs 21MB bluepill) due to minimal dependencies"

patterns-established:
  - "Standalone CLI pattern: thin wrapper launching directly into library"
  - "Typewriter animation for theatrical console output"

# Metrics
duration: 8min
completed: 2026-01-30
---

# Phase 10 Plan 04: MatrixLite Standalone CLI Summary

**Standalone matrixlite.exe CLI that launches directly into text-based Matrix rain effect**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-30T13:10:56Z
- **Completed:** 2026-01-30T13:18:33Z
- **Tasks:** 4 (2 code creation, 1 solution update, 1 verification)
- **Files created:** 2
- **Files modified:** 1

## Accomplishments
- Created MatrixShader.Cli.MatrixLite project with Native AOT configuration
- Implemented Program.cs with theatrical intro and FallbackMenu launch
- Added project to solution and verified build
- Verified Native AOT publish produces matrixlite.exe (1.7MB)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create csproj** - `c07b596` (feat)
2. **Task 2: Create Program.cs** - `fef0a9a` (feat)
3. **Task 3: Add to solution** - `416bdbf` (chore)
4. **Task 4: Verify publish** - Verification only (no commit)

## Files Created/Modified

### Created
- `MatrixShader/src/MatrixShader.Cli/MatrixLite/MatrixShader.Cli.MatrixLite.csproj` - Native AOT project config
- `MatrixShader/src/MatrixShader.Cli/MatrixLite/Program.cs` - Entry point with intro animation

### Modified
- `MatrixShader/MatrixShader.sln` - Added MatrixLite project reference

## Decisions Made
- **No DI needed:** MatrixLite is simple enough to instantiate FallbackMenu directly without dependency injection
- **Theatrical intro:** Typewriter effect for "Wake up, Neo..." quotes creates immersive experience
- **--quiet flag:** Skip intro for automation/scripting use cases
- **Minimal executable:** 1.7MB vs 21MB for bluepill due to no DI/services overhead

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- **vswhere.exe not in PATH:** Native AOT publish required adding VS Installer path to PATH environment variable
- **WPF DLLs in publish:** net8.0-windows TFM causes D3DCompiler, PenImc, etc. to be included alongside matrixlite.exe (expected behavior per Phase 9 decisions)

## Build Output

```
MatrixShader/src/MatrixShader.Cli/MatrixLite/bin/Release/net8.0-windows/win-x64/publish/
  matrixlite.exe (1.7MB)
  matrixlite.pdb
  D3DCompiler_47_cor3.dll
  PenImc_cor3.dll
  PresentationNative_cor3.dll
  vcruntime140_cor3.dll
  wpfgfx_cor3.dll
```

## User Setup Required

None - matrixlite.exe works in any terminal with ANSI and Unicode support.

## Usage

```bash
# Run with theatrical intro
matrixlite

# Run with --quiet to skip intro
matrixlite --quiet

# Show help
matrixlite --help
```

## Next Phase Readiness
- MatrixLite CLI complete and ready for distribution
- All Phase 10 plans (01-04) now complete
- Ready for installer integration (include matrixlite.exe alongside other CLIs)

---
*Phase: 10-matrixlite-fallback*
*Completed: 2026-01-30*
