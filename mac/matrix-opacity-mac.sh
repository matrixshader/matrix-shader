#!/bin/bash
# Matrix Shader - Ghostty opacity control (macOS)
# macOS port of matrix-opacity.sh — uses SIGHUP instead of D-Bus
#
# Ctrl+Shift+B: Cycle current -> 0 -> 100 -> CUSTOM -> 0 -> 100 -> ...
# Ctrl+Shift+J: Opacity down 5% (saves as custom)
# Ctrl+Shift+K: Opacity up 5% (saves as custom)

MATRIX_TMP="/tmp/matrixshader-$(id -u)"
mkdir -p "$MATRIX_TMP"
CUSTOM_FILE="$MATRIX_TMP/matrix-opacity-custom"
STEP=5
MIN=0
MAX=100
CUSTOM_DEFAULT=85

# Read saved custom value (from J/K adjustments), fallback to default
if [ -f "$CUSTOM_FILE" ]; then
    custom=$(cat "$CUSTOM_FILE" 2>/dev/null)
    case "$custom" in
        ''|*[!0-9]*) custom=$CUSTOM_DEFAULT ;;
    esac
else
    custom=$CUSTOM_DEFAULT
fi

# Read current opacity from first matrix config
first_matrix=$(ls $MATRIX_TMP/ghostty-matrix-*.conf 2>/dev/null | head -1)
if [ -n "$first_matrix" ]; then
    raw=$(grep -oE 'background-opacity[[:space:]]*=[[:space:]]*[0-9.]+' "$first_matrix" 2>/dev/null | grep -oE '[0-9.]+$')
else
    raw=$(grep -oE 'background-opacity[[:space:]]*=[[:space:]]*[0-9.]+' "$HOME/.config/ghostty/config" 2>/dev/null | grep -oE '[0-9.]+$')
fi
[ -z "$raw" ] && raw="1.0"
current=$(awk "BEGIN {printf \"%d\", $raw * 100}")

case "$1" in
    toggle)
        if [ "$current" -ge 95 ]; then
            new=$custom
        elif [ "$current" -gt 5 ]; then
            new=0
        else
            new=100
        fi
        ;;
    down)
        new=$((current - STEP))
        [ "$new" -lt "$MIN" ] && new=$MIN
        echo "$new" > "$CUSTOM_FILE"
        ;;
    up)
        new=$((current + STEP))
        [ "$new" -gt "$MAX" ] && new=$MAX
        echo "$new" > "$CUSTOM_FILE"
        ;;
    *)
        echo "Usage: $0 [toggle|up|down]"
        exit 1
        ;;
esac

# Convert back to 0.0-1.0
newf=$(awk "BEGIN {printf \"%.2f\", $new / 100.0}")
[ "$newf" = "0.00" ] && newf="0"
[ "$newf" = "1.00" ] && newf="1"

# Update ALL matrix config files
for conf in $MATRIX_TMP/ghostty-matrix-*.conf; do
    [ -f "$conf" ] && sed -i '' "s/background-opacity = .*/background-opacity = $newf/" "$conf"
done

# Also update default config if it has background-opacity
defconf="$HOME/.config/ghostty/config"
[ -f "$defconf" ] && sed -i '' "s/background-opacity = .*/background-opacity = $newf/" "$defconf" 2>/dev/null

# Signal ALL Ghostty instances to reload via SIGHUP
for pid in $(pgrep -f "ghostty" 2>/dev/null); do
    # Only signal actual ghostty binaries, not scripts mentioning ghostty
    exe=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [[ "$exe" == *ghostty* ]]; then
        kill -HUP "$pid" 2>/dev/null
    fi
done
