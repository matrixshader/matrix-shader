# Phase 4: Window Identity Service - Context

**Gathered:** 2026-01-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Reliable identification of Matrix shader windows across sessions. The system must distinguish Matrix windows from other Windows Terminal instances, track identity through window lifecycle events, assign confidence scores, and persist window-to-shader mappings.

This phase implements the identity resolution logic. Layout management and TUI integration are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Identity Layer Priority
- **Exact match of PowerShell 4-layer hierarchy**
- Layer 1: Launch Tracking — Confidence 1.0 (0.95 if recovered from disk). Window handle or PID lookup.
- Layer 2: Command Line Parsing — Confidence 0.95. Parse `-p "Matrix-N"` from process command line.
- Layer 3: Title Matching — Confidence 0.70. Regex pattern on window title.
- Layer 4: UI Automation — Confidence 0.85-0.95. Slow fallback, check TermControl elements first, then tabs.
- Fallback order is strict: try each layer in sequence, stop at first match.

### Confidence Thresholds
- Match PowerShell scores exactly:
  - Launch Tracking: 1.0 (fresh) or 0.95 (recovered from disk)
  - Command Line: 0.95
  - UI Automation (TermControl): 0.95
  - UI Automation (Tab): 0.85
  - UI Automation (Name): 0.90
  - Title Match: 0.70
- Confidence is metadata only — no auto-accept vs prompt behavior based on threshold.

### Identity Loss Handling
- Remove identity entries immediately when process is gone (no grace period)
- Unidentified Windows Terminal windows are skipped silently (not included in results)
- Handle validation checks both `IsWindow()` AND `IsWindowVisible()` — both must pass

### Registry Persistence
- **Location:** `AppData\Local\MatrixShader\identity-registry.json` (deviation from PowerShell)
- **Format:** JSON with version, savedAt timestamp, entries dictionary
- **Entry lifetime:** 24 hours max — cleaned on app startup
- **Atomic writes:** Reuse temp file + Move pattern from ConfigService (Phase 2)
- **Cleanup trigger:** Run on app startup, not periodic background

### Claude's Discretion
- Process command line retrieval approach (WMI alternative for C#)
- UI Automation library choice (if needed)
- Exact JSON schema for identity-registry.json
- Internal caching strategy for command line lookups

</decisions>

<specifics>
## Specific Ideas

- "Do what the PowerShell version already does" — the 1,287-line `WindowIdentityService.ps1` is the reference implementation
- PowerShell uses `Get-CimInstance` for batch WMI queries — C# will need equivalent
- PowerShell tracks by both window handle AND process ID — C# should do the same
- Performance target from PowerShell: 120ms for 6 windows (vs 3000ms with UI Automation only)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-window-identity-service*
*Context gathered: 2026-01-26*
