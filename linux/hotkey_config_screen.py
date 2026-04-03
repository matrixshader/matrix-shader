"""Hotkey configuration sub-screen for the Red Pill TUI.

Port of Windows HotkeyConfigScreen.cs. Provides arrow-key navigation,
Enter-to-edit, disable/enable toggle, reset-to-defaults, and save.
"""

import curses
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from hotkey_config import DEFAULT_BINDINGS, load_config, save_config, is_redpill


# Ordered list of default-bound actions
ACTION_ORDER = [
    "SwapLeft", "SwapRight", "CycleLayout", "ToggleTransparency",
    "OpacityDown", "OpacityUp", "SpeedUp", "SpeedDown",
    "ToggleFar", "ToggleMid", "ToggleNear", "ShowHelp", "ManualReload",
    "SnapbackSave", "SnapbackRestore",
]

# ALL possible actions (includes user-addable ones with no default binding)
ALL_ACTIONS = ACTION_ORDER + [
    "GlowUp", "GlowDown", "WidthUp", "WidthDown",
    "TrailUp", "TrailDown", "DensityUp", "DensityDown",
    "RedUp", "RedDown", "GreenUp", "GreenDown", "BlueUp", "BlueDown",
]

# Human-readable display names
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
    "SnapbackSave":       "Save Snapback",
    "SnapbackRestore":    "Restore Snapback",
    "GlowUp":             "Increase Glow",
    "GlowDown":           "Decrease Glow",
    "WidthUp":            "Increase Width",
    "WidthDown":          "Decrease Width",
    "TrailUp":            "Increase Trail",
    "TrailDown":          "Decrease Trail",
    "DensityUp":          "Increase Density",
    "DensityDown":        "Decrease Density",
    "RedUp":              "Increase Red",
    "RedDown":            "Decrease Red",
    "GreenUp":            "Increase Green",
    "GreenDown":          "Decrease Green",
    "BlueUp":             "Increase Blue",
    "BlueDown":           "Decrease Blue",
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
    if not binding:
        return "[Unbound]"
    if not binding.get("enabled", True):
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
        # Include user-added actions from saved config
        for action in self.config:
            if action not in self.actions and action in ALL_ACTIONS:
                self.actions.append(action)

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

    # -------------------------------------------------------------------
    # Raw key reader (bypasses Python buffered IO)
    # -------------------------------------------------------------------

    @staticmethod
    def _read_raw_key():
        """Read a single keypress using raw os.read — handles escape sequences."""
        import select
        fd = sys.stdin.fileno()
        b = os.read(fd, 1)
        if not b:
            return None
        if b == b'\x1b':
            r, _, _ = select.select([fd], [], [], 0.1)
            if r:
                b2 = os.read(fd, 1)
                if b2 == b'[':
                    r2, _, _ = select.select([fd], [], [], 0.1)
                    if r2:
                        b3 = os.read(fd, 1)
                        if b3 == b'A': return "UP"
                        if b3 == b'B': return "DOWN"
                        if b3 == b'C': return "RIGHT"
                        if b3 == b'D': return "LEFT"
                        while select.select([fd], [], [], 0.01)[0]:
                            os.read(fd, 1)
                        return None
            return "ESC"
        if b in (b'\n', b'\r'): return "ENTER"
        if b[0] == 127: return "BACKSPACE"
        if 32 <= b[0] < 127: return chr(b[0])
        return None

    # -------------------------------------------------------------------
    # ANSI rendering (direct writes, no TuiRenderer)
    # -------------------------------------------------------------------

    def _render_ansi(self):
        """Render config screen — direct raw writes."""
        G = "\x1b[38;2;110;220;170m"
        Y = "\x1b[33m"
        C = "\x1b[36m"
        W = "\x1b[97m"
        D = "\x1b[90m"
        R = "\x1b[0m"

        sys.stdout.write("\x1b[H\x1b[2J")
        sys.stdout.write(f"\r\n {G}HOTKEY CONFIGURATION{R}\r\n")
        sys.stdout.write(f" {W}Arrows to navigate, Enter to edit, A to add, ESC to exit{R}\r\n\r\n")

        for i, action in enumerate(self.actions):
            binding = self.config.get(action, {})
            display_name = self.get_display_name(action)

            if i == self.selected_index:
                indicator = f"{G} > {R}"
            else:
                indicator = "   "

            if i == self.selected_index and self.edit_mode:
                binding_display = f"{Y}[Press new key...]{R}"
            elif not binding.get("enabled", True):
                binding_display = f"{D}[Disabled]{R}"
            elif not binding:
                binding_display = f"{D}[Unbound]{R}"
            else:
                binding_display = f"{C}{format_binding(binding)}{R}"

            sys.stdout.write(f"\r{indicator}{display_name:<24s}{binding_display}\r\n")

        sys.stdout.write("\r\n")
        if self.status_message:
            sys.stdout.write(f"\r {Y}{self.status_message}{R}\r\n")
        sys.stdout.write(f"\r\n {G}[Enter]{R} Edit  {G}[A]{R} Add  {G}[D]{R} Disable  {G}[X]{R} Remove  {G}[R]{R} Reset  {G}[S]{R} Save  {G}[ESC]{R} Exit\r\n")
        sys.stdout.flush()

    # -------------------------------------------------------------------
    # Edit capture (assign new key binding)
    # -------------------------------------------------------------------

    def _handle_edit_capture_ansi(self, key_str):
        """Process a key in edit mode."""
        if key_str == "ESC":
            self.edit_mode = False
            self.status_message = None
            return

        key_name = None
        if key_str == "LEFT":    key_name = "Left"
        elif key_str == "RIGHT": key_name = "Right"
        elif key_str == "UP":    key_name = "Up"
        elif key_str == "DOWN":  key_name = "Down"
        elif key_str and len(key_str) == 1 and 32 < ord(key_str) < 127:
            key_name = key_str.upper()

        if key_name is None:
            self.status_message = "Invalid key — use a letter, number, or arrow"
            return

        action = self.actions[self.selected_index]
        self.config[action] = {
            "key": key_name,
            "modifiers": ["Ctrl", "Shift"],
            "enabled": True,
        }
        display = format_binding(self.config[action])
        self.status_message = f"Changed to {display} (press S to save)"
        self.edit_mode = False

    # -------------------------------------------------------------------
    # Add picker — choose from unbound actions
    # -------------------------------------------------------------------

    def _do_add(self):
        """Show picker of all unbound actions. User selects one to add."""
        G = "\x1b[38;2;110;220;170m"
        W = "\x1b[97m"
        Y = "\x1b[33m"
        R = "\x1b[0m"

        # Find actions not currently in the config
        bound = set(self.actions)
        unbound = [a for a in ALL_ACTIONS if a not in bound]
        if not unbound:
            self.status_message = "All actions are already bound"
            return

        sel = 0
        while True:
            sys.stdout.write("\x1b[H\x1b[2J")
            sys.stdout.write(f"\r\n {G}ADD HOTKEY{R}\r\n")
            sys.stdout.write(f" {W}Arrows to navigate, Enter to select, ESC to cancel{R}\r\n\r\n")

            for i, action in enumerate(unbound):
                name = ACTION_DISPLAY_NAMES.get(action, action)
                if i == sel:
                    sys.stdout.write(f"\r {G} > {Y}{name}{R}\r\n")
                else:
                    sys.stdout.write(f"\r    {W}{name}{R}\r\n")

            sys.stdout.flush()
            key = self._read_raw_key()
            if key is None:
                continue
            if key == "ESC":
                return
            if key == "UP":
                sel = (sel - 1) % len(unbound)
            elif key == "DOWN":
                sel = (sel + 1) % len(unbound)
            elif key == "ENTER":
                chosen = unbound[sel]
                self.actions.append(chosen)
                self.config[chosen] = {}  # unbound — user will press Enter to assign key
                self.selected_index = len(self.actions) - 1
                self.status_message = f"Added {ACTION_DISPLAY_NAMES.get(chosen, chosen)} — press Enter to assign a key"
                return

    # -------------------------------------------------------------------
    # Remove action from config
    # -------------------------------------------------------------------

    def _do_remove(self):
        """Remove the selected action from the config (only user-added ones)."""
        if self.selected_index < 0 or self.selected_index >= len(self.actions):
            return
        action = self.actions[self.selected_index]
        # Don't allow removing default-bound actions
        if action in DEFAULT_BINDINGS:
            self.status_message = "Can't remove default hotkeys — use D to disable"
            return
        self.actions.pop(self.selected_index)
        self.config.pop(action, None)
        if self.selected_index >= len(self.actions):
            self.selected_index = max(0, len(self.actions) - 1)
        self.status_message = f"Removed {ACTION_DISPLAY_NAMES.get(action, action)}"

    # -------------------------------------------------------------------
    # Main loop (ANSI mode)
    # -------------------------------------------------------------------

    def run_ansi(self):
        """Main loop using raw ANSI (no curses). Called from redpill_tui.py."""
        sys.stdout.write("\x1b[2J")
        sys.stdout.flush()

        while True:
            self._render_ansi()
            key = self._read_raw_key()
            if key is None:
                continue

            if self.edit_mode:
                self._handle_edit_capture_ansi(key)
                continue

            if key == "ESC":
                break
            elif key in ("k", "K", "UP"):
                self.move_selection(-1)
            elif key == "DOWN":
                self.move_selection(1)
            elif key == "ENTER":
                self.enter_edit_mode()
            elif key in ("a", "A"):
                self._do_add()
            elif key in ("x", "X"):
                self._do_remove()
            elif key in ("d", "D"):
                self.toggle_disable()
            elif key in ("r", "R"):
                self.reset_to_defaults()
            elif key in ("s", "S"):
                self.save()
