"""Hotkey action handlers for Matrix Shader (Linux).

All 13 hotkey actions implemented as standalone functions, consumed by
matrix_keys.py via the ACTION_MAP dispatch table.

Each action broadcasts to ALL active Matrix windows (via get_ghostty_bus_names).
Opacity actions delegate to matrix-opacity.sh (proven fast, correct 3-state cycle).
Opacity changes show a custom OSD toast (matrix_toast.py) with the new percentage.

Consumed by: matrix_keys.py event loop (Phase 2 Plan 03).
Dependencies: shader_service.py (Phase 1), Python 3 stdlib only.
"""

import json
import os
import subprocess
import sys
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

LAYOUT_MODES = ["pillars", "quads", "overlap", "auto"]

STATE_PATH = os.path.expanduser("~/.config/matrix-shader/state.json")

# Path to the proven-working opacity bash script
OPACITY_SCRIPT = os.path.expanduser("~/.local/bin/matrix-opacity.sh")

# Path to the OSD toast script (lives alongside this file)
TOAST_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "matrix_toast.py")

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



def action_speed_down() -> None:
    """Decrease RAIN_SPEED by SPEED_DELTA on all active Matrix windows."""
    mapping = get_ghostty_bus_names()
    if not mapping:
        return
    for slot in mapping:
        config = read_shader_config(slot)
        new_speed = max(config["RAIN_SPEED"] - SPEED_DELTA, SPEED_MIN)
        write_shader_param(slot, "RAIN_SPEED", new_speed)


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
    pass  # No toast for layer toggles — visual change is the feedback


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


# ---------------------------------------------------------------------------
# Opacity actions — delegate to proven matrix-opacity.sh
# ---------------------------------------------------------------------------

def _read_current_opacity() -> int:
    """Read the current background-opacity from the first matrix config.

    Returns opacity as an integer percentage (0-100).
    """
    import glob as _glob
    configs = sorted(_glob.glob("/tmp/ghostty-matrix-*.conf"))
    if not configs:
        configs = [os.path.expanduser("~/.config/ghostty/config")]
    for conf in configs:
        try:
            with open(conf) as f:
                for line in f:
                    if "background-opacity" in line:
                        val = line.split("=", 1)[1].strip()
                        return round(float(val) * 100)
        except (FileNotFoundError, ValueError, IndexError):
            continue
    return 100  # Default: fully opaque


def _fire_toast(opacity_pct: int) -> None:
    """Launch the OSD toast showing the opacity percentage.

    Fire-and-forget via subprocess.Popen. Silently ignores errors.
    """
    try:
        subprocess.Popen(
            [sys.executable, TOAST_SCRIPT, f"{opacity_pct}%"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (FileNotFoundError, OSError):
        pass


def _run_opacity(mode: str) -> None:
    """Call the working matrix-opacity.sh script directly.

    This is the original fast implementation — sed + busctl + gdbus.
    3-state toggle cycle: Off (100%) -> Custom (85%) -> Full (0%) -> Off.
    After the script runs, reads the new opacity and shows an OSD toast.
    """
    try:
        subprocess.run(
            [OPACITY_SCRIPT, mode],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return

    # Read the new opacity and show toast
    opacity = _read_current_opacity()
    _fire_toast(opacity)


def action_toggle_transparency() -> None:
    """Cycle: Off (100%) -> Custom (85%) -> Full transparent (0%) -> Off."""
    _run_opacity("toggle")


def action_opacity_down() -> None:
    """Decrease opacity by 5%."""
    _run_opacity("down")


def action_opacity_up() -> None:
    """Increase opacity by 5%."""
    _run_opacity("up")


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

    pass  # Layout mode written; actual repositioning deferred to Phase 6


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

    pass  # Visual change is the feedback


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
