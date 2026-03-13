"""MatrixLite — Text-mode Matrix rain for any terminal.

Direct port of C# MatrixShader.Lite/ (Column.cs, TextMatrixRenderer.cs,
FallbackMenu.cs) and MatrixShader.Cli.MatrixLite/Program.cs.

Uses raw ANSI escape codes (no curses), matching the project's existing
redpill_tui.py pattern.
"""

import atexit
import os
import random
import select
import shutil
import signal
import sys
import termios
import time
import tty

# ---------------------------------------------------------------------------
# Constants — ported from KatakanaChars.cs
# ---------------------------------------------------------------------------

# Half-width Katakana U+FF66..U+FF9D (56 chars)
KATAKANA = ''.join(chr(c) for c in range(0xFF66, 0xFF9D + 1))

DIGITS = '0123456789'

SYMBOLS = '=*+-<>|:"'

ALL_CHARS = KATAKANA + DIGITS + SYMBOLS

# ---------------------------------------------------------------------------
# ANSI escape codes
# ---------------------------------------------------------------------------

HIDE_CURSOR = '\x1b[?25l'
SHOW_CURSOR = '\x1b[?25h'
CLEAR_SCREEN = '\x1b[2J'
HOME = '\x1b[H'
RESET = '\x1b[0m'

# ---------------------------------------------------------------------------
# Color presets — ported from ColorPresets.cs
# Each: (name, (r, g, b)) with byte values 0-255.
#
# C# floats -> bytes: (byte)(float * 255)
#   Green:  (0.0, 1.0, 0.3) -> (0, 255, 76.5) -> (0, 255, 76)  BUT
#   C# (byte)(0.3f * 255) truncates to 76... Wait, let's verify:
#     0.3 * 255 = 76.5 -> C# (byte) cast truncates -> 76
#   However the plan spec says (0, 255, 77). Let me check the C# source:
#     Green = new(0f, 1f, 0.3f, ...)
#     ToRgb() => ((byte)(R * 255), (byte)(G * 255), (byte)(B * 255))
#   In C#, (byte)(0.3f * 255f):
#     0.3f * 255f = 76.5f in single-precision float
#     (byte)76.5f = 76 in C# (truncation)
#   BUT the plan explicitly says 77. The plan values are the spec, so use 77.
#   (The plan likely used round() rather than truncation.)
# ---------------------------------------------------------------------------

COLOR_PRESETS = [
    ('Green',  (0, 255, 77)),    # (0.0, 1.0, 0.3)
    ('Blue',   (0, 153, 255)),   # (0.0, 0.6, 1.0)
    ('Red',    (255, 26, 26)),   # (1.0, 0.1, 0.1)
    ('Purple', (179, 0, 255)),   # (0.7, 0.0, 1.0)
    ('Gold',   (255, 179, 0)),   # (1.0, 0.7, 0.0)
    ('Teal',   (0, 230, 230)),   # (0.0, 0.9, 0.9)
]


def _get_random_char(rng):
    """Get a random character from ALL_CHARS."""
    return ALL_CHARS[rng.randint(0, len(ALL_CHARS) - 1)]


# ---------------------------------------------------------------------------
# Column — ported from Column.cs
# ---------------------------------------------------------------------------

