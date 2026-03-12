"""Hotkey configuration sub-screen for the Red Pill TUI.

Port of Windows HotkeyConfigScreen.cs. Provides arrow-key navigation,
Enter-to-edit, disable/enable toggle, reset-to-defaults, and save.
"""

import curses
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from hotkey_config import DEFAULT_BINDINGS, load_config, save_config, is_redpill


# Ordered list of all 13 actions (matches Windows display order)
ACTION_ORDER = [
    "SwapLeft", "SwapRight", "CycleLayout", "ToggleTransparency",
    "OpacityDown", "OpacityUp", "SpeedUp", "SpeedDown",
    "ToggleFar", "ToggleMid", "ToggleNear", "ShowHelp", "ManualReload",
]

# Human-readable display names (matches Windows GetActionDisplayName)
ACTION_DISPLAY_NAMES = {
    "SwapLeft":           "Swap Window Left",
    "SwapRight":          "Swap Window Right",
    "CycleLayout":        "Cycle Layout Mode",
    "ToggleTransparency": "Toggle Transparency",
    "OpacityDown":        "Decrease Opacity",
    "OpacityUp":          "Increase Opacity",
    "SpeedUp":            "Increase Speed",
    "SpeedDown":          "Decrease Speed",
    "ToggleFar":          "Toggle Far Layer",
    "ToggleMid":          "Toggle Mid Layer",
    "ToggleNear":         "Toggle Near Layer",
    "ShowHelp":           "Show Help",
    "ManualReload":       "Force Reload",
}

# Color pair indices (reuse from redpill_tui)
CP_GREEN = 1
CP_YELLOW = 2
CP_RED = 3
CP_CYAN = 4


def _safe_addstr(stdscr, row, col, text, attr=0):
    """addstr with bounds checking."""
    try:
        stdscr.addstr(row, col, text, attr)
    except curses.error:
        pass


def format_binding(binding):
    """Format a binding dict as 'Ctrl+Shift+Left'."""
    if not binding or not binding.get("enabled", True):
        return "[Disabled]"
    parts = list(binding.get("modifiers", []))
    parts.append(binding.get("key", "?"))
    return "+".join(parts)


