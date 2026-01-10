# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Matrix Terminal Shader - A real-time controllable Matrix rain effect for Windows Terminal. Two-file system: HLSL pixel shader + PowerShell TUI controller.

## Architecture

```
User Input → matrix_tool.ps1 → Regenerates Matrix.hlsl → Windows Terminal hot-reloads → GPU renders
```

**Key mechanism:** PowerShell writes shader parameters as `#define` statements. Windows Terminal detects file timestamp change and reloads shader automatically (~100ms latency).

**Files:**
- `MVP/Matrix.hlsl` - HLSL pixel shader with 16 bit-packed Katakana-style glyphs (5x7 pixels each, stored as uint32)
- `MVP/matrix_tool.ps1` - PowerShell TUI with embedded shader template, real-time parameter control

## Critical Technical Details

### HLSL Glyph System
Glyphs are bit-packed: 35 bits (5×7 pixels) per character stored in uint32 constants. Lookup: `(GLYPHS[idx] >> bit_index) & 1u`

### Hot-Reload Mechanism
PowerShell regenerates entire shader file with new `#define` values, then touches file timestamp. Windows Terminal watches for changes.

### Layer System
Three parallax depth layers (FAR/MID/NEAR) rendered additively. Each can be toggled independently.

## File Encoding

PowerShell requires CRLF line endings. Always use Windows-native tools.

## Key Paths

- Installed shader: `C:\Users\ehome\Documents\Matrix\Matrix.hlsl`
- Installed controller: `C:\Users\ehome\Documents\Matrix\matrix_tool.ps1`
- Windows Terminal settings: `C:\Users\ehome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
- GitHub repo: `matrixshader/matrix-shader`

## Testing

1. Modify shader `#define` values directly in Matrix.hlsl - changes appear immediately in terminal
2. Run `matrix_tool.ps1` in Windows PowerShell to test TUI controls
3. Verify shader compiles by checking Windows Terminal shows effect (no error = success)
