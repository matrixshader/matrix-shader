# Phase 9: Native AOT & Polish - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Single-file Native AOT compilation with instant startup (<500ms target). Deliverables: installer package with all three executables, startup splash, and polished error handling. No runtime dependencies on target machine.

</domain>

<decisions>
## Implementation Decisions

### Distribution Format
- Three separate EXEs: `wakeupneo.exe`, `redpill.exe`, `bluepill.exe`
- Users type command names directly (no subcommands like `matrix redpill`)
- All components bundled in single installer — no loose files
- Install location: `AppData\Local\Programs\MatrixShader\`
- Installer adds to PATH so commands work from any terminal

### Startup Behavior
- Matrix number cascade splash on every startup (all three executables)
- Duration: 1-2 seconds minimum, or until app is actually ready (whichever is longer)
- Silent — no audio effects
- Green cascading numbers like the movie's opening sequence

### Error Experience
- Matrix-themed error messages ("SYSTEM FAILURE" style)
- Green on black color scheme even for errors
- Actionable info included but written in-theme (e.g., "Jack in at:" not "Install from:")
- Wait for keypress before closing so user can read error
- Late 90s telnet hacker group aesthetic throughout

### Claude's Discretion
- Exact Matrix number animation implementation
- Installer technology choice (WiX, Inno Setup, etc.)
- Native AOT trim settings and warnings handling
- Windows Sandbox test automation approach

</decisions>

<specifics>
## Specific Ideas

- "Late 90s telnet hacker group style program aesthetic" — the overall vibe reference
- Matrix number cascade splash inspired by the movie's opening green rain sequence
- Errors should feel like system failures in the Matrix universe, not generic Windows errors

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-native-aot-polish*
*Context gathered: 2026-01-29*
