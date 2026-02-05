# Phase 11: Installer & E2E Validation - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Build working installer, fix path mismatches, validate on clean system. Close all 14 gaps identified in GAP-ANALYSIS.md so v1.0 can actually ship.

</domain>

<decisions>
## Implementation Decisions

### Installer Approach
- Inno Setup (keep existing approach, actually build it this time)
- EXEs install to `C:\Program Files\MatrixShader\`
- Shaders + config install to `%LOCALAPPDATA%\MatrixShader\`
- Installer copies shaders to LocalAppData during install (not first-run)

### Path Resolution
- Fix all code to use `%LOCALAPPDATA%\MatrixShader\` instead of `Documents\Matrix\`
- One canonical location for user data (shaders, config, state, registry)
- Profile creation points to LocalAppData shader paths
- Remove hardcoded dev paths entirely

### Windows Terminal Installation (Install-time)
- Installer checks if WT exists
- If not → run `winget install` silently
- If winget fails → open Store page automatically (no prompt)
- If neither works → offer MatrixLite as fallback
- Never block silently — always give user a path forward

### Windows Terminal Detection (Runtime)
- Quick check only: does `settings.json` exist?
- Do NOT attempt to install at runtime (installer's job)
- If WT missing, show Red Pill / Blue Pill choice:
  - Red Pill → Open Store to install WT, wait, re-check
  - Blue Pill → Continue with MatrixLite
- Ask every time (don't remember choice) — user might have installed WT since last run

### Testing Methodology
- Manual testing by user in Windows Sandbox
- Create checklist for user to follow during testing
- User decides when ready to ship

### Claude's Discretion
- Exact winget command flags
- Store page opening mechanism
- Checklist format and detail level
- Error message wording

</decisions>

<specifics>
## Specific Ideas

- Red Pill / Blue Pill theming for the WT missing prompt — on brand
- Silent install unless it fails — don't interrupt user unnecessarily
- Always give user agency — never silently downgrade to MatrixLite

</specifics>

<deferred>
## Deferred Ideas

- Bundling Windows Terminal / creating custom terminal emulator — too large an undertaking, separate product
- MSIX/WinGet distribution — could be v2 alternative distribution method
- Automated E2E test scripts — manual testing for now

</deferred>

---

*Phase: 11-installer-e2e-validation*
*Context gathered: 2026-01-30*
