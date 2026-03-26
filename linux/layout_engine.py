"""Layout engine for Matrix Shader window positioning (Linux).

Direct port of MatrixShader.Core/Services/LayoutService.cs to Python.
Calculates and applies Pillars, Quads, Overlap, and Auto layouts
across one or more monitors using window_service.py for positioning.

Layout modes:
  - Pillars: Side-by-side vertical columns, full screen height
  - Quads: 2x2 grid with centered gap cross
  - Overlap: Stacked windows with configurable overlap percentage
  - Auto: Pillars for <= 4 windows, Quads for > 4

Consumed by: hotkey_actions.py (CycleLayout), matrix_keys.py (glitch timer)
Dependencies: window_service.py (Phase 5), state.json persistence
"""

import json
import os
import tempfile
import time

import window_service

# ---------------------------------------------------------------------------
# Constants (matching Windows LayoutService.cs)
# ---------------------------------------------------------------------------

MIN_WINDOW_WIDTH = 200
DEFAULT_MAX_PILLARS = 4
DEFAULT_GAP_SIZE = 30
MIN_SCALED_GAP = 20
MAX_GAP_SIZE = 200
DEFAULT_OVERLAP_PERCENT = 5
GLITCH_DRIFT_THRESHOLD = 15  # pixels of drift before snapping back
GLITCH_CHECK_INTERVAL = 3.0  # seconds between glitch checks

STATE_PATH = os.path.expanduser("~/.config/matrix-shader/state.json")


# ---------------------------------------------------------------------------
# State persistence helpers
# ---------------------------------------------------------------------------

def _load_state():
    """Read state.json, returning empty dict on failure."""
    try:
        with open(STATE_PATH) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def _save_state(state):
    """Atomic write to state.json."""
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


def load_layout_config():
    """Load layout config from state.json.

    Returns dict with keys: mode, gap_size, glitch_enabled, overlap_percent.
    """
    state = _load_state()
    layout = state.get("layout", {})
    return {
        "mode": layout.get("mode", "pillars"),
        "gap_size": layout.get("gap_size", DEFAULT_GAP_SIZE),
        "glitch_enabled": layout.get("glitch_enabled", True),
        "overlap_percent": layout.get("overlap_percent", DEFAULT_OVERLAP_PERCENT),
    }


def save_layout_config(config):
    """Save layout config to state.json under the 'layout' key."""
    state = _load_state()
    state["layout"] = {
        "mode": config["mode"],
        "gap_size": config["gap_size"],
        "glitch_enabled": config["glitch_enabled"],
        "overlap_percent": config["overlap_percent"],
    }
    _save_state(state)


# ---------------------------------------------------------------------------
# Gap scaling (matches LayoutService.cs CalculateScaledGap)
# ---------------------------------------------------------------------------

def calculate_scaled_gap(base_gap, window_count):
    """Scale gap size based on window count.

    1-2 windows: 100%, 3 windows: 80%, 4+ windows: 60%.
    Never below MIN_SCALED_GAP.
    """
    if window_count <= 2:
        scale = 1.0
    elif window_count == 3:
        scale = 0.8
    else:
        scale = 0.6
    return max(int(base_gap * scale), MIN_SCALED_GAP)


# ---------------------------------------------------------------------------
# Window distribution across monitors
# ---------------------------------------------------------------------------

def distribute_windows(window_count, screen_count, max_per_screen):
    """Distribute windows across monitors with balanced allocation.

    Primary monitor (index 0) gets priority for remainder windows.
    Matches LayoutService.cs DistributeWindows.

    Returns list of ints, one per screen.
    """
    distribution = [0] * screen_count

    if window_count <= 0 or screen_count <= 0:
        return distribution

    if screen_count == 1:
        distribution[0] = window_count
        return distribution

    base_count = window_count // screen_count
    remainder = window_count % screen_count

    for i in range(screen_count):
        count = base_count + (1 if i < remainder else 0)
        distribution[i] = min(count, max_per_screen)

    return distribution


# ---------------------------------------------------------------------------
# Layout algorithms
# ---------------------------------------------------------------------------

