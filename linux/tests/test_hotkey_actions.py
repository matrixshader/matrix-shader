"""Tests for hotkey_actions.py — all 13 action handlers + toast + ACTION_MAP."""
import json
import os
import subprocess
import sys
from unittest.mock import patch, MagicMock, call, mock_open

import pytest

# Ensure linux/ is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


# ---------------------------------------------------------------------------
# TestSpeedActions
# ---------------------------------------------------------------------------

class TestSpeedActions:
    """Speed up/down modifies RAIN_SPEED on ALL active windows."""

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_up_increases_by_delta(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_up
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"RAIN_SPEED": 0.8}
        action_speed_up()
        mock_write.assert_called_once_with(1, "RAIN_SPEED", 1.3)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_up_clamps_to_max(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_up
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"RAIN_SPEED": 4.8}
        action_speed_up()
        mock_write.assert_called_once_with(1, "RAIN_SPEED", 5.0)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_up_broadcasts_all_slots(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_up
        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }
        mock_read.return_value = {"RAIN_SPEED": 1.0}
        action_speed_up()
        assert mock_write.call_count == 2
        mock_write.assert_any_call(1, "RAIN_SPEED", 1.5)
        mock_write.assert_any_call(2, "RAIN_SPEED", 1.5)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_up_shows_toast(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_up
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"RAIN_SPEED": 1.0}
        action_speed_up()
        mock_toast.assert_called_once_with("Speed: 1.5")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_down_decreases_by_delta(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_down
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"RAIN_SPEED": 1.3}
        action_speed_down()
        mock_write.assert_called_once_with(1, "RAIN_SPEED", 0.8)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_down_clamps_to_min(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_down
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"RAIN_SPEED": 0.3}
        action_speed_down()
        mock_write.assert_called_once_with(1, "RAIN_SPEED", 0.1)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_speed_up_no_windows(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_speed_up
        mock_bus.return_value = {}
        action_speed_up()
        mock_write.assert_not_called()
        mock_toast.assert_not_called()


# ---------------------------------------------------------------------------
# TestLayerActions
# ---------------------------------------------------------------------------

class TestLayerActions:
    """Layer toggles flip SHOW_L1/L2/L3 between 0.0 and 1.0."""

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_far_on_to_off(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_far
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"SHOW_L1": 1.0}
        action_toggle_far()
        mock_write.assert_called_once_with(1, "SHOW_L1", 0.0)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_far_off_to_on(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_far
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"SHOW_L1": 0.0}
        action_toggle_far()
        mock_write.assert_called_once_with(1, "SHOW_L1", 1.0)

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_far_broadcasts(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_far
        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }
        mock_read.return_value = {"SHOW_L1": 1.0}
        action_toggle_far()
        assert mock_write.call_count == 2

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_far_toast_off(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_far
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"SHOW_L1": 1.0}
        action_toggle_far()
        mock_toast.assert_called_once_with("Far layer: OFF")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_far_toast_on(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_far
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"SHOW_L1": 0.0}
        action_toggle_far()
        mock_toast.assert_called_once_with("Far layer: ON")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_mid(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_mid
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"SHOW_L2": 1.0}
        action_toggle_mid()
        mock_write.assert_called_once_with(1, "SHOW_L2", 0.0)
        mock_toast.assert_called_once_with("Mid layer: OFF")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_near(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_near
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        mock_read.return_value = {"SHOW_L3": 1.0}
        action_toggle_near()
        mock_write.assert_called_once_with(1, "SHOW_L3", 0.0)
        mock_toast.assert_called_once_with("Near layer: OFF")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.write_shader_param")
    @patch("hotkey_actions.read_shader_config")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_no_windows(self, mock_bus, mock_read, mock_write, mock_toast):
        from hotkey_actions import action_toggle_far
        mock_bus.return_value = {}
        action_toggle_far()
        mock_write.assert_not_called()


# ---------------------------------------------------------------------------
# TestLayoutAction
# ---------------------------------------------------------------------------

class TestLayoutAction:
    """CycleLayout writes next layout mode to state.json."""

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    def test_cycle_from_pillars_to_quads(self, mock_svc, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout, LAYOUT_MODES
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "pillars"}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        assert state["layout_mode"] == "quads"

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    def test_cycle_wraps_from_auto_to_pillars(self, mock_svc, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "auto"}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        assert state["layout_mode"] == "pillars"

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    def test_cycle_creates_state_if_missing(self, mock_svc, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        # Default is "pillars", so next is "quads"
        assert state["layout_mode"] == "quads"

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    def test_cycle_preserves_other_state(self, mock_svc, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "pillars", "other_key": 42}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        assert state["other_key"] == 42

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    def test_cycle_all_modes(self, mock_svc, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout, LAYOUT_MODES
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "pillars"}))
        modes_visited = []
        for _ in range(len(LAYOUT_MODES)):
            with patch("hotkey_actions.STATE_PATH", str(state_file)):
                action_cycle_layout()
            state = json.loads(state_file.read_text())
            modes_visited.append(state["layout_mode"])
        assert modes_visited == ["quads", "overlap", "auto", "pillars"]

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    def test_cycle_shows_toast(self, mock_svc, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "pillars"}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        mock_toast.assert_called_once_with("Layout: quads")


# ---------------------------------------------------------------------------
# TestSwapActions
# ---------------------------------------------------------------------------

class TestSwapActions:
    """SwapLeft/Right rotates window positions in the layout formation."""

    def test_swap_left_rotates_positions(self):
        """SwapLeft moves window positions: [A, B, C] → [B, C, A]."""
        from hotkey_actions import action_swap_left

        positions_applied = []

        def fake_position(slot, x, y, w, h):
            positions_applied.append((slot, x))
            return True

        def fake_get_pid(slot):
            return 100 + slot

        def fake_get_position(slot):
            geos = {
                1: {"x": 0, "y": 0, "width": 640, "height": 1080},
                2: {"x": 640, "y": 0, "width": 640, "height": 1080},
                3: {"x": 1280, "y": 0, "width": 640, "height": 1080},
            }
            return geos.get(slot)

        fake_mapping = {"1": {"pid": 101}, "2": {"pid": 102}, "3": {"pid": 103}}

        with patch("window_service.load_mapping", return_value=fake_mapping), \
             patch("window_service.get_pid_for_slot", side_effect=fake_get_pid), \
             patch("window_service.get_position", side_effect=fake_get_position), \
             patch("window_service.position_window", side_effect=fake_position), \
             patch("layout_engine._update_applied_cache"):
            action_swap_left()

        # Left rotation: windows shift left; sorted by X = [1,2,3]
        # rotated_windows = [2,3,1], so slot 2→pos0, slot 3→pos640, slot 1→pos1280
        assert len(positions_applied) == 3
        slot_x = {s: x for s, x in positions_applied}
        assert slot_x[2] == 0
        assert slot_x[3] == 640
        assert slot_x[1] == 1280

    def test_swap_right_rotates_positions(self):
        """SwapRight moves window positions: [A, B, C] → [C, A, B]."""
        from hotkey_actions import action_swap_right

        positions_applied = []

        def fake_position(slot, x, y, w, h):
            positions_applied.append((slot, x))
            return True

        def fake_get_pid(slot):
            return 100 + slot

        geos = {
            1: {"x": 0, "y": 0, "width": 640, "height": 1080},
            2: {"x": 640, "y": 0, "width": 640, "height": 1080},
            3: {"x": 1280, "y": 0, "width": 640, "height": 1080},
        }

        def fake_get_position(slot):
            return geos.get(slot)

        fake_mapping = {"1": {"pid": 101}, "2": {"pid": 102}, "3": {"pid": 103}}

        with patch("window_service.load_mapping", return_value=fake_mapping), \
             patch("window_service.get_pid_for_slot", side_effect=fake_get_pid), \
             patch("window_service.get_position", side_effect=fake_get_position), \
             patch("window_service.position_window", side_effect=fake_position), \
             patch("layout_engine._update_applied_cache"):
            action_swap_right()

        # Right rotation: windows shift right; sorted by X = [1,2,3]
        # rotated_windows = [3,1,2], so slot 3→pos0, slot 1→pos640, slot 2→pos1280
        slot_x = {s: x for s, x in positions_applied}
        assert slot_x[3] == 0
        assert slot_x[1] == 640
        assert slot_x[2] == 1280

    @patch("hotkey_actions.show_toast")
    def test_swap_left_no_windows(self, mock_toast):
        """SwapLeft with no windows does nothing."""
        from hotkey_actions import action_swap_left
        with patch("window_service.load_mapping", return_value={}), \
             patch("window_service.get_pid_for_slot", return_value=None):
            action_swap_left()
        mock_toast.assert_not_called()

    def test_swap_left_single_window(self):
        """SwapLeft with 1 window does nothing (need 2+ to rotate)."""
        from hotkey_actions import action_swap_left
        with patch("window_service.load_mapping", return_value={"1": {"pid": 101}}), \
             patch("window_service.get_pid_for_slot", return_value=101):
            action_swap_left()


# ---------------------------------------------------------------------------
# TestOpacityActions
# ---------------------------------------------------------------------------

class TestOpacityActions:
    """Opacity up/down/toggle delegate to matrix-opacity.sh and show OSD toast."""

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._read_current_opacity", return_value=80)
    @patch("hotkey_actions.subprocess.run")
    def test_opacity_down(self, mock_run, mock_read_op, mock_fire, mock_svc):
        from hotkey_actions import action_opacity_down, OPACITY_SCRIPT
        action_opacity_down()
        mock_run.assert_called_once_with(
            [OPACITY_SCRIPT, "down"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3,
        )
        mock_fire.assert_called_once_with(80)

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._read_current_opacity", return_value=85)
    @patch("hotkey_actions.subprocess.run")
    def test_opacity_up(self, mock_run, mock_read_op, mock_fire, mock_svc):
        from hotkey_actions import action_opacity_up, OPACITY_SCRIPT
        action_opacity_up()
        mock_run.assert_called_once_with(
            [OPACITY_SCRIPT, "up"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3,
        )
        mock_fire.assert_called_once_with(85)

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._read_current_opacity", return_value=0)
    @patch("hotkey_actions.subprocess.run")
    def test_toggle_transparency(self, mock_run, mock_read_op, mock_fire, mock_svc):
        from hotkey_actions import action_toggle_transparency, OPACITY_SCRIPT
        action_toggle_transparency()
        mock_run.assert_called_once_with(
            [OPACITY_SCRIPT, "toggle"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3,
        )
        mock_fire.assert_called_once_with(0)

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._read_current_opacity")
    @patch("hotkey_actions.subprocess.run", side_effect=FileNotFoundError)
    def test_opacity_missing_script(self, mock_run, mock_read_op, mock_fire, mock_svc):
        from hotkey_actions import action_opacity_down
        action_opacity_down()  # Should not raise
        mock_fire.assert_not_called()

    def test_read_current_opacity_returns_int(self):
        from hotkey_actions import _read_current_opacity
        result = _read_current_opacity()
        assert isinstance(result, int)
        assert 0 <= result <= 100


# ---------------------------------------------------------------------------
# TestHelpAction
# ---------------------------------------------------------------------------

class TestHelpAction:
    """ShowHelp launches the Ghostty help window overlay."""

    @patch("hotkey_actions.subprocess.Popen")
    def test_show_help_launches_script(self, mock_popen):
        from hotkey_actions import action_show_help, HELP_SCRIPT
        action_show_help()
        mock_popen.assert_called_once()
        call_args = mock_popen.call_args[0][0]
        assert call_args == [HELP_SCRIPT]

    @patch("hotkey_actions.subprocess.Popen", side_effect=FileNotFoundError)
    def test_show_help_handles_missing_script(self, mock_popen):
        from hotkey_actions import action_show_help
        action_show_help()  # Should not raise


# ---------------------------------------------------------------------------
# TestReloadAction
# ---------------------------------------------------------------------------

class TestReloadAction:
    """ManualReload triggers D-Bus reload on ALL discovered instances."""

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_manual_reload_all(self, mock_bus, mock_reload, mock_toast):
        from hotkey_actions import action_manual_reload
        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
            3: {"pid": 300, "bus_name": ":1.30"},
        }
        action_manual_reload()
        assert mock_reload.call_count == 3
        mock_reload.assert_any_call(":1.10")
        mock_reload.assert_any_call(":1.20")
        mock_reload.assert_any_call(":1.30")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_manual_reload_shows_toast(self, mock_bus, mock_reload, mock_toast):
        from hotkey_actions import action_manual_reload
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        action_manual_reload()
        mock_toast.assert_called_once_with("Shaders reloaded")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_manual_reload_no_windows(self, mock_bus, mock_reload, mock_toast):
        from hotkey_actions import action_manual_reload
        mock_bus.return_value = {}
        action_manual_reload()
        mock_reload.assert_not_called()


# ---------------------------------------------------------------------------
# TestToast
# ---------------------------------------------------------------------------

class TestToast:
    """show_toast() is disabled — no popups in Matrix Shader."""

    def test_toast_is_noop(self):
        from hotkey_actions import show_toast
        # Should not raise or do anything
        show_toast("Speed: 1.5")
        show_toast("test", title="Custom Title")


# ---------------------------------------------------------------------------
# TestActionMap
# ---------------------------------------------------------------------------

class TestActionMap:
    """ACTION_MAP contains all 16 action names mapped to functions."""

    def test_action_map_has_all_16(self):
        from hotkey_actions import ACTION_MAP
        expected = {
            "SpeedUp", "SpeedDown",
            "ToggleFar", "ToggleMid", "ToggleNear",
            "CycleLayout",
            "SwapLeft", "SwapRight",
            "ToggleTransparency", "OpacityDown", "OpacityUp",
            "ShowHelp", "ManualReload",
            "SnapbackSave", "SnapbackRestore", "GlitchToggle",
        }
        assert set(ACTION_MAP.keys()) == expected

    def test_action_map_values_are_callable(self):
        from hotkey_actions import ACTION_MAP
        for name, fn in ACTION_MAP.items():
            assert callable(fn), f"ACTION_MAP[{name!r}] is not callable"

    def test_action_map_functions_are_correct(self):
        from hotkey_actions import (
            ACTION_MAP,
            action_speed_up, action_speed_down,
            action_toggle_far, action_toggle_mid, action_toggle_near,
            action_cycle_layout,
            action_swap_left, action_swap_right,
            action_toggle_transparency, action_opacity_down, action_opacity_up,
            action_show_help, action_manual_reload,
        )
        assert ACTION_MAP["SpeedUp"] is action_speed_up
        assert ACTION_MAP["SpeedDown"] is action_speed_down
        assert ACTION_MAP["ToggleFar"] is action_toggle_far
        assert ACTION_MAP["ToggleMid"] is action_toggle_mid
        assert ACTION_MAP["ToggleNear"] is action_toggle_near
        assert ACTION_MAP["CycleLayout"] is action_cycle_layout
        assert ACTION_MAP["SwapLeft"] is action_swap_left
        assert ACTION_MAP["SwapRight"] is action_swap_right
        assert ACTION_MAP["ToggleTransparency"] is action_toggle_transparency
        assert ACTION_MAP["OpacityDown"] is action_opacity_down
        assert ACTION_MAP["OpacityUp"] is action_opacity_up
        assert ACTION_MAP["ShowHelp"] is action_show_help
        assert ACTION_MAP["ManualReload"] is action_manual_reload
