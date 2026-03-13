#!/bin/bash
# Matrix Shader - Uninstaller
# Removes Matrix Shader from your system
# Ported from Windows installer/uninstall.ps1

set -e

INSTALL_DIR="$HOME/.local/share/matrixshader"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/matrix-shader"
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions/matrix-window-manager@custom"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo
echo -e "${RED}  Matrix Shader Uninstaller${RESET}"
echo -e "${RED}  =========================${RESET}"
echo

# Step 0: Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}  Matrix Shader not found at $INSTALL_DIR${RESET}"
    if [ -d "$CONFIG_DIR" ]; then
        echo
        echo -e "${YELLOW}  User data found: $CONFIG_DIR${RESET}"
        read -p "  Remove user data (settings, sessions)? (y/N) " REMOVE_DATA
        if [ "$REMOVE_DATA" = "y" ] || [ "$REMOVE_DATA" = "Y" ]; then
            rm -rf "$CONFIG_DIR"
            echo -e "${GREEN}  User data removed.${RESET}"
        fi
    fi
    echo
    echo -e "${DIM}  Nothing to uninstall.${RESET}"
    exit 0
fi

echo -e "${DIM}  Found: $INSTALL_DIR${RESET}"
echo

# Confirm
read -p "  Uninstall Matrix Shader? (y/N) " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${DIM}  Cancelled.${RESET}"
    exit 0
fi
echo

# Step 1: Kill running processes
echo -e "${CYAN}[1/7] Stopping running processes...${RESET}"
for proc in "ghostty.*config-file.*matrix" matrix_keys matrix_watchdog redpill_tui matrixlite bluepill; do
    pkill -f "$proc" 2>/dev/null || true
done
sleep 1
echo -e "${DIM}  Done${RESET}"

# Step 2: Remove installed files
echo -e "${CYAN}[2/7] Removing installed files...${RESET}"
rm -rf "$INSTALL_DIR"
echo -e "${DIM}  Removed $INSTALL_DIR${RESET}"

# Step 3: Remove commands from BIN_DIR
echo -e "${CYAN}[3/7] Removing commands...${RESET}"
for cmd in wakeupneo bluepill redpill matrixlite uninstall-matrix matrix_keys.py matrix_watchdog.py matrix-opacity.sh matrix-hotkey-help.sh; do
    rm -f "$BIN_DIR/$cmd"
done
echo -e "${DIM}  Removed commands from $BIN_DIR${RESET}"

# Step 4: Clean PATH from shell rc files
echo -e "${CYAN}[4/7] Cleaning PATH from shell config...${RESET}"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
        if grep -q '# Matrix Shader' "$rc"; then
            sed -i '/^# Matrix Shader$/,/^export PATH.*\.local\/bin/d' "$rc"
            echo -e "${DIM}  Cleaned $(basename "$rc")${RESET}"
        fi
    fi
done

# Step 5: Remove GNOME extension
echo -e "${CYAN}[5/7] Removing GNOME extension...${RESET}"
if [ -d "$GNOME_EXT_DIR" ]; then
    gnome-extensions disable matrix-window-manager@custom 2>/dev/null || true
    rm -rf "$GNOME_EXT_DIR"
    echo -e "${DIM}  Removed GNOME extension${RESET}"
else
    echo -e "${DIM}  No GNOME extension found${RESET}"
fi

# Step 6: User data prompt
echo -e "${CYAN}[6/7] User data...${RESET}"
if [ -d "$CONFIG_DIR" ]; then
    echo -e "${DIM}  Found user data: $CONFIG_DIR${RESET}"
    echo -e "${DIM}  This includes: settings, session state${RESET}"
    read -p "  Remove user data (settings, sessions)? (y/N) " REMOVE_DATA
    if [ "$REMOVE_DATA" = "y" ] || [ "$REMOVE_DATA" = "Y" ]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}  User data removed.${RESET}"
    else
        echo -e "${DIM}  User data preserved.${RESET}"
    fi
else
    echo -e "${DIM}  No user data found.${RESET}"
fi

# Step 7: Done
echo -e "${CYAN}[7/7] Complete${RESET}"
echo
echo -e "${GREEN}  Matrix Shader uninstalled.${RESET}"
echo
