# Project Research Summary

**Project:** Matrix Terminal Shader - C# Port
**Domain:** Windows Terminal Shader Control Application (PowerShell to C# Migration)
**Researched:** 2026-01-25
**Confidence:** HIGH

## Executive Summary

This project ports an existing, working PowerShell-based Matrix Terminal shader controller to C# for improved performance, distribution, and platform integration. The PowerShell version successfully manages up to 6 Windows Terminal instances running GPU pixel shaders, with sophisticated window layout algorithms, multi-layer identity tracking, and a full-featured TUI control panel. A previous C# port attempt **failed catastrophically** by building a text-based "MatrixLite" fallback that became the only implementation while the core GPU shader functionality was never properly completed.

The recommended approach is a strict **1:1 feature parity port** in Phase 1 before any architectural improvements. Use .NET 8 LTS with Native AOT compilation, Spectre.Console for TUI output (supplemented with manual keyboard handling), LibraryImport for Windows API calls, and System.Text.Json with source generators. The existing PowerShell codebase provides complete reference implementations for all features - translation fidelity is more important than "clean architecture" initially.

Critical risks center on **scope creep disguised as better architecture** (build abstractions instead of porting functionality), **P/Invoke declaration mismatches** (calling conventions, struct layouts, pointer sizes), and **inadequate clean-environment testing** (works on dev machine, fails on fresh Windows install). Mitigation: enforce feature parity checklists, test in Windows Sandbox after every phase, port complex services (WindowIdentityService, WindowLayoutEngine) as complete units rather than piecemeal.

## Key Findings

### Recommended Stack

Modern C# terminal applications targeting Windows Terminal use .NET 8 LTS with Native AOT for instant startup and single-file deployment. The existing MatrixShader codebase already follows current best practices with LibraryImport for Windows API interop and proper dependency injection setup.

**Core technologies:**
- **.NET 8.0 LTS**: Runtime with Native AOT support - provides <500ms startup, single .exe deployment, supported until November 2026
- **Spectre.Console 0.54.0**: Rich console rendering - tables, colors, progress bars, fully AOT-compatible (core library only, NOT Spectre.Console.Cli)
- **ConsoleAppFramework 5.7.13**: CLI argument parsing - zero-reflection source-generated parser, 280x faster than System.CommandLine, fully AOT-compatible
- **LibraryImport (built-in .NET 7+)**: P/Invoke declarations - source-generated marshalling for Windows API calls, already in use in existing WindowsApi.cs
- **System.Text.Json (built-in)**: Config/state persistence - requires JsonSerializerContext for AOT compatibility

**What to avoid:**
- **Spectre.Console.Cli** - reflection-based, breaks Native AOT
- **System.CommandLine** - complex API, unclear AOT status
- **Newtonsoft.Json** - reflection-based, not AOT-compatible
- **DllImport** - runtime marshalling, replaced by LibraryImport

**Migration notes for existing codebase:**
- LibraryImport usage is already correct
- Add JsonSerializerContext for all serializable types (MatrixState, ShaderConfig, etc.)
- Consider ConsoleAppFramework for CLI argument parsing in entry points
- Current .NET 8 target is correct; upgrade to .NET 10 LTS when stable (November 2025)

### Expected Features

PowerShell version implements 88+ discrete features across shader control, window management, layout engine, identity tracking, state persistence, terminal integration, and error handling. C# port must achieve **complete feature parity** before adding differentiators.

**Must have (table stakes):**
- RGB color adjustment (Q/W/A/S/Z/X keys) with 6 color presets (1-6 keys)
- Speed, Glow, Width, Trail, Density parameter controls
- Layer toggles (Far/Mid/Near parallax depth)
- Tab switching between up to 6 open shader windows
- Dirty state tracking with auto-save on tab switch
- Pillars/Quads layout modes with Shift+L cycling
- Multi-monitor distribution with gap size configuration
- 4-layer window identity (Launch tracking -> Command line -> Title -> UI Automation)
- State persistence (matrix_state.json, identity-registry.json, window-registry.json)
- Atomic file writes (temp+move pattern) to prevent corruption
- Shader hot-reload via HLSL file regeneration with #define injection
- Windows Terminal profile creation (Matrix-1 through Matrix-8)
- Diagnostic logging with $env:MATRIX_DEBUG support
- Transparency toggle (B key) with opacity slider (K/L keys)

**Should have (competitive - C# can exceed PowerShell):**
- Native Windows API with no Add-Type compilation delay
- Faster startup (<500ms vs. PowerShell interpreter overhead)
- Single executable distribution (no script execution policy issues)
- Better UI Automation API access (direct API vs. assembly load)
- Proper async/await for background monitoring

**Defer (v2+):**
- MatrixLite text fallback (complex, not required for Windows Terminal users - CRITICAL: previous failure built this first)
- System tray integration (nice-to-have)
- Global hotkeys (RegisterHotKey P/Invoke, system-wide shortcuts)
- Plugin system (user-contributed shaders)
- Multi-language localization

### Architecture Approach

The current MatrixShader C# project structure correctly separates Core library (services, models, Windows API) from CLI applications (Redpill control panel, Bluepill quick launcher, WakeupNeo setup wizard). This architecture validates against industry patterns for .NET console apps with Windows interop.

**Major components:**
1. **MatrixShader.Core** — Shared library with IShaderService (HLSL file manipulation), IConfigService (JSON persistence), ILayoutService (window positioning algorithms), IIdentityService (4-layer window identity resolution), WindowsApi static class (P/Invoke declarations)
2. **MatrixShader.Cli.Redpill** — Full-featured control panel TUI with Spectre.Console rendering, keyboard input handling, tab management, parameter adjustment
3. **MatrixShader.Cli.Bluepill** — Quick launcher that loads saved state, launches terminals, applies layout, exits (minimal dependencies)
4. **MatrixShader.Cli.WakeupNeo** — First-time setup wizard with interactive configuration flow

**Key architectural patterns:**
- **Interface-based services** (IShaderService, ILayoutService) for dependency injection and testing
- **Record types for immutable models** (WindowInfo, MonitorInfo, ShaderConfig) with value semantics
- **Static P/Invoke wrapper class** (WindowsApi) centralizing all Windows API interop using LibraryImport
- **Thread-safe registry with locking** (IdentityService._lock) for concurrent access to mutable state
- **Atomic file writes** (write temp, move with overwrite) to prevent corruption
- **Service lifetimes** (Singleton for stateless services and registries in short-lived CLI apps)

**Build order (dependencies):**
1. MatrixShader.Core (Models → Constants → Native/WindowsApi → Services)
2. CLI Applications (all depend on Core)

**Existing implementations to port:**
- LayoutService (465 lines) - Pillars/Quads/Overlap layout calculations
- IdentityService (445 lines) - 4-layer window identity resolution
- WindowsApi (344 lines) - P/Invoke declarations for user32.dll

**To implement:**
- ShaderService - HLSL file read/write with #define injection
- ConfigService - Full JSON state persistence
- TerminalSettingsService - Windows Terminal settings.json manipulation
- Control panel TUI in Redpill
- Launch logic in Bluepill and WakeupNeo

### Critical Pitfalls

Previous C# attempt failed due to scope creep (building MatrixLite fallback before core shader control worked), clean environment testing neglect (works on dev machine, fails in Windows Sandbox), and context bloat (lost track of required features). These are the highest-priority issues to prevent.

1. **Scope Creep Disguised as Better Architecture** — Building "improved" abstractions and fallback modes instead of 1:1 porting. Previous attempt created sophisticated EnvironmentService.DetectRenderMode(), IShaderService interfaces, TextMatrixRenderer - but actual shader control never worked. **Prevention:** Phase 1 MUST be exact port, define "done" as feature parity not cleaner code, ban MatrixLite until Full mode works, test against working PowerShell version side-by-side.

2. **Not Testing in Clean Environment Early** — Testing only on dev machine where dependencies exist (Windows Terminal configured, Matrix profiles created). Previous attempt failed in Windows Sandbox even with MatrixLite. **Prevention:** Windows Sandbox test in Phase 1 before other development, use self-contained deployment from day 1 (`dotnet publish -c release -r win-x64 --self-contained`), document all installer prerequisites, test both fresh install and existing Matrix user upgrade scenarios.

3. **P/Invoke Declaration Mismatch** — PowerShell Add-Type is forgiving; C# P/Invoke has stricter marshalling requirements. Wrong calling conventions, incorrect struct layouts, or mismatched types cause silent failures. **Prevention:** Use PInvoke.net or dotnet/pinvoke library (don't hand-roll), test each P/Invoke individually before integrating, compare results to PowerShell version, be explicit about struct packing with `[StructLayout(LayoutKind.Sequential)]`, use `IntPtr`/`nint` for handles not `int`/`long`.

4. **Regex Pattern Differences** — PowerShell -match is case-insensitive by default; C# Regex.Match is case-sensitive. Causes shader parameter parsing failures. **Prevention:** Use `RegexOptions.IgnoreCase` explicitly, test regex patterns in isolation with known inputs, extract working patterns from PowerShell code, add unit tests for EVERY regex pattern.

5. **File Encoding and Line Ending Mismatch** — PowerShell files require CRLF line endings (per CLAUDE.md). C# `File.WriteAllText` defaults to platform default. Shader files may fail to compile or hot-reload stops working. **Prevention:** Explicit UTF-8 with BOM for settings.json, use `Environment.NewLine` or explicit `"\r\n"` for CRLF, atomic write pattern (already in PowerShell code), test write-then-read byte-for-byte comparison.

## Implications for Roadmap

Based on research, the previous failure mode and PowerShell architecture dependencies dictate a specific build order. Core functionality MUST work before any enhancements.

### Phase 1: Core Shader Control Port
**Rationale:** This is the heart of the application - GPU shader parameter manipulation via HLSL file regeneration. Previous attempt failed by skipping this. Must be first and must work before proceeding.

**Delivers:** ShaderService that reads/writes HLSL files with #define parameter injection, hot-reload timing that matches PowerShell's ~100ms latency, ConfigService for matrix_state.json persistence, atomic file writes.

**Addresses:**
- Table stakes: RGB color adjustment, color presets, Speed/Glow/Width/Trail/Density controls, layer toggles
- PITFALL 1: No abstractions or fallbacks allowed until this works
- PITFALL 5: Explicit CRLF encoding for HLSL files
- PITFALL 9: Hot-reload timing sensitivity testing

**Avoids:** Building MatrixLite, creating EnvironmentService mode detection, any TUI before shader control is verified

**Quality gates:**
- Side-by-side comparison with matrix_control.ps1 shader output
- Shader hot-reload persists changes within 500ms
- Windows Sandbox test with fresh .NET install
- NO MatrixLite code exists
- Regex unit tests for parameter parsing

### Phase 2: Window Management & Identity
**Rationale:** Window positioning and identity tracking are complex (1287 lines in PowerShell) and interdependent. Port as complete unit based on PITFALL 8 lessons.

**Delivers:** ILayoutService with Pillars/Quads algorithms, IIdentityService with 4-layer fallback (Launch tracking -> Command line -> Title -> UI Automation), multi-monitor detection, window enumeration/positioning P/Invoke.

**Uses:**
- LibraryImport for EnumWindows, SetWindowPos, GetWindowRect, EnumDisplayMonitors
- System.Management for WMI command line queries
- UI Automation API for profile detection fallback

**Implements:**
- LayoutService (port existing 465-line reference)
- IdentityService (port existing 445-line reference with 4-layer hierarchy)
- WindowsApi extensions for layout functions

**Addresses:**
- Table stakes: Tab switching, window launch, Pillars/Quads layouts, layout mode cycling, multi-monitor distribution, gap size configuration, 4-layer identity, position persistence
- PITFALL 3: P/Invoke testing for each Windows API function
- PITFALL 8: Port identity service as a unit, not piecemeal

**Quality gates:**
- Window detection matches PowerShell output exactly
- Window positioning pixel-accurate (test Windows 10/11 border handling)
- Identity service: 120ms performance budget for 6 windows
- Layout modes: Both Pillars and Quads verified
- Windows Sandbox: Multi-monitor simulation tests

### Phase 3: Control Panel TUI
**Rationale:** With shader control and window management working, build the interactive interface. Framework choice is critical per PITFALL 6.

**Delivers:** Full-featured Redpill control panel with keyboard input handling, live parameter updates, tab switching, dirty state tracking, auto-save on tab switch.

**Uses:**
- Spectre.Console for tables, colors, progress bars, color swatches
- Manual Console.ReadKey loop for keyboard input (Spectre is not a TUI framework)
- Consider Terminal.Gui if Spectre limitations become blocking

**Addresses:**
- Table stakes: TUI control panel, color swatches, progress bars, setup wizard, Blue Pill path, Red Pill path, restore previous session
- PITFALL 6: TUI framework evaluation spike BEFORE implementation
- PITFALL 10: Console input handling platform differences
- PITFALL 11: Color code translation (use TrueColor ANSI)

**Quality gates:**
- All keyboard shortcuts from PowerShell version work
- UI refresh doesn't flicker
- Tab switching preserves dirty state
- Exit saves state correctly
- Shift+Key combinations handle properly

### Phase 4: Terminal Integration & Polish
**Rationale:** Windows Terminal settings.json manipulation, profile creation/sync, final error handling, diagnostic logging.

**Delivers:** TerminalSettingsService for settings.json read/write, profile creation (Matrix-1 through Matrix-8), tab color sync, transparency toggle, diagnostic logging.

**Addresses:**
- Table stakes: Profile creation, shader path configuration, tab color sync, background transparency, opacity slider, JSON parse error handling, settings.json lock handling, shader validation, diagnostic logging
- PITFALL 7: Settings.json race conditions (retry logic, minimal write window)
- PITFALL 12: Path handling across environments (OneDrive redirection)

**Quality gates:**
- Profile changes apply without corruption
- Changes work with Windows Terminal actively running
- Works with OneDrive Documents folder redirection
- $env:MATRIX_DEBUG logging equivalent works
- Feature parity checklist: ALL items checked

### Phase Ordering Rationale

- **Phase 1 before everything:** Core functionality must work before building on it (previous failure lesson)
- **Phase 2 follows Phase 1:** Can't test window management without working shaders in those windows
- **Phase 3 follows Phase 2:** TUI is pointless without underlying services to control
- **Phase 4 is integration:** Brings all pieces together with Terminal-specific features

**Dependency chain:**
```
Phase 1 (Shader Control)
  ↓ Shaders must work to verify window management
Phase 2 (Window Management)
  ↓ Windows must be managed to build TUI controls
Phase 3 (Control Panel)
  ↓ All services integrated before Terminal-specific features
Phase 4 (Terminal Integration)
```

**Anti-pattern to avoid:** Building phases in parallel or reversing order leads to the previous failure mode (built MatrixLite and architecture before core shader control).

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 3 (Control Panel):** TUI framework choice requires spike - evaluate Spectre.Console keyboard limitations vs. Terminal.Gui learning curve
- **Phase 4 (Terminal Integration):** Windows Terminal settings.json schema may have changed since PowerShell implementation; verify current schema

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Shader Control):** File I/O and regex patterns are well-documented, PowerShell code provides complete reference
- **Phase 2 (Window Management):** P/Invoke declarations have canonical sources (PInvoke.net, Microsoft docs), existing C# implementations provide reference

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified via NuGet/official sources, existing codebase already uses recommended approaches |
| Features | HIGH | Complete PowerShell reference implementation with 88+ features cataloged, previous failure mode documented |
| Architecture | HIGH | Existing C# codebase structure validates against industry patterns, reference implementations for major services |
| Pitfalls | HIGH | Previous failure provides concrete lessons, PowerShell hardening sprint (US-001 through US-010) documents proven patterns |

**Overall confidence:** HIGH

### Gaps to Address

- **TUI Framework Decision:** Spectre.Console vs. Terminal.Gui requires implementation spike in Phase 3. Spectre is not a full TUI framework (keyboard handling is manual), Terminal.Gui may be overkill. Need hands-on evaluation with keyboard input patterns.

- **Windows Terminal Settings.json Schema:** PowerShell code targets specific schema version. Verify current Windows Terminal version's schema hasn't changed field names or structure for `experimental.pixelShaderPath`, tab colors, opacity.

- **UI Automation API Performance:** 4th-layer fallback in identity service uses UI Automation. C# direct API access should be faster than PowerShell, but need to verify performance budget (120ms for 6 windows total) still holds.

- **Native AOT Compatibility Validation:** While all recommended stack components claim AOT support, final binary must be tested in clean environment with `PublishAot=true` to catch any trim warnings or runtime reflection errors.

**Mitigation during planning:**
- TUI framework: Allocate spike story in Phase 3 before full implementation
- Settings.json: Verify schema in Phase 4 pre-planning (read current WT settings.json)
- UI Automation: Profile performance during Phase 2 implementation, have fallback to simpler detection
- AOT validation: Add to every phase's quality gate (publish and test in Sandbox)

## Sources

### Primary (HIGH confidence)
- Microsoft .NET Support Policy - Runtime versions and LTS support windows
- Native AOT Deployment Overview - PublishAot configuration and compatibility
- Platform Invoke (P/Invoke) - LibraryImport source generation documentation
- Spectre.Console NuGet (v0.54.0) - Latest version and AOT compatibility status
- ConsoleAppFramework NuGet (v5.7.13) - Latest version and zero-reflection claims
- Microsoft CsWin32 GitHub - P/Invoke source generator as alternative
- Existing MatrixShader codebase: LayoutService.cs (465 lines), IdentityService.cs (445 lines), WindowsApi.cs (344 lines) - Reference implementations
- PowerShell codebase: matrix_control.ps1, WindowLayoutEngine.ps1, WindowIdentityService.ps1, MatrixUtils.ps1 - Complete feature reference

### Secondary (MEDIUM confidence)
- ConsoleAppFramework v5 Announcement - 280x performance claim vs. System.CommandLine
- Spectre.Console AOT Issue #1332 - Community confirmation of core library AOT support
- Terminal.Gui v2 What's New - Alpha status and feature comparison
- PInvoke.net: SetWindowPos - Community P/Invoke declarations
- Windows Terminal Pixel Shader Issues #9338 - Hot-reload behavior discussion

### Tertiary (LOW confidence - needs validation)
- Hot-reload timing (~100ms per CLAUDE.md) - Undocumented Windows Terminal internal polling, needs empirical testing
- Windows 10/11 border handling (7px offset) - Mentioned in pitfalls, needs verification in current OS versions

---
*Research completed: 2026-01-25*
*Ready for roadmap: yes*