class HotkeyConfigScreen:
    def __init__(self, config=None):
        if config is not None:
            self.config = config
        else:
            self.config = load_config()
        self.selected_index = 0
        self.edit_mode = False
        self.status_message = None
        self.actions = list(ACTION_ORDER)

    def get_display_name(self, action):
        """Get human-readable name for an action."""
        return ACTION_DISPLAY_NAMES.get(action, action)

    def move_selection(self, delta):
        """Move selection up (-1) or down (+1), clamped."""
        self.selected_index = max(0, min(len(self.actions) - 1, self.selected_index + delta))

    def toggle_disable(self):
        """Toggle enabled/disabled on the selected hotkey."""
        action = self.actions[self.selected_index]
        binding = self.config.get(action, {})
        currently_enabled = binding.get("enabled", True)
        binding["enabled"] = not currently_enabled
        self.config[action] = binding
        if binding["enabled"]:
            self.status_message = f"Enabled {self.get_display_name(action)}"
        else:
            self.status_message = f"Disabled {self.get_display_name(action)}"

    def reset_to_defaults(self):
        """Reset all bindings to defaults."""
        import copy
        self.config = copy.deepcopy(DEFAULT_BINDINGS)
        self.status_message = "Reset to defaults (press S to save)"

    def save(self):
        """Save config to hotkeys.json."""
        try:
            save_config(self.config)
            self.status_message = "Saved!"
            # Try conflict detection
            try:
                from hotkey_conflicts import detect_conflicts
                conflicts = detect_conflicts(self.config)
                if conflicts:
                    self.status_message = f"Saved! {len(conflicts)} conflict(s) detected."
            except ImportError:
                pass
        except Exception as e:
            self.status_message = f"Error saving: {e}"

    def enter_edit_mode(self):
        """Enter edit mode for the selected binding."""
        action = self.actions[self.selected_index]
        binding = self.config.get(action, {})
        if not binding.get("enabled", True):
            self.status_message = "Enable hotkey first (press D)"
            return
        self.edit_mode = True
        self.status_message = None

    def handle_edit_capture(self, key):
        """Process a key in edit mode. Returns True if edit ended."""
        if key == 27:  # Esc
            self.edit_mode = False
            self.status_message = None
            return True

        # Detect modifiers from curses key code
        # curses doesn't provide reliable modifier detection for arbitrary combos,
        # so we accept single keys as the "key" and let users specify modifiers
        # via the config file. For TUI edit mode, we capture the character and
        # assume Ctrl+Shift as default modifiers (matching the pattern of all defaults).
        key_name = None
        if 32 < key < 127:
            key_name = chr(key).upper()
        elif key == curses.KEY_LEFT:
            key_name = "Left"
        elif key == curses.KEY_RIGHT:
            key_name = "Right"
        elif key == curses.KEY_UP:
            key_name = "Up"
        elif key == curses.KEY_DOWN:
            key_name = "Down"
        elif key == curses.KEY_F5:
            key_name = "F5"

        if key_name is None:
            self.status_message = "Invalid key"
            return False

        action = self.actions[self.selected_index]
        self.config[action] = {
            "key": key_name,
            "modifiers": ["Ctrl", "Shift"],
            "enabled": True,
        }
        display = format_binding(self.config[action])
        self.status_message = f"Changed to {display} (press S to save)"
        self.edit_mode = False
        return True

    def render(self, stdscr):
        """Render the config screen."""
        stdscr.erase()
        row = 0

        _safe_addstr(stdscr, row, 1, "HOTKEY CONFIGURATION", curses.color_pair(CP_GREEN) | curses.A_BOLD)
        row += 1
        _safe_addstr(stdscr, row, 1, "Use arrows to navigate, Enter to edit, D to disable, R to reset all", curses.A_DIM)
        row += 2

        for i, action in enumerate(self.actions):
            binding = self.config.get(action, {})
            display_name = self.get_display_name(action)

            # Selection indicator
            if i == self.selected_index:
                indicator = " > "
                ind_attr = curses.color_pair(CP_GREEN) | curses.A_BOLD
            else:
                indicator = "   "
                ind_attr = 0

            _safe_addstr(stdscr, row, 0, indicator, ind_attr)
            _safe_addstr(stdscr, row, 3, f"{display_name:<24s}")

            if i == self.selected_index and self.edit_mode:
                _safe_addstr(stdscr, row, 27, "[Press new key combo...]",
                             curses.color_pair(CP_YELLOW) | curses.A_BOLD)
            elif not binding.get("enabled", True):
                _safe_addstr(stdscr, row, 27, "[Disabled]", curses.A_DIM)
            else:
                binding_str = format_binding(binding)
                _safe_addstr(stdscr, row, 27, binding_str, curses.color_pair(CP_CYAN))

            row += 1

        row += 1
        if self.status_message:
            _safe_addstr(stdscr, row, 1, self.status_message, curses.color_pair(CP_YELLOW))
        row += 2
        _safe_addstr(stdscr, row, 1, "[Enter] Edit  [D] Toggle disable  [R] Reset all  [S] Save  [Esc] Exit", curses.A_DIM)
        stdscr.refresh()

    def run(self, stdscr):
        """Main loop for the config screen."""
        if not is_redpill():
            _safe_addstr(stdscr, 0, 0, "Hotkey customization requires Red Pill.", curses.A_BOLD)
            _safe_addstr(stdscr, 1, 0, "Visit matrixshader.com/redpill", curses.A_DIM)
            stdscr.refresh()
            stdscr.getch()
            return

        while True:
            self.render(stdscr)
            key = stdscr.getch()

            if self.edit_mode:
                self.handle_edit_capture(key)
                continue

            if key == 27:  # Esc
                break
            elif key == curses.KEY_UP:
                self.move_selection(-1)
            elif key == curses.KEY_DOWN:
                self.move_selection(1)
            elif key == 10:  # Enter
                self.enter_edit_mode()
            elif key == ord('d') or key == ord('D'):
                self.toggle_disable()
            elif key == ord('r') or key == ord('R'):
                self.reset_to_defaults()
            elif key == ord('s') or key == ord('S'):
                self.save()

    # -------------------------------------------------------------------
    # ANSI mode (raw terminal, no curses) -- used by redpill_tui.py
    # -------------------------------------------------------------------

    def _render_ansi(self):
        """Render config screen using raw ANSI escape codes."""
        GREEN = "\x1b[32m"
        YELLOW = "\x1b[33m"
        CYAN = "\x1b[36m"
        GRAY = "\x1b[90m"
        RESET = "\x1b[0m"

        try:
            cw = max(80, os.get_terminal_size().columns)
            max_rows = os.get_terminal_size().lines
        except OSError:
            cw = 80
            max_rows = 24

        buf = []

        def padline(content):
            vlen = 0
            in_esc = False
            for c in content:
                if c == "\x1b":
                    in_esc = True
                    continue
                if in_esc:
                    if c.isalpha():
                        in_esc = False
                    continue
                vlen += 1
            pad = max(0, cw - vlen)
            buf.append(content + " " * pad + "\n")

        padline("")
        padline(f" {GREEN}HOTKEY CONFIGURATION{RESET}")
        padline(f" {GRAY}Use arrows to navigate, Enter to edit, D to disable, R to reset all{RESET}")
        padline("")

        for i, action in enumerate(self.actions):
            binding = self.config.get(action, {})
            display_name = self.get_display_name(action)

            if i == self.selected_index:
                indicator = f"{GREEN} > {RESET}"
            else:
                indicator = "   "

            if i == self.selected_index and self.edit_mode:
                binding_display = f"{YELLOW}[Press new key combo...]{RESET}"
            elif not binding.get("enabled", True):
                binding_display = f"{GRAY}[Disabled]{RESET}"
            else:
                binding_display = f"{CYAN}{format_binding(binding)}{RESET}"

            padline(f"{indicator}{display_name:<24s}{binding_display}")

        padline("")
        if self.status_message:
            padline(f" {YELLOW}{self.status_message}{RESET}")
        else:
            padline("")
        padline("")
        padline(f" {GRAY}[Enter] Edit  [D] Toggle disable  [R] Reset all  [S] Save  [Esc] Exit{RESET}")
        padline("")

        frame = "".join(buf)
        lines_written = frame.count("\n")
        remaining = max_rows - lines_written - 1
        if remaining > 0:
            blank = " " * cw + "\n"
            frame += blank * remaining

        sys.stdout.write("\x1b[H")
        sys.stdout.write(frame)
        sys.stdout.flush()

    def _handle_edit_capture_ansi(self, key_str):
        """Process a key in edit mode (raw terminal input). Returns True if edit ended."""
        if key_str == "\x1b":
            self.edit_mode = False
            self.status_message = None
            return True

        key_name = None
        if key_str == "LEFT":
            key_name = "Left"
        elif key_str == "RIGHT":
            key_name = "Right"
        elif key_str == "UP":
            key_name = "Up"
        elif key_str == "DOWN":
            key_name = "Down"
        elif len(key_str) == 1 and 32 < ord(key_str) < 127:
            key_name = key_str.upper()

        if key_name is None:
            self.status_message = "Invalid key"
            return False

        action = self.actions[self.selected_index]
        self.config[action] = {
            "key": key_name,
            "modifiers": ["Ctrl", "Shift"],
            "enabled": True,
        }
        display = format_binding(self.config[action])
        self.status_message = f"Changed to {display} (press S to save)"
        self.edit_mode = False
        return True

    def run_ansi(self):
        """Main loop using raw ANSI (no curses). Called from redpill_tui.py."""
        from redpill_tui import _read_key

        if not is_redpill():
            sys.stdout.write("\x1b[2J\x1b[H")
            sys.stdout.write(" Hotkey customization requires Red Pill.\n")
            sys.stdout.write(" Visit matrixshader.com/redpill\n\n")
            sys.stdout.write(" Press any key to return...\n")
            sys.stdout.flush()
            _read_key()
            return

        sys.stdout.write("\x1b[2J")
        sys.stdout.flush()

        while True:
            self._render_ansi()
            key_str = _read_key()

            if self.edit_mode:
                self._handle_edit_capture_ansi(key_str)
                continue

            if key_str == "\x1b":
                break
            elif key_str == "UP":
                self.move_selection(-1)
            elif key_str == "DOWN":
                self.move_selection(1)
            elif key_str in ("\n", "\r"):
                self.enter_edit_mode()
            elif key_str in ("d", "D"):
                self.toggle_disable()
            elif key_str in ("r", "R"):
                self.reset_to_defaults()
            elif key_str in ("s", "S"):
                self.save()
