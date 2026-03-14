"""Tests for construct CLI -- quick launch, white room, and transition.

Tests construct_service.py: find_next_slot, quick_launch, transition_to_rain,
color/bonus mappings, and help output.
"""

import os
import sys
import json
import tempfile
import textwrap
from pathlib import Path
from unittest.mock import patch, MagicMock, mock_open

import pytest

# Ensure linux/ is on the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import construct_service


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def isolate_env(tmp_path, monkeypatch):
    """Isolate file system and prevent real subprocess calls."""
    # Override slot shader dir to temp
    monkeypatch.setattr(construct_service, "SLOT_SHADER_DIR",
                        str(tmp_path / "shaders"))
    os.makedirs(tmp_path / "shaders", exist_ok=True)

    # Create a mock template shader for create_slot_shader
    template_dir = tmp_path / "shaders-glsl"
    template_dir.mkdir(parents=True, exist_ok=True)
    template_file = template_dir / "matrix-green-ghostty.glsl"
    template_file.write_text(
        "#define RAIN_R 0.0\n"
        "#define RAIN_G 1.0\n"
        "#define RAIN_B 0.3\n"
        "#define RAIN_SPEED 0.8\n"
    )

    # Also create bonus shader templates
    for name in construct_service.BONUS_SHADERS.values():
        (template_dir / name).write_text(f"// Bonus shader: {name}\nvoid mainImage(out vec4 c, in vec2 f) {{ c = vec4(1.0); }}\n")

    # Create white-room shader
    (template_dir / "white-room-ghostty.glsl").write_text(
        "#define STATE 1\n#define SELECTED 0\n#define STATE_TIME 0.0\nvoid mainImage(out vec4 c, in vec2 f) { c = vec4(1.0); }\n"
    )

    # Point TEMPLATE_PATH and related paths to temp
    monkeypatch.setattr(construct_service, "TEMPLATE_PATH",
                        str(template_file))

    # Set SHADER_SRC_DIR to point to our temp shaders-glsl
    monkeypatch.setattr(construct_service, "SHADER_SRC_DIR",
                        str(template_dir))

    return tmp_path


# ---------------------------------------------------------------------------
# Color and Bonus Mapping Tests
# ---------------------------------------------------------------------------

class TestColorMappings:
    """Test color name -> preset index mapping."""

    def test_green_maps_to_preset_0(self):
        assert construct_service.COLOR_MAP["green"] == 0

    def test_blue_maps_to_preset_1(self):
        assert construct_service.COLOR_MAP["blue"] == 1

    def test_red_maps_to_preset_2(self):
        assert construct_service.COLOR_MAP["red"] == 2

    def test_purple_maps_to_preset_3(self):
        assert construct_service.COLOR_MAP["purple"] == 3

    def test_gold_maps_to_preset_4(self):
        assert construct_service.COLOR_MAP["gold"] == 4

    def test_teal_maps_to_preset_5(self):
        assert construct_service.COLOR_MAP["teal"] == 5

    def test_all_six_standard_colors_present(self):
        assert len(construct_service.COLOR_MAP) == 6

    def test_bonus_shader_aurora_maps_to_correct_file(self):
        assert construct_service.BONUS_SHADERS["aurora"] == "aurora-borealis-ghostty.glsl"

    def test_bonus_shader_aurora_rain_maps_to_correct_file(self):
        assert construct_service.BONUS_SHADERS["aurora-rain"] == "aurora-rain-ghostty.glsl"

    def test_bonus_shader_fireplace_maps_to_correct_file(self):
        assert construct_service.BONUS_SHADERS["fireplace"] == "fireplace-ghostty.glsl"

    def test_bonus_shader_codevision_maps_to_correct_file(self):
        assert construct_service.BONUS_SHADERS["codevision"] == "matrix-codevision-ghostty.glsl"

    def test_bonus_shader_ultra_maps_to_correct_file(self):
        assert construct_service.BONUS_SHADERS["ultra"] == "matrix-ultra-ghostty.glsl"

    def test_bonus_shader_rain_on_glass_maps_to_correct_file(self):
        assert construct_service.BONUS_SHADERS["rain-on-glass"] == "rain-on-glass-ghostty.glsl"

    def test_all_six_bonus_shaders_present(self):
        assert len(construct_service.BONUS_SHADERS) == 6