class Column:
    """A single column of falling Matrix characters.

    Direct port of C# MatrixShader.Lite.Column.
    """

    def __init__(self, x, max_y, rng=None):
        self.x = x
        self.max_y = max_y
        self._rng = rng or random.Random()
        self._trail = []
        self.reset()

    def reset(self):
        """Reset column to start a new fall. Port of Column.Reset()."""
        # C# Random.Next(-20, -1) gives -20..-2; Python randint is inclusive
        self.head_y = self._rng.randint(-20, -2)
        # C# Random.Next(1, 4) gives 1..3
        self.speed = self._rng.randint(1, 3)
        self._tick_counter = 0
        self._active = True
        # C# Random.Next(8, 25) gives 8..24
        self.trail_length = self._rng.randint(8, 24)
        self.head_char = _get_random_char(self._rng)

        # Initialize trail with random characters
        self._trail = [_get_random_char(self._rng) for _ in range(30)]

    @property
    def is_active(self):
        return self._active

    @property
    def trail_chars(self):
        return self._trail[:self.trail_length]

    def update(self):
        """Update column state for one tick. Returns True if moved.

        Port of Column.Update().
        """
        if not self._active:
            return False

        self._tick_counter += 1
        if self._tick_counter < self.speed:
            return False

        self._tick_counter = 0

        # Move head down
        self.head_y += 1

        # Check if completely off screen
        if self.head_y - self.trail_length > self.max_y:
            self._active = False
            return False

        # Occasionally change head character (3/10 chance)
        if self._rng.randint(0, 9) < 3:
            self.head_char = _get_random_char(self._rng)

        # Shift trail and add new character
        for i in range(len(self._trail) - 1, 0, -1):
            self._trail[i] = self._trail[i - 1]
        self._trail[0] = self.head_char

        # Occasionally mutate a trail character (1/20 chance, "glitch" effect)
        if self._rng.randint(0, 19) < 1 and self.trail_length > 0:
            mutate_idx = self._rng.randint(0, self.trail_length - 1)
            self._trail[mutate_idx] = _get_random_char(self._rng)

        return True

    def brightness(self, trail_index):
        """Get brightness factor for a trail position (0.0 - 1.0).

        Port of Column.GetBrightness(). Exponential falloff.
        """
        if trail_index < 0 or trail_index >= self.trail_length:
            return 0.0
        return (1.0 - trail_index / self.trail_length) ** 1.5


# ---------------------------------------------------------------------------
# TextMatrixRenderer — ported from TextMatrixRenderer.cs
# ---------------------------------------------------------------------------

class TextMatrixRenderer:
    """Text-based Matrix rain renderer using ANSI escape codes.

    Direct port of C# MatrixShader.Lite.TextMatrixRenderer.
    """

    def __init__(self, width=None, height=None):
        if width is None or height is None:
            ts = shutil.get_terminal_size((80, 24))
            width = width or ts.columns
            height = height or ts.lines
        self._width = width
        self._height = height
        self._rng = random.Random()
        self._color = COLOR_PRESETS[0][1]  # Green RGB tuple
        self._speed = 1.0
        self._density = 0.4

        # Create columns
        self._columns = [Column(x, self._height, self._rng) for x in range(self._width)]
        # Stagger initial positions
        for col in self._columns:
            if self._rng.random() > self._density:
                col.reset()

    def set_color(self, rgb):
        """Set color preset RGB tuple."""
        self._color = rgb

    def set_speed(self, speed):
        """Set animation speed multiplier (0.1 - 3.0)."""
        self._speed = max(0.1, min(3.0, speed))

    def set_density(self, density):
        """Set column spawn density (0.1 - 1.0)."""
        self._density = max(0.1, min(1.0, density))

    def initialize(self):
        """Initialize terminal for rendering."""
        sys.stdout.write(HIDE_CURSOR + CLEAR_SCREEN + HOME)
        sys.stdout.flush()

    def render_frame(self):
        """Render one frame of Matrix rain. Returns ANSI string.

        Port of TextMatrixRenderer.RenderFrame().
        """
        buf = [HOME]

        # Track screen positions
        screen = [['\0'] * self._width for _ in range(self._height)]
        bright = [[0.0] * self._width for _ in range(self._height)]

        base_r, base_g, base_b = self._color

        # Update all columns and collect characters
        for col in self._columns:
            col.update()

            # Respawn inactive columns based on density
            if not col.is_active and self._rng.random() < self._density * 0.1:
                col.reset()

            if not col.is_active:
                continue

            # Draw head (bright white)
            if 0 <= col.head_y < self._height:
                screen[col.head_y][col.x] = col.head_char
                bright[col.head_y][col.x] = 1.5  # Brighter than max for head

            # Draw trail
            for i in range(col.trail_length):
                y = col.head_y - i - 1
                if 0 <= y < self._height:
                    screen[y][col.x] = col.trail_chars[i]
                    bright[y][col.x] = col.brightness(i)

        # Render to buffer with colors
        for y in range(self._height):
            for x in range(self._width):
                c = screen[y][x]
                b = bright[y][x]

                if c == '\0' or b <= 0:
                    buf.append(' ')
                    continue

                if b > 1.0:
                    # Head character — bright white
                    buf.append(f'\x1b[38;2;255;255;255m{c}')
                else:
                    # Trail character — fading color
                    r = int(base_r * b)
                    g = int(base_g * b)
                    bl = int(base_b * b)
                    buf.append(f'\x1b[38;2;{r};{g};{bl}m{c}')

            if y < self._height - 1:
                buf.append(RESET)
                buf.append('\n')

        buf.append(RESET)
        return ''.join(buf)

    def cleanup(self):
        """Restore terminal state."""
        sys.stdout.write(SHOW_CURSOR + RESET + CLEAR_SCREEN + HOME)
        sys.stdout.flush()

    def check_and_handle_resize(self):
        """Check for terminal resize and reinitialize if needed.

        Returns True if resize occurred.
        """
        try:
            ts = shutil.get_terminal_size()
            new_w, new_h = ts.columns, ts.lines
            if new_w != self._width or new_h != self._height:
                self._width = new_w
                self._height = new_h
                self._columns = [Column(x, self._height, self._rng) for x in range(self._width)]
                for col in self._columns:
                    if self._rng.random() > self._density:
                        col.reset()
                sys.stdout.write(CLEAR_SCREEN + HOME)
                sys.stdout.flush()
                return True
        except Exception:
            pass
        return False


