"""Tests for matrix-keys.py dispatch refactor — config-driven evdev event loop."""
import json
import os
import sys
from unittest.mock import patch, MagicMock, call

import pytest

# Ensure linux/ is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


# ---------------------------------------------------------------------------
# Helpers to create mock evdev events
# ---------------------------------------------------------------------------

def make_event(code, value, event_type=1):
    """Create a mock evdev event.

    Args:
        code: Key code (e.g. ecodes.KEY_DOWN).
        value: 0=release, 1=press, 2=repeat.
        event_type: Event type (1=EV_KEY, default).
    """
    ev = MagicMock()
    ev.type = event_type
    ev.code = code
    ev.value = value
    return ev


# ---------------------------------------------------------------------------
# TestDispatchKeyEvent
# ---------------------------------------------------------------------------

class TestDispatchKeyEvent:
    """dispatch_key_event routes evdev events to correct ACTION_MAP entries."""

    def test_matching_key_with_modifiers_calls_action(self):
        """Press Ctrl+Shift+Down should dispatch SpeedUp."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        # Simulate: Ctrl press, Shift press, Down press
        held_keys = {ecodes.KEY_LEFTCTRL, ecodes.KEY_LEFTSHIFT}
        event = make_event(ecodes.KEY_DOWN, 1)

        matrix_keys.dispatch_key_event(event, held_keys, hotkey_table, action_map)
        mock_action.assert_called_once()

    def test_non_matching_key_does_nothing(self):
        """Press Ctrl+Shift+X (not in table) does nothing."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        held_keys = {ecodes.KEY_LEFTCTRL, ecodes.KEY_LEFTSHIFT}
        event = make_event(ecodes.KEY_X, 1)

        matrix_keys.dispatch_key_event(event, held_keys, hotkey_table, action_map)
        mock_action.assert_not_called()

    def test_ignores_key_repeat(self):
        """Key repeat (value==2) should NOT trigger dispatch."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        held_keys = {ecodes.KEY_LEFTCTRL, ecodes.KEY_LEFTSHIFT}
        event = make_event(ecodes.KEY_DOWN, 2)  # repeat

        matrix_keys.dispatch_key_event(event, held_keys, hotkey_table, action_map)
        mock_action.assert_not_called()

    def test_ignores_key_release(self):
        """Key release (value==0) should NOT trigger dispatch."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        held_keys = {ecodes.KEY_LEFTCTRL, ecodes.KEY_LEFTSHIFT}
        event = make_event(ecodes.KEY_DOWN, 0)  # release

        matrix_keys.dispatch_key_event(event, held_keys, hotkey_table, action_map)
        mock_action.assert_not_called()

    def test_only_fires_on_key_press(self):
        """Only value==1 (press) triggers dispatch."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        held_keys = {ecodes.KEY_LEFTCTRL, ecodes.KEY_LEFTSHIFT}

        # Only press should fire
        matrix_keys.dispatch_key_event(make_event(ecodes.KEY_DOWN, 1), held_keys, hotkey_table, action_map)
        assert mock_action.call_count == 1

        # Release should not fire
        matrix_keys.dispatch_key_event(make_event(ecodes.KEY_DOWN, 0), held_keys, hotkey_table, action_map)
        assert mock_action.call_count == 1

        # Repeat should not fire
        matrix_keys.dispatch_key_event(make_event(ecodes.KEY_DOWN, 2), held_keys, hotkey_table, action_map)
        assert mock_action.call_count == 1

    def test_right_modifier_matches_too(self):
        """Right Ctrl + Right Shift should also match (any modifier from group)."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        held_keys = {ecodes.KEY_RIGHTCTRL, ecodes.KEY_RIGHTSHIFT}
        event = make_event(ecodes.KEY_DOWN, 1)

        matrix_keys.dispatch_key_event(event, held_keys, hotkey_table, action_map)
        mock_action.assert_called_once()

    def test_missing_modifier_does_not_match(self):
        """Only Ctrl held (no Shift) should NOT match Ctrl+Shift+Down."""
        from evdev import ecodes
        import matrix_keys

        mock_action = MagicMock()
        hotkey_table = {
            (frozenset({
                ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
                ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
            }), ecodes.KEY_DOWN): "SpeedUp",
        }
        action_map = {"SpeedUp": mock_action}

        held_keys = {ecodes.KEY_LEFTCTRL}  # No Shift
        event = make_event(ecodes.KEY_DOWN, 1)

        matrix_keys.dispatch_key_event(event, held_keys, hotkey_table, action_map)
        mock_action.assert_not_called()


