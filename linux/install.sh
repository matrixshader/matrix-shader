#!/bin/bash
# Matrix Shader - Linux Installer
# Usage: curl -sL matrixshader.com/linux | bash
#   or:  ./install.sh (after extracting tarball)
#
# Installs patched Ghostty + shaders + commands to ~/.local

set -e

GREEN='\033[0;32m'
DIM='\033[2m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

INSTALL_DIR="$HOME/.local/share/matrixshader"
BIN_DIR="$HOME/.local/bin"
SHADER_DIR="$INSTALL_DIR/shaders"
GHOSTTY_BIN="$INSTALL_DIR/ghostty"

echo
echo -e "${GREEN}  Matrix Shader - Linux Installer${RESET}"
echo -e "${GREEN}  ================================${RESET}"
echo

# Detect if running from extracted tarball or piped from curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/bin/ghostty" ]; then
    # Running from extracted tarball
    SOURCE_DIR="$SCRIPT_DIR"
else
    # Running from curl pipe - download release
    echo -e "${DIM}  Downloading latest release...${RESET}"
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    # Get latest release tarball URL from GitHub
    RELEASE_URL=$(curl -sL https://api.github.com/repos/matrixshader/matrix-shader/releases/latest \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]*linux-x86_64\.tar\.gz' | head -1)

    if [ -z "$RELEASE_URL" ]; then
        # Fallback to direct URL
        RELEASE_URL="https://github.com/matrixshader/matrix-shader/releases/latest/download/matrixshader-linux-x86_64.tar.gz"
    fi

    curl -sL "$RELEASE_URL" | tar xz -C "$TMPDIR"
    SOURCE_DIR=$(find "$TMPDIR" -name "ghostty" -path "*/bin/*" -exec dirname {} \; | head -1)
    SOURCE_DIR=$(dirname "$SOURCE_DIR")

    if [ ! -f "$SOURCE_DIR/bin/ghostty" ]; then
        echo -e "${RED}  Download failed. Try manual install:${RESET}"
        echo -e "${CYAN}  https://github.com/matrixshader/matrix-shader/releases${RESET}"
        exit 1
    fi
    echo -e "${GREEN}  Downloaded.${RESET}"
    echo
fi

# Kill any running matrix processes
for proc in ghostty-matrix matrix-hotkey matrix_keys; do
    pkill -f "$proc" 2>/dev/null || true
done

# Create directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$SHADER_DIR"

# Install Ghostty binary (patched for transparency)
echo -e "${DIM}  Installing patched Ghostty...${RESET}"
cp "$SOURCE_DIR/bin/ghostty" "$GHOSTTY_BIN"
chmod +x "$GHOSTTY_BIN"

# Install shaders
echo -e "${DIM}  Installing shaders...${RESET}"
cp "$SOURCE_DIR/shaders/"*.glsl "$SHADER_DIR/"

# Install scripts
echo -e "${DIM}  Installing commands...${RESET}"
cp "$SOURCE_DIR/scripts/wakeupneo.sh" "$BIN_DIR/wakeupneo"
cp "$SOURCE_DIR/scripts/matrix-opacity.sh" "$BIN_DIR/matrix-opacity.sh"
cp "$SOURCE_DIR/scripts/matrix-hotkey-help.sh" "$BIN_DIR/matrix-hotkey-help.sh"
cp "$SOURCE_DIR/scripts/matrix_keys.py" "$BIN_DIR/matrix_keys.py"
chmod +x "$BIN_DIR/wakeupneo" "$BIN_DIR/matrix-opacity.sh" "$BIN_DIR/matrix-hotkey-help.sh" "$BIN_DIR/matrix_keys.py"

# Patch script paths to use installed locations
sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$GHOSTTY_BIN\"|" "$BIN_DIR/wakeupneo"
sed -i "s|SHADER_DIR=.*|SHADER_DIR=\"$SHADER_DIR\"|" "$BIN_DIR/wakeupneo"
sed -i "s|MATRIX_KEYS=.*|MATRIX_KEYS=\"$BIN_DIR/matrix_keys.py\"|" "$BIN_DIR/wakeupneo"

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${DIM}  Adding ~/.local/bin to PATH...${RESET}"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q 'matrixshader' "$rc"; then
                echo '' >> "$rc"
                echo '# Matrix Shader' >> "$rc"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
            fi
        fi
    done
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install evdev hotkey listener dependency
echo -e "${DIM}  Setting up hotkey listener...${RESET}"
if python3 -c "import evdev" 2>/dev/null; then
    echo -e "${DIM}  python3-evdev: OK${RESET}"
else
    echo -e "${DIM}  Installing python3-evdev...${RESET}"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3-evdev >/dev/null 2>&1 || pip3 install --user evdev 2>/dev/null
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y python3-evdev >/dev/null 2>&1 || pip3 install --user evdev 2>/dev/null
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm python-evdev >/dev/null 2>&1 || pip3 install --user evdev 2>/dev/null
    else
        pip3 install --user evdev 2>/dev/null
    fi

    if python3 -c "import evdev" 2>/dev/null; then
        echo -e "${DIM}  python3-evdev: installed${RESET}"
    else
        echo -e "${RED}  python3-evdev: FAILED - hotkeys will use GNOME fallback${RESET}"
    fi
fi

# Ensure user can read /dev/input (needed for evdev hotkeys)
if ! groups | grep -qw input; then
    echo -e "${DIM}  Adding $USER to input group (for global hotkeys)...${RESET}"
    sudo usermod -aG input "$USER" 2>/dev/null && \
        echo -e "${DIM}  Added - log out and back in to take effect${RESET}" || \
        echo -e "${RED}  Could not add to input group - hotkeys may need sudo${RESET}"
fi

# Register GNOME hotkeys as fallback (if on GNOME)
if command -v gsettings >/dev/null 2>&1; then
    echo -e "${DIM}  Registering GNOME hotkey fallbacks...${RESET}"

    KEYS=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "[]")

    register_hotkey() {
        local name="$1" cmd="$2" binding="$3" slug="$4"
        local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${slug}/"
        if [[ "$KEYS" != *"$slug"* ]]; then
            KEYS=$(echo "$KEYS" | sed "s/]/, '$path']/; s/\[, /[/")
        fi
        gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" name "$name" 2>/dev/null
        gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" command "$cmd" 2>/dev/null
        gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" binding "$binding" 2>/dev/null
    }

    register_hotkey "Matrix Toggle" "$BIN_DIR/matrix-opacity.sh toggle" "<Ctrl><Shift>b" "matrix-toggle"
    register_hotkey "Matrix Opacity Up" "$BIN_DIR/matrix-opacity.sh up" "<Ctrl><Shift>k" "matrix-up"
    register_hotkey "Matrix Opacity Down" "$BIN_DIR/matrix-opacity.sh down" "<Ctrl><Shift>j" "matrix-down"
    register_hotkey "Matrix Help" "$BIN_DIR/matrix-hotkey-help.sh" "<Ctrl><Shift>h" "matrix-help"

    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$KEYS" 2>/dev/null
fi

echo
echo -e "${GREEN}  ================================${RESET}"
echo -e "${GREEN}  Matrix Shader installed!${RESET}"
echo -e "${GREEN}  ================================${RESET}"
echo
echo -e "  Commands available:"
echo -e "    ${CYAN}wakeupneo${RESET}  - Setup wizard (start here!)"
echo
echo -e "  Hotkeys:"
echo -e "    ${DIM}Ctrl+Shift+B   Toggle transparency${RESET}"
echo -e "    ${DIM}Ctrl+Shift+J/K Opacity down/up${RESET}"
echo -e "    ${DIM}Ctrl+Shift+H   Hotkey help${RESET}"
echo
echo -e "${DIM}  Open a new terminal, then type: ${CYAN}wakeupneo${RESET}"
echo
