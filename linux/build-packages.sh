#!/bin/bash
# Matrix Shader - Linux Package Builder
# Creates .deb and .rpm packages for GUI installer experience
#
# Usage: ./build-packages.sh
#
# Prerequisites: fpm (gem install fpm), rpmbuild, dpkg-deb
# Requires: build-release.sh to have been run first (uses same staged files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GHOSTTY_BIN="$HOME/ghostty-build/zig-out/bin/ghostty"

GREEN='\033[0;32m'
DIM='\033[2m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${GREEN}  Matrix Shader - Linux Package Builder${RESET}"
echo -e "${GREEN}  ======================================${RESET}"
echo ""

# Check prerequisites
if ! command -v fpm &>/dev/null; then
    echo -e "${RED}  fpm not found. Install: sudo gem install fpm${RESET}"
    exit 1
fi

if ! command -v rpmbuild &>/dev/null; then
    echo -e "${RED}  rpmbuild not found. Install: sudo dnf install rpm-build${RESET}"
    exit 1
fi

if ! command -v dpkg-deb &>/dev/null; then
    echo -e "${RED}  dpkg-deb not found. Install: sudo dnf install dpkg${RESET}"
    exit 1
fi

# Verify patched Ghostty binary
if [ ! -f "$GHOSTTY_BIN" ]; then
    echo -e "${RED}  Patched Ghostty binary not found at: $GHOSTTY_BIN${RESET}"
    exit 1
fi

# Read version
VERSION=$(grep -oP '<Version>\K[^<]+' "$PROJECT_DIR/MatrixShader/Directory.Build.props" 2>/dev/null || echo "1.0.0")
echo -e "${DIM}  Version: $VERSION${RESET}"

# Install paths
INSTALL_BASE="/opt/matrixshader"
BIN_DEST="$INSTALL_BASE/bin"
SHADER_DEST="$INSTALL_BASE/shaders"
PYLIB_DEST="$INSTALL_BASE/pylib"
SYMLINK_DIR="/usr/local/bin"

# Create staging directory mirroring final filesystem
STAGING=$(mktemp -d)
trap "rm -rf $STAGING" EXIT

mkdir -p "$STAGING$BIN_DEST"
mkdir -p "$STAGING$SHADER_DEST"
mkdir -p "$STAGING$PYLIB_DEST"
mkdir -p "$STAGING$SYMLINK_DIR"
mkdir -p "$STAGING/usr/share/gnome-shell/extensions"

# 1. Ghostty binary
echo -e "${DIM}  Staging Ghostty binary...${RESET}"
cp "$GHOSTTY_BIN" "$STAGING$BIN_DEST/ghostty"
chmod +x "$STAGING$BIN_DEST/ghostty"

# 2. Shaders
echo -e "${DIM}  Staging shaders...${RESET}"
for shader in "$PROJECT_DIR/shaders-glsl/"*-ghostty.glsl; do
    [ -f "$shader" ] || continue
    cp "$shader" "$STAGING$SHADER_DEST/"
done

# 3. Shell scripts (copy then patch paths for system install)
echo -e "${DIM}  Staging scripts...${RESET}"

# wakeupneo
cp "$SCRIPT_DIR/wakeupneo.sh" "$STAGING$BIN_DEST/wakeupneo"
chmod +x "$STAGING$BIN_DEST/wakeupneo"
sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYLIB_DEST\"|" "$STAGING$BIN_DEST/wakeupneo"
sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$BIN_DEST/ghostty\"|" "$STAGING$BIN_DEST/wakeupneo"
sed -i "s|SHADER_DIR=.*|SHADER_DIR=\"$SHADER_DEST\"|" "$STAGING$BIN_DEST/wakeupneo"
sed -i "s|^INSTALL_DIR=.*|INSTALL_DIR=\"$INSTALL_BASE\"|" "$STAGING$BIN_DEST/wakeupneo"
sed -i "s|MATRIX_KEYS=.*|MATRIX_KEYS=\"$BIN_DEST/matrix_keys.py\"|" "$STAGING$BIN_DEST/wakeupneo"
sed -i 's/-ghostty\.glsl/.glsl/g' "$STAGING$BIN_DEST/wakeupneo"
# Add PYTHONPATH
sed -i "2a\\
export PYTHONPATH=\"$PYLIB_DEST:\$PYTHONPATH\"  # Added by build-packages.sh" "$STAGING$BIN_DEST/wakeupneo"

