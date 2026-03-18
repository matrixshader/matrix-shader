#!/bin/bash
# Matrix Shader - Bluepill (macOS/Ghostty)
# Fast session restore — "Straight into the Matrix Shader, Coppertop!"
# macOS port of linux/bluepill.sh

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PYMOD_DIR="$SCRIPT_DIR"
LINUX_DIR="$SCRIPT_DIR/../linux"
SHADER_DIR="$SCRIPT_DIR/../shaders-glsl"
STATE_DIR="$HOME/.config/matrix-shader"
STATE_FILE="$STATE_DIR/state.json"
MATRIX_KEYS="$SCRIPT_DIR/matrix_keys_mac.py"
MATRIX_KEYS_PID="/tmp/matrix-keys.pid"

# Detect Ghostty binary
if [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
    GHOSTTY_BIN="/Applications/Ghostty.app/Contents/MacOS/ghostty"
elif [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
    GHOSTTY_BIN="$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
elif command -v ghostty &>/dev/null; then
    GHOSTTY_BIN="$(command -v ghostty)"
else
    GHOSTTY_BIN=""
fi

# Detect font
# Instant font detection via file existence (not system_profiler which takes 20-60s)
if [ -f "/Library/Fonts/NimbusMonoPS-Regular.otf" ] || [ -f "$HOME/Library/Fonts/NimbusMonoPS-Regular.otf" ]; then
    FONT="Nimbus Mono PS"
elif [ -f "/System/Library/Fonts/SFMono-Regular.otf" ] || [ -f "/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/SFMono-Regular.otf" ]; then
    FONT="SF Mono"
else
    FONT="Menlo"
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GOLD='\033[0;33m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

# Presets for foreground color lookup
PRESETS=(
    "Classic Green:0.0:1.0:0.3:#00ff4d"
    "Cyber Blue:0.0:0.6:1.0:#0099ff"
    "Blood Red:1.0:0.1:0.1:#ff1a1a"
    "Purple:0.7:0.0:1.0:#b300ff"
    "Gold:1.0:0.7:0.0:#ffb300"
    "Teal:0.0:0.9:0.9:#00e6e6"
)

# Self-relaunch inside Ghostty if not already there
if [ "$1" != "--in-ghostty" ]; then
    if [ -z "$GHOSTTY_BIN" ]; then
        echo "Error: Ghostty not found"
        exit 1
    fi
    setup_conf="/tmp/ghostty-bluepill.conf"
    cat > "$setup_conf" <<SETUPEOF
background = #000000
foreground = #6EDCAA
font-family = ${FONT}
font-style = Bold
font-size = 16
background-opacity = 1
macos-titlebar-style = hidden
SETUPEOF
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$setup_conf" -e "$SCRIPT_PATH" --in-ghostty >/dev/null 2>&1 &
    disown
    exit 0
fi

# --- Functions ---

get_open_slots() {
    local open=()
    for conf in /tmp/ghostty-matrix-*.conf; do
        [ -f "$conf" ] || continue
        local slot=$(echo "$conf" | grep -oE 'ghostty-matrix-[0-9]+' | grep -oE '[0-9]+')
        # Check if a ghostty process is using this config
        if ps aux 2>/dev/null | grep -v grep | grep -q "config-file=$conf"; then
            open+=("$slot")
        fi
    done
    echo "${open[*]}"
}

go_transparent() {
    setup_conf="/tmp/ghostty-bluepill.conf"
    cat > "$setup_conf" <<TRANSEOF
background = #000000
foreground = #6EDCAA
font-family = ${FONT}
font-style = Bold
font-size = 16
background-opacity = 0
macos-titlebar-style = hidden
TRANSEOF
    # Reload all Ghostty instances via SIGHUP
    for pid in $(pgrep -f "ghostty" 2>/dev/null); do
        kill -HUP "$pid" 2>/dev/null
    done
    sleep 0.3
}

launch_window_from_state() {
    local slot=$1

    # Read shader config for this slot from state.json
    local shader_config
    shader_config=$(python3 -c "
import sys; sys.path.insert(0, '$LINUX_DIR'); sys.path.insert(0, '$PYMOD_DIR')
from state_service import load_state
import json
state = load_state()
config = state.get('shader_configs', {}).get('$slot', {})
print(json.dumps(config))
" 2>/dev/null)

    local shader_file
    if [ -z "$shader_config" ] || [ "$shader_config" = "{}" ]; then
        # Fallback: use green preset
        shader_file=$(python3 "$PYMOD_DIR/shader_service_mac.py" create --slot "$slot" --preset 0 2>/dev/null)
    else
        # Create shader with saved RGB
        local r g b
        r=$(echo "$shader_config" | python3 -c "import sys,json; c=json.load(sys.stdin); print(c.get('RAIN_R', 0.0))")
        g=$(echo "$shader_config" | python3 -c "import sys,json; c=json.load(sys.stdin); print(c.get('RAIN_G', 1.0))")
        b=$(echo "$shader_config" | python3 -c "import sys,json; c=json.load(sys.stdin); print(c.get('RAIN_B', 0.3))")
        shader_file=$(python3 "$PYMOD_DIR/shader_service_mac.py" create --slot "$slot" --r "$r" --g "$g" --b "$b" 2>/dev/null)

        # Write all non-RGB params to restore full config
        python3 -c "
import sys; sys.path.insert(0, '$LINUX_DIR'); sys.path.insert(0, '$PYMOD_DIR')
import json
from shader_service_mac import write_shader_params
config = json.loads('''$shader_config''')
params = {k: v for k, v in config.items() if k not in ('RAIN_R', 'RAIN_G', 'RAIN_B')}
if params:
    write_shader_params($slot, params)
" 2>/dev/null
    fi

    if [ -z "$shader_file" ] || [ ! -f "$shader_file" ]; then
        echo -e "   Matrix-${slot} ${RED}FAILED${RESET} (no shader file)"
        return
    fi

    # Read opacity from state
    local opacity
    opacity=$(python3 -c "
import sys; sys.path.insert(0, '$LINUX_DIR'); sys.path.insert(0, '$PYMOD_DIR')
from state_service import load_state
state = load_state()
print(state.get('opacity', 85))
" 2>/dev/null || echo 85)
    local opacity_val
    opacity_val=$(awk "BEGIN {printf \"%.2f\", $opacity / 100}")
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

    local conf="/tmp/ghostty-matrix-${slot}.conf"
    cat > "$conf" <<EOF
custom-shader = ${shader_file}
background = #000000
foreground = ${fg}
font-family = ${FONT}
font-style = Bold
background-opacity = ${opacity_val}
macos-titlebar-style = hidden
custom-shader-animation = always
desktop-notifications = false
EOF

    echo -ne "   Waiting for Matrix-${slot}..."
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > /tmp/ghostty-matrix-${slot}.log 2>&1 &
    local ghostty_pid=$!
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
if [ -z "$GHOSTTY_BIN" ]; then
    echo -e "${RED} Ghostty not found${RESET}"
    echo -e "${DIM} Install Ghostty.app to /Applications first.${RESET}"
    sleep 3
    exit 1
fi

# Load saved slots from state.json
saved_slots=$(python3 -c "
import sys; sys.path.insert(0, '$LINUX_DIR'); sys.path.insert(0, '$PYMOD_DIR')
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

# Apply layout to position windows
sleep 0.5
python3 -c "
import sys; sys.path.insert(0, '$LINUX_DIR'); sys.path.insert(0, '$PYMOD_DIR')
import window_service_mac; sys.modules['window_service'] = window_service_mac
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
        nohup python3 -B "$MATRIX_KEYS" > /tmp/matrix-keys.log 2>&1 &
        disown
        echo -e "${GREEN} Starting hotkeys...${RESET} ${WHITE}OK${RESET}"
    fi
else
    nohup python3 -B "$MATRIX_KEYS" > /tmp/matrix-keys.log 2>&1 &
    disown
    echo -e "${GREEN} Starting hotkeys...${RESET} ${WHITE}OK${RESET}"
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
python3 -B "$SCRIPT_DIR/../linux/command_banner.py" 2>/dev/null

sleep infinity
