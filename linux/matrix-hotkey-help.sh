#!/bin/bash
# Matrix Shader - Hotkey Help Popup
# Spawns a small Ghostty window with the hotkey reference card.
# Closes on any keypress.

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PYMOD_DIR="$SCRIPT_DIR"

# Find Ghostty binary
for gb in "$HOME/.local/share/matrixshader/ghostty" "$(which ghostty 2>/dev/null)"; do
    [ -x "$gb" ] && GHOSTTY_BIN="$gb" && break
done
[ -z "$GHOSTTY_BIN" ] && exit 1

MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"

# Generate help text
HELP_FILE=$(mktemp "$MATRIX_TMP/matrix-help-XXXXXX.txt")
python3 -B -c "
import sys; sys.path.insert(0, '$PYMOD_DIR')
from hotkey_actions import _build_help_text
print(_build_help_text())
" > "$HELP_FILE" 2>/dev/null

# If Python help generation failed, write a basic reference
if [ ! -s "$HELP_FILE" ]; then
    cat > "$HELP_FILE" <<'HELP'

  MATRIX SHADER — HOTKEY REFERENCE

  Ctrl+Shift+Up/Down     Speed up/down
  Ctrl+Shift+Left/Right  Swap windows
  Ctrl+Shift+1/2/3       Toggle layers (far/mid/near)
  Ctrl+Shift+B           Toggle transparency
  Ctrl+Shift+J/K         Opacity down/up
  Ctrl+Shift+L           Cycle layout
  Ctrl+Shift+S           Save positions
  Ctrl+Shift+R           Restore positions
  Ctrl+Shift+G           Toggle glitch
  Ctrl+Shift+F5          Force reload
  Ctrl+Shift+H           This help

HELP
fi

# Write temp config for help window
HELP_CONF=$(mktemp "$MATRIX_TMP/ghostty-help-XXXXXX.conf")
cat > "$HELP_CONF" <<EOF
background = #000000
foreground = #00ff4d
font-family = Nimbus Mono PS
font-size = 14
background-opacity = 0.9
gtk-titlebar = true
window-decoration = client
desktop-notifications = false
EOF

# Launch help window
"$GHOSTTY_BIN" --config-default-files=false --config-file="$HELP_CONF" \
    -e bash -c "cat '$HELP_FILE'; echo; echo '  Press any key to close...'; read -rsn1"

# Cleanup
rm -f "$HELP_CONF" "$HELP_FILE"
