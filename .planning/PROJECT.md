# Matrix Terminal Shader - C#/.NET Rebuild

## What This Is

A complete rebuild of Matrix Terminal Shader from PowerShell to native C#/.NET. The PowerShell version (6,800+ lines) works perfectly - GPU shaders, window controls, monitoring, everything. The C# version must replicate this functionality with near-instant startup (<500ms vs 60+ seconds), then add MatrixLite text fallback for non-Windows-Terminal environments.

## Core Value

**The C# version must work exactly like the PowerShell version does today.** GPU shaders in Windows Terminal, multi-window management, real-time parameter control. MatrixLite is secondary - get the core working first.

## Requirements

### Validated

- ✓ LayoutService implemented (465 lines) — Pillars/Quads/Overlap from WindowLayoutEngine.ps1
- ✓ IdentityService implemented (445 lines) — 4-layer resolution from WindowIdentityService.ps1
- ✓ WindowsApi P/Invoke declarations (344 lines) — EnumWindows, SetWindowPos, GetMonitorInfo
- ✓ Models defined — WindowInfo, MonitorInfo, ShaderConfig, LayoutConfig
- ✓ Codebase mapped (7 documents, 1588 lines)

### Active

- [ ] ShaderService - HLSL file manipulation with #define injection and hot-reload
- [ ] ConfigService - JSON state persistence (matrix_state.json, registries)
- [ ] redpill.exe - Control panel TUI (replicate matrix_control.ps1)
- [ ] bluepill.exe - Quick launcher (replicate bluepill.ps1)
- [ ] wakeupneo.exe - Setup wizard (replicate matrix_setup.ps1)
- [ ] MatrixLite - Text-based fallback renderer for non-WT terminals
- [ ] Native AOT compilation - Single-file executables, no runtime

### Out of Scope

- Rewriting HLSL shaders — they work perfectly, just need C# to manipulate them
- New features beyond PowerShell parity — get it working first
- Cross-platform GPU shaders — Windows Terminal specific

## Context

**Working reference:** The PowerShell scripts in this repo work perfectly:
- `matrix_control.ps1` (1,200 lines) - Control panel TUI
- `WindowLayoutEngine.ps1` (3,894 lines) - Window positioning
- `WindowIdentityService.ps1` (1,281 lines) - Window tracking
- `shaders/*.hlsl` - GPU shaders (keep as-is)

**Previous C# attempt failed:** Only implemented MatrixLite, didn't work in any terminal including Windows Sandbox fresh install. Must test incrementally this time.

**Critical insight:** Context bloat during implementation causes lost details. Use GSD subagents to keep context fresh and delegate properly.

## Constraints

- **Tech stack**: C# 12 / .NET 8 / Native AOT — for instant startup
- **Reference**: PowerShell version is the spec — if it works there, C# must match
- **Testing**: Windows Sandbox for clean environment testing
- **Workflow**: GSD subagents for implementation — don't bloat orchestrator context

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Port core functionality before MatrixLite | PowerShell works, MatrixLite-only failed | — Pending |
| Use GSD subagents consistently | Context bloat caused previous failure | — Pending |
| Test in Windows Sandbox | Fresh environment catches missing deps | — Pending |
| Native AOT compilation | Instant startup, no runtime required | — Pending |

---
*Last updated: 2026-01-25 after initialization*
