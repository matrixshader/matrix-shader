# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Session Startup Protocol
At the start of EVERY session (or after compaction), before doing any work:
1. Read `C:\Users\ehome\documents\openmind\projects\matrixshader\sessions\` — list recent files, read the latest ones for context
2. Read your memory file at `~/.claude/projects/C--Users-ehome-documents-matrix/memory/MEMORY.md`
3. When launching agent swarms, always include: "Read the audit at openmind/projects/matrixshader/sessions/ for context"
4. The full transcript of previous sessions is in openmind — search it when you need context about past decisions

## Project Overview

Matrix Terminal Shader - Real-time GPU-powered Matrix rain effects for your terminal. Multi-platform: Windows Terminal (HLSL) and Linux/Ghostty (GLSL).

## Architecture

### Windows
```
User Input → matrix_control.ps1 → Regenerates HLSL #defines → Windows Terminal hot-reloads → GPU renders
```

### Linux
```
wakeupneo → spawns patched Ghostty instances → per-window GLSL shaders → D-Bus config reload for live control
```

**Key mechanism (Windows):** PowerShell writes shader parameters as `#define` statements. Windows Terminal detects file timestamp change and reloads shader automatically (~100ms latency).

**Key mechanism (Linux):** Each Ghostty window gets its own config file pointing to a color-specific GLSL shader. Opacity and reload controlled via D-Bus (`org.ghostty.Application`).

## Core Files

### Windows
- `MatrixShader/` - C#/.NET solution (CLI, Hotkeys, Core services)
- `shaders/Matrix-1.hlsl` through `Matrix-6.hlsl` - HLSL pixel shaders
- `shaders/Redpill-Neo.hlsl` - Custom 3D corridor shader
- `installer/` - Inno Setup installer and PowerShell install scripts

### Linux
- `linux/wakeupneo.sh` - Setup wizard (spawns in own Ghostty window)
- `linux/install.sh` - Full installer (tarball or curl pipe)
- `linux/i.sh` - One-liner bootstrap for `curl | bash`
- `shaders-glsl/` - GLSL shader ports (matrix-green.glsl, matrix-red.glsl, etc.)

### Website (SEPARATE PRIVATE REPO)
- Repo: `Ehomey/matrixshader.com` (private, Vercel auto-deploys)
- Website and API moved out of public repo on 2026-03-17
- DO NOT look for Website/ or api/ in the public repo — they're gone

## Technical Details

### HLSL Glyph System
Glyphs are bit-packed: 35 bits (5x7 pixels) per character stored in uint32 constants.

### GLSL Transparency Fix
Ghostty leaves `GL_BLEND` enabled during custom shader pass, causing alpha to blend against black instead of being written directly. Fix: disable blending in `opengl/main.zig` during shader render.

### Self-Relaunch Pattern (Linux)
Scripts use command-line flags (`--in-ghostty`, `--show`) instead of environment variables for detecting "am I in my own window?" - env vars leak through process trees. Combined with `nohup`/`disown`/`exit 0` for clean detachment.

## Building

### Windows
```powershell
dotnet publish MatrixShader/MatrixShader.sln -c Release /p:PublishAot=false
```

### Linux
```bash
./linux/build-release.sh          # tarball
./linux/build-packages.sh         # .deb + .rpm (requires fpm, rpmbuild, dpkg-deb)
```
Patched Ghostty binary is pre-built and bundled in release tarballs and packages.

## Install URLs
- `matrixshader.com/install.ps1` → Windows PowerShell script
- `matrixshader.com/linux` → Linux shell script (i.sh)
- `matrixshader.com/install` → Website download section (platform-neutral)

## Testing

- Windows: Run `matrix_control.ps1` in PowerShell, or use `MatrixShaderTest.wsb` for sandbox testing
- Linux: Run `wakeupneo` after installing via `linux/install.sh` or .deb/.rpm package
- Website: Push to `master` of `Ehomey/matrixshader.com` triggers Vercel auto-deploy

## GitHub

- Repo: `matrixshader/matrix-shader` (public, source-available BSL 1.1)
- Website repo: `Ehomey/matrixshader.com` (private, Vercel Hobby)
- Releases include: Windows installer (.exe), Windows zip (.zip), Linux tarball (.tar.gz), Linux .deb, Linux .rpm

