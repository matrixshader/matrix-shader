"""Tests for macOS platform abstraction (platform_mac.py).

Tests Ghostty binary discovery, PID detection, reload, toast, positioning.
All macOS calls (osascript, signal, ctypes) are mocked.
"""

import os
import signal
import subprocess
import sys
from unittest.mock import MagicMock, patch, call

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "linux"))

import platform_mac as pm


# ---------------------------------------------------------------------------
# Ghostty binary discovery
# ---------------------------------------------------------------------------

class TestGetGhosttyBin:
    """Test get_ghostty_bin search paths."""

    @patch("os.access", return_value=True)
    @patch("os.path.isfile", return_value=True)
    def test_finds_applications_path(self, mock_isfile, mock_access):
        result = pm.get_ghostty_bin()
        assert "ghostty" in result.lower()

    @patch("os.access", return_value=False)
    @patch("os.path.isfile", return_value=False)
    @patch("subprocess.run")
    def test_falls_back_to_which(self, mock_run, mock_isfile, mock_access):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="/usr/local/bin/ghostty\n"
        )
        result = pm.get_ghostty_bin()
        assert result == "/usr/local/bin/ghostty"

    @patch("os.access", return_value=False)
    @patch("os.path.isfile", return_value=False)
    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_returns_fallback(self, mock_run, mock_isfile, mock_access):
        result = pm.get_ghostty_bin()
        assert result == "ghostty"

    @patch("os.access", return_value=False)
    @patch("os.path.isfile", return_value=False)
    @patch("subprocess.run")
    def test_which_not_found(self, mock_run, mock_isfile, mock_access):
        mock_run.return_value = MagicMock(returncode=1, stdout="")
        result = pm.get_ghostty_bin()
        assert result == "ghostty"

    @patch("os.access", return_value=False)
    @patch("os.path.isfile", return_value=False)
    @patch("subprocess.run", side_effect=subprocess.TimeoutExpired("which", 3))
    def test_which_timeout(self, mock_run, mock_isfile, mock_access):
        result = pm.get_ghostty_bin()
        assert result == "ghostty"

    def test_search_paths_are_absolute(self):
        for path in pm._GHOSTTY_SEARCH_PATHS:
            # After expansion, should start with /
            expanded = os.path.expanduser(path)
            assert expanded.startswith("/"), f"Path not absolute: {path}"


# ---------------------------------------------------------------------------
# Ghostty process discovery
# ---------------------------------------------------------------------------

class TestGetGhosttyPids:
    """Test get_ghostty_pids slot-to-PID mapping."""

    @patch("subprocess.run")
    def test_parses_ps_output(self, mock_run):
        mock_run.return_value = MagicMock(
            stdout=(
                "  PID ARGS\n"
                " 1234 /Applications/Ghostty.app/Contents/MacOS/ghostty --config-file=/tmp/ghostty-matrix-1\n"
                " 5678 /Applications/Ghostty.app/Contents/MacOS/ghostty --config-file=/tmp/ghostty-matrix-2\n"
                "  999 /usr/bin/vim\n"
            )
        )
        mapping = pm.get_ghostty_pids()
        assert mapping == {1: {"pid": 1234}, 2: {"pid": 5678}}

    @patch("subprocess.run")
    def test_empty_ps_output(self, mock_run):
        mock_run.return_value = MagicMock(stdout="  PID ARGS\n")
        assert pm.get_ghostty_pids() == {}

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_ps_not_found(self, mock_run):
        assert pm.get_ghostty_pids() == {}

    @patch("subprocess.run", side_effect=subprocess.TimeoutExpired("ps", 5))
    def test_ps_timeout(self, mock_run):
        assert pm.get_ghostty_pids() == {}

    @patch("subprocess.run")
    def test_ignores_non_ghostty_lines(self, mock_run):
        mock_run.return_value = MagicMock(
            stdout=(
                " 100 bash\n"
                " 200 python3 matrix_keys_mac.py\n"
                " 300 ghostty --config-file=/tmp/ghostty-matrix-3\n"
            )
        )
        mapping = pm.get_ghostty_pids()
        assert len(mapping) == 1
        assert mapping[3]["pid"] == 300

    @patch("subprocess.run")
    def test_handles_high_slot_numbers(self, mock_run):
        mock_run.return_value = MagicMock(
            stdout=" 1000 ghostty --config-file=/tmp/ghostty-matrix-8\n"
        )
        mapping = pm.get_ghostty_pids()
        assert mapping[8]["pid"] == 1000

    @patch("subprocess.run")
    def test_skips_malformed_lines(self, mock_run):
        mock_run.return_value = MagicMock(
            stdout=(
                "ghostty-matrix-1\n"  # no PID
                "  abc ghostty-matrix-2\n"  # non-integer PID
                " 100 ghostty-matrix-3\n"
            )
        )
        mapping = pm.get_ghostty_pids()
        assert len(mapping) == 1
        assert 3 in mapping


