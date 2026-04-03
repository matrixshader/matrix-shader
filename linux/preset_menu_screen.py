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
                f" {R.WHITE}No presets saved yet. Press [S] to save your current config.{R.RESET}"
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
                    marker = f"{R.WHITE}[ ]{R.RESET}"
                    name_str = f"{R.WHITE}{name}{R.RESET}"

                line = f" {marker} {name_str}  {swatch}  {R.GRAY}{date_str}{R.RESET}"
                R.append_padded_line(buf, cw, line)

            R.append_padded_line(buf, cw, "")

        # Footer with controls
        R.append_padded_line(
            buf, cw,
            f" {R.GREEN}[S]{R.RESET} Save  {R.GREEN}[ENTER]{R.RESET} Load  {R.GREEN}[D]{R.RESET} Delete  {R.GREEN}[ESC]{R.RESET} Back"
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
        """Write the preset screen directly — no TuiRenderer."""
        G = "\x1b[38;2;110;220;170m"  # bright green
        W = "\x1b[97m"   # white
        Y = "\x1b[33m"   # yellow
        D = "\x1b[90m"   # dim
        R = "\x1b[0m"    # reset

        sys.stdout.write("\x1b[H\x1b[2J")  # home + clear (same order as _do_save)
        sys.stdout.write(f"\n {G}PRESETS{R}\n\n")

        if not self.presets:
            sys.stdout.write(f" {W}No presets saved yet.{R}\n")
        else:
            for i, p in enumerate(self.presets):
                name = p["name"]
                if i == self.selected:
                    sys.stdout.write(f" {Y}[>] {name}{R}\n")
                else:
                    sys.stdout.write(f" {W}[ ] {name}{R}\n")

        sys.stdout.write(f"\n {G}[S]{R} Save  {G}[ENTER]{R} Load  {G}[D]{R} Delete  {G}[ESC]{R} Back\n")

        if self.status_msg:
            sys.stdout.write(f"\n {G}{self.status_msg}{R}\n")

        sys.stdout.flush()

    # -------------------------------------------------------------------
    # Key handling
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

    def _handle_key(self, key):
        """Dispatch a key string. Returns False to exit, True to continue."""
        self.status_msg = None

        if key is None:
            return True

        if key == "ESC":
            return False

        if key == "UP":
            if self.presets:
                self.selected = (self.selected - 1) % len(self.presets)
            return True

        if key == "DOWN":
            if self.presets:
                self.selected = (self.selected + 1) % len(self.presets)
            return True

        if key in ('s', 'S'):
            self._do_save()
            return True

        if key == "ENTER":
            self._do_load()
            return True

        if key in ('d', 'D'):
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
            key = self._read_raw_key()
            if key is None:
                continue

            if key == "ESC":
                return

            if key == "ENTER":
                break

            if key == "BACKSPACE":
                if name_buf:
                    name_buf.pop()
                    sys.stdout.write("\b \b")
                    sys.stdout.flush()
                continue

            # Printable characters
            if len(key) == 1 and 32 <= ord(key) <= 126:
                name_buf.append(key)
                sys.stdout.write(key)
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
            confirm = self._read_raw_key()
            if confirm not in ('y', 'Y'):
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

        try:
            write_shader_params(self.active_slot, params)
        except Exception as e:
            self.status_msg = f"Write failed: {e}"
            return

        # Find the bus name for THIS slot's PID and reload it
        import subprocess
        reloaded = False
        try:
            from window_service import get_pid_for_slot
            target_pid = get_pid_for_slot(self.active_slot)
            if target_pid:
                result = subprocess.run(
                    ["busctl", "--user", "list"],
                    capture_output=True, text=True, timeout=3,
                    stdin=subprocess.DEVNULL,
                )
                for line in result.stdout.splitlines():
                    if "ghostty" not in line.lower():
                        continue
                    parts = line.split()
                    if len(parts) >= 2:
                        try:
                            if int(parts[1]) == target_pid:
                                reload_ghostty(parts[0])
                                reloaded = True
                                break
                        except ValueError:
                            continue
        except Exception:
            pass

        self.status_msg = f"Loaded '{name}'" if reloaded else f"Wrote '{name}' — reopen redpill to see changes"

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

        confirm = self._read_raw_key()
        if confirm not in ('y', 'Y'):
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
        sys.stdout.write("\x1b[2J\x1b[H")  # clear screen + cursor home
        sys.stdout.flush()

        try:
            while True:
                self._draw()
                key = self._read_raw_key()
                if not self._handle_key(key):
                    break
        except Exception as e:
            # Show error instead of silently dying
            sys.stdout.write(f"\x1b[2J\x1b[H\x1b[31mPreset screen error: {e}\x1b[0m\n")
            sys.stdout.write("Press any key...\n")
            sys.stdout.flush()
            self._read_raw_key()

        # Clear screen on exit
        sys.stdout.write("\x1b[2J")
        sys.stdout.flush()