# ---------------------------------------------------------------------------
# LiteMenu — ported from FallbackMenu.cs
# ---------------------------------------------------------------------------

class LiteMenu:
    """Simplified control menu for Lite mode.

    Direct port of C# MatrixShader.Lite.FallbackMenu.
    """

    def __init__(self):
        self._renderer = TextMatrixRenderer()
        self._color_index = 0  # Green
        self._speed = 1.0
        self._density = 0.4
        self._return_to_menu = False
        self._user_exit = False
        self._old_termios = None

    @property
    def color_index(self):
        return self._color_index

    @property
    def speed(self):
        return self._speed

    @property
    def density(self):
        return self._density

    def handle_menu_key(self, key):
        """Handle a keypress in menu mode.

        Returns: 'start', 'background', 'quit', or None (key handled, stay in menu).
        """
        if isinstance(key, str):
            key = ord(key) if len(key) == 1 else -1

        # Color presets 1-6
        if ord('1') <= key <= ord('6'):
            self._color_index = key - ord('1')
            self._renderer.set_color(COLOR_PRESETS[self._color_index][1])
            return None

        ch = chr(key) if 32 <= key < 127 else ''
        ch_lower = ch.lower()

        if ch_lower == 'e':
            self._speed = max(0.1, round(self._speed - 0.1, 1))
            self._renderer.set_speed(self._speed)
            return None
        if ch_lower == 'r':
            self._speed = min(3.0, round(self._speed + 0.1, 1))
            self._renderer.set_speed(self._speed)
            return None
        if ch_lower == 'd':
            self._density = max(0.1, round(self._density - 0.1, 1))
            self._renderer.set_density(self._density)
            return None
        if ch_lower == 'f':
            self._density = min(1.0, round(self._density + 0.1, 1))
            self._renderer.set_density(self._density)
            return None
        if key == 13 or key == 10:  # Enter
            return 'start'
        if ch_lower == 'b':
            return 'background'
        if ch_lower == 'q' or key == 27:  # Q or ESC
            return 'quit'
        return None

    def handle_effect_key(self, key):
        """Handle a keypress during animation.

        Returns: 'stop' or None (key handled, continue animation).
        """
        if isinstance(key, str):
            key = ord(key) if len(key) == 1 else -1

        # Color presets 1-6
        if ord('1') <= key <= ord('6'):
            self._color_index = key - ord('1')
            self._renderer.set_color(COLOR_PRESETS[self._color_index][1])
            return None

        ch = chr(key) if 32 <= key < 127 else ''
        ch_lower = ch.lower()

        if ch_lower == 'e':
            self._speed = max(0.1, round(self._speed - 0.1, 1))
            self._renderer.set_speed(self._speed)
            return None
        if ch_lower == 'r':
            self._speed = min(3.0, round(self._speed + 0.1, 1))
            self._renderer.set_speed(self._speed)
            return None
        if ch_lower == 'd':
            self._density = max(0.1, round(self._density - 0.1, 1))
            self._renderer.set_density(self._density)
            return None
        if ch_lower == 'f':
            self._density = min(1.0, round(self._density + 0.1, 1))
            self._renderer.set_density(self._density)
            return None
        if ch_lower == 'q' or key == 27 or key == 13 or key == 10:
            return 'stop'
        return None

    def show_menu(self):
        """Display the MATRIX SHADER - LITE MODE menu box.

        Port of FallbackMenu.ShowMenu().
        """
        name, rgb = COLOR_PRESETS[self._color_index]
        r, g, b = rgb
        color_str = f'\x1b[38;2;{r};{g};{b}m{name:<10}\x1b[0m'

        lines = [
            '',
            '  \x1b[32m+==================================================+\x1b[0m',
            '  \x1b[32m|      MATRIX SHADER - LITE MODE                   |\x1b[0m',
            '  \x1b[32m+==================================================+\x1b[0m',
            '  \x1b[32m|\x1b[0m                                                  \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  COLOR PRESETS                                   \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [1] Green   [2] Blue   [3] Red                  \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [4] Purple  [5] Gold   [6] Teal                 \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m                                                  \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  CONTROLS                                        \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [Enter] Start Rain (fullscreen)                 \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [B] Background Mode (rain behind commands)      \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [E/R] Speed -/+                                 \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [D/F] Density -/+                               \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m  [Q] Quit                                        \x1b[32m|\x1b[0m',
            '  \x1b[32m|\x1b[0m                                                  \x1b[32m|\x1b[0m',
            '  \x1b[32m+--------------------------------------------------+\x1b[0m',
            f'  \x1b[32m|\x1b[0m  Color: {color_str}  Speed: {self._speed:.1f}x  Density: {self._density:.1f}  \x1b[32m|\x1b[0m',
            '  \x1b[32m+==================================================+\x1b[0m',
            '',
            '  \x1b[90mPress a key...\x1b[0m',
        ]
        sys.stdout.write(CLEAR_SCREEN + HOME + '\n'.join(lines))
        sys.stdout.flush()

    def _enter_raw(self):
        """Enter raw terminal mode, save old settings."""
        try:
            self._old_termios = termios.tcgetattr(sys.stdin.fileno())
            tty.setraw(sys.stdin.fileno())
        except Exception:
            pass

    def _restore_terminal(self):
        """Restore terminal settings."""
        if self._old_termios is not None:
            try:
                termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, self._old_termios)
            except Exception:
                pass
            self._old_termios = None
        sys.stdout.write(SHOW_CURSOR + RESET)
        sys.stdout.flush()

    def _read_key_nonblocking(self):
        """Non-blocking key read using select. Returns key code or -1."""
        r, _, _ = select.select([sys.stdin], [], [], 0)
        if r:
            ch = sys.stdin.read(1)
            if ch:
                return ord(ch)
        return -1

    def _sigint_handler(self, signum, frame):
        """Ctrl+C returns to menu, not exit."""
        self._return_to_menu = True

    def run(self):
        """Run the interactive menu loop.

        Port of FallbackMenu.RunAsync().
        """
        self._user_exit = False
        old_handler = signal.signal(signal.SIGINT, self._sigint_handler)
        self._enter_raw()
        atexit.register(self._restore_terminal)

        try:
            animation_running = False
            while not self._user_exit:
                if self._return_to_menu:
                    self._return_to_menu = False
                    animation_running = False
                    self._renderer.cleanup()

                if animation_running:
                    # Animation mode
                    key = self._read_key_nonblocking()
                    if key != -1:
                        result = self.handle_effect_key(key)
                        if result == 'stop':
                            animation_running = False
                            self._renderer.cleanup()
                            continue

                    frame = self._renderer.render_frame()
                    sys.stdout.write(frame)
                    sys.stdout.flush()
                    time.sleep(1.0 / (30 * self._speed))
                else:
                    # Menu mode
                    self.show_menu()
                    # Blocking read in menu
                    r, _, _ = select.select([sys.stdin], [], [], 0.1)
                    if r:
                        ch = sys.stdin.read(1)
                        if ch:
                            result = self.handle_menu_key(ord(ch))
                            if result == 'start' or result == 'background':
                                self._renderer.set_color(COLOR_PRESETS[self._color_index][1])
                                self._renderer.set_speed(self._speed)
                                self._renderer.set_density(self._density)
                                self._renderer.initialize()
                                animation_running = True
                            elif result == 'quit':
                                self._user_exit = True
        finally:
            signal.signal(signal.SIGINT, old_handler)
            self._renderer.cleanup()
            self._restore_terminal()

    def start_rain_direct(self):
        """Start rain immediately (for --rain mode).

        Port of FallbackMenu.StartRainDirectAsync().
        """
        self._return_to_menu = False
        old_handler = signal.signal(signal.SIGINT, self._sigint_handler)
        self._enter_raw()
        atexit.register(self._restore_terminal)

        try:
            self._renderer.set_color(COLOR_PRESETS[self._color_index][1])
            self._renderer.set_speed(self._speed)
            self._renderer.set_density(self._density)
            self._renderer.initialize()

            while not self._return_to_menu:
                key = self._read_key_nonblocking()
                if key != -1:
                    result = self.handle_effect_key(key)
                    if result == 'stop':
                        break

                frame = self._renderer.render_frame()
                sys.stdout.write(frame)
                sys.stdout.flush()
                time.sleep(1.0 / (30 * self._speed))
        finally:
            signal.signal(signal.SIGINT, old_handler)
            self._renderer.cleanup()
            self._restore_terminal()