def calculate_pillars_layout(window_count, monitors, config):
    """Calculate Pillars layout: vertical columns side-by-side.

    Windows tile edge-to-edge, full screen height, gaps only between pillars.
    Matches LayoutService.cs CalculatePillarsLayout.

    Returns list of dicts with x, y, width, height, monitor_index.
    """
    gap_size = calculate_scaled_gap(config["gap_size"], window_count)
    max_pillars = DEFAULT_MAX_PILLARS
    distribution = distribute_windows(window_count, len(monitors), max_pillars)

    positions = []
    for screen_idx, monitor in enumerate(monitors):
        windows_on_screen = distribution[screen_idx]
        if windows_on_screen == 0:
            continue

        mx, my = monitor["x"], monitor["y"]
        mw, mh = monitor["width"], monitor["height"]
        columns = windows_on_screen

        adjusted_gap = gap_size
        between_gaps = max(0, columns - 1)
        total_h_gaps = between_gaps * adjusted_gap
        cell_width = (mw - total_h_gaps) // columns
        cell_height = mh

        # Reduce gaps if windows too narrow
        while cell_width < MIN_WINDOW_WIDTH and adjusted_gap > 0 and columns > 1:
            adjusted_gap = max(0, adjusted_gap - 5)
            total_h_gaps = between_gaps * adjusted_gap
            cell_width = (mw - total_h_gaps) // columns

        if cell_width < MIN_WINDOW_WIDTH:
            adjusted_gap = 0
            cell_width = mw // columns

        for i in range(windows_on_screen):
            x = mx + i * (cell_width + adjusted_gap)
            y = my
            positions.append({
                "x": x, "y": y,
                "width": cell_width, "height": cell_height,
                "monitor_index": screen_idx,
            })

    return positions


def calculate_quads_layout(window_count, monitors, config):
    """Calculate Quads layout: 2x2 grid with centered gap cross.

    Gaps only between quadrants, flush to screen edges.
    Matches LayoutService.cs CalculateQuadsLayout.

    Returns list of dicts with x, y, width, height, monitor_index.
    """
    gap_size = calculate_scaled_gap(config["gap_size"], window_count)
    windows_per_quad = 4
    distribution = distribute_windows(window_count, len(monitors), windows_per_quad)

    # Check for overflow
    total_capacity = len(monitors) * windows_per_quad
    if window_count > total_capacity:
        return _calculate_extended_grid(window_count, monitors, config, distribution)

    positions = []
    for screen_idx, monitor in enumerate(monitors):
        windows_on_screen = distribution[screen_idx]
        if windows_on_screen == 0:
            continue

        mx, my = monitor["x"], monitor["y"]
        mw, mh = monitor["width"], monitor["height"]

        half_width = (mw - gap_size) // 2
        half_height = (mh - gap_size) // 2

        # TL, TR, BL, BR — flush to edges
        quad_positions = [
            (mx, my),
            (mx + half_width + gap_size, my),
            (mx, my + half_height + gap_size),
            (mx + half_width + gap_size, my + half_height + gap_size),
        ]

        for pos_idx in range(min(windows_on_screen, 4)):
            qx, qy = quad_positions[pos_idx]
            positions.append({
                "x": qx, "y": qy,
                "width": half_width, "height": half_height,
                "monitor_index": screen_idx,
            })

    return positions


def _calculate_extended_grid(window_count, monitors, config, distribution):
    """Extended grid for overflow (more than 4 windows per screen)."""
    import math
    gap_size = max(0, config["gap_size"])
    positions = []

    for screen_idx, monitor in enumerate(monitors):
        windows_on_screen = distribution[screen_idx]
        if windows_on_screen <= 0:
            continue

        mx, my = monitor["x"], monitor["y"]
        mw, mh = monitor["width"], monitor["height"]

        cols = max(2, int(math.ceil(math.sqrt(
            windows_on_screen * (mw / mh)
        ))))
        rows = int(math.ceil(windows_on_screen / cols))

        total_h_gaps = max(0, cols - 1) * gap_size
        total_v_gaps = max(0, rows - 1) * gap_size
        cell_width = (mw - total_h_gaps) // cols
        cell_height = (mh - total_v_gaps) // rows

        for i in range(windows_on_screen):
            col = i % cols
            row = i // cols
            x = mx + col * (cell_width + gap_size)
            y = my + row * (cell_height + gap_size)
            positions.append({
                "x": x, "y": y,
                "width": cell_width, "height": cell_height,
                "monitor_index": screen_idx,
            })

    return positions