# ---------------------------------------------------------------------------
# find_next_slot Tests
# ---------------------------------------------------------------------------

class TestFindNextSlot:
    """Test find_next_slot returns lowest unused slot number (1-8)."""

    @patch("construct_service.subprocess.run")
    def test_returns_1_when_all_empty(self, mock_run):
        """No running Ghostty processes -> slot 1."""
        mock_run.return_value = MagicMock(stdout="", returncode=1)
        assert construct_service.find_next_slot() == 1

    @patch("construct_service._get_occupied_slots")
    def test_returns_2_when_slot_1_occupied(self, mock_occupied):
        """Slot 1 has a running process -> returns 2."""
        mock_occupied.return_value = {1}
        assert construct_service.find_next_slot() == 2

    @patch("construct_service._get_occupied_slots")
    def test_returns_none_when_all_8_slots_full(self, mock_occupied):
        """All 8 slots occupied -> returns None."""
        mock_occupied.return_value = {1, 2, 3, 4, 5, 6, 7, 8}
        assert construct_service.find_next_slot() is None

    @patch("construct_service._get_occupied_slots")
    def test_returns_lowest_gap(self, mock_occupied):
        """Slots 1,2,4 occupied -> returns 3."""
        mock_occupied.return_value = {1, 2, 4}
        assert construct_service.find_next_slot() == 3


# ---------------------------------------------------------------------------
# quick_launch Tests
# ---------------------------------------------------------------------------

class TestQuickLaunch:
    """Test quick_launch for standard and bonus colors."""

    @patch("construct_service._get_occupied_slots", return_value=set())
    @patch("construct_service.shader_service.create_slot_shader")
    def test_quick_launch_green_creates_shader(self, mock_create, mock_slots, isolate_env):
        """quick_launch('green') calls create_slot_shader with preset_idx=0."""
        mock_create.return_value = str(isolate_env / "shaders" / "matrix-1.glsl")
        result = construct_service.quick_launch("green")
        assert result["slot"] == 1
        mock_create.assert_called_once_with(1, preset_idx=0)

    @patch("construct_service._get_occupied_slots", return_value=set())
    @patch("construct_service.shader_service.create_slot_shader")
    def test_quick_launch_returns_conf_path(self, mock_create, mock_slots, isolate_env):
        """quick_launch returns the config path."""
        mock_create.return_value = str(isolate_env / "shaders" / "matrix-1.glsl")
        result = construct_service.quick_launch("green")
        assert result["conf"] == "/tmp/ghostty-matrix-1.conf"

    @patch("construct_service._get_occupied_slots", return_value={1, 2, 3, 4, 5, 6, 7, 8})
    def test_quick_launch_all_slots_full_returns_error(self, mock_slots):
        """All 8 slots full -> returns error dict."""
        result = construct_service.quick_launch("green")
        assert "error" in result

    @patch("construct_service._get_occupied_slots", return_value=set())
    def test_quick_launch_aurora_copies_bonus_shader(self, mock_slots, isolate_env):
        """quick_launch('aurora') copies bonus shader instead of using create_slot_shader."""
        result = construct_service.quick_launch("aurora")
        assert result["slot"] == 1
        # Bonus shader should be copied to slot dir as matrix-1.glsl
        slot_shader = Path(construct_service.SLOT_SHADER_DIR) / "matrix-1.glsl"
        assert slot_shader.exists()
        content = slot_shader.read_text()
        assert "Bonus shader" in content

    @patch("construct_service._get_occupied_slots", return_value=set())
    @patch("construct_service.shader_service.create_slot_shader")
    def test_quick_launch_all_standard_colors(self, mock_create, mock_slots, isolate_env):
        """All 6 standard colors can be launched."""
        for color, expected_idx in construct_service.COLOR_MAP.items():
            mock_create.return_value = str(isolate_env / "shaders" / "matrix-1.glsl")
            mock_slots.return_value = set()
            result = construct_service.quick_launch(color)
            assert result["slot"] == 1, f"Failed for color: {color}"

    @patch("construct_service._get_occupied_slots", return_value=set())
    def test_quick_launch_all_bonus_shaders(self, mock_slots, isolate_env):
        """All 6 bonus shaders can be launched."""
        for bonus_name in construct_service.BONUS_SHADERS:
            result = construct_service.quick_launch(bonus_name)
            assert "error" not in result, f"Failed for bonus: {bonus_name}"


