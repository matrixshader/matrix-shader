# Ghostty Linux Patches for Matrix Shader

Apply these patches to Ghostty source (tested against v1.1.3) before building.

## Patches

### 01-shader-hotreload-glblend.patch
Two critical rendering fixes:

1. **Shader hot-reload** — Defers shader reload from `changeConfig()` to `drawFrame()` for
   GTK GL context safety. Without this, changing shader parameters via D-Bus has no effect.

2. **GL_BLEND fix** — Disables blending during custom shader pass. Ghostty leaves `GL_BLEND`
   enabled, causing alpha to blend against black instead of being written directly. Also
   switches framebuffer texture format from RGB to RGBA for proper transparency.

### 02-suppress-toast-and-keybinds.patch
UX tweaks for Matrix Shader integration:

1. **Toast suppression** — Suppresses "Reloaded the configuration" toast in `Window.zig`.
   Matrix Shader fires config reloads on every hotkey press (opacity/shader changes via
   D-Bus), making the toast extremely disruptive.

2. **Keybind conflict** — Removes default `Ctrl+Shift+J` binding (`write_screen_file = paste`)
   from `Config.zig`. Conflicts with Matrix Shader's opacity-down hotkey.

## Applying

```bash
cd ~/ghostty-source
git apply /path/to/matrix-shader/linux/patches/01-shader-hotreload-glblend.patch
git apply /path/to/matrix-shader/linux/patches/02-suppress-toast-and-keybinds.patch
```

## Building

Requires Zig 0.13.0 and GTK development libraries.

```bash
# Download Zig 0.13.0 if not installed
ZIG_DIR="/tmp/zig-linux-x86_64-0.13.0"
if [ ! -d "$ZIG_DIR" ]; then
    curl -sL https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar xJ -C /tmp
fi

# Build
cd ~/ghostty-source
PATH="$ZIG_DIR:$PATH" zig build -Doptimize=ReleaseFast -Dapp-runtime=gtk

# Binary at: zig-out/bin/ghostty
```
