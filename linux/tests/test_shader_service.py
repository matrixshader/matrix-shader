"""Unit tests for shader_service.py -- all 11 shader parameters, read/write/create, D-Bus reload."""
import os
import sys
from unittest.mock import patch, MagicMock

import pytest

# Add linux/ to path so we can import shader_service
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import shader_service


# --- replace_define ---

class TestReplaceDefine:
    def test_replaces_value(self, shader_content):
        result = shader_service.replace_define(shader_content, "RAIN_SPEED", 2.5)
        assert "#define RAIN_SPEED     2.5" in result

    def test_preserves_other_defines(self, shader_content):
        result = shader_service.replace_define(shader_content, "RAIN_SPEED", 2.5)
        assert "#define RAIN_R         0.0" in result
        assert "#define RAIN_G         1.0" in result
        assert "#define RAIN_B         0.3" in result
        assert "#define GLOW_STRENGTH  0.8" in result

    def test_handles_varying_whitespace(self):
        content = "#define RAIN_SPEED  0.8\n#define RAIN_SPEED\t\t3.0\n"
        result = shader_service.replace_define(content, "RAIN_SPEED", 1.5)
        # Both lines should be updated
        assert "0.8" not in result
        assert "3.0" not in result
        assert "1.5" in result

    def test_formats_float_one_decimal(self, shader_content):
        result = shader_service.replace_define(shader_content, "RAIN_SPEED", 1.0)
        assert "#define RAIN_SPEED     1.0" in result
        # Should NOT produce "1" without decimal
        assert "#define RAIN_SPEED     1\n" not in result

    def test_formats_fractional_with_leading_zero(self, shader_content):
        result = shader_service.replace_define(shader_content, "RAIN_B", 0.3)
        assert "#define RAIN_B         0.3" in result

    def test_nonexistent_param_returns_unchanged(self, shader_content):
        result = shader_service.replace_define(shader_content, "NONEXISTENT_PARAM", 5.0)
        assert result == shader_content


# --- read_shader_config ---

class TestReadShaderConfig:
    def test_reads_all_11_params(self, tmp_shader_file, tmp_slot_dir, monkeypatch):
        # Put the shader file in the right slot path
        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        import shutil
        shutil.copy(tmp_shader_file, slot_path)
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)

        config = shader_service.read_shader_config(1)
        assert len(config) == 11
        assert config["RAIN_R"] == 0.0
        assert config["RAIN_G"] == 1.0
        assert config["RAIN_B"] == 0.3
        assert config["RAIN_SPEED"] == 0.8
        assert config["GLOW_STRENGTH"] == 0.8
        assert config["CHAR_WIDTH"] == 10.0
        assert config["TRAIL_POWER"] == 8.0
        assert config["RAIN_DENSITY"] == 0.4
        assert config["SHOW_L1"] == 1.0
        assert config["SHOW_L2"] == 1.0
        assert config["SHOW_L3"] == 1.0

    def test_returns_defaults_for_missing_params(self, tmp_slot_dir, monkeypatch):
        # Create a shader file missing some params
        minimal = "#define RAIN_R  0.5\nvoid mainImage() {}\n"
        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        with open(slot_path, "w") as f:
            f.write(minimal)
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)

        config = shader_service.read_shader_config(1)
        assert config["RAIN_R"] == 0.5
        # Missing params should get defaults
        assert config["RAIN_SPEED"] == shader_service.PARAM_DEFAULTS["RAIN_SPEED"]
        assert config["SHOW_L1"] == shader_service.PARAM_DEFAULTS["SHOW_L1"]

    def test_handles_integer_values(self, tmp_slot_dir, monkeypatch):
        # GLSL file with integer value "1" instead of "1.0"
        content = "#define SHOW_L1  1\n#define RAIN_SPEED  2\n"
        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        with open(slot_path, "w") as f:
            f.write(content)
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)

        config = shader_service.read_shader_config(1)
        assert config["SHOW_L1"] == 1.0
        assert config["RAIN_SPEED"] == 2.0


