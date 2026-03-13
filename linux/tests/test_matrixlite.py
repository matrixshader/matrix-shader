"""Tests for matrixlite.py — MatrixLite text-mode Matrix rain.

TDD port from C# MatrixShader.Lite/ (Column.cs, TextMatrixRenderer.cs,
FallbackMenu.cs, KatakanaChars.cs, ColorPresets.cs).
"""

import os
import sys
import random
from unittest.mock import patch, MagicMock

import pytest

# Ensure linux/ is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


class TestColumn:
    """Port of Column.cs behavior tests."""

    def test_init_head_y_in_range(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        assert -20 <= col.head_y <= -1

    def test_init_speed_in_range(self):
        from matrixlite import Column
        for seed in range(20):
            rng = random.Random(seed)
            col = Column(0, 50, rng=rng)
            assert 1 <= col.speed <= 3

    def test_init_trail_length_in_range(self):
        from matrixlite import Column
        for seed in range(20):
            rng = random.Random(seed)
            col = Column(0, 50, rng=rng)
            assert 8 <= col.trail_length <= 24  # C# Next(8, 25) -> 8..24

    def test_update_returns_false_when_tick_less_than_speed(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        col.speed = 3
        col._tick_counter = 0
        result = col.update()
        assert result is False

    def test_update_increments_head_y_on_tick(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        col.speed = 1
        col._tick_counter = 0
        old_y = col.head_y
        col.update()
        assert col.head_y == old_y + 1

    def test_column_becomes_inactive_off_screen(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 10, rng=rng)
        col.head_y = 10 + col.trail_length  # Just at boundary
        col.speed = 1
        col._tick_counter = 0
        col.update()
        assert col.head_y - col.trail_length > 10
        assert col.is_active is False

    def test_brightness_head_is_one(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        assert col.brightness(0) == pytest.approx(1.0)

    def test_brightness_tail_is_near_zero(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        assert col.brightness(col.trail_length - 1) < 0.1

    def test_brightness_negative_index_returns_zero(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        assert col.brightness(-1) == 0.0

    def test_brightness_beyond_trail_returns_zero(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        assert col.brightness(col.trail_length) == 0.0

    def test_reset_reinitializes(self):
        from matrixlite import Column
        rng = random.Random(42)
        col = Column(0, 50, rng=rng)
        col.head_y = 999
        col._active = False
        col.reset()
        assert -20 <= col.head_y <= -1
        assert col.is_active is True


class TestRenderer:
    """Port of TextMatrixRenderer.cs behavior tests."""

    def test_creates_correct_number_of_columns(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=10, height=5)
        assert len(renderer._columns) == 10

    def test_render_frame_contains_ansi_escape(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=10, height=5)
        frame = renderer.render_frame()
        assert '\x1b[' in frame

    def test_render_frame_starts_with_home(self):
        from matrixlite import TextMatrixRenderer, HOME
        renderer = TextMatrixRenderer(width=10, height=5)
        frame = renderer.render_frame()
        assert frame.startswith(HOME)

    def test_render_frame_ends_with_reset(self):
        from matrixlite import TextMatrixRenderer, RESET
        renderer = TextMatrixRenderer(width=10, height=5)
        frame = renderer.render_frame()
        assert frame.endswith(RESET)

    def test_head_characters_render_white(self):
        from matrixlite import TextMatrixRenderer
        rng = random.Random(42)
        renderer = TextMatrixRenderer(width=80, height=24)
        renderer._rng = rng
        # Force a column to have visible head
        renderer._columns[0].head_y = 2
        renderer._columns[0]._active = True
        renderer._columns[0].speed = 1
        frame = renderer.render_frame()
        assert '255;255;255' in frame

    def test_trail_uses_color_brightness(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=80, height=24)
        # Force columns to be visible with trail on screen
        for col in renderer._columns[:5]:
            col.head_y = 15
            col._active = True
            col.speed = 1
        frame = renderer.render_frame()
        # Should have non-white, non-zero color codes from trail
        assert '\x1b[38;2;' in frame

    def test_inactive_positions_are_spaces(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=10, height=5)
        # Force all columns inactive and off screen
        for col in renderer._columns:
            col._active = False
        frame = renderer.render_frame()
        # Frame should be mostly spaces (between HOME and RESET)
        assert '  ' in frame


class TestColorPresets:
    """Port of ColorPresets.cs behavior tests."""

    def test_has_exactly_6_presets(self):
        from matrixlite import COLOR_PRESETS
        assert len(COLOR_PRESETS) == 6

    def test_green_rgb(self):
        from matrixlite import COLOR_PRESETS
        name, (r, g, b) = COLOR_PRESETS[0]
        assert (r, g, b) == (0, 255, 77)

    def test_blue_rgb(self):
        from matrixlite import COLOR_PRESETS
        name, (r, g, b) = COLOR_PRESETS[1]
        assert (r, g, b) == (0, 153, 255)

    def test_red_rgb(self):
        from matrixlite import COLOR_PRESETS
        name, (r, g, b) = COLOR_PRESETS[2]
        assert (r, g, b) == (255, 26, 26)

    def test_purple_rgb(self):
        from matrixlite import COLOR_PRESETS
        name, (r, g, b) = COLOR_PRESETS[3]
        assert (r, g, b) == (179, 0, 255)

    def test_gold_rgb(self):
        from matrixlite import COLOR_PRESETS
        name, (r, g, b) = COLOR_PRESETS[4]
        assert (r, g, b) == (255, 179, 0)

    def test_teal_rgb(self):
        from matrixlite import COLOR_PRESETS
        name, (r, g, b) = COLOR_PRESETS[5]
        assert (r, g, b) == (0, 230, 230)

    def test_preset_names(self):
        from matrixlite import COLOR_PRESETS
        names = [name for name, _ in COLOR_PRESETS]
        assert names == ['Green', 'Blue', 'Red', 'Purple', 'Gold', 'Teal']


class TestCharacterSet:
    """Port of KatakanaChars.cs behavior tests."""

    def test_katakana_range(self):
        from matrixlite import KATAKANA
        # Half-width Katakana U+FF66..U+FF9D
        assert KATAKANA[0] == chr(0xFF66)   # wo
        assert KATAKANA[-1] == chr(0xFF9D)  # n

    def test_katakana_length(self):
        from matrixlite import KATAKANA
        # U+FF66 to U+FF9D inclusive = 56 chars
        assert len(KATAKANA) == 56

    def test_all_chars_contains_katakana_digits_symbols(self):
        from matrixlite import ALL_CHARS, KATAKANA, DIGITS, SYMBOLS
        assert ALL_CHARS == KATAKANA + DIGITS + SYMBOLS

    def test_all_chars_length(self):
        from matrixlite import ALL_CHARS
        # 56 katakana + 10 digits + 9 symbols = 75
        assert len(ALL_CHARS) == 75


class TestKeyHandling:
    """Port of FallbackMenu key dispatch tests."""

    def test_keys_1_through_6_set_color(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        for i in range(1, 7):
            menu.handle_menu_key(ord(str(i)))
            assert menu.color_index == i - 1

    def test_key_e_decreases_speed(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._speed = 1.0
        menu.handle_menu_key(ord('e'))
        assert menu.speed == pytest.approx(0.9)

    def test_key_r_increases_speed(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._speed = 1.0
        menu.handle_menu_key(ord('r'))
        assert menu.speed == pytest.approx(1.1)

    def test_key_d_decreases_density(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._density = 0.4
        menu.handle_menu_key(ord('d'))
        assert menu.density == pytest.approx(0.3)

    def test_key_f_increases_density(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._density = 0.4
        menu.handle_menu_key(ord('f'))
        assert menu.density == pytest.approx(0.5)

    def test_speed_clamps_at_minimum(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._speed = 0.1
        menu.handle_menu_key(ord('e'))
        assert menu.speed == pytest.approx(0.1)

    def test_speed_clamps_at_maximum(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._speed = 3.0
        menu.handle_menu_key(ord('r'))
        assert menu.speed == pytest.approx(3.0)

    def test_density_clamps_at_minimum(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._density = 0.1
        menu.handle_menu_key(ord('d'))
        assert menu.density == pytest.approx(0.1)

    def test_density_clamps_at_maximum(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        menu._density = 1.0
        menu.handle_menu_key(ord('f'))
        assert menu.density == pytest.approx(1.0)

    def test_q_signals_quit(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        result = menu.handle_menu_key(ord('q'))
        assert result == 'quit'

    def test_esc_signals_quit(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        result = menu.handle_menu_key(27)
        assert result == 'quit'

    def test_enter_signals_start(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        result = menu.handle_menu_key(13)
        assert result == 'start'

    def test_effect_key_q_signals_stop(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        result = menu.handle_effect_key(ord('q'))
        assert result == 'stop'

    def test_effect_key_esc_signals_stop(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        result = menu.handle_effect_key(27)
        assert result == 'stop'

    def test_effect_key_color_changes(self):
        from matrixlite import LiteMenu
        menu = LiteMenu()
        result = menu.handle_effect_key(ord('3'))
        assert result is None
        assert menu.color_index == 2  # Red


class TestFullscreen:
    """Terminal setup/cleanup tests."""

    def test_initialize_contains_hide_cursor(self):
        from matrixlite import TextMatrixRenderer, HIDE_CURSOR
        renderer = TextMatrixRenderer(width=10, height=5)
        with patch('sys.stdout') as mock_out:
            mock_out.write = MagicMock()
            mock_out.flush = MagicMock()
            renderer.initialize()
            written = ''.join(call[0][0] for call in mock_out.write.call_args_list)
            assert HIDE_CURSOR in written

    def test_initialize_contains_clear_screen(self):
        from matrixlite import TextMatrixRenderer, CLEAR_SCREEN
        renderer = TextMatrixRenderer(width=10, height=5)
        with patch('sys.stdout') as mock_out:
            mock_out.write = MagicMock()
            mock_out.flush = MagicMock()
            renderer.initialize()
            written = ''.join(call[0][0] for call in mock_out.write.call_args_list)
            assert CLEAR_SCREEN in written

    def test_cleanup_contains_show_cursor(self):
        from matrixlite import TextMatrixRenderer, SHOW_CURSOR
        renderer = TextMatrixRenderer(width=10, height=5)
        with patch('sys.stdout') as mock_out:
            mock_out.write = MagicMock()
            mock_out.flush = MagicMock()
            renderer.cleanup()
            written = ''.join(call[0][0] for call in mock_out.write.call_args_list)
            assert SHOW_CURSOR in written

    def test_cleanup_contains_reset(self):
        from matrixlite import TextMatrixRenderer, RESET
        renderer = TextMatrixRenderer(width=10, height=5)
        with patch('sys.stdout') as mock_out:
            mock_out.write = MagicMock()
            mock_out.flush = MagicMock()
            renderer.cleanup()
            written = ''.join(call[0][0] for call in mock_out.write.call_args_list)
            assert RESET in written


class TestResize:
    """Terminal resize detection tests."""

    def test_detects_size_change(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=80, height=24)
        with patch('shutil.get_terminal_size', return_value=os.terminal_size((100, 30))):
            resized = renderer.check_and_handle_resize()
            assert resized is True

    def test_column_count_matches_new_width(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=80, height=24)
        with patch('shutil.get_terminal_size', return_value=os.terminal_size((100, 30))):
            renderer.check_and_handle_resize()
            assert len(renderer._columns) == 100

    def test_columns_have_new_max_y(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=80, height=24)
        with patch('shutil.get_terminal_size', return_value=os.terminal_size((100, 30))):
            renderer.check_and_handle_resize()
            assert renderer._columns[0].max_y == 30

    def test_no_resize_when_same_size(self):
        from matrixlite import TextMatrixRenderer
        renderer = TextMatrixRenderer(width=80, height=24)
        with patch('shutil.get_terminal_size', return_value=os.terminal_size((80, 24))):
            resized = renderer.check_and_handle_resize()
            assert resized is False


class TestEntryPoint:
    """CLI entry point tests."""

    def test_help_returns_zero(self):
        from matrixlite import main
        with patch('sys.stdout'):
            assert main(['--help']) == 0

    def test_help_outputs_usage(self):
        from matrixlite import main
        with patch('sys.stdout') as mock_out:
            mock_out.write = MagicMock()
            mock_out.flush = MagicMock()
            main(['--help'])
            written = ''.join(
                call[0][0] for call in mock_out.write.call_args_list
                if call[0][0] is not None
            )
            assert 'Usage' in written or 'matrixlite' in written

    def test_rain_starts_direct_mode(self):
        from matrixlite import main, LiteMenu
        with patch.object(LiteMenu, 'start_rain_direct') as mock_rain:
            assert main(['--rain']) == 0
            mock_rain.assert_called_once()

    def test_menu_skips_intro(self):
        from matrixlite import main, LiteMenu
        with patch.object(LiteMenu, 'run') as mock_run:
            assert main(['--menu']) == 0
            mock_run.assert_called_once()
