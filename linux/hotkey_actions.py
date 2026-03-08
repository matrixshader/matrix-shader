"""Hotkey action handlers for Matrix Shader (Linux).

All 13 hotkey actions implemented as standalone functions, consumed by
matrix-keys.py via the ACTION_MAP dispatch table.

Each action broadcasts to ALL active Matrix windows (via get_ghostty_bus_names).
Opacity actions modify Ghostty config files (not shader #defines).
Toast notifications fire via notify-send with dunst stack tag for replacement.

Consumed by: matrix-keys.py event loop (Phase 2 Plan 03).
Dependencies: shader_service.py (Phase 1), Python 3 stdlib only.
"""

import glob
import json
import os
import re
import subprocess
import tempfile

from shader_service import (
    get_ghostty_bus_names,
    read_shader_config,
    write_shader_param,
    reload_ghostty,
)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SPEED_DELTA = 0.5   # Matches Windows SpeedDelta = 0.5f
SPEED_MIN = 0.1     # From PARAM_RANGES
SPEED_MAX = 5.0     # From PARAM_RANGES

OPACITY_STEP = 5          # Matches Windows OpacityDelta=5, matrix-opacity.sh STEP=5
CUSTOM_DEFAULT = 85        # Matches matrix-opacity.sh CUSTOM_DEFAULT=85

LAYOUT_MODES = ["pillars", "quads", "overlap", "auto"]

STATE_PATH = os.path.expanduser("~/.config/matrix-shader/state.json")
GHOSTTY_CONFIG = os.path.expanduser("~/.config/ghostty/config")

# Import from shader_service (already imported above)
from shader_service import SLOT_SHADER_DIR


# ---------------------------------------------------------------------------
# Toast helper
# ---------------------------------------------------------------------------

def show_toast(message: str, title: str = "Matrix Shader") -> None:
    """Show a desktop notification that replaces the previous one.

    Fire-and-forget via subprocess.Popen. Uses dunst stack tag for
    replacement on rapid keypresses. Silently handles missing notify-send.

    Args:
        message: Notification body text.
        title: Notification title (default "Matrix Shader").
    """
    cmd = [
        "notify-send",
        "--app-name=Matrix Shader",
        "--expire-time=1500",
        "--hint=string:x-dunst-stack-tag:matrix-shader",
        title,
        message,
    ]
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        pass  # notify-send not installed


# ---------------------------------------------------------------------------
# Shader actions (broadcast to ALL windows)
# ---------------------------------------------------------------------------

def action_speed_up() -> None:
    """Increase RAIN_SPEED by SPEED_DELTA on all active Matrix windows."""
    mapping = get_ghostty_bus_names()
    if not mapping:
        return
    new_speed = None
    for slot in mapping:
        config = read_shader_config(slot)
        new_speed = min(config["RAIN_SPEED"] + SPEED_DELTA, SPEED_MAX)
        write_shader_param(slot, "RAIN_SPEED", new_speed)
    if new_speed is not None:
        show_toast(f"Speed: {new_speed:.1f}")


def action_speed_down() -> None:
    """Decrease RAIN_SPEED by SPEED_DELTA on all active Matrix windows."""
    mapping = get_ghostty_bus_names()
    if not mapping:
        return
    new_speed = None
    for slot in mapping:
        config = read_shader_config(slot)
        new_speed = max(config["RAIN_SPEED"] - SPEED_DELTA, SPEED_MIN)
        write_shader_param(slot, "RAIN_SPEED", new_speed)
    if new_speed is not None:
        show_toast(f"Speed: {new_speed:.1f}")


def _toggle_layer(param: str, label: str) -> None:
    """Toggle a layer parameter between 0.0 and 1.0 on all windows.

    Args:
        param: Shader parameter name (SHOW_L1, SHOW_L2, SHOW_L3).
        label: Human-readable layer name for toast.
    """
    mapping = get_ghostty_bus_names()
    if not mapping:
        return
    new_val = None
    for slot in mapping:
        config = read_shader_config(slot)
        new_val = 0.0 if config[param] >= 0.5 else 1.0
        write_shader_param(slot, param, new_val)
    if new_val is not None:
        show_toast(f"{label}: {'ON' if new_val > 0 else 'OFF'}")


