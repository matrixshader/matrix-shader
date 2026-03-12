"""Tests for macOS shader service (shader_service_mac.py).

Tests all shader functions, compatibility aliases, and reload mechanisms.
All macOS-specific calls are mocked so tests run on Linux.
"""

import json
import os
import sys
import tempfile
from unittest.mock import MagicMock, mock_open, patch, call

import pytest

# Add paths
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "linux"))

import shader_service_mac as ssm


# ---------------------------------------------------------------------------
# Compatibility aliases
# ---------------------------------------------------------------------------

class TestGetGhosttyBusNames:
    """Test the compatibility alias get_ghostty_bus_names."""

    @patch.object(ssm, "get_ghostty_pids")
    def test_empty_mapping(self, mock_pids):
        mock_pids.return_value = {}
        result = ssm.get_ghostty_bus_names()
        assert result == {}

    @patch.object(ssm, "get_ghostty_pids")
    def test_single_slot(self, mock_pids):
        mock_pids.return_value = {1: {"pid": 1234}}
        result = ssm.get_ghostty_bus_names()
        assert result == {1: {"bus_name": 1234}}

    @patch.object(ssm, "get_ghostty_pids")
    def test_multiple_slots(self, mock_pids):
        mock_pids.return_value = {
            1: {"pid": 100},
            2: {"pid": 200},
            3: {"pid": 300},
        }
        result = ssm.get_ghostty_bus_names()
        assert len(result) == 3
        assert result[1]["bus_name"] == 100
        assert result[2]["bus_name"] == 200
        assert result[3]["bus_name"] == 300

    @patch.object(ssm, "get_ghostty_pids")
    def test_preserves_slot_keys(self, mock_pids):
        mock_pids.return_value = {5: {"pid": 555}}
        result = ssm.get_ghostty_bus_names()
        assert 5 in result


class TestReloadGhosttyAlias:
    """Test the compatibility alias reload_ghostty."""

    @patch.object(ssm, "reload_ghostty_mac")
    def test_calls_reload_with_int(self, mock_reload):
        ssm.reload_ghostty("1234")
        mock_reload.assert_called_once_with(1234)

    @patch.object(ssm, "reload_ghostty_mac")
    def test_calls_reload_with_pid(self, mock_reload):
        ssm.reload_ghostty(5678)
        mock_reload.assert_called_once_with(5678)


# ---------------------------------------------------------------------------
# write_shader_param
# ---------------------------------------------------------------------------

class TestWriteShaderParam:
    """Test write_shader_param function."""

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", return_value="modified content")
    @patch("builtins.open", mock_open(read_data="#define RAIN_SPEED 1.0"))
    @patch.object(ssm, "clamp_value", return_value=2.0)
    def test_writes_and_reloads(self, mock_clamp, mock_replace, mock_atomic,
                                 mock_pids, mock_reload):
        mock_pids.return_value = {1: {"pid": 1234}}
        ssm.write_shader_param(1, "RAIN_SPEED", 2.0)
        mock_clamp.assert_called_once_with("RAIN_SPEED", 2.0)
        mock_replace.assert_called_once()
        mock_atomic.assert_called_once()
        mock_reload.assert_called_once_with(1234)

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", return_value="content")
    @patch("builtins.open", mock_open(read_data="content"))
    @patch.object(ssm, "clamp_value", return_value=1.0)
    def test_no_reload_if_slot_not_found(self, mock_clamp, mock_replace,
                                          mock_atomic, mock_pids, mock_reload):
        mock_pids.return_value = {2: {"pid": 999}}
        ssm.write_shader_param(1, "RAIN_SPEED", 1.0)
        mock_reload.assert_not_called()

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", return_value="content")
    @patch("builtins.open", mock_open(read_data="content"))
    @patch.object(ssm, "clamp_value", return_value=0.5)
    def test_clamps_value_before_write(self, mock_clamp, mock_replace,
                                        mock_atomic, mock_pids, mock_reload):
        mock_pids.return_value = {}
        ssm.write_shader_param(1, "RAIN_DENSITY", 999.0)
        mock_clamp.assert_called_once_with("RAIN_DENSITY", 999.0)

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", return_value="content")
    @patch("builtins.open", mock_open(read_data="content"))
    @patch.object(ssm, "clamp_value", return_value=1.0)
    def test_shader_path_uses_slot(self, mock_clamp, mock_replace,
                                    mock_atomic, mock_pids, mock_reload):
        mock_pids.return_value = {}
        ssm.write_shader_param(3, "RAIN_SPEED", 1.0)
        open_call = open.call_args
        assert "matrix-3.glsl" in str(open_call)


