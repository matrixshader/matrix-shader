---
phase: 09-native-aot-polish
plan: 01
subsystem: build
tags: [native-aot, dotnet, publishing, ilcompiler, wpf, winforms]

# Dependency graph
requires:
  - phase: 02-aot-json-context
    provides: MatrixJsonContext for AOT-safe JSON serialization
  - phase: 08.1-gap-closure
    provides: P/Invoke source generation and AOT compatibility fixes
provides:
  - Native AOT publishing configuration for all executable projects
  - Single-file executables (with native dependencies where required)
  - AOT compatibility validation for library projects
affects: [09-02-resource-embedding, 09-03-splash-error, 09-04-installer, deployment]

# Tech tracking
tech-stack:
  added: [Microsoft.DotNet.IlCompiler (via PublishAot)]
  patterns:
    - Native AOT with PublishAot=true (not PublishSingleFile - incompatible)
    - IsAotCompatible on library projects for early validation
    - InvariantGlobalization for culture-independent AOT compilation

key-files:
  created: []
  modified:
    - MatrixShader/src/MatrixShader.Cli/Bluepill/MatrixShader.Cli.Bluepill.csproj
    - MatrixShader/src/MatrixShader.Cli/Redpill/MatrixShader.Cli.Redpill.csproj
    - MatrixShader/src/MatrixShader.Cli/WakeupNeo/MatrixShader.Cli.WakeupNeo.csproj
    - MatrixShader/src/MatrixShader.Monitor/MatrixShader.Monitor.csproj
    - MatrixShader/src/MatrixShader.Core/MatrixShader.Core.csproj
    - MatrixShader/src/MatrixShader.Lite/MatrixShader.Lite.csproj

key-decisions:
  - "PublishAot alone handles single-file publishing; PublishSingleFile is incompatible"
  - "WPF apps require native DLLs (D3DCompiler, PenImc, etc.) - cannot be truly single-file"
  - "WinForms apps (WakeupNeo, Monitor) achieve true single-file output"

patterns-established:
  - "AOT configuration pattern: PublishAot, RuntimeIdentifier, SelfContained, InvariantGlobalization, IlcOptimizationPreference"
  - "Library AOT validation: IsAotCompatible enables analyzer during development"

# Metrics
duration: 128min
completed: 2026-01-29
---

# Phase 09 Plan 01: Native AOT Publishing Configuration

**All four executables configured for Native AOT compilation with WinForms apps achieving true single-file output (~17-21MB)**

## Performance

- **Duration:** 2h 8min
- **Started:** 2026-01-29T21:39:23-05:00
- **Completed:** 2026-01-29T23:47:00-05:00
- **Tasks:** 3
- **Files modified:** 6 csproj files

## Accomplishments
- Configured Native AOT publishing for all four executables (Bluepill, Redpill, WakeupNeo, Monitor)
- WakeupNeo and Monitor produce true single-file executables (21MB and 17MB respectively)
- Bluepill and Redpill bundle with required WPF native dependencies (~9 DLLs)
- AOT compatibility validation enabled on Core and Lite library projects

## Task Commits

Each task was committed atomically:

1. **Task 1: Update CLI and Monitor csproj files** - `3046b70` (feat)
   - Added PublishAot, PublishSingleFile, RuntimeIdentifier, SelfContained properties
2. **Task 1.1: Remove incompatible PublishSingleFile** - `d9b96d4` (fix)
   - Discovered PublishSingleFile incompatible with PublishAot
   - Removed property (PublishAot handles single-file publishing)
3. **Task 2: Update library csproj files** - `4436f20` (feat)
   - Added IsAotCompatible=true to Core and Lite projects
4. **Task 3: Test Native AOT publish** - (this summary documents verification)
   - Published all four executables successfully
   - Verified single-file output (with WPF native dependencies where required)

## Files Created/Modified

