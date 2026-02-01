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
Current state: Has typewriter ("Wake up, Neo...", "The Matrix has you...") then jumps straight to menu.

What's MISSING and needs to be added:
1. After typewriter intro, show choice quote: "Everything begins with choice." (from MatrixQuotes.cs line 23)
   - OR use Morpheus's full speech: "This is your last chance. After this, there is no turning back..."
2. Present Red Pill / Blue Pill choice
3. **Blue Pill**: "Straight to the Matrix" - Start text rain IMMEDIATELY in current window
4. **Red Pill**: "Control the Code" - Show FallbackMenu (full control menu)

Files to modify:
- `MatrixShader/src/MatrixShader.Cli/MatrixLite/Program.cs` - Add choice after ShowIntro()
- `MatrixShader/src/MatrixShader.Lite/FallbackMenu.cs` - May need method to start rain directly

IMPORTANT: This is NOT the shader control menu (deleted matrix_tool.ps1 had Knock/Blue/Red for SHADERS, not text rain)

### Uninstall Behavior
- **User data**: Delete EVERYTHING in %LOCALAPPDATA%\MatrixShader - user starts fresh on reinstall
- **WT profiles**: Remove Matrix-1 through Matrix-6 profiles from settings.json, restore to pre-install state
- **Program Files**: Full cleanup (fix BUG-UNINST02 leaving 54+ DLLs)
- **Error messages**: Actionable - tell user WHAT files, WHERE they are, WHY removal failed, HOW to fix (fix BUG-UNINST01)

### WT Installation Flow
Apple-level engineering - automate EVERYTHING, user never does manual work unless they explicitly choose to:
1. Try winget install (automatic)
2. Try Microsoft Store (automatic)
3. Try direct .msixbundle download from GitHub releases (automatic)
4. Try running downloaded installer silently (automatic)
5. ONLY if all automatic attempts fail: show what happened and offer manual option

No dead ends - always have a path forward. Detect missing winget BEFORE attempting (GAP-E03a).

### First-Run Detection (BUG-FRX01)
- Bug: Shows "Previous sessions found 8 window slots" on FRESH install - impossible and wrong
- Fix: Actually check if session files exist before claiming previous sessions
- First run should do normal "Wake up, Neo..." intro, not claim false history
- Figure out WHY it thinks there are 8 slots and fix the root cause

### Installer Re-Run (GAP-INST01)
Smart detection when already installed:
- Detect existing installation
- Offer menu: Update / Repair / Uninstall / Cancel
- Don't blindly overwrite (current broken behavior)

### Verification (REQUIRED)

**Local verification (after each bug fix):**
- Test the specific fix locally before moving to next bug
- Don't batch fixes without testing - verify as you go

**Skipped Phase 10 tests (MUST DO NOW):**
These were marked "passed" but NEVER actually performed:
1. Visual Appearance Test - MatrixLite looks correct
2. Graceful Degradation Test - Falls back properly when WT unavailable
3. Terminal Resize Handling Test - Handles window resize
4. Non-Windows-Terminal Compatibility Test - Works in cmd.exe
5. Standalone MatrixLite Operation Test - Full standalone functionality

**Final E2E verification:**
1. Rebuild the installer with ALL fixed code
2. Set up fresh Windows Sandbox environment
3. Re-run ENTIRE E2E test checklist from TESTING.md
4. All 18 bugs must be verified FIXED
5. All 5 skipped Phase 10 tests must PASS
6. No new bugs introduced
7. Only THEN is Phase 12 complete

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
