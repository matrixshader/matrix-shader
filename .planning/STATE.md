# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-25)

**Core value:** The C# version must work exactly like the PowerShell version does today
**Current focus:** Phase 6 - Control Panel TUI

## Current Position

Phase: 6 of 10 (Control Panel TUI)
Plan: 4 of 4 in current phase
Status: Phase complete
Last activity: 2026-01-28 - Completed 06-04-PLAN.md (ControlPanel Integration)

Progress: [█████████████████░] 57% (17/30 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 17
- Average duration: 6 min
- Total execution time: 2.29 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-shader-service-foundation | 3 | 21 min | 7 min |
| 02-state-persistence | 2 | 11 min | 6 min |
| 03-windows-api-layer | 3 | 12 min | 4 min |
| 04-window-identity-service | 3 | 21 min | 7 min |
| 05-layout-service | 3 | 58 min | 19 min |
| 06-control-panel-tui | 3 | 14 min | 5 min |

**Recent Trend:**
- Last 5 plans: 05-02 (6 min), 05-03 (18 min), 06-02 (7 min), 06-03 (2 min), 06-04 (5 min)
- Trend: Stable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Phase order strict - Shader Control first, MatrixLite last (learned from previous failure)
- [Roadmap]: 10 phases for comprehensive depth, respecting research dependency chain
- [01-01]: PowerShell is source of truth for parameter validation ranges
- [01-01]: Clamp() returns new instance (immutable record pattern)
- [01-02]: HLSL file is source of truth for #define names (regex patterns must match exactly)
- [01-02]: Layer toggles parsed as float > 0.5 (not int comparison)
- [01-02]: InvariantCulture for float parsing (locale safety)
- [01-03]: F1 format (one decimal place) for shader values, matching PowerShell
- [01-03]: WriteConfig auto-creates missing files via CreateShader
- [01-03]: UTF8Encoding(false) for HLSL files (no BOM)
- [02-01]: UseStringEnumConverter in context for AOT-safe enum handling (not per-property JsonConverter)
- [02-01]: JsonSerializerIsReflectionEnabledByDefault=false for build-time AOT safety
- [02-01]: Dictionary<int, ShaderConfig> explicitly registered (required for nested collections)
- [02-02]: UTF8Encoding(false) for no BOM output, matching ShaderService pattern
- [02-02]: tempPath declared outside try block for cleanup scope in catch
- [02-02]: Temp file cleanup on save failure for robustness
- [03-01]: LibraryImport over DllImport for all new P/Invoke (AOT compatibility)
- [03-01]: Reuse existing RECT struct for DwmGetWindowAttribute out parameter
- [03-02]: GetAllWindows includes minimized windows for Matrix window tracking
- [03-02]: GetMonitors sorts primary first, then left-to-right to match PowerShell
- [03-02]: DWM-first pattern: Try DWM API, fall back to standard Windows API
- [03-03]: Border expansion outward (window rect = visible + margins) for pixel-perfect positioning
- [03-03]: SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW for z-order/focus preservation
- [04-01]: IdentitySource enum values 0-7 with confidence mapping via extension method
- [04-01]: WindowHandle stored as string in IdentityEntry (nint not JSON-friendly)
- [04-01]: Dictionary<string, IdentityEntry> for registry entries (matches PowerShell format)
- [04-02]: net8.0-windows TFM required for Windows Desktop framework reference (UI Automation)
- [04-02]: Batch WMI with OR joins for O(1) command line queries
- [04-02]: UI Automation Layer 4 order: TermControl (0.95) -> TabItem (0.85) -> Name (0.90)
- [04-02]: IsHandleValid = IsWindow AND IsWindowVisible (both required)
- [04-03]: Registry path uses LocalApplicationData (AppData\Local\MatrixShader)
- [04-03]: Atomic writes: temp file in same directory (.tmp) + File.Move
- [04-03]: CleanStaleEntries checks process existence, handle validity, and 24h age
- [04-03]: _recoveredKeys HashSet distinguishes fresh (1.0) from recovered (0.95) confidence
- [05-01]: UpdateConfig calls LoadState/SaveState immediately for real-time persistence
- [05-01]: AdjustGap clamps to 0-200 range matching PowerShell behavior
- [05-01]: CycleMode is pure function - caller must call UpdateConfig to persist
- [05-02]: ApplyLayout uses PositionWindowExact for pixel-perfect visible positioning
- [05-02]: Handle validation uses IsHandleValid (IsWindow AND IsWindowVisible)
- [05-03]: Dictionary keyed by "Matrix-N" format matches PowerShell naming convention
- [05-03]: Two-pass slot assignment: saved slots first, then fill remaining positions
- [05-03]: Immediate persistence via ConfigService.SaveState on any slot change
- [06-01]: Raw Console.Write with ANSI escape codes for pixel-perfect PowerShell matching
- [06-02]: Check uppercase KeyChar before ToLower for shift detection (matches PowerShell)
- [06-02]: net8.0-windows TFM for all CLI projects (Core compatibility)
- [06-03]: First open window takes priority over saved ActiveTab for initialization
- [06-03]: UpdateConfig writes to shader immediately (hot-reload), dirty flag for state persistence
- [06-04]: Remove Spectre.Console from Program.cs for pixel-perfect TUI matching
- [06-04]: Blocking Console.ReadKey (not polling with KeyAvailable) matches PowerShell behavior
- [06-04]: LayoutConfig.Mode is string (not enum) for JSON serialization

### Pending Todos

None yet.

### Blockers/Concerns

- Previous C# attempt failed by building MatrixLite before core shader control worked
- Must test in Windows Sandbox after each phase to catch missing dependencies early

## Session Continuity

Last session: 2026-01-28
Stopped at: Completed 06-04-PLAN.md (ControlPanel Integration) - Phase 6 Complete
Resume file: None

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-28*
