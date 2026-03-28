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

MATRIX_TMP = f"/tmp/matrixshader-{os.getuid()}"

from shader_service import (
    get_all_ghostty_configs,
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
SPEED_MAX = 20.0    # From PARAM_RANGES

# Opacity constants -- matches Windows v1.0.4 AdjustOpacity
OPACITY_DELTA = 5   # 5% per step
MIN_OPACITY = 0
MAX_OPACITY = 100

LAYOUT_MODES = ["pillars", "quads", "overlap", "auto"]

STATE_PATH = os.path.expanduser("~/.config/matrix-shader/state.json")

# Path to the proven-working opacity bash script (legacy, no longer called by hotkey actions)
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
# Opacity actions — inline Python with overflow/underflow counters
# Port of Windows v1.0.4 AdjustOpacity (HotkeyActions.cs)
# ---------------------------------------------------------------------------

# Module-level state for overflow/underflow tracking per config file
_overflow_counters = {}    # config_path -> int
_underflow_counters = {}   # config_path -> int
_base_opacity = {}         # config_path -> int (for external change detection)


def _read_current_opacity() -> int:
    """Read the current background-opacity from any running Ghostty config.

    Returns opacity as an integer percentage (0-100).
    """
    configs = sorted(get_all_ghostty_configs())
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


def _read_opacity_from_config(conf_path: str) -> int:
    """Read background-opacity from a specific Ghostty config file.

    Returns opacity as an integer percentage (0-100).
    """
    try:
        with open(conf_path) as f:
            for line in f:
                if "background-opacity" in line:
                    val = line.split("=", 1)[1].strip()
                    return round(float(val) * 100)
    except (FileNotFoundError, ValueError, IndexError):
        pass
    return 100


def _write_opacity_to_config(conf_path: str, opacity_pct: int) -> None:
    """Write opacity to a Ghostty config file via atomic replace.

    Replaces the `background-opacity = X.XX` line with the new value.
    """
    import re as _re
    value = f"{opacity_pct / 100:.2f}"
    if value == "0.00":
        value = "0"
    if value == "1.00":
        value = "1"
    try:
        with open(conf_path) as f:
            content = f.read()
        content = _re.sub(
            r"background-opacity = .*",
            f"background-opacity = {value}",
            content,
        )
        fd, tmp_path = tempfile.mkstemp(
            dir=os.path.dirname(conf_path), suffix=".tmp"
        )
        try:
            with os.fdopen(fd, "w") as f:
                f.write(content)
            os.replace(tmp_path, conf_path)
        except Exception:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise
    except (FileNotFoundError, PermissionError):
        pass


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


def _adjust_opacity_with_counters(delta: int):
    """Adjust opacity with overflow/underflow counter logic.

    Port of Windows v1.0.4 AdjustOpacity. Iterates ALL Matrix configs.

    - If delta > 0 (increasing): drain underflow first, then increase, then overflow
    - If delta < 0 (decreasing): drain overflow first, then decrease, then underflow
    - External change detection: if _base_opacity[conf] != current, reset both counters

    Args:
        delta: Positive to increase, negative to decrease.

    Returns:
        Representative opacity (int) for toast display, or None if all windows
        are capped (no visual change happened).
    """
    configs = sorted(get_all_ghostty_configs())
    if not configs:
        return None

    any_changed = False
    representative_opacity = None

    for conf in configs:
        current = _read_opacity_from_config(conf)

        # External change detection: if someone changed opacity outside hotkeys
        if conf in _base_opacity and _base_opacity[conf] != current:
            _overflow_counters[conf] = 0
            _underflow_counters[conf] = 0

        overflow = _overflow_counters.get(conf, 0)
        underflow = _underflow_counters.get(conf, 0)

        if delta > 0:
            # Increasing opacity
            if underflow > 0:
                # Drain underflow first (no visual change)
                _underflow_counters[conf] = underflow - 1
                _base_opacity[conf] = current
                representative_opacity = current
                continue
            new_opacity = current + delta
            if new_opacity > MAX_OPACITY:
                new_opacity = MAX_OPACITY
                if current >= MAX_OPACITY:
                    # Already at max, increment overflow
                    _overflow_counters[conf] = overflow + 1
                    _base_opacity[conf] = current
                    representative_opacity = current
                    continue
            _write_opacity_to_config(conf, new_opacity)
            _base_opacity[conf] = new_opacity
            _overflow_counters[conf] = 0
            _underflow_counters[conf] = 0
            representative_opacity = new_opacity
            any_changed = True
        else:
            # Decreasing opacity
            if overflow > 0:
                # Drain overflow first (no visual change)
                _overflow_counters[conf] = overflow - 1
                _base_opacity[conf] = current
                representative_opacity = current
                continue
            new_opacity = current + delta  # delta is negative
            if new_opacity < MIN_OPACITY:
                new_opacity = MIN_OPACITY
                if current <= MIN_OPACITY:
                    # Already at min, increment underflow
                    _underflow_counters[conf] = underflow + 1
                    _base_opacity[conf] = current
                    representative_opacity = current
                    continue
            _write_opacity_to_config(conf, new_opacity)
            _base_opacity[conf] = new_opacity
            _overflow_counters[conf] = 0
            _underflow_counters[conf] = 0
            representative_opacity = new_opacity
            any_changed = True

    # Reload all Ghostty instances if anything changed
    if any_changed:
        mapping = get_ghostty_bus_names()
        for slot_info in mapping.values():
            reload_ghostty(slot_info["bus_name"])

    return representative_opacity if any_changed else None


def action_toggle_transparency() -> None:
    """Cycle: Off (100%) -> Custom (85%) -> Full transparent (0%) -> Off.

    Resets overflow/underflow counters on toggle.
    """
    configs = sorted(get_all_ghostty_configs())
    if not configs:
        return

    current = _read_opacity_from_config(configs[0])

    # 3-state cycle matching Windows behavior
    if current >= 100:
        new_opacity = 85
    elif current > 0:
        new_opacity = 0
    else:
        new_opacity = 100

    for conf in configs:
        _write_opacity_to_config(conf, new_opacity)
        # Reset counters on toggle
        _overflow_counters[conf] = 0
        _underflow_counters[conf] = 0
        _base_opacity[conf] = new_opacity

    # Reload all Ghostty instances
    mapping = get_ghostty_bus_names()
    for slot_info in mapping.values():
        reload_ghostty(slot_info["bus_name"])

    _fire_toast(new_opacity)
    svc = _get_state_service()
    if svc:
        svc.update_opacity(new_opacity)


def action_opacity_down() -> None:
    """Decrease opacity by 5% with underflow counter support."""
    result = _adjust_opacity_with_counters(-OPACITY_DELTA)
    if result is not None:
        _fire_toast(result)
        svc = _get_state_service()
        if svc:
            svc.update_opacity(result)


def action_opacity_up() -> None:
    """Increase opacity by 5% with overflow counter support."""
    result = _adjust_opacity_with_counters(OPACITY_DELTA)
    if result is not None:
        _fire_toast(result)
        svc = _get_state_service()
        if svc:
            svc.update_opacity(result)


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
        current = state.get("layout", {}).get("mode", "pillars")

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
        state.setdefault("layout", {})["mode"] = next_mode
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


def _swap_config_foregrounds(slot_a: int, slot_b: int) -> None:
    """Swap the foreground color between two slots' Ghostty config files.

    When windows swap positions, the foreground text color in each config
    must follow the shader so the text color matches the rain color.
    """
    import re as _re
    conf_a = f"{MATRIX_TMP}/ghostty-matrix-{slot_a}.conf"
    conf_b = f"{MATRIX_TMP}/ghostty-matrix-{slot_b}.conf"
    try:
        with open(conf_a) as f:
            content_a = f.read()
        with open(conf_b) as f:
            content_b = f.read()
    except FileNotFoundError:
        return

    fg_pattern = _re.compile(r"^(foreground\s*=\s*)(.+)$", _re.MULTILINE)
    match_a = fg_pattern.search(content_a)
    match_b = fg_pattern.search(content_b)
    if not match_a or not match_b:
        return

    fg_a = match_a.group(2).strip()
    fg_b = match_b.group(2).strip()
    if fg_a == fg_b:
        return

    content_a = fg_pattern.sub(f"\\g<1>{fg_b}", content_a)
    content_b = fg_pattern.sub(f"\\g<1>{fg_a}", content_b)
    try:
        with open(conf_a, "w") as f:
            f.write(content_a)
        with open(conf_b, "w") as f:
            f.write(content_b)
    except OSError:
        pass

    # Also update construct configs if they exist (construct-originated windows
    # have Ghostty reading $MATRIX_TMP/ghostty-construct-{slot}.conf)
    for slot, new_fg in [(slot_a, fg_b), (slot_b, fg_a)]:
        cconf = f"{MATRIX_TMP}/ghostty-construct-{slot}.conf"
        try:
            with open(cconf) as f:
                cc = f.read()
            cc = fg_pattern.sub(f"\\g<1>{new_fg}", cc)
            with open(cconf, "w") as f:
                f.write(cc)
        except (FileNotFoundError, OSError):
            pass


def _swap_with_neighbor(direction: str) -> None:
    """Swap the focused window's position with its left or right neighbor.

    Matches Windows RotateLeft/RotateRight behavior: only the focused window
    and its immediate neighbor trade positions. All other windows stay put.

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

    window_order = [s for s, _ in slot_geos]

    # Find the focused window (most recently active slot from state)
    focused_slot = window_service.get_focused_slot()
    if focused_slot is None or focused_slot not in window_order:
        # Fallback: use first slot for left, last for right
        current_idx = 0 if direction == "right" else len(window_order) - 1
    else:
        current_idx = window_order.index(focused_slot)

    # Calculate neighbor index (wrap around)
    if direction == "left":
        neighbor_idx = (current_idx - 1 + len(window_order)) % len(window_order)
    else:
        neighbor_idx = (current_idx + 1) % len(window_order)

    if current_idx == neighbor_idx:
        return

    # Swap only the two windows — everything else stays put
    current_slot = window_order[current_idx]
    neighbor_slot = window_order[neighbor_idx]
    current_geo = slot_geos[current_idx][1]
    neighbor_geo = slot_geos[neighbor_idx][1]

    window_service.position_window(
        current_slot, neighbor_geo["x"], neighbor_geo["y"],
        neighbor_geo["width"], neighbor_geo["height"]
    )
    window_service.position_window(
        neighbor_slot, current_geo["x"], current_geo["y"],
        current_geo["width"], current_geo["height"]
    )

    # Swap foreground colors in Ghostty config files so text color follows the window
    _swap_config_foregrounds(current_slot, neighbor_slot)

    # Update layout cache with new positions
    result_layout = []
    for i, (slot, geo) in enumerate(slot_geos):
        if i == current_idx:
            result_layout.append((current_slot, neighbor_geo))
        elif i == neighbor_idx:
            result_layout.append((neighbor_slot, current_geo))
        else:
            result_layout.append((slot, geo))
    _update_applied_cache(result_layout)


def action_swap_left() -> None:
    """Swap focused window with its left neighbor."""
    _swap_with_neighbor("left")


def action_swap_right() -> None:
    """Swap focused window with its right neighbor."""
    _swap_with_neighbor("right")


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
    """Toggle glitch mode — Red Pill only. Free users get a nag."""
    try:
        from hotkey_config import is_redpill
        if not is_redpill():
            show_toast("Red Pill required")
            return
        from layout_engine import load_layout_config, save_layout_config
        config = load_layout_config()
        config["glitch_enabled"] = not config["glitch_enabled"]
        save_layout_config(config)
        state_str = "ON" if config["glitch_enabled"] else "OFF"
        show_toast(f"Glitch: {state_str}")
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
