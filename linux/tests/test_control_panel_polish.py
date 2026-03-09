"""Tests for Phase 4 Plan 03: help screen, dirty tracking, auto-save, state persistence."""

import sys
import os
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Mock shader_service before importing redpill_tui
import types

if "shader_service" not in sys.modules:
    _mock_ss = types.ModuleType("shader_service")
    _mock_ss.PARAM_DEFAULTS = {
        "RAIN_R": 0.0, "RAIN_G": 1.0, "RAIN_B": 0.3,
        "RAIN_SPEED": 0.8, "GLOW_STRENGTH": 0.8, "CHAR_WIDTH": 10.0,
        "TRAIL_POWER": 8.0, "RAIN_DENSITY": 0.4,
        "SHOW_L1": 1.0, "SHOW_L2": 1.0, "SHOW_L3": 1.0,
    }
    _mock_ss.PARAM_RANGES = {
        "RAIN_R": (0.0, 1.0), "RAIN_G": (0.0, 1.0), "RAIN_B": (0.0, 1.0),
        "RAIN_SPEED": (0.1, 5.0), "GLOW_STRENGTH": (0.2, 3.0),
        "CHAR_WIDTH": (6.0, 20.0), "TRAIL_POWER": (4.0, 15.0),
        "RAIN_DENSITY": (0.2, 1.0),
        "SHOW_L1": (0.0, 1.0), "SHOW_L2": (0.0, 1.0), "SHOW_L3": (0.0, 1.0),
    }
    _mock_ss.PRESET_COLORS = [
        (0.0, 1.0, 0.3), (0.0, 0.6, 1.0), (1.0, 0.1, 0.1),
        (0.7, 0.0, 1.0), (1.0, 0.7, 0.0), (0.0, 0.9, 0.9),
    ]
    _mock_ss.SLOT_SHADER_DIR = "/tmp/test-shaders"
    _mock_ss.write_shader_param = MagicMock()
    _mock_ss.write_shader_params = MagicMock()
    _mock_ss.read_shader_config = MagicMock(return_value=dict(_mock_ss.PARAM_DEFAULTS))
    _mock_ss.get_ghostty_bus_names = MagicMock(return_value={})
    _mock_ss.reload_ghostty = MagicMock()
    _mock_ss.create_slot_shader = MagicMock()

    def _real_clamp(param, value):
        lo, hi = _mock_ss.PARAM_RANGES.get(param, (0.0, 1.0))
        return max(lo, min(hi, value))

    _mock_ss.clamp_value = _real_clamp
    sys.modules["shader_service"] = _mock_ss

from redpill_tui import RedpillTUI, save_state


def _make_tui():
    tui = RedpillTUI()
    tui.active_slot = 1
    tui.tabs = [(1, 0, 1, 0.3)]
    tui._stdscr = None
    return tui


# -----------------------------------------------------------------------
# Help screen
# -----------------------------------------------------------------------

class TestHelpScreen:
    def test_help_dispatches(self):
        """? key dispatches to _show_help."""
        tui = _make_tui()
        mock_stdscr = MagicMock()
        tui._stdscr = mock_stdscr
        with patch("curses.color_pair", return_value=0):
            tui.handle_action("Help")
        # Should call getch to wait for keypress
        mock_stdscr.getch.assert_called()

    def test_help_renders_sections(self):
        """Help screen writes expected section headers."""
        tui = _make_tui()
        mock_stdscr = MagicMock()
        with patch("curses.color_pair", return_value=0):
            tui._show_help(mock_stdscr)
        # Collect all addstr calls
        calls = [str(c) for c in mock_stdscr.addstr.call_args_list]
        text = " ".join(calls)
        assert "HOTKEY HELP" in text
        assert "CONTROL PANEL KEYS" in text
        assert "SHIFT KEYS" in text
        assert "GLOBAL HOTKEYS" in text
        assert "Press any key to return" in text

    def test_help_none_stdscr(self):
        """Help with None stdscr is a no-op."""
        tui = _make_tui()
        tui._show_help(None)  # Should not crash


# -----------------------------------------------------------------------
# Reset to defaults (already in Phase 3, verify it works)
# -----------------------------------------------------------------------

class TestReset:
    def test_reset_writes_defaults(self):
        tui = _make_tui()
        tui.config["RAIN_SPEED"] = 3.0
        sys.modules["shader_service"].write_shader_params.reset_mock()
        tui.handle_action("Reset")
        sys.modules["shader_service"].write_shader_params.assert_called_once()
        assert tui.config == sys.modules["shader_service"].PARAM_DEFAULTS

    def test_reset_no_active_slot(self):
        tui = _make_tui()
        tui.active_slot = None
        sys.modules["shader_service"].write_shader_params.reset_mock()
        tui.handle_action("Reset")
        sys.modules["shader_service"].write_shader_params.assert_not_called()


# -----------------------------------------------------------------------
# Dirty tracking
# -----------------------------------------------------------------------

class TestDirtyTracking:
    def test_starts_clean(self):
        tui = _make_tui()
        assert tui.dirty is False

    def test_quit_sets_running_false(self):
        tui = _make_tui()
        tui.handle_action("Quit")
        assert tui.running is False


# -----------------------------------------------------------------------
# State persistence
# -----------------------------------------------------------------------

class TestStatePersistence:
    def test_save_full_state(self, tmp_path):
        state_file = tmp_path / "state.json"
        with patch("redpill_tui.STATE_PATH", str(state_file)):
            tui = _make_tui()
            tui.layout["mode"] = "Quads"
            tui.save_full_state()

            import json
            with open(state_file) as f:
                state = json.load(f)
            assert state["layout"]["mode"] == "Quads"
            assert state["active_tab"] == 1

    def test_save_full_state_includes_layout(self, tmp_path):
        state_file = tmp_path / "state.json"
        with patch("redpill_tui.STATE_PATH", str(state_file)):
            tui = _make_tui()
            tui.layout["glitch_enabled"] = True
            tui.layout["priority_lock"] = True
            tui.save_full_state()

            import json
            with open(state_file) as f:
                state = json.load(f)
            assert state["layout"]["glitch_enabled"] is True
            assert state["layout"]["priority_lock"] is True
