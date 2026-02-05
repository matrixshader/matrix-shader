# Phase 13: Post-E2E Polish - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 17 bugs discovered during post-microsprint Windows Sandbox testing. Bug fixes ONLY - no new features. Categories: WT Detection, MatrixLite, Shaders, Layout, Transparency, Redpill, Installer UX.

</domain>

<decisions>
## Implementation Decisions

### MatrixLite
- **Mode:** Cool demo, NOT usable terminal
- Effect runs fullscreen, ESC returns to menu, clean exit to normal terminal
- Don't try to make it a "background" - console limitations make true layering impossible
- **Splash screen in cmd.exe:** Only known issue - fix if needed, but low priority since WT installation works well ("Apple engineering achieved")
- Menu is fine - the menu issues reported were about Redpill, not MatrixLite

### Layout
- **4 Pillars:** Must be 4 side-by-side vertical narrow strips/columns
- **Gaps:** Respect gaps between windows - don't overlap in Pillars mode
- **Minimized windows:** Stay minimized - respect user's intentional choice
- **Overlap mode:** Already exists and works well (user chef's-kissed it)
- **Borderless:** Nice-to-have if easy to implement, skip if complex

### Transparency
- **Scope:** Matrix windows ONLY get transparency
- **Exception:** wakeupneo/bluepill menus turn their windows 100% transparent when they finish launching
- **Default opacity:** 85% for new Matrix windows
- **IMPORTANT:** Use 0-100 scale, NOT 0-1 (causes errors if wrong)
- **Menu windows:** Keep open but invisible (100% transparent) after launching

### Installer UX
- **Full Matrix theme:**
  - Black/dark background
  - Green text throughout
  - Blue Pill = Cancel, Red Pill = Install (button naming)
  - Matrix-style welcome message on first screen
- **Languages:** Keep multi-language support
- **Version BUG:** Installer shows 2.0.0 but should be 1.0.0

### Claude's Discretion
- Exact shade of green for installer
- Welcome message wording (keep it Matrix-themed)
- Technical approach for borderless windows (if feasible)
- Splash screen cmd.exe fix implementation details

</decisions>

<specifics>
## Specific Ideas

- "4 pillars should look like 4 narrow strips, respect the gaps"
- "Force borderless would make the effect better" (nice-to-have)
- User liked the overlap version ("chef's kiss")
- wakeupneo/bluepill windows should become invisible but stay open

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope (bug fixes only)

</deferred>

---

*Phase: 13-post-e2e-polish*
*Context gathered: 2026-02-01*
