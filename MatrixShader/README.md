# Matrix Shader - C# Rebuild

High-performance C#/.NET 8 implementation of Matrix Terminal Shader with Native AOT compilation.

## Features

- **Near-instant startup** (<500ms vs 60+ seconds in PowerShell)
- **Dual-mode rendering**:
  - **Full mode**: GPU shaders in Windows Terminal
  - **Lite mode**: Text-based ANSI fallback for any terminal
- **Single-file executables** with no runtime dependencies
- **Cross-platform text fallback** (Windows, Linux, macOS)

## Quick Start

```bash
# Setup wizard (first time)
./wakeupneo

# Quick launcher
./bluepill

# Control panel
./redpill
```

## Building

### Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Windows 10/11 (for full shader mode)

### Build Commands

```bash
# Debug build
dotnet build

# Release build
dotnet build -c Release

# Native AOT publish (Windows x64)
dotnet publish -c Release -r win-x64 --self-contained

# Native AOT publish (Linux x64)
dotnet publish -c Release -r linux-x64 --self-contained
```

### Output

Published executables will be in:
- `src/MatrixShader.Cli/Redpill/bin/Release/net8.0/win-x64/publish/redpill.exe`
- `src/MatrixShader.Cli/Bluepill/bin/Release/net8.0/win-x64/publish/bluepill.exe`
- `src/MatrixShader.Cli/WakeupNeo/bin/Release/net8.0/win-x64/publish/wakeupneo.exe`

## Project Structure

```
MatrixShader/
├── src/
│   ├── MatrixShader.Core/        # Shared library
│   │   ├── Models/               # Data models
│   │   ├── Services/             # Business logic
│   │   ├── Native/               # P/Invoke declarations
│   │   └── Constants/            # Colors, characters
│   │
│   ├── MatrixShader.Lite/        # Text-based renderer
│   │   ├── TextMatrixRenderer.cs # ANSI escape code renderer
│   │   ├── Column.cs             # Rain column logic
│   │   └── FallbackMenu.cs       # Simplified menu
│   │
│   ├── MatrixShader.Cli/         # Console applications
│   │   ├── Redpill/              # Control panel
│   │   ├── Bluepill/             # Quick launcher
│   │   └── WakeupNeo/            # Setup wizard
│   │
│   └── MatrixShader.Monitor/     # Background service
│
├── shaders/                      # HLSL pixel shaders
└── config/                       # Runtime configuration
```

## Applications

### redpill.exe - Control Panel

Full-featured control panel with:
- Tab-based shader window management (1-8)
- Real-time color adjustment (6 presets)
- Speed, glow, width, trail, density controls
- Layer toggles
- Layout management

### bluepill.exe - Quick Launcher

Instant Matrix rain with saved settings. No UI, just the effect.

### wakeupneo.exe - Setup Wizard

Interactive setup with "Blue Pill / Red Pill" choice:
- **Blue Pill**: Quick setup with defaults
- **Red Pill**: Full customization wizard

### matrix-monitor.exe - Background Service

Monitors Matrix windows for drag events and re-applies layouts automatically.

## Keyboard Controls

### Control Panel (redpill)

| Key | Action |
|-----|--------|
| 1-8 | Switch shader tab |
| 1-6 (Shift) | Color presets |
| E/R | Speed -/+ |
| G/H | Glow -/+ |
| W/T | Width -/+ |
| Y/U | Trail -/+ |
| D/F | Density -/+ |
| 7/8/9 | Toggle layers |
| S | Save |
| Q | Quit |

### Lite Mode

| Key | Action |
|-----|--------|
| 1-6 | Color presets |
| E/R | Speed -/+ |
| D/F | Density -/+ |
| Enter | Start/Stop rain |
| Q | Quit |

## Color Presets

1. **Green** - Classic Matrix
2. **Cyan** - Electric blue
3. **Red** - Sentinel alert
4. **Purple** - Cyber dreams
5. **Gold** - Machine city
6. **Teal** - Awakened

## Performance

| Metric | PowerShell | C# (Native AOT) |
|--------|------------|-----------------|
| Cold start | 60+ seconds | <500ms |
| Warm start | 5-10 seconds | <100ms |
| Keystroke response | 200-500ms | <16ms |
| Memory usage | ~200MB | <50MB |
| CPU idle | 5-10% | <1% |

## License

MIT License
