"""Tests for matrix_watchdog.py — process monitoring and restart logic."""

import os
import sys
from unittest.mock import patch, MagicMock, mock_open

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from matrix_watchdog import is_process_alive, read_pid, start_matrix_keys


class TestIsProcessAlive:
    def test_self_is_alive(self):
        """Our own process should be alive."""
        assert is_process_alive(os.getpid()) is True

    def test_dead_pid(self):
        """A very high PID should not exist."""
        assert is_process_alive(99999999) is False

    def test_pid_zero(self):
        """PID 0 (kernel) should raise and return False for non-root."""
        # os.kill(0, 0) checks the calling process group, not PID 0
        # Use a PID that definitely doesn't exist
        assert is_process_alive(4194304) is False  # Above typical PID_MAX


class TestReadPid:
    def test_valid_pid(self, tmp_path):
        """Reads a valid PID from file."""
        pid_file = tmp_path / "test.pid"
        pid_file.write_text("12345\n")
        assert read_pid(str(pid_file)) == 12345

    def test_missing_file(self, tmp_path):
        """Returns None for nonexistent file."""
        assert read_pid(str(tmp_path / "nonexistent.pid")) is None

    def test_corrupt_file(self, tmp_path):
        """Returns None for non-numeric content."""
        pid_file = tmp_path / "bad.pid"
        pid_file.write_text("not-a-number\n")
        assert read_pid(str(pid_file)) is None

    def test_empty_file(self, tmp_path):
        """Returns None for empty file."""
        pid_file = tmp_path / "empty.pid"
        pid_file.write_text("")
        assert read_pid(str(pid_file)) is None


class TestStartMatrixKeys:
    @patch("matrix_watchdog.subprocess.Popen")
    def test_start_calls_popen(self, mock_popen):
        """start_matrix_keys launches matrix_keys.py via Popen."""
        mock_fh = MagicMock()
        with patch("builtins.open", return_value=mock_fh):
            result = start_matrix_keys()
        assert result is True
        mock_popen.assert_called_once()
        args = mock_popen.call_args
        assert "matrix_keys.py" in args[0][0][1]

    @patch("matrix_watchdog.subprocess.Popen", side_effect=FileNotFoundError("no python"))
    def test_start_handles_missing_python(self, mock_popen):
        """Returns False if the subprocess can't be started."""
        with patch("builtins.open", return_value=MagicMock()):
            result = start_matrix_keys()
        assert result is False
