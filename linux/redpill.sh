#!/bin/bash
# Matrix Shader - Red Pill Control Panel (Linux/Ghostty)
# Self-relaunches in a Ghostty window if not already there.

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
TUI_SCRIPT="${SCRIPT_DIR}/redpill_tui.py"
GHOSTTY_BIN="/home/neo/ghostty-build/zig-out/bin/ghostty"

# Self-relaunch inside Ghostty if not already there
# Uses --in-ghostty flag (not env var) to avoid leaking through child processes
if [ "$1" != "--in-ghostty" ]; then
    # Check Ghostty exists
    if [ ! -f "$GHOSTTY_BIN" ]; then
        echo "Error: Ghostty not found at $GHOSTTY_BIN"
        echo "Build it first or update GHOSTTY_BIN path."
        exit 1
    fi

    conf="/tmp/ghostty-redpill.conf"
    cat > "$conf" <<'EOF'
background = #000000
foreground = #6EDCAA
font-family = Nimbus Mono PS
font-style = Bold
font-size = 16
background-opacity = 1
gtk-titlebar = true
window-decoration = client
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
exec python3 "$TUI_SCRIPT"
