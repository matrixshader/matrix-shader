"""Tests for macOS construct service (construct_service_mac.py).

Tests quick_launch, transition_to_rain_mac, find_next_slot_mac,
and color/shader mappings. All macOS-specific calls are mocked
so tests run on Linux.
"""

import os
import re
import sys
import tempfile
from unittest.mock import MagicMock, mock_open, patch, call

import pytest

# Add paths so imports work on Linux
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "linux"))


class TestConstructServiceMacImports:
    """Verify construct_service_mac exports expected names."""

    def test_import_module(self):
        import construct_service_mac
        assert construct_service_mac is not None

    def test_has_color_map(self):
        from construct_service_mac import COLOR_MAP
        assert isinstance(COLOR_MAP, dict)
        assert "green" in COLOR_MAP

    def test_has_bonus_shaders(self):
        from construct_service_mac import BONUS_SHADERS
        assert isinstance(BONUS_SHADERS, dict)
        assert "aurora" in BONUS_SHADERS

    def test_has_find_next_slot_mac(self):
        from construct_service_mac import find_next_slot_mac
        assert callable(find_next_slot_mac)

    def test_has_quick_launch(self):
        from construct_service_mac import quick_launch
        assert callable(quick_launch)

    def test_has_transition_to_rain_mac(self):
        from construct_service_mac import transition_to_rain_mac
        assert callable(transition_to_rain_mac)


class TestColorMappingsMatchLinux:
    """Verify Mac color/shader maps match Linux exactly."""

    def test_color_map_matches_linux(self):
        from construct_service_mac import COLOR_MAP
        from construct_service import COLOR_MAP as LINUX_COLOR_MAP
        assert COLOR_MAP == LINUX_COLOR_MAP

    def test_bonus_shaders_match_linux(self):
        from construct_service_mac import BONUS_SHADERS
        from construct_service import BONUS_SHADERS as LINUX_BONUS
        assert BONUS_SHADERS == LINUX_BONUS


class TestFindNextSlotMac:
    """Test Mac-specific slot discovery using ps instead of /proc."""

    @patch("construct_service_mac.subprocess.run")
    def test_empty_slots_returns_1(self, mock_run):
        """All slots empty returns slot 1."""
        mock_run.return_value = MagicMock(
            stdout="  PID ARGS\n 1234 /usr/bin/bash\n",
            returncode=0,
        )
        from construct_service_mac import find_next_slot_mac
        result = find_next_slot_mac()
        assert result == 1

    @patch("construct_service_mac.subprocess.run")
    @patch("os.path.isfile")
    def test_slot1_occupied_returns_2(self, mock_isfile, mock_run):
        """Slot 1 occupied returns slot 2."""
        mock_isfile.side_effect = lambda p: "matrix-1.conf" in p
        mock_run.return_value = MagicMock(
            stdout="  PID ARGS\n 1234 ghostty --config-file=/tmp/ghostty-matrix-1.conf\n",
            returncode=0,
        )
        from construct_service_mac import find_next_slot_mac
        result = find_next_slot_mac()
        assert result == 2

    @patch("construct_service_mac.subprocess.run")
    @patch("os.path.isfile")
    def test_all_slots_full_returns_none(self, mock_isfile, mock_run):
        """All 8 slots full returns None."""
        mock_isfile.return_value = True
        lines = "  PID ARGS\n"
        for s in range(1, 9):
            lines += f" {1000+s} ghostty --config-file=/tmp/ghostty-matrix-{s}.conf\n"
        mock_run.return_value = MagicMock(stdout=lines, returncode=0)
        from construct_service_mac import find_next_slot_mac
        result = find_next_slot_mac()
        assert result is None


class TestQuickLaunchMac:
    """Test quick_launch uses Mac-compatible slot finding."""

    @patch("construct_service_mac.find_next_slot_mac", return_value=1)
    @patch("construct_service_mac._write_ghostty_config_mac", return_value="/tmp/ghostty-matrix-1.conf")
    @patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/matrix-shaders/matrix-1.glsl")
    def test_quick_launch_green(self, mock_create, mock_conf, mock_slot):
        from construct_service_mac import quick_launch
        result = quick_launch("green")
        assert result["slot"] == 1
        assert "error" not in result
        mock_create.assert_called_once()

    @patch("construct_service_mac.find_next_slot_mac", return_value=None)
    def test_quick_launch_all_full(self, mock_slot):
        from construct_service_mac import quick_launch
        result = quick_launch("green")
        assert "error" in result

    @patch("construct_service_mac.find_next_slot_mac", return_value=2)
    @patch("construct_service_mac._write_ghostty_config_mac", return_value="/tmp/ghostty-matrix-2.conf")
    @patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/matrix-shaders/matrix-2.glsl")
    def test_quick_launch_blue(self, mock_create, mock_conf, mock_slot):
        from construct_service_mac import quick_launch
        result = quick_launch("blue")
        assert result["slot"] == 2

    @patch("construct_service_mac.find_next_slot_mac", return_value=3)
    @patch("construct_service_mac._write_ghostty_config_mac", return_value="/tmp/ghostty-matrix-3.conf")
    @patch("construct_service_mac.shutil.copy2")
    @patch("construct_service_mac.os.makedirs")
    def test_quick_launch_bonus_aurora(self, mock_mkdirs, mock_copy, mock_conf, mock_slot):
        from construct_service_mac import quick_launch
        result = quick_launch("aurora")
        assert result["slot"] == 3
        assert "error" not in result

    def test_quick_launch_unknown_color(self):
        from construct_service_mac import quick_launch
        with patch("construct_service_mac.find_next_slot_mac", return_value=1):
            result = quick_launch("neon-pink")
            assert "error" in result


