# Phase 14: Final Polish & Hotkey Stability - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 12 bugs from one-liner E2E testing: hotkey service crashes, acrylic blur, transparency persistence, shader cycling issues, and layout gaps. Background services (matrix-monitor, matrix-hotkeys) must stay alive and functional without redpill open.

</domain>

<decisions>
## Implementation Decisions

### Hotkey Service Stability
- Auto-restart silently when hotkey service crashes — matrix-monitor detects death and relaunches without user notification
- Stay alive 30 seconds after last Matrix window closes — gives time to reopen windows without restarting service
- Glitch/snap functionality lives in matrix-monitor.exe (background) — redpill only configures it
- Ctrl+Shift+Left/Right rotates focused window through ALL positions (1→2→3→4→1), not just neighbor swap
- Fullscreen windows are excluded from rotation — only tiled windows participate

### Transparency Appearance
- Plain transparency only (no acrylic blur) — standard PowerShell-style see-through, desktop shows clearly
- Default opacity: 85%
- Opacity range: 0-100% in 5% steps (already decided in earlier phase)
- Redpill menu stays fully opaque — only shader windows get transparency
- On uninstall: restore original WT settings from backup (save settings.json before first modification)

### Shader Cycling
- REMOVE shader cycling feature (Ctrl+Shift+S) entirely — shaders only differ by color, feature causes problems
- No reverse cycling needed since cycling is being removed
- Color presets can be revisited as a future feature

### Layout Reliability
- Gap size scales with window count but minimum 20px — larger gaps for fewer windows, never below 20px
- F11 = true fullscreen — glitch/snap must ignore fullscreen windows entirely (no snap back)
- Glitch/snap must work regardless of how layout changed (redpill menu or hotkeys) — just fix the bug, not a design change
- Glitch behavior: when windows overlap, snap them back to their assigned positions for current layout

### Claude's Discretion
- Exact auto-restart detection mechanism for hotkey service
- Gap scaling formula (how much to reduce per window)
- Backup file location for WT settings restoration

</decisions>

<specifics>
## Specific Ideas

- "Normal transparency like PowerShell has it" — no frosted glass, no haze, just plain see-through
- Window rotation should work across ALL positions, not ping-pong between two spots
- When fullscreen, glitch should leave that window alone and not reposition it

</specifics>

<deferred>
## Deferred Ideas

- Color presets / named color schemes (future enhancement after cycling removed)
- Reverse color cycling (if cycling feature revisited later)

</deferred>

---

*Phase: 14-final-polish-hotkey-stability*
*Context gathered: 2026-02-03*
