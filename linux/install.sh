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

# Read installed version (if any)
CURRENT_VERSION=""
if [ -f "$INSTALL_DIR/VERSION" ]; then
    CURRENT_VERSION=$(cat "$INSTALL_DIR/VERSION")
fi

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

# Read release version from source
RELEASE_VERSION=""
if [ -f "$SOURCE_DIR/VERSION" ]; then
    RELEASE_VERSION=$(cat "$SOURCE_DIR/VERSION")
fi

# Version comparison: offer update or reinstall if already installed
if [ -n "$CURRENT_VERSION" ] && [ -n "$RELEASE_VERSION" ]; then
    echo -e "  ${DIM}Installed version: $CURRENT_VERSION${RESET}"
    echo -e "  ${DIM}Available version: $RELEASE_VERSION${RESET}"
    echo

    version_gt() {
        [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
    }

    if version_gt "$RELEASE_VERSION" "$CURRENT_VERSION"; then
        echo -e "  ${GREEN}Update available!${RESET}"
        read -p "  Update $CURRENT_VERSION -> $RELEASE_VERSION? (Y/n) " CHOICE
        [ "$CHOICE" = "n" ] || [ "$CHOICE" = "N" ] && exit 0
    else
        echo -e "  ${DIM}Already up to date.${RESET}"
        if [ -t 0 ]; then
            read -p "  Reinstall? (y/N) " CHOICE
            [ "$CHOICE" != "y" ] && [ "$CHOICE" != "Y" ] && exit 0
        else
            # Non-interactive (curl pipe) — always reinstall same version
            echo -e "  ${DIM}Reinstalling (non-interactive)...${RESET}"
        fi
    fi
    echo
fi

# Kill any running matrix processes
for proc in ghostty-matrix matrix-hotkey matrix_keys; do
    pkill -f "$proc" 2>/dev/null || true
done

# Detect existing Ghostty installs and warn about patched binary
SYSTEM_GHOSTTY=""
if command -v ghostty &>/dev/null; then
    SYSTEM_GHOSTTY=$(command -v ghostty)
fi

if [ -n "$SYSTEM_GHOSTTY" ]; then
    echo -e "  ${CYAN}Existing Ghostty detected:${RESET} ${DIM}$SYSTEM_GHOSTTY${RESET}"
    echo
    echo -e "  ${DIM}Matrix Shader bundles its own patched Ghostty binary.${RESET}"
    echo -e "  ${DIM}Your existing Ghostty will NOT be modified.${RESET}"
    echo
    echo -e "  ${DIM}Why a patched build?${RESET}"
    echo -e "  ${DIM}  1. GL_BLEND fix: lets shaders render true transparency${RESET}"
    echo -e "  ${DIM}  2. Shader hot-reload: live color/speed changes via D-Bus${RESET}"
    echo -e "  ${DIM}  3. Toast/keybind suppression: clean shader-only windows${RESET}"
    echo
    echo -e "  ${DIM}Matrix windows use the patched binary at:${RESET}"
    echo -e "  ${CYAN}  $GHOSTTY_BIN${RESET}"
    echo -e "  ${DIM}Your normal 'ghostty' command is unchanged.${RESET}"
    echo
fi

# Create directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$SHADER_DIR"

# Install Ghostty binary (patched for transparency)
echo -e "${DIM}  Installing patched Ghostty...${RESET}"
# rm before cp: running executables can't be overwritten (ETXTBSY) but can be
# unlinked — the running process keeps its file descriptor to the old inode
rm -f "$GHOSTTY_BIN" 2>/dev/null
cp "$SOURCE_DIR/bin/ghostty" "$GHOSTTY_BIN"
chmod +x "$GHOSTTY_BIN"

# Install shaders
echo -e "${DIM}  Installing shaders...${RESET}"
cp "$SOURCE_DIR/shaders/"*.glsl "$SHADER_DIR/"

# Install scripts
echo -e "${DIM}  Installing commands...${RESET}"
cp "$SOURCE_DIR/scripts/wakeupneo.sh" "$BIN_DIR/wakeupneo"
cp "$SOURCE_DIR/scripts/matrix_keys.py" "$BIN_DIR/matrix_keys.py"
cp "$SOURCE_DIR/scripts/bluepill.sh" "$BIN_DIR/bluepill"
cp "$SOURCE_DIR/scripts/matrix_watchdog.py" "$BIN_DIR/matrix_watchdog.py"

# Optional scripts (may not exist in all builds)
for script in matrix-opacity.sh matrix-hotkey-help.sh; do
    [ -f "$SOURCE_DIR/scripts/$script" ] && cp "$SOURCE_DIR/scripts/$script" "$BIN_DIR/$script"
done

# Install redpill command (without .sh extension for clean CLI)
if [ -f "$SOURCE_DIR/scripts/redpill.sh" ]; then
    cp "$SOURCE_DIR/scripts/redpill.sh" "$BIN_DIR/redpill"
    chmod +x "$BIN_DIR/redpill"
fi

# Install construct command
if [ -f "$SOURCE_DIR/scripts/construct.sh" ]; then
    rm -f "$BIN_DIR/construct" 2>/dev/null
    cp "$SOURCE_DIR/scripts/construct.sh" "$BIN_DIR/construct"
    chmod +x "$BIN_DIR/construct"
fi

# Install uninstaller
if [ -f "$SOURCE_DIR/scripts/uninstall.sh" ]; then
    cp "$SOURCE_DIR/scripts/uninstall.sh" "$BIN_DIR/uninstall-matrix"
    chmod +x "$BIN_DIR/uninstall-matrix"
fi

# Install matrixlite
if [ -f "$SOURCE_DIR/scripts/matrixlite_launcher.sh" ]; then
    cp "$SOURCE_DIR/scripts/matrixlite_launcher.sh" "$BIN_DIR/matrixlite"
    chmod +x "$BIN_DIR/matrixlite"
fi

# Python modules (TUI, services, layout engine)
PYMOD_DIR="$INSTALL_DIR/pylib"
mkdir -p "$PYMOD_DIR"
for pymod in shader_service.py state_service.py hotkey_actions.py hotkey_config.py \
             hotkey_config_screen.py hotkey_conflicts.py layout_engine.py \
             matrix_toast.py redpill_tui.py redpill_keys.py window_service.py \
             license_service.py machine_fingerprint.py matrixlite.py installer_helpers.py \
             construct_service.py command_banner.py; do
    [ -f "$SOURCE_DIR/scripts/$pymod" ] && cp "$SOURCE_DIR/scripts/$pymod" "$PYMOD_DIR/"
done

chmod +x "$BIN_DIR/wakeupneo" "$BIN_DIR/matrix_keys.py" "$BIN_DIR/bluepill" "$BIN_DIR/matrix_watchdog.py"
chmod +x "$BIN_DIR/"*.sh 2>/dev/null || true

# Patch script paths to use installed locations
sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYMOD_DIR\"|" "$BIN_DIR/wakeupneo"
sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$GHOSTTY_BIN\"|" "$BIN_DIR/wakeupneo"
sed -i "s|SHADER_DIR=.*|SHADER_DIR=\"$SHADER_DIR\"|" "$BIN_DIR/wakeupneo"
sed -i "s|^INSTALL_DIR=.*|INSTALL_DIR=\"$INSTALL_DIR\"|" "$BIN_DIR/wakeupneo"
sed -i "s|MATRIX_KEYS=.*|MATRIX_KEYS=\"$BIN_DIR/matrix_keys.py\"|" "$BIN_DIR/wakeupneo"
# Installed shaders have -ghostty suffix stripped by build-release.sh
sed -i 's/-ghostty\.glsl/.glsl/g' "$BIN_DIR/wakeupneo"

# Patch bluepill paths
sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYMOD_DIR\"|" "$BIN_DIR/bluepill"
sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$GHOSTTY_BIN\"|" "$BIN_DIR/bluepill"
sed -i "s|MATRIX_KEYS=.*|MATRIX_KEYS=\"$BIN_DIR/matrix_keys.py\"|" "$BIN_DIR/bluepill"
sed -i "s|WATCHDOG_SCRIPT=.*|WATCHDOG_SCRIPT=\"$BIN_DIR/matrix_watchdog.py\"|" "$BIN_DIR/bluepill"

# Patch redpill paths
if [ -f "$BIN_DIR/redpill" ]; then
    sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$GHOSTTY_BIN\"|" "$BIN_DIR/redpill"
    sed -i "s|TUI_SCRIPT=.*|TUI_SCRIPT=\"$PYMOD_DIR/redpill_tui.py\"|" "$BIN_DIR/redpill"
    sed -i "s|\${SCRIPT_DIR}/../shaders-glsl|$SHADER_DIR|g" "$BIN_DIR/redpill"
fi

# Patch construct paths
if [ -f "$BIN_DIR/construct" ]; then
    sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYMOD_DIR\"|" "$BIN_DIR/construct"
    sed -i "s|GHOSTTY_BIN=.*|GHOSTTY_BIN=\"$GHOSTTY_BIN\"|" "$BIN_DIR/construct"
    sed -i "s|SHADER_DIR=.*|SHADER_DIR=\"$SHADER_DIR\"|" "$BIN_DIR/construct"
fi

# Patch construct_service.py shader directory (shaders-glsl -> shaders)
if [ -f "$PYMOD_DIR/construct_service.py" ]; then
    sed -i 's|"shaders-glsl"|"shaders"|g' "$PYMOD_DIR/construct_service.py"
fi

# Patch redpill_tui.py Ghostty path (Python string, not shell variable)
if [ -f "$PYMOD_DIR/redpill_tui.py" ]; then
    sed -i "s|GHOSTTY_BIN = .*|GHOSTTY_BIN = \"$GHOSTTY_BIN\"|" "$PYMOD_DIR/redpill_tui.py"
fi

# Patch shader_service.py template paths — installed shaders are at
# ../shaders/ (not ../shaders-glsl/) but filenames keep -ghostty suffix
if [ -f "$PYMOD_DIR/shader_service.py" ]; then
    sed -i 's|"shaders-glsl"|"shaders"|g' "$PYMOD_DIR/shader_service.py"
fi

# Patch matrixlite paths
if [ -f "$BIN_DIR/matrixlite" ]; then
    sed -i "s|^PYMOD_DIR=.*|PYMOD_DIR=\"$PYMOD_DIR\"|" "$BIN_DIR/matrixlite"
fi

# Inject PYTHONPATH into Python scripts so they can find modules in PYMOD_DIR.
# matrix_keys.py and matrix_watchdog.py import from hotkey_actions, hotkey_config, etc.
# which live in PYMOD_DIR after install.
for pyscript in "$BIN_DIR/matrix_keys.py" "$BIN_DIR/matrix_watchdog.py"; do
    if [ -f "$pyscript" ]; then
        # Add sys.path.insert right after the shebang/docstring imports
        if ! grep -q "PYMOD_DIR" "$pyscript"; then
            sed -i "1a\\
import sys as _sys; _sys.path.insert(0, '$PYMOD_DIR')  # Added by install.sh" "$pyscript"
        fi
    fi
done

# Inject PYTHONPATH into shell scripts that run inline python3 -c
for shscript in "$BIN_DIR/wakeupneo" "$BIN_DIR/bluepill" "$BIN_DIR/construct"; do
    if [ -f "$shscript" ]; then
        sed -i "2a\\
export PYTHONPATH=\"$PYMOD_DIR:\$PYTHONPATH\"  # Added by install.sh" "$shscript"
    fi
done

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

# Deploy GNOME Shell extension for window positioning (GNOME Wayland only)
if command -v gnome-extensions &>/dev/null; then
    EXTENSION_SRC="$SOURCE_DIR/gnome-extension/matrix-window-manager@custom"
    EXTENSION_DST="$HOME/.local/share/gnome-shell/extensions/matrix-window-manager@custom"
    if [ -d "$EXTENSION_SRC" ]; then
        echo -e "${DIM}  Installing GNOME Shell extension for window positioning...${RESET}"
        rm -rf "$EXTENSION_DST"
        mkdir -p "$(dirname "$EXTENSION_DST")"
        cp -r "$EXTENSION_SRC" "$EXTENSION_DST"
        gnome-extensions enable matrix-window-manager@custom 2>/dev/null || true
        echo -e "${DIM}  GNOME extension installed (logout/login may be needed to activate)${RESET}"
    fi
fi

# Remove legacy GNOME hotkeys (evdev-based matrix-keys handles all hotkeys now)
if command -v gsettings >/dev/null 2>&1; then
    KEYS=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "[]")
    if [[ "$KEYS" == *"matrix-"* ]]; then
        echo -e "${DIM}  Removing legacy GNOME hotkeys (matrix-keys handles these now)...${RESET}"
        for slug in matrix-toggle matrix-up matrix-down matrix-help; do
            local_path="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${slug}/"
            gsettings reset "$local_path" name 2>/dev/null
            gsettings reset "$local_path" command 2>/dev/null
            gsettings reset "$local_path" binding 2>/dev/null
        done
        # Remove matrix entries from the keybindings list
        NEW_KEYS=$(echo "$KEYS" | sed "s|, '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/matrix-[^']*/'||g; s|'/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/matrix-[^']*/', ||g; s|'/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/matrix-[^']*/'||g")
        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW_KEYS" 2>/dev/null
    fi