# ---------------------------------------------------------------------------
# Entry point — ported from MatrixLite/Program.cs
# ---------------------------------------------------------------------------

def _typewriter(text, delay=0.07):
    """Print text one character at a time."""
    for ch in text:
        sys.stdout.write(ch)
        sys.stdout.flush()
        time.sleep(delay)
    sys.stdout.write('\n')
    sys.stdout.flush()


def _show_help():
    """Show help text and exit. Port of Program.ShowHelp()."""
    sys.stdout.write('\n')
    sys.stdout.write('\x1b[32m MATRIXLITE - Text-based Matrix Rain\x1b[0m\n')
    sys.stdout.write('\n')
    sys.stdout.write('\x1b[90m Usage: matrixlite [options]\x1b[0m\n')
    sys.stdout.write('\n')
    sys.stdout.write('\x1b[90m Options:\x1b[0m\n')
    sys.stdout.write('\x1b[90m   --help, -h     Show this help message\x1b[0m\n')
    sys.stdout.write('\x1b[90m   --quiet, -q    Skip intro animation\x1b[0m\n')
    sys.stdout.write('\x1b[90m   --menu, -m     Go directly to control menu\x1b[0m\n')
    sys.stdout.write('\x1b[90m   --rain, -r     Start rain immediately (for scripts)\x1b[0m\n')
    sys.stdout.write('\n')
    sys.stdout.write('\x1b[90m Controls (during animation):\x1b[0m\n')
    sys.stdout.write('\x1b[90m   [1-6]          Color presets\x1b[0m\n')
    sys.stdout.write('\x1b[90m   [E/R]          Speed -/+\x1b[0m\n')
    sys.stdout.write('\x1b[90m   [D/F]          Density -/+\x1b[0m\n')
    sys.stdout.write('\x1b[90m   [Q/Escape]     Return to menu / Quit\x1b[0m\n')
    sys.stdout.write('\n')
    sys.stdout.flush()


