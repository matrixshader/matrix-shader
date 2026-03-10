# Ghostty macOS Patches for Matrix Shader

## Patches

### metal-shader-hotreload.patch
Makes the Metal renderer always reinitialize custom shaders on config reload.
Stock Ghostty only reloads shaders when the config PATH changes, but Matrix Shader
rewrites shader file CONTENT in-place (same path, new #define values).

**Without this patch:** Changing rain speed/color/density via hotkeys won't update
the shader visually until the window is closed and reopened.

**With this patch:** Shader parameter changes take effect within ~100ms of the config reload.

## Applying Patches

```bash
cd ~/ghostty-build  # or wherever Ghostty source is
git apply /path/to/matrix-shader/mac/patches/metal-shader-hotreload.patch
```

## Building Ghostty for macOS

### Prerequisites
- macOS 13+ (Ventura or later)
- Xcode 15+ (with Command Line Tools)
- Zig 0.13.0

### Build Steps

```bash
# 1. Clone Ghostty (if not already)
git clone https://github.com/ghostty-org/ghostty ~/ghostty-build
cd ~/ghostty-build

# 2. Apply patches
git apply /path/to/matrix-shader/mac/patches/metal-shader-hotreload.patch

# 3. Build the xcframework (Zig core)
zig build -Doptimize=ReleaseFast -Dapp-runtime=none -Demit-xcframework=true

# 4. Build the macOS app (Xcode)
xcodebuild -project macos/Ghostty.xcodeproj -scheme Ghostty -configuration Release

# 5. The built app is at:
# build/Release/Ghostty.app
# Copy to /Applications/ or ~/Applications/
```

### Using Stock Ghostty (No Patches)
If shader hot-reload is not critical (e.g., only preset color changes), stock Ghostty
from the official release works fine. Shaders render correctly without patches --
only live parameter modification requires the hot-reload patch.

Install stock Ghostty: `brew install --cask ghostty`
