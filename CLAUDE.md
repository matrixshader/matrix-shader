# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Matrix Terminal Shader - A real-time controllable Matrix rain effect for Windows Terminal. Multi-window system with interactive control panel for managing multiple shader instances simultaneously.

## Architecture

```
User Input → matrix_control.ps1 → Regenerates shader HLSL → Windows Terminal hot-reloads → GPU renders
```

**Key mechanism:** PowerShell writes shader parameters as `#define` statements. Windows Terminal detects file timestamp change and reloads shader automatically (~100ms latency).

**Core Files:**
- `matrix_control.ps1` - Multi-window control panel TUI with tabbed interface for up to 6 shader windows
- `matrix_setup.ps1` - Interactive setup wizard (Blue Pill vs Red Pill paths)
- `shaders/Matrix-1.hlsl` through `Matrix-6.hlsl` - HLSL pixel shaders with bit-packed Katakana glyphs
- `shaders/Redpill-Neo.hlsl` - Custom 3D corridor shader with glowing "MATRIX SHADER" logo (Neo vision)
- `prd.json` - Ralph-compatible user stories for current hardening sprint
- `MVP/Matrix.hlsl` - Original single-instance shader (legacy)

## Critical Technical Details

### HLSL Glyph System
Glyphs are bit-packed: 35 bits (5×7 pixels) per character stored in uint32 constants. Lookup: `(GLYPHS[idx] >> bit_index) & 1u`

### Hot-Reload Mechanism
PowerShell regenerates entire shader file with new `#define` values, then touches file timestamp. Windows Terminal watches for changes.

### Layer System
Three parallax depth layers (FAR/MID/NEAR) rendered additively. Each can be toggled independently.

### Multi-Window System
Control panel manages up to 6 independent shader windows. Each window:
- Can use different shader from library
- Has independent parameters (speed, color, density, layers)
- Is positioned/sized via Windows API calls
- Has configuration persisted to JSON files

## File Encoding

PowerShell requires CRLF line endings. Always use Windows-native tools.

## Key Paths

- Project root: `C:\Users\ehome\Documents\Matrix\`
- Control panel: `C:\Users\ehome\Documents\Matrix\matrix_control.ps1`
- Setup wizard: `C:\Users\ehome\Documents\Matrix\matrix_setup.ps1`
- Shader library: `C:\Users\ehome\Documents\Matrix\shaders\`
- Windows Terminal settings: `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
- GitHub repo: `matrixshader/matrix-shader`

## Testing

1. Modify shader `#define` values directly in any shader file - changes appear immediately in terminal
2. Run `matrix_control.ps1` in Windows PowerShell to test TUI controls and multi-window management
3. Run `matrix_setup.ps1` to test setup wizard flow (Blue Pill vs Red Pill)
4. Verify shader compiles by checking Windows Terminal shows effect (no error = success)

## Project State

### Current Phase: Phase 15 - Owner Analytics Dashboard & Website Polish (Complete)

### Completed Phases:
- [x] MVP single-instance shader (Matrix.hlsl + matrix_tool.ps1)
- [x] Multi-window system architecture
- [x] Setup wizard with Blue/Red Pill paths
- [x] Neo vision shader (Redpill-Neo.hlsl)
- [x] Code review and PRD generation
- [x] Control Panel Hardening (US-001 through US-010)
- [x] C#/.NET Rebuild (Phases 1-13)
- [x] Phase 14 Wave 1-4 (14-01 through 14-05)
- [x] Phase 14-06 E2E Round 1 Testing
- [x] Phase 15 - Owner Analytics Dashboard & Website Polish

### Current Phase Checklist (Phase 14):
- [x] 14-01: Hotkey service stability (crash recovery, stay-alive timer)
- [x] 14-02: Transparency fixes (plain transparency, settings backup/restore)
- [x] 14-03: Hotkey actions (window rotation, layer toggles)
- [x] 14-04: Layout fixes (gap scaling, fullscreen exclusion)
- [x] 14-05: Remove shader cycling, rename Cyan to Blue
- [x] 14-06: E2E Round 1 - Fixed transparency toggle, Glitch cooldown, auto-continue, feedback

