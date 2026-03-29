#!/bin/bash
# Matrix Shader - Linux Release Builder
# Creates matrixshader-linux-x86_64.tar.gz for GitHub release
#
# Usage: ./build-release.sh [--ghostty-bin PATH]
#
# By default, uses ~/ghostty-build/zig-out/bin/ghostty as the patched binary.
# Override with --ghostty-bin to use a different binary location.
#
# To build Ghostty from source with patches:
#   ./build-release.sh --build-ghostty

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GHOSTTY_BIN="$HOME/ghostty-build/zig-out/bin/ghostty"
BUILD_GHOSTTY=false

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --ghostty-bin)
            GHOSTTY_BIN="$2"
            shift 2
            ;;
        --build-ghostty)
            BUILD_GHOSTTY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

GREEN='\033[0;32m'
DIM='\033[2m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "${GREEN}  Matrix Shader - Linux Release Builder${RESET}"
echo -e "${GREEN}  ======================================${RESET}"
echo ""

# Build Ghostty from source if requested
if $BUILD_GHOSTTY; then
    echo -e "${DIM}  Building patched Ghostty from source...${RESET}"

    GHOSTTY_SRC="$HOME/ghostty-build"
    ZIG_DIR="/tmp/zig-linux-x86_64-0.13.0"

    # Ensure Zig 0.13.0 is available
    if [ ! -d "$ZIG_DIR" ]; then
        echo -e "${DIM}  Downloading Zig 0.13.0...${RESET}"
        curl -sL https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar xJ -C /tmp
    fi

    # Clone Ghostty if not present
    if [ ! -d "$GHOSTTY_SRC" ]; then
        echo -e "${DIM}  Cloning Ghostty...${RESET}"
        git clone https://github.com/ghostty-org/ghostty "$GHOSTTY_SRC"
    fi

    # Apply patches — reset to upstream tag first so patches apply cleanly
    # whether or not previous patch commits exist in the local repo
    echo -e "${DIM}  Applying Matrix Shader patches...${RESET}"
    cd "$GHOSTTY_SRC"
    git reset --hard v1.1.3 2>/dev/null || git checkout -- . 2>/dev/null || true
    git apply "$SCRIPT_DIR/patches/01-shader-hotreload-glblend.patch"
    git apply "$SCRIPT_DIR/patches/02-suppress-toast-and-keybinds.patch"

    # Build
    echo -e "${DIM}  Compiling (this takes a few minutes)...${RESET}"
    PATH="$ZIG_DIR:$PATH" zig build -Doptimize=ReleaseFast -Dapp-runtime=gtk
    GHOSTTY_BIN="$GHOSTTY_SRC/zig-out/bin/ghostty"
    cd "$PROJECT_DIR"
fi

# Verify patched Ghostty binary exists
if [ ! -f "$GHOSTTY_BIN" ]; then
    echo -e "${RED}  Patched Ghostty binary not found at: $GHOSTTY_BIN${RESET}"
    echo -e "${DIM}  Build it first:${RESET}"
    echo -e "${DIM}    $0 --build-ghostty${RESET}"
    echo -e "${DIM}  Or specify location:${RESET}"
    echo -e "${DIM}    $0 --ghostty-bin /path/to/ghostty${RESET}"
    exit 1
fi

# Verify it's a real binary
if ! file "$GHOSTTY_BIN" | grep -q "ELF.*64-bit"; then
    echo -e "${RED}  $GHOSTTY_BIN is not a valid Linux x86_64 binary${RESET}"
    exit 1
fi

echo -e "${DIM}  Ghostty binary: $GHOSTTY_BIN${RESET}"

# Create staging directory
STAGING=$(mktemp -d)
trap "rm -rf $STAGING" EXIT

RELEASE_DIR="$STAGING/matrixshader-linux-x86_64"
mkdir -p "$RELEASE_DIR"/{bin,shaders,scripts,gnome-extension}

# 1. Copy patched Ghostty binary
echo -e "${DIM}  Staging Ghostty binary...${RESET}"
cp "$GHOSTTY_BIN" "$RELEASE_DIR/bin/ghostty"
chmod +x "$RELEASE_DIR/bin/ghostty"

# 2. Copy GLSL shaders
echo -e "${DIM}  Staging shaders...${RESET}"
for shader in "$PROJECT_DIR/shaders-glsl/"*-ghostty.glsl; do
    [ -f "$shader" ] || continue
    # Keep original filename — shader_service.py expects the -ghostty suffix
    basename=$(basename "$shader")
    cp "$shader" "$RELEASE_DIR/shaders/$basename"
done

