# Codebase Structure

**Analysis Date:** 2026-01-25

## Directory Layout

```
C:\Users\ehome\Documents\Matrix/
├── .claude/                    # Claude Code settings
├── .git/                       # Git repository
├── .planning/                  # GSD orchestrator planning documents
│   └── codebase/              # Architecture/structure/testing docs
├── BACKGROUND IMAGES/          # Wallpaper resources
├── bin/                        # Compiled binaries and NPM entry points
│   ├── native/                # Native C# executables (redpill.exe)
│   └── redpill.js             # NPM script wrapper (Node.js entry point)
├── config/                     # Configuration templates (unused in current flow)
├── MatrixShader/              # C# Matrix API DLL compilation source
├── MVP/                        # Legacy single-instance shader (archive)
├── NOTES/                      # Development notes and checklists
├── PRD/                        # Product requirements and user stories
├── RECOVERY/                   # Agent recovery logs and phase documentation
├── shaders/                    # HLSL pixel shader implementations
│   ├── Matrix-1.hlsl          # Shader instance 1 (auto-generated at runtime)
│   ├── Matrix-2.hlsl          # Shader instance 2
│   ├── Matrix-3.hlsl          # Shader instance 3
│   ├── Matrix-4.hlsl          # Shader instance 4
│   ├── Matrix-5.hlsl          # Shader instance 5
│   ├── Matrix-6.hlsl          # Shader instance 6
│   ├── Matrix-7.hlsl          # Shader instance 7
│   ├── Matrix-8.hlsl          # Shader instance 8
│   └── Redpill-Neo.hlsl       # Custom 3D corridor shader (Neo vision)
├── STRATEGY/                   # Strategic planning and growth documents
├── tasks/                      # Ralph-compatible PRD and task tracking
├── TEAM_MEETING/              # Meeting notes and synthesis documents
├── Website/                    # Documentation and web assets
├── bluepill.ps1               # Quick launch script (restore previous session)
├── matrix_control.ps1         # Main control panel (TUI for shader parameters)
├── matrix_setup.ps1           # Setup wizard (interactive configuration)
├── MatrixLogging.ps1          # Unified diagnostic logging module
├── MatrixUtils.ps1            # Shared utilities (color swatches, screen dimensions)
├── WindowIdentityService.ps1  # Window detection and identity resolution
├── WindowLayoutEngine.ps1     # Multi-window layout and positioning engine
├── install.ps1                # Installation script
├── prd.json                   # Ralph-compatible product requirements (current hardening sprint)
├── matrix_state.json          # User state persistence (layout mode, window slots, gap size)
├── window-registry.json       # Window handle -> shader file mapping
├── identity-registry.json     # Profile name -> window identity mapping (persistent)
├── Compile-MatrixAPI.ps1      # Build script for MatrixAPI.dll
├── MatrixAPI.dll              # Compiled P/Invoke wrapper (optional pre-compiled)
├── CLAUDE.md                  # Project instructions for Claude AI
├── MATRIX.md                  # Main README with overview
├── LICENSE                    # MIT license
└── [70+ test/debug scripts]   # Various diagnostic and testing utilities
```

## Directory Purposes

**Root Level - Entry Points:**
- Purpose: Main user-facing scripts and state files
- Contains: `matrix_control.ps1`, `matrix_setup.ps1`, `bluepill.ps1` (PowerShell entry points), `prd.json` (project metadata)
- Key files: See "Entry Points" section below

**shaders/ - Shader Library:**
- Purpose: HLSL pixel shader implementations for GPU rendering
- Contains: 8 numbered slot shaders (Matrix-1.hlsl through Matrix-8.hlsl) + custom Neo vision shader
- Key files: `C:\Users\ehome\documents\matrix\shaders\Matrix-1.hlsl`, `C:\Users\ehome\documents\matrix\shaders\Redpill-Neo.hlsl`
- Generated: Yes - Matrix-{1..8}.hlsl are auto-generated from templates with parameter injection
- Committed: Yes - template present in `matrix_control.ps1` and `matrix_setup.ps1`

