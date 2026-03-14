#!/bin/bash
# Matrix Shader - Construct (macOS/Ghostty)
# Quick-launch a Matrix rain window or open the white room CRT picker.
# macOS port of linux/construct.sh
#
# Usage:
#   construct                     White room CRT color picker
#   construct --green             Instant green Matrix rain
#   construct --red|--blue|...    Instant rain with specified color
#   construct --aurora|--ultra|.. Instant bonus shader
#   construct --help              Show help

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PYMOD_DIR="$SCRIPT_DIR"
SHADER_DIR="$SCRIPT_DIR/../shaders-glsl"
CONFIG_DIR="$HOME/.config/matrix-shader"

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

# Detect font (macOS may not have Nimbus Mono PS)
if system_profiler SPFontsDataType 2>/dev/null | grep -qi "Nimbus Mono PS"; then
    FONT="Nimbus Mono PS"
elif system_profiler SPFontsDataType 2>/dev/null | grep -qi "SF Mono"; then
    FONT="SF Mono"
else
    FONT="Menlo"
fi

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
    python3 -B "$PYMOD_DIR/construct_service_mac.py" help
    python3 -B "$SCRIPT_DIR/../linux/command_banner.py" 2>/dev/null
    exit 0
fi

# --- Quick launch (any color/bonus flag) ---
if [ -n "$COLOR" ]; then
    # Check Ghostty
    if [ -z "$GHOSTTY_BIN" ]; then
        echo -e "${RED} Ghostty not found.${RESET}"
        echo -e "${DIM} Install Ghostty: brew install --cask ghostty${RESET}"
        exit 1
    fi

    # Call Python service to create shader + config
    result=$(python3 -B "$PYMOD_DIR/construct_service_mac.py" quick-launch --color "$COLOR" 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED} $result${RESET}"
        exit 1
    fi

    # Parse result: "slot:conf_path"
    slot="${result%%:*}"
    conf="${result#*:}"

    # Launch Ghostty
    if [ -n "$GHOSTTY_BIN" ]; then
        nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > /tmp/ghostty-matrix-${slot}.log 2>&1 &
    else
        open -na Ghostty --args --config-default-files=false --config-file="$conf" 2>/dev/null &
    fi
    disown

    echo -e "${GREEN} Matrix-${slot}${RESET} ${DIM}launched with ${COLOR}${RESET}"

    # Command reference banner
    python3 -B "$SCRIPT_DIR/../linux/command_banner.py" 2>/dev/null

    exit 0
fi

# --- White room flow ---

# If running inside Ghostty (--pick flag), run the picker
if [ "$IN_GHOSTTY" = "true" ]; then
    # Run the white room picker
    selected=$(python3 -B "$PYMOD_DIR/construct_service_mac.py" white-room 2>/dev/tty)
    exit_code=$?

    if [ $exit_code -ne 0 ] || [ -z "$selected" ] || [ "$selected" = "cancelled" ]; then
        echo -e "${DIM} Cancelled.${RESET}"
        sleep 1
        exit 0
    fi

    # Get the slot number from the Ghostty config filename
    own_conf=""
    own_slot=""
    for s in $(seq 1 8); do
        conf="/tmp/ghostty-construct-${s}.conf"
        if [ -f "$conf" ]; then
            own_pid=$$
            parent_pid=$(ps -o ppid= -p $own_pid 2>/dev/null | tr -d ' ')
            if ps -eo args 2>/dev/null | grep -q "config-file=$conf"; then
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

    # Transition to rain: swap shader + opacity + reload (Mac: SIGHUP)
    python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR'); sys.path.insert(0, '$SCRIPT_DIR/../linux')
from construct_service_mac import transition_to_rain_mac
transition_to_rain_mac($own_slot, $selected)
" 2>/dev/null

    echo
    echo -e "${GREEN} THE MATRIX HAS YOU.${RESET}"
    echo

    # Command reference banner
    python3 -B "$SCRIPT_DIR/../linux/command_banner.py" 2>/dev/null

    sleep infinity
    exit 0
fi

# --- Self-relaunch: spawn Ghostty with white room shader ---

# Check Ghostty
if [ -z "$GHOSTTY_BIN" ]; then
    echo -e "${RED} Ghostty not found.${RESET}"
    echo -e "${DIM} Install Ghostty: brew install --cask ghostty${RESET}"
    exit 1
fi

# Find next available slot for the construct window
next_slot=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR'); sys.path.insert(0, '$SCRIPT_DIR/../linux')
from construct_service_mac import find_next_slot_mac
s = find_next_slot_mac()
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
font-family = ${FONT}
font-style = Bold
font-size = 16
background-opacity = 1.0
macos-titlebar-style = hidden
desktop-notifications = false
EOF

# Self-relaunch inside Ghostty with --pick flag
if [ -n "$GHOSTTY_BIN" ]; then
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$construct_conf" \
        -e "$SCRIPT_PATH" --pick >/dev/null 2>&1 &
else
    open -na Ghostty --args --config-default-files=false --config-file="$construct_conf" \
        -e "$SCRIPT_PATH" --pick 2>/dev/null &
fi
disown
exit 0
