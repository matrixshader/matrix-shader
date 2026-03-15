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

### Website
- `Website/` - Static site deployed to Vercel (matrixshader.com)
- `api/` - Vercel serverless functions (tracking, subscriptions, validation)

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
Patched Ghostty binary is pre-built and bundled in release tarballs.

## Testing

- Windows: Run `matrix_control.ps1` in PowerShell, or use `MatrixShaderTest.wsb` for sandbox testing
- Linux: Run `wakeupneo` after installing via `linux/install.sh`
- Website: Push to `master` triggers Vercel auto-deploy

## GitHub

- Repo: `matrixshader/matrix-shader`
- Releases include Windows installer (.exe) and Linux tarball (.tar.gz)
