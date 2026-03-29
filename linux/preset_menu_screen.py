"""Interactive preset management screen for the Red Pill TUI.

Provides save, load, list, and delete operations for shader presets
using raw ANSI rendering (matching the existing TUI pattern).

Consumed by: redpill_tui.py (invoked from main menu).
Dependencies: preset_service, shader_service, redpill_keys, redpill_tui (TuiRenderer).
"""

import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from preset_service import (
    delete_preset,
    list_presets,
    load_preset,
    sanitize_name,
    save_preset,
)
from redpill_keys import read_key
from redpill_tui import TuiRenderer
from shader_service import (
    get_ghostty_bus_names,
    read_shader_config,
    reload_ghostty,
    write_shader_params,
)


# ---------------------------------------------------------------------------
# PresetMenuScreen
# ---------------------------------------------------------------------------

class PresetMenuScreen:
    """Full-screen preset management with save, load, delete, and list.

    Renders using raw ANSI (same pattern as _show_help in redpill_tui.py).
    Constructor takes active_slot (int) and optional presets_dir for test isolation.
    """

    def __init__(self, active_slot: int, presets_dir: str = None):
        self.active_slot = active_slot
        self.presets_dir = presets_dir
        self.presets = list_presets(presets_dir)
        self.selected = 0
        self.status_msg = None

    # -------------------------------------------------------------------
    # Refresh
    # -------------------------------------------------------------------

    def _refresh_presets(self):
        """Reload the presets list from disk."""
        self.presets = list_presets(self.presets_dir)

    # -------------------------------------------------------------------
    # Date formatting
    # -------------------------------------------------------------------

    @staticmethod
    def _format_date(iso_str):
        """Parse ISO 8601 timestamp into 'Mon DD' display format.

        Returns empty string on parse failure.
        """
        if not iso_str:
            return ""
        try:
            # Handle timezone-aware ISO strings
            dt = datetime.fromisoformat(iso_str)
            return dt.strftime("%b %d")
        except (ValueError, TypeError):
            return ""

    # -------------------------------------------------------------------
    # Rendering
    # -------------------------------------------------------------------

    def _render(self):
        """Build the full-frame ANSI buffer for the preset list.

        Returns list of strings (the frame buffer).
        """
        R = TuiRenderer
        cw = R.clear_width()
        buf = []

        # Header
        R.append_padded_line(buf, cw, "")
        R.append_padded_line(buf, cw, R.format_section_header("PRESETS"))
        R.append_padded_line(buf, cw, "")

        if not self.presets:
            R.append_padded_line(
                buf, cw,
                f" {R.GRAY}No presets saved yet. Press [S] to save your current config.{R.RESET}"
            )
            R.append_padded_line(buf, cw, "")
        else:
            for i, preset in enumerate(self.presets):
                r, g, b = preset.get("color", (0.0, 1.0, 0.3))
                swatch = R.color_swatch(r, g, b, width=2)
                date_str = self._format_date(preset.get("saved_at"))
                name = preset["name"]

                if i == self.selected:
                    marker = f"{R.YELLOW}[>]{R.RESET}"
                    name_str = f"{R.YELLOW}{name}{R.RESET}"
                else:
                    marker = f"{R.GRAY}[ ]{R.RESET}"
                    name_str = f"{R.GRAY}{name}{R.RESET}"

                line = f" {marker} {name_str}  {swatch}  {R.GRAY}{date_str}{R.RESET}"
                R.append_padded_line(buf, cw, line)

            R.append_padded_line(buf, cw, "")

        # Footer with controls
        R.append_padded_line(
            buf, cw,
            f" {R.GRAY}[S] Save  [ENTER] Load  [D] Delete  [ESC] Back{R.RESET}"
        )

        # Status message
        if self.status_msg:
            R.append_padded_line(buf, cw, f" {R.GREEN}{self.status_msg}{R.RESET}")
        else:
            R.append_padded_line(buf, cw, "")

        # Fill remaining rows
        lines_written = sum(1 for s in buf if s == "\n" or s.endswith("\n"))
        max_rows = R.terminal_height()
        remaining = max_rows - lines_written - 1
        if remaining > 0:
            R.append_blank_lines(buf, cw, remaining)

        return buf

    def _draw(self):
        """Write the rendered frame to stdout."""
        buf = self._render()
        frame = "".join(buf)
        sys.stdout.write("\x1b[H")  # cursor home
        sys.stdout.write(frame)
        sys.stdout.flush()

    # -------------------------------------------------------------------
    # Key handling
    # -------------------------------------------------------------------

    def _handle_key(self, key):
        """Dispatch a key code. Returns False to exit, True to continue."""
        # Clear status on any keypress
        self.status_msg = None

        if key == 27:  # ESC
            return False

        if key == -3:  # Up arrow
            if self.presets:
                self.selected = (self.selected - 1) % len(self.presets)
            return True

        if key == -4:  # Down arrow
            if self.presets:
                self.selected = (self.selected + 1) % len(self.presets)
            return True

        if key in (ord('s'), ord('S')):
            self._do_save()
            return True

        if key in (10, 13):  # Enter
            self._do_load()
            return True

        if key in (ord('d'), ord('D')):
            self._do_delete()
            return True

        return True

    # -------------------------------------------------------------------
    # Save flow
    # -------------------------------------------------------------------

    def _do_save(self):
        """Interactive save: prompt for name, check duplicates, save."""
        # Show prompt
        sys.stdout.write("\x1b[H\x1b[2J")
        sys.stdout.write("\n Preset name: ")
        sys.stdout.flush()

        # Read name character by character
        name_buf = []
        while True:
            key = read_key()

            if key == 27:  # ESC -- cancel
                return

            if key in (10, 13):  # Enter -- confirm
                break

            if key == 127:  # Backspace
                if name_buf:
                    name_buf.pop()
                    sys.stdout.write("\b \b")
                    sys.stdout.flush()
                continue

            # Printable characters (32-126)
            if 32 <= key <= 126:
                ch = chr(key)
                name_buf.append(ch)
                sys.stdout.write(ch)
                sys.stdout.flush()

        name = "".join(name_buf).strip()
        if not name:
            self.status_msg = "Name cannot be empty"
            return

        # Check for duplicate
        try:
            sanitized = sanitize_name(name)
        except ValueError:
            self.status_msg = "Name cannot be empty"
            return

        existing_names = [p["name"] for p in self.presets]
        if sanitized in existing_names:
            sys.stdout.write(f"\n Overwrite '{sanitized}'? [Y/N] ")
            sys.stdout.flush()
            confirm = read_key()
            if confirm not in (ord('y'), ord('Y')):
                self.status_msg = "Cancelled"
                return

        # Read current config and save
        current_config = read_shader_config(self.active_slot)
        save_preset(name, current_config, self.presets_dir)

        self._refresh_presets()
        self.status_msg = f"Saved '{sanitized}'"

    # -------------------------------------------------------------------
    # Load flow
    # -------------------------------------------------------------------

    def _do_load(self):
        """Load the selected preset into the active shader slot."""
        if not self.presets:
            return
        if self.selected < 0 or self.selected >= len(self.presets):
            return

        name = self.presets[self.selected]["name"]
        try:
            params = load_preset(name, self.presets_dir)
        except FileNotFoundError:
            self.status_msg = "Preset not found (may have been deleted)"
            return

        write_shader_params(self.active_slot, params)

        # Trigger D-Bus reload for the active slot
        bus_names = get_ghostty_bus_names()
        slot_info = bus_names.get(self.active_slot)
        if slot_info:
            bus_name = slot_info.get("bus_name")
            if bus_name:
                reload_ghostty(bus_name)

        self.status_msg = f"Loaded '{name}'"

    # -------------------------------------------------------------------
    # Delete flow
    # -------------------------------------------------------------------

    def _do_delete(self):
        """Delete the selected preset after Y/N confirmation."""
        if not self.presets:
            return
        if self.selected < 0 or self.selected >= len(self.presets):
            return

        name = self.presets[self.selected]["name"]
        sys.stdout.write(f"\n Delete '{name}'? [Y/N] ")
        sys.stdout.flush()

        confirm = read_key()
        if confirm not in (ord('y'), ord('Y')):
            self.status_msg = "Cancelled"
            return

        delete_preset(name, self.presets_dir)
        self._refresh_presets()

        # Adjust selection to stay in bounds
        if self.presets:
            self.selected = min(self.selected, len(self.presets) - 1)
        else:
            self.selected = 0

        self.status_msg = f"Deleted '{name}'"

    # -------------------------------------------------------------------
    # Main loop
    # -------------------------------------------------------------------

    def run(self):
        """Run the preset menu screen. Returns when user presses ESC."""
        sys.stdout.write("\x1b[2J")  # clear screen
        sys.stdout.flush()

        while True:
            self._draw()
            key = read_key()
            if not self._handle_key(key):
                break

        # Clear screen on exit
        sys.stdout.write("\x1b[2J")
        sys.stdout.flush()