# --- clamp_value ---

class TestClampValue:
    def test_clamps_above_max(self):
        assert shader_service.clamp_value("RAIN_SPEED", 10.0) == 5.0

    def test_clamps_below_min(self):
        assert shader_service.clamp_value("RAIN_SPEED", -1.0) == 0.1

    def test_within_range_unchanged(self):
        assert shader_service.clamp_value("RAIN_SPEED", 2.0) == 2.0

    def test_layer_values_clamped_0_to_1(self):
        assert shader_service.clamp_value("SHOW_L1", 0.5) == 0.5
        assert shader_service.clamp_value("SHOW_L1", -0.5) == 0.0
        assert shader_service.clamp_value("SHOW_L1", 1.5) == 1.0

    def test_rgb_values_clamped_0_to_1(self):
        assert shader_service.clamp_value("RAIN_R", 1.5) == 1.0
        assert shader_service.clamp_value("RAIN_G", -0.1) == 0.0

    def test_glow_range(self):
        assert shader_service.clamp_value("GLOW_STRENGTH", 0.1) == 0.2
        assert shader_service.clamp_value("GLOW_STRENGTH", 5.0) == 3.0

    def test_char_width_range(self):
        assert shader_service.clamp_value("CHAR_WIDTH", 1.0) == 6.0
        assert shader_service.clamp_value("CHAR_WIDTH", 25.0) == 20.0

    def test_trail_power_range(self):
        assert shader_service.clamp_value("TRAIL_POWER", 1.0) == 4.0
        assert shader_service.clamp_value("TRAIL_POWER", 20.0) == 15.0

    def test_density_range(self):
        assert shader_service.clamp_value("RAIN_DENSITY", 0.0) == 0.2
        assert shader_service.clamp_value("RAIN_DENSITY", 2.0) == 1.0


# --- atomic_write ---

class TestAtomicWrite:
    def test_writes_content(self, tmp_path):
        path = str(tmp_path / "test.glsl")
        shader_service.atomic_write(path, "hello world")
        with open(path) as f:
            assert f.read() == "hello world"

    def test_creates_parent_dirs(self, tmp_path):
        path = str(tmp_path / "subdir" / "nested" / "test.glsl")
        shader_service.atomic_write(path, "nested content")
        with open(path) as f:
            assert f.read() == "nested content"

    def test_content_matches_exactly(self, tmp_path, shader_content):
        path = str(tmp_path / "exact.glsl")
        shader_service.atomic_write(path, shader_content)
        with open(path) as f:
            assert f.read() == shader_content

    def test_overwrites_existing(self, tmp_path):
        path = str(tmp_path / "overwrite.glsl")
        shader_service.atomic_write(path, "original")
        shader_service.atomic_write(path, "replaced")
        with open(path) as f:
            assert f.read() == "replaced"


# --- create_slot_shader ---

class TestCreateSlotShader:
    def test_creates_file_at_correct_path(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        # Use the real template
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)

        result_path = shader_service.create_slot_shader(1, r=1.0, g=0.0, b=0.0)
        expected = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        assert result_path == expected
        assert os.path.exists(expected)

    def test_rgb_values_overwritten(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)

        shader_service.create_slot_shader(1, r=1.0, g=0.0, b=0.0)
        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define RAIN_R         1.0" in content
        assert "#define RAIN_G         0.0" in content
        assert "#define RAIN_B         0.0" in content

    def test_contains_full_shader_body(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)

        shader_service.create_slot_shader(1, r=1.0, g=0.0, b=0.0)
        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        # Should contain shader body code, not just headers
        assert "void mainImage" in content
        assert "DrawLayer" in content
        assert "GLYPHS" in content

    def test_preset_idx_loads_preset_rgb(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)

        # Preset 0 is green (0.0, 1.0, 0.3) based on wakeupneo.sh PRESETS
        shader_service.create_slot_shader(2, preset_idx=0)
        slot_path = os.path.join(tmp_slot_dir, "matrix-2.glsl")
        content = open(slot_path).read()
        assert "#define RAIN_R         0.0" in content
        assert "#define RAIN_G         1.0" in content
        assert "#define RAIN_B         0.3" in content