# ---------------------------------------------------------------------------
# Config reload
# ---------------------------------------------------------------------------

class TestReloadGhosttyMac:
    """Test reload_ghostty_mac via SIGHUP."""

    @patch("os.kill")
    def test_reload_by_signal(self, mock_kill):
        assert pm.reload_ghostty_mac(1234) is True
        mock_kill.assert_called_once_with(1234, signal.SIGHUP)

    @patch.object(pm, "_reload_by_osascript", return_value=True)
    @patch("os.kill", side_effect=ProcessLookupError)
    def test_falls_back_to_osascript(self, mock_kill, mock_osa):
        assert pm.reload_ghostty_mac(99999) is True
        mock_osa.assert_called_once()

    @patch.object(pm, "_reload_by_osascript", return_value=False)
    @patch("os.kill", side_effect=PermissionError)
    def test_osascript_fallback_fails(self, mock_kill, mock_osa):
        assert pm.reload_ghostty_mac(1) is False

    @patch.object(pm, "get_ghostty_pids")
    def test_reload_all_no_pid(self, mock_pids):
        mock_pids.return_value = {}
        assert pm.reload_ghostty_mac(None) is False

    @patch.object(pm, "_reload_by_signal", return_value=True)
    @patch.object(pm, "get_ghostty_pids")
    def test_reload_all_with_pids(self, mock_pids, mock_signal):
        mock_pids.return_value = {1: {"pid": 100}, 2: {"pid": 200}}
        assert pm.reload_ghostty_mac(None) is True
        assert mock_signal.call_count == 2


