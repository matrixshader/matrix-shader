"""State persistence for Matrix Shader (Linux).

Linux equivalent of MatrixShader.Core/Services/ConfigService.cs +
MatrixShader.Core/Models/MatrixState.cs.

Provides:
  - load_state / save_state: JSON persistence with atomic write
  - _migrate_state: backward-compatible migration from old format
  - snapshot_shader_configs: capture live shader params from running slots
  - StateService: class with debounced saves for hotkey integration

State file: ~/.config/matrix-shader/state.json
Dependencies: Python 3 stdlib + shader_service.py (Phase 1).
"""

import copy
import json
import logging
import os
import tempfile
import threading
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

STATE_PATH = os.path.expanduser("~/.config/matrix-shader/state.json")

DEFAULT_LAYOUT = {
    "mode": "pillars",
    "gap_size": 120,
    "overlap_percent": 5,
    "glitch_enabled": True,
    "monitor_count": 1,
    "max_windows_per_monitor": 4,
}

DEFAULT_STATE = {
    "active_tab": 1,
    "shader_configs": {},
    "layout": dict(DEFAULT_LAYOUT),
    "window_slots": {},
    "opacity": 85,
    "last_saved": None,
}


# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

def _migrate_state(raw):
    """Migrate old-format state to new format if needed.

    Old format: {"windows": [{"preset": 0, "slot": 1}, ...]}
    New format: {"shader_configs": {"1": {...all 11 params...}}, ...}

    Args:
        raw: Dict loaded from state.json.

    Returns:
        Dict in new format.
    """
    if "windows" in raw and "shader_configs" not in raw:
        # Lazy import to avoid circular dependency at module level
        from shader_service import PARAM_DEFAULTS, PRESET_COLORS

        shader_configs = {}
        for window in raw.get("windows", []):
            slot = window.get("slot", 1)
            preset = window.get("preset", 0)
            config = dict(PARAM_DEFAULTS)
            if 0 <= preset < len(PRESET_COLORS):
                r, g, b = PRESET_COLORS[preset]
                config["RAIN_R"] = r
                config["RAIN_G"] = g
                config["RAIN_B"] = b
            shader_configs[str(slot)] = config

        migrated = {
            "active_tab": 1,
            "shader_configs": shader_configs,
            "layout": dict(DEFAULT_LAYOUT),
            "window_slots": {},
            "opacity": 85,
            "last_saved": None,
        }
        # Preserve any extra keys from old format
        for key, val in raw.items():
            if key not in ("windows",) and key not in migrated:
                migrated[key] = val

        logger.info("Migrated old-format state.json (%d windows)", len(raw.get("windows", [])))
        return migrated

    return raw


def _ensure_keys(state):
    """Ensure all top-level keys exist, merging with defaults.

    Args:
        state: Dict to validate.

    Returns:
        Dict with all required keys present.
    """
    for key, default_val in DEFAULT_STATE.items():
        if key not in state:
            if isinstance(default_val, dict):
                state[key] = copy.deepcopy(default_val)
            else:
                state[key] = default_val
    return state


# ---------------------------------------------------------------------------
# Load / Save
# ---------------------------------------------------------------------------

def load_state(path=None):
    """Load state from JSON file.

    If the file doesn't exist, returns a copy of DEFAULT_STATE.
    If JSON is corrupt, logs warning and returns DEFAULT_STATE.
    Migrates old format if detected.

    Args:
        path: State file path. If None, uses STATE_PATH.

    Returns:
        Dict with full state.
    """
    if path is None:
        path = STATE_PATH

    if not os.path.exists(path):
        return copy.deepcopy(DEFAULT_STATE)

    try:
        with open(path) as f:
            raw = json.load(f)
    except (json.JSONDecodeError, ValueError) as e:
        logger.warning("Corrupt state.json, using defaults: %s", e)
        return copy.deepcopy(DEFAULT_STATE)
    except OSError as e:
        logger.warning("Cannot read state.json, using defaults: %s", e)
        return copy.deepcopy(DEFAULT_STATE)

    state = _migrate_state(raw)
    state = _ensure_keys(state)
    return state