### Next Steps:
- [ ] Build campaign folder: per-platform post drafts, UTM tracking links, launch calendar
- [ ] Wire UTM source tracking into script.js so dashboard shows which platform drives sales
- [ ] Add white rabbit cursor Easter egg on /redpill page
- [ ] E2E Round 2: verify Glitch, opacity toggle, Glitch cooldown, and auto-continue in Windows Sandbox
- [ ] Implement hotkey help popup (Matrix-styled) - user requested feature
- [ ] Test Glitch in Blue Pill path (wakeupneo and bluepill.exe)

## Session History

### Session 2026-01-11: Neo Vision & Hardening PRD
**Phase:** Control Panel Hardening - PRD Creation

**Accomplishments:**
1. Created custom Redpill-Neo vision shader (`shaders/Redpill-Neo.hlsl`)
   - 3D box corridor effect with Matrix code on walls/floor/ceiling
   - SDF-based glowing "MATRIX SHADER" logo text
   - Tuned text size, thickness, spacing, and glow levels
2. Updated Red Pill path in `matrix_setup.ps1`
   - Creates shaders for configured windows
   - Launches all Matrix windows user selected
   - Opens Redpill control panel with Neo vision background
   - Deleted legacy `matrix_tool.ps1` (replaced by `matrix_control.ps1`)
3. Code review via feature-dev:code-reviewer agent
   - Found critical bugs: unsafe atomic write, missing JSON error handling, regex issues
   - Found important issues: window handle sorting, fixed delays, lost unsaved changes
   - Overall rating: 7/10 - excellent design, needs hardening
4. Generated PRD (`tasks/prd-control-panel-hardening.md`) with 10 user stories
5. Created Ralph-compatible prd.json
   - Archived previous v2 prd.json to `archive/2026-01-11-matrix-v2-fix/`
   - New prd.json has 10 hardening stories
   - Reset progress.txt for new project

**Key Decisions:**
- Neo vision shader uses SDF text rendering instead of sprite-based glyphs
- Control panel hardening takes priority over new features
- Code review identified atomic file write as highest priority fix

**Next Steps:**
- Execute hardening user stories US-001 through US-010 via Ralph loop OR manual implementation
- Start with US-001 (safe atomic file writes) as highest priority
- Consider adding unit tests after hardening complete

**Files Modified:**
- `shaders/Redpill-Neo.hlsl` (created)
- `matrix_setup.ps1` (updated Red Pill path)
- `matrix_tool.ps1` (deleted - legacy file)
- `prd.json` (new hardening stories)
- `tasks/prd-control-panel-hardening.md` (created)
- `archive/2026-01-11-matrix-v2-fix/prd.json` (archived)
- `progress.txt` (reset for new project)

### Session 2026-01-17: Window Layout Engine Implementation
**Phase:** Control Panel Hardening - Window Layout Engine

**Accomplishments:**
1. Implemented complete 8-phase Window Layout Engine (`WindowLayoutEngine.ps1` - 1046 lines)
   - Phase 1: Get-MonitorInfo (multi-monitor detection via EnumDisplayMonitors)
   - Phase 2: Calculate-PillarsLayout (side-by-side columns per monitor)
   - Phase 3: Calculate-QuadsLayout (2x2 grid per monitor)
   - Phase 4: Find-MatrixWindows (EnumWindows P/Invoke for window detection)
   - Phase 5: Match-WindowsToSlots (registry-based shader-to-window mapping)
   - Phase 6: Set-WindowLayout (SetWindowPos P/Invoke for positioning)
   - Phase 7: Invoke-MatrixLayout (orchestration with layout mode cycling)
   - Phase 8: Edge case handling (50/50 tests passing)
2. Integration across all entry points
   - `matrix_control.ps1`: Added Shift+L hotkey to cycle layout modes (Pillars/Quads/Auto)
   - `matrix_setup.ps1`: Calls WindowLayoutEngine after launching windows
   - `bluepill.ps1`: Uses WindowLayoutEngine for automatic positioning
3. Comprehensive testing suite
   - Phase-specific tests (test-layout-phase1.ps1 through test-layout-phase8.ps1)
   - Edge case tests (window detection, missing slots, non-sequential slots, etc.)
   - Multi-monitor simulation tests
4. Architecture documentation (`ARCHITECTURE_WINDOW_LAYOUT.md`)
   - Detailed phase-by-phase implementation guide
   - API reference for all public functions
   - Edge case catalog with solutions
