#!/bin/bash
# Matrix Shader - Bluepill (Linux/Ghostty)
# Fast session restore — "Straight into the Matrix Shader, Coppertop!"
# Linux equivalent of MatrixShader.Cli.Bluepill

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PYMOD_DIR="$SCRIPT_DIR"
SHADER_DIR="$(dirname "$SCRIPT_PATH")/../shaders-glsl"
GHOSTTY_BIN="/home/neo/ghostty-build/zig-out/bin/ghostty"
CONFIG_DIR="$HOME/.config/ghostty"
STATE_DIR="$HOME/.config/matrix-shader"
STATE_FILE="$STATE_DIR/state.json"
MATRIX_KEYS="$(dirname "$SCRIPT_PATH")/matrix_keys.py"
MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"
MATRIX_KEYS_PID="$MATRIX_TMP/matrix-keys.pid"
WATCHDOG_SCRIPT="$(dirname "$SCRIPT_PATH")/matrix_watchdog.py"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GOLD='\033[0;33m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

# Launch matrix_keys with input group access (handles pre-relogin sessions)
launch_matrix_keys() {
    # Ensure D-Bus session address is passed to background process
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
    if id -nG 2>/dev/null | grep -qw input; then
        nohup python3 -B "$MATRIX_KEYS" > $MATRIX_TMP/matrix-keys.log 2>&1 &
    else
        nohup sg input -c "DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS' python3 -B '$MATRIX_KEYS'" > $MATRIX_TMP/matrix-keys.log 2>&1 &
    fi
    disown
}

# Presets for foreground color lookup
PRESETS=(
    "Classic Green:0.0:1.0:0.3:#00ff4d"
    "Cyber Blue:0.0:0.6:1.0:#0099ff"
    "Blood Red:1.0:0.1:0.1:#ff1a1a"
    "Purple:0.7:0.0:1.0:#b300ff"
    "Gold:1.0:0.7:0.0:#ffb300"
    "Teal:0.0:0.9:0.9:#00e6e6"
)

# Activate GNOME extension if needed (first install only)
if [ "$1" != "--in-ghostty" ] && command -v gnome-extensions &>/dev/null; then
    EXT_STATE=$(gnome-extensions info matrix-window-manager@custom 2>/dev/null | grep "State:" | awk '{print $2}')
    if [ -n "$EXT_STATE" ] && [ "$EXT_STATE" != "ACTIVE" ] && [ "$EXT_STATE" != "ENABLED" ]; then
        echo -e "\033[32m  Activating window snapping...\033[0m"
        sleep 1
        pkill -SIGTERM -u "$(id -u)" gnome-shell 2>/dev/null
        for i in $(seq 1 20); do
            sleep 0.5
            NEW_STATE=$(gnome-extensions info matrix-window-manager@custom 2>/dev/null | grep "State:" | awk '{print $2}')
            [ "$NEW_STATE" = "ACTIVE" ] || [ "$NEW_STATE" = "ENABLED" ] && break
        done
        sleep 1
    fi
fi

# Self-relaunch inside Ghostty if not already there
if [ "$1" != "--in-ghostty" ]; then
    setup_conf="$MATRIX_TMP/ghostty-bluepill.conf"
    cat > "$setup_conf" <<'SETUPEOF'
background = #000000
foreground = #6EDCAA
font-family = Nimbus Mono PS
font-style = Bold
font-size = 16
background-opacity = 1
gtk-titlebar = true
window-decoration = client
SETUPEOF
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$setup_conf" -e "$SCRIPT_PATH" --in-ghostty >/dev/null 2>&1 &
    disown
    exit 0
fi

# --- Functions ---

get_open_slots() {
    local open=()
    for conf in $MATRIX_TMP/ghostty-matrix-*.conf; do
        [ -f "$conf" ] || continue
        local slot=$(echo "$conf" | grep -oP 'ghostty-matrix-\K\d+')
        # Filter to actual ghostty processes — pgrep -f matches claude/editor transcripts too
        for pid in $(pgrep -u "$(id -u)" -f "config-file=$conf" 2>/dev/null); do
            local exe=$(readlink /proc/$pid/exe 2>/dev/null)
            if [[ "$exe" == *ghostty* ]]; then
                open+=("$slot")
                break
            fi
        done
    done
    echo "${open[*]}"
}

go_transparent() {
    setup_conf="$MATRIX_TMP/ghostty-bluepill.conf"
    cat > "$setup_conf" <<TRANSEOF
background = #000000
foreground = #6EDCAA
font-family = Nimbus Mono PS
font-style = Bold
font-size = 16
background-opacity = 0
gtk-titlebar = true
window-decoration = client
TRANSEOF
    for busname in $(busctl --user list 2>/dev/null | awk '/ghostty/{print $1}'); do
        gdbus call --session --dest "$busname" \
            --object-path /com/mitchellh/ghostty \
            --method org.gtk.Actions.Activate \
            'reload-config' '[]' '{}' >/dev/null 2>&1
    done
    sleep 0.3
}

