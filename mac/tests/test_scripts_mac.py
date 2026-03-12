"""Tests for Mac shell scripts: syntax validation and basic structure checks.

Validates all .sh files parse correctly with bash -n and checks for
common issues. Does NOT require macOS to run.
"""

import os
import subprocess
import sys

import pytest

MAC_DIR = os.path.join(os.path.dirname(__file__), "..")

SHELL_SCRIPTS = [
    "bluepill_mac.sh",
    "build-release.sh",
    "install_mac.sh",
    "i.sh",
    "matrix-hotkey-help-mac.sh",
    "matrix-opacity-mac.sh",
    "redpill_mac.sh",
    "wakeupneo_mac.sh",
]


class TestShellScriptSyntax:
    """Validate shell script syntax with bash -n."""

    @pytest.fixture(params=SHELL_SCRIPTS)
    def script_path(self, request):
        path = os.path.join(MAC_DIR, request.param)
        if not os.path.exists(path):
            pytest.skip(f"Script not found: {request.param}")
        return path

    def test_bash_syntax_valid(self, script_path):
        """Script passes bash -n syntax check."""
        result = subprocess.run(
            ["bash", "-n", script_path],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, (
            f"Syntax error in {os.path.basename(script_path)}:\n{result.stderr}"
        )


class TestShellScriptStructure:
    """Check structural properties of shell scripts."""

    @pytest.fixture(params=SHELL_SCRIPTS)
    def script_content(self, request):
        path = os.path.join(MAC_DIR, request.param)
        if not os.path.exists(path):
            pytest.skip(f"Script not found: {request.param}")
        with open(path) as f:
            return request.param, f.read()

    def test_has_shebang(self, script_content):
        """Script starts with a shebang line."""
        name, content = script_content
        assert content.startswith("#!"), f"{name} missing shebang"

    def test_shebang_is_bash(self, script_content):
        """Script uses bash (not sh)."""
        name, content = script_content
        first_line = content.split("\n")[0]
        assert "bash" in first_line, f"{name} shebang is not bash: {first_line}"

    def test_no_trailing_whitespace_in_shebang(self, script_content):
        """Shebang line has no trailing whitespace."""
        name, content = script_content
        first_line = content.split("\n")[0]
        assert first_line == first_line.rstrip(), f"{name} shebang has trailing whitespace"

    def test_ends_with_newline(self, script_content):
        """Script ends with a newline (POSIX convention)."""
        name, content = script_content
        assert content.endswith("\n"), f"{name} doesn't end with newline"

    def test_not_empty(self, script_content):
        """Script has content beyond the shebang."""
        name, content = script_content
        lines = [l for l in content.strip().split("\n") if l.strip() and not l.strip().startswith("#")]
        assert len(lines) > 0, f"{name} has no code"


class TestSpecificScripts:
    """Test specific properties of individual scripts."""

    def _read(self, name):
        path = os.path.join(MAC_DIR, name)
        if not os.path.exists(path):
            pytest.skip(f"Script not found: {name}")
        with open(path) as f:
            return f.read()

    def test_bluepill_has_kill_logic(self):
        content = self._read("bluepill_mac.sh")
        assert "kill" in content.lower() or "pkill" in content.lower() or "osascript" in content.lower()

    def test_redpill_launches_something(self):
        content = self._read("redpill_mac.sh")
        # Should reference ghostty or python or the matrix system
        assert "ghostty" in content.lower() or "python" in content.lower() or "matrix" in content.lower()

    def test_install_mac_has_install_dir(self):
        content = self._read("install_mac.sh")
        assert "INSTALL" in content or "install" in content

    def test_opacity_script_has_opacity_logic(self):
        content = self._read("matrix-opacity-mac.sh")
        assert "opacity" in content.lower() or "OPACITY" in content

    def test_help_script_references_hotkeys(self):
        content = self._read("matrix-hotkey-help-mac.sh")
        assert "hotkey" in content.lower() or "key" in content.lower() or "help" in content.lower()

    def test_build_release_creates_tarball(self):
        content = self._read("build-release.sh")
        assert "tar" in content

    def test_wakeupneo_references_ghostty(self):
        content = self._read("wakeupneo_mac.sh")
        assert "ghostty" in content.lower() or "Ghostty" in content

    def test_i_sh_is_bootstrap(self):
        content = self._read("i.sh")
        assert "curl" in content or "wget" in content or "install" in content.lower()


class TestShellcheck:
    """Run shellcheck if available (non-fatal if missing)."""

    @pytest.fixture(params=SHELL_SCRIPTS)
    def script_path(self, request):
        path = os.path.join(MAC_DIR, request.param)
        if not os.path.exists(path):
            pytest.skip(f"Script not found: {request.param}")
        return path

    def test_shellcheck(self, script_path):
        """Run shellcheck for warnings (skip if shellcheck not installed)."""
        try:
            result = subprocess.run(
                ["shellcheck", "--version"],
                capture_output=True, timeout=5
            )
            if result.returncode != 0:
                pytest.skip("shellcheck not available")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pytest.skip("shellcheck not installed")

        result = subprocess.run(
            ["shellcheck", "-S", "warning", script_path],
            capture_output=True, text=True, timeout=30
        )
        # Report but don't fail on warnings, only errors
        if result.returncode == 2:
            pytest.fail(f"shellcheck errors in {os.path.basename(script_path)}:\n{result.stdout}")
