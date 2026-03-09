"""Tests for hotkey_config_screen.py -- hotkey configuration TUI sub-screen."""

import sys
import os
import copy
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Mock hotkey_config before importing
import types

_mock_hc = types.ModuleType("hotkey_config")
_mock_hc.DEFAULT_BINDINGS = {
    "SwapLeft":           {"key": "Left",  "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "SwapRight":          {"key": "Right", "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "CycleLayout":        {"key": "L",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleTransparency": {"key": "B",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "OpacityDown":        {"key": "J",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "OpacityUp":          {"key": "K",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "SpeedUp":            {"key": "Down",  "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "SpeedDown":          {"key": "Up",    "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleFar":          {"key": "1",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleMid":          {"key": "2",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleNear":         {"key": "3",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ShowHelp":           {"key": "H",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ManualReload":       {"key": "F5",    "modifiers": ["Ctrl", "Shift"], "enabled": True},
}
_mock_hc.load_config = MagicMock(return_value=copy.deepcopy(_mock_hc.DEFAULT_BINDINGS))
_mock_hc.save_config = MagicMock()
_mock_hc.is_redpill = MagicMock(return_value=True)
_mock_hc.CONFIG_PATH = "/tmp/test-hotkeys.json"
sys.modules["hotkey_config"] = _mock_hc

from hotkey_config_screen import (
    HotkeyConfigScreen, ACTION_ORDER, ACTION_DISPLAY_NAMES,
    format_binding,
)


def _reset_mocks():
    _mock_hc.load_config.reset_mock()
    _mock_hc.save_config.reset_mock()
    _mock_hc.is_redpill.reset_mock()
    _mock_hc.is_redpill.return_value = True
    _mock_hc.load_config.return_value = copy.deepcopy(_mock_hc.DEFAULT_BINDINGS)


def _make_screen():
    _reset_mocks()
    return HotkeyConfigScreen(config=copy.deepcopy(_mock_hc.DEFAULT_BINDINGS))


# -----------------------------------------------------------------------
# Construction and ordering
# -----------------------------------------------------------------------

class TestConstruction:
    def test_action_order_has_13(self):
        assert len(ACTION_ORDER) == 13

    def test_all_actions_have_display_names(self):
        for action in ACTION_ORDER:
            assert action in ACTION_DISPLAY_NAMES

    def test_display_names(self):
        assert ACTION_DISPLAY_NAMES["SwapLeft"] == "Swap Window Left"
        assert ACTION_DISPLAY_NAMES["CycleLayout"] == "Cycle Layout Mode"
        assert ACTION_DISPLAY_NAMES["ManualReload"] == "Force Reload"

    def test_initial_state(self):
        screen = _make_screen()
        assert screen.selected_index == 0
        assert screen.edit_mode is False
        assert screen.status_message is None
        assert len(screen.actions) == 13


# -----------------------------------------------------------------------
# format_binding
# -----------------------------------------------------------------------

class TestFormatBinding:
    def test_standard_binding(self):
        binding = {"key": "Left", "modifiers": ["Ctrl", "Shift"], "enabled": True}
        assert format_binding(binding) == "Ctrl+Shift+Left"

    def test_disabled_binding(self):
        binding = {"key": "Left", "modifiers": ["Ctrl", "Shift"], "enabled": False}
        assert format_binding(binding) == "[Disabled]"

    def test_none_binding(self):
        assert format_binding(None) == "[Disabled]"

    def test_single_modifier(self):
        binding = {"key": "H", "modifiers": ["Ctrl"], "enabled": True}
        assert format_binding(binding) == "Ctrl+H"


# -----------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------

class TestNavigation:
    def test_move_down(self):
        screen = _make_screen()
        screen.move_selection(1)
        assert screen.selected_index == 1

    def test_move_up(self):
        screen = _make_screen()
        screen.selected_index = 5
        screen.move_selection(-1)
        assert screen.selected_index == 4

    def test_clamp_at_top(self):
        screen = _make_screen()
        screen.selected_index = 0
        screen.move_selection(-1)
        assert screen.selected_index == 0

    def test_clamp_at_bottom(self):
        screen = _make_screen()
        screen.selected_index = 12
        screen.move_selection(1)
        assert screen.selected_index == 12


# -----------------------------------------------------------------------
# Toggle disable
# -----------------------------------------------------------------------

class TestToggleDisable:
    def test_disable(self):
        screen = _make_screen()
        screen.toggle_disable()
        action = screen.actions[0]
        assert screen.config[action]["enabled"] is False
        assert "Disabled" in screen.status_message

    def test_re_enable(self):
        screen = _make_screen()
        action = screen.actions[0]
        screen.config[action]["enabled"] = False
        screen.toggle_disable()
        assert screen.config[action]["enabled"] is True
        assert "Enabled" in screen.status_message


# -----------------------------------------------------------------------
# Reset to defaults
# -----------------------------------------------------------------------

class TestResetDefaults:
    def test_reset(self):
        screen = _make_screen()
        screen.config["SwapLeft"]["key"] = "A"
        screen.reset_to_defaults()
        assert screen.config["SwapLeft"]["key"] == "Left"
        assert "Reset to defaults" in screen.status_message


# -----------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------

class TestSave:
    def test_save_success(self):
        screen = _make_screen()
        screen.save()
        _mock_hc.save_config.assert_called_once_with(screen.config)
        assert "Saved" in screen.status_message

    def test_save_error(self):
        screen = _make_screen()
        _mock_hc.save_config.side_effect = IOError("disk full")
        screen.save()
        assert "Error" in screen.status_message
        _mock_hc.save_config.side_effect = None


# -----------------------------------------------------------------------
# Edit mode
# -----------------------------------------------------------------------

class TestEditMode:
    def test_enter_edit_mode(self):
        screen = _make_screen()
        screen.enter_edit_mode()
        assert screen.edit_mode is True

    def test_enter_edit_on_disabled(self):
        screen = _make_screen()
        screen.config[screen.actions[0]]["enabled"] = False
        screen.enter_edit_mode()
        assert screen.edit_mode is False
        assert "Enable hotkey first" in screen.status_message

    def test_edit_capture_esc(self):
        screen = _make_screen()
        screen.edit_mode = True
        result = screen.handle_edit_capture(27)
        assert result is True
        assert screen.edit_mode is False

    def test_edit_capture_letter(self):
        screen = _make_screen()
        screen.edit_mode = True
        screen.handle_edit_capture(ord('x'))
        assert screen.edit_mode is False
        assert screen.config[screen.actions[0]]["key"] == "X"
        assert "Changed to" in screen.status_message

    def test_edit_capture_invalid(self):
        screen = _make_screen()
        screen.edit_mode = True
        result = screen.handle_edit_capture(0)  # Not a valid key
        assert result is False
        assert "Invalid key" in screen.status_message


# -----------------------------------------------------------------------
# Red Pill gate
# -----------------------------------------------------------------------

class TestRedPillGate:
    def test_gate_blocks_non_redpill(self):
        screen = _make_screen()
        _mock_hc.is_redpill.return_value = False
        mock_stdscr = MagicMock()
        # run() should show upgrade message and return after one getch
        screen.run(mock_stdscr)
        mock_stdscr.getch.assert_called_once()
