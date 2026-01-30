# Phase 10: MatrixLite Fallback - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Text-based Matrix rain renderer for non-Windows-Terminal environments. Provides graceful degradation when GPU shaders are unavailable. Renders ANSI-based rain effect in any console that supports 24-bit color.

</domain>

<decisions>
## Implementation Decisions

### Character Rendering
- Katakana + digits character set (movie-accurate mix)
- Column density matches HLSL shader's density parameter
- Three speed tiers matching FAR/MID/NEAR parallax layers for depth illusion
- Leading character (drop head) rendered bright white/green for glow effect

### Color System
- 24-bit RGB ANSI escape codes (\e[38;2;R;G;Bm)
- All 6 color presets supported: Classic Green, Amber, Cyan, Purple, Red, White
- Trail fade length controlled by shader's trail parameter
- Glow parameter has no ANSI equivalent - skip this parameter

### Detection & Switching
- Automatic detection + manual flag override (both supported)
- Fallback triggers when NOT running in Windows Terminal
- Separate executable: matrixlite.exe (standalone tool)
- Other CLIs (bluepill, wakeupneo) auto-launch matrixlite.exe when not in WT

### Performance & Input
- Frame rate scales with shader speed parameter
- Immediate adaptation on terminal resize (recalculate columns)
- Keep running at full speed when minimized (consistent with GPU shader)
- Full keyboard control matching redpill hotkeys (R/G/B, 1-6 presets, Q quit)

### Claude's Discretion
- Buffer/rendering strategy for smooth animation
- Exact character randomization algorithm
- Terminal capability detection method
- ANSI escape sequence optimization

</decisions>

<specifics>
## Specific Ideas

- Movie-accurate appearance: bright head character with fading trail
- Parameter parity where possible - density, speed, trail, color presets all work
- Graceful auto-launch from existing CLIs when WT not detected

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 10-matrixlite-fallback*
*Context gathered: 2026-01-30*
