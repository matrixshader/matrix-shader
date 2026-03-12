"""Tests for Phase 4 Plan 03: help screen, dirty tracking, auto-save, state persistence."""

import sys
import os
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Import the real shader_service for constants, then mock I/O functions
# on the redpill_tui namespace (where `from shader_service import ...` bound them).
import shader_service as _real_ss
import redpill_tui as _rt
from redpill_tui import RedpillTUI, save_state

_write_shader_param = MagicMock()
_write_shader_params = MagicMock()
_read_shader_config = MagicMock(return_value=dict(_real_ss.PARAM_DEFAULTS))
_get_ghostty_bus_names = MagicMock(return_value={})
_reload_ghostty = MagicMock()
_create_slot_shader = MagicMock()


def _install_mocks():
    """Install mocks on redpill_tui namespace (re-run after conftest restores)."""
    _rt.write_shader_param = _write_shader_param
    _rt.write_shader_params = _write_shader_params
    _rt.read_shader_config = _read_shader_config
    _rt.get_ghostty_bus_names = _get_ghostty_bus_names
    _rt.reload_ghostty = _reload_ghostty
    _rt.create_slot_shader = _create_slot_shader


_install_mocks()


def _make_tui():
    _install_mocks()
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
        """? key dispatches to _show_help and waits for keypress."""
        tui = _make_tui()
        with patch("redpill_tui.sys.stdout") as mock_stdout, \
             patch("redpill_tui.read_key", return_value=ord(' ')):
            tui.handle_action("Help")
        # Should have written output (help screen content)
        mock_stdout.write.assert_called()

    def test_help_renders_sections(self):
        """Help screen writes expected section headers."""
        tui = _make_tui()
        with patch("redpill_tui.sys.stdout") as mock_stdout, \
             patch("redpill_tui.read_key", return_value=ord(' ')):
            tui._show_help()
        # Collect all write calls
        calls = [str(c) for c in mock_stdout.write.call_args_list]
        text = " ".join(calls)
        assert "HOTKEY HELP" in text
        assert "CONTROL PANEL KEYS" in text
        assert "SHIFT KEYS" in text
        assert "GLOBAL HOTKEYS" in text
        assert "Press any key to return" in text

    def test_help_no_crash(self):
        """Help screen runs without crash."""
        tui = _make_tui()
        with patch("redpill_tui.sys.stdout") as mock_stdout, \
             patch("redpill_tui.read_key", return_value=ord(' ')):
            tui._show_help()  # Should not crash


# -----------------------------------------------------------------------
# Reset to defaults (already in Phase 3, verify it works)
# -----------------------------------------------------------------------

class TestReset:
    def test_reset_writes_defaults(self):
        tui = _make_tui()
        tui.config["RAIN_SPEED"] = 3.0
        _write_shader_params.reset_mock()
        tui.handle_action("Reset")
        _write_shader_params.assert_called_once()
        assert tui.config == _real_ss.PARAM_DEFAULTS

    def test_reset_no_active_slot(self):
        tui = _make_tui()
        tui.active_slot = None
        _write_shader_params.reset_mock()
        tui.handle_action("Reset")
        _write_shader_params.assert_not_called()


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
