# Matrix Shader

Transform your terminal into The Matrix.

## Installation

### Option 1: Installer (Recommended)

1. Download `MatrixShaderSetup.exe` from the [Releases](../../releases) page
2. Run the installer
3. Open a **new** terminal window (required for PATH to update)
4. Run `wakeupneo` to complete setup

### Option 2: Build from Source

Requires: .NET 8 SDK, Windows 10/11

```powershell
git clone https://github.com/matrixshader/matrix-shader.git
cd matrix-shader
dotnet build MatrixShader/MatrixShader.sln
```

## Commands

After installation, these commands are available:

| Command | Description |
|---------|-------------|
| `wakeupneo` | First-time setup wizard - creates profiles, configures shaders |
| `bluepill` | Quick launch - restores previous session |
| `redpill` | Control panel - full keyboard-driven TUI for parameter tweaking |
| `matrixlite` | Text fallback - works in any terminal (no Windows Terminal required) |

## Quick Start

```
wakeupneo
```

That's it. Follow the prompts.

Or just dive in:

```
bluepill
```

## Hotkeys

Global hotkeys are available when running bluepill, redpill, or wakeupneo (the `matrix-hotkeys` background process starts automatically):

- `Win+Alt+Left/Right` - Swap windows
- `Win+Alt+L` - Change layout
- `Win+Alt+B` - Toggle transparency
- `Win+Alt+J/K` - Adjust opacity

To configure hotkeys, press `H` in the redpill control panel.

## Requirements

- Windows 10 version 1903+ or Windows 11
- Windows Terminal (installed automatically if missing)
- GPU with DirectX 11+ support (for shader mode)

**Note:** MatrixLite text mode works without Windows Terminal or GPU shaders.

## License

Copyright (c) 2026 matrixshader.com. All Rights Reserved.

Free for personal, non-commercial use.
Commercial use, redistribution, and modification require written permission.

---

Inspired by The Matrix (1999).
Not affiliated with or endorsed by Warner Bros. Entertainment Inc.

If you are a rights holder and are interested in collaboration,
please contact: architect@matrixshader.com
