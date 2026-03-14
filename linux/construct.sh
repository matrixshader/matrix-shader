#!/bin/bash
# Matrix Shader - Construct (Linux/Ghostty)
# Quick-launch a Matrix rain window or open the white room CRT picker.
# Linux port of Windows Construct/Program.cs
#
# Usage:
#   construct                     White room CRT color picker
#   construct --green             Instant green Matrix rain
#   construct --red|--blue|...    Instant rain with specified color
#   construct --aurora|--ultra|.. Instant bonus shader
#   construct --help              Show help

SCRIPT_PATH="$(realpath "$0")"
PYMOD_DIR="$(dirname "$SCRIPT_PATH")"
SHADER_DIR="$(dirname "$SCRIPT_PATH")/../shaders-glsl"
GHOSTTY_BIN="/home/neo/ghostty-build/zig-out/bin/ghostty"
CONFIG_DIR="$HOME/.config/matrix-shader"

# Colors
GREEN='\033[0;32m'
DIM='\033[2m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

# Parse flags
COLOR=""
MODE=""
IN_GHOSTTY=false
for arg in "$@"; do
    case "$arg" in
        --pick)         IN_GHOSTTY=true ;;
        --help|-h)      MODE="help" ;;
        --green)        COLOR="green" ;;
        --red)          COLOR="red" ;;
        --blue)         COLOR="blue" ;;
        --purple)       COLOR="purple" ;;
        --gold)         COLOR="gold" ;;
        --teal)         COLOR="teal" ;;
        --aurora)       COLOR="aurora" ;;
        --aurora-rain)  COLOR="aurora-rain" ;;
        --fireplace)    COLOR="fireplace" ;;
        --codevision)   COLOR="codevision" ;;
        --ultra)        COLOR="ultra" ;;
        --rain-on-glass) COLOR="rain-on-glass" ;;
    esac
done

# --- Help ---
if [[ "$MODE" == "help" ]]; then
    python3 -B "$PYMOD_DIR/construct_service.py" help
    python3 -B "$PYMOD_DIR/command_banner.py" 2>/dev/null
    exit 0
fi

# --- Quick launch (any color/bonus flag) ---
if [ -n "$COLOR" ]; then
    # Check Ghostty
    if [ ! -f "$GHOSTTY_BIN" ]; then
        echo -e "${RED} Ghostty not found at $GHOSTTY_BIN${RESET}"
        exit 1
    fi

    # Call Python service to create shader + config
    result=$(python3 -B "$PYMOD_DIR/construct_service.py" quick-launch --color "$COLOR" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED} $result${RESET}"
        exit 1
    fi

    # Parse result: "slot:conf_path"
    slot="${result%%:*}"
    conf="${result#*:}"

    # Launch Ghostty
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > /tmp/ghostty-matrix-${slot}.log 2>&1 &
    disown

    echo -e "${GREEN} Matrix-${slot}${RESET} ${DIM}launched with ${COLOR}${RESET}"

    # Command reference banner
    python3 -B "$PYMOD_DIR/command_banner.py" 2>/dev/null

    exit 0
fi

# --- White room flow ---

# If running inside Ghostty (--pick flag), run the picker
if [ "$IN_GHOSTTY" = "true" ]; then
    # Run the white room picker
    selected=$(python3 -B "$PYMOD_DIR/construct_service.py" white-room 2>/dev/tty)
    exit_code=$?

    if [ $exit_code -ne 0 ] || [ -z "$selected" ] || [ "$selected" = "cancelled" ]; then
        echo -e "${DIM} Cancelled.${RESET}"
        sleep 1
        exit 0
    fi

    # Get the slot number from the Ghostty config filename
    # The config file is /tmp/ghostty-construct-{slot}.conf
    # We need to determine which slot this window is using
    own_conf=""
    own_slot=""
    for s in $(seq 1 8); do
        conf="/tmp/ghostty-construct-${s}.conf"
        if [ -f "$conf" ]; then
            # Check if this is our process
            own_pid=$$
            parent_pid=$(ps -o ppid= -p $own_pid 2>/dev/null | tr -d ' ')
            if pgrep -f "config-file=$conf" | grep -q "$parent_pid" 2>/dev/null; then
                own_conf="$conf"
                own_slot="$s"
                break
            fi
        fi
    done

    # Fallback: find the construct config that exists
    if [ -z "$own_slot" ]; then
        for s in $(seq 1 8); do
            conf="/tmp/ghostty-construct-${s}.conf"
            if [ -f "$conf" ]; then
                own_slot="$s"
                own_conf="$conf"
                break
            fi
        done
    fi

    if [ -z "$own_slot" ]; then
        echo -e "${RED} Could not determine window slot.${RESET}"
        sleep 2
        exit 1
    fi

    # Rename the construct config to matrix config for slot tracking
    matrix_conf="/tmp/ghostty-matrix-${own_slot}.conf"
    cp "$own_conf" "$matrix_conf"

    # Transition to rain: swap shader + opacity + reload
    python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from construct_service import transition_to_rain
transition_to_rain($own_slot, $selected)
" 2>/dev/null

    echo
    echo -e "${GREEN} THE MATRIX HAS YOU.${RESET}"
    echo

    # Command reference banner
    python3 -B "$PYMOD_DIR/command_banner.py" 2>/dev/null

    sleep infinity
    exit 0
fi

# --- Self-relaunch: spawn Ghostty with white room shader ---

# Check Ghostty
if [ ! -f "$GHOSTTY_BIN" ]; then
    echo -e "${RED} Ghostty not found at $GHOSTTY_BIN${RESET}"
    exit 1
fi

# Find next available slot for the construct window
next_slot=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from construct_service import find_next_slot
s = find_next_slot()
print(s if s is not None else '')
" 2>/dev/null)

if [ -z "$next_slot" ]; then
    echo -e "${RED} All 8 shader slots are in use. Close a Matrix window first.${RESET}"
    exit 1
fi

# Resolve white room shader path
white_room_shader="$SHADER_DIR/white-room-ghostty.glsl"
if [ ! -f "$white_room_shader" ]; then
    echo -e "${RED} White room shader not found at $white_room_shader${RESET}"
    exit 1
fi

# Write Ghostty config for white room (opaque, white foreground)
construct_conf="/tmp/ghostty-construct-${next_slot}.conf"
cat > "$construct_conf" <<EOF
custom-shader = ${white_room_shader}
custom-shader-animation = always
background = #000000
foreground = #6EDCAA
font-family = Nimbus Mono PS
font-style = Bold
font-size = 16
background-opacity = 1.0
gtk-titlebar = true
window-decoration = client
desktop-notifications = false
EOF

# Self-relaunch inside Ghostty with --pick flag
nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$construct_conf" \
    -e "$SCRIPT_PATH" --pick >/dev/null 2>&1 &
disown
exit 0
