"""Tests for layout controls in the Red Pill TUI (Phase 4, Plan 01)."""

import sys
import os
import json
import tempfile
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Import real shader_service, then mock only I/O functions
import shader_service as _real_ss

_io_patches = []


def setup_module():
    """Mock I/O functions on the real shader_service module."""
    _io_funcs = {
        "write_shader_param": MagicMock(),
        "write_shader_params": MagicMock(),
        "read_shader_config": MagicMock(return_value=dict(_real_ss.PARAM_DEFAULTS)),
        "get_ghostty_bus_names": MagicMock(return_value={}),
        "reload_ghostty": MagicMock(),
        "create_slot_shader": MagicMock(),
    }
    for name, mock in _io_funcs.items():
        p = patch.object(_real_ss, name, mock)
        p.start()
        _io_patches.append(p)


def teardown_module():
    """Restore real shader_service functions."""
    for p in _io_patches:
        p.stop()
    _io_patches.clear()


from redpill_tui import (
    RedpillTUI, cycle_layout_mode, load_state, save_state,
    LAYOUT_MODES, DEFAULT_LAYOUT, STATE_PATH,
)


def _make_tui(tmp_state_path=None):
    """Create a TUI with mocked state."""
    tui = RedpillTUI()
    tui.active_slot = 1
    tui.tabs = [(1, 0, 1, 0.3)]
    if tmp_state_path:
        tui._state_path = tmp_state_path
    return tui


# -----------------------------------------------------------------------
# cycle_layout_mode
# -----------------------------------------------------------------------

class TestCycleLayoutMode:
    def test_pillars_to_quads(self):
        assert cycle_layout_mode("Pillars") == "Quads"

    def test_quads_to_overlap(self):
        assert cycle_layout_mode("Quads") == "Overlap"

    def test_overlap_to_auto(self):
        assert cycle_layout_mode("Overlap") == "Auto"

    def test_auto_wraps_to_pillars(self):
        assert cycle_layout_mode("Auto") == "Pillars"

    def test_unknown_defaults_to_pillars(self):
        assert cycle_layout_mode("bogus") == "Pillars"

    def test_empty_defaults_to_pillars(self):
        assert cycle_layout_mode("") == "Pillars"


# -----------------------------------------------------------------------
# Layout action handlers
# -----------------------------------------------------------------------