def calculate_overlap_layout(window_count, monitors, config):
    """Calculate Overlap layout: stacked windows with configurable overlap.

    All windows on primary monitor, full height, centered as a group.
    Matches LayoutService.cs CalculateOverlapLayout.

    Returns list of dicts with x, y, width, height, monitor_index.
    """
    overlap_percent = max(0, min(20, config.get("overlap_percent", DEFAULT_OVERLAP_PERCENT)))

    # Use primary monitor
    primary_idx = 0
    for i, m in enumerate(monitors):
        if m.get("primary", False):
            primary_idx = i
            break

    monitor = monitors[primary_idx]
    mx, my = monitor["x"], monitor["y"]
    mw, mh = monitor["width"], monitor["height"]

    overlap_offset = int(mw * overlap_percent / 100.0)
    window_width = (mw + overlap_offset * (window_count - 1)) // window_count
    window_width = max(window_width, MIN_WINDOW_WIDTH)
    window_height = mh

    # Center the group
    total_width = window_width * window_count - overlap_offset * (window_count - 1)
    start_x = mx + (mw - total_width) // 2

    positions = []
    for i in range(window_count):
        x = start_x + i * (window_width - overlap_offset)
        positions.append({
            "x": x, "y": my,
            "width": window_width, "height": window_height,
            "monitor_index": primary_idx,
        })

    return positions


# ---------------------------------------------------------------------------
# High-level layout calculation
# ---------------------------------------------------------------------------

def calculate_layout(slots, config=None):
    """Calculate window positions for given slots.

    Args:
        slots: List of slot numbers (e.g. [1, 2, 3]).
        config: Layout config dict. If None, loaded from state.json.

    Returns:
        List of (slot, position_dict) tuples.
    """
    if not slots:
        return []

    if config is None:
        config = load_layout_config()

    monitors = window_service.get_monitors()
    if not monitors:
        return []

    # Sort monitors: primary first, then left-to-right
    monitors = sorted(monitors, key=lambda m: (not m.get("primary", False), m["x"]))

    window_count = len(slots)

    # Resolve Auto mode
    mode = config["mode"]
    if mode == "auto":
        mode = "pillars" if window_count <= 4 else "quads"

    # Calculate positions by mode
    if mode == "pillars":
        positions = calculate_pillars_layout(window_count, monitors, config)
    elif mode == "quads":
        positions = calculate_quads_layout(window_count, monitors, config)
    elif mode == "overlap":
        positions = calculate_overlap_layout(window_count, monitors, config)
    else:
        positions = calculate_pillars_layout(window_count, monitors, config)

    # Sort slots numerically for consistent ordering
    sorted_slots = sorted(slots)

    # Pair slots with positions
    result = []
    for i in range(min(len(sorted_slots), len(positions))):
        result.append((sorted_slots[i], positions[i]))

    return result


# ---------------------------------------------------------------------------
# Apply layout to windows
# ---------------------------------------------------------------------------

def apply_layout(slots=None, config=None):
    """Calculate and apply layout to all active Matrix windows.

    Args:
        slots: List of slot numbers. If None, discovered from window map.
        config: Layout config dict. If None, loaded from state.json.

    Returns:
        Number of windows successfully positioned.
    """
    if slots is None:
        mapping = window_service.load_mapping()
        slots = [int(s) for s in mapping.keys()
                 if window_service.get_pid_for_slot(int(s)) is not None]

    if not slots:
        return 0

    layout = calculate_layout(slots, config)
    success_count = 0

    for slot, pos in layout:
        ok = window_service.position_window(
            slot, pos["x"], pos["y"], pos["width"], pos["height"]
        )
        if ok:
            success_count += 1

    return success_count


def apply_current_layout():
    """Apply the current layout from state.json to all active windows.

    Convenience function for hotkey_actions.py integration.
    Returns number of windows positioned.
    """
    return apply_layout()


# ---------------------------------------------------------------------------
# Snapback: save and restore window positions
# ---------------------------------------------------------------------------

def snapback_save():
    """Save current window positions to state.json under 'snapback' key.

    Returns number of positions saved.
    """
    mapping = window_service.load_mapping()
    slots = [int(s) for s in mapping.keys()
             if window_service.get_pid_for_slot(int(s)) is not None]

    if not slots:
        return 0

    saved = {}
    for slot in sorted(slots):
        geo = window_service.get_position(slot)
        if geo:
            saved[str(slot)] = {
                "x": geo["x"], "y": geo["y"],
                "width": geo["width"], "height": geo["height"],
            }

    state = _load_state()
    state["snapback"] = saved
    _save_state(state)

    return len(saved)


