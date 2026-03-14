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
    """Opacity up/down/toggle use inline Python with overflow/underflow counters."""

    def setup_method(self):
        """Reset module-level counter state between tests."""
        import hotkey_actions
        hotkey_actions._overflow_counters.clear()
        hotkey_actions._underflow_counters.clear()
        hotkey_actions._base_opacity.clear()

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    @patch("hotkey_actions.get_all_ghostty_configs")
    def test_opacity_down(self, mock_configs, mock_bus, mock_reload, mock_fire, mock_svc, tmp_path):
        import hotkey_actions
        conf = tmp_path / "ghostty-matrix-1.conf"
        conf.write_text("background-opacity = 0.80\n")
        mock_configs.return_value = [str(conf)]
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        hotkey_actions.action_opacity_down()
        mock_fire.assert_called_once_with(75)

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    @patch("hotkey_actions.get_all_ghostty_configs")
    def test_opacity_up(self, mock_configs, mock_bus, mock_reload, mock_fire, mock_svc, tmp_path):
        import hotkey_actions
        conf = tmp_path / "ghostty-matrix-1.conf"
        conf.write_text("background-opacity = 0.85\n")
        mock_configs.return_value = [str(conf)]
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        hotkey_actions.action_opacity_up()
        mock_fire.assert_called_once_with(90)

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    @patch("hotkey_actions.get_all_ghostty_configs")
    def test_toggle_transparency(self, mock_configs, mock_bus, mock_reload, mock_fire, mock_svc, tmp_path):
        import hotkey_actions
        conf = tmp_path / "ghostty-matrix-1.conf"
        conf.write_text("background-opacity = 1\n")
        mock_configs.return_value = [str(conf)]
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        hotkey_actions.action_toggle_transparency()
        mock_fire.assert_called_once_with(85)

    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions.get_all_ghostty_configs", return_value=[])
    def test_opacity_no_configs_is_safe(self, mock_configs, mock_fire, mock_svc):
        from hotkey_actions import action_opacity_down
        action_opacity_down()  # Should not raise
        mock_fire.assert_not_called()

    def test_read_current_opacity_returns_int(self):
        from hotkey_actions import _read_current_opacity
        result = _read_current_opacity()
        assert isinstance(result, int)
        assert 0 <= result <= 100


# ---------------------------------------------------------------------------
# TestOpacityOverflow — v1.0.4 overflow/underflow counters
# ---------------------------------------------------------------------------