launch_window_from_state() {
    local slot=$1

    # Read shader config for this slot from state.json
    local shader_config
    shader_config=$(python3 -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from state_service import load_state
import json
state = load_state()
config = state.get('shader_configs', {}).get('$slot', {})
print(json.dumps(config))
" 2>/dev/null)

    # Create shader with ALL saved params baked in BEFORE Ghostty launches.
    # Single Python call: creates from template, writes RGB + speed + layers
    # atomically. No D-Bus reload (window doesn't exist yet).
    local shader_file
    shader_file=$(python3 -B -c "
import sys, json
sys.path.insert(0, '$PYMOD_DIR')
from shader_service import create_slot_shader, replace_define, atomic_write, SLOT_SHADER_DIR, PARAM_DEFAULTS
import os
config = json.loads('''$shader_config''') if '''$shader_config''' not in ('', '{}') else {}
r = config.get('RAIN_R', 0.0)
g = config.get('RAIN_G', 1.0)
b = config.get('RAIN_B', 0.3)
path = create_slot_shader($slot, r=r, g=g, b=b)
# Now write ALL remaining params directly into the shader file
non_rgb = {k: v for k, v in config.items() if k not in ('RAIN_R', 'RAIN_G', 'RAIN_B')}
if non_rgb:
    with open(path) as f:
        content = f.read()
    for param, value in non_rgb.items():
        if param in PARAM_DEFAULTS:
            content = replace_define(content, param, float(value))
    atomic_write(path, content)
print(path)
" 2>/dev/null)

    if [ -z "$shader_file" ] || [ ! -f "$shader_file" ]; then
        echo -e "   Matrix-${slot} ${RED}FAILED${RESET} (no shader file)"
        return
    fi

    # Read opacity from state
    local opacity
    opacity=$(python3 -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from state_service import load_state
state = load_state()
print(state.get('opacity', 85))
" 2>/dev/null || echo 85)
    local opacity_val
    opacity_val=$(awk "BEGIN {printf \"%.2f\", $opacity / 100}")
    # Clean up edge cases
    [ "$opacity_val" = "0.00" ] && opacity_val="0"
    [ "$opacity_val" = "1.00" ] && opacity_val="1"

    # Determine foreground color from RGB
    local fg
    fg=$(python3 -c "
import json, sys
c = json.loads('''$shader_config''') if '''$shader_config''' != '{}' else {}
r, g, b = c.get('RAIN_R', 0), c.get('RAIN_G', 1), c.get('RAIN_B', 0.3)
print('#%02x%02x%02x' % (int(r*255), int(g*255), int(b*255)))
" 2>/dev/null || echo "#00ff4d")

    # Generate color-matched borderless CSS
    local css_r css_g css_b
    css_r=$(python3 -c "import json; c=json.loads('''$shader_config''') if '''$shader_config'''!='{}' else {}; print(int(c.get('RAIN_R',0)*255))" 2>/dev/null || echo 0)
    css_g=$(python3 -c "import json; c=json.loads('''$shader_config''') if '''$shader_config'''!='{}' else {}; print(int(c.get('RAIN_G',1)*255))" 2>/dev/null || echo 255)
    css_b=$(python3 -c "import json; c=json.loads('''$shader_config''') if '''$shader_config'''!='{}' else {}; print(int(c.get('RAIN_B',0.3)*255))" 2>/dev/null || echo 77)
    local css_file="$MATRIX_TMP/ghostty-matrix-${slot}.css"
    cat > "$css_file" <<CSSEOF
@define-color headerbar_bg_color rgba(${css_r}, ${css_g}, ${css_b}, 0.15);
@define-color headerbar_backdrop_color rgba(${css_r}, ${css_g}, ${css_b}, 0.1);
@define-color headerbar_fg_color ${fg};
@define-color headerbar_border_color rgba(${css_r}, ${css_g}, ${css_b}, 0.3);
@define-color headerbar_shade_color rgba(0, 0, 0, 0);
headerbar { min-height: 22px; padding: 0 4px; border-bottom: 1px solid rgba(${css_r}, ${css_g}, ${css_b}, 0.2); }
headerbar button.titlebutton { min-height: 16px; min-width: 16px; padding: 2px; margin: 1px; color: ${fg}; opacity: 0.7; }
headerbar button.titlebutton:hover { opacity: 1; }
headerbar button.titlebutton.close:hover { color: #ff1a1a; }
headerbar .title { color: ${fg}; font-size: 10px; opacity: 0.6; }
CSSEOF

    local conf="$MATRIX_TMP/ghostty-matrix-${slot}.conf"
    cat > "$conf" <<EOF
custom-shader = ${shader_file}
background = #000000
foreground = ${fg}
font-family = Nimbus Mono PS
font-style = Bold
background-opacity = ${opacity_val}
gtk-titlebar = true
window-decoration = client
gtk-custom-css = ${css_file}
custom-shader-animation = always
desktop-notifications = false
keybind = ctrl+shift+j=unbind
keybind = ctrl+shift+k=unbind
keybind = ctrl+shift+b=unbind
keybind = ctrl+shift+h=unbind
keybind = ctrl+shift+l=unbind
keybind = ctrl+shift+one=unbind
keybind = ctrl+shift+two=unbind
keybind = ctrl+shift+three=unbind
keybind = ctrl+shift+up=unbind
keybind = ctrl+shift+down=unbind
keybind = ctrl+shift+left=unbind
keybind = ctrl+shift+right=unbind
keybind = ctrl+shift+f5=unbind
keybind = ctrl+shift+s=unbind
keybind = ctrl+shift+r=unbind
keybind = ctrl+shift+g=unbind
EOF

    echo -ne "   Waiting for Matrix-${slot}..."
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > $MATRIX_TMP/ghostty-matrix-${slot}.log 2>&1 &
    local ghostty_pid=$!
    # Register PID with window service for positioning (Phase 5/6)
    python3 "$PYMOD_DIR/window_service.py" register "$slot" "$ghostty_pid" 2>/dev/null
    sleep 0.3
    echo -e " ${GREEN}OK${RESET}"
}

# --- Main ---

clear
echo
echo -e "${GREEN} BLUEPILL - Enter the Matrix${RESET}"
echo -e "${DIM} ----------------------------------------${RESET}"
echo

# Check Ghostty
if [ ! -f "$GHOSTTY_BIN" ]; then
    echo -e "${RED} Ghostty not found at $GHOSTTY_BIN${RESET}"
    sleep 3
    exit 1
fi

# Load saved slots from state.json
saved_slots=$(python3 -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from state_service import load_state
state = load_state()
slots = sorted(state.get('shader_configs', {}).keys())
print(' '.join(slots))
" 2>/dev/null)

if [ -z "$saved_slots" ]; then
    echo -e "${DIM} No saved session found.${RESET}"
    echo -e "${DIM} Run ${CYAN}wakeupneo${DIM} to create your Matrix first.${RESET}"
    echo
    sleep 3
    exit 0
fi

echo -e "${GREEN} Restoring session...${RESET}"
echo -e "${DIM}   Saved slots: [${saved_slots}]${RESET}"
echo

# Detect already-open windows
open_slots=($(get_open_slots))

# Go transparent
go_transparent
clear
echo
echo -e "${GREEN} Restoring session...${RESET}"
echo

launched=0
skipped=0

for slot in $saved_slots; do
    # Skip if already open
    if [[ " ${open_slots[*]} " == *" $slot "* ]]; then
        echo -e "   Matrix-${slot} ${DIM}already open${RESET}"
        ((skipped++))
        continue
    fi

    launch_window_from_state "$slot"
    ((launched++))
done

if [ "$skipped" -gt 0 ]; then
    echo
    echo -e "${DIM}   Skipped ${skipped} already-open window(s)${RESET}"
fi

# Apply layout to position windows with proper gaps
sleep 0.5
python3 -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from layout_engine import apply_current_layout
n = apply_current_layout()
if n > 0:
    print(f'   Positioned {n} window(s) in layout')
" 2>/dev/null || true

# Start hotkey listener if not running
echo
if [ -f "$MATRIX_KEYS_PID" ]; then
    pid=$(cat "$MATRIX_KEYS_PID")
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN} Hotkeys...${RESET} ${DIM}already running${RESET}"
    else
        rm -f "$MATRIX_KEYS_PID"
        launch_matrix_keys
        echo -e "${GREEN} Starting hotkeys...${RESET} ${WHITE}OK${RESET}"
    fi
else
    launch_matrix_keys
    echo -e "${GREEN} Starting hotkeys...${RESET} ${WHITE}OK${RESET}"
fi

# Start watchdog if not running
if [ -f "$WATCHDOG_SCRIPT" ]; then
    watchdog_pid="$MATRIX_TMP/matrix-watchdog.pid"
    if [ -f "$watchdog_pid" ] && kill -0 "$(cat "$watchdog_pid")" 2>/dev/null; then
        : # Watchdog already running
    else
        nohup python3 "$WATCHDOG_SCRIPT" > /dev/null 2>&1 &
        disown
    fi
fi

# Final status
echo
echo -e "${GREEN} THE MATRIX HAS YOU.${RESET}"

echo
echo -e "${DIM} ----------------------------------------${RESET}"
echo -e " ${CYAN}GLOBAL HOTKEYS${RESET} ${DIM}(Ctrl+Shift+H for full reference)${RESET}"
echo
echo -e "${DIM}   Ctrl+Shift+B            Toggle transparency${RESET}"
echo -e "${DIM}   Ctrl+Shift+J / K        Opacity down / up${RESET}"
echo -e "${DIM}   Ctrl+Shift+H            Hotkey help overlay${RESET}"

echo
echo -e "${DIM} Enjoying Matrix Shader? Buy me a coffee:${RESET}"
echo -e "${GOLD} https://buymeacoffee.com/IKnowKungFu${RESET}"
echo

# Command reference banner
python3 -B "$PYMOD_DIR/command_banner.py" 2>/dev/null

sleep infinity