**bin/ - Compiled Binaries:**
- Purpose: NPM package entry point and native executables
- Contains: `redpill.js` (Node.js wrapper), `native/redpill.exe` (C# console app)
- Key files: `C:\Users\ehome\documents\matrix\bin\redpill.js`
- Generated: redpill.js, redpill.exe via Compile-MatrixAPI.ps1
- Committed: Yes

**MatrixShader/ - C# Source:**
- Purpose: Source code for MatrixAPI.dll and native redpill.exe
- Contains: C# project files, pre-compiled DLL
- Generated: MatrixAPI.dll
- Committed: Yes (source files)

**config/ - Configuration Templates:**
- Purpose: Formerly used for default settings (now superseded by inline defaults)
- Status: Unused in current flow - all defaults in `matrix_control.ps1`, `matrix_setup.ps1`

**MVP/ - Legacy Archive:**
- Purpose: Original single-instance shader implementation
- Contains: `MVP/Matrix.hlsl` (legacy)
- Status: Archived - current system uses 6-8 instance approach

**.planning/codebase/ - GSD Documentation:**
- Purpose: Architecture, structure, conventions, and testing documentation for orchestrator
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md (generated by `/gsd:map-codebase`)
- Generated: Yes - created by Claude Code agents
- Committed: Yes

**PRD/ - Product Requirements:**
- Purpose: Detailed user story specifications for current/past phases
- Contains: Markdown files with user story templates
- Key files: `tasks/prd.json` (Ralph-compatible current sprint)

**RECOVERY/ - Agent Logs:**
- Purpose: Recovery documentation from multi-phase implementations
- Contains: Phase output markdown, agent completion logs, rate-limit recovery docs
- Status: Reference only

**NOTES/, STRATEGY/, TEAM_MEETING/, Website/ - Documentation:**
- Purpose: Dev notes, strategic planning, meeting minutes, web content
- Status: Reference documentation, not code

## Key File Locations

**Entry Points:**
- `C:\Users\ehome\documents\matrix\matrix_control.ps1`: Interactive control panel TUI (1200+ lines). Main user interface for shader parameter adjustment, multi-window tab management, layout cycling.
- `C:\Users\ehome\documents\matrix\matrix_setup.ps1`: Setup wizard (300+ lines). Initial configuration, Blue Pill vs Red Pill path selection, window launching.
- `C:\Users\ehome\documents\matrix\bluepill.ps1`: Quick launch (200+ lines). Restore previous session without wizard.
- `C:\Users\ehome\documents\matrix\bin\redpill.js`: NPM entry point (8 lines). Delegates to native executable.

**Core Business Logic:**
- `C:\Users\ehome\documents\matrix\WindowIdentityService.ps1`: Window detection and identity resolution (700+ lines). Implements 4-layer hierarchy for robust window tracking.
- `C:\Users\ehome\documents\matrix\WindowLayoutEngine.ps1`: Layout calculation and positioning (1000+ lines). Multi-monitor aware, Pillars/Quads modes, edge case handling.
- `C:\Users\ehome\documents\matrix\MatrixLogging.ps1`: Unified logging (80+ lines). Centralized debug output controlled by `$env:MATRIX_DEBUG`.
- `C:\Users\ehome\documents\matrix\MatrixUtils.ps1`: Shared utilities (80+ lines). Color swatches, screen dimension queries, helper functions.

**Configuration/State:**
- `C:\Users\ehome\documents\matrix\matrix_state.json`: Persistent layout preferences (lastSlots, gapSize, mode, monitorCount, glitchEnabled).
- `C:\Users\ehome\documents\matrix\window-registry.json`: Window handle to shader file mapping (generated at runtime, keyed by window handle).
- `C:\Users\ehome\documents\matrix\identity-registry.json`: Profile name to window identity mapping (persistent across reboots).
- `C:\Users\ehome\documents\matrix\prd.json`: Ralph-compatible project requirements (current hardening sprint status).

**Shaders:**
- `C:\Users\ehome\documents\matrix\shaders\Matrix-1.hlsl` through `Matrix-8.hlsl`: Auto-generated pixel shaders with injected #define parameters.
- `C:\Users\ehome\documents\matrix\shaders\Redpill-Neo.hlsl`: Custom 3D corridor shader with SDF text (Neo vision mode).

**Compilation:**
- `C:\Users\ehome\documents\matrix\Compile-MatrixAPI.ps1`: Builds MatrixAPI.dll from C# source (if not pre-compiled).
- `C:\Users\ehome\documents\matrix\MatrixAPI.dll`: Pre-compiled P/Invoke wrapper (optional - WindowLayoutEngine falls back to inline compilation).

## Naming Conventions

**Files:**
- `matrix_*.ps1` pattern: Main entry points (matrix_control.ps1, matrix_setup.ps1, matrix_state.json)
- `Matrix-*.hlsl` pattern: Numbered shader instances (Matrix-1.hlsl through Matrix-8.hlsl)
- `*Service.ps1` pattern: Reusable service modules (WindowIdentityService.ps1, MatrixLogging.ps1)
- `*Engine.ps1` pattern: Complex subsystems (WindowLayoutEngine.ps1)
- `check-*.ps1`, `debug-*.ps1`, `test-*.ps1` pattern: Diagnostic and testing utilities
- `*-registry.json` pattern: Persistent mapping files (window-registry.json, identity-registry.json)

**Directories:**
- lowercase-with-hyphens: User content (BACKGROUND IMAGES, bin, config, shaders, tasks)
- UPPERCASE: Documentation (NOTES, STRATEGY, TEAM_MEETING, RECOVERY, Website, PRD)
- Dot-prefixed: System files (.claude, .git, .planning)

**Functions (PowerShell):**
- `Verb-Noun` pattern: `Load-Shader`, `Save-Shader`, `Write-MatrixLog`, `Get-ScreenTopology`, `Invoke-MatrixWindowLayout`, `Get-AllMatrixWindows`
- Pascal case for type names: `WindowLayoutAPI`, `MatrixWindowAPI`, `IdentityResolution`

**Variables:**
- `$matrixDir`: Root project directory
- `$shadersDir`: Shader library directory
- `$wtSettingsPath`: Windows Terminal settings.json path
- `$windowRegistryPath`: window-registry.json path
- `$script:` prefix: Module-level variables (caching, registry storage)

## Where to Add New Code

**New Feature (e.g., Additional Shader Effect):**
- Primary code: `C:\Users\ehome\documents\matrix\shaders\Matrix-{slot}.hlsl` (HLSL pixel shader code)
- Control logic: `C:\Users\ehome\documents\matrix\matrix_control.ps1` (add key handler + parameter adjustment function)
- Tests: `C:\Users\ehome\documents\matrix\test-*.ps1` (new test-effect-name.ps1)

**New Window Layout Mode:**
- Implementation: `C:\Users\ehome\documents\matrix\WindowLayoutEngine.ps1` (add `Calculate-{ModeName}Layout` function)
- Orchestration: Update `Invoke-MatrixWindowLayout` to handle new mode in switch statement
- Configuration: Update `matrix_state.json` schema to store mode preference
- Tests: `C:\Users\ehome\documents\matrix\test-layout-phase*.ps1` (add case for new mode)

**New Diagnostic Tool:**
- Location: `C:\Users\ehome\documents\matrix\debug-{purpose}.ps1` or `check-{purpose}.ps1`
- Pattern: Single-purpose script for troubleshooting specific subsystem
- Logging: Use `Write-MatrixLog` instead of `Write-Host` for consistency
- Example: `C:\Users\ehome\documents\matrix\check-hotkeys.ps1` (verify hotkey registration)

**New Service Module (Reusable Component):**
- Location: `C:\Users\ehome\documents\matrix\{Name}Service.ps1`
- Pattern: Exported functions with internal state via `$script:` variables
- Integration: Dot-source in entry points that need it (`. "$PSScriptRoot\{Name}Service.ps1"`)
- Documentation: JSDoc-style comments for public functions

**Utilities (Shared Helpers):**
- Location: Add to `C:\Users\ehome\documents\matrix\MatrixUtils.ps1` if general-purpose
- Export: Use `Set-Alias` if convenient shorthand needed (e.g., `Set-Alias Swatch Get-ColorSwatch`)

**Configuration/Defaults:**
- Shader Defaults: `$defaults` hashtable in `matrix_control.ps1`, `matrix_setup.ps1`
- Layout Defaults: `matrix_state.json` top-level keys
- Terminal Settings: Embedded inline in Load-TerminalEffects function (no separate config file)

**Tests:**
- Location: Root directory with `test-*.ps1` naming
- Framework: Manual/ad-hoc (no test runner; each script is standalone)
- Pattern: Output diagnostic info, success/fail messages, pause for visual inspection
- Examples: `C:\Users\ehome\documents\matrix\test-functional.ps1`, `C:\Users\ehome\documents\matrix\test-syntax.ps1`

## Special Directories

**shaders/ (Shader Library):**
- Purpose: HLSL implementations, auto-generated per-slot with parameter injection
- Generated: Yes - matrix_control.ps1 and matrix_setup.ps1 create these at runtime from templates
- Committed: No for Matrix-{1..8}.hlsl (ephemeral), Yes for Redpill-Neo.hlsl (static)
- Pattern: Each Matrix-N.hlsl contains bit-packed Katakana glyphs (35 bits per char = 5x7 pixels) and DrawLayer function with 3-layer parallax
- Hot-reload: Windows Terminal watches for timestamp changes and reloads automatically

**bin/native/ (Compiled C# Executables):**
- Purpose: Native Windows applications for CLI access (redpill.exe)
- Generated: Yes - compiled from MatrixShader/ C# project
- Committed: Yes (.exe binaries included)
- Used by: `bin/redpill.js` spawns as child process

**MatrixShader/ (C# Project Source):**
- Purpose: Source for MatrixAPI.dll and redpill.exe
- Generated: No (hand-written source)
- Committed: Yes
- Build: Run `Compile-MatrixAPI.ps1` to regenerate DLL (used if pre-compiled unavailable)

**.planning/codebase/ (GSD Documentation):**
- Purpose: Auto-generated architecture/testing documentation
- Generated: Yes - created by `/gsd:map-codebase` agent
- Committed: Yes - checked into version control
- Used by: `/gsd:plan-phase` and `/gsd:execute-phase` orchestrator commands

**RECOVERY/ (Agent Output Archive):**
- Purpose: Preserve phase-specific output and completion logs
- Generated: Yes - created during multi-phase implementations
- Committed: Yes
- Status: Reference/audit trail only, not active code

---

*Structure analysis: 2026-01-25*
