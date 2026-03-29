"""Tests for preset_menu_screen.py -- interactive preset management screen.

All shader_service and preset_service functions are mocked at the module level.
Tests verify PresetMenuScreen dispatches save/load/delete correctly.
"""

import os
import sys
from unittest.mock import MagicMock, patch, call

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import shader_service
import preset_menu_screen as pms
from preset_menu_screen import PresetMenuScreen

# ---------------------------------------------------------------------------
# Module-level mocks (same pattern as test_redpill_tui.py)
# ---------------------------------------------------------------------------

_save_preset = MagicMock()
_load_preset = MagicMock(return_value=dict(shader_service.PARAM_DEFAULTS))
_list_presets = MagicMock(return_value=[])
_delete_preset = MagicMock()
_sanitize_name = MagicMock(side_effect=lambda n: n.strip().lower().replace(" ", "-"))

_read_shader_config = MagicMock(return_value=dict(shader_service.PARAM_DEFAULTS))
_write_shader_params = MagicMock()
_get_ghostty_bus_names = MagicMock(return_value={})
_reload_ghostty = MagicMock()


def _install_mocks():
    """Install all mocks on the preset_menu_screen module namespace."""
    pms.save_preset = _save_preset
    pms.load_preset = _load_preset
    pms.list_presets = _list_presets
    pms.delete_preset = _delete_preset
    pms.sanitize_name = _sanitize_name
    pms.read_shader_config = _read_shader_config
    pms.write_shader_params = _write_shader_params
    pms.get_ghostty_bus_names = _get_ghostty_bus_names
    pms.reload_ghostty = _reload_ghostty


def _reset_mocks():
    """Reset all mocks to default state."""
    _save_preset.reset_mock()
    _save_preset.side_effect = None
    _load_preset.reset_mock()
    _load_preset.side_effect = None
    _load_preset.return_value = dict(shader_service.PARAM_DEFAULTS)
    _list_presets.reset_mock()
    _list_presets.side_effect = None
    _list_presets.return_value = []
    _delete_preset.reset_mock()
    _delete_preset.side_effect = None
    _sanitize_name.reset_mock()
    _sanitize_name.side_effect = lambda n: n.strip().lower().replace(" ", "-")
    _read_shader_config.reset_mock()
    _read_shader_config.side_effect = None
    _read_shader_config.return_value = dict(shader_service.PARAM_DEFAULTS)
    _write_shader_params.reset_mock()
    _write_shader_params.side_effect = None
    _get_ghostty_bus_names.reset_mock()
    _get_ghostty_bus_names.side_effect = None
    _get_ghostty_bus_names.return_value = {}
    _reload_ghostty.reset_mock()
    _reload_ghostty.side_effect = None
    _install_mocks()


_install_mocks()


def _make_screen(active_slot=1, presets=None):
    """Create a PresetMenuScreen with mocked dependencies."""
    _reset_mocks()
    if presets is not None:
        _list_presets.return_value = presets
    screen = PresetMenuScreen(active_slot=active_slot, presets_dir="/tmp/test-presets")
    return screen


def _sample_presets():
    """Return a sample list of presets for testing."""
    return [
        {"name": "blood-rain", "filename": "blood-rain.json",
         "color": (1.0, 0.1, 0.1), "saved_at": "2026-03-25T10:00:00+00:00"},
        {"name": "my-cool-preset", "filename": "my-cool-preset.json",
         "color": (0.0, 1.0, 0.3), "saved_at": "2026-03-28T15:30:00+00:00"},
        {"name": "night-mode", "filename": "night-mode.json",
         "color": (0.0, 0.6, 1.0), "saved_at": "2026-03-27T09:00:00+00:00"},
    ]


# ---------------------------------------------------------------------------
# TestEmptyList
# ---------------------------------------------------------------------------

class TestEmptyList:
    def test_empty_list_renders_message(self):
        """Empty preset list shows 'No presets saved yet' message."""
        screen = _make_screen(presets=[])
        output = screen._render()
        rendered = "".join(output)
        assert "No presets" in rendered

    def test_empty_list_shows_save_hint(self):
        """Empty list tells user to press S."""
        screen = _make_screen(presets=[])
        output = screen._render()
        rendered = "".join(output)
        assert "S" in rendered


# ---------------------------------------------------------------------------
# TestListRendering
# ---------------------------------------------------------------------------

class TestListRendering:
    def test_selected_preset_highlighted(self):
        """Selected preset row should use YELLOW color."""
        screen = _make_screen(presets=_sample_presets())
        screen.selected = 0
        output = screen._render()
        rendered = "".join(output)
        # YELLOW escape: \x1b[33m
        assert "\x1b[33m" in rendered

    def test_presets_show_names(self):
        """Each preset name appears in the rendered output."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        output = screen._render()
        rendered = "".join(output)
        for p in presets:
            assert p["name"] in rendered

    def test_preset_date_displayed(self):
        """Save date is formatted and displayed."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        output = screen._render()
        rendered = "".join(output)
        # "Mar 28" from 2026-03-28
        assert "Mar 28" in rendered


