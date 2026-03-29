"""Tests for preset_service.py -- preset CRUD with JSON file storage."""

import json
import os
import re
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from preset_service import (
    PRESETS_DIR,
    delete_preset,
    list_presets,
    load_preset,
    sanitize_name,
    save_preset,
)


# ---------------------------------------------------------------------------
# TestSanitize
# ---------------------------------------------------------------------------

class TestSanitize:
    def test_spaces_to_dashes(self):
        assert sanitize_name("My Cool Preset") == "my-cool-preset"

    def test_strip_and_collapse(self):
        assert sanitize_name("  spaces  ") == "spaces"

    def test_uppercase_to_lowercase(self):
        assert sanitize_name("UPPER Case") == "upper-case"

    def test_remove_special_chars(self):
        assert sanitize_name("special!@#chars") == "specialchars"

    def test_empty_raises_valueerror(self):
        with pytest.raises(ValueError):
            sanitize_name("")

    def test_all_stripped_raises_valueerror(self):
        with pytest.raises(ValueError):
            sanitize_name("---")

    def test_already_clean_passthrough(self):
        assert sanitize_name("my-preset") == "my-preset"

    def test_multiple_spaces_collapse_to_single_dash(self):
        assert sanitize_name("foo   bar   baz") == "foo-bar-baz"

    def test_leading_trailing_dashes_stripped(self):
        assert sanitize_name("--hello--") == "hello"


# ---------------------------------------------------------------------------
# TestSave
# ---------------------------------------------------------------------------

