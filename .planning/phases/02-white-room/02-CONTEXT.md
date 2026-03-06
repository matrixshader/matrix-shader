# Phase 2: White Room - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

**Reference image:** `.planning/phases/02-white-room/CONSTRUCT-reference.png`

<domain>
## Phase Boundary

User launches `construct` with no args and sees a retro CRT TV in a white void with a 2x3 navigable color picker on screen. Arrow keys move between swatches, Enter selects a color, CRT powers off, window goes dark at 85% transparency, then the existing Matrix rain shader for that color starts.

</domain>

<decisions>
## Implementation Decisions

### CRT TV visual design
- Match the reference image (CONSTRUCT-reference.png) as closely as possible without copyright infringement
- Full detail: wood grain cabinet, brass knobs, speaker grilles, legs — all rendered in HLSL
- Animated static/snow on the TV screen behind the color swatches
- No scanlines
- 6 color swatches in 2x3 grid using exact shader preset RGB values: Green(0,1,0.3), Blue(0,0.6,1), Red(1,0.1,0.1), Purple(0.7,0,1), Gold(1,0.7,0), Teal(0,0.9,0.9)
- Selected swatch highlighted with glowing border
- Pure white void background (dark mode toggle is a future addition via Redpill setting)
- Vintage-style branding on cabinet bezel (original, not infringing)

### Color picker interaction
- Arrow keys navigate the 2x3 grid with full wrapping:
  - Left/right move between swatches in reading order, wrapping at row edges to next/prev row
  - Up/down toggle between the two rows, wrapping at top/bottom
- Enter = select. CRT power-off animation plays, then transition to rain
- No confirmation step — pick it and go

### Launch flow
- `construct` with no args spawns a NEW Windows Terminal window (must be WT for shader support)
- Window starts at 100% opacity (opaque) for pure white void
- TV zooms in from a tiny point (CRT power-ON effect — inverse of the power-off at the end)
- After color selection and CRT-off: window transitions to user's transparency setting (e.g. 85%)
- Then existing Matrix-{color}.hlsl rain shader starts

### Shader architecture
- **Two shader files, NOT one monolithic file**
- White room shader (new HLSL): handles TV rendering, picker, CRT power-on zoom, CRT power-off animation
- Rain shader (existing Matrix-N.hlsl): unchanged, already works
- C# drives state via `#define` writes to the white room shader (existing hot-reload pattern)
- `#define SELECTED N` (0-5) for arrow key navigation
- `#define STATE N` for state transitions (power-on, idle/picking, power-off)
- Shader handles animation timing via iTime within each state
- When CRT-off animation completes: C# swaps settings.json shader path from WhiteRoom.hlsl to Matrix-{color}.hlsl
- The dark screen between CRT-off and rain start hides any swap latency (~100ms)
- After swap, window behaves identically to `construct --color`

### Claude's Discretion
- Exact CRT power-on zoom timing and easing
- Glow border animation style (pulse, solid, etc.)
- Cabinet detail rendering approach in HLSL (procedural textures vs geometric approximation)
- State machine implementation details
- Timing of opacity transition from 100% to user's setting

</decisions>

<specifics>
## Specific Ideas

- Reference image provided: vintage console TV (Philco Predicta style) with wood cabinet, brass hardware, two speakers, legs, static screen, 6 saturated color squares
- CRT power-ON (zoom from point) is the inverse of CRT power-OFF (shrink to point) — visual symmetry bookending the experience
- The "seam" between white room and rain is hidden by the dark screen — user sees: TV → CRT off → dark → rain fades in

</specifics>

<bugs>
## Required Bug Fixes (pre-release)

These affect daily use and must be fixed before 3/11 release:

1. **Tab color not syncing on new windows** — When construct opens a new window (e.g. `construct --red`), the tab shows green instead of matching the shader color
2. **Duplicate profile naming** — New construct windows get profile names (e.g. "Matrix-2") that conflict with existing windows, causing incorrect labeling

</bugs>

<deferred>
## Deferred Ideas

- Dark mode white room (black void instead of white) — toggle in Redpill settings
- Terminal text color matching shader color (like Linux version does)
- Text color setting in Redpill + toggle to default white
- Wakeupneo self-launch into black window (like Linux version)
- SaaS/enterprise licensing tiers

</deferred>

---

*Phase: 02-white-room*
*Context gathered: 2026-03-06*
