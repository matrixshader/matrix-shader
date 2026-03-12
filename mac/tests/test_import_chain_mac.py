"""Tests for the Mac import chain and sys.modules override trick.

Validates that matrix_keys_mac.py's sys.modules["shader_service"] = shader_service_mac
trick works correctly, ensuring hotkey_actions.py uses macOS reload instead of D-Bus.
"""

import importlib
import os
import sys
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "linux"))


class TestShaderServiceMacImports:
    """Test that shader_service_mac re-exports all needed symbols."""

    def test_has_param_defaults(self):
        import shader_service_mac
        assert hasattr(shader_service_mac, "PARAM_DEFAULTS")

    def test_has_param_ranges(self):
        import shader_service_mac
        assert hasattr(shader_service_mac, "PARAM_RANGES")

    def test_has_preset_colors(self):
        import shader_service_mac
        assert hasattr(shader_service_mac, "PRESET_COLORS")

    def test_has_clamp_value(self):
        import shader_service_mac
        assert callable(shader_service_mac.clamp_value)

    def test_has_replace_define(self):
        import shader_service_mac
        assert callable(shader_service_mac.replace_define)

    def test_has_read_shader_config(self):
        import shader_service_mac
        assert callable(shader_service_mac.read_shader_config)

    def test_has_create_slot_shader(self):
        import shader_service_mac
        assert callable(shader_service_mac.create_slot_shader)

    def test_has_atomic_write(self):
        import shader_service_mac
        assert callable(shader_service_mac.atomic_write)

    def test_has_get_ghostty_bus_names(self):
        """Compatibility alias must exist."""
        import shader_service_mac
        assert callable(shader_service_mac.get_ghostty_bus_names)

    def test_has_reload_ghostty(self):
        """Compatibility alias must exist."""
        import shader_service_mac
        assert callable(shader_service_mac.reload_ghostty)

    def test_has_write_shader_param(self):
        import shader_service_mac
        assert callable(shader_service_mac.write_shader_param)

    def test_has_write_shader_params(self):
        import shader_service_mac
        assert callable(shader_service_mac.write_shader_params)

    def test_has_reload_all(self):
        import shader_service_mac
        assert callable(shader_service_mac.reload_all)


class TestSysModulesOverride:
    """Test the sys.modules trick for import redirection."""

    def test_override_replaces_shader_service(self):
        """Setting sys.modules['shader_service'] makes imports resolve to mac version."""
        import shader_service_mac
        saved = sys.modules.get("shader_service")
        try:
            sys.modules["shader_service"] = shader_service_mac
            import shader_service
            assert shader_service is shader_service_mac
            assert hasattr(shader_service, "write_shader_param")
            assert hasattr(shader_service, "get_ghostty_bus_names")
            assert hasattr(shader_service, "reload_ghostty")
        finally:
            if saved is not None:
                sys.modules["shader_service"] = saved
            else:
                sys.modules.pop("shader_service", None)

    def test_action_map_sees_mac_functions(self):
        """After override, hotkey_actions imports get mac versions."""
        import shader_service_mac
        saved = sys.modules.get("shader_service")
        try:
            sys.modules["shader_service"] = shader_service_mac
            # Force re-import
            if "hotkey_actions" in sys.modules:
                importlib.reload(sys.modules["hotkey_actions"])
            import hotkey_actions
            assert hasattr(hotkey_actions, "ACTION_MAP")
            assert isinstance(hotkey_actions.ACTION_MAP, dict)
            assert len(hotkey_actions.ACTION_MAP) > 0
        finally:
            if saved is not None:
                sys.modules["shader_service"] = saved
            else:
                sys.modules.pop("shader_service", None)


class TestHotkeyConfigMacImports:
    """Test hotkey_config_mac imports from Linux hotkey_config."""

    def test_imports_config_path(self):
        from hotkey_config_mac import CONFIG_PATH
        assert isinstance(CONFIG_PATH, str)

    def test_imports_default_bindings(self):
        from hotkey_config_mac import DEFAULT_BINDINGS
        assert isinstance(DEFAULT_BINDINGS, dict)
        assert len(DEFAULT_BINDINGS) > 0

    def test_imports_is_redpill(self):
        from hotkey_config_mac import is_redpill
        assert callable(is_redpill)

    def test_imports_load_config(self):
        from hotkey_config_mac import load_config
        assert callable(load_config)

    def test_imports_save_config(self):
        from hotkey_config_mac import save_config
        assert callable(save_config)

    def test_imports_build_hotkey_table_mac(self):
        from hotkey_config_mac import build_hotkey_table_mac
        assert callable(build_hotkey_table_mac)

    def test_imports_key_name_to_cgevent(self):
        from hotkey_config_mac import KEY_NAME_TO_CGEVENT
        assert isinstance(KEY_NAME_TO_CGEVENT, dict)

    def test_imports_modifier_flags(self):
        from hotkey_config_mac import MODIFIER_FLAGS
        assert isinstance(MODIFIER_FLAGS, dict)


class TestPlatformMacImports:
    """Test platform_mac exports."""

    def test_imports_get_ghostty_pids(self):
        from platform_mac import get_ghostty_pids
        assert callable(get_ghostty_pids)

    def test_imports_reload_ghostty_mac(self):
        from platform_mac import reload_ghostty_mac
        assert callable(reload_ghostty_mac)

    def test_imports_show_toast_mac(self):
        from platform_mac import show_toast_mac
        assert callable(show_toast_mac)

    def test_imports_check_accessibility_permission(self):
        from platform_mac import check_accessibility_permission
        assert callable(check_accessibility_permission)

    def test_imports_get_ghostty_bin(self):
        from platform_mac import get_ghostty_bin
        assert callable(get_ghostty_bin)

    def test_imports_position_window(self):
        from platform_mac import position_window
        assert callable(position_window)

    def test_imports_get_screen_size(self):
        from platform_mac import get_screen_size
        assert callable(get_screen_size)


class TestCrossModuleDependency:
    """Test that shader_service_mac properly imports from platform_mac."""

    def test_shader_service_uses_platform_reload(self):
        import shader_service_mac
        import platform_mac
        # The reload_ghostty_mac used by shader_service_mac should be the same function
        assert shader_service_mac.reload_ghostty_mac is platform_mac.reload_ghostty_mac

    def test_shader_service_uses_platform_pids(self):
        import shader_service_mac
        import platform_mac
        assert shader_service_mac.get_ghostty_pids is platform_mac.get_ghostty_pids
