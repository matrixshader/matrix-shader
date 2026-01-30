# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-25)

**Core value:** The C# version must work exactly like the PowerShell version does today
**Current focus:** Phase 9 Native AOT & Polish - IN PROGRESS

## Current Position

Phase: 9 of 10 (Native AOT & Polish)
Plan: 2 of 4 in current phase
Status: In progress
Last activity: 2026-01-29 - Completed 09-02-PLAN.md (Startup Splash & Error Handler)

Progress: [##############################] 100% (32/32 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 25
- Average duration: 6 min
- Total execution time: 3.1 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-shader-service-foundation | 3 | 21 min | 7 min |
| 02-state-persistence | 2 | 11 min | 6 min |
| 03-windows-api-layer | 3 | 12 min | 4 min |
| 04-window-identity-service | 3 | 21 min | 7 min |
| 05-layout-service | 3 | 58 min | 19 min |
| 06-control-panel-tui | 4 | 16 min | 4 min |
| 07-terminal-integration | 4 | 22 min | 6 min |
| 08-cli-applications | 3 | 22 min | 7 min |

**Recent Trend:**
- Last 5 plans: 07-03 (9 min), 07-04 (3 min), 08-01 (5 min), 08-02 (5 min), 08-03 (12 min)
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
- [07-01]: Record type for TerminalProfile (immutable, pattern matching)
- [07-01]: Class type for TerminalSettings/ProfilesContainer (mutated during updates)
- [07-01]: JsonExtensionData preserves unknown settings.json properties during round-trip
- [07-01]: JsonPropertyName handles dotted 'experimental.pixelShaderPath' property
- [07-02]: Regex-based profile extraction for malformed JSON recovery
- [07-02]: UpsertProfile inserts at beginning so Matrix profiles appear at top
- [07-02]: Backup path uses .matrix-backup suffix for easy identification
- [07-03]: Static class for DiagnosticLogger (no DI needed, matches PowerShell pattern)
- [07-03]: Parallel channel to ILogger (DiagnosticLogger for MATRIX_DEBUG=1 user output)
- [07-03]: Thread-safe file writes with lock object
- [07-03]: Silent error handling matches PowerShell -ErrorAction SilentlyContinue
- [07-04]: Profile GUID format with braces matching PowerShell: {guid}
- [07-04]: hidden=true, opacity=95 for profile defaults matching install.ps1
- [07-04]: Regex pattern ^Matrix-\d+$ for Matrix-N profile detection
- [07-04]: CreateMatrixProfiles skips existing profiles (idempotent operation)
- [08-01]: DiagnosticLogger.Initialize() over non-existent Enable() (API correction)
- [08-01]: LibraryImport for P/Invoke declarations (AOT compatibility)
- [08-01]: Static class for CliBootstrap (no DI, matches DiagnosticLogger pattern)
- [08-02]: Use nint instead of IntPtr for window handles (consistent with Core library)
- [08-02]: RegisterWindowHandle signature matches interface (nint, string, int)
- [08-02]: MatrixState.Layout property (not LayoutConfig) per model definition
- [08-02]: ShaderService.CreateShader requires ShaderConfig parameter
- [08-03]: Remove Spectre.Console per CONTEXT.md (no third-party TUI libraries)
- [08-03]: ANSI 24-bit color swatches for color preview in wizard
- [08-03]: GetActiveSlots filters to non-default configs for restore detection
- [08.1-02]: async Task.Run().Wait() for Launch matches blocking TUI while allowing async detection
- [08.1-02]: SnapbackSave uses CalculateLayout first for position consistency
- [08.1-02]: PrimaryWindowCount 0 = auto (follows PowerShell convention)
- [08.1-04]: Keep DllImport for GetMonitorInfo (MONITORINFOEX struct with fixed char array unsupported by LibraryImport)
- [08.1-04]: Use unsafe fixed char buffer in MONITORINFOEX with GetDeviceName() helper
- [08.1-01]: Remove Spectre.Console globally - all TUI uses native Console.Write with ANSI codes
- [08.1-03]: ApplyOpacityToProfile applies opacity to Windows Terminal settings.json on B/K/L keys
- [08.1-03]: SyncTabColorToShader converts float RGB (0-1) to hex #RRGGBB on save
- [08.1-05]: GetActiveSlots uses ShaderExists not color comparison (matches Bluepill)
- [08.1-05]: No hardcoded user-specific paths in ShaderService
- [08.1-05]: Monitor starts silently from Bluepill (optional enhancement)
- [09-02]: Use Stopwatch.GetTimestamp/GetElapsedTime for timing (monotonic, high-resolution)
- [09-02]: Avoid ref in async methods (C# 12 limitation)
- [09-02]: ASCII art sized for standard terminal width (~60 chars)

### Pending Todos

None yet.

### Blockers/Concerns

- Previous C# attempt failed by building MatrixLite before core shader control worked
- Must test in Windows Sandbox after each phase to catch missing dependencies early

## Session Continuity

Last session: 2026-01-29
Stopped at: Completed 09-02-PLAN.md (Startup Splash & Error Handler)
Resume file: None
Next action: Execute 09-03-PLAN.md (CLI Integration)

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-29*