# ---------------------------------------------------------------------------
# transition_to_rain Tests
# ---------------------------------------------------------------------------

class TestTransitionToRain:
    """Test TransitionToRain: config rewrite, opacity update, D-Bus reload."""

    @patch("construct_service.shader_service.reload_ghostty")
    @patch("construct_service.shader_service.get_ghostty_bus_names")
    @patch("construct_service.shader_service.create_slot_shader")
    def test_transition_rewrites_config_shader_path(
        self, mock_create, mock_bus, mock_reload, isolate_env
    ):
        """transition_to_rain replaces white-room shader with rain shader."""
        slot = 1
        shader_path = str(isolate_env / "shaders" / "matrix-1.glsl")
        mock_create.return_value = shader_path
        mock_bus.return_value = {1: {"pid": 123, "bus_name": ":1.42"}}
        mock_reload.return_value = True

        # Write initial config pointing to white-room
        conf_path = f"/tmp/ghostty-matrix-{slot}.conf"
        with open(conf_path, "w") as f:
            f.write(
                "custom-shader = /some/path/white-room.glsl\n"
                "background-opacity = 1.0\n"
                "background = #000000\n"
            )

        try:
            construct_service.transition_to_rain(slot, 0)

            # Verify config was rewritten
            with open(conf_path) as f:
                content = f.read()
            assert "white-room" not in content
            assert f"matrix-{slot}.glsl" in content
        finally:
            os.unlink(conf_path)

    @patch("construct_service.shader_service.reload_ghostty")
    @patch("construct_service.shader_service.get_ghostty_bus_names")
    @patch("construct_service.shader_service.create_slot_shader")
    def test_transition_updates_opacity(
        self, mock_create, mock_bus, mock_reload, isolate_env
    ):
        """transition_to_rain changes background-opacity from 1.0 to 0.85."""
        slot = 2
        shader_path = str(isolate_env / "shaders" / "matrix-2.glsl")
        mock_create.return_value = shader_path
        mock_bus.return_value = {2: {"pid": 456, "bus_name": ":1.99"}}
        mock_reload.return_value = True

        conf_path = f"/tmp/ghostty-matrix-{slot}.conf"
        with open(conf_path, "w") as f:
            f.write(
                "custom-shader = /path/to/white-room.glsl\n"
                "background-opacity = 1.0\n"
            )

        try:
            construct_service.transition_to_rain(slot, 1)

            with open(conf_path) as f:
                content = f.read()
            assert "background-opacity = 0.85" in content
            assert "background-opacity = 1.0" not in content
        finally:
            os.unlink(conf_path)

    @patch("construct_service.shader_service.reload_ghostty")
    @patch("construct_service.shader_service.get_ghostty_bus_names")
    @patch("construct_service.shader_service.create_slot_shader")
    def test_transition_triggers_dbus_reload(
        self, mock_create, mock_bus, mock_reload, isolate_env
    ):
        """transition_to_rain triggers D-Bus reload on the slot's Ghostty instance."""
        slot = 3
        shader_path = str(isolate_env / "shaders" / "matrix-3.glsl")
        mock_create.return_value = shader_path
        mock_bus.return_value = {3: {"pid": 789, "bus_name": ":1.55"}}
        mock_reload.return_value = True

        conf_path = f"/tmp/ghostty-matrix-{slot}.conf"
        with open(conf_path, "w") as f:
            f.write(
                "custom-shader = /path/to/white-room.glsl\n"
                "background-opacity = 1.0\n"
            )

        try:
            construct_service.transition_to_rain(slot, 0)
            mock_reload.assert_called_once_with(":1.55")
        finally:
            os.unlink(conf_path)

    @patch("construct_service.shader_service.reload_ghostty")
    @patch("construct_service.shader_service.get_ghostty_bus_names")
    @patch("construct_service.shader_service.create_slot_shader")
    def test_transition_creates_rain_shader_with_preset(
        self, mock_create, mock_bus, mock_reload, isolate_env
    ):
        """transition_to_rain calls create_slot_shader with correct preset."""
        slot = 1
        shader_path = str(isolate_env / "shaders" / "matrix-1.glsl")
        mock_create.return_value = shader_path
        mock_bus.return_value = {1: {"pid": 123, "bus_name": ":1.42"}}
        mock_reload.return_value = True

        conf_path = f"/tmp/ghostty-matrix-{slot}.conf"
        with open(conf_path, "w") as f:
            f.write(
                "custom-shader = /path/to/white-room.glsl\n"
                "background-opacity = 1.0\n"
            )

        try:
            construct_service.transition_to_rain(slot, 4)  # Gold
            mock_create.assert_called_once_with(slot, preset_idx=4)
        finally:
            os.unlink(conf_path)


