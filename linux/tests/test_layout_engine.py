"""Tests for layout_engine.py — Phase 6 Layout Engine.

Tests cover:
- Gap scaling formula
- Window distribution across monitors
- Pillars layout algorithm
- Quads layout algorithm
- Overlap layout algorithm
- Auto mode selection
- Multi-monitor distribution
- Snapback save/restore
- Glitch mode drift detection
- Layout config persistence
"""

import json
import os
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import layout_engine


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_monitor(x=0, y=0, width=1920, height=1080, primary=True, name="eDP-1"):
    return {"x": x, "y": y, "width": width, "height": height,
            "scale": 1.0, "primary": primary, "name": name}


def default_config(**overrides):
    cfg = {
        "mode": "pillars",
        "gap_size": 40,
        "glitch_enabled": True,
        "overlap_percent": 5,
    }
    cfg.update(overrides)
    return cfg


# ---------------------------------------------------------------------------
# Gap Scaling
# ---------------------------------------------------------------------------

class TestGapScaling(unittest.TestCase):

    def test_one_window_full_gap(self):
        assert layout_engine.calculate_scaled_gap(40, 1) == 40

    def test_two_windows_full_gap(self):
        assert layout_engine.calculate_scaled_gap(40, 2) == 40

    def test_three_windows_80_percent(self):
        assert layout_engine.calculate_scaled_gap(40, 3) == 32

    def test_four_windows_60_percent(self):
        assert layout_engine.calculate_scaled_gap(40, 4) == 24

    def test_eight_windows_60_percent(self):
        assert layout_engine.calculate_scaled_gap(40, 8) == 24

    def test_minimum_gap_enforced(self):
        # 10 * 0.6 = 6, but minimum is 20
        assert layout_engine.calculate_scaled_gap(10, 4) == 20

    def test_zero_base_gap(self):
        assert layout_engine.calculate_scaled_gap(0, 2) == 20  # MIN_SCALED_GAP


# ---------------------------------------------------------------------------
# Window Distribution
# ---------------------------------------------------------------------------

class TestDistribution(unittest.TestCase):

    def test_single_screen_all_windows(self):
        assert layout_engine.distribute_windows(3, 1, 4) == [3]

    def test_two_screens_even(self):
        assert layout_engine.distribute_windows(4, 2, 4) == [2, 2]

    def test_two_screens_odd(self):
        # 3 windows on 2 screens: primary gets extra
        assert layout_engine.distribute_windows(3, 2, 4) == [2, 1]

    def test_max_per_screen_capped(self):
        # 8 windows, 2 screens, max 4 each
        assert layout_engine.distribute_windows(8, 2, 4) == [4, 4]

    def test_zero_windows(self):
        assert layout_engine.distribute_windows(0, 2, 4) == [0, 0]

    def test_zero_screens(self):
        assert layout_engine.distribute_windows(3, 0, 4) == []

    def test_one_window(self):
        assert layout_engine.distribute_windows(1, 1, 4) == [1]

    def test_three_screens(self):
        # 5 windows on 3 screens: 2, 2, 1
        assert layout_engine.distribute_windows(5, 3, 4) == [2, 2, 1]


# ---------------------------------------------------------------------------
# Pillars Layout
# ---------------------------------------------------------------------------