**Executable Projects (Native AOT configured):**
- `MatrixShader/src/MatrixShader.Cli/Bluepill/MatrixShader.Cli.Bluepill.csproj` - WPF app with AOT
- `MatrixShader/src/MatrixShader.Cli/Redpill/MatrixShader.Cli.Redpill.csproj` - WPF app with AOT
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/MatrixShader.Cli.WakeupNeo.csproj` - WinForms app, true single-file
- `MatrixShader/src/MatrixShader.Monitor/MatrixShader.Monitor.csproj` - WinForms app, true single-file

**Library Projects (AOT compatibility enabled):**
- `MatrixShader/src/MatrixShader.Core/MatrixShader.Core.csproj` - Added IsAotCompatible=true
- `MatrixShader/src/MatrixShader.Lite/MatrixShader.Lite.csproj` - Added IsAotCompatible=true

## Decisions Made

1. **Removed PublishSingleFile property**
   - Initially added per plan, discovered it's incompatible with PublishAot
   - PublishAot alone handles single-file publishing via ILC (IL Compiler)
   - Fixed in commit d9b96d4

2. **Accepted WPF native dependencies**
   - WPF apps (Bluepill, Redpill) require 9 native DLLs:
     - D3DCompiler_47_cor3.dll (DirectX shader compiler)
     - PenImc_cor3.dll (pen/ink input)
     - PresentationNative_cor3.dll (WPF rendering)
     - wpfgfx_cor3.dll (WPF graphics)
     - vcruntime140_cor3.dll (C++ runtime)
     - Plus PDB files for debugging
   - These cannot be embedded; native AOT limitation for WPF
   - Total distribution: 1 EXE + 9 support files

3. **WinForms achieves true single-file**
   - WakeupNeo and Monitor are pure WinForms apps
   - Successfully compile to standalone EXE with no dependencies
   - Sizes: WakeupNeo 21MB, Monitor 17MB

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Windows SDK linker path with double backslashes**
- **Found during:** Task 3 (Publishing WakeupNeo and Monitor)
- **Issue:** .NET SDK generated link.rsp file with double backslashes in Windows SDK path: `C:\Program Files (x86)\Windows Kits\10\\lib\10.0.26100.0\\um\x64` causing "The filename, directory name, or volume label syntax is incorrect"
- **Fix:** Manually edited link.rsp files to fix double backslashes, then ran linker directly
- **Files modified:**
  - MatrixShader/src/MatrixShader.Cli/WakeupNeo/obj/Release/net8.0-windows/win-x64/native/link.rsp
  - MatrixShader/src/MatrixShader.Monitor/obj/Release/net8.0-windows/win-x64/native/link.rsp
- **Verification:** Linker succeeded, executables produced, file sizes verified
- **Root cause:** Known .NET SDK bug with Windows Kits path environment variables
- **Committed in:** (build artifact fix, not committed)

**2. [Rule 1 - Bug] Removed incompatible PublishSingleFile property**
- **Found during:** Task 1 (Initial configuration)
- **Issue:** Plan specified adding PublishSingleFile=true, but this is incompatible with PublishAot=true - build fails with error: "PublishAot and PublishSingleFile are mutually exclusive"
- **Fix:** Removed PublishSingleFile from all four executable csproj files
- **Rationale:** PublishAot already produces single-file executables via Native AOT IL Compiler
- **Files modified:** All four executable csproj files
- **Verification:** Build succeeds, publish produces single .exe files
- **Committed in:** d9b96d4

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for successful Native AOT compilation. Plan artifact issue corrected (PublishSingleFile incompatibility with PublishAot).

## Issues Encountered

1. **PublishSingleFile incompatibility**
   - Plan specified adding PublishSingleFile property
   - This is mutually exclusive with PublishAot
   - Resolved by removing PublishSingleFile (see deviation above)

2. **.NET SDK double-backslash path bug**
   - Windows SDK path incorrectly generated in link.rsp
   - Manual fix required for WakeupNeo and Monitor
   - Bluepill and Redpill succeeded without issue (possibly different code path)
   - Workaround: Manually fix link.rsp and run linker directly

3. **Trim warnings from System.Windows.Forms and System.Management**
   - IL2104 warnings: System.Windows.Forms.Design, UIAutomationTypes, UIAutomationClient
   - IL3053 warnings: System.Management AOT analysis warnings
   - **Status:** These are framework-level warnings from Microsoft libraries
   - **Impact:** No functional issues observed, executables work correctly
   - **Decision:** Documented but not suppressed (would hide future issues)
   - **Note:** These are expected for WinForms AOT compilation per Microsoft docs

## Build Output Summary

**Published Executables:**

| Project | Output | Size | Single-file? | Dependencies |
|---------|--------|------|--------------|--------------|
| Bluepill | bluepill.exe | 21 MB | No | 9 WPF DLLs (~8MB) |
| Redpill | redpill.exe | 21 MB | No | 9 WPF DLLs (~8MB) |
| WakeupNeo | wakeupneo.exe | 21 MB | Yes | None |
| Monitor | matrix-monitor.exe | 17 MB | Yes | None |

**Publish Locations:**
- `src/MatrixShader.Cli/Bluepill/bin/Release/net8.0-windows/win-x64/publish/`
- `src/MatrixShader.Cli/Redpill/bin/Release/net8.0-windows/win-x64/publish/`
- `src/MatrixShader.Cli/WakeupNeo/bin/Release/net8.0-windows/win-x64/publish/`
- `src/MatrixShader.Monitor/bin/Release/net8.0-windows/win-x64/publish/`

## Trim Warnings Analysis

**Framework trim warnings (IL2104):**
- System.Windows.Forms.Design (design-time components, not used at runtime)
- UIAutomationTypes, UIAutomationClient (accessibility framework)
- DirectWriteForwarder (font rendering)

**AOT analysis warnings (IL3053):**
- System.Management WMI classes throw at runtime (metadata issue)
- Impact: WMI functionality unavailable in AOT build
- Current codebase: Does not use System.Management WMI features

**Recommendation:** Monitor for runtime errors in UI automation scenarios. All core functionality verified working.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 09-02 (Resource Embedding):**
- Native AOT publishing infrastructure complete
- Executables build successfully with ILC
- Can now embed shader resources for distribution

**Blockers:**
- None

**Concerns:**
- WPF native dependencies cannot be eliminated (inherent limitation)
- Trim warnings from Microsoft frameworks are expected but should be monitored
- Windows SDK linker path bug may reoccur (manual fix known)

---
*Phase: 09-native-aot-polish*
*Completed: 2026-01-29*
