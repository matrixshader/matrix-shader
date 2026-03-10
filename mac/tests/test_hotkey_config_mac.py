"""Tests for macOS hotkey configuration mapping."""

import os
import sys
import pytest

# Add paths
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "linux"))

from hotkey_config_mac import (
    KEY_NAME_TO_CGEVENT,
    MODIFIER_FLAGS,
    build_hotkey_table_mac,
)
from hotkey_config import DEFAULT_BINDINGS


class TestKeyMapping:
    """Test CGEvent key code mapping."""

    def test_all_default_keys_mapped(self):
        """All keys used in DEFAULT_BINDINGS have CGEvent mappings."""
        for action, binding in DEFAULT_BINDINGS.items():
            key_name = binding["key"]
            assert key_name in KEY_NAME_TO_CGEVENT, (
                f"Key '{key_name}' for action '{action}' not in KEY_NAME_TO_CGEVENT"
            )

    def test_all_modifiers_mapped(self):
        """All modifiers used in DEFAULT_BINDINGS have flag mappings."""
        for action, binding in DEFAULT_BINDINGS.items():
            for mod in binding.get("modifiers", []):
                assert mod in MODIFIER_FLAGS, (
                    f"Modifier '{mod}' for action '{action}' not in MODIFIER_FLAGS"
                )

    def test_key_codes_are_positive_integers(self):
        """All CGEvent key codes are positive integers."""
        for name, code in KEY_NAME_TO_CGEVENT.items():
            assert isinstance(code, int), f"Key '{name}' code is not int: {code}"
            assert code >= 0, f"Key '{name}' has negative code: {code}"

    def test_modifier_flags_are_bitmasks(self):
        """Modifier flags are valid bitmasks (powers of 2 shifted)."""
        for name, flag in MODIFIER_FLAGS.items():
            assert isinstance(flag, int), f"Modifier '{name}' flag is not int"
            assert flag > 0, f"Modifier '{name}' has zero/negative flag"

    def test_16_keys_mapped(self):
        """Exactly 16 keys are mapped (matching 16 hotkeys)."""
        assert len(KEY_NAME_TO_CGEVENT) == 16

    def test_4_modifiers_mapped(self):
        """4 modifier types are mapped (Ctrl, Shift, Alt, Super)."""
        assert len(MODIFIER_FLAGS) == 4


class TestHotkeyTable:
    """Test hotkey table building."""

    def test_build_default_table(self):
        """Default table has 16 entries (one per action)."""
        table = build_hotkey_table_mac(DEFAULT_BINDINGS)
        assert len(table) == 16

    def test_table_keys_are_tuples(self):
        """Table keys are (modifier_mask, keycode) tuples."""
        table = build_hotkey_table_mac(DEFAULT_BINDINGS)
        for key in table:
            assert isinstance(key, tuple), f"Key {key} is not tuple"
            assert len(key) == 2, f"Key {key} does not have 2 elements"
            mod_mask, keycode = key
            assert isinstance(mod_mask, int), f"Modifier mask {mod_mask} is not int"
            assert isinstance(keycode, int), f"Keycode {keycode} is not int"

    def test_table_values_are_action_names(self):
        """Table values are valid action name strings."""
        table = build_hotkey_table_mac(DEFAULT_BINDINGS)
        for action in table.values():
            assert isinstance(action, str)
            assert action in DEFAULT_BINDINGS

    def test_ctrl_shift_modifier_mask(self):
        """Default Ctrl+Shift modifier mask is correct."""
        expected_mask = MODIFIER_FLAGS["Ctrl"] | MODIFIER_FLAGS["Shift"]
        table = build_hotkey_table_mac(DEFAULT_BINDINGS)
        for (mod_mask, _), action in table.items():
            assert mod_mask == expected_mask, (
                f"Action '{action}' has unexpected modifier mask: "
                f"0x{mod_mask:08x} (expected 0x{expected_mask:08x})"
            )

    def test_disabled_binding_excluded(self):
        """Disabled bindings are not included in the table."""
        config = dict(DEFAULT_BINDINGS)
        config["SpeedUp"] = {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": False}
        table = build_hotkey_table_mac(config, is_redpill_flag=True)
        assert len(table) == 15  # 16 - 1 disabled

    def test_unknown_key_skipped(self):
        """Unknown key names are skipped without error."""
        config = dict(DEFAULT_BINDINGS)
        config["SpeedUp"] = {"key": "Unknown", "modifiers": ["Ctrl", "Shift"], "enabled": True}
        table = build_hotkey_table_mac(config, is_redpill_flag=True)
        assert len(table) == 15  # 16 - 1 unknown

    def test_redpill_flag_uses_config(self):
        """With redpill=True, uses provided config instead of defaults."""
        custom_config = {
            "SpeedUp": {"key": "Up", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        table = build_hotkey_table_mac(custom_config, is_redpill_flag=True)
        assert len(table) == 1
        # The key code for "Up" on macOS is 126
        assert (MODIFIER_FLAGS["Ctrl"] | MODIFIER_FLAGS["Shift"], 126) in table

    def test_redpill_false_ignores_config(self):
        """With redpill=False, uses DEFAULT_BINDINGS regardless of config."""
        custom_config = {
            "SpeedUp": {"key": "Up", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        table = build_hotkey_table_mac(custom_config, is_redpill_flag=False)
        assert len(table) == 16  # Uses all defaults, ignores custom
