# MatrixShader v1.0.3 Update

## What This Is

A v1.0.3 increment to the shipped MatrixShader product — adding global transparency controls, the `construct` white room experience, shipping MatrixCodeVision as the Redpill shader, and UX polish across all CLI tools. Not a major version bump — these are features and fixes that improve the existing product.

## Core Value

**Every Matrix window behaves as part of one unified system.** Transparency, colors, and settings feel coordinated — not like 8 separate windows the user has to manage individually.

## Requirements

### Validated (existing, shipped in v1.0.0-v1.0.2)

- ✓ GPU shader hot-reload via #define injection — existing
- ✓ 6 color presets (Green, Blue, Red, Purple, Gold, Teal) — existing
- ✓ Up to 8 shader windows with profile management — existing
- ✓ Redpill TUI control panel with 40+ keyboard shortcuts — existing
- ✓ Global hotkeys (Ctrl+Shift combos) — existing
- ✓ Per-profile opacity setting (85% default) — existing
- ✓ `construct` CLI for quick-launch with --color flags — existing (this session)
- ✓ Command reference banner on all CLI exits — existing (this session)

### Active

- [ ] Global transparency: all Matrix windows share one transparency setting by default
- [ ] Transparency toggle cycle: 0% → 100% → Custom (via hotkey and redpill)
- [ ] Custom transparency: increment/decrement by 5% steps
- [ ] Redpill can disable global linking (per-window mode)
- [ ] Construct white room: `construct` (no args) opens white shader with color picker
- [ ] White room transition: picking a color transitions the shader to Matrix rain in that color
- [ ] MatrixCodeVision shader included in release build as Redpill background
- [ ] Wakeupneo: consistent arrow-key menus (replace Y/N session restore prompt)
- [ ] Wakeupneo: move licensing info before setup, not after

### Out of Scope

- New color presets — 6 is enough for this increment
- Bonus shader gallery page on website — separate workstream
- Cross-platform (Ghostty/Linux) — separate milestone
- Community shader marketplace — future
- New shader effects beyond Construct white room — v2+

## Context

**Existing codebase:** 9,047+ lines of C# across 9 projects. Full codebase map at `.planning-v1/codebase/`.

**Transparency today:** Per-profile opacity in Windows Terminal settings.json. `UseAcrylic = false` (plain transparency, no blur). Hotkeys `Ctrl+Shift+B` toggles, `Ctrl+Shift+K/O` adjusts. But each window is independent — no global coordination.

**Construct today:** `construct.exe` launches a Matrix window with a color flag. No-args defaults to green. The white room experience (HLSL shader with interactive picker) is new.

**MatrixCodeVision:** Already wired in `TerminalSettingsService.cs:304` but hasn't been in a shipped release yet. The .hlsl file is committed to git.

**Key services:**
- `ShaderService` — writes #define values to HLSL files, WT hot-reloads
- `ConfigService` — JSON state persistence (matrix_state.json)
- `TerminalSettingsService` — reads/writes WT settings.json, creates profiles
- `CliBootstrap` — finds wt.exe, shaders dir, shared startup

## Constraints

- **Tech stack**: C# 12 / .NET 8 / Native AOT (existing)
- **Shader language**: HLSL for Windows Terminal pixel shaders
- **WT limitation**: Cannot programmatically change profile opacity at runtime — must write settings.json and WT hot-reloads
- **No new dependencies**: Keep the dependency footprint minimal

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Global transparency by default | Matches Linux/Mac versions, users expect unified behavior | — Pending |
| 0%/100%/Custom toggle cycle | Simple mental model, covers 90% of use cases | — Pending |
| 5% step increments | Fine enough for tuning, coarse enough to not be tedious | — Pending |
| White room as HLSL shader | WT hot-reload enables the transition effect without restarting | — Pending |
| MatrixCodeVision replaces Redpill-Neo | Better text readability, more visually impressive | ✓ Already wired |
| construct requires --flag syntax | User's explicit preference, keeps CLI clean | ✓ Done |

---
*Last updated: 2026-03-06 after initialization*
