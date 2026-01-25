# Codebase Concerns

**Analysis Date:** 2026-01-25

## Tech Debt

**Shader Template Duplication:**
- Issue: Identical HLSL shader template string duplicated across three entry points
- Files: `matrix_control.ps1` (lines 8-90), `matrix_setup.ps1` (lines 11-93), `bluepill.ps1`
- Impact: Changes to glyph system or shader structure require updates in three places; risk of inconsistency
- Fix approach: Extract shader template to shared module file `ShaderTemplate.ps1`, source it in all entry points; make it a single source of truth

**Multiple P/Invoke API Classes:**
- Issue: Windows API P/Invoke declarations duplicated across three large scripts
- Files: `matrix_control.ps1` (~180 lines of P/Invoke), `WindowLayoutEngine.ps1` (~70 lines), `WindowIdentityService.ps1` (~100 lines)
- Impact: Maintenance burden when adding new API calls; DLL compilation (`MatrixAPI.dll`) must be kept in sync with all definitions
- Fix approach: Consolidate all P/Invoke definitions into single `WindowAPIDefs.ps1` module; load once at startup; reduces compiled DLL size

**Silently Swallowed Catch Blocks:**
- Issue: Catch blocks with no body or minimal logging exist in terminal effect operations
- Files: `matrix_control.ps1` (lines 364, 434, 580, 669), `WindowLayoutEngine.ps1` multiple locations
- Impact: Failures in transparency application, JSON operations silently fail; user has no visibility into what went wrong
- Fix approach: Add structured logging to all catch blocks; log at WARN level with context (operation, values); never use bare `catch { }` without logging

**Layout Mode State Cached Inconsistently:**
- Issue: Layout configuration cached in multiple ways: JSON file, script-scoped variables, registry
- Files: `matrix_control.ps1` (Get-MatrixLayoutConfig/Set-MatrixLayoutConfig), `WindowLayoutEngine.ps1` (script:LayoutMode, script:AccommodationState)
- Impact: Cache invalidation unclear; Position-MatrixWindows may use stale config; multi-instance scenarios could have diverged state
- Fix approach: Single source of truth for layout state; consider persistent JSON only, no script variables; implement write-through caching with version tracking

## Known Bugs

**Identity Registry Stale Entries:**
- Symptoms: Old window PIDs remain in `identity-registry.json` after windows close; registry grows without bound
- Files: `WindowIdentityService.ps1` (line 278 Save-IdentityRegistry), `matrix_control.ps1` (Clean-WindowRegistry)
- Trigger: Launch 10+ windows, close half, registry never shrinks; old PIDs remain even after restart
- Workaround: Manually delete `identity-registry.json` to reset; system auto-cleans on next 10-window launch (cleanup threshold in line 241 of `matrix_monitor.ps1`)
- Fix approach: Implement automatic garbage collection every 100 registrations or on startup; validate PIDs are still alive before reusing

