#!/bin/bash
# Matrix Shader - Red Pill Control Panel (macOS/Ghostty)
# Self-relaunches in a Ghostty window if not already there.
# macOS port of linux/redpill.sh

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
TUI_SCRIPT="${SCRIPT_DIR}/../linux/redpill_tui.py"
MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"

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

# Handle --activate without launching Ghostty window
if [ "$1" = "--activate" ]; then
    export PYTHONPATH="${SCRIPT_DIR}:${SCRIPT_DIR}/../linux:${PYTHONPATH:-}"
    exec python3 -B "$TUI_SCRIPT" --activate "$2"
fi

# Self-relaunch inside Ghostty if not already there
if [ "$1" != "--in-ghostty" ]; then
    if [ -z "$GHOSTTY_BIN" ]; then
        echo "Error: Ghostty not found"
        echo "Install Ghostty.app to /Applications first."
        exit 1
    fi

    REDPILL_SHADER="$(cd "$SCRIPT_DIR/../shaders-glsl" && pwd)/matrix-codevision-ghostty.glsl"

    conf="$MATRIX_TMP/ghostty-redpill.conf"
    cat > "$conf" <<EOF
custom-shader = ${REDPILL_SHADER}
custom-shader-animation = always
background = #000000
foreground = #6EDCAA
font-family = ${FONT}
font-style = Bold
font-size = 9
adjust-cell-height = -4
window-padding-x = 1
window-padding-y = 1
window-width = 132
window-height = 58
background-opacity = 0.85
macos-titlebar-style = hidden
desktop-notifications = false
EOF

    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" \
        -e "$SCRIPT_PATH" --in-ghostty >/dev/null 2>&1 &
    disown
    exit 0
fi

# Running inside Ghostty -- launch the TUI
# Set up Python path so TUI can find mac modules
export PYTHONPATH="${SCRIPT_DIR}:${SCRIPT_DIR}/../linux:${PYTHONPATH:-}"
python3 -B "$TUI_SCRIPT"

# Command reference banner after TUI exits
python3 -B "$SCRIPT_DIR/../linux/command_banner.py" 2>/dev/null
