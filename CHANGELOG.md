# Changelog

All notable changes to Matrix Shader are documented here.

## v1.0.5 (2026-04-03)

### Features
- **Preset system** — Save, load, and delete custom shader configurations from the Red Pill control panel (Shift+P). Launch saved presets with `construct --preset <name>`.
- **Hotkey configuration** — Add, edit, disable, and remove global hotkeys from the Red Pill control panel (Shift+H). 14 new bindable actions: Glow, Width, Trail, Density, and RGB adjustments.
- **Color-matched window chrome** — Thin semi-transparent title bars tinted to match each window's shader color. Borderless look with visible close/minimize/maximize on hover.
- **Clickable URLs** — OSC 8 hyperlinks in all terminal output.
- **Positioning diagnostics** — Launch scripts now print extension status, window count, and monitor count when positioning windows.
- **Ghostty MIT license** — THIRD-PARTY-LICENSES.txt included in release.

### Fixes
- **Glitch mode** — Reverted to overlap-only detection. Glitch prevents windows from piling on each other but no longer intercepts manual resize or move. Snap restores full position and size.
- **Global GlitchToggle hotkey removed** — Was never approved. Glitch toggle is Shift+G inside Red Pill only.
- **Hotkey config screen** — Completely rewritten. Arrow key navigation works in Ghostty. All key bindings mappable (26 letters, 0-9, F1-F12, arrows).
- **Preset menu screen** — Completely rewritten. Visible text rendering in Ghostty. Save/load/delete all functional.
- **License activation** — `is_redpill()` now checks actual license key file instead of stale `redpill.json`.
- **Keyboard daemon** — Background thread for glitch checks (no more 700ms keyboard lag). Key repeat events no longer forwarded. Keyboard finder skips its own virtual device.
- **Gap sizing** — Fixed at 35px. No longer reads stale values from old state files.
- **Multi-user isolation** — All `/tmp` paths use per-user directories. All `pgrep` calls filter by user ID.
- **GNOME extension** — Auto-activation on first install. Catches all non-ACTIVE states.
- **Install terminal** — Closes properly after launching wakeupneo.
- **Watchdog** — Single-instance guard prevents duplicate watchdog processes.
- **Orphan recovery** — Monitor registers unregistered Matrix windows automatically.

### Security
- **HMAC secret removed from all client builds** — License validation is server-only. Secret stays on Vercel, never in tarballs, .deb, or .rpm packages.

### Platform
- Linux tarball, .deb (Ubuntu/Debian), .rpm (Fedora/RHEL) on GitHub Releases
- 764 tests passing
- Patched Ghostty binary (4 patches: shader hot-reload, GL_BLEND fix, toast suppression, keybind conflict)

## v1.0.4 (2026-03-14)

### Features
- **Construct** — CRT TV white room color picker with 3D wood cabinet, fullscreen zoom, arrow key browsing, CRT power-off animation.
- **7 GLSL shader ports** — All HLSL shaders ported to GLSL for Ghostty.
- **MatrixCodeVision** — New red pill background shader (replaces old corridor).
- **Opacity counters** — Overflow/underflow tracking for smooth opacity cycling.
- **Command banner** — Shows available commands after window launch.
- **Window filtering** — Red Pill TUI only shows Matrix shader windows, not other terminals.
- **Swap hotkey** — Swaps focused window with neighbor (matches Windows behavior).

### Fixes
- **Y-flip** — All HLSL-to-GLSL shader ports use correct UV flip for OpenGL.
- **Stale PID vaccine** — Dead PID purge on every window map load.

## v1.0.3 (2026-03-13)

### Features
- **MatrixLite** — Text-mode rain for any terminal (no GPU required). Synchronized output, dirty-cell rendering, 10-level palette, twinkling.
- **Installer** — `install.sh` with `curl | bash` support. Auto-detects Ghostty, installs GNOME extension, sets up PATH.
- **Uninstaller** — `uninstall-matrix` removes everything cleanly.

## v1.0.2 (2026-03-10)

### Features
- **Red Pill TUI** — Full curses-based control panel. Live parameter adjustment (speed, glow, width, trail, density), custom RGB, per-window layer toggles, multi-tab management, layout mode controls, snapback save/restore.
- **Layout engine** — Pillars, Quads, Overlap, Auto modes with gap scaling.
- **Hotkey system** — Global Ctrl+Shift hotkeys via evdev keyboard grab with UInput re-injection.
- **State persistence** — All settings saved to `~/.config/matrix-shader/state.json`.

## v1.0.1 (2026-03-09)

### Features
- **GNOME Shell extension** — D-Bus API for Wayland window positioning (MoveResize, GetGeometry, ListWindows, GetFocusedPid).
- **Focused window detection** — 4-level cascade: GNOME extension, ListWindows, Ghostty is-focused D-Bus, state.json fallback.

## v1.0.0 (2026-03-08)

### Features
- **Initial Linux port** — Matrix rain shaders running in patched Ghostty.
- **wakeupneo** — Setup wizard with splash animation, color picker, window launch.
- **bluepill** — Session restore from saved state.
- **GLSL shaders** — Green, Red, Blue, Purple, Gold, Teal rain effects.
