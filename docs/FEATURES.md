# Matrix Shader — Feature Reference

## Commands

### `wakeupneo`
Setup wizard. Start here after installing.
- Animated splash screen with Matrix quotes
- Color picker: choose from 6 agent-coded presets (Green, Blue, Red, Purple, Gold, Teal)
- Deploys 3 Matrix shader windows in Pillars layout
- Auto-activates GNOME extension for window positioning (Linux)
- Starts hotkey daemon in background
- Flags: `--morpheus` (philosophical intro), `--agent-smith` (chaos mode), `--update` (check for updates)

### `construct`
Launch individual Matrix terminal windows.
- No arguments: opens the white room CRT TV color picker (fullscreen, arrow key browsing, GPU zoom, power-off animation)
- `--green`, `--red`, `--blue`, `--purple`, `--gold`, `--teal`: quick launch with preset color
- `--aurora`, `--aurora-rain`, `--fireplace`, `--codevision`, `--ultra`, `--rain-on-glass`: bonus shaders
- `--preset <name>`: launch from a saved preset (all 11 shader parameters applied)
- `--help`: show all available colors and options

### `bluepill`
Restore your last Matrix session.
- Reads saved shader configs from state.json
- Relaunches all windows with their colors, speed, layers, opacity
- Applies layout (Pillars/Quads/Overlap/Auto with 35px gaps)
- `--preset <name>`: launch a single preset window instead of restoring full session

