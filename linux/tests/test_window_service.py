"""Unit tests for window_service.py."""
import json
import os
import sys
import tempfile
from unittest.mock import patch, MagicMock

import pytest

# Add parent directory to path for import
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import window_service


@pytest.fixture(autouse=True)
def use_tmp_map_file(tmp_path):
    """Use a temporary file for the window mapping."""
    original = window_service.MAP_FILE
    window_service.MAP_FILE = str(tmp_path / 'matrix-window-map.json')
    # Reset extension cache between tests
    window_service._extension_cache = None
    yield
    window_service.MAP_FILE = original
    window_service._extension_cache = None


# --- Slot Mapping Tests ---

class TestSlotMapping:
    def test_register_and_lookup(self):
        window_service.register_window(1, 12345)
        assert window_service.get_pid_for_slot(1) is None  # PID 12345 is not alive

    def test_register_with_own_pid(self):
        my_pid = os.getpid()
        window_service.register_window(1, my_pid)
        assert window_service.get_pid_for_slot(1) == my_pid

    def test_unregister(self):
        my_pid = os.getpid()
        window_service.register_window(1, my_pid)
        window_service.unregister_window(1)
        assert window_service.get_pid_for_slot(1) is None

    def test_multiple_slots(self):
        my_pid = os.getpid()
        window_service.register_window(1, my_pid)
        window_service.register_window(2, my_pid)
        window_service.register_window(3, my_pid)
        assert window_service.get_pid_for_slot(1) == my_pid
        assert window_service.get_pid_for_slot(2) == my_pid
        assert window_service.get_pid_for_slot(3) == my_pid

    def test_dead_pid_returns_none(self):
        window_service.register_window(1, 99999999)
        assert window_service.get_pid_for_slot(1) is None

    def test_mapping_persistence(self):
        my_pid = os.getpid()
        window_service.register_window(1, my_pid)
        # Re-read from file
        mapping = window_service.load_mapping()
        assert str(1) in mapping
        assert mapping['1']['pid'] == my_pid

    def test_empty_mapping(self):
        assert window_service.get_pid_for_slot(1) is None
        assert window_service.load_mapping() == {}

    def test_overwrite_slot(self):
        my_pid = os.getpid()
        window_service.register_window(1, 12345)
        window_service.register_window(1, my_pid)
        assert window_service.get_pid_for_slot(1) == my_pid


# --- D-Bus Response Parsing Tests ---

class TestResponseParsing:
    def test_parse_bool_true(self):
        assert window_service._parse_bool_response('(true,)') is True

    def test_parse_bool_false(self):
        assert window_service._parse_bool_response('(false,)') is False

    def test_parse_bool_empty(self):
        assert window_service._parse_bool_response('') is False

    def test_parse_string_simple(self):
        response = "('hello',)"
        assert window_service._parse_string_response(response) == 'hello'

    def test_parse_string_json(self):
        response = '(\'{"x":0,"y":0,"width":683,"height":768}\',)'
        parsed = window_service._parse_string_response(response)
        data = json.loads(parsed)
        assert data['x'] == 0
        assert data['width'] == 683

    def test_parse_string_json_array(self):
        response = '(\'[{"pid":1234,"x":0,"y":0,"width":100,"height":200}]\',)'
        parsed = window_service._parse_string_response(response)
        data = json.loads(parsed)
        assert len(data) == 1
        assert data[0]['pid'] == 1234

    def test_parse_string_empty_json(self):
        response = "('{}',)"
        parsed = window_service._parse_string_response(response)
        data = json.loads(parsed)
        assert data == {}


# --- Monitor Parsing Tests ---

class TestMonitorParsing:
    REAL_MUTTER_OUTPUT = (
        "(uint32 1, [(('eDP-1', 'BOE', '0x0817', '0x00000000'), "
        "[('1366x768@60.000', 1366, 768, 59.999866485595703, 1.0, [1.0], "
        "{'is-current': <true>, 'is-preferred': <true>}), "
        "('1280x720@59.745', 1280, 720, 59.744712829589844, 1.0, [1.0], {})], "
        "{'is-builtin': <true>, 'display-name': <'Built-in display'>})], "
        "[(0, 0, 1.0, uint32 0, true, [('eDP-1', 'BOE', '0x0817', '0x00000000')], "
        "@a{sv} {})], {'layout-mode': <uint32 1>})"
    )

    def test_parse_single_monitor(self):
        monitors = window_service._parse_mutter_monitors(self.REAL_MUTTER_OUTPUT)
        assert len(monitors) == 1
        m = monitors[0]
        assert m['name'] == 'eDP-1'
        assert m['x'] == 0
        assert m['y'] == 0
        assert m['width'] == 1366
        assert m['height'] == 768
        assert m['scale'] == 1.0
        assert m['primary'] is True

    def test_parse_empty_returns_fallback(self):
        monitors = window_service._parse_mutter_monitors('')
        assert len(monitors) == 1
        assert monitors[0]['name'] == 'unknown'

    def test_fallback_monitors(self):
        monitors = window_service._fallback_monitors()
        assert len(monitors) == 1
        assert monitors[0]['width'] > 0
        assert monitors[0]['height'] > 0
        assert monitors[0]['primary'] is True


# --- Backend Selection Tests ---

class TestBackendSelection:
    @patch('window_service.gnome_extension_available', return_value=True)
    @patch('window_service.move_resize_gnome', return_value=True)
    def test_uses_gnome_when_available(self, mock_gnome, mock_avail):
        my_pid = os.getpid()
        window_service.register_window(1, my_pid)
        window_service._extension_cache = None
        result = window_service.position_window(1, 0, 0, 800, 600)
        assert result is True
        mock_gnome.assert_called_once_with(my_pid, 0, 0, 800, 600)

    @patch('window_service.gnome_extension_available', return_value=False)
    @patch('window_service.move_resize_xwayland', return_value=True)
    def test_falls_back_to_xwayland(self, mock_xwayland, mock_avail):
        my_pid = os.getpid()
        window_service.register_window(1, my_pid)
        window_service._extension_cache = None
        result = window_service.position_window(1, 0, 0, 800, 600)
        assert result is True
        mock_xwayland.assert_called_once_with(my_pid, 0, 0, 800, 600)

    def test_no_pid_returns_false(self):
        result = window_service.position_window(99, 0, 0, 800, 600)
        assert result is False


# --- Decoration Offset Tests ---

class TestDecorationOffset:
    def test_default_offset(self):
        offset = window_service.measure_decoration_offset(99)
        assert offset['titlebar_height'] == 37
        assert offset['shadow_left'] == 0


# --- PID Alive Tests ---

class TestPidAlive:
    def test_own_pid_alive(self):
        assert window_service._pid_alive(os.getpid()) is True

    def test_dead_pid(self):
        assert window_service._pid_alive(99999999) is False

    def test_invalid_pid(self):
        assert window_service._pid_alive(None) is False
        assert window_service._pid_alive('abc') is False
