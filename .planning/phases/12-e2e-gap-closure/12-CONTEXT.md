# Phase 12: E2E Gap Closure - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix all 18 bugs discovered during Windows Sandbox E2E testing. Every bug must be fixed - no broken shipping. Apple engineering standards.

Source: `installer/TESTING.md` test session 2026-01-31

</domain>

<decisions>
## Implementation Decisions

### Bug Priority
- All 18 bugs are must-fix (Critical, High, AND Medium)
- No shipping with known broken functionality
- Apple engineering standards apply

### Windows Terminal Detection
- Exhaustive detection: Store, Scoop, Chocolatey, Portable, PATH, parent process
- Check multiple paths, not just one hardcoded Store location
- Dynamic wt.exe discovery for portable installs
- Correct settings.json path for each install type

### MatrixLite Quality Bar
- Full standalone experience, not just emergency fallback
- Background mode: rain behind commands (live wallpaper style)
- Menu first on launch: show options before starting rain
- Classic Matrix green (#00FF00) as default
- Terminal remains usable while effect runs

### MatrixLite Intro Flow (LOST FEATURE - RESTORE)
- Red Pill / Blue Pill choice at startup (matching matrix_setup.ps1 spirit)
- Original PowerShell version had this but was lost during C# port
- FallbackMenu.cs created Jan 25 based on lost reference
- Restore the 3-option menu: Knock/Blue/Red or similar

### Uninstall Behavior
- Full cleanup of Program Files (fix BUG-UNINST02 leaving 54+ DLLs)
- Actionable error messages (fix BUG-UNINST01)
- Clear indication of what files remain and why

### WT Installation Flow
- Detect missing winget before attempting install (GAP-E03a)
- Provide GitHub direct download fallback (GAP-E03b)
- No dead ends - always offer a path forward (GAP-E03c)

### Claude's Discretion
- Exact implementation order within severity tiers
- Technical approach to VT Processing fix
- Specific wording of error messages

</decisions>

<specifics>
## Specific Ideas

- VT Processing fix requires P/Invoke for SetConsoleMode with ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004)
- Shader regex bug shows `$10.0` instead of `#define RAIN_R 0.0` - likely regex backreference issue
- First-run detection needs to check for actual first run, not just empty session

</specifics>

<deferred>
## Deferred Ideas

- Mac/Linux MatrixLite support — v2.0 (cross-platform)
- Support for non-WT shader-capable terminals — v2.0
- Automated E2E testing in CI — future enhancement

</deferred>

---

*Phase: 12-e2e-gap-closure*
*Context gathered: 2026-01-31*