class TestReloadByOsascript:
    """Test _reload_by_osascript fallback."""

    @patch("subprocess.run")
    def test_success(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        assert pm._reload_by_osascript() is True

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_no_osascript(self, mock_run):
        assert pm._reload_by_osascript() is False

    @patch("subprocess.run", side_effect=subprocess.TimeoutExpired("osascript", 5))
    def test_timeout(self, mock_run):
        assert pm._reload_by_osascript() is False


# ---------------------------------------------------------------------------
# Toast notifications
# ---------------------------------------------------------------------------

class TestShowToastMac:
    """Test show_toast_mac notification."""

    @patch("subprocess.Popen")
    def test_sends_notification(self, mock_popen):
        pm.show_toast_mac("Hello", "Matrix")
        mock_popen.assert_called_once()
        args = mock_popen.call_args[0][0]
        assert args[0] == "osascript"

    @patch("subprocess.Popen")
    def test_escapes_quotes(self, mock_popen):
        pm.show_toast_mac('He said "hi"', 'Title "x"')
        mock_popen.assert_called_once()
        script = mock_popen.call_args[0][0][2]
        assert '\\"' in script

    @patch("subprocess.Popen", side_effect=FileNotFoundError)
    def test_no_osascript_no_crash(self, mock_popen):
        # Should not raise
        pm.show_toast_mac("msg")

    @patch("subprocess.Popen")
    def test_default_title(self, mock_popen):
        pm.show_toast_mac("body only")
        script = mock_popen.call_args[0][0][2]
        assert "Matrix Shader" in script


# ---------------------------------------------------------------------------
# Window positioning
# ---------------------------------------------------------------------------

class TestPositionWindowPlatform:
    """Test position_window in platform_mac."""

    @patch("subprocess.run")
    def test_success(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        assert pm.position_window(1234, 100, 200, 800, 600) is True

    @patch("subprocess.run")
    def test_failure(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1)
        assert pm.position_window(1234, 0, 0, 800, 600) is False

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_no_osascript(self, mock_run):
        assert pm.position_window(1234, 0, 0, 800, 600) is False

    @patch("subprocess.run", side_effect=subprocess.TimeoutExpired("osascript", 5))
    def test_timeout(self, mock_run):
        assert pm.position_window(1234, 0, 0, 800, 600) is False

    @patch("subprocess.run")
    def test_script_contains_coordinates(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        pm.position_window(42, 100, 200, 1920, 1080)
        script = mock_run.call_args[0][0][2]
        assert "42" in script
        assert "{100, 200}" in script
        assert "{1920, 1080}" in script


# ---------------------------------------------------------------------------
# Screen size
# ---------------------------------------------------------------------------

class TestGetScreenSize:
    """Test get_screen_size."""

    @patch("subprocess.run")
    def test_parses_dimensions(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="2560,1440\n"
        )
        w, h = pm.get_screen_size()
        assert w == 2560
        assert h == 1440

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_fallback(self, mock_run):
        w, h = pm.get_screen_size()
        assert (w, h) == (1920, 1080)

    @patch("subprocess.run")
    def test_bad_output_fallback(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="garbage")
        w, h = pm.get_screen_size()
        assert (w, h) == (1920, 1080)

    @patch("subprocess.run")
    def test_nonzero_return(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stdout="")
        w, h = pm.get_screen_size()
        assert (w, h) == (1920, 1080)


# ---------------------------------------------------------------------------
# Accessibility permission
# ---------------------------------------------------------------------------

class TestCheckAccessibilityPermission:
    """Test check_accessibility_permission."""

    def test_returns_false_on_linux(self):
        # We're running on linux, so sys.platform != "darwin"
        assert pm.check_accessibility_permission() is False

    @patch("sys.platform", "darwin")
    def test_returns_true_on_darwin_with_permission(self):
        mock_lib = MagicMock()
        mock_lib.AXIsProcessTrusted.return_value = True
        with patch("ctypes.cdll.LoadLibrary", return_value=mock_lib):
            assert pm.check_accessibility_permission() is True

    @patch("sys.platform", "darwin")
    def test_returns_false_on_darwin_without_permission(self):
        mock_lib = MagicMock()
        mock_lib.AXIsProcessTrusted.return_value = False
        with patch("ctypes.cdll.LoadLibrary", return_value=mock_lib):
            assert pm.check_accessibility_permission() is False

    @patch("sys.platform", "darwin")
    def test_returns_false_on_load_error(self):
        with patch("ctypes.cdll.LoadLibrary", side_effect=OSError):
            assert pm.check_accessibility_permission() is False


class TestRequestAccessibilityPermission:
    """Test request_accessibility_permission."""

    @patch("subprocess.Popen")
    def test_opens_settings(self, mock_popen):
        pm.request_accessibility_permission()
        mock_popen.assert_called_once()
        args = mock_popen.call_args[0][0]
        assert args[0] == "open"
        assert "Accessibility" in args[1]

    @patch("subprocess.Popen", side_effect=FileNotFoundError)
    def test_no_open_command(self, mock_popen):
        # Should not raise
        pm.request_accessibility_permission()
