# Phase 1: Global Transparency - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Ctrl+Shift+J/K adjust opacity on ALL Matrix windows simultaneously (not just the focused window), with per-window overflow/underflow counters that preserve the Redpill-set per-window mix. Add a brief OSD toast showing the opacity % on each adjustment.

</domain>

<decisions>
## Implementation Decisions

### Toggle interaction
- Toggle cycle stays Off -> Custom -> Full (existing order, no change)
- Overflow/underflow counters are PRESERVED across toggle cycles — toggling to Off or Full does not reset counters
- Toggling back to Custom restores the full mix+offset (not just the base Redpill mix)
- Counters track push-past-ceiling (overflow) and push-past-floor (underflow) per window independently

### Redpill sync
- When Redpill changes a single window's opacity (B/K/L keys), that window's overflow counter resets to 0
- The Redpill-set value becomes the new base for that window
- Other windows' counters are NOT affected — completely independent
- Redpill is the per-window authority; hotkeys are the global authority

### Visual feedback
- Brief OSD toast showing just the opacity percentage (e.g., "85%") on each Ctrl+Shift+J/K press
- Toast is ON by default (acts as subtle freemium nudge — visible to all users)
- Toggleable OFF in Redpill settings menu
- Minimal aesthetic — just the number, no progress bar

### Claude's Discretion
- OSD toast duration and fade behavior
- Toast positioning on screen
- Exact implementation of the OSD rendering (console overlay vs native window)
- How overflow counters are stored in memory (Dictionary per profile name, same pattern as existing _customOpacity)

</decisions>

<specifics>
## Specific Ideas

- "Like a mixing board — pushing all faders up/down relatively, each channel caps independently"
- Overflow counter design: when a window hits 100%, each additional +5 push increments its overflow counter instead of changing the displayed value. On pullback, each -5 drains one overflow before the displayed value drops. This perfectly restores the original mix.
- Same logic inverted for underflow at 0%
- When ALL windows hit ceiling/floor, further pushes in that direction are capped — only the opposite direction allowed

</specifics>

<deferred>
## Deferred Ideas

- Saved transparency presets (named mix configurations that can be toggled through) — future phase
- OSD toast for OTHER hotkey actions beyond opacity — future consideration

</deferred>

---

*Phase: 01-global-transparency*
*Context gathered: 2026-03-06*
