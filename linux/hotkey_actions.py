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



# ---------------------------------------------------------------------------
# Lazy state service (debounced persistence)
# ---------------------------------------------------------------------------

_state_svc = None


def _get_state_service():
    """Get or create the global StateService instance (lazy init)."""
    global _state_svc
    if _state_svc is None:
        try:
            from state_service import StateService
            _state_svc = StateService()
        except Exception:
            pass  # state_service not available
    return _state_svc


# ---------------------------------------------------------------------------
# Toast helper
# ---------------------------------------------------------------------------

def show_toast(message: str, title: str = "Matrix Shader") -> None:
    """Disabled — no popups in Matrix Shader."""
    return


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
        show_toast(f"Speed: {new_speed}")
    svc = _get_state_service()
    if svc:
        svc.mark_dirty()


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
        show_toast(f"Speed: {new_speed}")
    svc = _get_state_service()
    if svc:
        svc.mark_dirty()


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
        state_str = "ON" if new_val >= 0.5 else "OFF"
        show_toast(f"{label}: {state_str}")
    svc = _get_state_service()
    if svc:
        svc.mark_dirty()


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

    svc = _get_state_service()
    if svc:
        svc.update_opacity(opacity)


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
    """Cycle through layout modes, write to state.json, and reposition windows.

    Cycles: pillars -> quads -> overlap -> auto -> pillars ...
    """
    svc = _get_state_service()
    if svc:
        current = svc.state.get("layout", {}).get("mode", "pillars")
    else:
        # Fallback: read from file
        state = {}
        try:
            with open(STATE_PATH) as f:
                state = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        current = state.get("layout_mode", state.get("layout", {}).get("mode", "pillars"))

    try:
        idx = LAYOUT_MODES.index(current)
    except ValueError:
        idx = 0
    next_mode = LAYOUT_MODES[(idx + 1) % len(LAYOUT_MODES)]
    show_toast(f"Layout: {next_mode}")

    if svc:
        svc.update_layout({"mode": next_mode})
    else:
        # Fallback: manual write
        state["layout_mode"] = next_mode
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

    # Apply the new layout to reposition windows (Phase 6)
    try:
        from layout_engine import apply_current_layout
        apply_current_layout()
    except Exception:
        pass  # Layout engine may not be available yet


def _rotate_positions(direction: str) -> None:
    """Rotate window positions in the current layout formation.

    Reads CURRENT window positions and rotates them. E.g. with 2 windows
    at positions [A|B], SwapLeft produces [B|A], and another SwapLeft
    produces [A|B] again.

    Args:
        direction: "left" or "right".
    """
    try:
        from layout_engine import _update_applied_cache
        import window_service
    except ImportError:
        return

    mapping = window_service.load_mapping()
    live_slots = [
        int(s) for s in mapping.keys()
        if window_service.get_pid_for_slot(int(s)) is not None
    ]
    if len(live_slots) < 2:
        return

    # Read current positions and sort by X (left-to-right visual order)
    slot_geos = []
    for slot in live_slots:
        geo = window_service.get_position(slot)
        if not geo:
            return
        slot_geos.append((slot, geo))
    slot_geos.sort(key=lambda sg: sg[1]["x"])

    # Fixed positions (the physical spots on screen)
    positions = [
        {"x": g["x"], "y": g["y"], "width": g["width"], "height": g["height"]}
        for _, g in slot_geos
    ]
    # Window order (which slot sits in which position)
    window_order = [s for s, _ in slot_geos]

    # Rotate windows: LEFT = each window slides left, leftmost wraps right
    if direction == "left":
        rotated_windows = window_order[1:] + window_order[:1]
    else:
        rotated_windows = window_order[-1:] + window_order[:-1]

    # Apply: each rotated window gets the fixed position at that index
    result_layout = list(zip(rotated_windows, positions))
    _update_applied_cache(result_layout)

    for slot, pos in result_layout:
        window_service.position_window(
            slot, pos["x"], pos["y"], pos["width"], pos["height"]
        )


def action_swap_left() -> None:
    """Rotate window positions left in the layout formation."""
    _rotate_positions("left")


def action_swap_right() -> None:
    """Rotate window positions right in the layout formation."""
    _rotate_positions("right")


# ---------------------------------------------------------------------------
# Help action
# ---------------------------------------------------------------------------

# Human-readable labels for action names
_ACTION_LABELS = {
    "SpeedUp": "Speed Up",
    "SpeedDown": "Speed Down",
    "ToggleFar": "Toggle Far Layer",
    "ToggleMid": "Toggle Mid Layer",
    "ToggleNear": "Toggle Near Layer",
    "CycleLayout": "Cycle Layout",
    "SwapLeft": "Swap Left",
    "SwapRight": "Swap Right",
    "ToggleTransparency": "Toggle Transparency",
    "OpacityDown": "Opacity Down",
    "OpacityUp": "Opacity Up",
    "ShowHelp": "Show Help",
    "ManualReload": "Reload Shaders",
}


def _build_help_text() -> str:
    """Build help text from the current hotkey config."""
    from hotkey_config import load_config
    config = load_config()
    lines = []
    for action, binding in config.items():
        if not binding.get("enabled", True):
            continue
        mods = "+".join(binding.get("modifiers", []))
        key = binding.get("key", "?")
        combo = f"{mods}+{key}" if mods else key
        label = _ACTION_LABELS.get(action, action)
        lines.append(f"{combo:<20s} {label}")
    return "\n".join(lines)


HELP_SCRIPT = os.path.expanduser("~/.local/bin/matrix-hotkey-help.sh")


def action_show_help() -> None:
    """Launch the Ghostty-window help overlay showing all hotkey bindings."""
    try:
        subprocess.Popen(
            [HELP_SCRIPT],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (FileNotFoundError, OSError):
        pass


# ---------------------------------------------------------------------------
# Layout engine actions (Phase 6)
# ---------------------------------------------------------------------------

def action_snapback_save() -> None:
    """Save current window positions for later restoration."""
    try:
        from layout_engine import snapback_save
        count = snapback_save()
        if count > 0:
            show_toast(f"Saved {count} window position(s)")
    except Exception:
        pass


def action_snapback_restore() -> None:
    """Restore previously saved window positions."""
    try:
        from layout_engine import snapback_restore
        count = snapback_restore()
        if count > 0:
            show_toast(f"Restored {count} window position(s)")
    except Exception:
        pass


def action_glitch_toggle() -> None:
    """Toggle glitch mode (auto-snap windows back to formation)."""
    try:
        from layout_engine import load_layout_config, save_layout_config
        config = load_layout_config()
        config["glitch_enabled"] = not config["glitch_enabled"]
        save_layout_config(config)
        state_str = "ON" if config["glitch_enabled"] else "OFF"
        show_toast(f"Glitch mode: {state_str}")
    except Exception:
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
    "SnapbackSave": action_snapback_save,
    "SnapbackRestore": action_snapback_restore,
    "GlitchToggle": action_glitch_toggle,
}
