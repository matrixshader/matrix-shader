#!/bin/bash
# Matrix Shader - Hotkey Help Popup
# Spawns a small Ghostty window with the hotkey reference card.
# Closes on any keypress.

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
# After install, Python modules live in ~/.local/share/matrixshader/pylib/,
# not alongside this script in ~/.local/bin/. Fall back to SCRIPT_DIR for
# development (running from the repo).
PYMOD_DIR="$HOME/.local/share/matrixshader/pylib"
if [ ! -f "$PYMOD_DIR/hotkey_actions.py" ]; then
    PYMOD_DIR="$SCRIPT_DIR"
fi
export PYTHONPATH="$PYMOD_DIR:$PYTHONPATH"

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
print()
print('  MATRIX SHADER — HOTKEY REFERENCE')
print()
for line in _build_help_text().splitlines():
    print('  ' + line)
print()
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
window-width = 60
window-height = 20
EOF

# Write a small display script so Ghostty -e gets a single executable path
# (avoids quoting issues with bash -c and Ghostty's argument splitting)
HELP_DISPLAY=$(mktemp "$MATRIX_TMP/matrix-help-display-XXXXXX.sh")
cat > "$HELP_DISPLAY" <<DISPLAYEOF
#!/bin/bash
cat '$HELP_FILE'
echo
echo '  Press any key to close...'
read -rsn1
DISPLAYEOF
chmod +x "$HELP_DISPLAY"

# Launch help window
"$GHOSTTY_BIN" --config-default-files=false --config-file="$HELP_CONF" \
    -e "$HELP_DISPLAY"

# Cleanup
rm -f "$HELP_CONF" "$HELP_FILE" "$HELP_DISPLAY"
