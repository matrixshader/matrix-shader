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
MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"

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
PICK_SLOT=""
for arg in "$@"; do
    case "$arg" in
        --pick)         IN_GHOSTTY=true ;;
        --slot=*)       PICK_SLOT="${arg#--slot=}" ;;
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

    # Launch Ghostty — same pattern as wakeupneo launch_window()
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > $MATRIX_TMP/ghostty-matrix-${slot}.log 2>&1 &
    ghostty_pid=$!
    disown
    # Register PID immediately (same pattern as wakeupneo line 427-429)
    python3 -B "$PYMOD_DIR/window_service.py" register "$slot" "$ghostty_pid" 2>/dev/null
    sleep 0.5

    # Apply layout — wait for window to be mapped by compositor
    sleep 1.0
    python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from layout_engine import apply_current_layout
n = apply_current_layout()
if n == 0:
    import time; time.sleep(0.5)
    apply_current_layout()
" 2>/dev/null

    echo -e "${GREEN} Matrix-${slot}${RESET} ${DIM}launched with ${COLOR}${RESET}"

    # Command reference banner
    python3 -B "$PYMOD_DIR/command_banner.py" 2>/dev/null

    exit 0
fi

# --- White room flow ---

# If running inside Ghostty (--pick flag), run the shader-driven picker
if [ "$IN_GHOSTTY" = "true" ]; then
    # Slot was passed via --slot=N by the launcher
    own_slot="$PICK_SLOT"
    own_conf="$MATRIX_TMP/ghostty-construct-${own_slot}.conf"
    own_shader="$MATRIX_TMP/ghostty-construct-${own_slot}-shader.glsl"

    if [ -z "$own_slot" ] || [ ! -f "$own_conf" ] || [ ! -f "$own_shader" ]; then
        echo -e "${RED} Could not determine window slot (got: ${own_slot}).${RESET}" >&2
        sleep 2
        exit 1
    fi

    # Run the white room picker (shader-driven via #define rewrites + D-Bus reload)
    # Arrow keys change SELECTED in shader, shader renders highlighted swatch on CRT TV
    selected=$(python3 -B "$PYMOD_DIR/construct_service.py" white-room --shader-path "$own_shader" 2>/dev/tty)
    exit_code=$?

    if [ $exit_code -ne 0 ] || [ -z "$selected" ] || [ "$selected" = "cancelled" ]; then
        # Power-off animation already played by picker on cancel
        sleep 0.5
        rm -f "$own_shader" "$own_conf"
        exit 0
    fi

    # Transition to rain IN THIS WINDOW
    python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from construct_service import transition_to_rain
transition_to_rain($own_slot, $selected, construct_conf='$own_conf')
"

    # Wait for Ghostty to detect config change and reload shader
    sleep 0.5

    # Clean up construct shader copy (keep config — Ghostty still reads it on D-Bus reload)
    rm -f "$own_shader"

    # Register this window in the matrix system — SAME as wakeupneo does
    # Find our Ghostty parent PID (we're a child process of Ghostty)
    ghostty_pid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
    # Walk up if needed — construct.sh → bash → ghostty
    while [ -n "$ghostty_pid" ] && [ "$ghostty_pid" != "1" ]; do
        exe=$(readlink /proc/$ghostty_pid/exe 2>/dev/null || true)
        if echo "$exe" | grep -q ghostty; then
            break
        fi
        ghostty_pid=$(ps -o ppid= -p $ghostty_pid 2>/dev/null | tr -d ' ')
    done

    if [ -n "$ghostty_pid" ] && [ "$ghostty_pid" != "1" ]; then
        # Register with window_service (same call as wakeupneo line 429)
        python3 -B "$PYMOD_DIR/window_service.py" register "$own_slot" "$ghostty_pid" 2>/dev/null

        # Create ghostty-matrix-{slot}.conf so get_ghostty_bus_names finds us
        matrix_conf="$MATRIX_TMP/ghostty-matrix-${own_slot}.conf"
        [ ! -f "$matrix_conf" ] && cp "$own_conf" "$matrix_conf"

        # Exit fullscreen via D-Bus (uses patched Ghostty's toggle-fullscreen action)
        busname=$(busctl --user list 2>/dev/null | awk -v p="$ghostty_pid" '$2==p && /ghostty/{print $1}')
        if [ -n "$busname" ]; then
            gdbus call --session --dest "$busname" \
                --object-path /com/mitchellh/ghostty \
                --method org.gtk.Actions.Activate \
                "toggle-fullscreen" "[]" "{}" >/dev/null 2>&1
        fi
        # Wait for GNOME to complete unfullscreen animation
        sleep 1.5

        # Apply layout

        python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from layout_engine import apply_current_layout
n = apply_current_layout()
if n == 0:
    import time; time.sleep(0.5)
    apply_current_layout()
" 2>/dev/null
    fi

    # Hand off to a real shell — this is now a usable Matrix terminal
    exec "${SHELL:-/bin/bash}"
fi

# --- Self-relaunch: spawn Ghostty with white room shader ---

# Activate GNOME extension if needed (first install only)
if command -v gnome-extensions &>/dev/null; then
    EXT_STATE=$(gnome-extensions info matrix-window-manager@custom 2>/dev/null | grep "State:" | awk '{print $2}')
    if [ "$EXT_STATE" = "ERROR" ] || [ "$EXT_STATE" = "INITIALIZED" ]; then
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

# Resolve white room shader — COPY to temp so we never modify the source
white_room_source="$SHADER_DIR/white-room-ghostty.glsl"
if [ ! -f "$white_room_source" ]; then
    echo -e "${RED} White room shader not found at $white_room_source${RESET}"
    exit 1
fi
white_room_shader="$MATRIX_TMP/ghostty-construct-${next_slot}-shader.glsl"
cp "$white_room_source" "$white_room_shader"

# Write Ghostty config for white room (opaque, white foreground)
construct_conf="$MATRIX_TMP/ghostty-construct-${next_slot}.conf"
cat > "$construct_conf" <<EOF
custom-shader = ${white_room_shader}
custom-shader-animation = always
background = #000000
foreground = #6EDCAA
font-family = Nimbus Mono PS
font-style = Bold
font-size = 16
background-opacity = 1.0
gtk-titlebar = false
window-decoration = none
window-padding-x = 0
window-padding-y = 0
fullscreen = true
desktop-notifications = false
EOF

# Self-relaunch inside Ghostty with --pick flag + slot number
nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$construct_conf" \
    -e "$SCRIPT_PATH" --pick --slot="${next_slot}" >/dev/null 2>&1 &
disown
exit 0