class TestTransitionToRainMac:
    """Test transition_to_rain_mac uses SIGHUP reload instead of D-Bus."""

    @patch("construct_service_mac.reload_ghostty_mac")
    @patch("construct_service_mac.get_ghostty_pids", return_value={1: {"pid": 1234}})
    @patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/matrix-shaders/matrix-1.glsl")
    def test_uses_sighup_reload(self, mock_create, mock_pids, mock_reload):
        from construct_service_mac import transition_to_rain_mac

        # Create temp config file for test
        conf = "/tmp/ghostty-matrix-1.conf"
        with open(conf, "w") as f:
            f.write("custom-shader = /tmp/white-room.glsl\nbackground-opacity = 1.0\n")

        result = transition_to_rain_mac(1, 0)
        assert result is True
        mock_reload.assert_called_once_with(1234)

        # Cleanup
        os.unlink(conf)

    @patch("construct_service_mac.reload_ghostty_mac")
    @patch("construct_service_mac.get_ghostty_pids", return_value={})
    @patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/matrix-shaders/matrix-1.glsl")
    def test_no_reload_if_no_pids(self, mock_create, mock_pids, mock_reload):
        from construct_service_mac import transition_to_rain_mac

        conf = "/tmp/ghostty-matrix-1.conf"
        with open(conf, "w") as f:
            f.write("custom-shader = /tmp/white-room.glsl\nbackground-opacity = 1.0\n")

        result = transition_to_rain_mac(1, 0)
        assert result is True
        mock_reload.assert_not_called()

        os.unlink(conf)

    def test_returns_false_if_no_config(self):
        from construct_service_mac import transition_to_rain_mac
        # No config file at slot 99
        with patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/x.glsl"):
            result = transition_to_rain_mac(99, 0)
            assert result is False


class TestGhosttyConfigMac:
    """Test Mac-specific Ghostty config uses Mac font and titlebar."""

    @patch("construct_service_mac.find_next_slot_mac", return_value=1)
    @patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/matrix-shaders/matrix-1.glsl")
    def test_config_uses_macos_titlebar(self, mock_create, mock_slot):
        from construct_service_mac import quick_launch
        result = quick_launch("green")
        conf_path = result["conf"]
        with open(conf_path) as f:
            content = f.read()
        assert "macos-titlebar-style" in content

    @patch("construct_service_mac.find_next_slot_mac", return_value=1)
    @patch("construct_service_mac.shader_service.create_slot_shader", return_value="/tmp/matrix-shaders/matrix-1.glsl")
    def test_config_no_gtk_titlebar(self, mock_create, mock_slot):
        from construct_service_mac import quick_launch
        result = quick_launch("green")
        conf_path = result["conf"]
        with open(conf_path) as f:
            content = f.read()
        assert "gtk-titlebar" not in content


class TestConstructMacShFlags:
    """Test construct_mac.sh parses the same flags as Linux."""

    def _read_script(self):
        path = os.path.join(os.path.dirname(__file__), "..", "construct_mac.sh")
        if not os.path.exists(path):
            pytest.skip("construct_mac.sh not yet created")
        with open(path) as f:
            return f.read()

    def test_has_green_flag(self):
        content = self._read_script()
        assert "--green" in content

    def test_has_aurora_flag(self):
        content = self._read_script()
        assert "--aurora" in content

    def test_has_pick_flag(self):
        content = self._read_script()
        assert "--pick" in content

    def test_has_help_flag(self):
        content = self._read_script()
        assert "--help" in content

    def test_has_all_color_flags(self):
        content = self._read_script()
        for flag in ["--green", "--red", "--blue", "--purple", "--gold", "--teal"]:
            assert flag in content, f"Missing flag: {flag}"

    def test_has_all_bonus_flags(self):
        content = self._read_script()
        for flag in ["--aurora", "--aurora-rain", "--fireplace",
                     "--codevision", "--ultra", "--rain-on-glass"]:
            assert flag in content, f"Missing bonus flag: {flag}"

    def test_uses_mac_ghostty_detection(self):
        content = self._read_script()
        assert "/Applications/Ghostty.app" in content

    def test_no_linux_ghostty_path(self):
        content = self._read_script()
        assert "ghostty-build/zig-out" not in content

    def test_calls_command_banner(self):
        content = self._read_script()
        assert "command_banner" in content
