# Phase 7: Terminal Integration - Context

**Gathered:** 2026-01-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Application manages Windows Terminal configuration — reading/writing settings.json, creating Matrix profiles, setting shader paths, and diagnostic logging. This phase makes the control panel (Phase 6) able to actually launch and configure Windows Terminal windows.

</domain>

<decisions>
## Implementation Decisions

### Profile Creation Strategy
- **Overwrite profiles completely** — Match PowerShell behavior, no merge logic
- **BUT store opacity in our state** — Window transparency is a WT profile setting, so we track it per-slot and apply via Windows API (not stored in settings.json)
- **Profile count** — User chooses 1-8 during setup wizard, matching PowerShell
- **Truly elegant error handling:**
  - If settings.json missing: Create fresh with Matrix profiles + sensible WT defaults
  - If settings.json malformed: Backup broken file, use lenient parsing to extract all profiles, fix JSON errors, rebuild valid file with ALL recovered profiles + our Matrix profiles
  - If specific profile caused issue: Repair that profile too
  - User never does manual recovery — we do the grunt work silently

### Settings Backup Behavior
- **Single backup only** — `settings.json.matrix-backup`, overwrite previous
- **Backup location** — Claude's discretion
- **No manual restore command** — Trust the repair code, no "break glass" option
- **Repair notification** — Silent unless user runs with `--verbose`

### Shader Path Handling
- **Path strategy** — Claude's discretion (research PowerShell approach, determine optimal)
- **Missing shader files** — Recreate from defaults automatically (self-healing)
- **Validation timing** — Match PowerShell; if PowerShell doesn't validate on launch, Claude decides
- **Portability** — If user moves Matrix folder, auto-detect on launch and update paths in settings.json

### Diagnostic Logging
- **Log content** — Match PowerShell exactly (whatever MATRIX_DEBUG=1 captures)
- **Log location** — Claude's discretion
- **Log rotation** — Match PowerShell behavior
- **Activation methods** — Both `MATRIX_DEBUG=1` env var AND `--debug` command line flag

### Claude's Discretion
- Shader path strategy (absolute vs relative, exact location)
- Backup file location
- Log file location
- Validation timing if PowerShell doesn't do it

</decisions>

<specifics>
## Specific Ideas

- "Truly elegant" = user never does manual work. If something is broken, we fix it for them automatically and silently.
- Opacity is a special case: it's a WT profile setting, but we want bluepill to restore it. Solution: store in our state, apply via Windows API.
- The profile in settings.json is just a "launcher" — all the live customization state (colors, effects, opacity) lives in our system.

</specifics>

<deferred>
## Deferred Ideas

- **Support for other shader-capable terminals** — User mentioned terminals beyond Windows Terminal that support shaders. Different APIs, config formats, shader systems. Worth exploring in a future phase after core WT support is solid.

</deferred>

---

*Phase: 07-terminal-integration*
*Context gathered: 2026-01-28*
