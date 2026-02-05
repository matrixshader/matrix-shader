---
phase: 12-e2e-gap-closure
plan: 04
subsystem: installer
tags: [winget, msixbundle, github-api, windows-terminal, installation]

# Dependency graph
requires:
  - phase: 12-01
    provides: WT detection fixes
provides:
  - IsWingetAvailable() detection before install
  - TryDownloadFromGitHubAsync() for direct GitHub download
  - 4-method installation fallback chain
  - Manual instructions as last resort
affects: [12-07-final-verification, installer, wakeupneo]

# Tech tracking
tech-stack:
  added: [System.Net.Http for GitHub API calls]
  patterns: [fallback chain pattern, progress-based download]

key-files:
  modified:
    - MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs

key-decisions:
  - "winget detection via --version with 5-second timeout"
  - "GitHub releases API parsing via regex (no JSON library dependency)"
  - "Add-AppxPackage via PowerShell for msixbundle installation"
  - "Progress indicator during download"

patterns-established:
  - "Fallback chain: Try automated, then interactive, then manual instructions"
  - "User-agent header for GitHub API requests"

# Metrics
duration: 8min
completed: 2026-02-01
---

# Phase 12 Plan 04: WT Installation Fallback Summary

**Robust WT installation with 4 fallback methods: winget detection, Store, GitHub direct download, and manual instructions**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-01T05:58:42Z
- **Completed:** 2026-02-01T06:06:42Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added IsWingetAvailable() to detect winget before attempting install (GAP-E03a)
- Created TryDownloadFromGitHubAsync() for direct .msixbundle download from GitHub releases (GAP-E03b)
- Added manual instructions as last resort fallback - no dead ends (GAP-E03c)
- User informed at each step with clear messaging

## Task Commits

Each task was committed atomically:

1. **Task 1: Detect winget availability before attempting install** - `ff34ef6` (feat)
2. **Task 2: Add GitHub direct download fallback** - `823f8af` (feat)

## Files Created/Modified
- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` - Enhanced WT installation with 4 fallback methods

## Installation Flow

The new TryInstallWindowsTerminalAsync() method follows this priority:

1. **Method 1: winget** (if IsWingetAvailable() returns true)
   - Runs `winget install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements`
   - Skipped entirely if winget not available (no silent failures)

2. **Method 2: Microsoft Store**
   - Opens ms-windows-store:// protocol with WT product ID
   - User prompted with Y/N before opening

3. **Method 3: GitHub direct download**
   - Fetches latest release from api.github.com
   - Parses JSON response for .msixbundle URL via regex
   - Downloads with progress indicator (percentage display)
   - Installs via Add-AppxPackage PowerShell command

4. **Method 4: Manual instructions**
   - Displays GitHub releases URL
   - Tells user which file to download (.msixbundle)
   - Allows continuation with Lite mode

## Decisions Made
- Used regex parsing instead of JSON library to avoid adding new dependencies
- 5-second timeout for winget --version check
- User-Agent header "MatrixShader-Installer" for GitHub API
- Progress indicator shows percentage during download
- 30-second timeout on HTTP client
- Temp file cleaned up after successful installation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - build succeeded on first attempt for both tasks.

## Bugs Fixed

| Bug ID | Description | Status |
|--------|-------------|--------|
| GAP-E03a | winget detection missing before install | FIXED |
| GAP-E03b | No GitHub download fallback | FIXED |
| GAP-E03c | Dead end when Store unavailable | FIXED |

## Next Phase Readiness
- WT installation now has no dead ends
- Ready for Windows Sandbox testing in 12-07
- GitHub download requires internet access (expected)

---
*Phase: 12-e2e-gap-closure*
*Completed: 2026-02-01*
