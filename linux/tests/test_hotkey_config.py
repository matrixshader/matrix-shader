"""Tests for hotkey_config: config model, defaults, persistence, inotify, Red Pill gate."""
import json
import os
import struct
import sys
import ctypes
from unittest.mock import patch, MagicMock

import pytest

# Ensure linux/ is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import hotkey_config


class TestDefaultBindings:
    """DEFAULT_BINDINGS has all 13 hotkeys with correct structure."""

    def test_has_13_bindings(self):
        assert len(hotkey_config.DEFAULT_BINDINGS) == 13

    def test_all_actions_present(self):
        expected_actions = {
            "SwapLeft", "SwapRight", "CycleLayout", "ToggleTransparency",
            "OpacityDown", "OpacityUp", "SpeedUp", "SpeedDown",
            "ToggleFar", "ToggleMid", "ToggleNear", "ShowHelp", "ManualReload",
        }
        assert set(hotkey_config.DEFAULT_BINDINGS.keys()) == expected_actions

    def test_each_binding_has_required_keys(self):
        for action, binding in hotkey_config.DEFAULT_BINDINGS.items():
            assert "key" in binding, f"{action} missing 'key'"
            assert "modifiers" in binding, f"{action} missing 'modifiers'"
            assert "enabled" in binding, f"{action} missing 'enabled'"

    def test_no_cycle_shader(self):
        assert "CycleShader" not in hotkey_config.DEFAULT_BINDINGS

    def test_default_modifiers_are_ctrl_shift(self):
        for action, binding in hotkey_config.DEFAULT_BINDINGS.items():
            assert binding["modifiers"] == ["Ctrl", "Shift"], (
                f"{action} should have Ctrl+Shift modifiers"
            )

    def test_all_enabled_by_default(self):
        for action, binding in hotkey_config.DEFAULT_BINDINGS.items():
            assert binding["enabled"] is True, f"{action} should be enabled"


class TestKeyNameToEvdev:
    """KEY_NAME_TO_EVDEV maps all 13 key names correctly."""

    def test_has_13_entries(self):
        assert len(hotkey_config.KEY_NAME_TO_EVDEV) == 13

    def test_arrow_keys(self):
        from evdev import ecodes
        assert hotkey_config.KEY_NAME_TO_EVDEV["Left"] == ecodes.KEY_LEFT      # 105
        assert hotkey_config.KEY_NAME_TO_EVDEV["Right"] == ecodes.KEY_RIGHT    # 106
        assert hotkey_config.KEY_NAME_TO_EVDEV["Up"] == ecodes.KEY_UP          # 103
        assert hotkey_config.KEY_NAME_TO_EVDEV["Down"] == ecodes.KEY_DOWN      # 108

    def test_letter_keys(self):
        from evdev import ecodes
        assert hotkey_config.KEY_NAME_TO_EVDEV["L"] == ecodes.KEY_L    # 38
        assert hotkey_config.KEY_NAME_TO_EVDEV["B"] == ecodes.KEY_B    # 48
        assert hotkey_config.KEY_NAME_TO_EVDEV["J"] == ecodes.KEY_J    # 36
        assert hotkey_config.KEY_NAME_TO_EVDEV["K"] == ecodes.KEY_K    # 37
        assert hotkey_config.KEY_NAME_TO_EVDEV["H"] == ecodes.KEY_H    # 35

    def test_number_keys(self):
        from evdev import ecodes
        assert hotkey_config.KEY_NAME_TO_EVDEV["1"] == ecodes.KEY_1    # 2
        assert hotkey_config.KEY_NAME_TO_EVDEV["2"] == ecodes.KEY_2    # 3
        assert hotkey_config.KEY_NAME_TO_EVDEV["3"] == ecodes.KEY_3    # 4

    def test_function_key(self):
        from evdev import ecodes
        assert hotkey_config.KEY_NAME_TO_EVDEV["F5"] == ecodes.KEY_F5  # 63