def action_toggle_far() -> None:
    """Toggle the far (background) layer on all windows."""
    _toggle_layer("SHOW_L1", "Far layer")


def action_toggle_mid() -> None:
    """Toggle the mid layer on all windows."""
    _toggle_layer("SHOW_L2", "Mid layer")


def action_toggle_near() -> None:
    """Toggle the near (foreground) layer on all windows."""
    _toggle_layer("SHOW_L3", "Near layer")


def action_manual_reload() -> None:
    """Force D-Bus reload on ALL discovered Ghostty instances."""
    mapping = get_ghostty_bus_names()
    if not mapping:
        return
    for slot_info in mapping.values():
        reload_ghostty(slot_info["bus_name"])
    show_toast("Shaders reloaded")


# ---------------------------------------------------------------------------
# Opacity actions (modify Ghostty config files, not shader #defines)
# ---------------------------------------------------------------------------

def get_current_opacity() -> int:
    """Read current opacity from first /tmp/ghostty-matrix-*.conf file.

    Returns:
        Opacity as integer percentage (0-100). Default 100 if no files.
    """
    configs = sorted(glob.glob("/tmp/ghostty-matrix-*.conf"))
    if not configs:
        return 100
    try:
        with open(configs[0]) as f:
            match = re.search(r"background-opacity\s*=\s*([\d.]+)", f.read())
        if match:
            return int(float(match.group(1)) * 100)
    except (OSError, ValueError):
        pass
    return 100


def set_opacity(percent: int) -> None:
    """Write opacity to ALL matrix config files + default config, then reload.

    Args:
        percent: Opacity as integer percentage (0-100).
    """
    # Format opacity value
    if percent <= 0:
        value = "0"
    elif percent >= 100:
        value = "1"
    else:
        value = f"{percent / 100:.2f}"

    # Update all /tmp/ghostty-matrix-*.conf files
    for conf in glob.glob("/tmp/ghostty-matrix-*.conf"):
        try:
            with open(conf) as f:
                content = f.read()
            content = re.sub(
                r"background-opacity\s*=\s*[\d.]+",
                f"background-opacity = {value}",
                content,
            )
            with open(conf, "w") as f:
                f.write(content)
        except OSError:
            continue

    # Also update default Ghostty config
    if os.path.exists(GHOSTTY_CONFIG):
        try:
            with open(GHOSTTY_CONFIG) as f:
                content = f.read()
            content = re.sub(
                r"background-opacity\s*=\s*[\d.]+",
                f"background-opacity = {value}",
                content,
            )
            with open(GHOSTTY_CONFIG, "w") as f:
                f.write(content)
        except OSError:
            pass

    # Reload ALL Ghostty instances
    mapping = get_ghostty_bus_names()
    for slot_info in mapping.values():
        reload_ghostty(slot_info["bus_name"])

    show_toast(f"Opacity: {percent}%")


def action_toggle_transparency() -> None:
    """Toggle between 0% opacity and CUSTOM_DEFAULT (85%)."""
    current = get_current_opacity()
    if current > 0:
        set_opacity(0)
    else:
        set_opacity(CUSTOM_DEFAULT)


def action_opacity_down() -> None:
    """Decrease opacity by OPACITY_STEP%, minimum 0%."""
    current = get_current_opacity()
    set_opacity(max(current - OPACITY_STEP, 0))


def action_opacity_up() -> None:
    """Increase opacity by OPACITY_STEP%, maximum 100%."""
    current = get_current_opacity()
    set_opacity(min(current + OPACITY_STEP, 100))


# ---------------------------------------------------------------------------
# State actions
# ---------------------------------------------------------------------------