### `redpill`
Full control panel. Requires license ($5 Founder's Edition).
- Opens in its own Ghostty window with MatrixCodeVision background shader
- Real-time parameter adjustment with instant GPU feedback
- `--activate REDPILL-XXXX-XXXX-XXXX-XXXX`: activate license key

### `matrixlite`
Text-mode Matrix rain for any terminal (no GPU required).
- Synchronized output via DECSET 2026
- Dirty-cell rendering for minimal terminal writes
- 10-level brightness palette with twinkling effect
- Color presets displayed in actual terminal colors

---

## Red Pill Control Panel

### Parameter Controls (TUI keys)
| Key | Action |
|-----|--------|
| 1-6 | Color presets (Green/Blue/Red/Purple/Gold/Teal) |
| Q/W | Red channel -/+ |
| A/S | Green channel -/+ |
| Z/X | Blue channel -/+ |
| E/R | Speed -/+ |
| D/F | Glow -/+ |
| C/V | Width -/+ |
| T/Y | Trail -/+ |
| G/H | Density -/+ |
| 7/8/9 | Toggle layers (Far/Mid/Near) |
| B | Toggle transparency |
| K/L | Opacity -/+ |
| -/+ | Deploy count -/+ |
| Enter | Deploy windows |
| 0 | Reset to defaults |
| Tab | Switch between windows |
| ESC | Exit |

### Shift Keys (TUI)
| Key | Action |
|-----|--------|
| Shift+P | Presets (save/load/delete shader configs) |
| Shift+G | Toggle Glitch (overlap auto-snap) |
| Shift+L | Cycle layout (Pillars → Quads → Overlap → Auto) |
| Shift+H | Configure global hotkeys |
| Shift+S | Save snapback position |
| Shift+R | Restore snapback position |
| ? | Help screen |

---

## Global Hotkeys

Active whenever Matrix shader windows exist. Work from any application.

### Default Bindings
| Hotkey | Action |
|--------|--------|
| Ctrl+Shift+Left | Swap window left |
| Ctrl+Shift+Right | Swap window right |
| Ctrl+Shift+L | Cycle layout mode |
| Ctrl+Shift+B | Toggle transparency |
| Ctrl+Shift+J | Opacity down |
| Ctrl+Shift+K | Opacity up |
| Ctrl+Shift+Down | Speed up |
| Ctrl+Shift+Up | Speed down |
| Ctrl+Shift+1 | Toggle Far layer |
| Ctrl+Shift+2 | Toggle Mid layer |
| Ctrl+Shift+3 | Toggle Near layer |
| Ctrl+Shift+H | Show help overlay |
| Ctrl+Shift+F5 | Force shader reload |
| Ctrl+Shift+S | Snapback save |
| Ctrl+Shift+R | Snapback restore |

### User-Addable Actions (Red Pill)
These can be bound to any Ctrl+Shift+key via the hotkey config screen:
- Increase/Decrease Glow
- Increase/Decrease Width
- Increase/Decrease Trail
- Increase/Decrease Density
- Increase/Decrease Red, Green, Blue

---

## Preset System

### Save (Shift+P → S in Red Pill)
Saves all 11 current shader parameters to `~/.config/matrix-shader/presets/<name>.json`:
- RGB color (RAIN_R, RAIN_G, RAIN_B)
- Speed, Glow, Width, Trail, Density
- Layer visibility (SHOW_L1, SHOW_L2, SHOW_L3)

### Load (construct --preset)
```bash
construct --preset my-night-mode
```
Launches a new Matrix window with the exact saved configuration.

### Delete (Shift+P → D in Red Pill)
Select a preset and press D, then Y to confirm deletion.

---

## Layout Modes

| Mode | Description |
|------|-------------|
| Pillars | Side-by-side vertical columns, full screen height, 35px gaps |
| Quads | 2x2 grid with centered gap cross |
| Overlap | Stacked windows with configurable overlap percentage |
| Auto | Pillars for ≤4 windows, Quads for >4 |

## Glitch Mode

When enabled (Shift+G in Red Pill), Matrix windows auto-snap back to formation when they overlap each other. Manual resize and repositioning are NOT blocked — only overlapping windows trigger a snap-back.

Also triggers re-layout when a window is closed (remaining windows fill the screen) or when a new window is added.

---

## Shaders

### Color Presets
| Name | RGB |
|------|-----|
| Classic Green | 0.0, 1.0, 0.3 |
| Blue | 0.0, 0.6, 1.0 |
| Red | 1.0, 0.1, 0.1 |
| Purple | 0.7, 0.0, 1.0 |
| Gold | 1.0, 0.7, 0.0 |
| Teal | 0.0, 0.9, 0.9 |

### Bonus Shaders
- Aurora, Aurora Rain, Fireplace
- MatrixCodeVision (3D code tunnel — Red Pill background)
- Ultra, Rain on Glass
- White Room (3D CRT TV — construct picker)

### Configurable Parameters
| Parameter | Range | Default |
|-----------|-------|---------|
| RAIN_SPEED | 0.1 – 20.0 | 0.8 |
| GLOW_STRENGTH | 0.2 – 3.0 | 1.2 |
| CHAR_WIDTH | 6.0 – 20.0 | 8.0 |
| TRAIL_POWER | 4.0 – 15.0 | 8.0 |
| RAIN_DENSITY | 0.2 – 1.0 | 0.5 |
| RAIN_R/G/B | 0.0 – 1.0 | varies |
| SHOW_L1/L2/L3 | 0.0 or 1.0 | 1.0 |

---

## License

### Activation
```bash
redpill --activate REDPILL-XXXX-XXXX-XXXX-XXXX
```
Or paste the key when prompted on first `redpill` launch.

### Details
- One-time purchase ($5 Founder's Edition, normally $10)
- 3-machine limit per key
- First activation requires internet
- Fully offline after activation — no phone-home ever
- Key stored at `~/.config/matrix-shader/license.key`

---

## Installation

### Linux (any distro)
```bash
curl -sL matrixshader.com/linux | bash
```

### Ubuntu/Debian
```bash
sudo apt install ./matrix-shader_1.0.5_amd64.deb
```

### Fedora/RHEL
```bash
sudo dnf install ./matrix-shader-1.0.5.x86_64.rpm
```

### Windows
```powershell
irm matrixshader.com/install.ps1 | iex
```

### Uninstall
```bash
uninstall-matrix
```
