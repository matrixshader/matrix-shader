"""Tests for command_banner.py -- command reference banner shown on CLI exit."""
import io
import os
import sys
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


class TestCommandBanner:
    """Command banner output matches Windows ShowCommandBanner format."""

    def _capture_banner(self):
        """Capture show_command_banner() stdout output."""
        from command_banner import show_command_banner
        captured = io.StringIO()
        with patch("sys.stdout", captured):
            show_command_banner()
        return captured.getvalue()

    def test_banner_contains_all_5_commands(self):
        output = self._capture_banner()
        for cmd in ["wakeupneo", "construct", "bluepill", "redpill", "matrixlite"]:
            assert cmd in output, f"Missing command: {cmd}"

    def test_command_names_use_green_ansi(self):
        """Command names use #35B381 green via 24-bit ANSI escape."""
        output = self._capture_banner()
        # \033[38;2;53;179;129m is the 24-bit color for #35B381
        assert "\033[38;2;53;179;129m" in output

    def test_descriptions_use_dim_ansi(self):
        """Descriptions use dim ANSI escape."""
        output = self._capture_banner()
        assert "\033[2m" in output

    def test_banner_starts_with_blank_line_and_header(self):
        """Banner starts with blank line and COMMANDS header in dim."""
        output = self._capture_banner()
        lines = output.split("\n")
        # First line is blank (from print())
        assert lines[0].strip() == ""
        # Second line contains "COMMANDS"
        assert "COMMANDS" in lines[1]

    def test_banner_header_is_dim(self):
        """COMMANDS header uses dim ANSI."""
        output = self._capture_banner()
        lines = output.split("\n")
        header_line = lines[1]
        assert "\033[2m" in header_line
        assert "COMMANDS" in header_line

    def test_output_format_matches_windows(self):
        """Output matches Windows ShowCommandBanner format exactly."""
        output = self._capture_banner()
        # Verify each command has a description
        assert "Start here" in output
        assert "Launch individual Matrix terminal" in output
        assert "Quickly relaunch last saved settings" in output
        assert "Full control panel" in output
        assert "Visual effect only" in output

    def test_module_runnable_as_script(self):
        """command_banner.py can be run as __main__."""
        import subprocess
        result = subprocess.run(
            [sys.executable, os.path.join(os.path.dirname(__file__), "..", "command_banner.py")],
            capture_output=True, text=True, timeout=5,
        )
        assert result.returncode == 0
        assert "COMMANDS" in result.stdout
        assert "wakeupneo" in result.stdout
