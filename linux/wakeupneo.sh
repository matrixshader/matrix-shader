#!/bin/bash
# Matrix Shader - WakeupNeo (Linux/Ghostty)
# Exact port of Windows WakeupNeo setup wizard

SCRIPT_PATH="$(realpath "$0")"
PYMOD_DIR="$(dirname "$SCRIPT_PATH")"
SHADER_DIR="$(dirname "$SCRIPT_PATH")/../shaders-glsl"
GHOSTTY_BIN="/home/neo/ghostty-build/zig-out/bin/ghostty"
CONFIG_DIR="$HOME/.config/ghostty"
STATE_DIR="$HOME/.config/matrix-shader"
STATE_FILE="$STATE_DIR/state.json"
HOTKEY_HELP="$HOME/.local/bin/matrix-hotkey-help.sh"
MATRIX_KEYS="$(dirname "$SCRIPT_PATH")/matrix_keys.py"
MATRIX_KEYS_PID="/tmp/matrix-keys.pid"

# Parse flags
MODE=""
IN_GHOSTTY=false
for arg in "$@"; do
    case "$arg" in
        --in-ghostty)  IN_GHOSTTY=true ;;
        --morpheus)    MODE="morpheus" ;;
        --agent-smith) MODE="agent-smith" ;;
        --update)      MODE="update" ;;
        --help|-h)     MODE="help" ;;
    esac
done

# Self-relaunch inside Ghostty if not already there
# Uses --in-ghostty flag (not env var) to avoid leaking through child processes
if [ "$IN_GHOSTTY" != "true" ]; then
    # --update and --agent-smith run directly (no Ghostty window needed)
    if [[ "$MODE" == "update" ]]; then
        # Define check_update inline for direct invocation (functions defined later)
        :  # Handled after function definitions below
    fi
    if [[ "$MODE" == "agent-smith" ]]; then
        :  # Handled after function definitions below
    fi
    if [[ "$MODE" != "update" && "$MODE" != "agent-smith" ]]; then
        setup_conf="/tmp/ghostty-wakeupneo.conf"
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
        nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$setup_conf" -e "$SCRIPT_PATH" --in-ghostty ${MODE:+--$MODE} >/dev/null 2>&1 &
        disown
        exit 0
    fi
fi

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GOLD='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
RESET='\033[0m'

# Preset definitions: name:R:G:B:foreground_hex
PRESETS=(
    "Classic Green:0.0:1.0:0.3:#00ff4d"
    "Cyber Blue:0.0:0.6:1.0:#0099ff"
    "Blood Red:1.0:0.1:0.1:#ff1a1a"
    "Purple:0.7:0.0:1.0:#b300ff"
    "Gold:1.0:0.7:0.0:#ffb300"
    "Teal:0.0:0.9:0.9:#00e6e6"
    "Redpill-Neo 3D:0.0:1.0:0.0:#00ff00"
)

PRESET_COLORS=("$GREEN" "$BLUE" "$RED" "$PURPLE" "$GOLD" "$CYAN" "$GREEN")
PRESET_FILES=("matrix-green-ghostty.glsl" "matrix-blue-ghostty.glsl" "matrix-red-ghostty.glsl" "matrix-purple-ghostty.glsl" "matrix-gold-ghostty.glsl" "matrix-teal-ghostty.glsl" "redpill-neo-ghostty.glsl")

# Matrix movie quotes (ported from MatrixQuotes.cs)
MATRIX_QUOTES=(
    "The Matrix has you..."
    "Follow the white rabbit."
    "There is no spoon."
    "Free your mind."
    "I know kung fu."
    "Welcome to the real world."
    "What is the Matrix?"
    "You've been living in a dream world, Neo."
    "Unfortunately, no one can be told what the Matrix is."
    "The body cannot live without the mind."
    "Dodge this."
    "I can only show you the door."
    "Everything begins with choice."
    "There's a difference between knowing the path and walking the path."
)