# ---------------------------------------------------------------------------
# TestConfigReload
# ---------------------------------------------------------------------------

class TestConfigReload:
    """Hotkey table rebuilds when inotify signals config change."""

    @patch("matrix_keys.notify_conflicts")
    @patch("matrix_keys.detect_conflicts", return_value=[])
    @patch("matrix_keys.is_redpill", return_value=False)
    @patch("matrix_keys.build_hotkey_table")
    @patch("matrix_keys.load_config")
    def test_rebuild_on_inotify_signal(self, mock_load, mock_build, mock_rp, mock_detect, mock_notify):
        """When watcher signals change, config is reloaded and table rebuilt."""
        import matrix_keys

        new_config = {"SpeedUp": {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": True}}
        mock_load.return_value = new_config
        mock_build.return_value = {}

        mock_watcher = MagicMock()
        mock_watcher.check.return_value = True

        matrix_keys.handle_config_reload(mock_watcher)

        mock_load.assert_called_once()
        mock_build.assert_called_once()
        mock_rp.assert_called_once()
        mock_detect.assert_called_once_with(new_config)
        mock_notify.assert_called_once_with([])


# ---------------------------------------------------------------------------
# TestConflictDetectionStartup
# ---------------------------------------------------------------------------

class TestConflictDetectionStartup:
    """Conflict detection runs on initial startup."""

    @patch("matrix_keys.notify_conflicts")
    @patch("matrix_keys.detect_conflicts")
    @patch("matrix_keys.build_hotkey_table")
    @patch("matrix_keys.is_redpill", return_value=False)
    @patch("matrix_keys.load_config")
    def test_conflicts_checked_on_startup(self, mock_load, mock_rp, mock_build, mock_detect, mock_notify):
        """startup_init() runs detect_conflicts and notify_conflicts."""
        import matrix_keys

        config = {"SpeedUp": {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": True}}
        mock_load.return_value = config
        mock_build.return_value = {}
        mock_detect.return_value = [{"action": "SpeedUp", "key": "Down", "modifiers": ["Ctrl", "Shift"], "system_source": "gnome"}]

        result = matrix_keys.startup_init()

        mock_detect.assert_called_once_with(config)
        mock_notify.assert_called_once()
        assert len(mock_notify.call_args[0][0]) == 1


# ---------------------------------------------------------------------------
# TestConflictDetectionReload
# ---------------------------------------------------------------------------

class TestConflictDetectionReload:
    """Conflict detection runs again after config reload."""

    @patch("matrix_keys.notify_conflicts")
    @patch("matrix_keys.detect_conflicts")
    @patch("matrix_keys.is_redpill", return_value=False)
    @patch("matrix_keys.build_hotkey_table", return_value={})
    @patch("matrix_keys.load_config")
    def test_conflicts_rechecked_on_reload(self, mock_load, mock_build, mock_rp, mock_detect, mock_notify):
        """handle_config_reload() re-runs detect_conflicts."""
        import matrix_keys

        config = {"SpeedUp": {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": True}}
        mock_load.return_value = config
        mock_detect.return_value = []

        mock_watcher = MagicMock()
        mock_watcher.check.return_value = True

        matrix_keys.handle_config_reload(mock_watcher)

        mock_detect.assert_called_once_with(config)
        mock_notify.assert_called_once()


# ---------------------------------------------------------------------------
# TestRedPillGate
# ---------------------------------------------------------------------------

class TestRedPillGate:
    """Red Pill status controls whether custom bindings are used."""

    @patch("matrix_keys.notify_conflicts")
    @patch("matrix_keys.detect_conflicts", return_value=[])
    @patch("matrix_keys.build_hotkey_table")
    @patch("matrix_keys.is_redpill")
    @patch("matrix_keys.load_config")
    def test_redpill_true_passes_to_build_table(self, mock_load, mock_rp, mock_build, mock_detect, mock_notify):
        """When Red Pill, build_hotkey_table gets is_redpill=True."""
        import matrix_keys

        mock_load.return_value = {}
        mock_rp.return_value = True
        mock_build.return_value = {}

        matrix_keys.startup_init()

        mock_build.assert_called_once_with({}, True)

    @patch("matrix_keys.notify_conflicts")
    @patch("matrix_keys.detect_conflicts", return_value=[])
    @patch("matrix_keys.build_hotkey_table")
    @patch("matrix_keys.is_redpill")
    @patch("matrix_keys.load_config")
    def test_redpill_false_passes_to_build_table(self, mock_load, mock_rp, mock_build, mock_detect, mock_notify):
        """When not Red Pill, build_hotkey_table gets is_redpill=False."""
        import matrix_keys

        mock_load.return_value = {}
        mock_rp.return_value = False
        mock_build.return_value = {}

        matrix_keys.startup_init()

        mock_build.assert_called_once_with({}, False)


# ---------------------------------------------------------------------------
# TestKeyboardReconnect
# ---------------------------------------------------------------------------

class TestKeyboardReconnect:
    """Keyboard disconnect triggers reconnect loop (preserved behavior)."""

    def test_find_keyboard_returns_device(self):
        """find_keyboard is still present and callable."""
        import matrix_keys
        assert callable(matrix_keys.find_keyboard)

    def test_pidfile_constant_preserved(self):
        """PIDFILE constant is still defined."""
        import matrix_keys
        assert hasattr(matrix_keys, "PIDFILE")
        assert matrix_keys.PIDFILE == "/tmp/matrix-keys.pid"


# ---------------------------------------------------------------------------
# TestAllDefaultHotkeys
# ---------------------------------------------------------------------------

class TestAllDefaultHotkeys:
    """All 13 default hotkeys are in the dispatch table."""

    def test_all_13_hotkeys_in_table(self):
        """build_hotkey_table with DEFAULT_BINDINGS returns 13 entries."""
        from hotkey_config import DEFAULT_BINDINGS, build_hotkey_table
        table = build_hotkey_table(DEFAULT_BINDINGS)
        assert len(table) == 13
        actions = set(table.values())
        expected = {
            "SwapLeft", "SwapRight", "CycleLayout", "ToggleTransparency",
            "OpacityDown", "OpacityUp", "SpeedUp", "SpeedDown",
            "ToggleFar", "ToggleMid", "ToggleNear", "ShowHelp", "ManualReload",
        }
        assert actions == expected

    def test_startup_init_produces_table_with_13(self):
        """startup_init() returns a hotkey table with 13 entries for default config."""
        import matrix_keys
        from hotkey_config import DEFAULT_BINDINGS

        with patch("matrix_keys.load_config", return_value=dict(DEFAULT_BINDINGS)), \
             patch("matrix_keys.is_redpill", return_value=False), \
             patch("matrix_keys.detect_conflicts", return_value=[]), \
             patch("matrix_keys.notify_conflicts"):
            result = matrix_keys.startup_init()
            assert len(result["hotkey_table"]) == 13


# ---------------------------------------------------------------------------
# TestDisabledHotkey
# ---------------------------------------------------------------------------

class TestDisabledHotkey:
    """Disabled hotkey (enabled=false) is excluded from dispatch table."""

    def test_disabled_hotkey_excluded(self):
        """A disabled hotkey should not appear in the dispatch table."""
        from hotkey_config import DEFAULT_BINDINGS, build_hotkey_table

        config = dict(DEFAULT_BINDINGS)
        config["SpeedUp"] = dict(config["SpeedUp"])
        config["SpeedUp"]["enabled"] = False
        table = build_hotkey_table(config, is_redpill=True)
        assert len(table) == 12
        assert "SpeedUp" not in table.values()


# ---------------------------------------------------------------------------
# TestOldCodeRemoved
# ---------------------------------------------------------------------------

class TestOldCodeRemoved:
    """Old hard-coded HOTKEYS dict, run_action, OPACITY_SCRIPT, HOTKEY_HELP removed."""

    def test_no_hotkeys_dict(self):
        """The old HOTKEYS dict should be removed."""
        import matrix_keys
        assert not hasattr(matrix_keys, "HOTKEYS")

    def test_no_run_action(self):
        """The old run_action() function should be removed."""
        import matrix_keys
        assert not hasattr(matrix_keys, "run_action")

    def test_no_opacity_script(self):
        """The old OPACITY_SCRIPT constant should be removed."""
        import matrix_keys
        assert not hasattr(matrix_keys, "OPACITY_SCRIPT")

    def test_no_hotkey_help_script(self):
        """The old HOTKEY_HELP constant should be removed."""
        import matrix_keys
        assert not hasattr(matrix_keys, "HOTKEY_HELP")

    def test_no_listen_function(self):
        """The old listen() function should be removed (replaced by unified loop)."""
        import matrix_keys
        assert not hasattr(matrix_keys, "listen")