def snapback_restore():
    """Restore window positions from state.json 'snapback' key.

    Returns number of windows restored.
    """
    state = _load_state()
    saved = state.get("snapback", {})

    if not saved:
        return 0

    restored = 0
    for slot_str, pos in saved.items():
        slot = int(slot_str)
        if window_service.get_pid_for_slot(slot) is None:
            continue
        ok = window_service.position_window(
            slot, pos["x"], pos["y"], pos["width"], pos["height"]
        )
        if ok:
            restored += 1

    return restored


# ---------------------------------------------------------------------------
# Glitch mode: auto-snap drifted windows back to formation
# ---------------------------------------------------------------------------

# Cache of last-applied positions for drift detection
_last_applied = {}  # slot -> {"x": ..., "y": ..., "width": ..., "height": ...}
_last_glitch_check = 0.0


def _update_applied_cache(slots_and_positions):
    """Update the cache of last-applied positions after a layout apply."""
    global _last_applied
    for slot, pos in slots_and_positions:
        _last_applied[slot] = {
            "x": pos["x"], "y": pos["y"],
            "width": pos["width"], "height": pos["height"],
        }


def check_and_snap():
    """Check if windows have drifted from their formation and snap back.

    Called periodically from the matrix_keys.py event loop timer.
    Only acts if glitch mode is enabled in state.json.

    Returns number of windows snapped, or -1 if glitch is disabled.
    """
    global _last_glitch_check

    config = load_layout_config()
    if not config["glitch_enabled"]:
        return -1

    now = time.time()
    if now - _last_glitch_check < GLITCH_CHECK_INTERVAL:
        return 0
    _last_glitch_check = now

    if not _last_applied:
        # No cached positions — seed from CURRENT actual window positions
        mapping = window_service.load_mapping()
        slots = [int(s) for s in mapping.keys()
                 if window_service.get_pid_for_slot(int(s)) is not None]
        layout = []
        for s in slots:
            geo = window_service.get_position(s)
            if geo:
                layout.append((s, {"x": geo["x"], "y": geo["y"],
                                   "width": geo["width"], "height": geo["height"]}))
        if layout:
            _update_applied_cache(layout)
        return 0

    # Only snap when windows overlap (skip if in overlap layout)
    if config.get("mode") == "overlap":
        return 0

    current_geos = {}
    for slot in _last_applied:
        geo = window_service.get_position(slot)
        if geo:
            current_geos[slot] = geo

    if len(current_geos) < 2:
        return 0

    # Detect overlap between any pair
    has_overlap = False
    slots_list = list(current_geos.keys())
    for i in range(len(slots_list)):
        for j in range(i + 1, len(slots_list)):
            a, b = current_geos[slots_list[i]], current_geos[slots_list[j]]
            if (a["x"] < b["x"] + b["width"] and a["x"] + a["width"] > b["x"] and
                a["y"] < b["y"] + b["height"] and a["y"] + a["height"] > b["y"]):
                has_overlap = True
                break
        if has_overlap:
            break

    if not has_overlap:
        return 0

    # Overlapping — snap positions back, keep current sizes
    snapped = 0
    for slot, target in _last_applied.items():
        cur = current_geos.get(slot)
        w = cur["width"] if cur else target["width"]
        h = cur["height"] if cur else target["height"]
        ok = window_service.position_window(
            slot, target["x"], target["y"], w, h
        )
        if ok:
            snapped += 1

    return snapped


# Patch apply_layout to update the glitch cache
_original_apply_layout = apply_layout


def _apply_layout_with_cache(slots=None, config=None):
    """Wrapper around apply_layout that updates the glitch position cache."""
    if slots is None:
        mapping = window_service.load_mapping()
        slots = [int(s) for s in mapping.keys()
                 if window_service.get_pid_for_slot(int(s)) is not None]

    if not slots:
        return 0

    cfg = config if config is not None else load_layout_config()
    layout = calculate_layout(slots, cfg)
    _update_applied_cache(layout)

    success_count = 0
    for slot, pos in layout:
        ok = window_service.position_window(
            slot, pos["x"], pos["y"], pos["width"], pos["height"]
        )
        if ok:
            success_count += 1

    return success_count


apply_layout = _apply_layout_with_cache
apply_current_layout = _apply_layout_with_cache
