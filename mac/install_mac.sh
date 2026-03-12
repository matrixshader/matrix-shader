#!/bin/bash
# Matrix Shader - macOS Installer
# Standalone install script (also usable via curl | bash)
#
# Usage:
#   ./install_mac.sh              Install from release tarball (stock Ghostty)
#   ./install_mac.sh --patch      Install + build patched Ghostty for shader hot-reload

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
YELLOW='\033[0;33m'
RESET='\033[0m'

PATCH_GHOSTTY=false
for arg in "$@"; do
    case "$arg" in
        --patch) PATCH_GHOSTTY=true ;;
    esac
done

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗${RESET}"
echo -e "${GREEN}  ║     MATRIX SHADER - Mac Install      ║${RESET}"
echo -e "${GREEN}  ╚══════════════════════════════════════╝${RESET}"
echo ""

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_SUFFIX="x86_64" ;;
    arm64)   ARCH_SUFFIX="aarch64" ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${RESET}"
        exit 1
        ;;
esac

echo -e "${DIM}  Architecture: $ARCH ($ARCH_SUFFIX)${RESET}"

# Check for Ghostty (stock is OK -- we'll patch if --patch flag given)
GHOSTTY_FOUND=false
if [ -d "/Applications/Ghostty.app" ] || [ -d "$HOME/Applications/Ghostty.app" ] || command -v ghostty &>/dev/null; then
    GHOSTTY_FOUND=true
    echo -e "${DIM}  Ghostty: found${RESET}"
fi

if ! $GHOSTTY_FOUND && ! $PATCH_GHOSTTY; then
    echo -e "${RED}  Ghostty not found.${RESET}"
    echo -e "${DIM}  Install Ghostty first: brew install --cask ghostty${RESET}"
    echo -e "${DIM}  Then re-run this installer.${RESET}"
    echo ""
    echo -e "${DIM}  For full shader hot-reload support, use:${RESET}"
    echo -e "${CYAN}    ./install_mac.sh --patch${RESET}"
    echo ""
    exit 1
fi

# Install directory
INSTALL_DIR="$HOME/.local/share/matrix-shader"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/matrix-shader"

echo -e "${DIM}  Install dir: $INSTALL_DIR${RESET}"

# Download latest release
echo ""
echo -e "${GREEN}  Downloading Matrix Shader...${RESET}"

RELEASE_URL="https://github.com/matrixshader/matrix-shader/releases/latest/download/matrix-shader-mac-${ARCH_SUFFIX}.tar.gz"

mkdir -p "$INSTALL_DIR"

if curl -fsSL "$RELEASE_URL" -o /tmp/matrix-shader-mac.tar.gz 2>/dev/null; then
    tar xzf /tmp/matrix-shader-mac.tar.gz -C "$INSTALL_DIR" --strip-components=1
    rm -f /tmp/matrix-shader-mac.tar.gz
    echo -e "${DIM}  Downloaded and extracted.${RESET}"
else
    echo -e "${DIM}  Download failed -- using local files if available.${RESET}"
    # If running from the repo directory, copy local files
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/wakeupneo_mac.sh" ]; then
        cp -R "$SCRIPT_DIR/../" "$INSTALL_DIR/"
        echo -e "${DIM}  Copied from local repo.${RESET}"
    else
        echo -e "${RED}  No local files found. Please check your internet connection.${RESET}"
        exit 1
    fi
fi

# Create bin directory and symlinks
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/mac/wakeupneo_mac.sh" "$BIN_DIR/wakeupneo"
chmod +x "$BIN_DIR/wakeupneo"

echo -e "${DIM}  Created: $BIN_DIR/wakeupneo${RESET}"

# Create config directories
mkdir -p "$CONFIG_DIR/shaders"

# macOS convention symlink
APP_SUPPORT_DIR="$HOME/Library/Application Support/MatrixShader"
if [ ! -e "$APP_SUPPORT_DIR" ]; then
    ln -sf "$CONFIG_DIR" "$APP_SUPPORT_DIR"
fi