# --- write_shader_param ---

class TestWriteShaderParam:
    def test_modifies_param_in_slot(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        # Create a shader file for slot 1
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)

        # Mock D-Bus functions so they don't actually call system
        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_param(1, "RAIN_SPEED", 2.5)

        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define RAIN_SPEED     2.5" in content

    def test_slot_isolation(self, tmp_slot_dir, monkeypatch):
        """SHDR-03: Write to slot 1 does not affect slot 2."""
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)
        shader_service.create_slot_shader(2)

        # Modify slot 1 only
        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_param(1, "RAIN_SPEED", 4.0)

        # Slot 2 should be unchanged
        slot2_path = os.path.join(tmp_slot_dir, "matrix-2.glsl")
        content2 = open(slot2_path).read()
        assert "#define RAIN_SPEED     0.8" in content2

        # Slot 1 should be changed
        slot1_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content1 = open(slot1_path).read()
        assert "#define RAIN_SPEED     4.0" in content1

    def test_clamps_out_of_range(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)

        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_param(1, "RAIN_SPEED", 99.0)  # Way above max 5.0

        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define RAIN_SPEED     5.0" in content


# --- write_shader_params (batch) ---

class TestWriteShaderParams:
    def test_batch_write_multiple_params(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)

        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_params(1, {
                "RAIN_SPEED": 3.0,
                "RAIN_R": 1.0,
                "RAIN_G": 0.0,
            })

        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define RAIN_SPEED     3.0" in content
        assert "#define RAIN_R         1.0" in content
        assert "#define RAIN_G         0.0" in content


# --- get_ghostty_bus_names (mocked) ---

class TestGetGhosttyBusNames:
    def test_parses_busctl_output(self, mock_busctl_output):
        mock_result = MagicMock()
        mock_result.stdout = mock_busctl_output
        mock_result.returncode = 0

        def mock_cmdline(pid):
            cmdlines = {
                4016: "/usr/bin/ghostty\x00--config-file=/tmp/ghostty-matrix-1.conf\x00",
                4070: "/usr/bin/ghostty\x00--config-file=/tmp/ghostty-matrix-2.conf\x00",
                4139: "/usr/bin/ghostty\x00--config-file=/tmp/ghostty-matrix-3.conf\x00",
            }
            return cmdlines.get(pid, "")

        with patch("subprocess.run", return_value=mock_result):
            with patch("builtins.open", side_effect=lambda f, *a, **kw:
                MagicMock(
                    read=lambda: mock_cmdline(int(f.split("/")[2])),
                    __enter__=lambda s: s,
                    __exit__=lambda s, *a: None,
                ) if f.startswith("/proc/") else (_ for _ in ()).throw(FileNotFoundError(f))
            ):
                mapping = shader_service.get_ghostty_bus_names()

        assert 1 in mapping
        assert 2 in mapping
        assert 3 in mapping
        assert mapping[1]["pid"] == 4016
        assert mapping[1]["bus_name"] == ":1.118"

    def test_correlates_pids_to_slots(self, mock_busctl_output):
        mock_result = MagicMock()
        mock_result.stdout = mock_busctl_output
        mock_result.returncode = 0

        def mock_cmdline(pid):
            cmdlines = {
                4016: "/usr/bin/ghostty\x00--config-file=/tmp/ghostty-matrix-1.conf\x00",
                4070: "/usr/bin/ghostty\x00--config-file=/tmp/ghostty-matrix-2.conf\x00",
                4139: "/usr/bin/ghostty\x00--config-file=/tmp/ghostty-matrix-3.conf\x00",
            }
            return cmdlines.get(pid, "")

        with patch("subprocess.run", return_value=mock_result):
            with patch("builtins.open", side_effect=lambda f, *a, **kw:
                MagicMock(
                    read=lambda: mock_cmdline(int(f.split("/")[2])),
                    __enter__=lambda s: s,
                    __exit__=lambda s, *a: None,
                ) if f.startswith("/proc/") else (_ for _ in ()).throw(FileNotFoundError(f))
            ):
                mapping = shader_service.get_ghostty_bus_names()

        assert mapping[2]["pid"] == 4070
        assert mapping[2]["bus_name"] == ":1.119"
        assert mapping[3]["pid"] == 4139
        assert mapping[3]["bus_name"] == ":1.120"