# 3. Copy scripts
echo -e "${DIM}  Staging scripts...${RESET}"
cp "$SCRIPT_DIR/wakeupneo.sh"      "$RELEASE_DIR/scripts/"
cp "$SCRIPT_DIR/matrix_keys.py"    "$RELEASE_DIR/scripts/"
cp "$SCRIPT_DIR/bluepill.sh"       "$RELEASE_DIR/scripts/"
cp "$SCRIPT_DIR/matrix_watchdog.py" "$RELEASE_DIR/scripts/"

# Optional scripts (may not exist in all builds)
for optional in matrix-opacity.sh matrix-hotkey-help.sh; do
    [ -f "$SCRIPT_DIR/$optional" ] && cp "$SCRIPT_DIR/$optional" "$RELEASE_DIR/scripts/"
done

# Copy Python modules needed by scripts
for pymod in shader_service.py state_service.py hotkey_actions.py hotkey_config.py \
             hotkey_config_screen.py hotkey_conflicts.py layout_engine.py \
             matrix_toast.py redpill_tui.py redpill_keys.py window_service.py \
             license_service.py machine_fingerprint.py command_banner.py \
             construct_service.py preset_service.py preset_menu_screen.py; do
    [ -f "$SCRIPT_DIR/$pymod" ] && cp "$SCRIPT_DIR/$pymod" "$RELEASE_DIR/scripts/"
done

# Copy redpill launcher
[ -f "$SCRIPT_DIR/redpill.sh" ] && cp "$SCRIPT_DIR/redpill.sh" "$RELEASE_DIR/scripts/"

# Copy construct launcher
[ -f "$SCRIPT_DIR/construct.sh" ] && cp "$SCRIPT_DIR/construct.sh" "$RELEASE_DIR/scripts/"

# Copy uninstaller
[ -f "$SCRIPT_DIR/uninstall.sh" ] && cp "$SCRIPT_DIR/uninstall.sh" "$RELEASE_DIR/scripts/"

# Copy matrixlite
[ -f "$SCRIPT_DIR/matrixlite.py" ] && cp "$SCRIPT_DIR/matrixlite.py" "$RELEASE_DIR/scripts/"
[ -f "$SCRIPT_DIR/matrixlite_launcher.sh" ] && cp "$SCRIPT_DIR/matrixlite_launcher.sh" "$RELEASE_DIR/scripts/"
[ -f "$SCRIPT_DIR/installer_helpers.py" ] && cp "$SCRIPT_DIR/installer_helpers.py" "$RELEASE_DIR/scripts/"

chmod +x "$RELEASE_DIR/scripts/"*.sh "$RELEASE_DIR/scripts/"*.py 2>/dev/null || true

# 4. Copy GNOME Shell extension
EXTENSION_SRC="$SCRIPT_DIR/gnome-extension/matrix-window-manager@custom"
if [ -d "$EXTENSION_SRC" ]; then
    echo -e "${DIM}  Staging GNOME extension...${RESET}"
    cp -r "$EXTENSION_SRC" "$RELEASE_DIR/gnome-extension/"
fi

# 5. Copy installer
echo -e "${DIM}  Staging installer...${RESET}"
cp "$SCRIPT_DIR/install.sh" "$RELEASE_DIR/"
chmod +x "$RELEASE_DIR/install.sh"

# Write version stamp from Directory.Build.props (package.json moved to private repo)
PACKAGE_VERSION=$(grep -oP '<Version>\K[^<]+' "$PROJECT_DIR/MatrixShader/Directory.Build.props" 2>/dev/null || echo "1.0.0")
echo "$PACKAGE_VERSION" > "$RELEASE_DIR/VERSION"
echo -e "${DIM}  Version: $PACKAGE_VERSION${RESET}"

# 6. Create tarball
OUTPUT="$PROJECT_DIR/matrixshader-linux-x86_64.tar.gz"
echo -e "${DIM}  Creating tarball...${RESET}"
cd "$STAGING"
tar czf "$OUTPUT" "matrixshader-linux-x86_64"

SIZE=$(du -sh "$OUTPUT" | cut -f1)

echo ""
echo -e "${GREEN}  Release built successfully!${RESET}"
echo -e "${DIM}  Output: $OUTPUT${RESET}"
echo -e "${DIM}  Size:   $SIZE${RESET}"
echo ""
echo -e "${DIM}  Contents:${RESET}"
tar tzf "$OUTPUT" | head -30
echo -e "${DIM}  ...${RESET}"
echo ""
echo -e "${DIM}  Upload to GitHub release:${RESET}"
echo -e "${DIM}    gh release upload vX.Y.Z $OUTPUT${RESET}"
echo ""
