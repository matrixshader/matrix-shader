"""Tests for uninstaller, version comparison, and desktop notifications.

Phase 10 Plan 02 — INST-01/02/03.
"""

import os
import sys
import subprocess
import textwrap
from unittest.mock import patch, MagicMock, call

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


class TestUninstaller:
    """Tests that uninstall.sh removes the right things."""

    def test_script_exists_and_executable(self):
        script = os.path.join(os.path.dirname(__file__), '..', 'uninstall.sh')
        assert os.path.isfile(script)
        assert os.access(script, os.X_OK)

    def test_script_syntax_valid(self):
        script = os.path.join(os.path.dirname(__file__), '..', 'uninstall.sh')
        result = subprocess.run(['bash', '-n', script], capture_output=True, text=True)
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_kills_matrix_processes(self):
        script = os.path.join(os.path.dirname(__file__), '..', 'uninstall.sh')
        with open(script) as f:
            content = f.read()
        # Should kill ghostty, matrix_keys, matrix_watchdog, redpill, matrixlite, bluepill
        for proc in ['ghostty', 'matrix_keys', 'matrix_watchdog', 'redpill', 'matrixlite', 'bluepill']:
            assert proc in content, f"Should kill {proc}"

    def test_removes_install_dir(self):
        script = os.path.join(os.path.dirname(__file__), '..', 'uninstall.sh')
        with open(script) as f:
            content = f.read()
        assert 'INSTALL_DIR' in content
        assert 'rm -rf' in content

    def test_removes_bin_commands(self):
        script = os.path.join(os.path.dirname(__file__), '..', 'uninstall.sh')
        with open(script) as f:
            content = f.read()
        for cmd in ['wakeupneo', 'bluepill', 'redpill', 'matrixlite', 'uninstall-matrix']:
            assert cmd in content, f"Should remove {cmd}"

    def test_removes_gnome_extension(self):
        script = os.path.join(os.path.dirname(__file__), '..', 'uninstall.sh')
        with open(script) as f:
            content = f.read()
        assert 'gnome-shell/extensions' in content or 'GNOME_EXT_DIR' in content


class TestPathCleanup:
    """Tests for PATH block removal from shell rc files."""

    def _run_sed_cleanup(self, rc_content, tmp_path):
        """Write content to a temp rc file, run the sed pattern, return result."""
        rc_file = tmp_path / ".bashrc"
        rc_file.write_text(rc_content)
        # The exact sed pattern from uninstall.sh
        subprocess.run(
            ['sed', '-i', '/^# Matrix Shader$/,/^export PATH.*\\.local\\/bin/d', str(rc_file)],
            check=True
        )
        return rc_file.read_text()

    def test_removes_matrix_shader_block(self, tmp_path):
        rc = textwrap.dedent("""\
            # existing stuff
            alias ll='ls -la'

            # Matrix Shader
            export PATH="$HOME/.local/bin:$PATH"

            # other stuff
            export EDITOR=vim
        """)
        result = self._run_sed_cleanup(rc, tmp_path)
        assert '# Matrix Shader' not in result
        assert 'alias ll' in result
        assert 'EDITOR=vim' in result

    def test_removes_multiple_blocks(self, tmp_path):
        rc = textwrap.dedent("""\
            # Matrix Shader
            export PATH="$HOME/.local/bin:$PATH"

            # Matrix Shader
            export PATH="$HOME/.local/bin:$PATH"

            alias foo=bar
        """)
        result = self._run_sed_cleanup(rc, tmp_path)
        assert '# Matrix Shader' not in result
        assert 'alias foo=bar' in result

    def test_no_modification_without_block(self, tmp_path):
        rc = "alias ll='ls -la'\nexport EDITOR=vim\n"
        result = self._run_sed_cleanup(rc, tmp_path)
        assert result == rc


class TestVersionCompare:
    """Tests for version_gt() shell function (sort -V based)."""

    def _version_gt(self, v1, v2):
        """Run the same version_gt logic as in install.sh via bash."""
        script = f'''
            version_gt() {{
                [ "$(printf '%s\\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
            }}
            version_gt "{v1}" "{v2}" && echo "true" || echo "false"
        '''
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        return result.stdout.strip() == "true"

    def test_newer_patch(self):
        assert self._version_gt("1.0.4", "1.0.3") is True

    def test_equal_versions(self):
        assert self._version_gt("1.0.3", "1.0.3") is False

    def test_older_version(self):
        assert self._version_gt("1.0.3", "1.0.4") is False

    def test_numeric_not_lexicographic(self):
        assert self._version_gt("1.0.10", "1.0.9") is True

    def test_major_version_bump(self):
        assert self._version_gt("2.0.0", "1.9.9") is True


class TestNotification:
    """Tests for desktop notification after window launch."""

    def test_notify_send_call(self):
        """notify_matrix_running() should call notify-send with correct args."""
        from installer_helpers import notify_matrix_running
        with patch('subprocess.run') as mock_run:
            notify_matrix_running(3)
            mock_run.assert_called_once()
            args = mock_run.call_args[0][0]
            assert args[0] == 'notify-send'
            assert '--app-name=Matrix Shader' in args
            assert '--expire-time=5000' in args

    def test_notify_includes_window_count(self):
        from installer_helpers import notify_matrix_running
        with patch('subprocess.run') as mock_run:
            notify_matrix_running(5)
            args = mock_run.call_args[0][0]
            body = args[-1]
            assert '5' in body

    def test_notify_handles_missing_notify_send(self):
        from installer_helpers import notify_matrix_running
        with patch('subprocess.run', side_effect=FileNotFoundError):
            # Should not raise
            notify_matrix_running(1)
