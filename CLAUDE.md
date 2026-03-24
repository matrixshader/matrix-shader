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
- Latest released: v1.0.5
- Windows in progress: v1.0.6 (construct stability fixes)

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

### Windows Status: STABILIZATION IN PROGRESS
All regression fixes from the 2026-03-21 team investigation are committed (7010d9b, 6df48cb).
The system is functional but has three remaining stability gaps:

1. **deploy-local.ps1 does not restart hotkeys** — kills processes, never restarts them.
   Fix needed: add `Start-Process matrix-hotkeys.exe` and `Start-Process matrix-monitor.exe`
   at the end of `installer/deploy-local.ps1`.

2. **No orphan recovery** — when hotkeys restart, windows whose registry entries were lost
   become invisible. Linux has Vaccine 2 (pgrep scan). Windows needs the equivalent in
   `FindMatrixWindows`: scan all `WindowsTerminal` processes, match unregistered hwnds to
   Matrix profiles via settings.json GUID lookup.

3. **Title overwrite breaks Layer 3** — apps like Claude Code, vim, htop change the terminal
   title, breaking title-based identity. Layer 1 (hwnd registry) is reliable but lost on restart.
   Long-term: persist identity registry to disk and reload on startup.

### Session Log
| Date | Phase | Accomplishments | Next Steps |
|------|-------|-----------------|------------|
| 2026-03-24 | Linux release polish | Fixed build version bug, /install URL, added .deb/.rpm packages, updated website, removed tarball from git | Test install, marketing |
| 2026-03-22 | Construct stability (Win) | Fixed 5 regressions, foreground color + dead window vaccine | deploy-local restart, orphan recovery, v1.0.6 |
| 2026-03-21 | Construct fix plan (Win) | Team investigation identified 5 regressions | Fix and commit regressions |
| 2026-03-20 | Linux v1.0.5 ship | Construct working, 4 Ghostty patches, matrixlite rewrite, tarball deployed | Testing, marketing |
| 2026-03-17 | Repo split + license rotation | Website to private repo, secret rotated, BSL 1.1 license | Rebuild tarballs with new secret |
| 2026-03-14 | v1.0.4 launch | Windows + Linux released. Website launched. Pricing confirmed. | Marketing launch |
