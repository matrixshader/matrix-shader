# Matrix Terminal Shader

Real-time Matrix rain effect for Windows Terminal with multi-window control, automatic positioning, and GPU-accelerated rendering.

![Matrix Shader Demo](https://raw.githubusercontent.com/matrixshader/matrix-shader/main/demo.gif)

## Installation

```bash
npm install -g matrix-shader
```

**Requirements:**
- Windows 10/11
- Windows Terminal (from Microsoft Store)
- Node.js 14+

## Quick Start

```bash
# Launch the setup wizard
wakeupneo
```

Choose your path:
- **Blue Pill** - Quick setup, launches Matrix windows
- **Red Pill** - Full control panel with live parameter editing

## Commands

| Command | Description |
|---------|-------------|
| `wakeupneo` | Setup wizard - configure colors, window count |
| `bluepill` | Quick launch with last saved settings |
| `redpill` | Open the control panel for live adjustments |
| `matrix-hotkeys` | Start background hotkey daemon |

## Features

**Multi-Window System**
- Launch up to 8 independent Matrix shader windows
- Each window can have different colors and settings
- Automatic positioning across multiple monitors

**Layout Modes**
- **Pillars** - Side-by-side columns (best for 2-4 windows)
- **Quads** - 2x2 grid per monitor (scales to any count)

**Real-Time Control**
- Adjust speed, color, density, glow on the fly
- Changes appear instantly (~100ms hot-reload)
- Toggle individual depth layers (far/mid/near)

**Global Hotkeys** (run `matrix-hotkeys`)
- `Win+Alt+Left/Right` - Swap window positions
- `Win+Alt+L` - Cycle layout mode
- `Win+Alt+B` - Toggle transparency
- `Win+Alt+J/K` - Adjust opacity

## Control Panel

Run `redpill` to open the TUI control panel:

```
┌─────────────────────────────────────────┐
│  RED PILL - Tab 1                       │
│  ═══════════════════════════════════════│
│                                         │
│  Color: ██ Classic Green                │
│  Speed: ████████░░ 0.8                  │
│  Density: ██████░░░░ 0.6                │
│                                         │
│  [1-6] Tab  [←→] Speed  [↑↓] Density   │
│  [C] Color  [L] Layers  [Shift+L] Layout│
└─────────────────────────────────────────┘
```

**Keyboard Controls:**
- `1-8` - Switch between shader tabs
- `←/→` - Adjust speed
- `↑/↓` - Adjust density
- `C` - Cycle color preset
- `G` - Adjust glow
- `W` - Adjust character width
- `1/2/3` - Toggle depth layers
- `Shift+L` - Cycle layout mode
- `Shift+N` - Launch new window
- `Q` - Quit

## Color Presets

| Key | Name | RGB |
|-----|------|-----|
| 1 | Classic | Green (0, 1, 0.3) |
| 2 | Cyber | Blue (0, 0.6, 1) |
| 3 | Blood | Red (1, 0.1, 0.1) |
| 4 | Purple | Violet (0.7, 0, 1) |
| 5 | Gold | Amber (1, 0.7, 0) |
| 6 | Cyan | Teal (0, 0.9, 0.9) |

## How It Works

```
PowerShell Control → Shader Files (.hlsl) → Windows Terminal GPU
     ↓                      ↓                       ↓
  User Input         #define values          Real-time render
                     (hot-reload)
```

1. Control scripts modify shader `#define` parameters
2. File timestamp change triggers Windows Terminal reload
3. GPU renders the updated effect in ~100ms

## Shader System

Each Matrix window uses an HLSL pixel shader with:
- **Bit-packed Katakana glyphs** - 35 bits per character (5x7 pixels)
- **Three parallax layers** - Far, Mid, Near for depth effect
- **Configurable parameters** - Speed, color, density, glow, trail

The Neo vision shader (`Redpill-Neo.hlsl`) features:
- 3D box corridor with Matrix code on walls
- SDF-rendered glowing "MATRIX SHADER" logo
- Used as the Red Pill control panel background

## Troubleshooting

**Windows don't position correctly**
- Run `wakeupneo` again to re-detect monitors
- Check if Windows Terminal is running as admin

**Shader doesn't load**
- Verify Windows Terminal supports pixel shaders
- Check `shaders/` folder exists with `.hlsl` files

**Hotkeys not working**
- Run `matrix-hotkeys` in a separate terminal
- Check for conflicting global hotkeys

## Uninstall

```bash
npm uninstall -g matrix-shader
```

Then remove Matrix profiles from Windows Terminal settings manually, or delete:
```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```
(Windows Terminal will recreate it with defaults)

## License

Copyright (c) 2024 matrixshader.com. All Rights Reserved.

Free for personal, non-commercial use.
Commercial use, redistribution, and modification require written permission.

---

Inspired by The Matrix (1999).
Not affiliated with or endorsed by Warner Bros. Entertainment Inc.

If you are a rights holder and are interested in collaboration,
please contact: architect@matrixshader.com
