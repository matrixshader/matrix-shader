"""Tests for redpill_tui.py -- TUI action handlers.

All shader_service functions are mocked. Tests verify that handle_action()
dispatches correctly and updates internal state.
"""

import sys
import os
from unittest.mock import patch, MagicMock, call
from pytest import approx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Import real shader_service for constants, then import redpill_tui.
import shader_service
import redpill_tui
from redpill_tui import RedpillTUI, color_swatch, progress_bar, PRESET_ACTIONS, LAYER_ACTIONS
from redpill_keys import PARAM_DELTAS

# Create mock objects and patch them onto the redpill_tui module namespace
# (where `from shader_service import ...` bound them).
_write_shader_param = MagicMock()
_write_shader_params = MagicMock()
_read_shader_config = MagicMock(return_value=dict(shader_service.PARAM_DEFAULTS))
_get_ghostty_bus_names = MagicMock(return_value={})
_reload_ghostty = MagicMock()
_create_slot_shader = MagicMock()

redpill_tui.write_shader_param = _write_shader_param
redpill_tui.write_shader_params = _write_shader_params
redpill_tui.read_shader_config = _read_shader_config
redpill_tui.get_ghostty_bus_names = _get_ghostty_bus_names
redpill_tui.reload_ghostty = _reload_ghostty
redpill_tui.create_slot_shader = _create_slot_shader


def _make_tui(slot=1, config=None):
    """Create a RedpillTUI with a mocked active slot."""
    tui = RedpillTUI()
    tui.active_slot = slot
    tui.tabs = [(slot, 0.0, 1.0, 0.3)]
    if config:
        tui.config = config
    else:
        tui.config = dict(shader_service.PARAM_DEFAULTS)
    return tui


def _reset_mocks():
    _write_shader_param.reset_mock()
    _write_shader_params.reset_mock()
    _read_shader_config.reset_mock()
    _read_shader_config.return_value = dict(shader_service.PARAM_DEFAULTS)
    _get_ghostty_bus_names.reset_mock()
    _get_ghostty_bus_names.return_value = {}
    _reload_ghostty.reset_mock()
    _create_slot_shader.reset_mock()
    # Re-install mocks on redpill_tui in case conftest restored originals
    redpill_tui.write_shader_param = _write_shader_param
    redpill_tui.write_shader_params = _write_shader_params
    redpill_tui.read_shader_config = _read_shader_config
    redpill_tui.get_ghostty_bus_names = _get_ghostty_bus_names
    redpill_tui.reload_ghostty = _reload_ghostty
    redpill_tui.create_slot_shader = _create_slot_shader


# -----------------------------------------------------------------------
# Rendering helpers
# -----------------------------------------------------------------------

class TestColorSwatch:
    def test_green(self):
        result = color_swatch(0.0, 1.0, 0.0)
        assert "\033[48;2;0;255;0m" in result
        assert "\033[0m" in result

    def test_white(self):
        result = color_swatch(1.0, 1.0, 1.0, width=3)
        assert "\033[48;2;255;255;255m" in result
        assert "   " in result

    def test_clamps(self):
        result = color_swatch(-1.0, 2.0, 0.5)
        assert "\033[48;2;0;255;127m" in result


class TestProgressBar:
    def test_full(self):
        assert progress_bar(5.0, 0.0, 5.0) == "=" * 15

    def test_empty(self):
        assert progress_bar(0.0, 0.0, 5.0) == "-" * 15

    def test_half(self):
        bar = progress_bar(2.5, 0.0, 5.0)
        assert "=" in bar and "-" in bar

    def test_bad_range(self):
        assert progress_bar(5.0, 5.0, 5.0) == "-" * 15


# -----------------------------------------------------------------------
# Preset actions
# -----------------------------------------------------------------------

