#!/bin/bash
# Matrix Shader - Hotkey Help Overlay (macOS)
# macOS port of matrix-hotkey-help.sh
# Spawns in its own Ghostty window, black bg, green text, box-drawing border

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Detect Ghostty binary
if [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
    GHOSTTY_BIN="/Applications/Ghostty.app/Contents/MacOS/ghostty"
elif [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
    GHOSTTY_BIN="$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
elif command -v ghostty &>/dev/null; then
    GHOSTTY_BIN="$(command -v ghostty)"
else
    echo "Error: Ghostty not found"
    exit 1
fi

# Detect font
if system_profiler SPFontsDataType 2>/dev/null | grep -qi "Nimbus Mono PS"; then
    FONT="Nimbus Mono PS"
elif system_profiler SPFontsDataType 2>/dev/null | grep -qi "SF Mono"; then
    FONT="SF Mono"
else
    FONT="Menlo"
fi

# Without --show flag: spawn a new Ghostty window and exit immediately
if [ "$1" != "--show" ]; then
    conf="/tmp/ghostty-hotkey-help.conf"
    cat > "$conf" <<CONFEOF
background = #000000
foreground = #35B381
font-family = ${FONT}
font-size = 14
background-opacity = 1
macos-titlebar-style = hidden
confirm-close-surface = false
CONFEOF
    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" -e "$SCRIPT_PATH" --show >/dev/null 2>&1 &
    disown
    exit 0
fi

# === DISPLAY CODE - only runs inside the overlay Ghostty window ===

BRIGHT='\033[38;2;110;220;170m'
BASE='\033[38;2;53;179;129m'
SOFT='\033[38;2;35;120;86m'
BORDER='\033[38;2;25;90;64m'
BOLD='\033[1m'
R='\033[0m'

TL=$'\u2554' TR=$'\u2557' BL=$'\u255A' BR=$'\u255D'
HZ=$'\u2550' VT=$'\u2551' ML=$'\u2560' MR=$'\u2563'

W=56

box_line() {
    local content="$1"
    local visible
    visible=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
    local vlen=${#visible}
    local pad=$((W - vlen))
    [ "$pad" -lt 0 ] && pad=0
    printf "  ${BORDER}${VT}${R}%b%*s${BORDER}${VT}${R}\n" "$content" "$pad" ""
}

hotkey_line() {
    printf -v padded_key "%-24s" "$1"
    box_line "  ${BASE}${padded_key}${R}${SOFT}${2}${R}"
}

clear
tput civis 2>/dev/null
echo

printf "  ${BORDER}${TL}"; printf "${HZ}%.0s" $(seq 1 $W); printf "${TR}${R}\n"

box_line "  ${BRIGHT}${BOLD}M A T R I X   S H A D E R${R}"
box_line "  ${SOFT}Hotkey Reference${R}"

printf "  ${BORDER}${ML}"; printf "${HZ}%.0s" $(seq 1 $W); printf "${MR}${R}\n"
box_line ""

box_line "  ${BRIGHT}${BOLD}TRANSPARENCY${R}"
box_line ""
hotkey_line "Ctrl+Shift+B" "Toggle: Off / Custom / Full"
hotkey_line "Ctrl+Shift+J" "Opacity down 5%"
hotkey_line "Ctrl+Shift+K" "Opacity up 5%"
box_line ""

box_line "  ${BRIGHT}${BOLD}RAIN SPEED${R}"
box_line ""
hotkey_line "Ctrl+Shift+Down" "Speed up"
hotkey_line "Ctrl+Shift+Up" "Speed down"
box_line ""

box_line "  ${BRIGHT}${BOLD}LAYERS${R}"
box_line ""
hotkey_line "Ctrl+Shift+1" "Toggle far layer"
hotkey_line "Ctrl+Shift+2" "Toggle mid layer"
hotkey_line "Ctrl+Shift+3" "Toggle near layer"
box_line ""

box_line "  ${BRIGHT}${BOLD}LAYOUT${R}"
box_line ""
hotkey_line "Ctrl+Shift+L" "Cycle layout mode"
hotkey_line "Ctrl+Shift+Left" "Swap left"
hotkey_line "Ctrl+Shift+Right" "Swap right"
box_line ""

box_line "  ${BRIGHT}${BOLD}SYSTEM${R}"
box_line ""
hotkey_line "Ctrl+Shift+H" "This overlay"
hotkey_line "Ctrl+Shift+F5" "Reload shaders"
box_line ""

printf "  ${BORDER}${BL}"; printf "${HZ}%.0s" $(seq 1 $W); printf "${BR}${R}\n"
echo

sleep infinity