# bluepill
cp "$SCRIPT_DIR/bluepill.sh" "$STAGING$BIN_DEST/bluepill"
chmod +x "$STAGING$BIN_DEST/bluepill"
sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYLIB_DEST\"|" "$STAGING$BIN_DEST/bluepill"
sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$BIN_DEST/ghostty\"|" "$STAGING$BIN_DEST/bluepill"
sed -i "s|MATRIX_KEYS=.*|MATRIX_KEYS=\"$BIN_DEST/matrix_keys.py\"|" "$STAGING$BIN_DEST/bluepill"
sed -i "s|WATCHDOG_SCRIPT=.*|WATCHDOG_SCRIPT=\"$BIN_DEST/matrix_watchdog.py\"|" "$STAGING$BIN_DEST/bluepill"
sed -i "2a\\
export PYTHONPATH=\"$PYLIB_DEST:\$PYTHONPATH\"  # Added by build-packages.sh" "$STAGING$BIN_DEST/bluepill"

# redpill
if [ -f "$SCRIPT_DIR/redpill.sh" ]; then
    cp "$SCRIPT_DIR/redpill.sh" "$STAGING$BIN_DEST/redpill"
    chmod +x "$STAGING$BIN_DEST/redpill"
    sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$BIN_DEST/ghostty\"|" "$STAGING$BIN_DEST/redpill"
    sed -i "s|TUI_SCRIPT=.*|TUI_SCRIPT=\"$PYLIB_DEST/redpill_tui.py\"|" "$STAGING$BIN_DEST/redpill"
fi

# construct
if [ -f "$SCRIPT_DIR/construct.sh" ]; then
    cp "$SCRIPT_DIR/construct.sh" "$STAGING$BIN_DEST/construct"
    chmod +x "$STAGING$BIN_DEST/construct"
    sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYLIB_DEST\"|" "$STAGING$BIN_DEST/construct"
    sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$BIN_DEST/ghostty\"|" "$STAGING$BIN_DEST/construct"
    sed -i "s|SHADER_DIR=.*|SHADER_DIR=\"$SHADER_DEST\"|" "$STAGING$BIN_DEST/construct"
    sed -i "2a\\
export PYTHONPATH=\"$PYLIB_DEST:\$PYTHONPATH\"  # Added by build-packages.sh" "$STAGING$BIN_DEST/construct"
fi

# matrixlite launcher
if [ -f "$SCRIPT_DIR/matrixlite_launcher.sh" ]; then
    cp "$SCRIPT_DIR/matrixlite_launcher.sh" "$STAGING$BIN_DEST/matrixlite"
    chmod +x "$STAGING$BIN_DEST/matrixlite"
    sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYLIB_DEST\"|" "$STAGING$BIN_DEST/matrixlite"
fi

# matrix_keys.py and matrix_watchdog.py
cp "$SCRIPT_DIR/matrix_keys.py" "$STAGING$BIN_DEST/"
cp "$SCRIPT_DIR/matrix_watchdog.py" "$STAGING$BIN_DEST/"
chmod +x "$STAGING$BIN_DEST/matrix_keys.py" "$STAGING$BIN_DEST/matrix_watchdog.py"
# Inject PYTHONPATH into Python scripts
for pyscript in "$STAGING$BIN_DEST/matrix_keys.py" "$STAGING$BIN_DEST/matrix_watchdog.py"; do
    if [ -f "$pyscript" ] && ! grep -q "PYMOD_DIR" "$pyscript"; then
        sed -i "1a\\
import sys as _sys; _sys.path.insert(0, '$PYLIB_DEST')  # Added by build-packages.sh" "$pyscript"
    fi
done