class TestPresetActions:
    def setup_method(self):
        _reset_mocks()

    def test_preset_green(self):
        tui = _make_tui()
        tui.handle_action("PresetGreen")
        _write_shader_params.assert_called_once_with(
            1, {"RAIN_R": 0.0, "RAIN_G": 1.0, "RAIN_B": 0.3}
        )
        assert tui.config["RAIN_R"] == 0.0
        assert tui.config["RAIN_G"] == 1.0
        assert tui.config["RAIN_B"] == 0.3

    def test_preset_blue(self):
        tui = _make_tui()
        tui.handle_action("PresetBlue")
        _write_shader_params.assert_called_once_with(
            1, {"RAIN_R": 0.0, "RAIN_G": 0.6, "RAIN_B": 1.0}
        )

    def test_preset_red(self):
        tui = _make_tui()
        tui.handle_action("PresetRed")
        _write_shader_params.assert_called_once_with(
            1, {"RAIN_R": 1.0, "RAIN_G": 0.1, "RAIN_B": 0.1}
        )

    def test_preset_purple(self):
        tui = _make_tui()
        tui.handle_action("PresetPurple")
        _write_shader_params.assert_called_once_with(
            1, {"RAIN_R": 0.7, "RAIN_G": 0.0, "RAIN_B": 1.0}
        )

    def test_preset_gold(self):
        tui = _make_tui()
        tui.handle_action("PresetGold")
        _write_shader_params.assert_called_once_with(
            1, {"RAIN_R": 1.0, "RAIN_G": 0.7, "RAIN_B": 0.0}
        )

    def test_preset_teal(self):
        tui = _make_tui()
        tui.handle_action("PresetTeal")
        _write_shader_params.assert_called_once_with(
            1, {"RAIN_R": 0.0, "RAIN_G": 0.9, "RAIN_B": 0.9}
        )

    def test_all_presets_covered(self):
        """Every PRESET_ACTIONS entry maps to a valid PRESET_COLORS index."""
        assert len(PRESET_ACTIONS) == 6
        for action, idx in PRESET_ACTIONS.items():
            assert 0 <= idx < 6

    def test_preset_updates_tab_color(self):
        tui = _make_tui()
        tui.handle_action("PresetRed")
        assert tui.tabs[0] == (1, 1.0, 0.1, 0.1)


# -----------------------------------------------------------------------
# Parameter adjustment actions
# -----------------------------------------------------------------------

