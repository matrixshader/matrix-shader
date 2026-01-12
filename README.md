# Matrix Terminal Shader

A real-time controllable Matrix rain effect for Windows Terminal with an interactive control panel for managing multiple shader instances.

## Overview

Matrix Terminal Shader transforms Windows Terminal into a customizable Matrix-style digital rain effect. Control multiple shader windows simultaneously with real-time parameter adjustments, custom shader selection, and an immersive Neo-vision interface.

## Features

- **Multi-Window Management**: Control up to 6 independent Matrix shader windows
- **Real-Time Parameter Control**: Adjust speed, color, density, and layer visibility on the fly
- **Custom Shader Library**: Choose from 6+ pre-built shaders including classic Matrix rain, tunnel effects, and 3D corridors
- **Hot-Reload Technology**: Changes appear instantly in Windows Terminal (~100ms latency)
- **Neo Vision Interface**: Redpill mode features custom 3D corridor shader with glowing Matrix logo
- **Setup Wizard**: Interactive PowerShell wizard guides you through installation

## Architecture

```
User Input → matrix_control.ps1 → Regenerates shader HLSL → Windows Terminal hot-reloads → GPU renders
```

**Key mechanism:** PowerShell writes shader parameters as `#define` statements. Windows Terminal detects file timestamp changes and reloads shaders automatically.

## Quick Start

1. Run the setup wizard:
   ```powershell
   .\matrix_setup.ps1
   ```

2. Choose your path:
   - **Blue Pill**: Just install the original Matrix shader
   - **Red Pill**: Install multi-window system with control panel

3. Follow the prompts to configure your Matrix windows

4. Use the control panel (`matrix_control.ps1`) to adjust shaders in real-time

## Current Status

### Recently Completed (v2 Hardening Sprint)
- Created custom Redpill-Neo vision shader with 3D corridor and glowing logo text
- Updated Red Pill path to launch configured windows and Neo control panel
- Conducted code review of matrix_control.ps1 (rated 7/10)
- Generated PRD with 10 hardening user stories

### In Progress
- Control panel hardening (10 user stories in prd.json):
  - Safe atomic file writes
  - JSON error handling
  - Shader value validation
  - Auto-save on tab switch
  - Robust window detection/positioning
  - Diagnostic logging
  - Code consolidation

### Next Steps
Execute hardening user stories US-001 through US-010 to improve control panel robustness.

## Key Files

- `matrix_control.ps1` - Multi-window control panel TUI
- `matrix_setup.ps1` - Interactive setup wizard
- `shaders/` - Library of HLSL pixel shaders
  - `Redpill-Neo.hlsl` - 3D corridor Neo vision shader
  - `Matrix-1.hlsl` through `Matrix-6.hlsl` - Classic Matrix effects
- `prd.json` - Current project user stories
- `tasks/prd-control-panel-hardening.md` - Hardening requirements document

## Technical Details

### HLSL Glyph System
Glyphs are bit-packed: 35 bits (5x7 pixels) per character stored in uint32 constants. Efficient GPU-side lookup via bit masking.

### Layer System
Three parallax depth layers (FAR/MID/NEAR) rendered additively. Each layer can be toggled independently for different visual effects.

### File Encoding
PowerShell requires CRLF line endings. Always use Windows-native tools when editing.

## Repository

GitHub: [matrixshader/matrix-shader](https://github.com/matrixshader/matrix-shader)

## License

MIT License
