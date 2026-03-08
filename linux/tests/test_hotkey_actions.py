"""Tests for hotkey_actions.py — all 13 action handlers + toast + ACTION_MAP."""
import json
import os
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
    def test_cycle_from_pillars_to_quads(self, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout, LAYOUT_MODES
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "pillars"}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        assert state["layout_mode"] == "quads"

    @patch("hotkey_actions.show_toast")
    def test_cycle_wraps_from_auto_to_pillars(self, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "auto"}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        assert state["layout_mode"] == "pillars"

    @patch("hotkey_actions.show_toast")
    def test_cycle_creates_state_if_missing(self, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        # Default is "pillars", so next is "quads"
        assert state["layout_mode"] == "quads"

    @patch("hotkey_actions.show_toast")
    def test_cycle_preserves_other_state(self, mock_toast, tmp_path):
        from hotkey_actions import action_cycle_layout
        state_file = tmp_path / "state.json"
        state_file.write_text(json.dumps({"layout_mode": "pillars", "other_key": 42}))
        with patch("hotkey_actions.STATE_PATH", str(state_file)):
            action_cycle_layout()
        state = json.loads(state_file.read_text())
        assert state["other_key"] == 42

    @patch("hotkey_actions.show_toast")
    def test_cycle_all_modes(self, mock_toast, tmp_path):
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
    def test_cycle_shows_toast(self, mock_toast, tmp_path):
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
    """Opacity up/down/toggle modify Ghostty config files."""

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_get_current_opacity_reads_from_config(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import get_current_opacity
        conf = tmp_path / "ghostty-matrix-1.conf"
        conf.write_text("font-size = 12\nbackground-opacity = 0.85\nwindow-padding = 0\n")
        with patch("hotkey_actions.glob.glob", return_value=[str(conf)]):
            assert get_current_opacity() == 85

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_get_current_opacity_no_files(self, mock_bus, mock_reload, mock_toast):
        from hotkey_actions import get_current_opacity
        with patch("hotkey_actions.glob.glob", return_value=[]):
            assert get_current_opacity() == 100

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_down(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_opacity_down
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0.85\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.85\n")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_opacity_down()

        assert "0.80" in conf1.read_text()
        mock_toast.assert_called_once_with("Opacity: 80%")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_down_clamps_to_zero(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_opacity_down
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0.03\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.03\n")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_opacity_down()

        content = conf1.read_text()
        assert "background-opacity = 0" in content
        mock_toast.assert_called_once_with("Opacity: 0%")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_up(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_opacity_up
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0.80\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.80\n")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_opacity_up()

        assert "0.85" in conf1.read_text()
        mock_toast.assert_called_once_with("Opacity: 85%")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_up_clamps_to_100(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_opacity_up
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0.97\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.97\n")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_opacity_up()

        content = conf1.read_text()
        assert "background-opacity = 1" in content
        mock_toast.assert_called_once_with("Opacity: 100%")

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_modifies_all_configs(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_opacity_up
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf2 = tmp_path / "ghostty-matrix-2.conf"
        conf1.write_text("background-opacity = 0.50\n")
        conf2.write_text("background-opacity = 0.50\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.50\n")

        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1), str(conf2)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_opacity_up()

        assert "0.55" in conf1.read_text()
        assert "0.55" in conf2.read_text()
        assert "0.55" in ghostty_conf.read_text()

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_reloads_all_instances(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_opacity_up
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0.50\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.50\n")

        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_opacity_up()
        assert mock_reload.call_count == 2

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_transparency_on_to_off(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_toggle_transparency
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0.85\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0.85\n")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_toggle_transparency()

        content = conf1.read_text()
        assert "background-opacity = 0" in content

    @patch("hotkey_actions.show_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_transparency_off_to_default(self, mock_bus, mock_reload, mock_toast, tmp_path):
        from hotkey_actions import action_toggle_transparency, CUSTOM_DEFAULT
        conf1 = tmp_path / "ghostty-matrix-1.conf"
        conf1.write_text("background-opacity = 0\n")
        ghostty_conf = tmp_path / "config"
        ghostty_conf.write_text("background-opacity = 0\n")

        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}

        with patch("hotkey_actions.glob.glob", return_value=[str(conf1)]), \
             patch("hotkey_actions.GHOSTTY_CONFIG", str(ghostty_conf)):
            action_toggle_transparency()

        content = conf1.read_text()
        assert "0.85" in content


# ---------------------------------------------------------------------------
# TestHelpAction
# ---------------------------------------------------------------------------

class TestHelpAction:
    """ShowHelp sends notification with all 13 hotkey bindings."""

    @patch("hotkey_actions.subprocess.Popen")
    def test_show_help_sends_notification(self, mock_popen):
        from hotkey_actions import action_show_help
        action_show_help()
        mock_popen.assert_called_once()
        call_args = mock_popen.call_args[0][0]
        assert "notify-send" in call_args[0]
        # Should contain at least some hotkey info
        body = call_args[-1]
        assert "Speed" in body or "speed" in body.lower()

    @patch("hotkey_actions.subprocess.Popen")
    def test_show_help_long_expire(self, mock_popen):
        from hotkey_actions import action_show_help
        action_show_help()
        call_args = mock_popen.call_args[0][0]
        assert "--expire-time=10000" in call_args


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
    """ACTION_MAP contains all 13 action names mapped to functions."""

    def test_action_map_has_all_13(self):
        from hotkey_actions import ACTION_MAP
        expected = {
            "SpeedUp", "SpeedDown",
            "ToggleFar", "ToggleMid", "ToggleNear",
            "CycleLayout",
            "SwapLeft", "SwapRight",
            "ToggleTransparency", "OpacityDown", "OpacityUp",
            "ShowHelp", "ManualReload",
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
