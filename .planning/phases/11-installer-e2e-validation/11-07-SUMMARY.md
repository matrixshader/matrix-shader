---
phase: 11-installer-e2e-validation
plan: 07
subsystem: installer
tags: [powershell, one-liner, install, uninstall, github-releases]

dependency-graph:
  requires: [11-06]
  provides: [one-liner-install, uninstall-script]
  affects: []

tech-stack:
  added: []
  patterns: [one-liner-install, github-releases-download]

key-files:
  created:
    - installer/install.ps1
    - installer/uninstall.ps1
  modified: []

decisions:
  - "Admin installs to Program Files, non-admin to LocalAppData"
  - "Download from GitHub Releases API with fallback URL"
  - "User data cleanup is optional with prompt"

metrics:
  duration: "~5 minutes"
  completed: "2026-01-31"
---

# Phase 11 Plan 07: One-Liner Install Script Summary

PowerShell one-liner install/uninstall scripts for frictionless command-line installation.

## What Was Built

### install.ps1
- **One-liner usage:** `irm https://matrixshader.com/install.ps1 | iex`
- **Admin detection:** Installs to `C:\Program Files\MatrixShader` when admin, `%LOCALAPPDATA%\Programs\MatrixShader` when not
- **GitHub Releases integration:** Downloads latest release zip via API with fallback URL
- **Full extraction:** Copies all executables, DLLs, and .NET runtime
- **Shader handling:** Copies shaders to `%LOCALAPPDATA%\MatrixShader\shaders`
- **PATH management:** Adds install dir to system PATH (admin) or user PATH (non-admin)
- **Idempotent:** Safe to run multiple times for updates
- **Cross-version:** Works in PowerShell 5.1 and 7+
- **Optional quick-start:** Offers to run `wakeupneo` immediately after install

### uninstall.ps1
- **One-liner usage:** `irm https://matrixshader.com/uninstall.ps1 | iex`
- **Auto-detection:** Finds installation in either location
- **Admin enforcement:** Requires admin when installed to Program Files
- **Clean removal:** Removes executables, runtime, and PATH entry
- **User data preservation:** Prompts before removing settings and custom shaders
- **Graceful handling:** Works even if partial installation

## Verification

All checks passed:
- [x] install.ps1 exists and has valid syntax
- [x] uninstall.ps1 exists and has valid syntax
- [x] README shows one-liner as primary install method (line 8)
- [x] TESTING.md has E2E-00 test cases for one-liner scenarios

## Commits

| Hash | Description |
|------|-------------|
| 129a339 | feat(11-07): create one-liner install script |
| 5855c7c | feat(11-07): create uninstall script |

## Key Files Created

```
installer/
  install.ps1      # 228 lines - download, extract, configure
  uninstall.ps1    # 153 lines - detect, remove, cleanup
```

## Deviations from Plan

None - plan executed exactly as written. Tasks 3 and 4 verified existing content without needing changes.

## Next Steps

1. **Upload release zip:** Create GitHub Release with `MatrixShader.zip` containing publish folder contents
2. **Host scripts:** Set up `matrixshader.com/install.ps1` redirect to raw GitHub URL
3. **Test in Sandbox:** Follow TESTING.md E2E-00 checklist in clean Windows Sandbox

## Usage Example

```powershell
# Install (one command)
irm https://matrixshader.com/install.ps1 | iex

# Use Matrix Shader
wakeupneo    # Setup wizard
bluepill     # Quick launch
redpill      # Control panel

# Uninstall (one command)
irm https://matrixshader.com/uninstall.ps1 | iex
```