class TestSave:
    def test_save_creates_json_file(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("night-mode", {"RAIN_R": 0.1, "RAIN_G": 0.2, "RAIN_B": 0.9}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "night-mode.json")
        assert os.path.isfile(path)

    def test_save_json_structure(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("test", {"RAIN_R": 0.5}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "test.json")
        with open(path) as f:
            data = json.load(f)
        assert data["name"] == "test"
        assert "params" in data
        assert "saved_at" in data
        assert data["version"] == 1

    def test_save_fills_missing_params_from_defaults(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("partial", {"RAIN_R": 0.5}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "partial.json")
        with open(path) as f:
            data = json.load(f)
        params = data["params"]
        # RAIN_R should be the value we set
        assert params["RAIN_R"] == 0.5
        # All 11 params should be present
        assert len(params) == 11
        # Defaults for the rest
        assert params["RAIN_G"] == 1.0
        assert params["RAIN_SPEED"] == 0.8

    def test_save_drops_unknown_params(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("clean", {"RAIN_R": 0.5, "BOGUS_PARAM": 99.0}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "clean.json")
        with open(path) as f:
            data = json.load(f)
        assert "BOGUS_PARAM" not in data["params"]
        assert len(data["params"]) == 11

    def test_save_overwrites_existing(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("dup", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        save_preset("dup", {"RAIN_R": 0.9}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "dup.json")
        with open(path) as f:
            data = json.load(f)
        assert data["params"]["RAIN_R"] == 0.9

    def test_save_sanitizes_name(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("My Cool Preset", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "my-cool-preset.json")
        assert os.path.isfile(path)

    def test_save_creates_directory(self, tmp_path):
        presets_dir = str(tmp_path / "deep" / "nested" / "presets")
        save_preset("test", {}, presets_dir=presets_dir)
        assert os.path.isdir(presets_dir)

    def test_save_all_11_params_roundtrip(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        full_params = {
            "RAIN_R": 0.7,
            "RAIN_G": 0.0,
            "RAIN_B": 1.0,
            "RAIN_SPEED": 1.5,
            "GLOW_STRENGTH": 2.0,
            "CHAR_WIDTH": 12.0,
            "TRAIL_POWER": 10.0,
            "RAIN_DENSITY": 0.6,
            "SHOW_L1": 0.0,
            "SHOW_L2": 1.0,
            "SHOW_L3": 0.0,
        }
        save_preset("full", full_params, presets_dir=presets_dir)
        loaded = load_preset("full", presets_dir=presets_dir)
        assert loaded == full_params


# ---------------------------------------------------------------------------
# TestLoad
# ---------------------------------------------------------------------------

class TestLoad:
    def test_load_returns_params(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("test", {"RAIN_R": 0.3, "RAIN_G": 0.4}, presets_dir=presets_dir)
        params = load_preset("test", presets_dir=presets_dir)
        assert params["RAIN_R"] == 0.3
        assert params["RAIN_G"] == 0.4
        assert len(params) == 11

    def test_load_not_found_raises_filenotfounderror(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        os.makedirs(presets_dir, exist_ok=True)
        with pytest.raises(FileNotFoundError):
            load_preset("nonexistent", presets_dir=presets_dir)

    def test_load_corrupt_json_raises_valueerror(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        os.makedirs(presets_dir, exist_ok=True)
        corrupt_path = os.path.join(presets_dir, "corrupt.json")
        with open(corrupt_path, "w") as f:
            f.write("{{{not valid json!!!")
        with pytest.raises(ValueError):
            load_preset("corrupt", presets_dir=presets_dir)

    def test_load_by_unsanitized_name(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("night-mode", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        params = load_preset("Night Mode", presets_dir=presets_dir)
        assert params["RAIN_R"] == 0.1


# ---------------------------------------------------------------------------
# TestList
# ---------------------------------------------------------------------------

class TestList:
    def test_list_returns_saved_presets(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("alpha", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        save_preset("beta", {"RAIN_R": 0.2}, presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert len(result) == 2
        names = [p["name"] for p in result]
        assert names == ["alpha", "beta"]  # sorted alphabetically

    def test_list_empty_dir(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        os.makedirs(presets_dir, exist_ok=True)
        result = list_presets(presets_dir=presets_dir)
        assert result == []

    def test_list_nonexistent_dir(self, tmp_path):
        presets_dir = str(tmp_path / "missing")
        result = list_presets(presets_dir=presets_dir)
        assert result == []

    def test_list_ignores_non_json_files(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        os.makedirs(presets_dir, exist_ok=True)
        # Create a non-json file
        with open(os.path.join(presets_dir, "readme.txt"), "w") as f:
            f.write("not a preset")
        save_preset("real", {"RAIN_R": 0.5}, presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert len(result) == 1
        assert result[0]["name"] == "real"

    def test_list_skips_corrupt_json(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        os.makedirs(presets_dir, exist_ok=True)
        # Create a corrupt json file
        with open(os.path.join(presets_dir, "bad.json"), "w") as f:
            f.write("{{{garbage")
        save_preset("good", {"RAIN_R": 0.5}, presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert len(result) == 1
        assert result[0]["name"] == "good"

    def test_list_includes_color_info(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("colorful", {"RAIN_R": 0.7, "RAIN_G": 0.0, "RAIN_B": 1.0}, presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert len(result) == 1
        assert result[0]["color"] == (0.7, 0.0, 1.0)

    def test_list_includes_saved_at(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("timed", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert result[0]["saved_at"] is not None
        assert "T" in result[0]["saved_at"]  # ISO 8601

    def test_list_includes_filename(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("test", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert result[0]["filename"] == "test.json"


# ---------------------------------------------------------------------------
# TestDelete
# ---------------------------------------------------------------------------

class TestDelete:
    def test_delete_removes_file(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("doomed", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        path = os.path.join(presets_dir, "doomed.json")
        assert os.path.isfile(path)
        delete_preset("doomed", presets_dir=presets_dir)
        assert not os.path.isfile(path)

    def test_delete_not_found_raises_filenotfounderror(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        os.makedirs(presets_dir, exist_ok=True)
        with pytest.raises(FileNotFoundError):
            delete_preset("ghost", presets_dir=presets_dir)

    def test_delete_by_unsanitized_name(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("night-mode", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        delete_preset("Night Mode", presets_dir=presets_dir)
        assert not os.path.isfile(os.path.join(presets_dir, "night-mode.json"))

    def test_delete_then_list_empty(self, tmp_path):
        presets_dir = str(tmp_path / "presets")
        save_preset("only", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        delete_preset("only", presets_dir=presets_dir)
        result = list_presets(presets_dir=presets_dir)
        assert result == []


# ---------------------------------------------------------------------------
# TestCrossProcess
# ---------------------------------------------------------------------------

class TestCrossProcess:
    def test_separate_save_load_see_same_data(self, tmp_path):
        """Simulate cross-process: save in one call, load in another."""
        presets_dir = str(tmp_path / "presets")
        # "Process 1" saves
        save_preset("shared", {"RAIN_R": 0.42, "RAIN_SPEED": 3.0}, presets_dir=presets_dir)
        # "Process 2" loads (no caching, fresh disk read)
        params = load_preset("shared", presets_dir=presets_dir)
        assert params["RAIN_R"] == 0.42
        assert params["RAIN_SPEED"] == 3.0

    def test_no_caching_sees_updates(self, tmp_path):
        """Verify load always reads fresh from disk."""
        presets_dir = str(tmp_path / "presets")
        save_preset("evolving", {"RAIN_R": 0.1}, presets_dir=presets_dir)
        params1 = load_preset("evolving", presets_dir=presets_dir)
        assert params1["RAIN_R"] == 0.1

        # Update the file
        save_preset("evolving", {"RAIN_R": 0.9}, presets_dir=presets_dir)
        params2 = load_preset("evolving", presets_dir=presets_dir)
        assert params2["RAIN_R"] == 0.9


# ---------------------------------------------------------------------------
# TestConstructPresetIntegration
# ---------------------------------------------------------------------------

class TestConstructPresetIntegration:
    """Tests for quick_launch_from_preset in construct_service.py."""

    def test_valid_preset_returns_slot_conf_shader(self, tmp_path, monkeypatch):
        """quick_launch_from_preset with valid preset returns {slot, conf, shader}
        and shader file contains the preset's #define values."""
        from construct_service import quick_launch_from_preset

        presets_dir = str(tmp_path / "presets")
        shader_dir = str(tmp_path / "shaders")
        os.makedirs(shader_dir, exist_ok=True)

        # Create a template shader for create_slot_shader to copy
        template = os.path.join(os.path.dirname(__file__), "..", "..", "shaders-glsl", "matrix-green-ghostty.glsl")
        assert os.path.isfile(template), f"Template shader not found: {template}"

        # Save a preset with known params
        full_params = {
            "RAIN_R": 0.5, "RAIN_G": 0.2, "RAIN_B": 0.8,
            "RAIN_SPEED": 2.5, "GLOW_STRENGTH": 1.2,
            "CHAR_WIDTH": 15.0, "TRAIL_POWER": 6.0, "RAIN_DENSITY": 0.4,
            "SHOW_L1": 0.0, "SHOW_L2": 1.0, "SHOW_L3": 0.0,
        }
        save_preset("test-preset", full_params, presets_dir=presets_dir)

        # Monkeypatch slot finding and shader directory
        import shader_service
        monkeypatch.setattr("construct_service.find_next_slot", lambda: 1)
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", shader_dir)

        # Monkeypatch _get_session_opacity to avoid scanning running windows
        monkeypatch.setattr("construct_service._get_session_opacity", lambda: "0.85")

        result = quick_launch_from_preset("test-preset", presets_dir=presets_dir)

        assert "error" not in result
        assert "slot" in result
        assert "conf" in result
        assert "shader" in result
        assert result["slot"] == 1

        # Verify shader file contains the preset's params as #define values
        # replace_define preserves original whitespace padding, so use regex
        with open(result["shader"]) as f:
            shader_content = f.read()
        assert re.search(r"#define\s+RAIN_R\s+0\.5", shader_content)
        assert re.search(r"#define\s+RAIN_G\s+0\.2", shader_content)
        assert re.search(r"#define\s+RAIN_B\s+0\.8", shader_content)
        assert re.search(r"#define\s+RAIN_SPEED\s+2\.5", shader_content)
        assert re.search(r"#define\s+SHOW_L1\s+0\.0", shader_content)
        assert re.search(r"#define\s+SHOW_L3\s+0\.0", shader_content)

    def test_nonexistent_preset_returns_error_with_available(self, tmp_path):
        """quick_launch_from_preset with nonexistent name returns error listing available presets."""
        from construct_service import quick_launch_from_preset

        presets_dir = str(tmp_path / "presets")
        # Save one preset so we have something in the list
        save_preset("existing-one", {"RAIN_R": 0.1}, presets_dir=presets_dir)

        result = quick_launch_from_preset("nonexistent", presets_dir=presets_dir)

        assert "error" in result
        assert "not found" in result["error"].lower()
        assert "existing-one" in result["error"]

    def test_foreground_color_derived_from_preset_rgb(self, tmp_path, monkeypatch):
        """quick_launch_from_preset derives foreground hex from RAIN_R/G/B, not PRESET_FOREGROUNDS."""
        from construct_service import quick_launch_from_preset

        presets_dir = str(tmp_path / "presets")
        shader_dir = str(tmp_path / "shaders")
        os.makedirs(shader_dir, exist_ok=True)

        # Save preset with pure red
        save_preset("pure-red", {
            "RAIN_R": 1.0, "RAIN_G": 0.0, "RAIN_B": 0.0,
        }, presets_dir=presets_dir)

        import shader_service
        monkeypatch.setattr("construct_service.find_next_slot", lambda: 2)
        monkeypatch.setattr(shader_service, "SLOT_SHADER_DIR", shader_dir)
        monkeypatch.setattr("construct_service._get_session_opacity", lambda: "0.85")

        result = quick_launch_from_preset("pure-red", presets_dir=presets_dir)

        assert "error" not in result
        # Read the conf file and verify foreground = #ff0000
        with open(result["conf"]) as f:
            conf_content = f.read()
        assert "foreground = #ff0000" in conf_content