def action_cycle_layout() -> None:
    """Cycle through layout modes and write to state.json.

    Cycles: pillars -> quads -> overlap -> auto -> pillars ...
    NOTE: Actual window repositioning is deferred to Phase 6.
    """
    # Read current state
    state = {}
    try:
        with open(STATE_PATH) as f:
            state = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    current = state.get("layout_mode", "pillars")
    try:
        idx = LAYOUT_MODES.index(current)
    except ValueError:
        idx = 0
    next_mode = LAYOUT_MODES[(idx + 1) % len(LAYOUT_MODES)]
    state["layout_mode"] = next_mode

    # Atomic write to state.json
    dir_path = os.path.dirname(STATE_PATH)
    os.makedirs(dir_path, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(state, f, indent=2)
        os.replace(tmp_path, STATE_PATH)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

    show_toast(f"Layout: {next_mode}")


def _rotate_shaders(direction: str) -> None:
    """Rotate shader files between active slots.

    Args:
        direction: "left" or "right".
    """
    mapping = get_ghostty_bus_names()
    if len(mapping) < 2:
        return

    slots = sorted(mapping.keys())

    # Read all shader contents
    contents = {}
    for slot in slots:
        path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")
        try:
            with open(path) as f:
                contents[slot] = f.read()
        except FileNotFoundError:
            contents[slot] = ""

    # Rotate contents
    if direction == "left":
        # Left: slot N gets content from slot N+1 (wrapping)
        rotated = {}
        for i, slot in enumerate(slots):
            src_slot = slots[(i + 1) % len(slots)]
            rotated[slot] = contents[src_slot]
    else:
        # Right: slot N gets content from slot N-1 (wrapping)
        rotated = {}
        for i, slot in enumerate(slots):
            src_slot = slots[(i - 1) % len(slots)]
            rotated[slot] = contents[src_slot]

    # Write rotated contents
    for slot, content in rotated.items():
        path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")
        with open(path, "w") as f:
            f.write(content)

    # Reload all affected slots
    for slot_info in mapping.values():
        reload_ghostty(slot_info["bus_name"])

    show_toast(f"Slots rotated {direction}")


def action_swap_left() -> None:
    """Rotate slot shader assignments left (1->2->3->1)."""
    _rotate_shaders("left")


def action_swap_right() -> None:
    """Rotate slot shader assignments right (3->2->1->3)."""
    _rotate_shaders("right")


# ---------------------------------------------------------------------------
# Help action
# ---------------------------------------------------------------------------

HELP_TEXT = """\
Ctrl+Shift+Down  Speed Up
Ctrl+Shift+Up    Speed Down
Ctrl+Shift+1     Toggle Far Layer
Ctrl+Shift+2     Toggle Mid Layer
Ctrl+Shift+3     Toggle Near Layer
Ctrl+Shift+L     Cycle Layout
Ctrl+Shift+Left  Swap Left
Ctrl+Shift+Right Swap Right
Ctrl+Shift+B     Toggle Transparency
Ctrl+Shift+J     Opacity Down
Ctrl+Shift+K     Opacity Up
Ctrl+Shift+H     Show Help
Ctrl+Shift+F5    Reload Shaders"""


def action_show_help() -> None:
    """Send a desktop notification listing all 13 hotkey bindings."""
    cmd = [
        "notify-send",
        "--app-name=Matrix Shader",
        "--expire-time=10000",
        "--hint=string:x-dunst-stack-tag:matrix-shader",
        "Matrix Shader Hotkeys",
        HELP_TEXT,
    ]
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        pass


# ---------------------------------------------------------------------------
# Dispatch table
# ---------------------------------------------------------------------------

ACTION_MAP = {
    "SpeedUp": action_speed_up,
    "SpeedDown": action_speed_down,
    "ToggleFar": action_toggle_far,
    "ToggleMid": action_toggle_mid,
    "ToggleNear": action_toggle_near,
    "CycleLayout": action_cycle_layout,
    "SwapLeft": action_swap_left,
    "SwapRight": action_swap_right,
    "ToggleTransparency": action_toggle_transparency,
    "OpacityDown": action_opacity_down,
    "OpacityUp": action_opacity_up,
    "ShowHelp": action_show_help,
    "ManualReload": action_manual_reload,
}
