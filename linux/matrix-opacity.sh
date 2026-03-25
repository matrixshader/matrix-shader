#!/bin/bash
# Matrix Shader - Ghostty opacity control
# Matches Windows version hotkey behavior exactly
#
# Ctrl+Shift+B: Cycle current → 0 → 100 → CUSTOM → 0 → 100 → ...
# Ctrl+Shift+J: Opacity down 5% (saves as custom)
# Ctrl+Shift+K: Opacity up 5% (saves as custom)

CONFIG="$HOME/.config/ghostty/config"
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
    # Validate it's a number
    case "$custom" in
        ''|*[!0-9]*) custom=$CUSTOM_DEFAULT ;;
    esac
else
    custom=$CUSTOM_DEFAULT
fi

# Read current opacity from first matrix config (or default)
first_matrix=$(ls $MATRIX_TMP/ghostty-matrix-*.conf 2>/dev/null | head -1)
if [ -n "$first_matrix" ]; then
    raw=$(grep -oP 'background-opacity\s*=\s*\K[0-9.]+' "$first_matrix" 2>/dev/null)
else
    raw=$(grep -oP 'background-opacity\s*=\s*\K[0-9.]+' "$CONFIG" 2>/dev/null)
fi
[ -z "$raw" ] && raw="1.0"
# Convert to 0-100 integer
current=$(awk "BEGIN {printf \"%d\", $raw * 100}")

case "$1" in
    toggle)
        # Cycle: current → 0 → 100 → custom → 0 → 100 → custom
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
        # Save as custom value
        echo "$new" > "$CUSTOM_FILE"
        ;;
    up)
        new=$((current + STEP))
        [ "$new" -gt "$MAX" ] && new=$MAX
        # Save as custom value
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

# Update ONLY matrix window configs (NOT construct, preview, wakeupneo, or other windows)
for conf in $MATRIX_TMP/ghostty-matrix-*.conf; do
    [ -f "$conf" ] && sed -i "s/background-opacity = .*/background-opacity = $newf/" "$conf"
done

# Reload ONLY matrix windows (match by config filename pattern)
for pid in $(pgrep -u "$(id -u)" -f "ghostty.*ghostty-matrix-[0-9]"); do
    busname=$(busctl --user list 2>/dev/null | awk -v p="$pid" '$2==p && /ghostty/{print $1}')
    [ -n "$busname" ] && gdbus call --session --dest "$busname" \
        --object-path /com/mitchellh/ghostty \
        --method org.gtk.Actions.Activate \
        'reload-config' '[]' '{}' >/dev/null 2>&1
done