5. Recovery documentation (RECOVERY/ folder)
   - Per-phase output markdown files
   - Agent completion logs
   - Rate-limit recovery documentation

**Key Decisions:**
- Centralized layout engine vs. inline positioning in each script
- Registry-based window-to-shader mapping for persistent identification
- Two layout modes (Pillars and Quads) with mode cycling
- P/Invoke for Windows API calls (EnumWindows, SetWindowPos, EnumDisplayMonitors)
- Edge case priority: robustness over performance

**Next Steps:**
- Complete remaining hardening stories (US-009 diagnostic logging, US-010 consolidate key handlers)
- Enhance registry system for shader-to-window persistence
- Add additional layout modes (cascade, fullscreen, custom)
- Performance optimization for large window counts

**Files Modified:**
- `WindowLayoutEngine.ps1` (created - 1046 lines)
- `ARCHITECTURE_WINDOW_LAYOUT.md` (created)
- `matrix_control.ps1` (added Shift+L layout cycling)
- `matrix_setup.ps1` (integrated WindowLayoutEngine)
- `bluepill.ps1` (integrated WindowLayoutEngine)
- `CLAUDE.md` (updated project state)
- `README.md` (updated current status)
- `prd.json` (marked US-001 through US-008 complete)
- Test files: test-layout-phase1.ps1 through test-layout-phase8.ps1
- RECOVERY/phase1-8_output.md (phase documentation)
- RECOVERY/agent logs (completion tracking)

### Session 2026-02-05: Phase 14 E2E Testing and Bug Fixes
**Phase:** Final Polish & Hotkey Stability - E2E Round 1

**Accomplishments:**
1. Executed Phase 14 (6 plans across 4 waves):
   - 14-01: Hotkey service stability with crash recovery and stay-alive timer
   - 14-02: Transparency fixes (plain transparency instead of acrylic blur, settings backup/restore)
   - 14-03: Hotkey action fixes (window rotation instead of swap, layer toggle actions)
   - 14-04: Layout fixes (gap scaling, fullscreen window exclusion from Glitch)
   - 14-05: Removed shader cycling feature, renamed Cyan preset to Blue
   - 14-06: E2E verification and bug fixes from testing

2. Fixed AOT Build Issues:
   - Disabled AOT compilation to avoid UiaProviderCallback marshalling errors
   - Rebuild all executables with `/p:PublishAot=false` flag

3. E2E Bug Fixes from Round 1 Testing:
   - **BUG-TRANS04**: ToggleTransparency (Ctrl+B) changed from UseAcrylic toggle to Opacity 85%↔100% toggle
   - **BUG-GLITCH01**: Added 5-second cooldown after manual hotkey rotation to prevent Glitch snap-back fighting
   - **UX-FEEDBACK01**: WakeupNeo now shows "Starting hotkeys & Glitch... OK" for both Blue/Red pill paths
   - **UX-FLOW01**: Auto-continue after WT install - launches `wt.exe wakeupneo` instead of manual steps
   - **BUG-SHADER06**: Fixed shader phase offsets - copied correct shaders with staggered rain column timing

4. Documentation Created:
   - `installer/LOCAL-TESTING.md` - CLI one-liner test setup documentation
   - `MatrixShaderTest.wsb` - Windows Sandbox config for E2E testing

**Key Decisions:**
- Disable AOT compilation to avoid UI Automation marshalling errors (trade startup time for stability)
- Change transparency toggle from acrylic to opacity for plain see-through effect
- Add Glitch cooldown to prevent hotkey/monitor fighting
- Auto-continue after WT install improves UX flow
- Use Windows Sandbox for E2E testing with HTTP server on Default Switch

**Next Steps (Round 2 Testing):**
- Verify Glitch works in Blue Pill path (wakeupneo and bluepill.exe)
- Verify Ctrl+B toggles opacity correctly (85%↔100%)
- Verify hotkey rotation doesn't trigger Glitch snap-back (5s cooldown)
- Verify auto-continue after WT install works
- Implement hotkey help popup (Matrix-styled) - user requested feature

**Files Modified:**
- `MatrixShader/src/MatrixShader.Hotkeys/HotkeyActions.cs` (opacity toggle)
- `MatrixShader/src/MatrixShader.Hotkeys/MatrixWindowMonitor.cs` (5s cooldown)
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` (feedback, auto-continue)
- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` (auto-continue)
- `installer/LOCAL-TESTING.md` (created)
- `MatrixShaderTest.wsb` (created)