# Optional helper scripts
for optional in matrix-opacity.sh matrix-hotkey-help.sh; do
    if [ -f "$SCRIPT_DIR/$optional" ]; then
        cp "$SCRIPT_DIR/$optional" "$STAGING$BIN_DEST/$optional"
        chmod +x "$STAGING$BIN_DEST/$optional"
    fi
done

# uninstall script
if [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
    cp "$SCRIPT_DIR/uninstall.sh" "$STAGING$BIN_DEST/uninstall-matrix"
    chmod +x "$STAGING$BIN_DEST/uninstall-matrix"
fi

# 4. Python modules
echo -e "${DIM}  Staging Python modules...${RESET}"
for pymod in shader_service.py state_service.py hotkey_actions.py hotkey_config.py \
             hotkey_config_screen.py hotkey_conflicts.py layout_engine.py \
             matrix_toast.py redpill_tui.py redpill_keys.py window_service.py \
             license_service.py machine_fingerprint.py matrixlite.py installer_helpers.py \
             construct_service.py command_banner.py; do
    [ -f "$SCRIPT_DIR/$pymod" ] && cp "$SCRIPT_DIR/$pymod" "$STAGING$PYLIB_DEST/"
done

# Patch construct_service.py shader dir
if [ -f "$STAGING$PYLIB_DEST/construct_service.py" ]; then
    sed -i 's|"shaders-glsl"|"shaders"|g' "$STAGING$PYLIB_DEST/construct_service.py"
fi

# Patch shader_service.py shader dir
if [ -f "$STAGING$PYLIB_DEST/shader_service.py" ]; then
    sed -i 's|"shaders-glsl"|"shaders"|g' "$STAGING$PYLIB_DEST/shader_service.py"
fi

# Patch redpill_tui.py Ghostty path
if [ -f "$STAGING$PYLIB_DEST/redpill_tui.py" ]; then
    sed -i "s|GHOSTTY_BIN = .*|GHOSTTY_BIN = \"$BIN_DEST/ghostty\"|" "$STAGING$PYLIB_DEST/redpill_tui.py"
fi

# 5. License secret
LICENSE_SECRET_VALUE="${LICENSE_SECRET:-}"
if [ -z "$LICENSE_SECRET_VALUE" ]; then
    LICENSE_SECRET_FILE="$SCRIPT_DIR/../MatrixShader/license-secret.key"
    if [ -f "$LICENSE_SECRET_FILE" ]; then
        LICENSE_SECRET_VALUE=$(cat "$LICENSE_SECRET_FILE")
    fi
fi
if [ -n "$LICENSE_SECRET_VALUE" ]; then
    cat > "$STAGING$PYLIB_DEST/_license_secret.py" <<PYEOF
# Auto-generated by build-packages.sh — do not edit
SECRET = "${LICENSE_SECRET_VALUE}"
PYEOF
    echo -e "${DIM}  License secret embedded${RESET}"
else
    echo -e "${DIM}  Warning: no license secret${RESET}"
fi

# 6. GNOME Shell extension
EXTENSION_SRC="$SCRIPT_DIR/gnome-extension/matrix-window-manager@custom"
if [ -d "$EXTENSION_SRC" ]; then
    echo -e "${DIM}  Staging GNOME extension...${RESET}"
    cp -r "$EXTENSION_SRC" "$STAGING/usr/share/gnome-shell/extensions/"
fi

# 7. VERSION file
echo "$VERSION" > "$STAGING$INSTALL_BASE/VERSION"

# 8. Create symlinks in /usr/local/bin
echo -e "${DIM}  Creating symlinks...${RESET}"
for cmd in wakeupneo bluepill redpill construct matrixlite; do
    if [ -f "$STAGING$BIN_DEST/$cmd" ]; then
        ln -sf "$BIN_DEST/$cmd" "$STAGING$SYMLINK_DIR/$cmd"
    fi
done
ln -sf "$BIN_DEST/uninstall-matrix" "$STAGING$SYMLINK_DIR/uninstall-matrix" 2>/dev/null || true

# 9. Create postinstall script
POSTINSTALL=$(mktemp)
cat > "$POSTINSTALL" <<'POSTEOF'
#!/bin/bash
# Post-install: add user to input group for evdev hotkeys
REAL_USER="${SUDO_USER:-$USER}"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    if ! id -nG "$REAL_USER" | grep -qw input; then
        usermod -aG input "$REAL_USER" 2>/dev/null || true
    fi
fi

# Enable GNOME extension if available
if command -v gnome-extensions &>/dev/null; then
    gnome-extensions enable matrix-window-manager@custom 2>/dev/null || true
fi

echo ""
echo "  Matrix Shader installed!"
echo ""
echo "  Commands:"
echo "    wakeupneo    - Setup wizard (start here!)"
echo "    construct    - Launch Matrix terminal"
echo "    bluepill     - Fast session restore"
echo "    redpill      - Control panel"
echo "    matrixlite   - Text-mode rain (any terminal)"
echo ""
echo "  Open a new terminal, then type: wakeupneo"
echo ""
POSTEOF
chmod +x "$POSTINSTALL"

# 10. Create preremove script
PREREMOVE=$(mktemp)
cat > "$PREREMOVE" <<'RMEOF'
#!/bin/bash
# Kill matrix processes before removal
for proc in ghostty-matrix matrix-hotkey matrix_keys; do
    pkill -f "$proc" 2>/dev/null || true
done
RMEOF
chmod +x "$PREREMOVE"

# 11. Build packages
OUTPUT_DIR="$PROJECT_DIR/linux/output"
mkdir -p "$OUTPUT_DIR"

echo -e "${DIM}  Building .deb package...${RESET}"
fpm -s dir \
    -t deb \
    --name matrix-shader \
    --version "$VERSION" \
    --architecture x86_64 \
    --description "GPU-powered Matrix rain effects for your terminal" \
    --url "https://matrixshader.com" \
    --license "BSL-1.1" \
    --vendor "Matrix Shader" \
    --maintainer "Matrix Shader <hello@matrixshader.com>" \
    --depends python3 \
    --depends python3-evdev \
    --after-install "$POSTINSTALL" \
    --before-remove "$PREREMOVE" \
    --force \
    -p "$OUTPUT_DIR/matrix-shader_${VERSION}_amd64.deb" \
    -C "$STAGING" \
    . 2>&1 | sed 's/^/  /'

echo -e "${DIM}  Building .rpm package...${RESET}"
fpm -s dir \
    -t rpm \
    --name matrix-shader \
    --version "$VERSION" \
    --architecture x86_64 \
    --description "GPU-powered Matrix rain effects for your terminal" \
    --url "https://matrixshader.com" \
    --license "BSL-1.1" \
    --vendor "Matrix Shader" \
    --maintainer "Matrix Shader <hello@matrixshader.com>" \
    --depends python3 \
    --depends python3-evdev \
    --after-install "$POSTINSTALL" \
    --before-remove "$PREREMOVE" \
    --force \
    -p "$OUTPUT_DIR/matrix-shader-${VERSION}.x86_64.rpm" \
    -C "$STAGING" \
    . 2>&1 | sed 's/^/  /'

# Clean up temp scripts
rm -f "$POSTINSTALL" "$PREREMOVE"

echo ""
echo -e "${GREEN}  Packages built successfully!${RESET}"
echo ""
for pkg in "$OUTPUT_DIR"/*.deb "$OUTPUT_DIR"/*.rpm; do
    [ -f "$pkg" ] && echo -e "  ${CYAN}$(basename "$pkg")${RESET}  $(du -sh "$pkg" | cut -f1)"
done
echo ""
echo -e "${DIM}  Install (Fedora):  sudo dnf install $OUTPUT_DIR/matrix-shader-${VERSION}.x86_64.rpm${RESET}"
echo -e "${DIM}  Install (Ubuntu):  sudo apt install $OUTPUT_DIR/matrix-shader_${VERSION}_amd64.deb${RESET}"
echo -e "${DIM}  Or double-click the .deb in a file manager on Ubuntu/Debian${RESET}"
echo ""
