# PRD: Matrix Control Panel Reliability Hardening

## Introduction

The Matrix Control Panel (`matrix_control.ps1`) is a PowerShell TUI for controlling Matrix rain shader effects in Windows Terminal. A code review identified several critical reliability issues that could cause data loss, crashes, or incorrect behavior. This PRD addresses those issues to prepare the tool for potential public release.

## Goals

- Prevent settings.json data loss from unsafe file operations
- Eliminate crashes from malformed or locked JSON files
- Ensure shader values are always valid (no parsing garbage)
- Implement robust window detection by title/PID correlation
- Replace timing-based waits with active polling
- Auto-save shader changes on tab switch to prevent lost work
- Remove dead code and add diagnostic logging
- Achieve production-quality reliability for public release

## User Stories

### US-001: Safe Atomic File Write
**Description:** As a user, I want settings.json writes to be truly atomic so that my Windows Terminal settings are never lost or corrupted.

**Acceptance Criteria:**
- [ ] Replace delete+rename pattern with `Move-Item -Force` or equivalent
- [ ] If move fails, original file remains intact
- [ ] Add try-catch with user-friendly error message on failure
- [ ] Test by simulating write during file lock (open settings.json in notepad)
- [ ] Settings survive interrupted write operations

---

### US-002: JSON Error Handling
**Description:** As a user, I want the control panel to handle corrupted or locked settings gracefully so that it doesn't crash unexpectedly.

**Acceptance Criteria:**
- [ ] Wrap all `ConvertFrom-Json` calls in try-catch
- [ ] Wrap all file read/write operations in try-catch
- [ ] Display clear error message when settings.json is malformed
- [ ] Display clear error message when settings.json is locked by another process
- [ ] Offer retry option for locked file scenarios
- [ ] Script continues running (degraded mode) rather than crashing

---

### US-003: Shader Value Validation
**Description:** As a user, I want shader parameter parsing to reject invalid values so that shaders always compile correctly.

**Acceptance Criteria:**
- [ ] Regex pattern rejects multiple decimal points (e.g., "1.2.3")
- [ ] Regex pattern only matches valid float format: `\d+\.?\d*`
- [ ] Invalid values fall back to defaults with warning message
- [ ] Add validation before writing shader (reject NaN, Infinity, negative where inappropriate)
- [ ] Test with manually corrupted shader file

---

### US-004: Robust Window Detection
**Description:** As a user, I want window detection to accurately identify Matrix windows so that launching and positioning work correctly.

**Acceptance Criteria:**
- [ ] Match windows by exact title pattern "Matrix-N" where N is digit
- [ ] Correlate window handles with Windows Terminal process specifically
- [ ] Ignore non-Windows Terminal processes with similar titles
- [ ] Return accurate list of open slot numbers
- [ ] Handle edge case: window title changed by user
- [ ] Add logging of detected windows for debugging

---

### US-005: Robust Window Positioning
**Description:** As a user, I want window positioning to work reliably regardless of handle values so that windows are always arranged correctly.

**Acceptance Criteria:**
- [ ] Match handles to specific Matrix-N windows by title, not handle sort order
- [ ] Position windows in slot order (Matrix-1 leftmost, Matrix-2 next, etc.)
- [ ] Handle case where some slots are missing (e.g., only Matrix-1 and Matrix-3 open)
- [ ] Log positioning actions for debugging
- [ ] Test with windows opened in non-sequential order

---

### US-006: Poll-Based Window Launch
**Description:** As a user, I want window launching to be responsive and reliable so that I don't wait unnecessarily or have positioning fail.

**Acceptance Criteria:**
- [ ] Replace fixed 1500ms sleep with active polling for window existence
- [ ] Poll every 100ms, timeout after 5 seconds
- [ ] Proceed immediately when window is detected
- [ ] Show error message if window doesn't appear within timeout
- [ ] Display progress indicator during launch ("Waiting for Matrix-N...")
- [ ] Total launch time reduced by ~50% in typical cases

---