# Add to PATH (zsh -- macOS default shell)
SHELL_RC="$HOME/.zshrc"
if [ -f "$HOME/.bashrc" ] && [ ! -f "$SHELL_RC" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if ! grep -q 'matrix-shader' "$SHELL_RC" 2>/dev/null; then
    echo '' >> "$SHELL_RC"
    echo '# Matrix Shader' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo -e "${DIM}  Added to PATH in $SHELL_RC${RESET}"
fi

# Build patched Ghostty if requested
if $PATCH_GHOSTTY; then
    echo ""
    echo -e "${GREEN}  Building patched Ghostty for shader hot-reload...${RESET}"
    echo -e "${DIM}  This requires Xcode 15+ and takes a few minutes.${RESET}"
    echo ""

    # Check prerequisites
    if ! command -v xcodebuild &>/dev/null; then
        echo -e "${RED}  Xcode not found. Install from the App Store, then re-run with --patch.${RESET}"
        echo -e "${DIM}  Matrix Shader is installed but shader hot-reload won't work.${RESET}"
        echo -e "${DIM}  You can still use it -- changes just require reopening the window.${RESET}"
        PATCH_GHOSTTY=false
    fi
fi

if $PATCH_GHOSTTY; then
    GHOSTTY_SRC="$HOME/.local/share/matrix-shader/ghostty-src"
    PATCH_DIR="$INSTALL_DIR/mac/patches"

    # Download Zig 0.13.0 if needed
    ZIG_DIR="/tmp/zig-macos-${ARCH}-0.13.0"
    if [ ! -d "$ZIG_DIR" ]; then
        echo -e "${DIM}  Downloading Zig 0.13.0...${RESET}"
        ZIG_ARCH="$ARCH"
        [ "$ARCH" = "arm64" ] && ZIG_ARCH="aarch64"
        curl -sL "https://ziglang.org/download/0.13.0/zig-macos-${ZIG_ARCH}-0.13.0.tar.xz" | tar xJ -C /tmp
    fi

    # Clone Ghostty if not present
    if [ ! -d "$GHOSTTY_SRC" ]; then
        echo -e "${DIM}  Cloning Ghostty source...${RESET}"
        git clone https://github.com/ghostty-org/ghostty "$GHOSTTY_SRC"
    else
        echo -e "${DIM}  Resetting Ghostty source...${RESET}"
        cd "$GHOSTTY_SRC"
        git checkout -- . 2>/dev/null || true
    fi

    cd "$GHOSTTY_SRC"

    # Apply Metal shader hot-reload patch
    if [ -f "$PATCH_DIR/metal-shader-hotreload.patch" ]; then
        echo -e "${DIM}  Applying metal-shader-hotreload.patch...${RESET}"
        git apply "$PATCH_DIR/metal-shader-hotreload.patch"
    else
        echo -e "${RED}  Patch file not found: $PATCH_DIR/metal-shader-hotreload.patch${RESET}"
        echo -e "${DIM}  Skipping Ghostty build.${RESET}"
        cd "$HOME"
        PATCH_GHOSTTY=false
    fi
fi

if $PATCH_GHOSTTY; then
    # Build xcframework (Zig core)
    echo -e "${DIM}  Building Zig core (xcframework)...${RESET}"
    PATH="$ZIG_DIR:$PATH" zig build -Doptimize=ReleaseFast -Dapp-runtime=none -Demit-xcframework=true

    # Build macOS app (Xcode)
    echo -e "${DIM}  Building Ghostty.app (Xcode)...${RESET}"
    xcodebuild -project macos/Ghostty.xcodeproj -scheme Ghostty -configuration Release \
        -derivedDataPath build 2>&1 | tail -5

    BUILT_APP="build/Build/Products/Release/Ghostty.app"
    if [ -d "$BUILT_APP" ]; then
        echo -e "${GREEN}  Patched Ghostty built successfully!${RESET}"

        # Back up stock Ghostty if it exists
        for app_dir in "/Applications" "$HOME/Applications"; do
            if [ -d "$app_dir/Ghostty.app" ]; then
                if [ ! -d "$app_dir/Ghostty-stock.app" ]; then
                    echo -e "${DIM}  Backing up stock Ghostty to $app_dir/Ghostty-stock.app${RESET}"
                    cp -R "$app_dir/Ghostty.app" "$app_dir/Ghostty-stock.app"
                fi
                echo -e "${DIM}  Installing patched Ghostty to $app_dir/Ghostty.app${RESET}"
                rm -rf "$app_dir/Ghostty.app"
                cp -R "$BUILT_APP" "$app_dir/Ghostty.app"
                break
            fi
        done
    else
        echo -e "${RED}  Ghostty build failed. Shader hot-reload won't be available.${RESET}"
        echo -e "${DIM}  Matrix Shader still works -- changes just need window reopen.${RESET}"
    fi

    cd "$HOME"
fi

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗${RESET}"
echo -e "${GREEN}  ║   Matrix Shader installed!           ║${RESET}"
echo -e "${GREEN}  ╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "${DIM}  To start (open a new terminal first):${RESET}"
echo -e "${CYAN}    wakeupneo${RESET}"
echo ""
if ! $PATCH_GHOSTTY && $GHOSTTY_FOUND; then
    echo -e "${YELLOW}  Note: Using stock Ghostty.${RESET}"
    echo -e "${DIM}  Shader changes require closing and reopening the window.${RESET}"
    echo -e "${DIM}  For live hot-reload, reinstall with:${RESET}"
    echo -e "${CYAN}    ./install_mac.sh --patch${RESET}"
    echo ""
fi
echo -e "${DIM}  Global hotkeys require Accessibility permission.${RESET}"
echo -e "${DIM}  When prompted, grant access in:${RESET}"
echo -e "${DIM}    System Settings > Privacy & Security > Accessibility${RESET}"
echo ""