def save_state(state, path=None):
    """Save state to JSON file with atomic write.

    Updates last_saved timestamp. Creates parent directories if needed.

    Args:
        state: Dict to persist.
        path: State file path. If None, uses STATE_PATH.
    """
    if path is None:
        path = STATE_PATH

    state["last_saved"] = datetime.now(timezone.utc).isoformat()

    dir_path = os.path.dirname(path)
    if dir_path:
        os.makedirs(dir_path, exist_ok=True)

    content = json.dumps(state, indent=2) + "\n"

    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


# ---------------------------------------------------------------------------
# Snapshot
# ---------------------------------------------------------------------------

def snapshot_shader_configs():
    """Capture current shader configs from all active slots.

    Discovers running Ghostty instances and reads their shader parameters.

    Returns:
        Dict mapping str(slot) -> config dict with all 11 params.
    """
    from shader_service import get_ghostty_bus_names, read_shader_config

    mapping = get_ghostty_bus_names()
    configs = {}
    for slot in mapping:
        configs[str(slot)] = read_shader_config(slot)
    return configs


# ---------------------------------------------------------------------------
# StateService (debounced saves for hotkey integration)
# ---------------------------------------------------------------------------

class StateService:
    """In-memory state manager with debounced disk persistence.

    Provides update methods that modify the in-memory state and schedule
    a debounced write to disk. The debounce timer coalesces rapid changes
    (e.g. holding speed up key) into a single disk write.
    """

    def __init__(self, path=None, debounce_ms=500):
        """Initialize StateService.

        Args:
            path: State file path. If None, uses STATE_PATH.
            debounce_ms: Debounce interval in milliseconds.
        """
        self._path = path or STATE_PATH
        self._state = load_state(self._path)
        self._dirty = False
        self._timer = None
        self._debounce_s = debounce_ms / 1000.0
        self._lock = threading.Lock()

    @property
    def state(self):
        """Return current in-memory state dict."""
        return self._state

    def save(self):
        """Save current state to disk immediately."""
        # Snapshot live shader configs before saving
        try:
            live_configs = snapshot_shader_configs()
            if live_configs:
                self._state["shader_configs"] = live_configs
        except Exception:
            pass  # If snapshot fails, save what we have
        save_state(self._state, self._path)
        self._dirty = False

    def mark_dirty(self):
        """Schedule a debounced save.

        If called multiple times within the debounce interval,
        only a single disk write occurs after the last call.
        """
        with self._lock:
            self._dirty = True
            if self._timer is not None:
                self._timer.cancel()
            self._timer = threading.Timer(self._debounce_s, self._flush)
            self._timer.daemon = True
            self._timer.start()

    def _flush(self):
        """Debounce callback: save if still dirty."""
        with self._lock:
            if not self._dirty:
                return
            timer = self._timer
            self._timer = None
        try:
            self.save()
        except Exception as e:
            logger.warning("Failed to save state: %s", e)

    def flush(self):
        """Flush any pending saves immediately (call on shutdown)."""
        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
                self._timer = None
        if self._dirty:
            try:
                self.save()
            except Exception as e:
                logger.warning("Failed to flush state: %s", e)

    def update_shader_config(self, slot, config):
        """Update shader config for a slot in-memory and mark dirty.

        Args:
            slot: Slot number (int or str).
            config: Dict of parameter name -> value.
        """
        self._state["shader_configs"][str(slot)] = config
        self.mark_dirty()

    def update_layout(self, layout_dict):
        """Update layout config in-memory and mark dirty.

        Merges provided keys into existing layout dict.

        Args:
            layout_dict: Dict of layout keys to update.
        """
        if "layout" not in self._state:
            self._state["layout"] = dict(DEFAULT_LAYOUT)
        self._state["layout"].update(layout_dict)
        self.mark_dirty()

    def update_opacity(self, opacity_pct):
        """Update opacity in-memory and mark dirty.

        Args:
            opacity_pct: Integer percentage (0-100).
        """
        self._state["opacity"] = opacity_pct
        self.mark_dirty()
