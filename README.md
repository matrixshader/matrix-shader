# Matrix Terminal Shader

A multi-window Matrix rain effect system for Windows Terminal with automatic window positioning, real-time shader control, and multi-monitor support.

## What It Does

Transform your Windows Terminal into a Matrix-style command center. Launch multiple shader windows that automatically position themselves across your monitors, then control them all from a single TUI control panel.

**Key Capabilities:**
- Launch 1-6 Matrix shader windows that auto-arrange across multiple monitors
- Two layout modes: **Pillars** (side-by-side columns) or **Quads** (2x2 grid per screen)
- Real-time parameter control: speed, color, density, glyph style, layer visibility
- Hot-reload: Changes appear instantly (~100ms) without restarting anything
- Interactive setup wizard with Blue Pill (simple) and Red Pill (full system) paths

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         matrix_setup.ps1                                 │
│                    (Setup Wizard - Blue/Red Pill)                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
         ┌──────────────────┐            ┌──────────────────────┐
         │   bluepill.ps1   │            │  matrix_control.ps1  │
         │  (Simple Install)│            │   (Control Panel)    │
         └──────────────────┘            └──────────────────────┘
                    │                               │
                    └───────────────┬───────────────┘
                                    ▼
                    ┌───────────────────────────────┐
                    │    WindowLayoutEngine.ps1     │
                    │  - Multi-monitor detection    │
                    │  - Pillars/Quads layouts      │
                    │  - Windows API (SetWindowPos) │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │      shaders/*.hlsl           │
                    │  - Matrix rain effects        │
                    │  - 3D corridor (Neo vision)   │
                    │  - Hot-reload via timestamp   │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │       Windows Terminal        │
                    │   (GPU shader rendering)      │
                    └───────────────────────────────┘
```

**Hot-Reload Mechanism:** PowerShell regenerates shader files with new `#define` values. Windows Terminal watches for file timestamp changes and reloads automatically.

## Quick Start

```powershell
# Run the setup wizard
.\matrix_setup.ps1
```

Choose your path:
- **Blue Pill**: Simple single-shader install for your terminal background
- **Red Pill**: Full multi-window system with control panel and Neo vision

## Control Panel

The control panel (`matrix_control.ps1`) provides:
- **Tabbed interface** for switching between shader windows
- **Keyboard controls** for all parameters (arrows, +/-, letters)
- **Shift+L** to cycle between Pillars and Quads layout modes
- **Live preview** as you adjust settings

## Window Layout Engine

The `WindowLayoutEngine.ps1` handles all window positioning:

| Mode | Description |
|------|-------------|
| **Pillars** | Side-by-side columns with configurable gap. Best for 1-4 windows. |
| **Quads** | 2x2 grid per screen. Scales to any number of windows across monitors. |

Features:
- Automatic multi-monitor detection via `[System.Windows.Forms.Screen]::AllScreens`
- Windows API integration (P/Invoke): `SetWindowPos`, `EnumWindows`, `IsWindowVisible`
- Configurable gaps, taskbar-aware positioning
- Handles edge cases: zero windows, 10+ windows, screen disconnection, invalid handles

## Files

| File | Purpose |
|------|---------|
| `matrix_setup.ps1` | Interactive setup wizard |
| `matrix_control.ps1` | Multi-window TUI control panel |
| `WindowLayoutEngine.ps1` | Centralized window positioning (1046 lines) |
| `bluepill.ps1` | Blue Pill installation script |
| `shaders/Matrix-1.hlsl` - `Matrix-6.hlsl` | Classic Matrix rain shaders |
| `shaders/Redpill-Neo.hlsl` | 3D corridor with glowing logo (Red Pill background) |

## Technical Details

### HLSL Glyph System
Katakana glyphs are bit-packed: 35 bits (5x7 pixels) per character in `uint32` constants. GPU-side lookup: `(GLYPHS[idx] >> bit_index) & 1u`

### Layer System
Three parallax depth layers (FAR/MID/NEAR) rendered additively. Each toggleable for different visual effects.

### Windows API Integration
```powershell
# P/Invoke declarations in WindowLayoutEngine.ps1
[DllImport("user32.dll")] SetWindowPos()
[DllImport("user32.dll")] EnumWindows()
[DllImport("user32.dll")] IsWindowVisible()
[DllImport("user32.dll")] GetWindowText()
```

## Requirements

- Windows 10/11
- Windows Terminal (with pixel shader support)
- PowerShell 5.1+

## License

MIT License