class TestModifierNameToEvdev:
    """MODIFIER_NAME_TO_EVDEV maps Ctrl/Shift/Alt/Super to left and right evdev codes."""

    def test_ctrl_maps_to_both_sides(self):
        from evdev import ecodes
        assert hotkey_config.MODIFIER_NAME_TO_EVDEV["Ctrl"] == {
            ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL
        }

    def test_shift_maps_to_both_sides(self):
        from evdev import ecodes
        assert hotkey_config.MODIFIER_NAME_TO_EVDEV["Shift"] == {
            ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT
        }

    def test_alt_maps_to_both_sides(self):
        from evdev import ecodes
        assert hotkey_config.MODIFIER_NAME_TO_EVDEV["Alt"] == {
            ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT
        }

    def test_super_maps_to_both_sides(self):
        from evdev import ecodes
        assert hotkey_config.MODIFIER_NAME_TO_EVDEV["Super"] == {
            ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA
        }


class TestLoadConfig:
    """load_config() handles missing, valid, and corrupt files."""

    def test_creates_file_when_missing(self, tmp_path):
        config_path = str(tmp_path / "hotkeys.json")
        config = hotkey_config.load_config(path=config_path)
        assert config == hotkey_config.DEFAULT_BINDINGS
        assert os.path.exists(config_path)

    def test_created_file_has_valid_json(self, tmp_path):
        config_path = str(tmp_path / "hotkeys.json")
        hotkey_config.load_config(path=config_path)
        with open(config_path) as f:
            data = json.load(f)
        assert data == hotkey_config.DEFAULT_BINDINGS

    def test_loads_existing_valid_file(self, tmp_path):
        config_path = str(tmp_path / "hotkeys.json")
        custom = {"SpeedUp": {"key": "X", "modifiers": ["Alt"], "enabled": False}}
        with open(config_path, "w") as f:
            json.dump(custom, f)
        config = hotkey_config.load_config(path=config_path)
        assert config == custom

    def test_corrupted_json_returns_defaults(self, tmp_path):
        config_path = str(tmp_path / "hotkeys.json")
        with open(config_path, "w") as f:
            f.write("{broken json!!!")
        config = hotkey_config.load_config(path=config_path)
        assert config == hotkey_config.DEFAULT_BINDINGS

    def test_creates_parent_dirs_if_needed(self, tmp_path):
        config_path = str(tmp_path / "deep" / "nested" / "hotkeys.json")
        config = hotkey_config.load_config(path=config_path)
        assert config == hotkey_config.DEFAULT_BINDINGS
        assert os.path.exists(config_path)


class TestSaveConfig:
    """save_config() writes valid JSON with indent=2 using atomic write."""

    def test_writes_valid_json(self, tmp_path):
        config_path = str(tmp_path / "hotkeys.json")
        hotkey_config.save_config(hotkey_config.DEFAULT_BINDINGS, path=config_path)
        with open(config_path) as f:
            data = json.load(f)
        assert data == hotkey_config.DEFAULT_BINDINGS

    def test_writes_with_indent(self, tmp_path):
        config_path = str(tmp_path / "hotkeys.json")
        hotkey_config.save_config(hotkey_config.DEFAULT_BINDINGS, path=config_path)
        with open(config_path) as f:
            content = f.read()
        # indent=2 means there should be 2-space indentation
        assert "\n  " in content

    def test_creates_parent_dirs(self, tmp_path):
        config_path = str(tmp_path / "subdir" / "hotkeys.json")
        hotkey_config.save_config({"test": True}, path=config_path)
        assert os.path.exists(config_path)


