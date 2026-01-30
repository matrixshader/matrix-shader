# Matrix Terminal Shader - C#/.NET Rebuild

## What This Is

A native C#/.NET implementation of Matrix Terminal Shader - a real-time controllable Matrix rain effect for Windows Terminal. Features GPU pixel shaders with hot-reload, multi-window management with automatic layout positioning, and MatrixLite text-based fallback for non-Windows-Terminal environments.

## Core Value

**Instant startup with full PowerShell feature parity.** GPU shaders in Windows Terminal, multi-window management, real-time parameter control - all launching in under 2 seconds (vs 60+ seconds for PowerShell).

## Current State (v1.0 Shipped)

**Shipped:** 2026-01-30

**Tech stack:** C# 12 / .NET 8 / Native AOT
**Codebase:** 9,047 lines of C#
**Executables:** 4 Native AOT single-file binaries (redpill, bluepill, wakeupneo, matrixlite)

**What works:**
- ShaderService with #define injection and Windows Terminal hot-reload
- ConfigService with atomic JSON persistence (matrix_state.json)
- IdentityService with 4-layer identity resolution (confidence scoring)
- LayoutService with Pillars/Quads/Overlap/Auto modes and multi-monitor support
- Control panel TUI matching PowerShell (40+ keyboard shortcuts)
- CLI applications: redpill, bluepill, wakeupneo, matrixlite
- MatrixLite text-based fallback for non-WT terminals
- Installer with PATH integration

## Requirements

### Validated (v1.0)

**Shader Control:**
- ✓ RGB color adjustment (0.0-1.0 range) — v1.0
- ✓ 6 color presets (Green, Cyan, Red, Purple, Gold, Teal) — v1.0
- ✓ Animation speed, glow, width, trail, density controls — v1.0
- ✓ 3 parallax layer toggles — v1.0
- ✓ #define injection with hot-reload — v1.0

**Window Management:**
- ✓ Windows Terminal window detection — v1.0
- ✓ 4-layer identity resolution with confidence scoring — v1.0
- ✓ Up to 8 shader windows via tabbed interface — v1.0
- ✓ Pillars/Quads/Auto layout modes — v1.0
- ✓ Configurable gap size — v1.0
- ✓ Multi-monitor support — v1.0
- ✓ Window-to-shader mapping persistence — v1.0

**CLI Applications:**
- ✓ redpill.exe control panel TUI — v1.0
- ✓ bluepill.exe session restore — v1.0
- ✓ wakeupneo.exe setup wizard — v1.0
- ✓ Native AOT single-file executables — v1.0
- ✓ Startup time ~1000ms cold (acceptable) — v1.0

**State Persistence:**
- ✓ JSON shader configuration — v1.0
- ✓ Window registry persistence — v1.0
- ✓ Identity registry persistence — v1.0
- ✓ Layout preferences persistence — v1.0
- ✓ Atomic file writes — v1.0

**Terminal Integration:**
- ✓ Windows Terminal settings.json read/write — v1.0
- ✓ Matrix-1 through Matrix-8 profile creation — v1.0
- ✓ Pixel shader path auto-update — v1.0
- ✓ MATRIX_DEBUG=1 diagnostic logging — v1.0

**User Experience:**
- ✓ Color swatches in TUI — v1.0
- ✓ Blue Pill / Red Pill setup paths — v1.0
- ✓ PowerShell-matching keyboard shortcuts — v1.0
- ✓ Dirty state indicator — v1.0
- ✓ Auto-save on tab switch — v1.0

**MatrixLite Fallback:**
- ✓ Text-based Matrix rain in non-WT terminals — v1.0
- ✓ Movie-accurate Katakana character set — v1.0
- ✓ 6 color presets via ANSI codes — v1.0
- ✓ Graceful degradation — v1.0

### Active

(No active requirements - v1.0 complete, awaiting next milestone planning)

### Out of Scope

- GUI application — Terminal-native experience is core identity
- Cross-platform GPU shaders — Windows Terminal specific
- Cloud sync — Unnecessary complexity
- Telemetry — Privacy concerns
- New shader effects — Feature parity achieved, evaluate for v2.0

## Context

**Reference implementation:** PowerShell scripts in this repo:
- `matrix_control.ps1` (1,200 lines) - Control panel TUI
- `WindowLayoutEngine.ps1` (3,894 lines) - Window positioning
- `WindowIdentityService.ps1` (1,281 lines) - Window tracking
- `shaders/*.hlsl` - GPU shaders (unchanged)

**Previous failure:** First C# attempt only implemented MatrixLite, didn't work anywhere. v1.0 success came from porting core shader control first.

## Constraints

- **Tech stack**: C# 12 / .NET 8 / Native AOT
- **Reference**: PowerShell version is the spec
- **Testing**: Windows Sandbox for clean environment validation
- **Workflow**: GSD subagents for implementation to prevent context bloat

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Port core functionality before MatrixLite | PowerShell works, MatrixLite-only failed | ✓ Success |
| Use GSD subagents consistently | Context bloat caused previous failure | ✓ Effective |
| Test in Windows Sandbox | Fresh environment catches missing deps | ✓ Validated |
| Native AOT compilation | Instant startup, no runtime required | ✓ ~1000ms cold |
| LibraryImport for P/Invoke | AOT compatibility | ✓ All 20 declarations |
| Source-generated JSON | AOT-safe serialization | ✓ 19 types registered |
| 4-layer identity resolution | Match PowerShell confidence scoring | ✓ Implemented |
| Decimal phase numbering (08.1) | Clear insertion semantics for urgent work | ✓ Used once |

---
*Last updated: 2026-01-30 after v1.0 milestone*
