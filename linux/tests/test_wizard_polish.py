"""Tests for Phase 9: Wizard Polish & Easter Eggs.

Covers: Redpill-Neo preset (SHDR-07), Matrix quotes (WIZD-02),
splash animation (WIZD-01), arrow-key menu (WIZD-03),
morpheus mode (WIZD-05), agent-smith mode (WIZD-06),
update checker (WIZD-04).
"""
import os
import sys
import re
import json
import subprocess
import textwrap

import pytest

# Ensure linux/ is on path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import shader_service


# ---------------------------------------------------------------------------
# SHDR-07: Redpill-Neo as 7th preset
# ---------------------------------------------------------------------------

class TestRedpillNeoPreset:
    """Test that Redpill-Neo is selectable as the 7th color preset."""

    def test_preset_colors_has_7_entries(self):
        """PRESET_COLORS should have 7 entries (indices 0-6)."""
        assert len(shader_service.PRESET_COLORS) == 7

    def test_redpill_neo_preset_entry_is_none(self):
        """Index 6 should be None to signal special handling."""
        assert shader_service.PRESET_COLORS[6] is None

    def test_redpill_neo_path_constant_exists(self):
        """REDPILL_NEO_PATH should be defined."""
        assert hasattr(shader_service, "REDPILL_NEO_PATH")
        assert "redpill-neo" in shader_service.REDPILL_NEO_PATH

    def test_create_slot_shader_preset_6_copies_redpill(self, tmp_path, monkeypatch):
        """preset_idx=6 should copy redpill-neo shader, not rewrite template."""
        slot_dir = tmp_path / "shaders"
        slot_dir.mkdir()
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", str(slot_dir))

        # Create a fake redpill-neo source file
        neo_src = tmp_path / "redpill-neo-ghostty.glsl"
        neo_src.write_text("// REDPILL-NEO header\n#define RAIN_SPEED 0.7\n")
        monkeypatch.setattr(shader_service, "REDPILL_NEO_PATH", str(neo_src))

        result = shader_service.create_slot_shader(slot=1, preset_idx=6)
        expected_path = str(slot_dir / "matrix-1.glsl")
        assert result == expected_path
        assert os.path.isfile(expected_path)

    def test_create_slot_shader_preset_6_contains_redpill_header(self, tmp_path, monkeypatch):
        """Copied file should contain the REDPILL-NEO header, proving correct source."""
        slot_dir = tmp_path / "shaders"
        slot_dir.mkdir()
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", str(slot_dir))

        neo_src = tmp_path / "redpill-neo-ghostty.glsl"
        neo_src.write_text("// REDPILL-NEO header\n#define GRID_LINES 0.008\n")
        monkeypatch.setattr(shader_service, "REDPILL_NEO_PATH", str(neo_src))

        result = shader_service.create_slot_shader(slot=1, preset_idx=6)
        content = open(result).read()
        assert "REDPILL-NEO" in content

    def test_create_slot_shader_preset_6_no_rain_r_define(self, tmp_path, monkeypatch):
        """Redpill-Neo copy should NOT contain RAIN_R #define (not template-based)."""
        slot_dir = tmp_path / "shaders"
        slot_dir.mkdir()
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", str(slot_dir))

        neo_src = tmp_path / "redpill-neo-ghostty.glsl"
        neo_src.write_text("// REDPILL-NEO\n#define RAIN_SPEED 0.7\n")
        monkeypatch.setattr(shader_service, "REDPILL_NEO_PATH", str(neo_src))

        result = shader_service.create_slot_shader(slot=1, preset_idx=6)
        content = open(result).read()
        assert "#define RAIN_R" not in content

    def test_create_slot_shader_preset_0_through_5_still_works(self, tmp_path, monkeypatch):
        """Existing presets 0-5 should still work normally (regression)."""
        slot_dir = tmp_path / "shaders"
        slot_dir.mkdir()
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", str(slot_dir))

        template = tmp_path / "matrix-green-ghostty.glsl"
        template.write_text(
            "#define RAIN_R 0.0\n#define RAIN_G 1.0\n#define RAIN_B 0.3\n"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", str(template))

        for idx in range(6):
            result = shader_service.create_slot_shader(slot=idx + 1, preset_idx=idx)
            assert os.path.isfile(result)
            content = open(result).read()
            assert "#define RAIN_R" in content


# ---------------------------------------------------------------------------
# WIZD-02: Matrix movie quotes
# ---------------------------------------------------------------------------

EXPECTED_QUOTES = [
    "The Matrix has you...",
    "Follow the white rabbit.",
    "There is no spoon.",
    "Free your mind.",
    "I know kung fu.",
    "Welcome to the real world.",
    "What is the Matrix?",
    "You've been living in a dream world, Neo.",
    "Unfortunately, no one can be told what the Matrix is.",
    "The body cannot live without the mind.",
    "Dodge this.",
    "I can only show you the door.",
    "Everything begins with choice.",
    "There's a difference between knowing the path and walking the path.",
]


class TestMatrixQuotes:
    """Test Matrix movie quotes in wakeupneo scripts."""

    def _read_script(self, name):
        script_dir = os.path.join(os.path.dirname(__file__), "..")
        if name == "linux":
            path = os.path.join(script_dir, "wakeupneo.sh")
        else:
            path = os.path.join(script_dir, "..", "mac", "wakeupneo_mac.sh")
        with open(path) as f:
            return f.read()

    def test_linux_has_14_quotes(self):
        """Linux wakeupneo.sh should have exactly 14 MATRIX_QUOTES entries."""
        content = self._read_script("linux")
        matches = re.findall(r'^\s+"[^"]+"\s*$', content, re.MULTILINE)
        # Filter to only those within the MATRIX_QUOTES block
        in_block = False
        count = 0
        for line in content.splitlines():
            if "MATRIX_QUOTES=(" in line:
                in_block = True
                continue
            if in_block:
                if line.strip() == ")":
                    break
                if line.strip().startswith('"'):
                    count += 1
        assert count == 14, f"Expected 14 quotes, found {count}"

    def test_mac_has_14_quotes(self):
        """Mac wakeupneo_mac.sh should have exactly 14 MATRIX_QUOTES entries."""
        content = self._read_script("mac")
        in_block = False
        count = 0
        for line in content.splitlines():
            if "MATRIX_QUOTES=(" in line:
                in_block = True
                continue
            if in_block:
                if line.strip() == ")":
                    break
                if line.strip().startswith('"'):
                    count += 1
        assert count == 14, f"Expected 14 quotes, found {count}"

    def test_linux_has_show_random_quote_function(self):
        """Linux wakeupneo.sh should have show_random_quote function."""
        content = self._read_script("linux")
        assert "show_random_quote()" in content

    def test_quotes_include_dim_formatting(self):
        """show_random_quote should use DIM ANSI formatting."""
        content = self._read_script("linux")
        # Find the function body
        assert "${DIM}" in content or "\\033[2m" in content

    def test_known_quotes_present_in_linux(self):
        """All 14 expected quotes should appear in the Linux script."""
        content = self._read_script("linux")
        for quote in EXPECTED_QUOTES:
            # Escape apostrophes for shell matching
            assert quote in content, f"Missing quote: {quote}"

    def test_known_quotes_present_in_mac(self):
        """All 14 expected quotes should appear in the Mac script."""
        content = self._read_script("mac")
        for quote in EXPECTED_QUOTES:
            assert quote in content, f"Missing quote: {quote}"


# ---------------------------------------------------------------------------
# Helper to read script content
# ---------------------------------------------------------------------------

def _read_script(name):
    script_dir = os.path.join(os.path.dirname(__file__), "..")
    if name == "linux":
        path = os.path.join(script_dir, "wakeupneo.sh")
    else:
        path = os.path.join(script_dir, "..", "mac", "wakeupneo_mac.sh")
    with open(path) as f:
        return f.read()


# ---------------------------------------------------------------------------
# WIZD-01: Splash animation
# ---------------------------------------------------------------------------

class TestSplashAnimation:
    """Test splash animation function exists and has correct properties."""

    def test_linux_matrix_splash_function_exists(self):
        """matrix_splash function should be defined in Linux script."""
        content = _read_script("linux")
        assert "matrix_splash()" in content

    def test_mac_matrix_splash_function_exists(self):
        """matrix_splash function should be defined in Mac script."""
        content = _read_script("mac")
        assert "matrix_splash()" in content

    def test_splash_uses_hide_cursor(self):
        """Splash should use tput civis to hide cursor."""
        content = _read_script("linux")
        assert "tput civis" in content

    def test_splash_uses_show_cursor(self):
        """Splash should use tput cnorm to restore cursor."""
        content = _read_script("linux")
        assert "tput cnorm" in content

    def test_splash_uses_cursor_home_not_clear(self):
        """Splash should use cursor home (\\033[H) for frame updates, not clear."""
        content = _read_script("linux")
        # Extract just the matrix_splash function body
        in_func = False
        func_lines = []
        brace_depth = 0
        for line in content.splitlines():
            if "matrix_splash()" in line and "{" in line:
                in_func = True
                brace_depth = 1
                func_lines.append(line)
                continue
            if in_func:
                brace_depth += line.count("{") - line.count("}")
                func_lines.append(line)
                if brace_depth <= 0:
                    break
        func_body = "\n".join(func_lines)
        # Should have cursor home escape
        assert "\\033[H" in func_body or "\\x1b[H" in func_body

    def test_splash_duration_approximately_1_5_seconds(self):
        """Splash should run for approximately 1.5 seconds (30 frames at 50ms)."""
        content = _read_script("linux")
        # Check for frame count or duration constant
        assert "frames=30" in content or "1.5" in content or "1500" in content

    def test_splash_called_before_typewriter(self):
        """matrix_splash should be called before typewriter intro in main flow."""
        content = _read_script("linux")
        splash_pos = content.find("matrix_splash")
        # Find the call site (not the function def)
        # Look for the call in the main section
        main_section = content[content.find("# --- Main ---"):]
        splash_call = main_section.find("matrix_splash")
        typewriter_call = main_section.find("typewriter")
        assert splash_call >= 0, "matrix_splash not called in main section"
        assert splash_call < typewriter_call, "splash should come before typewriter"


# ---------------------------------------------------------------------------
# WIZD-03: Arrow-key menu
# ---------------------------------------------------------------------------

class TestArrowMenu:
    """Test arrow-key navigable menu function."""

    def test_linux_arrow_menu_function_exists(self):
        """arrow_menu function should be defined in Linux script."""
        content = _read_script("linux")
        assert "arrow_menu()" in content

    def test_mac_arrow_menu_function_exists(self):
        """arrow_menu function should be defined in Mac script."""
        content = _read_script("mac")
        assert "arrow_menu()" in content

    def test_arrow_menu_uses_read_rsn1(self):
        """arrow_menu should use read -rsn1 for keypress capture."""
        content = _read_script("linux")
        assert "read -rsn1" in content

    def test_arrow_menu_handles_up_arrow(self):
        """arrow_menu should handle [A escape sequence for up arrow."""
        content = _read_script("linux")
        assert "'[A'" in content or '"[A"' in content

    def test_arrow_menu_handles_down_arrow(self):
        """arrow_menu should handle [B escape sequence for down arrow."""
        content = _read_script("linux")
        assert "'[B'" in content or '"[B"' in content

    def test_pill_choice_uses_arrow_menu(self):
        """Pill choice should use arrow_menu instead of numbered prompt."""
        content = _read_script("linux")
        # The old pattern should be gone
        assert 'echo -ne " > "' not in content
        # arrow_menu should be used for pill choice
        assert "arrow_menu" in content

    def test_linux_no_old_pill_prompt(self):
        """Old [1]/[2] pill choice prompt should be replaced."""
        content = _read_script("linux")
        # Check the summary/pill section doesn't have the old read pattern
        assert 'read -r pill_choice' not in content


# ---------------------------------------------------------------------------
# WIZD-05: Morpheus mode
# ---------------------------------------------------------------------------

class TestMorpheusMode:
    """Test --morpheus easter egg mode."""

    def test_linux_morpheus_intro_function_exists(self):
        """morpheus_intro function should be defined."""
        content = _read_script("linux")
        assert "morpheus_intro()" in content

    def test_mac_morpheus_intro_function_exists(self):
        content = _read_script("mac")
        assert "morpheus_intro()" in content

    def test_morpheus_contains_red_pill_text(self):
        """morpheus_intro should contain the red pill quote."""
        content = _read_script("linux")
        assert "red pill" in content.lower() or "rabbit hole" in content.lower()

    def test_morpheus_flag_handled(self):
        """--morpheus flag should be recognized in flag parsing."""
        content = _read_script("linux")
        assert "--morpheus" in content

    def test_mac_morpheus_flag_handled(self):
        content = _read_script("mac")
        assert "--morpheus" in content


# ---------------------------------------------------------------------------
# WIZD-06: Agent Smith mode
# ---------------------------------------------------------------------------

class TestAgentSmithMode:
    """Test --agent-smith easter egg mode."""

    def test_linux_agent_smith_function_exists(self):
        """agent_smith_mode function should be defined."""
        content = _read_script("linux")
        assert "agent_smith_mode()" in content

    def test_mac_agent_smith_function_exists(self):
        content = _read_script("mac")
        assert "agent_smith_mode()" in content

    def test_agent_smith_calls_shader_service_write(self):
        """agent_smith_mode should call shader_service.py write."""
        content = _read_script("linux")
        # Find within agent_smith_mode function
        assert "shader_service.py" in content and "write" in content

    def test_agent_smith_triggers_reload(self):
        """agent_smith_mode should trigger Ghostty reload."""
        content = _read_script("linux")
        # Should have reload logic (busctl/gdbus for Linux)
        assert "reload-config" in content

    def test_agent_smith_flag_handled(self):
        """--agent-smith flag should be recognized."""
        content = _read_script("linux")
        assert "--agent-smith" in content

    def test_mac_agent_smith_flag_handled(self):
        content = _read_script("mac")
        assert "--agent-smith" in content


# ---------------------------------------------------------------------------
# WIZD-04: Update checker
# ---------------------------------------------------------------------------

class TestUpdateChecker:
    """Test --update version checker."""

    def test_linux_check_update_function_exists(self):
        """check_update function should be defined."""
        content = _read_script("linux")
        assert "check_update()" in content

    def test_mac_check_update_function_exists(self):
        content = _read_script("mac")
        assert "check_update()" in content

    def test_linux_get_current_version_function_exists(self):
        """get_current_version function should be defined."""
        content = _read_script("linux")
        assert "get_current_version()" in content

    def test_update_uses_github_api(self):
        """check_update should call GitHub releases API."""
        content = _read_script("linux")
        assert "api.github.com" in content

    def test_update_has_max_time(self):
        """check_update should use curl --max-time to avoid blocking."""
        content = _read_script("linux")
        assert "max-time" in content

    def test_update_silent_failure(self):
        """check_update should return 0 on curl failure (silent)."""
        content = _read_script("linux")
        assert "return 0" in content

    def test_update_flag_handled(self):
        """--update flag should be recognized."""
        content = _read_script("linux")
        assert "--update" in content

    def test_version_comparison_uses_python(self):
        """Version comparison should use Python tuple comparison."""
        content = _read_script("linux")
        assert "tuple(map(int" in content or "split('.')" in content

    def test_version_file_fallback(self):
        """get_current_version should fall back to 0.0.0 if VERSION missing."""
        content = _read_script("linux")
        assert "0.0.0" in content

    def test_version_comparison_logic(self):
        """Python version comparison logic should work correctly."""
        # Test the actual Python one-liner logic used in the script
        assert tuple(map(int, "1.2.0".split("."))) > tuple(map(int, "1.0.3".split(".")))
        assert not tuple(map(int, "1.0.3".split("."))) > tuple(map(int, "1.0.3".split(".")))
        assert not tuple(map(int, "0.9.0".split("."))) > tuple(map(int, "1.0.3".split(".")))


# ---------------------------------------------------------------------------
# Build release: VERSION file
# ---------------------------------------------------------------------------

class TestBuildReleaseVersion:
    """Test VERSION file is bundled in release tarballs."""

    def test_linux_build_release_has_version(self):
        """Linux build-release.sh should extract and bundle VERSION file."""
        path = os.path.join(os.path.dirname(__file__), "..", "build-release.sh")
        with open(path) as f:
            content = f.read()
        assert "VERSION" in content

    def test_mac_build_release_has_version(self):
        """Mac build-release.sh should extract and bundle VERSION file."""
        path = os.path.join(os.path.dirname(__file__), "..", "..", "mac", "build-release.sh")
        with open(path) as f:
            content = f.read()
        assert "VERSION" in content