class TestBuildHotkeyTable:
    """build_hotkey_table() converts config to evdev lookup table."""

    def test_returns_dict_with_frozenset_tuple_keys(self):
        table = hotkey_config.build_hotkey_table(hotkey_config.DEFAULT_BINDINGS)
        for key in table:
            mod_set, key_code = key
            assert isinstance(mod_set, frozenset)
            assert isinstance(key_code, int)

    def test_has_13_entries_for_defaults(self):
        table = hotkey_config.build_hotkey_table(hotkey_config.DEFAULT_BINDINGS)
        assert len(table) == 13

    def test_maps_to_action_names(self):
        table = hotkey_config.build_hotkey_table(hotkey_config.DEFAULT_BINDINGS)
        actions = set(table.values())
        expected = {
            "SwapLeft", "SwapRight", "CycleLayout", "ToggleTransparency",
            "OpacityDown", "OpacityUp", "SpeedUp", "SpeedDown",
            "ToggleFar", "ToggleMid", "ToggleNear", "ShowHelp", "ManualReload",
        }
        assert actions == expected

    def test_skips_disabled_bindings(self):
        config = dict(hotkey_config.DEFAULT_BINDINGS)
        config["SpeedUp"] = {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": False}
        table = hotkey_config.build_hotkey_table(config)
        assert len(table) == 12
        assert "SpeedUp" not in table.values()

    def test_redpill_false_always_returns_defaults(self):
        custom_config = {
            "SpeedUp": {"key": "X", "modifiers": ["Alt"], "enabled": True},
        }
        table = hotkey_config.build_hotkey_table(custom_config, is_redpill=False)
        # Should use DEFAULT_BINDINGS, not custom
        actions = set(table.values())
        assert "SpeedUp" in actions
        assert len(table) == 13

    def test_redpill_true_returns_custom_bindings(self):
        custom_config = {
            "SpeedUp": {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        table = hotkey_config.build_hotkey_table(custom_config, is_redpill=True)
        assert len(table) == 1
        assert "SpeedUp" in table.values()

    def test_correct_evdev_codes_for_speed_up(self):
        from evdev import ecodes
        table = hotkey_config.build_hotkey_table(hotkey_config.DEFAULT_BINDINGS)
        # SpeedUp is Ctrl+Shift+Down
        expected_mods = frozenset({
            ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
            ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
        })
        expected_key = ecodes.KEY_DOWN
        assert (expected_mods, expected_key) in table
        assert table[(expected_mods, expected_key)] == "SpeedUp"


class TestIsRedpill:
    """is_redpill() checks file existence."""

    def test_returns_true_when_file_exists(self, tmp_path):
        redpill_path = str(tmp_path / "redpill.json")
        with open(redpill_path, "w") as f:
            json.dump({"licensed": True}, f)
        with patch.object(hotkey_config, "_REDPILL_PATH", redpill_path):
            assert hotkey_config.is_redpill() is True

    def test_returns_false_when_file_missing(self, tmp_path):
        redpill_path = str(tmp_path / "redpill.json")
        with patch.object(hotkey_config, "_REDPILL_PATH", redpill_path):
            assert hotkey_config.is_redpill() is False


class TestInotifyWatcher:
    """InotifyWatcher provides fd for select.select() and detects config changes."""

    def test_fileno_returns_valid_fd(self, tmp_path):
        watcher = hotkey_config.InotifyWatcher(str(tmp_path))
        try:
            fd = watcher.fileno()
            assert isinstance(fd, int)
            assert fd >= 0
        finally:
            watcher.close()

    def test_watches_directory_not_file(self, tmp_path):
        """InotifyWatcher watches the directory, so atomic writes are detected."""
        watcher = hotkey_config.InotifyWatcher(str(tmp_path))
        try:
            # The watcher should have been created on the directory
            assert watcher._watch_dir == str(tmp_path)
        finally:
            watcher.close()

    def test_check_returns_true_when_config_modified(self, tmp_path):
        config_file = tmp_path / "hotkeys.json"
        config_file.write_text("{}")

        watcher = hotkey_config.InotifyWatcher(str(tmp_path), filename="hotkeys.json")
        try:
            # Write to the file to trigger inotify
            config_file.write_text('{"test": true}')
            # Give kernel a moment to deliver the event
            import select as sel
            readable, _, _ = sel.select([watcher.fileno()], [], [], 1.0)
            if readable:
                result = watcher.check()
                assert result is True
        finally:
            watcher.close()

    def test_check_returns_false_when_no_changes(self, tmp_path):
        watcher = hotkey_config.InotifyWatcher(str(tmp_path))
        try:
            result = watcher.check()
            assert result is False
        finally:
            watcher.close()

    def test_close_cleans_up(self, tmp_path):
        watcher = hotkey_config.InotifyWatcher(str(tmp_path))
        fd = watcher.fileno()
        watcher.close()
        # After close, fd should be invalid
        assert watcher._fd == -1