class TestOpacityOverflow:
    """Opacity overflow/underflow counters match Windows C# AdjustOpacity logic."""

    def setup_method(self):
        """Reset module-level counter state between tests."""
        import hotkey_actions
        hotkey_actions._overflow_counters.clear()
        hotkey_actions._underflow_counters.clear()
        hotkey_actions._base_opacity.clear()

    def _make_config(self, opacity_pct):
        """Create a temp config file with background-opacity set."""
        import tempfile
        fd, path = tempfile.mkstemp(suffix=".conf")
        with os.fdopen(fd, "w") as f:
            f.write(f"background-opacity = {opacity_pct / 100:.2f}\n")
        return path

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_up_at_100_increments_overflow(self, mock_bus, mock_reload,
                                                     mock_svc, mock_toast):
        """Opacity up at 100% increments overflow counter, no visual change."""
        import hotkey_actions
        conf = self._make_config(100)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(hotkey_actions.OPACITY_DELTA)
        assert result is None  # No visual change
        assert hotkey_actions._overflow_counters.get(conf, 0) == 1
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_down_at_0_increments_underflow(self, mock_bus, mock_reload,
                                                      mock_svc, mock_toast):
        """Opacity down at 0% increments underflow counter, no visual change."""
        import hotkey_actions
        conf = self._make_config(0)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(-hotkey_actions.OPACITY_DELTA)
        assert result is None
        assert hotkey_actions._underflow_counters.get(conf, 0) == 1
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_up_drains_underflow(self, mock_bus, mock_reload,
                                          mock_svc, mock_toast):
        """Opacity up with underflow > 0 drains underflow, no opacity change."""
        import hotkey_actions
        conf = self._make_config(0)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        hotkey_actions._underflow_counters[conf] = 2
        hotkey_actions._base_opacity[conf] = 0
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(hotkey_actions.OPACITY_DELTA)
        assert result is None
        assert hotkey_actions._underflow_counters[conf] == 1
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_down_drains_overflow(self, mock_bus, mock_reload,
                                           mock_svc, mock_toast):
        """Opacity down with overflow > 0 drains overflow, no opacity change."""
        import hotkey_actions
        conf = self._make_config(100)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        hotkey_actions._overflow_counters[conf] = 3
        hotkey_actions._base_opacity[conf] = 100
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(-hotkey_actions.OPACITY_DELTA)
        assert result is None
        assert hotkey_actions._overflow_counters[conf] == 2
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_up_at_50_increases(self, mock_bus, mock_reload,
                                         mock_svc, mock_toast):
        """Opacity up at 50% increases by OPACITY_DELTA (5%), no counter change."""
        import hotkey_actions
        conf = self._make_config(50)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(hotkey_actions.OPACITY_DELTA)
        assert result == 55
        # Verify file was written
        with open(conf) as f:
            content = f.read()
        assert "0.55" in content
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_opacity_down_at_50_decreases(self, mock_bus, mock_reload,
                                            mock_svc, mock_toast):
        """Opacity down at 50% decreases by OPACITY_DELTA (5%), no counter change."""
        import hotkey_actions
        conf = self._make_config(50)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(-hotkey_actions.OPACITY_DELTA)
        assert result == 45
        with open(conf) as f:
            content = f.read()
        assert "0.45" in content
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_external_change_resets_counters(self, mock_bus, mock_reload,
                                              mock_svc, mock_toast):
        """External opacity change (base mismatch) resets both counters."""
        import hotkey_actions
        conf = self._make_config(70)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        # Simulate: we were at 100% with overflow, but someone changed to 70%
        hotkey_actions._overflow_counters[conf] = 5
        hotkey_actions._underflow_counters[conf] = 3
        hotkey_actions._base_opacity[conf] = 100
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(hotkey_actions.OPACITY_DELTA)
        assert result == 75
        assert hotkey_actions._overflow_counters.get(conf, 0) == 0
        assert hotkey_actions._underflow_counters.get(conf, 0) == 0
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_toggle_cycle(self, mock_bus, mock_reload, mock_svc, mock_toast):
        """Toggle cycles Off(100)->Custom(85)->Full(0)->Off(100)."""
        import hotkey_actions
        conf = self._make_config(100)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            # From 100 (Off) -> 85 (Custom)
            hotkey_actions.action_toggle_transparency()
            with open(conf) as f:
                content = f.read()
            assert "0.85" in content

            # From 85 (Custom) -> 0 (Full transparent)
            hotkey_actions.action_toggle_transparency()
            with open(conf) as f:
                content = f.read()
            assert "background-opacity = 0" in content

            # From 0 (Full) -> 100 (Off)
            hotkey_actions.action_toggle_transparency()
            with open(conf) as f:
                content = f.read()
            assert "background-opacity = 1" in content
        os.unlink(conf)

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_adjust_writes_all_configs_and_reloads(self, mock_bus, mock_reload,
                                                     mock_svc, mock_toast):
        """adjust_opacity writes to all Matrix window configs and reloads all."""
        import hotkey_actions
        conf1 = self._make_config(50)
        conf2 = self._make_config(50)
        mock_bus.return_value = {
            1: {"pid": 100, "bus_name": ":1.10"},
            2: {"pid": 200, "bus_name": ":1.20"},
        }
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf1, conf2]):
            result = hotkey_actions._adjust_opacity_with_counters(hotkey_actions.OPACITY_DELTA)
        assert result == 55
        # Both files should be updated
        for conf in [conf1, conf2]:
            with open(conf) as f:
                assert "0.55" in f.read()
            os.unlink(conf)
        # Reload called for all bus names
        assert mock_reload.call_count == 2

    @patch("hotkey_actions._fire_toast")
    @patch("hotkey_actions._get_state_service", return_value=None)
    @patch("hotkey_actions.reload_ghostty")
    @patch("hotkey_actions.get_ghostty_bus_names")
    def test_returns_none_all_capped(self, mock_bus, mock_reload,
                                       mock_svc, mock_toast):
        """Returns None when all windows are at max and pressing up."""
        import hotkey_actions
        conf = self._make_config(100)
        mock_bus.return_value = {1: {"pid": 100, "bus_name": ":1.10"}}
        with patch("hotkey_actions.get_all_ghostty_configs", return_value=[conf]):
            result = hotkey_actions._adjust_opacity_with_counters(hotkey_actions.OPACITY_DELTA)
        assert result is None
        os.unlink(conf)


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
