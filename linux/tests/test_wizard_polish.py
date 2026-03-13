"""Tests for Phase 9: Wizard Polish & Easter Eggs.

Covers: Redpill-Neo preset (SHDR-07), Matrix quotes (WIZD-02),
splash animation (WIZD-01), arrow-key menu (WIZD-03),
morpheus mode (WIZD-05), agent-smith mode (WIZD-06),
update checker (WIZD-04).
"""
import os
import sys
import re
import subprocess

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