# ---------------------------------------------------------------------------
# Help Output Tests
# ---------------------------------------------------------------------------

class TestHelpOutput:
    """Test help output contains standard colors and bonus shaders."""

    def test_help_contains_standard_colors_section(self, capsys):
        construct_service.show_help()
        output = capsys.readouterr().out
        assert "Colors:" in output

    def test_help_contains_bonus_shaders_section(self, capsys):
        construct_service.show_help()
        output = capsys.readouterr().out
        assert "Bonus Shaders:" in output

    def test_help_lists_all_standard_colors(self, capsys):
        construct_service.show_help()
        output = capsys.readouterr().out
        for color in ["green", "red", "blue", "purple", "gold", "teal"]:
            assert f"--{color}" in output

    def test_help_lists_all_bonus_shaders(self, capsys):
        construct_service.show_help()
        output = capsys.readouterr().out
        for bonus in ["aurora", "aurora-rain", "fireplace", "codevision", "ultra", "rain-on-glass"]:
            assert f"--{bonus}" in output

    def test_help_shows_no_args_description(self, capsys):
        construct_service.show_help()
        output = capsys.readouterr().out
        assert "white room" in output.lower() or "color picker" in output.lower()


# ---------------------------------------------------------------------------
# Ghostty Config Writing Tests
# ---------------------------------------------------------------------------

class TestWriteGhosttyConfig:
    """Test Ghostty config generation for construct."""

    @patch("construct_service.shader_service.create_slot_shader")
    @patch("construct_service._get_occupied_slots", return_value=set())
    def test_config_contains_custom_shader(self, mock_slots, mock_create, isolate_env):
        """Generated Ghostty config points to the correct shader file."""
        shader_path = str(isolate_env / "shaders" / "matrix-1.glsl")
        mock_create.return_value = shader_path
        result = construct_service.quick_launch("green")

        conf_path = result["conf"]
        with open(conf_path) as f:
            content = f.read()
        assert f"custom-shader = {shader_path}" in content
        # Cleanup
        os.unlink(conf_path)

    @patch("construct_service.shader_service.create_slot_shader")
    @patch("construct_service._get_occupied_slots", return_value=set())
    def test_config_contains_animation_always(self, mock_slots, mock_create, isolate_env):
        """Ghostty config enables shader animation."""
        shader_path = str(isolate_env / "shaders" / "matrix-1.glsl")
        mock_create.return_value = shader_path
        result = construct_service.quick_launch("green")

        with open(result["conf"]) as f:
            content = f.read()
        assert "custom-shader-animation = always" in content
        os.unlink(result["conf"])
