#!/bin/bash
# Matrix Shader - Red Pill Control Panel (Linux/Ghostty)
# Self-relaunches in a Ghostty window if not already there.

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
TUI_SCRIPT="${SCRIPT_DIR}/redpill_tui.py"
GHOSTTY_BIN="/home/neo/ghostty-build/zig-out/bin/ghostty"
MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"

# Handle --activate without launching Ghostty window
if [ "$1" = "--activate" ]; then
    exec python3 -B "$TUI_SCRIPT" --activate "$2"
fi

# Self-relaunch inside Ghostty if not already there
# Uses --in-ghostty flag (not env var) to avoid leaking through child processes
if [ "$1" != "--in-ghostty" ]; then
    # Check Ghostty exists
    if [ ! -f "$GHOSTTY_BIN" ]; then
        echo "Error: Ghostty not found at $GHOSTTY_BIN"
        echo "Build it first or update GHOSTTY_BIN path."
        exit 1
    fi

    REDPILL_SHADER="$(realpath "${SCRIPT_DIR}/../shaders-glsl/matrix-codevision-ghostty.glsl")"

    conf="$MATRIX_TMP/ghostty-redpill.conf"
    cat > "$conf" <<EOF
custom-shader = ${REDPILL_SHADER}
custom-shader-animation = always
background = #000000
foreground = #6EDCAA
font-family = Nimbus Mono PS
font-style = Bold
font-size = 9
adjust-cell-height = -4
window-padding-x = 1
window-padding-y = 1
window-width = 132
window-height = 58
background-opacity = 0.85
gtk-titlebar = true
window-decoration = client
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

    nohup "$GHOSTTY_BIN" --config-default-files=false --config-file="$conf" \
        -e "$SCRIPT_PATH" --in-ghostty >/dev/null 2>&1 &
    disown
    exit 0
fi

# Running inside Ghostty -- launch the TUI
python3 -B "$TUI_SCRIPT"

# Command reference banner after TUI exits
python3 -B "${SCRIPT_DIR}/command_banner.py" 2>/dev/null
