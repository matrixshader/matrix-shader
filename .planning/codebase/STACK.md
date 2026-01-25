# Technology Stack

**Analysis Date:** 2026-01-25

## Languages

**Primary:**
- PowerShell 5.1+ - Core scripting, control panel, setup wizard, multi-window management
- HLSL (High-Level Shading Language) - GPU shader rendering for Matrix rain effect and visual effects

**Secondary:**
- JavaScript (Node.js) - NPM wrapper scripts for CLI entry points
- C# - P/Invoke bindings for Windows API calls (compiled to DLL or embedded)

## Runtime

**Environment:**
- Windows PowerShell 5.1+ or PowerShell Core
- Node.js 14.0.0+ (for npm package wrapping)
- Windows 10/11 with Windows Terminal

**Package Manager:**
- npm (Node Package Manager)
- Lockfile: Not detected (no package-lock.json found)

## Frameworks

**Core:**
- Windows Terminal - Terminal emulator that hosts and renders shaders
- Direct3D / Windows Terminal Shader System - GPU rendering pipeline

**Shader System:**
- HLSL Pixel Shaders - 6 main shader slots (Matrix-1.hlsl through Matrix-6.hlsl) plus specialized shaders
- Custom Neo Vision Shader - `shaders/Redpill-Neo.hlsl` - 3D box corridor with SDF text rendering

**Build/Dev:**
- PowerShell Compilation - Compiles C# P/Invoke code inline or precompiled to `MatrixAPI.dll`
- Node.js CLI - Spawns native executables through npm bin entry points

## Key Dependencies

**Critical:**
- Windows API P/Invoke Bindings - user32.dll functions:
  - EnumWindows - Window enumeration
  - SetWindowPos - Window positioning
  - GetWindowText - Window title retrieval
  - EnumDisplayMonitors - Multi-monitor detection
  - UI Automation (UIAutomationCore) - Terminal profile detection and window identity

**Infrastructure:**
- System.Windows.Forms - Screen detection and monitor topology
- System.Diagnostics.Process - Window process identification
- WMI (Windows Management Instrumentation) - Process command-line arguments retrieval
- Windows Registry - Shader-to-window mapping persistence

**Development:**
- MatrixAPI.dll - Precompiled P/Invoke wrapper (optional, compiled inline as fallback)

## Configuration

**Environment:**
- `$env:USERPROFILE\Documents\Matrix` - Project root directory
- `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` - Windows Terminal settings integration
- `$env:MATRIX_DEBUG=1` - Debug logging control (MatrixLogging.ps1)

**Build:**
- `package.json` - NPM metadata for npm package release
- `bin/native/` - Compiled executables:
  - `bluepill.exe` - Instant launch CLI
  - `redpill.exe` - Control panel CLI
  - `wakeupneo.exe` - Setup wizard CLI
- Shader library: `shaders/` directory with 10+ .hlsl files

## File Encoding

**Requirement:**
- PowerShell files: CRLF line endings (Windows-native)
- HLSL shaders: LF or CRLF (shader compiler agnostic)
- JSON configs: UTF-8 with BOM (Windows Terminal compatible)

## Configuration Files

**State Management:**
- `matrix_state.json` - Persists slots, layout mode, monitor count, gap size
- `window-registry.json` - Shader-to-window instance mapping
- `identity-registry.json` - Launch tracking and window identity resolution
- `config/slots.json` - Slot configuration

**Project Metadata:**
- `prd.json` - User stories and project roadmap (Ralph-compatible)
- `.claude/settings.local.json` - Claude Code agent settings

## Platform Requirements

**Development:**
- Windows 10 or 11
- PowerShell 5.1 or Core
- Windows Terminal (latest version)
- Node.js 14+
- C# compiler (for P/Invoke compilation, optional if using precompiled DLL)

**Production:**
- Windows 10 or 11
- Windows Terminal
- GPU with Direct3D 11+ support
- npm for package installation

## Package Distribution

**NPM Package:**
- Name: `matrix-shader`
- Version: 2.0.0
- Files included:
  - `bin/` - CLI entry points and native executables
  - `shaders/` - Shader library (10+ HLSL files)
  - `README.md` - Documentation
  - `LICENSE` - SEE LICENSE IN LICENSE

**Repository:**
- GitHub: `github.com/matrixshader/matrix-shader`
- Licensed: Custom (Free for personal use, commercial use requires permission)

---

*Stack analysis: 2026-01-25*