### US-007: Auto-Save on Tab Switch
**Description:** As a user, I want my shader changes automatically saved when switching tabs so that I never lose work.

**Acceptance Criteria:**
- [ ] Detect dirty state before tab switch
- [ ] Auto-save current shader if dirty before loading new tab
- [ ] Display brief "Auto-saved" confirmation message
- [ ] Clear dirty flag after auto-save
- [ ] No user action required to preserve changes

---

### US-008: Remove Dead Code
**Description:** As a developer, I want dead code removed so that the codebase is clean and maintainable.

**Acceptance Criteria:**
- [ ] Remove space key (VK 32) handler (transparency already auto-saves)
- [ ] Remove any other unreachable or unused code paths
- [ ] Verify no functionality is lost after removal
- [ ] Update comments to reflect current behavior

---

### US-009: Add Diagnostic Logging
**Description:** As a developer, I want diagnostic logging so that issues can be debugged when users report problems.

**Acceptance Criteria:**
- [ ] Add `$VerbosePreference` support for optional verbose output
- [ ] Log key operations: file saves, window detection, launches, positioning
- [ ] Log errors with context (what operation failed, what values were involved)
- [ ] Logs written to `$matrixDir\debug.log` when verbose mode enabled
- [ ] Add `-Verbose` parameter or environment variable to enable
- [ ] Logs don't appear in normal operation (clean UI preserved)

---

### US-010: Consolidate Key Handlers
**Description:** As a developer, I want duplicate key handlers consolidated so that code is DRY and maintainable.

**Acceptance Criteria:**
- [ ] Create helper function for case-insensitive key handling
- [ ] Replace duplicate uppercase/lowercase switch cases
- [ ] Reduce total lines of key handling code by ~30%
- [ ] All existing keyboard controls still work identically

---

## Functional Requirements

- FR-1: File writes must use atomic move operation, not delete+rename
- FR-2: All JSON parsing must be wrapped in try-catch with recovery
- FR-3: Shader value regex must enforce valid float format only
- FR-4: Window detection must correlate handles with process name AND window title
- FR-5: Window positioning must match by title content, not handle ordering
- FR-6: Window launch must poll for existence with configurable timeout
- FR-7: Tab switch must trigger auto-save when dirty flag is set
- FR-8: Verbose logging must be available but disabled by default
- FR-9: All error messages must be user-friendly (no raw exceptions)

## Non-Goals

- No new features (this is hardening only)
- No UI redesign or layout changes
- No configuration file system (keep defaults in code for now)
- No undo/redo system
- No copy/paste between tabs
- No real-time shader preview (still requires manual reload)

## Technical Considerations

- PowerShell 5.1 compatibility required (Windows built-in)
- Must work with Windows Terminal stable release
- P/Invoke for window positioning already in place - extend, don't replace
- Consider `[System.IO.File]::Move()` for atomic operations
- Logging should use `Write-Verbose` for PowerShell convention

## Success Metrics

- Zero data loss scenarios (settings.json always recoverable)
- Zero unhandled crashes from JSON/file operations
- Window positioning accuracy: 100% correct order in all test scenarios
- Launch time reduced by 40-60% with polling vs fixed delay
- No user-reported "lost changes" after tab switching

## Open Questions

- Should verbose logging also capture to Windows Event Log for enterprise scenarios?
- Should we add a "safe mode" that skips settings.json writes entirely?
- Consider adding version number to script for issue reporting?

## Implementation Order

Recommended sequence based on risk and dependencies:

1. **US-001** (Atomic write) - Highest risk, fix first
2. **US-002** (JSON handling) - Crash prevention
3. **US-003** (Value validation) - Shader reliability
4. **US-007** (Auto-save) - Quick win, improves UX
5. **US-008** (Dead code) - Quick cleanup
6. **US-004** (Window detection) - Foundation for US-005, US-006
7. **US-005** (Window positioning) - Depends on US-004
8. **US-006** (Poll-based launch) - Depends on US-004
9. **US-009** (Logging) - Helps debug remaining issues
10. **US-010** (Consolidate handlers) - Final polish
