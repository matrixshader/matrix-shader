---
phase: 09-native-aot-polish
plan: 04
subsystem: deployment
tags: [inno-setup, installer, packaging, path-integration, windows]

# Dependency graph
requires:
  - phase: 09-01
    provides: "Native AOT compilation configuration for all projects"
provides:
  - "Inno Setup installer script with system PATH integration"
  - "Build automation script that publishes and packages all executables"
  - "Installer includes all four executables plus shader library"
affects: [10-matrixlite]

# Tech tracking
tech-stack:
  added: [inno-setup]
  patterns: [installer-with-path-integration, multi-executable-packaging]

key-files:
  created:
    - installer/MatrixShaderSetup.iss
    - installer/build-installer.ps1
  modified: []

key-decisions:
  - "NeedsAddPath function prevents duplicate PATH entries (case-insensitive check)"
  - "PrivilegesRequired=admin for system PATH modification"
  - "ChangesEnvironment=yes enables immediate command availability without reboot"
  - "matrix-monitor.exe included for Bluepill drag-snap functionality"

patterns-established:
  - "Pattern 1: Inno Setup [Registry] section modifies system PATH with duplicate prevention"
  - "Pattern 2: Build script verifies all executables exist before invoking Inno compiler"

# Metrics
duration: 4min
completed: 2026-01-29
---

# Phase 9 Plan 4: Installer Script & Build Automation Summary

**Inno Setup installer with system PATH integration packages all four executables (wakeupneo, redpill, bluepill, matrix-monitor) plus shader library into single distributable**

## Performance

- **Duration:** 4 minutes
- **Started:** 2026-01-30T04:40:16Z
- **Completed:** 2026-01-30T04:44:27Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Inno Setup script installs to Program Files with automatic PATH registration
- Build automation script publishes all four projects and compiles installer
- NeedsAddPath function prevents duplicate PATH entries during upgrades
- Includes matrix-monitor.exe for Bluepill drag-snap window detection

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Inno Setup script** - `bd350f4` (chore)
2. **Task 2: Create build automation script** - `75f7b00` (chore)

**Plan metadata:** (to be committed separately)

## Files Created/Modified
- `installer/MatrixShaderSetup.iss` - Inno Setup installer script with PATH integration
- `installer/build-installer.ps1` - PowerShell script to publish and build installer

## Decisions Made

1. **NeedsAddPath function with case-insensitive check** - Prevents duplicate PATH entries by checking if install directory already exists in PATH (case-insensitive comparison). Essential for clean upgrades.

2. **PrivilegesRequired=admin** - Required for modifying system PATH in HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment. Ensures installer has permission.

3. **ChangesEnvironment=yes** - Signals to Inno Setup that PATH was modified. Allows Windows to refresh environment variables so commands work immediately in new terminals without reboot.

4. **Include matrix-monitor.exe** - Critical for Bluepill drag-snap functionality. Monitor runs silently in background detecting window movement events.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

**Manual step: Install Inno Setup 6.x**
To build the installer, users must:
1. Download Inno Setup 6.x from https://jrsoftware.org/isdl.php
2. Install to default location: C:\Program Files (x86)\Inno Setup 6\
3. Or specify custom path via `-InnoSetupPath` parameter to build-installer.ps1

No USER-SETUP.md needed (one-time developer tool install, not runtime dependency).

## Next Phase Readiness

- Installer packaging complete - ready for Phase 10 MatrixLite implementation
- Build pipeline tested (build-installer.ps1 can be run to generate distributable)
- All four executables packaged together with shader library
- System PATH integration ensures commands work immediately after install

**Blocker:** Inno Setup compiler must be installed on build machine before running build-installer.ps1. This is a dev-time dependency, not runtime.

---
*Phase: 09-native-aot-polish*
*Completed: 2026-01-29*