**Technical Notes:**
- Build uses AOT disabled: `/p:PublishAot=false`
- Local testing uses HTTP server on port 9090 with IP 172.21.80.1 (Default Switch)
- `installer/output` is gitignored - rebuild required for each test
- Branch `feature/smart-window-management` merged to `master` and pushed

### Session 2026-02-18: Owner Analytics Dashboard & Website Polish
**Phase:** Phase 15 - Analytics, Tracking, and Website Asset Completion

**Accomplishments:**
1. Owner Analytics Dashboard (`Website/admin/index.html`):
   - Glassmorphism UI with Matrix green terminal aesthetic using JetBrains Mono font
   - Password-protected (client-side gate + Authorization header to API)
   - Chart.js line/bar charts for page views, redpill clicks, GitHub clicks over 30 days
   - KPI cards: total downloads, installs, activations, purchases, subscribers
   - Live refresh every 60 seconds; `noindex, nofollow` meta to keep it invisible to search
   - Matrix rain canvas background (same as all other pages)

2. Enhanced `api/track.js`:
   - Added time-series daily keys (`ts:<event>:<YYYY-MM-DD>`) in parallel with global counters
   - Extended allowed event list: `page_view`, `redpill_click`, `github_click`
   - Both global `stats:<event>` and per-day `ts:<event>:<date>` incremented atomically

3. Created `api/dashboard.js`:
   - Password-protected via `Authorization: Bearer <DASHBOARD_PASSWORD>` header (env var on Vercel)
   - Fetches last-30-day time-series for page_view, redpill_click, github_click
   - Returns all-time totals for download, install, activate, subscribe, purchase
   - Gracefully handles missing Redis keys (defaults to 0)

4. Enhanced `Website/script.js`:
   - `sendBeacon` calls for `page_view` on DOMContentLoaded
   - `redpill_click` fires on the Buy button click
   - `github_click` fires on the GitHub star/release links

5. Added `page_view` tracking to `Website/redpill/index.html` and `Website/redpill/thankyou/index.html`

6. Matrix rain video background added to ALL pages:
   - `Website/privacy/index.html`, `Website/terms/index.html`
   - `Website/404.html`, `Website/redpill/thankyou/index.html`
   - `Website/admin/index.html`

7. Pushed all previously uncommitted website redesign assets (36 files):
   - Responsive images: `pillars-layout` and `quads-layout` at 400w, 800w, 1920w (webp + png)
   - `Website/shared.css` - shared stylesheet across all pages
   - `Website/robots.txt` and `Website/sitemap.xml` - SEO infrastructure
   - `Website/404.html` - custom 404 page
   - `Website/assets/icons/` - favicon/PWA icon set
   - `Website/assets/logo.webp` - WebP logo variant
   - `Website/assets/favicon-original.ico` and `logo-original.jpg` - originals preserved

**Key Decisions:**
- Password protection via HTTP Authorization header (Bearer token) rather than session cookies - simpler for a single-owner dashboard
- `noindex, nofollow` on admin page rather than route-level protection (Vercel handles route auth via env var check in the API)
- Time-series keys added as a parallel write to avoid breaking existing counters
- Used `navigator.sendBeacon` for tracking (non-blocking, survives page unload)
- Matrix rain video background unified across all pages for brand consistency
- `DASHBOARD_PASSWORD` env var must be set in Vercel dashboard (user confirmed done)

**Files Modified/Created:**
- `Website/admin/index.html` (created - glassmorphism analytics dashboard)
- `api/dashboard.js` (created - password-protected analytics API)
- `api/track.js` (modified - time-series keys, new event types)
- `Website/script.js` (modified - sendBeacon tracking calls)
- `Website/index.html` (modified - tracking calls)
- `Website/redpill/index.html` (modified - page_view tracking, video bg)
- `Website/redpill/thankyou/index.html` (modified - page_view tracking, video bg)
- `Website/privacy/index.html` (modified - video background)
- `Website/terms/index.html` (modified - video background)
- `Website/404.html` (created - custom 404 with Matrix rain)
- `Website/shared.css` (created - shared styles)
- `Website/robots.txt` (created)
- `Website/sitemap.xml` (created)
- `Website/assets/` - 20+ new responsive image and icon assets

