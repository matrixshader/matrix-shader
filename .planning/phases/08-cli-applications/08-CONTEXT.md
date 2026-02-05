# Phase 8: CLI Applications - Context

**Gathered:** 2026-01-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Three standalone CLI executables: bluepill (session restore), wakeupneo (setup wizard), and redpill (control panel). Entry point consolidation with shared bootstrap. Match PowerShell behavior with Matrix-style presentation.

</domain>

<decisions>
## Implementation Decisions

### bluepill behavior
- Restores full state: window positions, shader configs, AND layout mode (Pillars/Quads)
- If no previous session: launches single window with first (green) profile
- Launches missing windows automatically (doesn't just configure existing)
- After restore: types "There is no spoon..." in Matrix green (#00FF00)
- Typewriter effect: cinematic 150ms per character
- Waits for any key after message finishes, then exits
- No --silent flag - theatrics are the point

### wakeupneo wizard flow
- Match PowerShell behavior exactly
- Blue Pill path: ask window count, let user customize colors, launch windows, position them
- Red Pill path: same as Blue Pill PLUS opens control panel (redpill)
- Interactive arrow-key menu for Blue/Red Pill choice
- Matrix-style throughout: typewriter text, green colors, dramatic pauses

### CLI invocation style
- Brief Matrix-esque --help on all CLIs:
  - wakeupneo: "Walking the path"
  - redpill: "Wake up and fully Control the Matrix Shader"
  - bluepill: "Straight into the Matrix Shader, Coppertop!"
- Exit codes: standard (0 success, 1 error) - Claude's discretion
- --debug flag support: Claude's discretion

### Shared bootstrap
- Check if Windows Terminal installed before running
- If missing: auto-install via `winget install Microsoft.WindowsTerminal`
- If winget fails: offer Microsoft Store fallback ("Install via Microsoft Store instead? [Y/N]")
- First-run setup handled inline (match bluepill.ps1 behavior)
- Auto-create directories, default green shader, profile on first run

### Style
- Matrix green: Classic #00FF00 for all CLI text
- Banners: match PowerShell version exactly (simple text headers)
- Unified style across all CLIs: same prompt format, colors, separators
- Separators: dashes (---) instead of equals signs

### Easter eggs
- Random Matrix quote on each CLI launch
- Hidden flag --morpheus: philosophical explanations before each action ("Let me tell you why you're here...")
- Hidden flag --agent-smith: chaos mode - random colors/speeds on all windows

### Claude's Discretion
- Shared bootstrap architecture (common init vs minimal sharing)
- --debug flag placement (all CLIs vs just redpill vs environment variable only)
- Exact exit codes beyond 0/1
- Which Matrix quotes to include
- Exact --morpheus phrasing and timing
- What "chaos mode" specifically does for --agent-smith

</decisions>

<specifics>
## Specific Ideas

- "There is no spoon..." typewriter effect: cinematic pace, Matrix green, wait for keypress
- Morpheus mode should feel like he's explaining the Matrix to Neo
- Agent Smith mode should feel chaotic and overwhelming

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 08-cli-applications*
*Context gathered: 2026-01-28*
