#!/bin/bash
# Matrix Shader - WakeupNeo (macOS/Ghostty)
# macOS port of linux/wakeupneo.sh

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SHADER_DIR="$SCRIPT_DIR/../shaders-glsl"
SHADER_SERVICE="$SCRIPT_DIR/shader_service_mac.py"
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

# Detect font (macOS may not have Nimbus Mono PS)
if system_profiler SPFontsDataType 2>/dev/null | grep -qi "Nimbus Mono PS"; then
    FONT="Nimbus Mono PS"
elif system_profiler SPFontsDataType 2>/dev/null | grep -qi "SF Mono"; then
    FONT="SF Mono"
else
    FONT="Menlo"
fi

# Self-relaunch inside Ghostty if not already there
if [ "$1" != "--in-ghostty" ]; then
    setup_conf="/tmp/ghostty-wakeupneo.conf"
    cat > "$setup_conf" <<SETUPEOF
background = #000000
foreground = #6EDCAA
font-family = ${FONT}
font-style = Bold
font-size = 16
background-opacity = 1
macos-titlebar-style = hidden
SETUPEOF
    if [ -n "$GHOSTTY_BIN" ]; then
        nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$setup_conf" -e "$SCRIPT_PATH" --in-ghostty >/dev/null 2>&1 &
        disown
    else
        # Fallback: try open -a
        open -na Ghostty --args --config-default-files=false --config-file="$setup_conf" -e "$SCRIPT_PATH" --in-ghostty 2>/dev/null &
    fi
    exit 0
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
    local ri=$(python3 -c "print(int($r * 255))")
    local gi=$(python3 -c "print(int($g * 255))")
    local bi=$(python3 -c "print(int($b * 255))")
    printf "\033[48;2;%d;%d;%dm   \033[0m" "$ri" "$gi" "$bi"
}

# --- Functions ---

get_open_slots() {
    local open=()
    for conf in /tmp/ghostty-matrix-*.conf; do
        [ -f "$conf" ] || continue
        local slot=$(echo "$conf" | grep -oE 'ghostty-matrix-[0-9]+' | grep -oE '[0-9]+')
        # macOS: use ps instead of pgrep -f
        if ps -eo args 2>/dev/null | grep -q "config-file=$conf"; then
            open+=("$slot")
        fi
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
    shader_file=$(python3 "$SHADER_SERVICE" create --slot "$slot" --preset "$preset_idx" 2>/dev/null)
    if [ -z "$shader_file" ] || [ ! -f "$shader_file" ]; then
        # Fallback: try Linux shader_service
        shader_file=$(python3 "$SCRIPT_DIR/../linux/shader_service.py" create --slot "$slot" --preset "$preset_idx" 2>/dev/null)
    fi
    if [ -z "$shader_file" ] || [ ! -f "$shader_file" ]; then
        echo -e "   ${DIM}(shader creation failed)${RESET}"
        return 1
    fi

    local conf="/tmp/ghostty-matrix-${slot}.conf"
    cat > "$conf" <<EOF
custom-shader = ${shader_file}
background = #000000
foreground = ${fg}
font-family = ${FONT}
font-style = Bold
background-opacity = 0.85
macos-titlebar-style = hidden
custom-shader-animation = always
EOF

    echo -ne "   Waiting for Matrix-${slot}..."

    if [ -n "$GHOSTTY_BIN" ]; then
        nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" > /tmp/ghostty-matrix-${slot}.log 2>&1 &
    else
        open -na Ghostty --args --config-default-files=false --config-file="$conf" 2>/dev/null &
    fi
    sleep 0.5

    local swatch=$(color_swatch "$r" "$g" "$b")
    echo -e " ${swatch} ${PRESET_COLORS[$preset_idx]}${name}${RESET} ${GREEN}OK${RESET}"
}

go_transparent() {
    setup_conf="/tmp/ghostty-wakeupneo.conf"
    cat > "$setup_conf" <<TRANSEOF
background = #000000
foreground = #6EDCAA
font-family = ${FONT}
font-style = Bold
font-size = 16
background-opacity = 0
macos-titlebar-style = hidden
TRANSEOF
    # Trigger config reload on all Ghostty instances
    python3 "$SCRIPT_DIR/platform_mac.py" reload 2>/dev/null || \
    python3 -c "
import sys; sys.path.insert(0, '$SCRIPT_DIR')
from platform_mac import reload_ghostty_mac
reload_ghostty_mac()
" 2>/dev/null
    sleep 0.3
}