class TestParameterActions:
    def setup_method(self):
        _reset_mocks()

    def test_speed_increase(self):
        tui = _make_tui()
        tui.handle_action("SpeedIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_SPEED"] == approx(0.9)

    def test_speed_decrease(self):
        tui = _make_tui()
        tui.handle_action("SpeedDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_SPEED"] == approx(0.7)

    def test_glow_increase(self):
        tui = _make_tui()
        tui.handle_action("GlowIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["GLOW_STRENGTH"] == approx(0.9)

    def test_glow_decrease(self):
        tui = _make_tui()
        tui.handle_action("GlowDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["GLOW_STRENGTH"] == approx(0.7)

    def test_width_increase(self):
        tui = _make_tui()
        tui.handle_action("WidthIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["CHAR_WIDTH"] == approx(11.0)

    def test_width_decrease(self):
        tui = _make_tui()
        tui.handle_action("WidthDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["CHAR_WIDTH"] == approx(9.0)

    def test_trail_increase(self):
        tui = _make_tui()
        tui.handle_action("TrailIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["TRAIL_POWER"] == approx(8.5)

    def test_trail_decrease(self):
        tui = _make_tui()
        tui.handle_action("TrailDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["TRAIL_POWER"] == approx(7.5)

    def test_density_increase(self):
        tui = _make_tui()
        tui.handle_action("DensityIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_DENSITY"] == approx(0.5)

    def test_density_decrease(self):
        tui = _make_tui()
        tui.handle_action("DensityDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_DENSITY"] == approx(0.3)

    def test_red_increase(self):
        tui = _make_tui()
        tui.handle_action("RedIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_R"] == approx(0.05)

    def test_red_decrease_clamped(self):
        """RAIN_R starts at 0.0, decrease should clamp to 0.0."""
        tui = _make_tui()
        tui.handle_action("RedDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_R"] == approx(0.0)

    def test_green_increase(self):
        tui = _make_tui()
        tui.handle_action("GreenIncrease")
        # 1.0 + 0.05 = 1.05, clamped to 1.0
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_G"] == approx(1.0)

    def test_blue_decrease(self):
        tui = _make_tui()
        tui.handle_action("BlueDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_B"] == approx(0.25)

    def test_blue_increase(self):
        tui = _make_tui()
        tui.handle_action("BlueIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_B"] == approx(0.35)

    def test_speed_clamps_at_max(self):
        tui = _make_tui(config={**shader_service.PARAM_DEFAULTS, "RAIN_SPEED": 5.0})
        tui.handle_action("SpeedIncrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_SPEED"] == approx(5.0)

    def test_speed_clamps_at_min(self):
        tui = _make_tui(config={**shader_service.PARAM_DEFAULTS, "RAIN_SPEED": 0.1})
        tui.handle_action("SpeedDecrease")
        _write_shader_param.assert_called_once()
        assert tui.config["RAIN_SPEED"] == approx(0.1)

    def test_rgb_change_updates_tab_color(self):
        tui = _make_tui()
        tui.handle_action("RedIncrease")
        assert tui.tabs[0][1] == approx(0.05)  # r changed

    def test_all_param_deltas_handled(self):
        """Every PARAM_DELTAS entry is dispatched by handle_action."""
        for action in PARAM_DELTAS:
            _reset_mocks()
            tui = _make_tui()
            tui.handle_action(action)
            assert _write_shader_param.called, f"{action} did not call write_shader_param"


# -----------------------------------------------------------------------
# Layer toggle actions
# -----------------------------------------------------------------------

class TestLayerActions:
    def setup_method(self):
        _reset_mocks()

    def test_layer1_toggle_off(self):
        """SHOW_L1 starts at 1.0, toggle should set to 0.0."""
        tui = _make_tui()
        tui.handle_action("Layer1Toggle")
        _write_shader_param.assert_called_once_with(1, "SHOW_L1", 0.0)
        assert tui.config["SHOW_L1"] == 0.0

    def test_layer1_toggle_on(self):
        """SHOW_L1 at 0.0, toggle should set to 1.0."""
        tui = _make_tui(config={**shader_service.PARAM_DEFAULTS, "SHOW_L1": 0.0})
        tui.handle_action("Layer1Toggle")
        _write_shader_param.assert_called_once_with(1, "SHOW_L1", 1.0)
        assert tui.config["SHOW_L1"] == 1.0

    def test_layer2_toggle(self):
        tui = _make_tui()
        tui.handle_action("Layer2Toggle")
        _write_shader_param.assert_called_once_with(1, "SHOW_L2", 0.0)

    def test_layer3_toggle(self):
        tui = _make_tui()
        tui.handle_action("Layer3Toggle")
        _write_shader_param.assert_called_once_with(1, "SHOW_L3", 0.0)

    def test_all_layers_covered(self):
        assert len(LAYER_ACTIONS) == 3
        for action, param in LAYER_ACTIONS.items():
            assert param.startswith("SHOW_L")


# -----------------------------------------------------------------------
# No active slot -- all actions should be no-ops
# -----------------------------------------------------------------------

class TestNoActiveSlot:
    def setup_method(self):
        _reset_mocks()

    def _make_empty_tui(self):
        tui = RedpillTUI()
        tui.active_slot = None
        tui.tabs = []
        return tui

    def test_preset_no_crash(self):
        tui = self._make_empty_tui()
        tui.handle_action("PresetGreen")
        _write_shader_params.assert_not_called()

    def test_param_no_crash(self):
        tui = self._make_empty_tui()
        tui.handle_action("SpeedIncrease")
        _write_shader_param.assert_not_called()

    def test_layer_no_crash(self):
        tui = self._make_empty_tui()
        tui.handle_action("Layer1Toggle")
        _write_shader_param.assert_not_called()

    def test_reset_no_crash(self):
        tui = self._make_empty_tui()
        tui.handle_action("Reset")
        _write_shader_params.assert_not_called()


# -----------------------------------------------------------------------
# Opacity actions
# -----------------------------------------------------------------------

class TestOpacityActions:
    def setup_method(self):
        _reset_mocks()

    def test_transparency_toggle_on(self):
        tui = _make_tui()
        tui.transparency = False
        tui.opacity = 80
        with patch.object(tui, "_apply_opacity") as mock_apply:
            tui.handle_action("TransparencyToggle")
            assert tui.transparency is True
            mock_apply.assert_called_once_with(80)

    def test_transparency_toggle_off(self):
        tui = _make_tui()
        tui.transparency = True
        with patch.object(tui, "_apply_opacity") as mock_apply:
            tui.handle_action("TransparencyToggle")
            assert tui.transparency is False
            mock_apply.assert_called_once_with(100)

    def test_opacity_decrease(self):
        tui = _make_tui()
        tui.opacity = 80
        tui.transparency = True
        with patch.object(tui, "_apply_opacity") as mock_apply:
            tui.handle_action("OpacityDecrease")
            assert tui.opacity == 75
            mock_apply.assert_called_once_with(75)

    def test_opacity_increase(self):
        tui = _make_tui()
        tui.opacity = 80
        tui.transparency = True
        with patch.object(tui, "_apply_opacity") as mock_apply:
            tui.handle_action("OpacityIncrease")
            assert tui.opacity == 85
            mock_apply.assert_called_once_with(85)

    def test_opacity_clamp_min(self):
        tui = _make_tui()
        tui.opacity = 0
        tui.transparency = True
        with patch.object(tui, "_apply_opacity"):
            tui.handle_action("OpacityDecrease")
            assert tui.opacity == 0

    def test_opacity_clamp_max(self):
        tui = _make_tui()
        tui.opacity = 100
        tui.transparency = True
        with patch.object(tui, "_apply_opacity"):
            tui.handle_action("OpacityIncrease")
            assert tui.opacity == 100

    def test_opacity_no_apply_when_transparency_off(self):
        """C# behavior: opacity doesn't change at all when transparency is off."""
        tui = _make_tui()
        tui.opacity = 80
        tui.transparency = False
        with patch.object(tui, "_apply_opacity") as mock_apply:
            tui.handle_action("OpacityDecrease")
            assert tui.opacity == 80  # Unchanged -- matches C# HandleKey
            mock_apply.assert_not_called()


# -----------------------------------------------------------------------
# Deploy actions
# -----------------------------------------------------------------------

class TestDeployActions:
    def setup_method(self):
        _reset_mocks()

    def test_launch_increase(self):
        tui = _make_tui()
        tui.launch_count = 0
        tui.handle_action("LaunchIncrease")
        assert tui.launch_count == 1

    def test_launch_decrease(self):
        tui = _make_tui()
        tui.launch_count = 2
        tui.handle_action("LaunchDecrease")
        assert tui.launch_count == 1

    def test_launch_decrease_clamp(self):
        tui = _make_tui()
        tui.launch_count = 0
        tui.handle_action("LaunchDecrease")
        assert tui.launch_count == 0

    def test_launch_zero_noop(self):
        tui = _make_tui()
        tui.launch_count = 0
        with patch.object(tui, "_deploy_windows") as mock_deploy:
            tui.handle_action("Launch")
            mock_deploy.assert_not_called()

    def test_launch_deploys(self):
        tui = _make_tui()
        tui.launch_count = 2
        with patch.object(tui, "_deploy_windows") as mock_deploy:
            tui.handle_action("Launch")
            mock_deploy.assert_called_once_with(2)

    def test_deploy_finds_available_slots(self):
        _get_ghostty_bus_names.return_value = {
            1: {"pid": "1", "bus_name": "a"},
            3: {"pid": "3", "bus_name": "c"},
        }
        _read_shader_config.return_value = dict(shader_service.PARAM_DEFAULTS)
        tui = _make_tui()
        with patch.object(tui, "_launch_ghostty_window"):
            tui._deploy_windows(2)
        # Should pick slots 2 and 4 (skipping 1 and 3)
        calls = _create_slot_shader.call_args_list
        assert calls[0] == call(2, preset_idx=0)
        assert calls[1] == call(4, preset_idx=0)

    def test_deploy_resets_count(self):
        _get_ghostty_bus_names.return_value = {}
        _read_shader_config.return_value = dict(shader_service.PARAM_DEFAULTS)
        tui = _make_tui()
        tui.launch_count = 3
        with patch.object(tui, "_launch_ghostty_window"):
            tui._deploy_windows(3)
        assert tui.launch_count == 0


# -----------------------------------------------------------------------
# Tab navigation
# -----------------------------------------------------------------------

class TestTabNavigation:
    def setup_method(self):
        _reset_mocks()
        _read_shader_config.return_value = dict(shader_service.PARAM_DEFAULTS)

    def test_tab_forward(self):
        tui = RedpillTUI()
        tui.tabs = [(1, 0, 1, 0.3), (2, 0, 0.6, 1), (3, 1, 0.1, 0.1)]
        tui.active_slot = 1
        tui.handle_action("Tab")
        assert tui.active_slot == 2

    def test_tab_wraps(self):
        tui = RedpillTUI()
        tui.tabs = [(1, 0, 1, 0.3), (2, 0, 0.6, 1)]
        tui.active_slot = 2
        tui.handle_action("Tab")
        assert tui.active_slot == 1

    def test_shifttab_backward(self):
        tui = RedpillTUI()
        tui.tabs = [(1, 0, 1, 0.3), (2, 0, 0.6, 1)]
        tui.active_slot = 1
        tui.handle_action("ShiftTab")
        assert tui.active_slot == 2

    def test_tab_empty(self):
        tui = RedpillTUI()
        tui.tabs = []
        tui.active_slot = None
        tui.handle_action("Tab")
        assert tui.active_slot is None


# -----------------------------------------------------------------------
# Reset action
# -----------------------------------------------------------------------

class TestResetAction:
    def setup_method(self):
        _reset_mocks()

    def test_reset_writes_defaults(self):
        tui = _make_tui(config={**shader_service.PARAM_DEFAULTS, "RAIN_SPEED": 3.0})
        tui.handle_action("Reset")
        _write_shader_params.assert_called_once()
        params = _write_shader_params.call_args[0][1]
        assert params == shader_service.PARAM_DEFAULTS

    def test_reset_restores_config(self):
        tui = _make_tui(config={**shader_service.PARAM_DEFAULTS, "RAIN_SPEED": 5.0})
        tui.handle_action("Reset")
        assert tui.config["RAIN_SPEED"] == 0.8


# -----------------------------------------------------------------------
# Quit action
# -----------------------------------------------------------------------

class TestQuitAction:
    def test_quit_sets_running_false(self):
        tui = _make_tui()
        assert tui.running is True
        tui.handle_action("Quit")
        assert tui.running is False