fi

# Write version stamp
if [ -n "$RELEASE_VERSION" ]; then
    echo "$RELEASE_VERSION" > "$INSTALL_DIR/VERSION"
fi

echo
echo -e "${GREEN}  ================================${RESET}"
echo -e "${GREEN}  Matrix Shader installed!${RESET}"
echo -e "${GREEN}  ================================${RESET}"
echo
echo -e "  Commands available:"
echo -e "    ${CYAN}wakeupneo${RESET}        - Setup wizard (start here!)"
echo -e "    ${CYAN}construct${RESET}        - Launch individual Matrix terminal (--help for colors)"
echo -e "    ${CYAN}bluepill${RESET}         - Fast session restore"
echo -e "    ${CYAN}redpill${RESET}          - Control panel (advanced)"
echo -e "    ${CYAN}matrixlite${RESET}       - Text-mode rain (any terminal)"
echo -e "    ${CYAN}uninstall-matrix${RESET} - Remove Matrix Shader"
echo
echo -e "  Hotkeys:"
echo -e "    ${DIM}Ctrl+Shift+B   Toggle transparency${RESET}"
echo -e "    ${DIM}Ctrl+Shift+J/K Opacity down/up${RESET}"
echo -e "    ${DIM}Ctrl+Shift+H   Hotkey help${RESET}"
echo
# Auto-launch wakeupneo instead of asking user to open a new terminal.
# Use the full path to avoid PATH issues (login shells may not source .bashrc).
if [ ! -t 0 ]; then
    # curl-pipe mode: stdin is the pipe, reopen from tty
    exec "$BIN_DIR/wakeupneo" </dev/tty
else
    exec "$BIN_DIR/wakeupneo"
fi
# Fallback if exec fails (should not reach here)
echo -e "${DIM}  Open a new terminal, then type: ${CYAN}wakeupneo${RESET}"
echo