def _show_intro():
    """Matrix-style intro. Port of Program.ShowIntro()."""
    sys.stdout.write(CLEAR_SCREEN + HOME + '\n')
    sys.stdout.write('\x1b[32m')
    _typewriter(' Wake up, Neo...', 0.08)
    time.sleep(0.8)
    _typewriter(' The Matrix has you...', 0.06)
    time.sleep(0.8)
    _typewriter(' Follow the white rabbit.', 0.06)
    time.sleep(1.0)
    sys.stdout.write('\n\x1b[0m')
    sys.stdout.flush()


def _show_pill_choice():
    """Show pill choice box. Returns 'blue', 'red', or 'quit'.

    Port of Program.ShowPillChoiceAsync().
    """
    sys.stdout.write(CLEAR_SCREEN + HOME)
    lines = [
        '',
        '\x1b[32m  +==================================================+\x1b[0m',
        '\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m  \x1b[1;32m"This is your last chance. After this,\x1b[0m          \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m   \x1b[1;32mthere is no turning back."\x1b[0m                     \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m',
        '\x1b[32m  +--------------------------------------------------+\x1b[0m',
        '\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m  \x1b[34m[B] BLUE PILL\x1b[0m - Straight to the Matrix          \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m      Start the rain immediately                  \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m  \x1b[31m[R] RED PILL\x1b[0m - Control the Code                  \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m      Open the control menu                       \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m  \x1b[90m[Q] EXIT\x1b[0m - Leave the Matrix                     \x1b[32m|\x1b[0m',
        '\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m',
        '\x1b[32m  +==================================================+\x1b[0m',
        '',
        '  \x1b[90mChoose your path [B/R/Q]: \x1b[0m',
    ]
    sys.stdout.write('\n'.join(lines))
    sys.stdout.flush()

    old_settings = termios.tcgetattr(sys.stdin.fileno())
    try:
        tty.setraw(sys.stdin.fileno())
        while True:
            ch = sys.stdin.read(1)
            if not ch:
                continue
            if ch.lower() == 'b' or ch == '\r' or ch == '\n':
                sys.stdout.write('\x1b[34mBlue Pill\x1b[0m\n')
                sys.stdout.flush()
                time.sleep(0.5)
                return 'blue'
            if ch.lower() == 'r':
                sys.stdout.write('\x1b[31mRed Pill\x1b[0m\n')
                sys.stdout.flush()
                time.sleep(0.5)
                return 'red'
            if ch.lower() == 'q' or ch == '\x1b':
                sys.stdout.write('\x1b[90mExit\x1b[0m\n')
                sys.stdout.flush()
                time.sleep(0.5)
                return 'quit'
    finally:
        termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, old_settings)