# --- reload_ghostty (mocked) ---

class TestReloadGhostty:
    def test_calls_gdbus_with_correct_args(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            shader_service.reload_ghostty(":1.118")

            mock_run.assert_called_once()
            args = mock_run.call_args[0][0]
            assert args[0] == "gdbus"
            assert args[1] == "call"
            assert "--session" in args
            assert "--dest" in args
            assert ":1.118" in args
            assert "--object-path" in args
            assert "/com/mitchellh/ghostty" in args
            assert "--method" in args
            assert "org.gtk.Actions.Activate" in args
            assert "reload-config" in args

    def test_returns_true_on_success(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            result = shader_service.reload_ghostty(":1.118")
            assert result is True

    def test_returns_false_on_timeout(self):
        import subprocess
        with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("gdbus", 5)):
            result = shader_service.reload_ghostty(":1.118")
            assert result is False

    def test_targets_only_specified_bus_name(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            shader_service.reload_ghostty(":1.119")

            args = mock_run.call_args[0][0]
            assert ":1.119" in args
            # Should NOT contain other bus names
            assert ":1.118" not in str(args)


# --- Layer toggle tests (SHDR-04) ---

class TestLayerToggle:
    def test_toggle_layer_off(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)

        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_param(1, "SHOW_L1", 0.0)

        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define SHOW_L1        0.0" in content

    def test_toggle_layer_on(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)

        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_param(1, "SHOW_L1", 0.0)
            shader_service.write_shader_param(1, "SHOW_L1", 1.0)

        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define SHOW_L1        1.0" in content


# --- RGB arbitrary values (SHDR-05) ---

class TestRGBArbitrary:
    def test_arbitrary_rgb_values(self, tmp_slot_dir, monkeypatch):
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", tmp_slot_dir)
        template_path = os.path.join(
            os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl"
        )
        monkeypatch.setattr(shader_service, "TEMPLATE_PATH", template_path)
        shader_service.create_slot_shader(1)

        with patch.object(shader_service, "get_ghostty_bus_names", return_value={}):
            shader_service.write_shader_params(1, {
                "RAIN_R": 0.7,
                "RAIN_G": 0.2,
                "RAIN_B": 0.9,
            })

        slot_path = os.path.join(tmp_slot_dir, "matrix-1.glsl")
        content = open(slot_path).read()
        assert "#define RAIN_R         0.7" in content
        assert "#define RAIN_G         0.2" in content
        assert "#define RAIN_B         0.9" in content


# --- Reload targeting (SHDR-06) ---

class TestReloadTargeting:
    def test_reload_targets_specific_bus(self):
        """SHDR-06: Force reload targets only the specific bus_name."""
        calls = []
        def capture_run(cmd, **kwargs):
            calls.append(cmd)
            return MagicMock(returncode=0)

        with patch("subprocess.run", side_effect=capture_run):
            shader_service.reload_ghostty(":1.118")
            shader_service.reload_ghostty(":1.119")

        assert len(calls) == 2
        # First call targets :1.118
        assert ":1.118" in calls[0]
        assert ":1.119" not in str(calls[0])
        # Second call targets :1.119
        assert ":1.119" in calls[1]
        assert ":1.118" not in str(calls[1])