# ---------------------------------------------------------------------------
# TestNavigation
# ---------------------------------------------------------------------------

class TestNavigation:
    def test_down_arrow_moves_selection_down(self):
        """Down arrow increments selected index."""
        screen = _make_screen(presets=_sample_presets())
        screen.selected = 0
        screen._handle_key(-4)  # Down arrow
        assert screen.selected == 1

    def test_up_arrow_moves_selection_up(self):
        """Up arrow decrements selected index."""
        screen = _make_screen(presets=_sample_presets())
        screen.selected = 1
        screen._handle_key(-3)  # Up arrow
        assert screen.selected == 0

    def test_down_arrow_wraps_to_top(self):
        """Down from last item wraps to first."""
        screen = _make_screen(presets=_sample_presets())
        screen.selected = 2  # last item
        screen._handle_key(-4)  # Down arrow
        assert screen.selected == 0

    def test_up_arrow_wraps_to_bottom(self):
        """Up from first item wraps to last."""
        screen = _make_screen(presets=_sample_presets())
        screen.selected = 0
        screen._handle_key(-3)  # Up arrow
        assert screen.selected == 2


# ---------------------------------------------------------------------------
# TestSaveFlow
# ---------------------------------------------------------------------------

class TestSaveFlow:
    def test_save_calls_save_preset(self):
        """Save flow reads name, calls save_preset with current config."""
        screen = _make_screen(presets=[])
        # Mock read_key to type "cool" then Enter
        keys = [ord('c'), ord('o'), ord('o'), ord('l'), 10]  # Enter=10
        with patch.object(pms, 'read_key', side_effect=keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        _save_preset.assert_called_once()
        args = _save_preset.call_args
        assert args[0][0] == "cool"  # name
        assert args[1].get("presets_dir") == "/tmp/test-presets" or args[0][2] == "/tmp/test-presets"

    def test_save_empty_name_rejected(self):
        """Empty name shows error, save_preset NOT called."""
        screen = _make_screen(presets=[])
        # Just press Enter with nothing typed
        keys = [10]
        with patch.object(pms, 'read_key', side_effect=keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        _save_preset.assert_not_called()
        assert screen.status_msg is not None
        assert "empty" in screen.status_msg.lower() or "cannot" in screen.status_msg.lower()

    def test_save_esc_cancels(self):
        """ESC during name input cancels save."""
        screen = _make_screen(presets=[])
        keys = [ord('a'), ord('b'), 27]  # ESC=27
        with patch.object(pms, 'read_key', side_effect=keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        _save_preset.assert_not_called()

    def test_save_backspace_removes_char(self):
        """Backspace removes last character during name input."""
        screen = _make_screen(presets=[])
        # Type "abc", backspace, "d", Enter -> "abd"
        keys = [ord('a'), ord('b'), ord('c'), 127, ord('d'), 10]
        with patch.object(pms, 'read_key', side_effect=keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        _save_preset.assert_called_once()
        assert _save_preset.call_args[0][0] == "abd"

    def test_save_duplicate_overwrite_confirmed(self):
        """Duplicate name with Y confirmation overwrites."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        # Type "night-mode" then Enter, then Y to confirm overwrite
        name_keys = [ord(c) for c in "night-mode"] + [10, ord('y')]
        with patch.object(pms, 'read_key', side_effect=name_keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        _save_preset.assert_called_once()

    def test_save_duplicate_overwrite_rejected(self):
        """Duplicate name with N cancels overwrite."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        # Type "night-mode" then Enter, then N to reject
        name_keys = [ord(c) for c in "night-mode"] + [10, ord('n')]
        with patch.object(pms, 'read_key', side_effect=name_keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        _save_preset.assert_not_called()

    def test_save_status_message_set(self):
        """Successful save sets status message."""
        screen = _make_screen(presets=[])
        keys = [ord('t'), ord('e'), ord('s'), ord('t'), 10]
        with patch.object(pms, 'read_key', side_effect=keys):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_save()
        assert screen.status_msg is not None
        assert "saved" in screen.status_msg.lower() or "test" in screen.status_msg.lower()


# ---------------------------------------------------------------------------
# TestLoadFlow
# ---------------------------------------------------------------------------

class TestLoadFlow:
    def test_load_calls_write_params_and_reload(self):
        """Load applies preset params and triggers D-Bus reload."""
        presets = _sample_presets()
        screen = _make_screen(active_slot=1, presets=presets)
        screen.selected = 1  # my-cool-preset
        _get_ghostty_bus_names.return_value = {
            1: {"bus_name": "org.ghostty.test_1234", "pid": 1234}
        }
        custom_params = dict(shader_service.PARAM_DEFAULTS)
        custom_params["RAIN_R"] = 0.5
        _load_preset.return_value = custom_params

        screen._do_load()

        _load_preset.assert_called_once_with("my-cool-preset", "/tmp/test-presets")
        _write_shader_params.assert_called_once_with(1, custom_params)
        _reload_ghostty.assert_called_once_with("org.ghostty.test_1234")

    def test_load_empty_list_no_op(self):
        """Load with no presets does nothing."""
        screen = _make_screen(presets=[])
        screen._do_load()
        _load_preset.assert_not_called()
        _write_shader_params.assert_not_called()

    def test_load_file_not_found_shows_error(self):
        """Load handles race condition (preset deleted between list and load)."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        screen.selected = 0
        _load_preset.side_effect = FileNotFoundError("gone")

        screen._do_load()

        assert screen.status_msg is not None
        assert "not found" in screen.status_msg.lower() or "deleted" in screen.status_msg.lower()
        _write_shader_params.assert_not_called()

    def test_load_without_bus_name_still_writes_params(self):
        """Load writes params even if no bus name found (window may have closed)."""
        presets = _sample_presets()
        screen = _make_screen(active_slot=1, presets=presets)
        screen.selected = 0
        _get_ghostty_bus_names.return_value = {}  # No windows

        screen._do_load()

        _load_preset.assert_called_once()
        _write_shader_params.assert_called_once()
        _reload_ghostty.assert_not_called()


# ---------------------------------------------------------------------------
# TestDeleteFlow
# ---------------------------------------------------------------------------

class TestDeleteFlow:
    def test_delete_with_y_calls_delete_preset(self):
        """Delete with Y confirmation removes preset."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        screen.selected = 1  # my-cool-preset

        with patch.object(pms, 'read_key', return_value=ord('y')):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_delete()

        _delete_preset.assert_called_once_with("my-cool-preset", "/tmp/test-presets")

    def test_delete_with_n_no_op(self):
        """Delete with N cancels without removing."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        screen.selected = 0

        with patch.object(pms, 'read_key', return_value=ord('n')):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_delete()

        _delete_preset.assert_not_called()

    def test_delete_empty_list_no_op(self):
        """Delete with no presets does nothing."""
        screen = _make_screen(presets=[])
        screen._do_delete()
        _delete_preset.assert_not_called()

    def test_delete_adjusts_selection_index(self):
        """After deleting last item, selected index adjusts to stay in bounds."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        screen.selected = 2  # last item

        # After delete, list_presets returns one fewer
        def _shrink_list():
            _list_presets.return_value = presets[:2]
        _delete_preset.side_effect = lambda *a, **kw: _shrink_list()

        with patch.object(pms, 'read_key', return_value=ord('y')):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_delete()

        assert screen.selected <= 1

    def test_delete_status_message(self):
        """Successful delete sets status message."""
        presets = _sample_presets()
        screen = _make_screen(presets=presets)
        screen.selected = 0

        with patch.object(pms, 'read_key', return_value=ord('y')):
            with patch('sys.stdout', new_callable=lambda: MagicMock()):
                screen._do_delete()

        assert screen.status_msg is not None
        assert "deleted" in screen.status_msg.lower() or presets[0]["name"] in screen.status_msg.lower()


# ---------------------------------------------------------------------------
# TestKeyDispatch
# ---------------------------------------------------------------------------

class TestKeyDispatch:
    def test_esc_returns_false(self):
        """ESC key signals exit from run loop."""
        screen = _make_screen(presets=_sample_presets())
        result = screen._handle_key(27)  # ESC
        assert result is False

    def test_s_key_triggers_save(self):
        """Pressing 's' triggers save flow."""
        screen = _make_screen(presets=[])
        # Mock _do_save so it doesn't actually run
        screen._do_save = MagicMock()
        screen._handle_key(ord('s'))
        screen._do_save.assert_called_once()

    def test_capital_s_triggers_save(self):
        """Pressing 'S' also triggers save flow."""
        screen = _make_screen(presets=[])
        screen._do_save = MagicMock()
        screen._handle_key(ord('S'))
        screen._do_save.assert_called_once()

    def test_enter_triggers_load(self):
        """Enter triggers load flow."""
        screen = _make_screen(presets=_sample_presets())
        screen._do_load = MagicMock()
        screen._handle_key(10)
        screen._do_load.assert_called_once()

    def test_d_triggers_delete(self):
        """Pressing 'd' triggers delete flow."""
        screen = _make_screen(presets=_sample_presets())
        screen._do_delete = MagicMock()
        screen._handle_key(ord('d'))
        screen._do_delete.assert_called_once()

    def test_capital_d_triggers_delete(self):
        """Pressing 'D' also triggers delete flow."""
        screen = _make_screen(presets=_sample_presets())
        screen._do_delete = MagicMock()
        screen._handle_key(ord('D'))
        screen._do_delete.assert_called_once()

    def test_unknown_key_returns_true(self):
        """Unknown keys do not exit the loop."""
        screen = _make_screen(presets=_sample_presets())
        result = screen._handle_key(ord('z'))
        assert result is True