class TestLayoutActions:
    def test_layout_cycle(self):
        tui = _make_tui()
        tui.layout["mode"] = "Pillars"
        with patch("redpill_tui.save_state"):
            tui.handle_action("LayoutCycle")
        assert tui.layout["mode"] == "Quads"

    def test_layout_cycle_wraps(self):
        tui = _make_tui()
        tui.layout["mode"] = "Auto"
        with patch("redpill_tui.save_state"):
            tui.handle_action("LayoutCycle")
        assert tui.layout["mode"] == "Pillars"

    def test_glitch_toggle_on(self):
        tui = _make_tui()
        tui.layout["glitch_enabled"] = False
        with patch("redpill_tui.save_state"):
            tui.handle_action("GlitchToggle")
        assert tui.layout["glitch_enabled"] is True

    def test_glitch_toggle_off(self):
        tui = _make_tui()
        tui.layout["glitch_enabled"] = True
        with patch("redpill_tui.save_state"):
            tui.handle_action("GlitchToggle")
        assert tui.layout["glitch_enabled"] is False

    def test_priority_toggle(self):
        tui = _make_tui()
        tui.layout["priority_lock"] = False
        with patch("redpill_tui.save_state"):
            tui.handle_action("PriorityToggle")
        assert tui.layout["priority_lock"] is True

    def test_priority_toggle_off(self):
        tui = _make_tui()
        tui.layout["priority_lock"] = True
        with patch("redpill_tui.save_state"):
            tui.handle_action("PriorityToggle")
        assert tui.layout["priority_lock"] is False

    def test_primary_decrease(self):
        tui = _make_tui()
        tui.layout["primary_window_count"] = 3
        with patch("redpill_tui.save_state"):
            tui.handle_action("PrimaryDecrease")
        assert tui.layout["primary_window_count"] == 2

    def test_primary_decrease_clamp(self):
        tui = _make_tui()
        tui.layout["primary_window_count"] = 0
        with patch("redpill_tui.save_state"):
            tui.handle_action("PrimaryDecrease")
        assert tui.layout["primary_window_count"] == 0

    def test_primary_increase(self):
        tui = _make_tui()
        tui.layout["primary_window_count"] = 3
        with patch("redpill_tui.save_state"):
            tui.handle_action("PrimaryIncrease")
        assert tui.layout["primary_window_count"] == 4

    def test_primary_increase_clamp(self):
        tui = _make_tui()
        tui.layout["primary_window_count"] = 8
        with patch("redpill_tui.save_state"):
            tui.handle_action("PrimaryIncrease")
        assert tui.layout["primary_window_count"] == 8

    def test_primary_reset(self):
        tui = _make_tui()
        tui.layout["primary_window_count"] = 5
        with patch("redpill_tui.save_state"):
            tui.handle_action("PrimaryReset")
        assert tui.layout["primary_window_count"] == 0

    def test_snapback_save(self):
        tui = _make_tui()
        tui.tabs = [(1, 0, 1, 0.3), (2, 1, 0, 0)]
        with patch("redpill_tui.save_state"):
            tui.handle_action("SnapbackSave")
        assert "1" in tui.snapback_positions
        assert "2" in tui.snapback_positions

    def test_snapback_restore_noop(self):
        """Restore is a no-op until positioning is implemented."""
        tui = _make_tui()
        tui.handle_action("SnapbackRestore")  # Should not crash

    def test_monitor_change_noop(self):
        """MonitorChange is a no-op."""
        tui = _make_tui()
        tui.handle_action("MonitorChange")  # Should not crash

    def test_layout_cycle_persists(self):
        """Layout cycle should call save_state."""
        tui = _make_tui()
        with patch("redpill_tui.save_state") as mock_save:
            tui.handle_action("LayoutCycle")
            mock_save.assert_called_once()

    def test_glitch_toggle_persists(self):
        tui = _make_tui()
        with patch("redpill_tui.save_state") as mock_save:
            tui.handle_action("GlitchToggle")
            mock_save.assert_called_once()


# -----------------------------------------------------------------------
# State persistence
# -----------------------------------------------------------------------

class TestStatePersistence:
    def test_save_and_load_roundtrip(self, tmp_path):
        state_file = tmp_path / "state.json"
        with patch("redpill_tui.STATE_PATH", str(state_file)):
            save_state({"layout": {"mode": "Quads"}})
            result = load_state()
            assert result["layout"]["mode"] == "Quads"

    def test_load_missing_file(self, tmp_path):
        with patch("redpill_tui.STATE_PATH", str(tmp_path / "missing.json")):
            result = load_state()
            assert result == {}

    def test_save_creates_directory(self, tmp_path):
        state_file = tmp_path / "sub" / "dir" / "state.json"
        with patch("redpill_tui.STATE_PATH", str(state_file)):
            save_state({"test": True})
            assert state_file.exists()


# -----------------------------------------------------------------------
# Dirty tracking
# -----------------------------------------------------------------------

class TestDirtyTracking:
    def test_starts_clean(self):
        tui = _make_tui()
        assert tui.dirty is False

    def test_layout_default_state(self, tmp_path):
        with patch("redpill_tui.STATE_PATH", str(tmp_path / "missing.json")):
            tui = _make_tui()
        assert tui.layout["mode"] == "Pillars"
        assert tui.layout["glitch_enabled"] is True
        assert tui.layout["priority_lock"] is False
        assert tui.layout["primary_window_count"] == 0