**Position Tracking Race Condition:**
- Symptoms: "Position not stable" message appears intermittently on rapid window drags; windows occasionally snap to wrong position
- Files: `WindowLayoutEngine.ps1` (lines 3770-3810, Update-PositionTracking)
- Trigger: Click-drag window border rapidly, switch layout modes mid-drag
- Cause: 300ms threshold for position stability (line 388 in `matrix_control.ps1`) too aggressive when user drags slow; multi-threaded position updates race with accommodation logic
- Workaround: Wait for "IDLE" state before switching layout (don't use Shift+L while dragging)
- Fix approach: Increase stability threshold to 500ms; add debounce to layout mode switching during accommodation

**Empty IdentitySource Fallthrough:**
- Symptoms: Window detection may fail with "IdentitySource=null" in some scenarios; window appears in registry but Position-MatrixWindows skips it
- Files: `WindowIdentityService.ps1` (Resolve-WindowIdentity function)
- Trigger: Launch window before identity service fully initializes; very tight timing
- Cause: All four identity layers (Launch Tracking, Command Line, Title, UI Automation) can fail in race condition; function returns entry with null IdentitySource
- Workaround: Re-launch the window; second attempt succeeds
- Fix approach: Add fallback IdentitySource='Unknown' when all layers fail; log which layers failed for debugging

## Security Considerations

**Unvalidated shader.json Load:**
- Risk: If `identity-registry.json` is corrupted with malformed JSON, ConvertFrom-Json throws error and control panel crashes
- Files: `matrix_control.ps1` (line 239 Load-TerminalEffects with catch, but minimal recovery), `WindowIdentityService.ps1` (Load-IdentityRegistry)
- Current mitigation: Try-catch blocks present; errors logged; script continues in degraded mode
- Recommendations:
  - Add schema validation after JSON parse (whitelist expected keys: ProfileName, LaunchTime, etc.)
  - Implement atomic JSON writes with validation before Move-Item in Save-IdentityRegistry (currently only in matrix_control.ps1 line 623-624)
  - Add file integrity check (file hash or version tag) to detect tampering

**File Permissions on Matrix State Files:**
- Risk: `identity-registry.json`, `matrix_state.json`, `window-registry.json` stored in user's Documents folder with default permissions; other user accounts on machine could read shader configurations
- Files: All paths use `$env:USERPROFILE\Documents\Matrix\`
- Current mitigation: None; files created with default ACLs
- Recommendations:
  - Restrict ACLs on state files to owner only: `icacls "path" /grant:r "$env:USERNAME:(F)" /inheritance:r` at initialization
  - Document in setup wizard that state files contain user window arrangements (low sensitivity but still private)
  - Validate file permissions on startup and warn if unrestricted

**Registry Access via UI Automation:**
- Risk: `Get-ProfileFromUIAutomation` (matrix_control.ps1) reads Windows Terminal profile names through UI element enumeration; could fail or be spoofed if TermControl element structure changes
- Files: `matrix_control.ps1` (line ~470 deep element traversal for profile name)
- Current mitigation: Fallback to title-based matching if UI Automation fails
- Recommendations:
  - Document which Windows Terminal version this assumes (current: likely v1.18+)
  - Add version check to verify Windows Terminal API stability
  - Consider reading profiles directly from `settings.json` as additional validation layer

**DLL Compilation Fallback:**
- Risk: If `MatrixAPI.dll` missing, code silently compiles P/Invoke C# code at runtime; could be slow but also introduces compilation latency unpredictably
- Files: `matrix_control.ps1` (lines 309-371), `WindowLayoutEngine.ps1` (lines 6-69), `WindowIdentityService.ps1` (lines 18-155)
- Current mitigation: DLL exists in repo (5.6KB); fallback documented in comments
- Recommendations:
  - Verify DLL signature/hash on load to detect tampering: `Get-FileHash MatrixAPI.dll | Compare-Object $expectedHash`
  - Pre-compile on install; fail loudly if DLL missing rather than silent fallback
  - Document DLL as critical deliverable in CLAUDE.md

## Performance Bottlenecks

**WindowIdentityService Four-Layer Resolution:**
- Problem: Get-AllWindowIdentities calls four identity resolution methods in sequence; slowest case (all layers fail, triggers UI Automation) can take 500ms+ per window
- Files: `WindowIdentityService.ps1` (lines 1000-1100, Resolve-WindowIdentity orchestration)
- Cause: UI Automation (Layer 4) traverses accessibility tree for each window; ~100-300ms per window
- Current: 6 windows x 100ms (best case) = 600ms; 6 windows x 300ms (worst case) = 1800ms
- Impact: Noticeable 2-3 second delay when launching 6 windows simultaneously
- Improvement path:
  1. Batch Layer 2 (WMI command line queries) - already done
  2. Parallelize Layer 4 (UI Automation) using background jobs for first 2-3 windows
  3. Cache Layer 1 results for 30 seconds; reuse for rapid successive lookups
  4. Consider removing Layer 4 entirely if Layers 1-3 achieve 95%+ hit rate in practice

**Position Polling in Accommodation System:**
- Problem: Detect-DragInProgress (line 3735) polls window positions every 100ms when looking for drag end; 1000ms stability check means up to 10 checks per accommodation cycle
- Files: `WindowLayoutEngine.ps1` (lines 3700-3820)
- Cause: GetWindowRect P/Invoke call for each window each poll; no way to hook Windows events directly from PowerShell
- Impact: Constant CPU usage during user drag operations; ~5% CPU per window being dragged
- Improvement path:
  - Register for WM_MOVING window message via P/Invoke hook (complex, high risk)
  - Accept current behavior as acceptable; document that drag accommodation trades 5% CPU for smooth UX
  - Add power-saving mode: disable accommodation on battery power

**Layout Calculation Re-computation:**
- Problem: Position-MatrixWindows calls Get-ScreenTopology and Calculate-Layout even when nothing changed
- Files: `matrix_control.ps1` (lines 980, 1174, 1193) - called on every key press that affects layout
- Cause: No memoization of screen topology; recalculated on each layout change
- Impact: 100ms delay each time user presses ',' '.' or Shift+L
- Improvement path:
  - Cache screen topology with version stamp (invalidate on WM_DISPLAYCHANGE)
  - Lazy evaluation: only recalculate if window count or screen topology changed
  - Measure actual impact: may be negligible if 100ms is already acceptable for UI responsiveness

**String Replacement in Shader Template:**
- Problem: Save-Shader uses 13 sequential `-replace` operations on 3.9KB template string
- Files: `matrix_control.ps1` (lines 182-185), `matrix_setup.ps1` (lines 108-111)
- Cause: No templating engine; manual string substitution
- Impact: O(n*m) complexity where n=template size, m=number of replacements; negligible for 3.9KB but inelegant
- Improvement path: Use a proper templating approach (PSM templating or StringBuilder for better scalability if shader grows)

## Fragile Areas

**Window Layout Engine (3899 LOC):**
- Files: `WindowLayoutEngine.ps1`
- Why fragile: Largest single file in codebase; contains 8 distinct phases with interdependencies; manual P/Invoke structures; complex multi-monitor logic
- Safe modification:
  - Changes to phases 1-3 (topology, pillars, quads): Low risk; functions are well-documented
  - Changes to phases 5-7 (matching, setting, orchestration): High risk; tight coupling with identity service and control panel
  - Changes to phase 8 (accommodation): Critical; drag detection and position tracking interact with real-time window state
- Test coverage:
  - test-layout-phase1.ps1 through test-layout-phase8.ps1 exist (all 8 phases have tests)
  - Coverage appears comprehensive (50/50 tests mentioned in CLAUDE.md for phase 8)
  - Gap: No integration tests for multi-monitor with actual monitors; simulation-based only

**WindowIdentityService Identity Resolution:**
- Files: `WindowIdentityService.ps1` (1286 LOC)
- Why fragile: Four-layer resolution with different failure modes; registry persistence adds state complexity; race conditions possible if windows launched while service initializing
- Safe modification:
  - Layers 1-3 (Launch Tracking, Command Line, Title): Relatively stable; focus on batch query optimization
  - Layer 4 (UI Automation): Fragile to Windows Terminal UI changes; each version may change element names/structure
  - Registry persistence: Changes to Save-IdentityRegistry format could break existing registries
- Test coverage:
  - test-identity-service.ps1 (444 LOC) covers basic scenarios
  - Gap: No test for Layer 4 fallback with disabled UI Automation
  - Gap: No regression test for registry format compatibility after version upgrade
  - Gap: No test for multi-threaded registry access (two scripts launching windows simultaneously)

**matrix_control.ps1 Key Handler Dispatch:**
- Files: `matrix_control.ps1` (lines 920-1220)
- Why fragile: Complex keyboard dispatch logic with normalization (ToLower) but special cases (Shift+L for layout vs 'L' for opacity); hard to trace control flow
- Safe modification:
  - Adding new key: Safe; append case in switch statement
  - Changing normalization: High risk; breaks case-sensitive layer detection
  - Removing key: Medium risk; verify no duplicate handling paths
- Test coverage:
  - Hardening stories US-005 and US-010 addressed key handler consolidation
  - Gap: No automated test suite for key dispatch logic; manual testing only
  - Gap: No regression test for Shift+key vs regular key interactions

## Scaling Limits

**Maximum Windows per Session:**
- Current capacity: 8 shader slots (Matrix-1 through Matrix-8)
- Limit: Hard-coded in multiple places (shader template, layouts, slot detection regex)
- Scaling path:
  1. Add support for Matrix-9 through Matrix-16 (requires updated layouts for ultra-wide monitors)
  2. Update regex patterns: `^Matrix-\d+$` becomes `^Matrix-([1-9]\d?)$` (supports 1-99)
  3. Modify layout calculations to support arbitrary window counts across arbitrary monitor counts
  4. Test with 12+ window simulation on multi-monitor setup

**Registry Size Limit:**
- Current: `identity-registry.json` grows indefinitely as windows are launched/closed
- Limit: No enforced cap; in theory could reach 10MB+ with 10000s of historical entries
- Scaling path:
  1. Implement automatic cleanup threshold (garbage collection at 1000 entries)
  2. Track last-seen timestamp for each registry entry; prune entries older than 30 days
  3. Consider moving to SQLite database if registry needs persistent query capabilities

**Monitor Count Scaling:**
- Current: Tested with 2 monitors; logic generalizes to N monitors in theory
- Limit: UI/UX assumes 2-3 monitors for practical use; layout modes (Pillars/Quads) optimized for 2 monitors
- Scaling path:
  1. Add "Auto" layout mode that adapts to monitor count (e.g., 2 rows x 2 cols on 4+ monitors)
  2. Test on actual 3-monitor and 4-monitor setups (not simulated)
  3. Consider horizontal-only layout for ultra-wide (1x8) scenarios

## Dependencies at Risk

**Windows Terminal Integration Dependency:**
- Risk: Hot-reload mechanism relies on Windows Terminal detecting HLSL file timestamp changes and reloading; if Windows Terminal changes file watching behavior, shader updates won't appear
- Impact: Core functionality breaks; users see no effect from control panel inputs
- Migration plan:
  - Currently no fallback mechanism; could add polling in separate background process that checks for file changes and triggers refresh via Windows Terminal API (if exposed)
  - Could embed shader directly in Windows Terminal profile instead of external file (requires API changes to WT)

**UI Automation Dependency:**
- Risk: Layer 4 identity resolution uses Windows UI Automation API; if Windows Terminal changes TermControl element structure, window detection fails silently
- Impact: Falls back to Layer 3 (title matching) which is 85% reliable; some windows may be misidentified
- Migration plan:
  - Add Windows Terminal version check to document which versions are supported
  - Implement Windows Terminal settings.json direct read as alternative to UI Automation
  - Monitor Windows Terminal release notes for breaking changes to internal UI

**PowerShell Version Assumption:**
- Risk: Code uses features that may not exist in older PowerShell versions (e.g., PSv5.0 vs PSv7.x compatibility)
- Impact: Setup wizard fails silently on unsupported versions
- Current mitigation: CLAUDE.md specifies "Windows PowerShell" (implying PSv5.1 minimum)
- Fix approach: Add explicit version check at script startup; fail with clear error if PSv5.0 or older

## Missing Critical Features

**Undo/Redo for Shader Changes:**
- Problem: No way to revert to previous shader settings; must manually recreate color/speed values
- Blocks: Users frustrated by accidental color changes; no recovery path
- Impact: Medium - usability issue, not functionality blocker
- Solution: Implement shader history buffer (last 10 states) with '[' and ']' hotkeys for undo/redo

**Shader Presets Persistence:**
- Problem: Presets defined in code (matrix_setup.ps1 lines 97-110) but not saved to disk; new presets can't be created by users
- Blocks: Users can't save their favorite shader combinations; limited customization
- Impact: Medium - limits user engagement with the tool
- Solution: Store presets in JSON file; add 'S' key to save current state as named preset

**Cross-Session Window State Restoration:**
- Problem: Window positions and configurations not restored on system restart
- Blocks: Users must manually reconfigure windows after reboot
- Impact: Medium - convenience issue for persistent use case
- Current: matrix_state.json exists but restoration logic incomplete
- Solution: Implement state save/restore in matrix_setup.ps1 Blue Pill initialization

**Monitor Hotplug Handling:**
- Problem: If monitors disconnect/reconnect while control panel running, layout becomes invalid; windows not repositioned
- Blocks: Laptop docking scenarios; temporary monitor disconnection
- Impact: Low - edge case but annoying for mobile users
- Solution: Register WM_DISPLAYCHANGE handler; reapply current layout on change

## Test Coverage Gaps

**WindowIdentityService Layer 4 Fallback (UI Automation):**
- What's not tested: Behavior when UI Automation returns null or TermControl element is missing
- Files: `WindowIdentityService.ps1` (lines 700-800 Get-UIAutomationIdentity)
- Risk: If UI Automation path has unhandled exception, window detection fails silently; user sees "no windows found"
- Priority: High - core path used when layers 1-3 fail

**Atomic File Write Error Recovery:**
- What's not tested: Scenario where temp file created but Move-Item fails (e.g., permission denied, disk full)
- Files: `matrix_control.ps1` (lines 620-630 Save-Shader), `WindowIdentityService.ps1` (lines 278-279 Save-IdentityRegistry)
- Risk: Temp file left behind; original file untouched but operation appears to fail; next write may overwrite temp with corrupted data
- Priority: High - US-001 mitigation depends on this behavior

**Multi-Instance Window Launch Collision:**
- What's not tested: Launch two windows with same profile name simultaneously (via two control panel instances or race condition)
- Files: `WindowIdentityService.ps1` (Register-LaunchEvent), `matrix_control.ps1` (Launch-MatrixWindows)
- Risk: Identity registry confusion; both windows claim same profile; positioning applies to wrong window
- Priority: Medium - requires user error (dual control panel launch) to trigger

**Corrupted JSON File Recovery:**
- What's not tested: Partial JSON writes (e.g., power loss during file write); recovery logic
- Files: `matrix_control.ps1` (Load-Shader line 157), `WindowIdentityService.ps1` (Load-IdentityRegistry)
- Risk: Script crashes with ConvertFrom-Json error; control panel won't start
- Priority: Medium - edge case but blocks user entirely

**Layout Calculation Edge Cases:**
- What's not tested: Asymmetric monitor configurations (e.g., 1920x1080 + 3840x2160); off-brand resolutions (e.g., 1366x768); Windows scaling (125%, 150%)
- Files: `WindowLayoutEngine.ps1` (Calculate-PillarsLayout, Calculate-QuadsLayout)
- Risk: Window positioning off-screen or overlapping on exotic configurations
- Priority: Medium - limits usability on non-standard setups

---

*Concerns audit: 2026-01-25*