**Technical Notes:**
- `DASHBOARD_PASSWORD` must be set in Vercel environment variables (Production)
- Dashboard URL: `https://matrixshader.com/admin` (noindex - not linked from site)
- Redis keys used: `stats:<event>` (all-time) and `ts:<event>:<YYYY-MM-DD>` (daily)
- All 4 commits pushed to `origin/master` before this session close

### Session 2026-02-23: Security Hardening, Sentry Integration & Launch Strategy
**Phase:** Post-v1.0 - Security, Observability, and Go-to-Market

**Accomplishments:**
1. Sentry Error Monitoring Integration:
   - Created shared `api/_sentry.js` helper module for consistent error capture
   - Integrated Sentry across all 8 API endpoints: validate, webhook, faq, dashboard, backup, track, unsubscribe
   - Captures errors with endpoint context, graceful degradation if Sentry unavailable
   - Free tier sufficient for current traffic levels

2. Security Hardening - License Key Validation:
   - **Fake key bypass closed**: Added HMAC signature verification to `api/validate.js` - keys are now cryptographically validated, not just format-checked
   - **Refund key revocation**: `api/webhook.js` now marks refunded keys as revoked in Redis, preventing continued use after refund

3. Launch Strategy Research:
   - Comprehensive research compiled at `.planning/research/LAUNCH-STRATEGY.md` (30+ sources)
   - Channel priority established: Hacker News #1, Reddit #2, Twitter/X #3, Product Hunt #5
   - Reddit needs 4-6 weeks account seasoning for new accounts (user has older personal account)
   - Target subreddits ranked by subscriber count and cultural fit
   - Competitor landscape analysis: no paid Matrix rain product exists
   - Wallpaper Engine cited as market proof ($3.99, 20-50M owners)
   - Timing: Feb-March seasonal sweet spot, Matrix 5 coming, DEF CON August 2026
   - Recommended 6-phase launch sequence over 7+ weeks

4. Business Strategy Decision:
   - Chose Strategy C: spend $0, launch this week with free channels
   - LemonSqueezy is merchant of record - no LLC needed to start selling
   - Order: launch -> sales -> Traveling Mailbox -> LLC -> bank account
   - Let product revenue fund its own infrastructure

5. Updated `.planning/UNIFIED-ROADMAP.md` with launch-first priorities

**Key Decisions:**
- Strategy C ($0 launch budget) - cash-strapped, let sales fund infrastructure
- Use personal Reddit account (older, with history) instead of new u/matrixshader - bypasses seasoning period
- LemonSqueezy as merchant of record eliminates need for LLC before first sale
- HMAC verification for license keys - cryptographic validation, not just format check
- Sentry free tier for error monitoring - catches API errors without cost

**Lesson Learned:**
- **Never dismiss subagent results.** When parallel research agents return, always review their findings properly, call out what is new or different, and integrate honestly. The point of parallel agents is getting different perspectives. Dismissing one agent's work with "already incorporated" without proper review is lazy and disrespectful to the research process.

**Pending Items:**
- Campaign folder: per-platform post drafts, UTM tracking links, launch calendar (user explicitly requested)
- White rabbit cursor: custom cursor Easter egg on /redpill page
- UTM source tracking: wire into script.js so dashboard shows which platform drives sales

**Files Modified:**
- `api/_sentry.js` (created - shared Sentry helper)
- `api/validate.js` (HMAC key verification)
- `api/webhook.js` (refund key revocation)
- `api/faq.js` (Sentry integration)
- `api/dashboard.js` (Sentry integration)
- `api/backup.js` (Sentry integration)
- `api/track.js` (Sentry integration)
- `api/unsubscribe.js` (Sentry integration)
- `.planning/UNIFIED-ROADMAP.md` (updated priorities)
- `.planning/research/LAUNCH-STRATEGY.md` (created - comprehensive launch research)

**Technical Notes:**
- Sentry DSN configured via `SENTRY_DSN` env var in Vercel
- HMAC uses `LEMON_SQUEEZY_SIGNING_SECRET` for key validation
- Revoked keys stored in Redis as `revoked:<key>` with TTL
- User has older personal Reddit account - 1-2 weeks of genuine comments in target subreddits recommended before promotional posts
- User context: fighting flu + dental infection, doing Amazon Flex gig work, every dollar counts
