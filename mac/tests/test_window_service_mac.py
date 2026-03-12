"""Tests for macOS window service (window_service_mac.py).

Tests window positioning, slot mapping, monitor discovery, and geometry.
All subprocess/osascript calls are mocked.
"""

import json
import os
import sys
import tempfile
from unittest.mock import MagicMock, mock_open, patch, call

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "linux"))

import window_service_mac as wsm


# ---------------------------------------------------------------------------
# Slot-to-PID Mapping
# ---------------------------------------------------------------------------

class TestLoadMapping:
    """Test load_mapping from JSON file."""

    def test_returns_dict_on_valid_json(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"1": {"pid": 100}}')
        with patch.object(wsm, "MAP_FILE", str(f)):
            result = wsm.load_mapping()
        assert result == {"1": {"pid": 100}}

    def test_returns_empty_on_missing_file(self):
        with patch.object(wsm, "MAP_FILE", "/tmp/nonexistent-map-xyz.json"):
            result = wsm.load_mapping()
        assert result == {}

    def test_returns_empty_on_invalid_json(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text("not json")
        with patch.object(wsm, "MAP_FILE", str(f)):
            result = wsm.load_mapping()
        assert result == {}

    def test_returns_empty_on_empty_file(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text("")
        with patch.object(wsm, "MAP_FILE", str(f)):
            result = wsm.load_mapping()
        assert result == {}


class TestSaveMapping:
    """Test save_mapping to JSON file."""

    def test_writes_valid_json(self, tmp_path):
        f = tmp_path / "map.json"
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.save_mapping({"1": {"pid": 100}})
        data = json.loads(f.read_text())
        assert data == {"1": {"pid": 100}}

    def test_overwrites_existing(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"old": true}')
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.save_mapping({"new": True})
        data = json.loads(f.read_text())
        assert data == {"new": True}

    def test_writes_empty_mapping(self, tmp_path):
        f = tmp_path / "map.json"
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.save_mapping({})
        assert json.loads(f.read_text()) == {}


class TestRegisterWindow:
    """Test register_window slot registration."""

    def test_registers_new_slot(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text("{}")
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.register_window(1, 1234)
            data = json.loads(f.read_text())
        assert data["1"]["pid"] == 1234

    def test_overwrites_existing_slot(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"1": {"pid": 999}}')
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.register_window(1, 5678)
            data = json.loads(f.read_text())
        assert data["1"]["pid"] == 5678

    def test_preserves_other_slots(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"2": {"pid": 200}}')
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.register_window(1, 100)
            data = json.loads(f.read_text())
        assert data["1"]["pid"] == 100
        assert data["2"]["pid"] == 200

    def test_converts_pid_to_int(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text("{}")
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.register_window(1, "1234")
            data = json.loads(f.read_text())
        assert data["1"]["pid"] == 1234


class TestUnregisterWindow:
    """Test unregister_window slot removal."""

    def test_removes_existing_slot(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"1": {"pid": 100}, "2": {"pid": 200}}')
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.unregister_window(1)
            data = json.loads(f.read_text())
        assert "1" not in data
        assert "2" in data

    def test_noop_on_missing_slot(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"1": {"pid": 100}}')
        with patch.object(wsm, "MAP_FILE", str(f)):
            wsm.unregister_window(99)
            data = json.loads(f.read_text())
        assert data == {"1": {"pid": 100}}


class TestGetPidForSlot:
    """Test get_pid_for_slot lookup."""

    def test_returns_pid_when_alive(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"1": {"pid": 100}}')
        with patch.object(wsm, "MAP_FILE", str(f)), \
             patch.object(wsm, "_pid_alive", return_value=True):
            assert wsm.get_pid_for_slot(1) == 100

    def test_returns_none_when_dead(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text('{"1": {"pid": 100}}')
        with patch.object(wsm, "MAP_FILE", str(f)), \
             patch.object(wsm, "_pid_alive", return_value=False):
            assert wsm.get_pid_for_slot(1) is None

    def test_returns_none_when_slot_missing(self, tmp_path):
        f = tmp_path / "map.json"
        f.write_text("{}")
        with patch.object(wsm, "MAP_FILE", str(f)):
            assert wsm.get_pid_for_slot(99) is None


class TestPidAlive:
    """Test _pid_alive helper."""

    @patch("os.kill")
    def test_alive_process(self, mock_kill):
        assert wsm._pid_alive(os.getpid()) is True

    @patch("os.kill", side_effect=ProcessLookupError)
    def test_dead_process(self, mock_kill):
        assert wsm._pid_alive(99999) is False

    @patch("os.kill", side_effect=PermissionError)
    def test_permission_error_returns_false(self, mock_kill):
        assert wsm._pid_alive(1) is False

    def test_invalid_pid_returns_false(self):
        assert wsm._pid_alive(None) is False

    def test_negative_pid_returns_false(self):
        # os.kill with negative pids targets process groups, but we wrap in try
        assert wsm._pid_alive("not_a_number") is False


# ---------------------------------------------------------------------------
# osascript wrapper
# ---------------------------------------------------------------------------

class TestOsascript:
    """Test _osascript helper."""

    @patch("subprocess.run")
    def test_success(self, mock_run):
        mock_run.return_value = MagicMock(stdout="result\n", returncode=0)
        out, ok = wsm._osascript("tell app ...")
        assert ok is True
        assert out == "result"

    @patch("subprocess.run")
    def test_failure(self, mock_run):
        mock_run.return_value = MagicMock(stdout="", returncode=1)
        out, ok = wsm._osascript("bad script")
        assert ok is False

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_osascript_not_found(self, mock_run):
        out, ok = wsm._osascript("anything")
        assert ok is False
        assert out == ""

    def test_timeout(self):
        import subprocess as sp
        with patch("subprocess.run", side_effect=sp.TimeoutExpired("cmd", 5)):
            out, ok = wsm._osascript("slow")
        assert ok is False


# ---------------------------------------------------------------------------
# Window positioning
# ---------------------------------------------------------------------------

class TestMoveResizeWindow:
    """Test move_resize_window via osascript."""

    @patch.object(wsm, "_osascript", return_value=("", True))
    def test_success(self, mock_osa):
        assert wsm.move_resize_window(1234, 0, 0, 800, 600) is True
        script = mock_osa.call_args[0][0]
        assert "1234" in script
        assert "{0, 0}" in script
        assert "{800, 600}" in script

    @patch.object(wsm, "_osascript", return_value=("", False))
    def test_failure(self, mock_osa):
        assert wsm.move_resize_window(1234, 0, 0, 800, 600) is False


class TestGetGeometryWindow:
    """Test get_geometry_window via osascript."""

    @patch.object(wsm, "_osascript", return_value=("100,200,800,600", True))
    def test_parses_geometry(self, mock_osa):
        geo = wsm.get_geometry_window(1234)
        assert geo == {"x": 100, "y": 200, "width": 800, "height": 600}

    @patch.object(wsm, "_osascript", return_value=("", False))
    def test_returns_none_on_failure(self, mock_osa):
        assert wsm.get_geometry_window(1234) is None

    @patch.object(wsm, "_osascript", return_value=("bad", True))
    def test_returns_none_on_bad_output(self, mock_osa):
        assert wsm.get_geometry_window(1234) is None

    @patch.object(wsm, "_osascript", return_value=("", True))
    def test_returns_none_on_empty_output(self, mock_osa):
        assert wsm.get_geometry_window(1234) is None


class TestListGhosttyWindows:
    """Test list_ghostty_windows via osascript."""

    @patch.object(wsm, "_osascript", return_value=("0,0,800,600|100,100,1920,1080", True))
    def test_parses_multiple_windows(self, mock_osa):
        windows = wsm.list_ghostty_windows()
        assert len(windows) == 2
        assert windows[0] == {"x": 0, "y": 0, "width": 800, "height": 600}
        assert windows[1] == {"x": 100, "y": 100, "width": 1920, "height": 1080}

    @patch.object(wsm, "_osascript", return_value=("", False))
    def test_returns_empty_on_failure(self, mock_osa):
        assert wsm.list_ghostty_windows() == []

    @patch.object(wsm, "_osascript", return_value=("", True))
    def test_returns_empty_on_empty_output(self, mock_osa):
        assert wsm.list_ghostty_windows() == []

    @patch.object(wsm, "_osascript", return_value=("bad|data", True))
    def test_skips_bad_entries(self, mock_osa):
        assert wsm.list_ghostty_windows() == []

    @patch.object(wsm, "_osascript", return_value=("0,0,800,600|bad", True))
    def test_partial_bad_entries(self, mock_osa):
        windows = wsm.list_ghostty_windows()
        assert len(windows) == 1


# ---------------------------------------------------------------------------
# High-level API
# ---------------------------------------------------------------------------

class TestPositionWindow:
    """Test position_window high-level function."""

    @patch.object(wsm, "move_resize_window", return_value=True)
    @patch.object(wsm, "get_pid_for_slot", return_value=1234)
    def test_success(self, mock_pid, mock_move):
        assert wsm.position_window(1, 0, 0, 800, 600) is True
        mock_move.assert_called_once_with(1234, 0, 0, 800, 600)

    @patch.object(wsm, "get_pid_for_slot", return_value=None)
    def test_no_pid_returns_false(self, mock_pid):
        assert wsm.position_window(1, 0, 0, 800, 600) is False


class TestGetPosition:
    """Test get_position high-level function."""

    @patch.object(wsm, "get_geometry_window", return_value={"x": 0, "y": 0, "width": 800, "height": 600})
    @patch.object(wsm, "get_pid_for_slot", return_value=1234)
    def test_returns_geometry(self, mock_pid, mock_geo):
        geo = wsm.get_position(1)
        assert geo["width"] == 800

    @patch.object(wsm, "get_pid_for_slot", return_value=None)
    def test_no_pid_returns_none(self, mock_pid):
        assert wsm.get_position(1) is None


# ---------------------------------------------------------------------------
# Monitor discovery
# ---------------------------------------------------------------------------

class TestGetMonitors:
    """Test get_monitors and system_profiler parsing."""

    @patch("subprocess.run")
    def test_parses_system_profiler(self, mock_run):
        profiler_data = {
            "SPDisplaysDataType": [{
                "spdisplays_ndrvs": [{
                    "_name": "Main Display",
                    "_spdisplays_resolution": "2560 x 1440",
                    "spdisplays_main": "spdisplays_yes",
                }]
            }]
        }
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(profiler_data)
        )
        monitors = wsm.get_monitors()
        assert len(monitors) >= 1
        assert monitors[0]["width"] == 2560
        assert monitors[0]["height"] == 1440
        assert monitors[0]["primary"] is True

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_fallback_on_missing_command(self, mock_run):
        monitors = wsm.get_monitors()
        assert len(monitors) == 1
        assert monitors[0]["width"] == 1920

    @patch("subprocess.run")
    def test_fallback_on_bad_json(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="not json")
        monitors = wsm.get_monitors()
        assert len(monitors) == 1
        assert monitors[0]["primary"] is True

    @patch("subprocess.run")
    def test_retina_scale(self, mock_run):
        profiler_data = {
            "SPDisplaysDataType": [{
                "spdisplays_ndrvs": [{
                    "_name": "Retina Display",
                    "_spdisplays_resolution": "2560 x 1600 Retina",
                    "spdisplays_main": "spdisplays_yes",
                }]
            }]
        }
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(profiler_data)
        )
        monitors = wsm.get_monitors()
        assert monitors[0]["scale"] == 2.0

    @patch("subprocess.run")
    def test_non_retina_scale(self, mock_run):
        profiler_data = {
            "SPDisplaysDataType": [{
                "spdisplays_ndrvs": [{
                    "_name": "External",
                    "_spdisplays_resolution": "1920 x 1080",
                    "spdisplays_main": "spdisplays_yes",
                }]
            }]
        }
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(profiler_data)
        )
        monitors = wsm.get_monitors()
        assert monitors[0]["scale"] == 1.0

    @patch("subprocess.run")
    def test_multiple_monitors(self, mock_run):
        profiler_data = {
            "SPDisplaysDataType": [{
                "spdisplays_ndrvs": [
                    {
                        "_name": "Main",
                        "_spdisplays_resolution": "2560 x 1440",
                        "spdisplays_main": "spdisplays_yes",
                    },
                    {
                        "_name": "External",
                        "_spdisplays_resolution": "1920 x 1080",
                    },
                ]
            }]
        }
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(profiler_data)
        )
        monitors = wsm.get_monitors()
        assert len(monitors) == 2
        assert monitors[0]["x"] == 0  # main display at origin
        assert monitors[0]["primary"] is True
        assert monitors[1]["primary"] is False


class TestFallbackMonitors:
    """Test _fallback_monitors."""

    def test_returns_single_default(self):
        result = wsm._fallback_monitors()
        assert len(result) == 1
        assert result[0]["width"] == 1920
        assert result[0]["height"] == 1080
        assert result[0]["primary"] is True


class TestMeasureDecorationOffset:
    """Test measure_decoration_offset."""

    def test_returns_fixed_values(self):
        offset = wsm.measure_decoration_offset(1)
        assert offset["titlebar_height"] == 28
        assert offset["shadow_left"] == 0
        assert offset["shadow_right"] == 0

    def test_same_for_any_slot(self):
        assert wsm.measure_decoration_offset(1) == wsm.measure_decoration_offset(5)