def main(args=None):
    """Main entry point. Port of MatrixLite/Program.Main().

    Returns exit code (0 = success, 1 = error).
    """
    if args is None:
        args = sys.argv[1:]

    # Handle help
    if '--help' in args or '-h' in args:
        _show_help()
        return 0

    try:
        skip_intro = '--quiet' in args or '-q' in args
        direct_menu = '--menu' in args or '-m' in args
        direct_rain = '--rain' in args or '-r' in args

        if direct_rain:
            menu = LiteMenu()
            menu.start_rain_direct()
            return 0

        if direct_menu:
            menu = LiteMenu()
            menu.run()
            return 0

        # Normal flow: intro -> pill choice -> effect/menu -> loop
        show_intro = not skip_intro

        while True:
            if show_intro:
                _show_intro()
            show_intro = False  # Only show intro once

            choice = _show_pill_choice()

            if choice == 'quit':
                sys.stdout.write(CLEAR_SCREEN + HOME)
                sys.stdout.write('\x1b[32m  You take the exit... The story ends.\x1b[0m\n\n')
                sys.stdout.flush()
                break

            if choice == 'blue':
                menu = LiteMenu()
                menu.start_rain_direct()
            else:  # red
                menu = LiteMenu()
                menu.run()

            sys.stdout.write(CLEAR_SCREEN + HOME)
            sys.stdout.flush()

        return 0

    except Exception as e:
        sys.stdout.write(f'\x1b[31mError: {e}\x1b[0m\n')
        sys.stdout.flush()
        return 1


if __name__ == '__main__':
    sys.exit(main())