class TestPillarsLayout(unittest.TestCase):

    def test_single_window_full_screen(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_pillars_layout(1, monitors, config)
        assert len(positions) == 1
        p = positions[0]
        assert p["x"] == 0
        assert p["y"] == 0
        assert p["width"] == 1920
        assert p["height"] == 1080

    def test_two_windows_split(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_pillars_layout(2, monitors, config)
        assert len(positions) == 2
        # With gap=40, total gaps = 40 (1 gap between 2 windows)
        # cell_width = (1920 - 40) / 2 = 940
        assert positions[0]["x"] == 0
        assert positions[0]["width"] == 940
        assert positions[1]["x"] == 940 + 40  # 980
        assert positions[1]["width"] == 940

    def test_three_windows_scaled_gap(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_pillars_layout(3, monitors, config)
        assert len(positions) == 3
        # gap scaled to 80% of 40 = 32
        gap = layout_engine.calculate_scaled_gap(40, 3)
        total_gaps = 2 * gap
        cell_width = (1920 - total_gaps) // 3
        assert positions[0]["width"] == cell_width
        assert positions[0]["x"] == 0
        assert positions[1]["x"] == cell_width + gap

    def test_full_height(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_pillars_layout(2, monitors, config)
        for p in positions:
            assert p["height"] == 1080

    def test_multi_monitor_distribution(self):
        monitors = [make_monitor(primary=True), make_monitor(x=1920, primary=False)]
        config = default_config()
        positions = layout_engine.calculate_pillars_layout(4, monitors, config)
        assert len(positions) == 4
        # 2 on each monitor
        assert positions[0]["monitor_index"] == 0
        assert positions[1]["monitor_index"] == 0
        assert positions[2]["monitor_index"] == 1
        assert positions[3]["monitor_index"] == 1


# ---------------------------------------------------------------------------
# Quads Layout
# ---------------------------------------------------------------------------

class TestQuadsLayout(unittest.TestCase):

    def test_four_windows_2x2(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_quads_layout(4, monitors, config)
        assert len(positions) == 4

        gap = layout_engine.calculate_scaled_gap(40, 4)
        half_w = (1920 - gap) // 2
        half_h = (1080 - gap) // 2

        # TL
        assert positions[0]["x"] == 0
        assert positions[0]["y"] == 0
        assert positions[0]["width"] == half_w
        assert positions[0]["height"] == half_h

        # TR
        assert positions[1]["x"] == half_w + gap
        assert positions[1]["y"] == 0

        # BL
        assert positions[2]["x"] == 0
        assert positions[2]["y"] == half_h + gap

        # BR
        assert positions[3]["x"] == half_w + gap
        assert positions[3]["y"] == half_h + gap

    def test_two_windows_quads(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_quads_layout(2, monitors, config)
        assert len(positions) == 2
        # Only TL and TR filled
        assert positions[0]["y"] == 0
        assert positions[1]["y"] == 0

    def test_overflow_to_extended_grid(self):
        monitors = [make_monitor()]
        config = default_config()
        # 5 windows on 1 monitor = overflow (capacity 4)
        positions = layout_engine.calculate_quads_layout(5, monitors, config)
        assert len(positions) == 5


# ---------------------------------------------------------------------------
# Overlap Layout
# ---------------------------------------------------------------------------

class TestOverlapLayout(unittest.TestCase):

    def test_single_window_full_screen(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_overlap_layout(1, monitors, config)
        assert len(positions) == 1
        assert positions[0]["width"] == 1920
        assert positions[0]["height"] == 1080

    def test_two_windows_overlap(self):
        monitors = [make_monitor()]
        config = default_config(overlap_percent=5)
        positions = layout_engine.calculate_overlap_layout(2, monitors, config)
        assert len(positions) == 2
        # overlap_offset = 1920 * 5 / 100 = 96
        # window_width = (1920 + 96 * 1) / 2 = 1008
        assert positions[0]["width"] == 1008
        assert positions[1]["width"] == 1008
        # Windows should overlap
        assert positions[1]["x"] < positions[0]["x"] + positions[0]["width"]

    def test_uses_primary_monitor(self):
        monitors = [
            make_monitor(x=1920, primary=False, name="HDMI-1"),
            make_monitor(x=0, primary=True, name="eDP-1"),
        ]
        config = default_config()
        positions = layout_engine.calculate_overlap_layout(2, monitors, config)
        # All on primary (index 1)
        assert all(p["monitor_index"] == 1 for p in positions)

    def test_full_height(self):
        monitors = [make_monitor()]
        config = default_config()
        positions = layout_engine.calculate_overlap_layout(3, monitors, config)
        for p in positions:
            assert p["height"] == 1080


# ---------------------------------------------------------------------------
# Auto Mode
# ---------------------------------------------------------------------------

class TestAutoMode(unittest.TestCase):

    @patch("layout_engine.window_service")
    def test_auto_pillars_for_few_windows(self, mock_ws):
        mock_ws.get_monitors.return_value = [make_monitor()]
        config = default_config(mode="auto")
        layout = layout_engine.calculate_layout([1, 2, 3], config)
        assert len(layout) == 3
        # Auto with 3 windows = pillars, so all same height
        for slot, pos in layout:
            assert pos["height"] == 1080

    @patch("layout_engine.window_service")
    def test_auto_quads_for_many_windows(self, mock_ws):
        mock_ws.get_monitors.return_value = [make_monitor()]
        config = default_config(mode="auto")
        layout = layout_engine.calculate_layout([1, 2, 3, 4, 5], config)
        assert len(layout) == 5


# ---------------------------------------------------------------------------
# Full calculate_layout integration
# ---------------------------------------------------------------------------

class TestCalculateLayout(unittest.TestCase):

    @patch("layout_engine.window_service")
    def test_empty_slots(self, mock_ws):
        assert layout_engine.calculate_layout([], default_config()) == []

    @patch("layout_engine.window_service")
    def test_no_monitors(self, mock_ws):
        mock_ws.get_monitors.return_value = []
        assert layout_engine.calculate_layout([1, 2], default_config()) == []

    @patch("layout_engine.window_service")
    def test_slots_sorted(self, mock_ws):
        mock_ws.get_monitors.return_value = [make_monitor()]
        layout = layout_engine.calculate_layout([3, 1, 2], default_config())
        slots = [s for s, p in layout]
        assert slots == [1, 2, 3]


# ---------------------------------------------------------------------------
# Snapback Save/Restore
# ---------------------------------------------------------------------------

class TestSnapback(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.state_path = os.path.join(self.tmpdir, "state.json")
        self._orig_state_path = layout_engine.STATE_PATH
        layout_engine.STATE_PATH = self.state_path

    def tearDown(self):
        layout_engine.STATE_PATH = self._orig_state_path
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("layout_engine.window_service")
    def test_save_and_restore(self, mock_ws):
        mock_ws.load_mapping.return_value = {"1": {"pid": 100}, "2": {"pid": 200}}
        mock_ws.get_pid_for_slot.side_effect = lambda s: {1: 100, 2: 200}.get(s)
        mock_ws.get_position.side_effect = lambda s: {
            1: {"x": 0, "y": 0, "width": 960, "height": 1080},
            2: {"x": 960, "y": 0, "width": 960, "height": 1080},
        }.get(s)
        mock_ws.position_window.return_value = True

        saved = layout_engine.snapback_save()
        assert saved == 2

        # Verify state.json has snapback data
        with open(self.state_path) as f:
            state = json.load(f)
        assert "1" in state["snapback"]
        assert state["snapback"]["1"]["x"] == 0

        # Restore
        restored = layout_engine.snapback_restore()
        assert restored == 2
        assert mock_ws.position_window.call_count == 2

    @patch("layout_engine.window_service")
    def test_save_empty_no_windows(self, mock_ws):
        mock_ws.load_mapping.return_value = {}
        assert layout_engine.snapback_save() == 0

    @patch("layout_engine.window_service")
    def test_restore_empty(self, mock_ws):
        # No snapback key in state
        with open(self.state_path, "w") as f:
            json.dump({}, f)
        assert layout_engine.snapback_restore() == 0


# ---------------------------------------------------------------------------
# Glitch Mode
# ---------------------------------------------------------------------------

class TestGlitchMode(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.state_path = os.path.join(self.tmpdir, "state.json")
        self._orig_state_path = layout_engine.STATE_PATH
        layout_engine.STATE_PATH = self.state_path
        layout_engine._last_applied = {}
        layout_engine._last_glitch_check = 0.0

    def tearDown(self):
        layout_engine.STATE_PATH = self._orig_state_path
        layout_engine._last_applied = {}
        layout_engine._last_glitch_check = 0.0
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("layout_engine.window_service")
    def test_glitch_disabled_returns_negative(self, mock_ws):
        config = default_config(glitch_enabled=False)
        with open(self.state_path, "w") as f:
            json.dump({"layout": config}, f)
        result = layout_engine.check_and_snap()
        assert result == -1

    @patch("layout_engine.window_service")
    def test_glitch_detects_drift_and_snaps(self, mock_ws):
        config = default_config(glitch_enabled=True)
        with open(self.state_path, "w") as f:
            json.dump({"layout": config}, f)

        # Set cached positions
        layout_engine._last_applied = {
            1: {"x": 0, "y": 0, "width": 960, "height": 1080},
        }

        # Current position is drifted
        mock_ws.get_position.return_value = {
            "x": 50, "y": 0, "width": 960, "height": 1080
        }
        mock_ws.position_window.return_value = True

        result = layout_engine.check_and_snap()
        assert result == 1
        mock_ws.position_window.assert_called_once_with(1, 0, 0, 960, 1080)

    @patch("layout_engine.window_service")
    def test_glitch_no_drift_no_snap(self, mock_ws):
        config = default_config(glitch_enabled=True)
        with open(self.state_path, "w") as f:
            json.dump({"layout": config}, f)

        layout_engine._last_applied = {
            1: {"x": 0, "y": 0, "width": 960, "height": 1080},
        }

        # Current position is within threshold
        mock_ws.get_position.return_value = {
            "x": 5, "y": 0, "width": 960, "height": 1080
        }

        result = layout_engine.check_and_snap()
        assert result == 0
        mock_ws.position_window.assert_not_called()


# ---------------------------------------------------------------------------
# Layout Config Persistence
# ---------------------------------------------------------------------------

class TestLayoutConfig(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.state_path = os.path.join(self.tmpdir, "state.json")
        self._orig_state_path = layout_engine.STATE_PATH
        layout_engine.STATE_PATH = self.state_path

    def tearDown(self):
        layout_engine.STATE_PATH = self._orig_state_path
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_load_defaults_when_no_file(self):
        config = layout_engine.load_layout_config()
        assert config["mode"] == "pillars"
        assert config["gap_size"] == 40
        assert config["glitch_enabled"] is True
        assert config["overlap_percent"] == 5

    def test_save_and_load_roundtrip(self):
        config = {
            "mode": "quads",
            "gap_size": 60,
            "glitch_enabled": False,
            "overlap_percent": 10,
        }
        layout_engine.save_layout_config(config)

        loaded = layout_engine.load_layout_config()
        assert loaded["mode"] == "quads"
        assert loaded["gap_size"] == 60
        assert loaded["glitch_enabled"] is False
        assert loaded["overlap_percent"] == 10

    def test_load_respects_layout_mode_key(self):
        # action_cycle_layout writes layout_mode at top level
        with open(self.state_path, "w") as f:
            json.dump({"layout_mode": "overlap"}, f)
        config = layout_engine.load_layout_config()
        assert config["mode"] == "overlap"


if __name__ == "__main__":
    unittest.main()
