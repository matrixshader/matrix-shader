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
    """SwapLeft/Right rotates slot shader file assignments."""

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_swap_left_rotates_shaders(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_swap_left
        import hotkey_actions
        # Create 3 slot shader files
        shader_dir = tmp_path / "shaders"
        shader_dir.mkdir()
        (shader_dir / "matrix-1.glsl").write_text("SHADER_1")
        (shader_dir / "matrix-2.glsl").write_text("SHADER_2")
        (shader_dir / "matrix-3.glsl").write_text("SHADER_3")

        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
            3: {"pid": 300, "bus_name": ":1.30"},
        }
        with patch.object(hotkey_actions, "SLOT_SHADER_DIR", str(shader_dir)):
            action_swap_left()

        # Left rotation: slot 1 gets slot 2's content, slot 2 gets slot 3's, slot 3 gets slot 1's
        assert (shader_dir / "matrix-1.glsl").read_text() == "SHADER_2"
        assert (shader_dir / "matrix-2.glsl").read_text() == "SHADER_3"
        assert (shader_dir / "matrix-3.glsl").read_text() == "SHADER_1"

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_swap_right_rotates_shaders(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_swap_right
        import hotkey_actions
        shader_dir = tmp_path / "shaders"
        shader_dir.mkdir()
        (shader_dir / "matrix-1.glsl").write_text("SHADER_1")
        (shader_dir / "matrix-2.glsl").write_text("SHADER_2")
        (shader_dir / "matrix-3.glsl").write_text("SHADER_3")

        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
            3: {"pid": 300, "bus_name": ":1.30"},
        }
        with patch.object(hotkey_actions, "SLOT_SHADER_DIR", str(shader_dir)):
            action_swap_right()

        # Right rotation: slot 1 gets slot 3's content, slot 2 gets slot 1's, slot 3 gets slot 2's
        assert (shader_dir / "matrix-1.glsl").read_text() == "SHADER_3"
        assert (shader_dir / "matrix-2.glsl").read_text() == "SHADER_1"
        assert (shader_dir / "matrix-3.glsl").read_text() == "SHADER_2"

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_swap_left_reloads_all(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_swap_left
        import hotkey_actions
        shader_dir = tmp_path / "shaders"
        shader_dir.mkdir()
        (shader_dir / "matrix-1.glsl").write_text("S1")
        (shader_dir / "matrix-2.glsl").write_text("S2")

        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }
        with patch.object(hotkey_actions, "SLOT_SHADER_DIR", str(shader_dir)):
            action_swap_left()
        assert mock_reload.call_count == 2

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_swap_left_no_windows(self, mock_bus, mock_reload, mock_toast):
        from hotkey_actions import action_swap_left
        mock_bus.return_value = {}
        action_swap_left()
        mock_reload.assert_not_called()

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_swap_left_single_window(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_swap_left
        import hotkey_actions
        shader_dir = tmp_path / "shaders"
        shader_dir.mkdir()
        (shader_dir / "matrix-1.glsl").write_text("ONLY_ONE")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch.object(hotkey_actions, "SLOT_SHADER_DIR", str(shader_dir)):
            action_swap_left()
        # With 1 slot, nothing changes
        assert (shader_dir / "matrix-1.glsl").read_text() == "ONLY_ONE"

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_swap_shows_toast(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_swap_left
        import hotkey_actions
        shader_dir = tmp_path / "shaders"
        shader_dir.mkdir()
        (shader_dir / "matrix-1.glsl").write_text("S1")
        (shader_dir / "matrix-2.glsl").write_text("S2")

        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }
        with patch.object(hotkey_actions, "SLOT_SHADER_DIR", str(shader_dir)):
            action_swap_left()
        mock_toast.assert_called_once_with("Slots rotated left")


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
    """show_toast() calls notify-send with proper arguments."""

    @patch("hotkey_actions.subprocess.Popen")
    def test_toast_calls_notify_send(self, mock_popen):
        from hotkey_actions import show_toast
        show_toast("Speed: 1.5")
        mock_popen.assert_called_once()
        cmd = mock_popen.call_args[0][0]
        assert cmd[0] == "notify-send"
        assert "--app-name=Matrix Shader" in cmd
        assert "--expire-time=1500" in cmd
        assert "--hint=string:x-dunst-stack-tag:matrix-shader" in cmd
        assert "Matrix Shader" in cmd  # title
        assert "Speed: 1.5" in cmd  # message body

    @patch("hotkey_actions.subprocess.Popen", side_effect=FileNotFoundError)
    def test_toast_handles_missing_notify_send(self, mock_popen):
        from hotkey_actions import show_toast
        # Should not raise
        show_toast("test")

    @patch("hotkey_actions.subprocess.Popen")
    def test_toast_custom_title(self, mock_popen):
        from hotkey_actions import show_toast
        show_toast("hello", title="Custom Title")
        cmd = mock_popen.call_args[0][0]
        assert "Custom Title" in cmd
        assert "hello" in cmd


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
