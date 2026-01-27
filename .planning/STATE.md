# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-25)

**Core value:** The C# version must work exactly like the PowerShell version does today
**Current focus:** Phase 3 - Windows API Layer

## Current Position

Phase: 3 of 10 (Windows API Layer)
Plan: 1 of 4 in current phase
Status: In progress
Last activity: 2026-01-26 — Completed 03-01-PLAN.md

Progress: [██████░░░░] 20% (6/30 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 6 min
- Total execution time: 0.57 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-shader-service-foundation | 3 | 21 min | 7 min |
| 02-state-persistence | 2 | 11 min | 6 min |
| 03-windows-api-layer | 1 | 4 min | 4 min |

**Recent Trend:**
- Last 5 plans: 01-03 (8 min), 02-01 (6 min), 02-02 (5 min), 03-01 (4 min)
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

### Pending Todos

None yet.

### Blockers/Concerns

- Previous C# attempt failed by building MatrixLite before core shader control worked
- Must test in Windows Sandbox after each phase to catch missing dependencies early

## Session Continuity

Last session: 2026-01-26
Stopped at: Completed 03-01-PLAN.md
Resume file: None

---
*State initialized: 2026-01-25*
*Last updated: 2026-01-26*