# Color swatch using ANSI 24-bit color
color_swatch() {
    local r=$1 g=$2 b=$3
    # Convert 0.0-1.0 to 0-255
    local ri=$(awk "BEGIN {printf \"%d\", $r * 255}")
    local gi=$(awk "BEGIN {printf \"%d\", $g * 255}")
    local bi=$(awk "BEGIN {printf \"%d\", $b * 255}")
    printf "\033[48;2;%d;%d;%dm   \033[0m" "$ri" "$gi" "$bi"
}

# --- Functions ---

# Detect which Matrix slots have running Ghostty processes
# Returns space-separated list of open slot numbers
get_open_slots() {
    local open=()
    for conf in /tmp/ghostty-matrix-*.conf; do
        [ -f "$conf" ] || continue
        local slot=$(echo "$conf" | grep -oP 'ghostty-matrix-\K\d+')
        # Filter to actual ghostty processes — pgrep -f matches claude/editor transcripts too
        for pid in $(pgrep -f "config-file=$conf" 2>/dev/null); do
            local exe=$(readlink /proc/$pid/exe 2>/dev/null)
            if [[ "$exe" == *ghostty* ]]; then
                open+=("$slot")
                break
            fi
        done
    done
    echo "${open[*]}"
}

typewriter() {
    local text="$1" delay="${2:-0.04}"
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

show_random_quote() {
    local idx=$(( RANDOM % ${#MATRIX_QUOTES[@]} ))
    echo -e " ${DIM}\"${MATRIX_QUOTES[$idx]}\"${RESET}"
    echo
}

morpheus_intro() {
    echo
    typewriter " I imagine that right now, you're feeling a bit like Alice." 0.05
    sleep 0.5
    typewriter " Tumbling down the rabbit hole." 0.05
    sleep 0.5
    echo
    typewriter " You take the red pill, you stay in Wonderland..." 0.06
    sleep 0.3
    typewriter " and I show you how deep the rabbit hole goes." 0.06
    sleep 0.8
    echo
    typewriter " Remember, all I'm offering is the truth." 0.05
    sleep 0.3
    typewriter " Nothing more." 0.06
    sleep 1
    echo
}

agent_smith_mode() {
    echo -e "${GREEN} AGENT SMITH MODE: CHAOS${RESET}"
    echo
    typewriter " Mr. Anderson..." 0.10
    sleep 0.5
    typewriter " You're going to help us, Mr. Anderson." 0.08
    sleep 0.5
    typewriter " Whether you want to or not." 0.08
    sleep 1

    local count=0
    for conf in /tmp/ghostty-matrix-*.conf; do
        [ -f "$conf" ] || continue
        local slot=$(echo "$conf" | grep -oP 'ghostty-matrix-\K\d+')
        # Generate random RGB and speed
        local r g b speed
        r=$(python3 -c "import random; print(f'{random.random():.1f}')")
        g=$(python3 -c "import random; print(f'{random.random():.1f}')")
        b=$(python3 -c "import random; print(f'{random.random():.1f}')")
        speed=$(python3 -c "import random; print(f'{random.random() * 2.5 + 0.5:.1f}')")

        python3 "$PYMOD_DIR/shader_service.py" write --slot "$slot" --param RAIN_R --value "$r"
        python3 "$PYMOD_DIR/shader_service.py" write --slot "$slot" --param RAIN_G --value "$g"
        python3 "$PYMOD_DIR/shader_service.py" write --slot "$slot" --param RAIN_B --value "$b"
        python3 "$PYMOD_DIR/shader_service.py" write --slot "$slot" --param RAIN_SPEED --value "$speed"
        ((count++))
    done

    # Trigger reload on all Ghostty instances
    for busname in $(busctl --user list 2>/dev/null | awk '/ghostty/{print $1}'); do
        gdbus call --session --dest "$busname" \
            --object-path /com/mitchellh/ghostty \
            --method org.gtk.Actions.Activate \
            'reload-config' '[]' '{}' >/dev/null 2>&1
    done

    echo
    echo -e "${GREEN} Chaos applied to ${count} window(s).${RESET}"
    echo -e "${DIM} There is no spoon.${RESET}"
}

get_current_version() {
    local version_file
    version_file="$(dirname "$SCRIPT_PATH")/../VERSION"
    if [ -f "$version_file" ]; then
        cat "$version_file"
    else
        echo "0.0.0"
    fi
}

check_update() {
    local current_version
    current_version=$(get_current_version)
    local api_url="https://api.github.com/repos/matrixshader/matrix-shader/releases/latest"

    # Silent, non-blocking: max 5 seconds, fail silently
    local response
    response=$(curl -s --max-time 5 -H "User-Agent: MatrixShader-UpdateCheck" "$api_url" 2>/dev/null) || return 0

    local latest
    latest=$(echo "$response" | python3 -c "
import sys, json, re
try:
    data = json.load(sys.stdin)
    tag = data.get('tag_name', '').lstrip('v')
    match = re.match(r'[\d.]+', tag)
    print(match.group(0) if match else '')
except:
    pass
" 2>/dev/null) || return 0

    if [ -z "$latest" ]; then
        return 0
    fi

    # Compare versions using Python tuple comparison
    if python3 -c "
import sys
v1 = tuple(map(int, '$latest'.split('.')))
v2 = tuple(map(int, '$current_version'.split('.')))
sys.exit(0 if v1 > v2 else 1)
" 2>/dev/null; then
        echo
        echo -e " \033[33m UPDATE AVAILABLE: v${latest}\033[0m"
        echo -e " \033[90m Current: v${current_version}\033[0m"
        echo -e " \033[90m Update:  curl -sL matrixshader.com/install | bash\033[0m"
        echo
    fi
}

# Handle --update and --agent-smith direct invocations (no Ghostty window)
if [ "$IN_GHOSTTY" != "true" ]; then
    if [[ "$MODE" == "update" ]]; then
        check_update
        exit 0
    fi
    if [[ "$MODE" == "agent-smith" ]]; then
        agent_smith_mode
        exit 0
    fi
fi

matrix_splash() {
    local width=$(tput cols 2>/dev/null || echo 80)
    local height=$(tput lines 2>/dev/null || echo 24)
    local chars="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    local char_count=${#chars}

    tput civis 2>/dev/null  # Hide cursor
    printf '\033[H\033[2J'  # Clear screen once at start

    # Column state: position and speed
    declare -a col_pos col_speed col_trail
    for ((x=0; x<width; x++)); do
        col_pos[$x]=$(( (RANDOM % height) * -1 ))
        col_speed[$x]=$(( RANDOM % 2 + 1 ))
        col_trail[$x]=$(( RANDOM % 8 + 4 ))
    done

    # Animate for ~1.5 seconds (30 frames at ~50ms each)
    local frames=30
    for ((frame=0; frame<frames; frame++)); do
        local buf=""
        for ((x=0; x<width; x++)); do
            local pos=${col_pos[$x]}
            local trail=${col_trail[$x]}

            for ((t=0; t<trail && t<3; t++)); do
                local y=$((pos - t))
                if ((y >= 0 && y < height)); then
                    local c="${chars:$(( RANDOM % char_count )):1}"
                    if ((t == 0)); then
                        buf+="\033[$((y+1));$((x+1))H\033[97m${c}"   # White head
                    elif ((t == 1)); then
                        buf+="\033[$((y+1));$((x+1))H\033[92m${c}"   # Bright green
                    else
                        buf+="\033[$((y+1));$((x+1))H\033[32m${c}"   # Green
                    fi
                fi
            done

            # Advance column
            col_pos[$x]=$(( pos + ${col_speed[$x]} ))
            # Reset if past screen
            if ((col_pos[$x] - trail > height)); then
                col_pos[$x]=$(( (RANDOM % height) * -1 ))
                col_speed[$x]=$(( RANDOM % 2 + 1 ))
            fi
        done

        printf "${buf}\033[0m"
        printf '\033[H'  # Cursor home (no flicker — no clear between frames)
        sleep 0.05
    done

    printf '\033[H\033[2J'  # Clear screen at end
    tput cnorm 2>/dev/null  # Show cursor
}

arrow_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local count=${#options[@]}

    tput civis 2>/dev/null  # Hide cursor during menu

    # Save cursor position for redrawing
    local menu_lines=$((count + 4))  # prompt + blank + options + blank

    # Initial draw
    echo
    echo -e " ${DIM}${prompt}${RESET}"
    echo
    for ((i=0; i<count; i++)); do
        if [ "$i" -eq "$selected" ]; then
            echo -e "   ${GREEN}>${RESET} \033[1;32m${options[$i]}\033[0m"
        else
            echo -e "     \033[90m${options[$i]}\033[0m"
        fi
    done

    while true; do
        # Read keypress
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') ((selected = (selected - 1 + count) % count)) ;;  # Up
                '[B') ((selected = (selected + 1) % count)) ;;          # Down
            esac
        elif [[ "$key" == "" ]]; then  # Enter
            tput cnorm 2>/dev/null  # Show cursor
            echo "$selected"
            return 0
        fi

        # Redraw options only (move cursor up to option start)
        printf "\033[${count}A"
        for ((i=0; i<count; i++)); do
            printf "\033[2K"  # Clear line
            if [ "$i" -eq "$selected" ]; then
                echo -e "   ${GREEN}>${RESET} \033[1;32m${options[$i]}\033[0m"
            else
                echo -e "     \033[90m${options[$i]}\033[0m"
            fi
        done
    done
}

launch_window() {
    local preset_idx=$1
    local slot=$2
    IFS=':' read -r name r g b fg <<< "${PRESETS[$preset_idx]}"
    # Create per-slot shader from template with preset colors
    local shader_file
    shader_file=$(python3 "$PYMOD_DIR/shader_service.py" create --slot "$slot" --preset "$preset_idx" 2>/dev/null)
    if [ -z "$shader_file" ] || [ ! -f "$shader_file" ]; then
        # Fallback to direct preset file if shader_service fails
        shader_file="${SHADER_DIR}/${PRESET_FILES[$preset_idx]}"
        echo -e "   ${DIM}(using preset file fallback)${RESET}"
    fi
    local conf="/tmp/ghostty-matrix-${slot}.conf"

    cat > "$conf" <<EOF
custom-shader = ${shader_file}
background = #000000
foreground = ${fg}
font-family = Nimbus Mono PS
font-style = Bold
background-opacity = 0.85
gtk-titlebar = true
window-decoration = client
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

    # NOTE: Do NOT overwrite default config - matrix windows use their own config files
    # Default ~/.config/ghostty/config stays clean so normal Ghostty opens are normal

    echo -ne "   Waiting for Matrix-${slot}..."
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > /tmp/ghostty-matrix-${slot}.log 2>&1 &
    local ghostty_pid=$!
    # Register PID with window service for positioning (Phase 5)
    python3 "$PYMOD_DIR/window_service.py" register "$slot" "$ghostty_pid" 2>/dev/null
    sleep 0.5
    local swatch=$(color_swatch "$r" "$g" "$b")
    echo -e " ${swatch} ${PRESET_COLORS[$preset_idx]}${name}${RESET} ${GREEN}OK${RESET}"
}

# Turn wizard window 100% transparent (glass pane)
go_transparent() {
    setup_conf="/tmp/ghostty-wakeupneo.conf"
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
    # Signal ALL Ghostty instances to reload
    for busname in $(busctl --user list 2>/dev/null | awk '/ghostty/{print $1}'); do
        gdbus call --session --dest "$busname" \
            --object-path /com/mitchellh/ghostty \
            --method org.gtk.Actions.Activate \
            'reload-config' '[]' '{}' >/dev/null 2>&1
    done
    sleep 0.3
}

# Post-launch display (shown on transparent glass background)
show_post_launch() {
    local is_redpill=$1

    echo
    # Kill any existing hotkey listener, then start fresh
    if [ -f "$MATRIX_KEYS_PID" ]; then
        kill "$(cat "$MATRIX_KEYS_PID")" 2>/dev/null
        rm -f "$MATRIX_KEYS_PID"
    fi

    if [ -f "$MATRIX_KEYS" ]; then
        nohup python3 -B "$MATRIX_KEYS" > /tmp/matrix-keys.log 2>&1 &
        disown
        echo -e "${GREEN} Starting hotkeys...${RESET} ${WHITE}OK${RESET}"
    else
        echo -e "${GREEN} Starting hotkeys...${RESET} ${RED}MISSING (${MATRIX_KEYS})${RESET}"
    fi

    # Start watchdog to auto-restart hotkey listener on crash
    WATCHDOG_SCRIPT="$PYMOD_DIR/matrix_watchdog.py"
    if [ -f "$WATCHDOG_SCRIPT" ]; then
        watchdog_pid="/tmp/matrix-watchdog.pid"
        if [ -f "$watchdog_pid" ] && kill -0 "$(cat "$watchdog_pid")" 2>/dev/null; then
            : # Watchdog already running
        else
            nohup python3 "$WATCHDOG_SCRIPT" > /dev/null 2>&1 &
            disown
        fi
    fi

    # Final message
    echo
    if [ "$is_redpill" -eq 1 ]; then
        # Check license and either launch TUI or show purchase prompt
        local licensed
        licensed=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from license_service import is_licensed
print('yes' if is_licensed() else 'no')
" 2>/dev/null)

        if [ "$licensed" = "yes" ]; then
            echo -e "${GREEN} THE MATRIX HAS YOU.${RESET}"
            echo -e "${DIM} Launching control panel...${RESET}"
            sleep 1
            # Launch redpill TUI in its own Ghostty window, then close wizard
            REDPILL_SCRIPT="$PYMOD_DIR/redpill.sh"
            if [ -f "$REDPILL_SCRIPT" ]; then
                bash "$REDPILL_SCRIPT" &
                disown
                sleep 0.5
                exit 0
            fi
        else
            echo -e "${GREEN} THE RED PILL${RESET}"
            echo
            echo -e "${DIM} Opening purchase page...${RESET}"
            xdg-open "https://matrixshader.com/redpill" 2>/dev/null &
            echo
            echo -ne " ${CYAN}Paste your key here after purchase (or Enter to skip): ${RESET}"
            read -r license_key
            if [ -n "$license_key" ]; then
                python3 -B "$PYMOD_DIR/redpill_tui.py" --activate "$license_key"
                # If activation succeeded, launch the TUI
                licensed=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from license_service import is_licensed
print('yes' if is_licensed() else 'no')
" 2>/dev/null)
                if [ "$licensed" = "yes" ]; then
                    echo -e "${DIM} Launching control panel...${RESET}"
                    sleep 1
                    REDPILL_SCRIPT="$PYMOD_DIR/redpill.sh"
                    if [ -f "$REDPILL_SCRIPT" ]; then
                        bash "$REDPILL_SCRIPT" &
                        disown
                        sleep 0.5
                        exit 0
                    fi
                fi
            fi
        fi
    else
        echo -e "${GREEN} FOLLOW THE WHITE RABBIT.${RESET}"
        echo
        echo -e "${DIM} Unlock the Red Pill control panel:${RESET}"
        echo -e "${CYAN} matrixshader.com/redpill${RESET}"
    fi

    # Hotkey summary
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

    # Background update check (silent, non-blocking)
    check_update &

    sleep infinity
}

# --- Main ---

matrix_splash

echo

# Dramatic intro - matches Windows version timing
typewriter " Wake up, Neo..." 0.10
sleep 1

typewriter " The Matrix has you..." 0.08
sleep 1

typewriter " Follow the white rabbit." 0.08
sleep 0.5

show_random_quote
sleep 1

# Morpheus easter egg: extended philosophical intro
if [[ "$MODE" == "morpheus" ]]; then
    morpheus_intro
fi

# Clear and show header
clear
echo
echo " WAKE UP, NEO..."
echo -e "${DIM} ----------------------------------------${RESET}"
echo

# Check Ghostty
if [ ! -f "$GHOSTTY_BIN" ]; then
    echo -e "${RED} Ghostty not found at $GHOSTTY_BIN${RESET}"
    echo -e "${DIM} Build it first: cd ~/ghostty-build && zig build -Doptimize=ReleaseFast -Dapp-runtime=gtk${RESET}"
    echo
    sleep 3
    exit 1
fi

# Check for previous session
mkdir -p "$STATE_DIR" "$CONFIG_DIR"

if [ -f "$STATE_FILE" ]; then
    num_prev=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(len(d['windows']))" 2>/dev/null || echo 0)
    if [ "$num_prev" -gt 0 ]; then
        prev_slots=$(python3 -c "
import json
d=json.load(open('$STATE_FILE'))
print(', '.join(str(w['slot']) for w in d['windows']))
" 2>/dev/null)
        echo -e "${GREEN} Previous session found:${RESET}"
        echo
        echo -e "${DIM}   ${num_prev} windows, slots: [${prev_slots}]${RESET}"
        echo
        echo -ne " Restore previous? (y/n): "
        read -rsn1 restore
        echo

        if [[ "$restore" == "y" || "$restore" == "Y" ]]; then
            # Detect already-open Matrix windows
            open_slots=($(get_open_slots))

            # Turn wizard transparent, then show restore on glass background
            go_transparent
            clear
            echo
            echo -e "${GREEN} Restoring session...${RESET}"
            echo

            launched=0
            skipped=0
            for i in $(seq 0 $((num_prev - 1))); do
                preset_idx=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['windows'][$i]['preset'])")
                slot=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['windows'][$i]['slot'])")

                # Skip if this slot is already running
                if [[ " ${open_slots[*]} " == *" $slot "* ]]; then
                    IFS=':' read -r name r g b fg <<< "${PRESETS[$preset_idx]}"
                    swatch=$(color_swatch "$r" "$g" "$b")
                    echo -e "   Matrix-${slot} ${swatch} ${PRESET_COLORS[$preset_idx]}${name}${RESET} ${DIM}already open${RESET}"
                    ((skipped++))
                    continue
                fi

                launch_window "$preset_idx" "$slot"
                ((launched++))
                sleep 0.3
            done

            if [ "$skipped" -gt 0 ]; then
                echo
                echo -e "${DIM}   Skipped ${skipped} already-open window(s)${RESET}"
            fi

            # Apply layout to position restored windows
            sleep 0.5
            python3 -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from layout_engine import apply_current_layout
n = apply_current_layout()
if n > 0:
    print(f'   Positioned {n} window(s) in layout')
" 2>/dev/null || true

            show_post_launch 0
            exit 0
        fi
        echo
    fi
fi

# Detect currently open Matrix windows (matches Windows FindMatrixWindows)
open_slots=($(get_open_slots))
if [ "${#open_slots[@]}" -gt 0 ] && [ -n "${open_slots[0]}" ]; then
    echo -e "${DIM} Detected ${#open_slots[@]} open Matrix window(s): slots [${open_slots[*]}]${RESET}"
    echo
fi

# Calculate available slots (1-8 minus occupied)
declare -a available_slots
for s in $(seq 1 8); do
    if [[ " ${open_slots[*]} " != *" $s "* ]]; then
        available_slots+=("$s")
    fi
done
max_new=${#available_slots[@]}

if [ "$max_new" -eq 0 ]; then
    echo -e "${GREEN} All 8 Matrix slots are in use!${RESET}"
    echo -e "${DIM} Close some Matrix windows first, or use the control panel.${RESET}"
    sleep 3
    exit 0
fi

echo -ne " How many NEW Matrix tabs? (1-${max_new}): "
read -r num_windows

if ! [[ "$num_windows" =~ ^[0-9]+$ ]] || [ "$num_windows" -lt 1 ]; then
    num_windows=1
fi
[ "$num_windows" -gt "$max_new" ] && num_windows=$max_new

# Configure each tab
declare -a selected_presets
declare -a selected_slots
slot_idx=0

for w in $(seq 1 "$num_windows"); do
    clear
    echo
    echo -e "${GREEN} TAB $w OF $num_windows${RESET}"
    echo -e "${DIM} ----------------------------------------${RESET}"
    echo

    # Show color presets with swatches
    for i in "${!PRESETS[@]}"; do
        IFS=':' read -r name r g b fg <<< "${PRESETS[$i]}"
        local_swatch=$(color_swatch "$r" "$g" "$b")
        # Visual separator before Redpill-Neo (option 7)
        if [ "$i" -eq 6 ]; then
            echo
        fi
        echo -e "   [$((i+1))] ${local_swatch} ${PRESET_COLORS[$i]}${name}${RESET}"
    done

    echo
    echo -ne " Color (1-7): "
    read -r choice

    if ! [[ "$choice" =~ ^[1-7]$ ]]; then
        choice=1
    fi
    selected_presets+=($((choice - 1)))
    selected_slots+=("${available_slots[$slot_idx]}")
    ((slot_idx++))
done

# Summary and pill choice
clear
echo
echo -e "${GREEN} THE MATRIX HAS YOU...${RESET}"
echo -e "${DIM} ----------------------------------------${RESET}"
echo

for i in "${!selected_presets[@]}"; do
    idx=${selected_presets[$i]}
    IFS=':' read -r name r g b fg <<< "${PRESETS[$idx]}"
    local_swatch=$(color_swatch "$r" "$g" "$b")
    echo -e "   Tab ${selected_slots[$i]}: ${local_swatch} ${PRESET_COLORS[$idx]}${name}${RESET}"
done

echo
echo -e "${DIM} ----------------------------------------${RESET}"
echo
echo -e "${DIM} This is your last chance. After this, there is no turning back.${RESET}"

pill_result=$(arrow_menu "Choose your path:" \
    "${BLUE}BLUE PILL${RESET} - Enter the Matrix" \
    "${RED}RED PILL${RESET}  - Full Customization (control panel)")

if [[ "$pill_result" == "1" ]]; then
    is_redpill=1
else
    is_redpill=0
fi

# === AFTER CHOICE: Glass pane + launch + display ===

go_transparent
clear
echo
echo -e "${GREEN} Opening windows...${RESET}"
echo

for i in "${!selected_presets[@]}"; do
    launch_window "${selected_presets[$i]}" "${selected_slots[$i]}"
    sleep 0.3
done

# Desktop notification
WINDOW_COUNT=${#selected_presets[@]}
if command -v notify-send &>/dev/null; then
    notify-send \
        --app-name="Matrix Shader" \
        --expire-time=5000 \
        "The Matrix has you" \
        "$WINDOW_COUNT window(s) deployed" 2>/dev/null || true
fi

# Save state with slot info
{
    echo '{"windows":['
    for i in "${!selected_presets[@]}"; do
        [ "$i" -gt 0 ] && echo ','
        echo -n "  {\"preset\": ${selected_presets[$i]}, \"slot\": ${selected_slots[$i]}}"
    done
    echo
    echo ']}'
} > "$STATE_FILE"

# Apply pillars layout to position windows with proper gaps
sleep 0.5
python3 -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from layout_engine import apply_current_layout
n = apply_current_layout()
if n > 0:
    print(f'   Positioned {n} window(s) in layout')
" 2>/dev/null || true

show_post_launch "$is_redpill"
