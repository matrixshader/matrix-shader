#!/bin/bash
# Matrix Shader - Hotkey Help Popup
# Spawns a small Ghostty window with the hotkey reference card.
# Closes on any keypress.

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
# After install, Python modules live in ~/.local/share/matrixshader/pylib/,
# not alongside this script in ~/.local/bin/. Fall back to SCRIPT_DIR for
# development (running from the repo).
PYMOD_DIR="$HOME/.local/share/matrixshader/pylib"
if [ ! -f "$PYMOD_DIR/hotkey_actions.py" ]; then
    PYMOD_DIR="$SCRIPT_DIR"
fi
export PYTHONPATH="$PYMOD_DIR:$PYTHONPATH"

# Find Ghostty binary
for gb in "$HOME/.local/share/matrixshader/ghostty" "$(which ghostty 2>/dev/null)"; do
    [ -x "$gb" ] && GHOSTTY_BIN="$gb" && break
done
[ -z "$GHOSTTY_BIN" ] && exit 1

MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"

# Generate help text — matches Windows HotkeyHelpOverlay.cs
HELP_FILE=$(mktemp "$MATRIX_TMP/matrix-help-XXXXXX.txt")

# Check license status
IS_REDPILL=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from hotkey_config import is_redpill
print('1' if is_redpill() else '0')
" 2>/dev/null || echo "0")

G='\033[38;2;110;220;170m'  # Bright green
C='\033[36m'                 # Cyan
D='\033[90m'                 # Dim
W='\033[97m'                 # White
Y='\033[33m'                 # Yellow
B='\033[1m'                  # Bold
R='\033[0m'                  # Reset
TL='╔'; TR='╗'; BL='╚'; BR='╝'; H='═'; V='║'; ML='╠'; MR='╣'
BW=54

pad() { printf "%-${1}s" "$2"; }

box() {
    local text="$1"
    # Strip ANSI for width calc
    local plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local vis=${#plain}
    local inner=$((BW - 2))
    local spaces=$((inner - vis))
    [ "$spaces" -lt 0 ] && spaces=0
    echo -e "  ${G}${V}${R}${text}$(printf '%*s' $spaces '')${G}${V}${R}"
}

hk() { box "  ${C}$(pad 24 "$1")${R}${W}$2${R}"; }

{
    echo
    echo -e "  ${G}${TL}$(printf '%*s' $((BW-2)) '' | tr ' ' '═')${TR}${R}"
    box "${G}${B}  M A T R I X   S H A D E R${R}"
    box "${D}  Reference Guide${R}"
    echo -e "  ${G}${ML}$(printf '%*s' $((BW-2)) '' | tr ' ' '═')${MR}${R}"
    box ""
    box "${G}${B}  WINDOW CONTROLS${R}"
    box ""
    hk "Ctrl+Shift+Left/Right" "Rotate windows"
    hk "Ctrl+Shift+L" "Cycle layout mode"
    box ""
    box "${G}${B}  VISUAL CONTROLS${R}"
    box ""
    hk "Ctrl+Shift+B" "Cycle transparency"
    hk "Ctrl+Shift+J / K" "Opacity down / up"
    hk "Ctrl+Shift+Down/Up" "Speed down / up"
    box ""
    box "${G}${B}  LAYER CONTROLS${R}"
    box ""
    hk "Ctrl+Shift+1" "Toggle Far layer"
    hk "Ctrl+Shift+2" "Toggle Mid layer"
    hk "Ctrl+Shift+3" "Toggle Near layer"
    box ""
    box "${G}${B}  SYSTEM${R}"
    box ""
    hk "Ctrl+Shift+F5" "Force shader reload"
    hk "Ctrl+Shift+H" "This overlay"
    box ""
    echo -e "  ${G}${ML}$(printf '%*s' $((BW-2)) '' | tr ' ' '═')${MR}${R}"
    box ""
    box "${G}${B}  COMMANDS${R}"
    box ""
    box "  ${C}wakeupneo${R}${W}          Setup wizard${R}"
    box "  ${C}construct${R}${W}          Launch Matrix terminal${R}"
    box "  ${C}construct --green${R}${W}  Quick launch (any color)${R}"
    box "  ${C}bluepill${R}${W}           Restore last session${R}"
    box "  ${C}redpill${R}${W}            Control panel (paid)${R}"
    box "  ${C}matrixlite${R}${W}         Text-mode rain${R}"
    box ""
    echo -e "  ${G}${ML}$(printf '%*s' $((BW-2)) '' | tr ' ' '═')${MR}${R}"
    if [ "$IS_REDPILL" = "0" ]; then
        box ""
        box "  ${Y}Unlock the full control panel${R}"
        box "  ${C}\033]8;;https://matrixshader.com/redpill\033\\matrixshader.com/redpill\033]8;;\033\\${R}"
    else
        box ""
        box "  ${G}Red Pill active. Full control unlocked.${R}"
    fi
    box ""
    echo -e "  ${G}${BL}$(printf '%*s' $((BW-2)) '' | tr ' ' '═')${BR}${R}"
    echo
} > "$HELP_FILE"

# Write temp config for help window
HELP_CONF=$(mktemp "$MATRIX_TMP/ghostty-help-XXXXXX.conf")
cat > "$HELP_CONF" <<EOF
background = #000000
foreground = #00ff4d
font-family = Nimbus Mono PS
font-size = 14
background-opacity = 0.9
gtk-titlebar = true
window-decoration = client
desktop-notifications = false
window-width = 60
window-height = 38
EOF

# Write a small display script so Ghostty -e gets a single executable path
# (avoids quoting issues with bash -c and Ghostty's argument splitting)
HELP_DISPLAY=$(mktemp "$MATRIX_TMP/matrix-help-display-XXXXXX.sh")
cat > "$HELP_DISPLAY" <<DISPLAYEOF
#!/bin/bash
cat '$HELP_FILE'
echo
echo '  Press any key to close...'
read -rsn1
DISPLAYEOF
chmod +x "$HELP_DISPLAY"

# Launch help window
"$GHOSTTY_BIN" --config-default-files=false --config-file="$HELP_CONF" \
    -e "$HELP_DISPLAY"

# Cleanup
rm -f "$HELP_CONF" "$HELP_FILE" "$HELP_DISPLAY"