## Current Project State (updated 2026-03-24)

### Version
- Latest released: v1.0.5 (both platforms rebuilt 2026-03-24 with all fixes)
- No version increment planned — current work is stabilization of v1.0.5

### Linux Status: v1.0.5 SHIPPED
All features working. Construct white room, 4 Ghostty patches, matrixlite rewrite, stale PID vaccine.
Release assets on GitHub: tarball (.tar.gz), .deb (Ubuntu/Debian), .rpm (Fedora/RHEL).

Recent fixes (2026-03-24):
- build-release.sh reads version from Directory.Build.props (was broken since repo split)
- Update URL fixed from /install (404) to /linux
- Tarball removed from git tracking (lives on GitHub Releases only)
- .deb and .rpm package builder added (linux/build-packages.sh)
- Website updated: Linux tab has .deb/.rpm downloads, "Preview" label removed
- /install rewrite added to vercel.json (redirects to /#get-started)

### Windows Status: STABILIZED — READY FOR E2E TEST
v1.0.5 Windows release rebuilt and uploaded to GitHub (zip + installer) on 2026-03-24.
All regression fixes from 2026-03-21 team investigation + 2026-03-24 session are committed and shipped.

**Fixed (shipped in v1.0.5 rebuild):**
- deploy-local.ps1 restarts background processes after deploy
- ProcessCleanup utility: kill-before-launch prevents duplicate hotkeys/monitor
- Monitor: single-instance check, auto-exit after 30s with no windows, watchdog respects clean exit
- Construct: deduplicates hotkey processes
- Foreground text color syncs with shader/tab color in all launch paths (wakeupneo, redpill, construct)
- Hotkeys use WriteDefines() — speed/layer changes can never corrupt shader color defines
- Speed hotkey (Ctrl+Shift+Up/Down) is global to all windows
- 5 regression fixes from team investigation (UpsertProfilesSurgical, CalculateLayoutByCurrentMonitor, StartsWith identity, cache invalidation, RemoveProfileSurgical)
- Dead window vaccine in LoadRegistry

**Known issues (not blocking release):**
1. **Orphan recovery** — when hotkeys restart, windows without registry entries become invisible.
   Linux has Vaccine 2 (pgrep scan). Windows needs the equivalent in FindMatrixWindows.
2. **Title overwrite breaks Layer 3** — apps that change terminal title break title-based detection.
   Layer 1 (hwnd registry) works while hotkeys are alive. Long-term: persist registry to disk.
3. **WT shader reload unreliable from file writes** — Ctrl+Shift+F5 works but programmatic
   file changes don't always trigger WT to recompile. Need better reload mechanism.

### Release Pipeline
1. Install + e2e test on BOTH Windows and Linux (founder tests personally)
2. Fix what breaks, repeat until passing
3. Marketing push (launch posts via Agent Smith, demo video)

### Next Session Actions (Priority Order)
1. Clean end-to-end test: fresh install from v1.0.5 zip/exe → wakeupneo → construct x3 → verify hotkeys + Glitch
2. Clean end-to-end test on Linux: .deb/.rpm install + tarball
3. Fix any issues found in e2e
4. Once both platforms pass: marketing push

### Session Log
| Date | Phase | Accomplishments | Next Steps |
|------|-------|-----------------|------------|
| 2026-03-24 | Windows stabilization | ProcessCleanup, foreground sync, shader-safe hotkeys, global speed, deploy-local restart, v1.0.5 rebuilt and uploaded | E2E test |
| 2026-03-24 | Linux release polish | Fixed build version bug, /install URL, added .deb/.rpm packages, updated website, removed tarball from git | E2E test |
| 2026-03-22 | Construct stability (Win) | Fixed 5 regressions, foreground color + dead window vaccine | deploy-local restart, orphan recovery |
| 2026-03-21 | Construct fix plan (Win) | Team investigation identified 5 regressions | Fix and commit regressions |
| 2026-03-20 | Linux v1.0.5 ship | Construct working, 4 Ghostty patches, matrixlite rewrite, tarball deployed | Testing |
| 2026-03-17 | Repo split + license rotation | Website to private repo, secret rotated, BSL 1.1 license | Rebuild tarballs |
| 2026-03-14 | v1.0.4 launch | Windows + Linux released. Website launched. Pricing confirmed. | Marketing launch |
