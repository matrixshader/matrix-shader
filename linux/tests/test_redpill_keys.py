"""Tests for redpill_keys.py -- key-to-action mapping."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from redpill_keys import process_key, PARAM_DELTAS


class TestSpecialKeys:
    def test_tab(self):
        assert process_key(9) == "Tab"

    def test_enter(self):
        assert process_key(10) == "Launch"

    def test_escape(self):
        assert process_key(27) == "Quit"

    def test_shift_tab(self):
        assert process_key(353) == "ShiftTab"


class TestShiftCombinations:
    """Shift+letter detected via uppercase chars BEFORE lowercase fallback."""

    def test_shift_l_layout_cycle(self):
        assert process_key(ord('L')) == "LayoutCycle"

    def test_lowercase_l_opacity_increase(self):
        assert process_key(ord('l')) == "OpacityIncrease"

    def test_shift_s_snapback_save(self):
        assert process_key(ord('S')) == "SnapbackSave"

    def test_lowercase_s_green_increase(self):
        assert process_key(ord('s')) == "GreenIncrease"

    def test_shift_h_hotkey_config(self):
        assert process_key(ord('H')) == "HotkeyConfig"

    def test_lowercase_h_density_increase(self):
        assert process_key(ord('h')) == "DensityIncrease"

    def test_shift_g_glitch_toggle(self):
        assert process_key(ord('G')) == "GlitchToggle"

    def test_lowercase_g_density_decrease(self):
        assert process_key(ord('g')) == "DensityDecrease"

    def test_shift_r_snapback_restore(self):
        assert process_key(ord('R')) == "SnapbackRestore"

    def test_lowercase_r_speed_increase(self):
        assert process_key(ord('r')) == "SpeedIncrease"

    def test_question_mark_help(self):
        assert process_key(ord('?')) == "Help"


class TestColorPresets:
    def test_preset_green(self):
        assert process_key(ord('1')) == "PresetGreen"

    def test_preset_blue(self):
        assert process_key(ord('2')) == "PresetBlue"

    def test_preset_red(self):
        assert process_key(ord('3')) == "PresetRed"

    def test_preset_purple(self):
        assert process_key(ord('4')) == "PresetPurple"

    def test_preset_gold(self):
        assert process_key(ord('5')) == "PresetGold"

    def test_preset_teal(self):
        assert process_key(ord('6')) == "PresetTeal"


class TestRGBKeys:
    def test_red_decrease(self):
        assert process_key(ord('q')) == "RedDecrease"

    def test_red_increase(self):
        assert process_key(ord('w')) == "RedIncrease"

    def test_green_decrease(self):
        assert process_key(ord('a')) == "GreenDecrease"

    def test_green_increase(self):
        assert process_key(ord('s')) == "GreenIncrease"

    def test_blue_decrease(self):
        assert process_key(ord('z')) == "BlueDecrease"

    def test_blue_increase(self):
        assert process_key(ord('x')) == "BlueIncrease"


class TestParameterKeys:
    def test_speed_decrease(self):
        assert process_key(ord('e')) == "SpeedDecrease"

    def test_speed_increase(self):
        assert process_key(ord('r')) == "SpeedIncrease"

    def test_glow_decrease(self):
        assert process_key(ord('d')) == "GlowDecrease"

    def test_glow_increase(self):
        assert process_key(ord('f')) == "GlowIncrease"

    def test_width_decrease(self):
        assert process_key(ord('c')) == "WidthDecrease"

    def test_width_increase(self):
        assert process_key(ord('v')) == "WidthIncrease"

    def test_trail_decrease(self):
        assert process_key(ord('t')) == "TrailDecrease"

    def test_trail_increase(self):
        assert process_key(ord('y')) == "TrailIncrease"

    def test_density_decrease(self):
        assert process_key(ord('g')) == "DensityDecrease"

    def test_density_increase(self):
        assert process_key(ord('h')) == "DensityIncrease"


class TestLayerToggles:
    def test_layer1_far(self):
        assert process_key(ord('7')) == "Layer1Toggle"

    def test_layer2_mid(self):
        assert process_key(ord('8')) == "Layer2Toggle"

    def test_layer3_near(self):
        assert process_key(ord('9')) == "Layer3Toggle"


class TestOpacityKeys:
    def test_transparency_toggle(self):
        assert process_key(ord('b')) == "TransparencyToggle"

    def test_opacity_decrease(self):
        assert process_key(ord('k')) == "OpacityDecrease"

    def test_opacity_increase(self):
        assert process_key(ord('l')) == "OpacityIncrease"


class TestDeployKeys:
    def test_launch_decrease(self):
        assert process_key(ord('-')) == "LaunchDecrease"

    def test_launch_increase_plus(self):
        assert process_key(ord('+')) == "LaunchIncrease"

    def test_launch_increase_equals(self):
        assert process_key(ord('=')) == "LaunchIncrease"


class TestResetKey:
    def test_reset(self):
        assert process_key(ord('0')) == "Reset"


class TestUnknownKey:
    def test_unknown_returns_none(self):
        assert process_key(999) is None

    def test_space_returns_none(self):
        assert process_key(ord(' ')) is None

    def test_tilde_returns_none(self):
        assert process_key(ord('~')) is None


class TestParamDeltas:
    def test_speed_increase_delta(self):
        assert PARAM_DELTAS["SpeedIncrease"] == ("RAIN_SPEED", 0.1)

    def test_speed_decrease_delta(self):
        assert PARAM_DELTAS["SpeedDecrease"] == ("RAIN_SPEED", -0.1)

    def test_glow_increase_delta(self):
        assert PARAM_DELTAS["GlowIncrease"] == ("GLOW_STRENGTH", 0.1)

    def test_glow_decrease_delta(self):
        assert PARAM_DELTAS["GlowDecrease"] == ("GLOW_STRENGTH", -0.1)

    def test_width_increase_delta(self):
        assert PARAM_DELTAS["WidthIncrease"] == ("CHAR_WIDTH", 1.0)

    def test_width_decrease_delta(self):
        assert PARAM_DELTAS["WidthDecrease"] == ("CHAR_WIDTH", -1.0)

    def test_trail_increase_delta(self):
        assert PARAM_DELTAS["TrailIncrease"] == ("TRAIL_POWER", 0.5)

    def test_trail_decrease_delta(self):
        assert PARAM_DELTAS["TrailDecrease"] == ("TRAIL_POWER", -0.5)

    def test_density_increase_delta(self):
        assert PARAM_DELTAS["DensityIncrease"] == ("RAIN_DENSITY", 0.1)

    def test_density_decrease_delta(self):
        assert PARAM_DELTAS["DensityDecrease"] == ("RAIN_DENSITY", -0.1)

    def test_red_decrease_delta(self):
        assert PARAM_DELTAS["RedDecrease"] == ("RAIN_R", -0.05)

    def test_red_increase_delta(self):
        assert PARAM_DELTAS["RedIncrease"] == ("RAIN_R", 0.05)

    def test_green_decrease_delta(self):
        assert PARAM_DELTAS["GreenDecrease"] == ("RAIN_G", -0.05)

    def test_green_increase_delta(self):
        assert PARAM_DELTAS["GreenIncrease"] == ("RAIN_G", 0.05)

    def test_blue_decrease_delta(self):
        assert PARAM_DELTAS["BlueDecrease"] == ("RAIN_B", -0.05)

    def test_blue_increase_delta(self):
        assert PARAM_DELTAS["BlueIncrease"] == ("RAIN_B", 0.05)

    def test_total_count(self):
        assert len(PARAM_DELTAS) == 16