show_post_launch() {
    local is_redpill=$1

    echo

    # Kill any existing hotkey listener, then start fresh
    if [ -f "$MATRIX_KEYS_PID" ]; then
        kill "$(cat "$MATRIX_KEYS_PID")" 2>/dev/null
        rm -f "$MATRIX_KEYS_PID"
    fi

    if [ -f "$MATRIX_KEYS" ]; then
        nohup python3 "$MATRIX_KEYS" > /tmp/matrix-keys.log 2>&1 &
        disown
        echo -e "${GREEN} Starting hotkeys...${RESET} ${WHITE}OK${RESET}"
    else
        echo -e "${GREEN} Starting hotkeys...${RESET} ${RED}MISSING (${MATRIX_KEYS})${RESET}"
    fi

    # PYMOD_DIR for license_service.py (lives in linux/)
    local PYMOD_DIR="$SCRIPT_DIR/../linux"

    echo
    if [ "$is_redpill" -eq 1 ]; then
        # Check license and either launch TUI or show purchase prompt
        local licensed
        licensed=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR'); sys.path.insert(0, '$SCRIPT_DIR')
from license_service import is_licensed
print('yes' if is_licensed() else 'no')
" 2>/dev/null)

        if [ "$licensed" = "yes" ]; then
            echo -e "${GREEN} THE MATRIX HAS YOU.${RESET}"
            echo -e "${DIM} Launching control panel...${RESET}"
            sleep 1
            # Launch redpill TUI in its own Ghostty window, then close wizard
            REDPILL_SCRIPT="$SCRIPT_DIR/redpill_mac.sh"
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
            open "https://matrixshader.com/redpill" 2>/dev/null &
            echo
            echo -ne " ${CYAN}Paste your key here after purchase (or Enter to skip): ${RESET}"
            read -r license_key
            if [ -n "$license_key" ]; then
                export PYTHONPATH="${SCRIPT_DIR}:${PYMOD_DIR}:${PYTHONPATH:-}"
                python3 -B "$PYMOD_DIR/redpill_tui.py" --activate "$license_key"
                # If activation succeeded, launch the TUI
                licensed=$(python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR'); sys.path.insert(0, '$SCRIPT_DIR')
from license_service import is_licensed
print('yes' if is_licensed() else 'no')
" 2>/dev/null)
                if [ "$licensed" = "yes" ]; then
                    echo -e "${DIM} Launching control panel...${RESET}"
                    sleep 1
                    REDPILL_SCRIPT="$SCRIPT_DIR/redpill_mac.sh"
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

    # Check Accessibility permission
    python3 -c "
import sys; sys.path.insert(0, '$SCRIPT_DIR')
from platform_mac import check_accessibility_permission
if not check_accessibility_permission():
    print('\033[33m Note: Grant Accessibility permission for hotkeys to work.\033[0m')
    print('\033[2m System Settings > Privacy & Security > Accessibility\033[0m')
" 2>/dev/null

    sleep infinity
}

# --- Main ---

matrix_splash

echo

# Dramatic intro
typewriter " Wake up, Neo..." 0.10
sleep 1

typewriter " The Matrix has you..." 0.08
sleep 1

typewriter " Follow the white rabbit." 0.08
sleep 0.5

show_random_quote
sleep 1

# Clear and show header
clear
echo
echo " WAKE UP, NEO..."
echo -e "${DIM} ----------------------------------------${RESET}"
echo

# Check Ghostty
if [ -z "$GHOSTTY_BIN" ] && ! command -v ghostty &>/dev/null; then
    echo -e "${RED} Ghostty not found.${RESET}"
    echo -e "${DIM} Install Ghostty: brew install --cask ghostty${RESET}"
    echo
    sleep 3
    exit 1
fi

# Check for previous session
mkdir -p "$STATE_DIR"

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
            open_slots=($(get_open_slots))
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

            show_post_launch 0
            exit 0
        fi
        echo
    fi
fi

# Detect currently open Matrix windows
open_slots=($(get_open_slots))
if [ "${#open_slots[@]}" -gt 0 ] && [ -n "${open_slots[0]}" ]; then
    echo -e "${DIM} Detected ${#open_slots[@]} open Matrix window(s): slots [${open_slots[*]}]${RESET}"
    echo
fi

# Calculate available slots
declare -a available_slots
for s in $(seq 1 8); do
    if [[ " ${open_slots[*]} " != *" $s "* ]]; then
        available_slots+=("$s")
    fi
done
max_new=${#available_slots[@]}

if [ "$max_new" -eq 0 ]; then
    echo -e "${GREEN} All 8 Matrix slots are in use!${RESET}"
    echo -e "${DIM} Close some Matrix windows first.${RESET}"
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

# Save state
{
    echo '{"windows":['
    for i in "${!selected_presets[@]}"; do
        [ "$i" -gt 0 ] && echo ','
        echo -n "  {\"preset\": ${selected_presets[$i]}, \"slot\": ${selected_slots[$i]}}"
    done
    echo
    echo ']}'
} > "$STATE_FILE"

show_post_launch "$is_redpill"
