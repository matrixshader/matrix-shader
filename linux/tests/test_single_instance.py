"""Tests for single-instance guard in matrix_keys.py."""

import fcntl
import os
import subprocess
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Ensure hotkey_config has all names matrix_keys expects (may be mocked by other tests)
if "hotkey_config" in sys.modules:
    from unittest.mock import MagicMock
    hc = sys.modules["hotkey_config"]
    for attr in ("CONFIG_PATH", "InotifyWatcher", "build_hotkey_table", "is_redpill", "load_config"):
        if not hasattr(hc, attr):
            setattr(hc, attr, MagicMock())

import matrix_keys


@pytest.fixture
def pid_path(tmp_path):
    """Provide a temporary PID file path and reset module state after test."""
    path = str(tmp_path / "test-matrix-keys.pid")
    original_pidfile = matrix_keys.PIDFILE
    original_lock_fd = matrix_keys._lock_fd
    matrix_keys.PIDFILE = path
    matrix_keys._lock_fd = None
    yield path
    # Cleanup: release any lock we hold
    matrix_keys.release_single_instance()
    matrix_keys.PIDFILE = original_pidfile
    matrix_keys._lock_fd = original_lock_fd


class TestAcquire:
    def test_acquire_writes_pid(self, pid_path):
        """acquire_single_instance writes our PID to the file."""
        assert matrix_keys.acquire_single_instance() is True
        with open(pid_path) as f:
            assert int(f.read().strip()) == os.getpid()

    def test_acquire_twice_in_subprocess_fails(self, pid_path):
        """A second process cannot acquire the lock while the first holds it."""
        assert matrix_keys.acquire_single_instance() is True

        # Try to acquire from a child process
        result = subprocess.run(
            [
                sys.executable, "-c",
                f"""
import fcntl, os, sys
try:
    fd = open({pid_path!r}, "w")
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    print("acquired")
except (IOError, OSError):
    print("blocked")
"""
            ],
            capture_output=True, text=True, timeout=5,
        )
        assert result.stdout.strip() == "blocked"


class TestRelease:
    def test_release_cleans_up(self, pid_path):
        """release_single_instance removes the PID file."""
        matrix_keys.acquire_single_instance()
        assert os.path.exists(pid_path)
        matrix_keys.release_single_instance()
        assert not os.path.exists(pid_path)

    def test_acquire_after_release(self, pid_path):
        """Can re-acquire after releasing."""
        assert matrix_keys.acquire_single_instance() is True
        matrix_keys.release_single_instance()
        assert matrix_keys.acquire_single_instance() is True


class TestStalePid:
    def test_stale_pid_file_overwritten(self, pid_path):
        """A stale PID file (no lock held) is overwritten by acquire."""
        # Write a fake PID without holding a lock
        with open(pid_path, "w") as f:
            f.write("99999999")

        assert matrix_keys.acquire_single_instance() is True
        with open(pid_path) as f:
            assert int(f.read().strip()) == os.getpid()