# ---------------------------------------------------------------------------
# write_shader_params
# ---------------------------------------------------------------------------

class TestWriteShaderParams:
    """Test write_shader_params (multi-param) function."""

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", side_effect=lambda c, p, v: f"{c}+{p}={v}")
    @patch("builtins.open", mock_open(read_data="base"))
    @patch.object(ssm, "clamp_value", side_effect=lambda p, v: v)
    def test_applies_multiple_params(self, mock_clamp, mock_replace,
                                      mock_atomic, mock_pids, mock_reload):
        mock_pids.return_value = {1: {"pid": 100}}
        params = {"RAIN_SPEED": 2.0, "RAIN_DENSITY": 0.5}
        ssm.write_shader_params(1, params)
        assert mock_replace.call_count == 2
        assert mock_clamp.call_count == 2

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", return_value="c")
    @patch("builtins.open", mock_open(read_data="c"))
    @patch.object(ssm, "clamp_value", side_effect=lambda p, v: v)
    def test_single_reload_for_multiple_params(self, mock_clamp, mock_replace,
                                                mock_atomic, mock_pids, mock_reload):
        mock_pids.return_value = {1: {"pid": 100}}
        ssm.write_shader_params(1, {"A": 1.0, "B": 2.0, "C": 3.0})
        mock_reload.assert_called_once_with(100)

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    @patch.object(ssm, "atomic_write")
    @patch.object(ssm, "replace_define", return_value="c")
    @patch("builtins.open", mock_open(read_data="c"))
    @patch.object(ssm, "clamp_value", side_effect=lambda p, v: v)
    def test_empty_params_still_writes(self, mock_clamp, mock_replace,
                                        mock_atomic, mock_pids, mock_reload):
        mock_pids.return_value = {}
        ssm.write_shader_params(1, {})
        mock_atomic.assert_called_once()
        mock_replace.assert_not_called()


# ---------------------------------------------------------------------------
# reload_all
# ---------------------------------------------------------------------------

class TestReloadAll:
    """Test reload_all function."""

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    def test_reloads_all_slots(self, mock_pids, mock_reload):
        mock_pids.return_value = {
            1: {"pid": 100},
            2: {"pid": 200},
            3: {"pid": 300},
        }
        ssm.reload_all()
        assert mock_reload.call_count == 3
        mock_reload.assert_any_call(100)
        mock_reload.assert_any_call(200)
        mock_reload.assert_any_call(300)

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    def test_no_instances(self, mock_pids, mock_reload):
        mock_pids.return_value = {}
        ssm.reload_all()
        mock_reload.assert_not_called()

    @patch.object(ssm, "reload_ghostty_mac")
    @patch.object(ssm, "get_ghostty_pids")
    def test_single_instance(self, mock_pids, mock_reload):
        mock_pids.return_value = {5: {"pid": 555}}
        ssm.reload_all()
        mock_reload.assert_called_once_with(555)


# ---------------------------------------------------------------------------
# Imports and exports
# ---------------------------------------------------------------------------

class TestImportsExist:
    """Test that all expected names are importable."""

    def test_param_defaults(self):
        assert hasattr(ssm, "PARAM_DEFAULTS")
        assert isinstance(ssm.PARAM_DEFAULTS, dict)

    def test_param_ranges(self):
        assert hasattr(ssm, "PARAM_RANGES")
        assert isinstance(ssm.PARAM_RANGES, dict)

    def test_preset_colors(self):
        assert hasattr(ssm, "PRESET_COLORS")
        assert isinstance(ssm.PRESET_COLORS, (list, tuple, dict))

    def test_slot_shader_dir(self):
        assert hasattr(ssm, "SLOT_SHADER_DIR")
        assert isinstance(ssm.SLOT_SHADER_DIR, str)

    def test_template_path(self):
        assert hasattr(ssm, "TEMPLATE_PATH")
        assert isinstance(ssm.TEMPLATE_PATH, str)

    def test_atomic_write(self):
        assert callable(ssm.atomic_write)

    def test_clamp_value(self):
        assert callable(ssm.clamp_value)

    def test_create_slot_shader(self):
        assert callable(ssm.create_slot_shader)

    def test_read_shader_config(self):
        assert callable(ssm.read_shader_config)

    def test_replace_define(self):
        assert callable(ssm.replace_define)

    def test_get_ghostty_bus_names(self):
        assert callable(ssm.get_ghostty_bus_names)

    def test_reload_ghostty(self):
        assert callable(ssm.reload_ghostty)

    def test_write_shader_param(self):
        assert callable(ssm.write_shader_param)

    def test_write_shader_params(self):
        assert callable(ssm.write_shader_params)

    def test_reload_all(self):
        assert callable(ssm.reload_all)
