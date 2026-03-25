#!/usr/bin/env python3
"""Red Pill TUI Control Panel for Matrix Shader (Linux/Ghostty).

Full-screen TUI using raw ANSI escape codes for live shader parameter adjustment.
Direct port of MatrixShader.Cli.Redpill (C#/.NET).

Launch via `redpill` command (shell wrapper with Ghostty self-relaunch).
"""

import glob as _glob
import json
import os
import re
import subprocess
import sys
import tempfile

MATRIX_TMP = f"/tmp/matrixshader-{os.getuid()}"

# Ensure linux/ directory is in sys.path for sibling imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from redpill_keys import PARAM_DELTAS, process_key, read_key, enter_raw_mode, restore_mode
from shader_service import (
    PARAM_DEFAULTS,
    PARAM_RANGES,
    PRESET_COLORS,
    SLOT_SHADER_DIR,
    clamp_value,
    create_slot_shader,
    get_all_ghostty_configs,
    get_ghostty_bus_names,
    read_shader_config,
    reload_ghostty,
    resolve_config_path,
    write_shader_param,
    write_shader_params,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

def _find_ghostty():
    """Discover Ghostty binary location at runtime."""
    import shutil
    env_bin = os.environ.get("MATRIX_GHOSTTY_BIN")
    if env_bin and os.path.isfile(env_bin):
        return env_bin
    candidates = [
        os.path.expanduser("~/.local/share/matrixshader/ghostty"),
        "/Applications/Ghostty.app/Contents/MacOS/ghostty",
        os.path.expanduser("~/Applications/Ghostty.app/Contents/MacOS/ghostty"),
    ]
    for c in candidates:
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    return shutil.which("ghostty") or "ghostty"

GHOSTTY_BIN = _find_ghostty()

# Preset action name -> PRESET_COLORS index
PRESET_ACTIONS = {
    "PresetGreen": 0,
    "PresetBlue": 1,
    "PresetRed": 2,
    "PresetPurple": 3,
    "PresetGold": 4,
    "PresetTeal": 5,
}

PRESET_NAMES = ["Green", "Blue", "Red", "Purple", "Gold", "Teal"]

# Layer action name -> shader parameter
LAYER_ACTIONS = {
    "Layer1Toggle": "SHOW_L1",
    "Layer2Toggle": "SHOW_L2",
    "Layer3Toggle": "SHOW_L3",
}

# Layout modes -- cycles Pillars -> Quads -> Overlap -> Auto -> Pillars
LAYOUT_MODES = ["Pillars", "Quads", "Overlap", "Auto"]

# State file path (matches hotkey_actions.py STATE_PATH)
STATE_PATH = os.path.expanduser("~/.config/matrix-shader/state.json")

# Default layout state
DEFAULT_LAYOUT = {
    "mode": "Pillars",
    "glitch_enabled": False,
    "priority_lock": False,
    "primary_window_count": 0,
}


# ---------------------------------------------------------------------------
# TuiRenderer -- port of TuiRenderer.cs
# Uses raw ANSI escape codes, NOT curses.
# ---------------------------------------------------------------------------

class TuiRenderer:
    """Static rendering methods for pixel-perfect TUI output.

    Port of C# TuiRenderer.cs. All methods return strings for buffered
    rendering (write-once pattern: build full frame, cursor home, write).
    """

    # ANSI escape codes (matching C# TuiRenderer constants)
    ESC = "\x1b"
    RESET = "\x1b[0m"
    GREEN = "\x1b[32m"
    GRAY = "\x1b[90m"
    YELLOW = "\x1b[33m"
    CYAN = "\x1b[36m"
    RED = "\x1b[31m"
    WHITE = "\x1b[37m"
    DIM = "\x1b[2m"
    MAGENTA = "\x1b[35m"

    @staticmethod
    def clear_width():
        """Dynamic terminal width for padding lines (minimum 80)."""
        try:
            return max(80, os.get_terminal_size().columns)
        except OSError:
            return 80

    @staticmethod
    def terminal_height():
        """Dynamic terminal height."""
        try:
            return os.get_terminal_size().lines
        except OSError:
            return 24

    @staticmethod
    def color_swatch(r, g, b, width=2):
        """Create a color swatch using RGB background color."""
        r8 = int(max(0, min(255, r * 255)))
        g8 = int(max(0, min(255, g * 255)))
        b8 = int(max(0, min(255, b * 255)))
        return f"\x1b[48;2;{r8};{g8};{b8}m{' ' * width}\x1b[0m"

    @staticmethod
    def progress_bar(val, min_val, max_val, width=15):
        """Create a progress bar with green filled and gray empty portions."""
        if max_val <= min_val:
            return "\x1b[90m" + "-" * width + "\x1b[0m"
        pct = max(0.0, min(1.0, (val - min_val) / (max_val - min_val)))
        filled = int(pct * width)
        empty = width - filled
        return f"\x1b[32m{'=' * filled}\x1b[90m{'-' * empty}\x1b[0m"

    @staticmethod
    def format_parameter_row(keys, label, value, val, min_val, max_val):
        """Return a parameter row string with consistent formatting."""
        bar = TuiRenderer.progress_bar(val, min_val, max_val)
        return f" [{keys}] {label:<8s} {value:>4s} {bar}"

    @staticmethod
    def format_layer_status(key, name, enabled):
        """Return layer toggle status string with color-coded ON/off indicator."""
        status = "ON " if enabled else "off"
        color = TuiRenderer.GREEN if enabled else TuiRenderer.GRAY
        return f" [{key}] {name}: {color}{status}{TuiRenderer.RESET}"

    @staticmethod
    def format_section_header(title):
        """Return a section header string with white text."""
        return f" {TuiRenderer.WHITE}{title}{TuiRenderer.RESET}"

    @staticmethod
    def format_tab_bar(tabs, active_slot):
        """Return the tab bar string showing all Matrix shader windows."""
        parts = [" TABS: "]
        if not tabs:
            parts.append(f"{TuiRenderer.GRAY}(no Matrix windows detected){TuiRenderer.RESET}")
        else:
            for slot, r, g, b in tabs:
                if slot == active_slot:
                    parts.append(f"{TuiRenderer.YELLOW}[{slot}]{TuiRenderer.RESET}")
                else:
                    parts.append(f"{TuiRenderer.GRAY} {slot} {TuiRenderer.RESET}")
                parts.append(TuiRenderer.color_swatch(r, g, b, 1))
                parts.append(" ")
        return "".join(parts)

    @staticmethod
    def format_color_presets():
        """Return the color preset row string with numbered swatches."""
        s = TuiRenderer.color_swatch
        return (f" [1]{s(0, 1, 0.3)}Green "
                f"[2]{s(0, 0.6, 1)}Blue "
                f"[3]{s(1, 0.1, 0.1)}Red "
                f"[4]{s(0.7, 0, 1)}Purple "
                f"[5]{s(1, 0.7, 0)}Gold "
                f"[6]{s(0, 0.9, 0.9)}Teal")

    @staticmethod
    def format_header(slot, dirty):
        """Return the header string with title and dirty indicator."""
        dirty_mark = "*" if dirty else " "
        return f" {TuiRenderer.RED}RED PILL{TuiRenderer.RESET}{dirty_mark}- Tab {slot}"

    @staticmethod
    def append_footer(buf, cw, launch_count, can_launch, glitch_enabled):
        """Append the footer lines with launch, save controls, and hotkey help hint."""
        if launch_count > 0:
            enter_action = f"[ENTER] Deploy {launch_count} window(s)"
            enter_color = TuiRenderer.YELLOW
        else:
            enter_action = "[ENTER] (set count first)"
            enter_color = TuiRenderer.GRAY
        TuiRenderer.append_padded_line(
            buf, cw,
            f" {enter_color}{enter_action}{TuiRenderer.RESET}  "
            f"{TuiRenderer.GRAY}[0] Reset  [ESC] Quit{TuiRenderer.RESET}")
        TuiRenderer.append_padded_line(
            buf, cw,
            f" {TuiRenderer.GRAY}[Shift+H] Configure hotkeys  [?] Help{TuiRenderer.RESET}")
        TuiRenderer.append_padded_line(
            buf, cw,
            f" {TuiRenderer.GREEN}All changes apply instantly{TuiRenderer.RESET}")

    @staticmethod
    def append_padded_line(buf, cw, content):
        """Append a line padded to clear_width to prevent residual text."""
        visible_len = TuiRenderer.visible_length(content)
        padding = max(0, cw - visible_len)
        buf.append(content)
        buf.append(" " * padding)
        buf.append("\n")

    @staticmethod
    def visible_length(s):
        """Calculate the visible length of a string (excluding ANSI escape sequences)."""
        length = 0
        in_escape = False
        for ch in s:
            if ch == "\x1b":
                in_escape = True
                continue
            if in_escape:
                if ch.isalpha():
                    in_escape = False
                continue
            length += 1
        return length

    @staticmethod
    def append_blank_lines(buf, cw, count):
        """Append blank padded lines to fill remaining visible rows."""
        blank = " " * cw + "\n"
        for _ in range(count):
            buf.append(blank)


# Keep module-level aliases for backwards compatibility with tests
def color_swatch(r, g, b, width=2):
    """Create ANSI 24-bit background color swatch string."""
    return TuiRenderer.color_swatch(r, g, b, width)


def progress_bar(val, min_val, max_val, width=15):
    """Create text progress bar: ====-------."""
    if max_val <= min_val:
        return "-" * width
    pct = max(0.0, min(1.0, (val - min_val) / (max_val - min_val)))
    filled = int(pct * width)
    empty = width - filled
    return "=" * filled + "-" * empty


# ---------------------------------------------------------------------------
# TUI Application
# ---------------------------------------------------------------------------

def load_state():
    """Load application state from state.json."""
    try:
        with open(STATE_PATH) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(state):
    """Atomic write application state to state.json."""
    dir_path = os.path.dirname(STATE_PATH)
    os.makedirs(dir_path, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(state, f, indent=2)
        os.replace(tmp_path, STATE_PATH)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def cycle_layout_mode(current_mode):
    """Cycle through layout modes: Pillars -> Quads -> Overlap -> Auto -> Pillars."""
    try:
        idx = LAYOUT_MODES.index(current_mode)
    except ValueError:
        idx = -1
    return LAYOUT_MODES[(idx + 1) % len(LAYOUT_MODES)]


class RedpillTUI:
    def __init__(self):
        self.active_slot = None
        self.config = dict(PARAM_DEFAULTS)
        self.tabs = []              # [(slot, r, g, b), ...]
        self.launch_count = 0
        self.transparency = False
        self.opacity = 100
        self.running = True
        self.dirty = False
        self.layout = dict(DEFAULT_LAYOUT)
        self.snapback_positions = {}
        self._load_layout()

    def refresh_tabs(self):
        """Discover open Matrix shader windows and their colors.

        Uses get_ghostty_bus_names() which filters by /proc/{pid}/cmdline
        matching 'ghostty-matrix-{slot}'. This naturally excludes:
        - Regular Ghostty windows (no matrix config in cmdline)
        - Construct white room windows (ghostty-construct.conf)
        - Redpill TUI windows (ghostty-redpill.conf)
        Only actual Matrix shader windows (slots 1-8) appear as tabs.
        """
        mapping = get_ghostty_bus_names()
        self.tabs = []
        for slot in sorted(mapping.keys()):
            cfg = read_shader_config(slot)
            self.tabs.append((slot, cfg["RAIN_R"], cfg["RAIN_G"], cfg["RAIN_B"]))

        valid_slots = [t[0] for t in self.tabs]
        if self.tabs and (self.active_slot is None or self.active_slot not in valid_slots):
            self.active_slot = self.tabs[0][0]
        elif not self.tabs:
            self.active_slot = None

        if self.active_slot is not None:
            self.config = read_shader_config(self.active_slot)
        else:
            self.config = dict(PARAM_DEFAULTS)

        self._read_initial_opacity()

    def _read_initial_opacity(self):
        """Read current opacity from any running Ghostty config."""
        configs = sorted(get_all_ghostty_configs())
        for conf in configs:
            try:
                with open(conf) as f:
                    for line in f:
                        if "background-opacity" in line:
                            val = line.split("=", 1)[1].strip()
                            self.opacity = round(float(val) * 100)
                            self.transparency = self.opacity < 100
                            return
            except (FileNotFoundError, ValueError, IndexError):
                continue

    def _load_layout(self):
        """Load layout state from state.json."""
        state = load_state()
        layout = state.get("layout", {})
        self.layout = {
            "mode": layout.get("mode", DEFAULT_LAYOUT["mode"]),
            "glitch_enabled": layout.get("glitch_enabled", DEFAULT_LAYOUT["glitch_enabled"]),
            "priority_lock": layout.get("priority_lock", DEFAULT_LAYOUT["priority_lock"]),
            "primary_window_count": layout.get("primary_window_count", DEFAULT_LAYOUT["primary_window_count"]),
        }
        self.snapback_positions = state.get("window_slots", {})

    def _save_layout(self):
        """Persist layout state to state.json."""
        state = load_state()
        state["layout"] = dict(self.layout)
        if self.snapback_positions:
            state["window_slots"] = self.snapback_positions
        save_state(state)

    def save_full_state(self):
        """Save full application state (layout + active tab + configs)."""
        state = load_state()
        state["layout"] = dict(self.layout)
        state["active_tab"] = self.active_slot
        if self.snapback_positions:
            state["window_slots"] = self.snapback_positions
        save_state(state)

    def switch_tab(self, direction=1):
        """Cycle active tab. direction=1 forward, -1 backward."""
        if not self.tabs:
            return
        slots = [t[0] for t in self.tabs]
        try:
            idx = slots.index(self.active_slot)
        except ValueError:
            idx = 0
        idx = (idx + direction) % len(slots)
        self.active_slot = slots[idx]
        self.config = read_shader_config(self.active_slot)

    # -------------------------------------------------------------------
    # Rendering (ANSI escape codes, matching C# TuiRenderer + Render())
    # -------------------------------------------------------------------

    def render(self):
        """Full screen render using ANSI escape codes.

        Port of C# ControlPanel.Render(). Builds entire frame as a string
        buffer, then writes at once with cursor home for flicker-free update.
        Line-for-line match of the C# TUI layout.
        """
        R = TuiRenderer
        cw = R.clear_width()
        buf = []
        cfg = self.config

        # Header
        R.append_padded_line(buf, cw, R.format_header(
            self.active_slot if self.active_slot else 0, self.dirty))
        R.append_padded_line(buf, cw,
            R.format_tab_bar(self.tabs, self.active_slot)
            + f"  {R.GRAY}[TAB] next tab{R.RESET}")

        # Agent colors
        R.append_padded_line(buf, cw, R.format_section_header("AGENT COLORS"))
        R.append_padded_line(buf, cw, R.format_color_presets())

        # Current color
        cr = cfg.get("RAIN_R", 0)
        cg = cfg.get("RAIN_G", 1)
        cb = cfg.get("RAIN_B", 0.3)
        R.append_padded_line(buf, cw, f" CURRENT {R.color_swatch(cr, cg, cb, 3)}")
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "Q/W", "Red", f"{cr:.1f}", cr, 0, 1))
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "A/S", "Green", f"{cg:.1f}", cg, 0, 1))
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "Z/X", "Blue", f"{cb:.1f}", cb, 0, 1))

        # Rain parameters
        R.append_padded_line(buf, cw, R.format_section_header("RAIN PARAMETERS"))
        speed = cfg.get("RAIN_SPEED", 0.8)
        glow = cfg.get("GLOW_STRENGTH", 0.8)
        width = cfg.get("CHAR_WIDTH", 10.0)
        trail = cfg.get("TRAIL_POWER", 8.0)
        density = cfg.get("RAIN_DENSITY", 0.4)
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "E/R", "Speed", f"{speed:.1f}", speed, 0.1, 5.0))
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "D/F", "Glow", f"{glow:.1f}", glow, 0.2, 3.0))
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "C/V", "Width", f"{width:.0f}", width, 6.0, 20.0))
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "T/Y", "Trail", f"{trail:.0f}", trail, 4.0, 15.0))
        R.append_padded_line(buf, cw, R.format_parameter_row(
            "G/H", "Density", f"{density:.1f}", density, 0.2, 1.0))

        # Layers
        R.append_padded_line(buf, cw, R.format_section_header("LAYERS"))
        l1 = cfg.get("SHOW_L1", 1.0) >= 0.5
        l2 = cfg.get("SHOW_L2", 1.0) >= 0.5
        l3 = cfg.get("SHOW_L3", 1.0) >= 0.5
        R.append_padded_line(buf, cw,
            R.format_layer_status("7", "Far", l1) + "  "
            + R.format_layer_status("8", "Mid", l2) + "  "
            + R.format_layer_status("9", "Near", l3))

        # Window effects
        R.append_padded_line(buf, cw, R.format_section_header("WINDOW EFFECTS"))
        trans_status = "ON " if self.transparency else "off"
        trans_color = R.CYAN if self.transparency else R.GRAY
        R.append_padded_line(buf, cw,
            f" [B] Transparency:  {trans_color}{trans_status}{R.RESET}"
            f"  {R.GRAY}(toggles & applies){R.RESET}")
        if self.transparency:
            R.append_padded_line(buf, cw,
                f" [K/L] Opacity:     {self.opacity:3d}% "
                f"{R.progress_bar(self.opacity, 0, 100)}")

        # Combat training
        glitch_on = self.layout.get("glitch_enabled", False)
        glitch_status = "ON " if glitch_on else "off"
        glitch_color = R.CYAN if glitch_on else R.GRAY
        R.append_padded_line(buf, cw, R.format_section_header("COMBAT TRAINING"))
        R.append_padded_line(buf, cw,
            f" [Shift+G] Glitch:  {glitch_color}{glitch_status}{R.RESET}"
            f"  {R.GRAY}(windows auto-snap to formation){R.RESET}")
        layout_mode = self.layout.get("mode", "Pillars")
        layout_color = R.YELLOW if layout_mode.lower() == "pillars" else R.MAGENTA
        R.append_padded_line(buf, cw,
            f" [Shift+L] Layout:  {layout_color}{layout_mode}{R.RESET}"
            f"  {R.GRAY}(Pillars=columns, Quads=2x2){R.RESET}")

        # Deploy
        R.append_padded_line(buf, cw, f" {R.MAGENTA}DEPLOY{R.RESET}")
        if self.tabs:
            open_str = ",".join(str(t[0]) for t in self.tabs)
        else:
            open_str = "none"
        R.append_padded_line(buf, cw,
            f" {R.GRAY}Open:{R.RESET} {R.GREEN}{open_str}{R.RESET}")
        launch_status = f"{self.launch_count} window(s)" if self.launch_count > 0 else "disabled"
        launch_color = R.MAGENTA if self.launch_count > 0 else R.GRAY
        R.append_padded_line(buf, cw,
            f" [-/+] Count: {launch_color}{launch_status}{R.RESET}")

        # Footer
        R.append_footer(buf, cw, self.launch_count,
                        self.launch_count > 0, glitch_on)

        # Reset colors, cursor home, write frame, clear leftover lines
        frame = "".join(buf)
        sys.stdout.write("\x1b[0m\x1b[H")
        sys.stdout.write(frame)
        sys.stdout.write("\x1b[J")  # clear from cursor to end of screen
        sys.stdout.flush()

    # -------------------------------------------------------------------
    # Action handlers
    # -------------------------------------------------------------------

    def handle_action(self, action):
        """Dispatch an action string to its handler."""
        # Tab navigation
        if action == "Tab":
            self.switch_tab(1)
            return
        if action == "ShiftTab":
            self.switch_tab(-1)
            return
        if action == "Quit":
            self.running = False
            return

        # Color presets
        if action in PRESET_ACTIONS:
            if self.active_slot is None:
                return
            idx = PRESET_ACTIONS[action]
            r, g, b = PRESET_COLORS[idx]
            write_shader_params(self.active_slot, {
                "RAIN_R": r, "RAIN_G": g, "RAIN_B": b,
            })
            self.config["RAIN_R"] = r
            self.config["RAIN_G"] = g
            self.config["RAIN_B"] = b
            self._update_tab_color()
            return

        # Parameter adjustments (RGB + rain params)
        if action in PARAM_DELTAS:
            if self.active_slot is None:
                return
            param, delta = PARAM_DELTAS[action]
            new_val = self.config.get(param, PARAM_DEFAULTS.get(param, 0)) + delta
            new_val = clamp_value(param, new_val)
            write_shader_param(self.active_slot, param, new_val)
            self.config[param] = new_val
            if param in ("RAIN_R", "RAIN_G", "RAIN_B"):
                self._update_tab_color()
            return

        # Layer toggles
        if action in LAYER_ACTIONS:
            if self.active_slot is None:
                return
            param = LAYER_ACTIONS[action]
            current = self.config.get(param, 1.0)
            new_val = 0.0 if current >= 0.5 else 1.0
            write_shader_param(self.active_slot, param, new_val)
            self.config[param] = new_val
            return

        # Opacity
        if action == "TransparencyToggle":
            self.transparency = not self.transparency
            if self.transparency:
                self._apply_opacity(self.opacity)
            else:
                self._apply_opacity(100)
            return
        if action == "OpacityDecrease":
            if self.transparency and self.opacity > 0:
                self.opacity -= 5
                self._apply_opacity(self.opacity)
            return
        if action == "OpacityIncrease":
            if self.transparency and self.opacity < 100:
                self.opacity += 5
                self._apply_opacity(self.opacity)
            return

        # Deploy controls
        if action == "LaunchDecrease":
            self.launch_count = max(0, self.launch_count - 1)
            return
        if action == "LaunchIncrease":
            self.launch_count += 1
            return
        if action == "Launch":
            if self.launch_count > 0:
                self._deploy_windows(self.launch_count)
            return

        # Reset
        if action == "Reset":
            if self.active_slot is None:
                return
            write_shader_params(self.active_slot, dict(PARAM_DEFAULTS))
            self.config = dict(PARAM_DEFAULTS)
            self._update_tab_color()
            return

        # Layout controls
        if action == "LayoutCycle":
            self.layout["mode"] = cycle_layout_mode(self.layout.get("mode", "Pillars"))
            self._save_layout()
            return
        if action == "GlitchToggle":
            self.layout["glitch_enabled"] = not self.layout.get("glitch_enabled", False)
            self._save_layout()
            return
        if action == "SnapbackSave":
            self.snapback_positions = {str(t[0]): True for t in self.tabs}
            self._save_layout()
            return
        if action == "SnapbackRestore":
            return
        if action == "PriorityToggle":
            self.layout["priority_lock"] = not self.layout.get("priority_lock", False)
            self._save_layout()
            return
        if action == "MonitorChange":
            return
        if action == "PrimaryDecrease":
            self.layout["primary_window_count"] = max(0, self.layout.get("primary_window_count", 0) - 1)
            self._save_layout()
            return
        if action == "PrimaryIncrease":
            self.layout["primary_window_count"] = min(8, self.layout.get("primary_window_count", 0) + 1)
            self._save_layout()
            return
        if action == "PrimaryReset":
            self.layout["primary_window_count"] = 0
            self._save_layout()
            return

        # Help screen
        if action == "Help":
            self._show_help()
            return

        # Hotkey config screen
        if action == "HotkeyConfig":
            self._show_hotkey_config()
            return

    def _update_tab_color(self):
        """Update the active tab's color in the tabs list and sync Ghostty foreground."""
        if self.active_slot is None:
            return
        r = self.config.get("RAIN_R", 0)
        g = self.config.get("RAIN_G", 1)
        b = self.config.get("RAIN_B", 0.3)
        self.tabs = [
            (slot, r, g, b) if slot == self.active_slot else (slot, tr, tg, tb)
            for slot, tr, tg, tb in self.tabs
        ]
        self._sync_foreground_color(self.active_slot, r, g, b)

    def _sync_foreground_color(self, slot, r, g, b):
        """Update Ghostty config foreground color to match rain RGB and reload."""
        fg = f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"
        conf = resolve_config_path(slot)
        if not conf:
            return
        try:
            with open(conf) as f:
                content = f.read()
            content = re.sub(r"foreground = #[0-9a-fA-F]+", f"foreground = {fg}", content)
            with open(conf, "w") as f:
                f.write(content)
        except (FileNotFoundError, PermissionError):
            return
        mapping = get_ghostty_bus_names()
        bus = mapping.get(slot, {}).get("bus_name")
        if bus:
            reload_ghostty(bus)


    def _apply_opacity(self, percent):
        """Write opacity to all matrix config files and reload."""
        value = f"{percent / 100:.2f}"
        if value == "0.00":
            value = "0"
        if value == "1.00":
            value = "1"

        # Update ALL running Ghostty configs (any launch method)
        confs = get_all_ghostty_configs()
        for conf in confs:
            try:
                with open(conf) as f:
                    content = f.read()
                content = re.sub(
                    r"background-opacity = .*",
                    f"background-opacity = {value}",
                    content,
                )
                with open(conf, "w") as f:
                    f.write(content)
            except (FileNotFoundError, PermissionError):
                continue

        mapping = get_ghostty_bus_names()
        for slot_info in mapping.values():
            reload_ghostty(slot_info["bus_name"])

    def _deploy_windows(self, count):
        """Launch new Matrix windows into available slots."""
        mapping = get_ghostty_bus_names()
        used_slots = set(mapping.keys())

        for _ in range(count):
            slot = None
            for s in range(1, 9):
                if s not in used_slots:
                    slot = s
                    break
            if slot is None:
                break

            create_slot_shader(slot, preset_idx=0)
            self._launch_ghostty_window(slot)
            used_slots.add(slot)

        self.launch_count = 0
        self.refresh_tabs()

    def _launch_ghostty_window(self, slot):
        """Spawn a Ghostty window for the given slot."""
        shader_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")
        conf_path = f"{MATRIX_TMP}/ghostty-matrix-{slot}.conf"

        conf_content = f"""custom-shader = {shader_path}
background = #000000
foreground = #00ff4d
font-family = Nimbus Mono PS
font-style = Bold
background-opacity = 0.85
gtk-titlebar = true
window-decoration = client
custom-shader-animation = always
keybind = ctrl+shift+j=unbind
keybind = ctrl+shift+k=unbind
keybind = ctrl+shift+b=unbind
keybind = ctrl+shift+h=unbind
keybind = ctrl+shift+l=unbind
keybind = ctrl+shift+one=unbind
keybind = ctrl+shift+two=unbind
keybind = ctrl+shift+three=unbind
keybind = ctrl+shift+up=unbind
keybind = ctrl+shift+down=unbind
keybind = ctrl+shift+left=unbind
keybind = ctrl+shift+right=unbind
keybind = ctrl+shift+f5=unbind
"""
        with open(conf_path, "w") as f:
            f.write(conf_content)

        ghostty = GHOSTTY_BIN
        if not os.path.isfile(ghostty):
            import shutil
            ghostty = shutil.which("ghostty") or ghostty

        try:
            subprocess.Popen(
                [ghostty, "--config-default-files=false", f"--config-file={conf_path}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except (FileNotFoundError, OSError):
            pass

    # -------------------------------------------------------------------
    # Help screen (ANSI, no curses)
    # -------------------------------------------------------------------

    def _show_help(self):
        """Show full help screen, wait for any keypress to return."""
        R = TuiRenderer
        cw = R.clear_width()
        buf = []

        R.append_padded_line(buf, cw, "")
        R.append_padded_line(buf, cw, f" {R.GREEN}HOTKEY HELP{R.RESET}")
        R.append_padded_line(buf, cw, "")

        R.append_padded_line(buf, cw, f" {R.DIM}CONTROL PANEL KEYS (local):{R.RESET}")
        R.append_padded_line(buf, cw, "")
        help_lines = [
            "   [1-6]      Agent colors (Green/Blue/Red/Purple/Gold/Teal)",
            "   [Q/W]      Red -/+          [A/S] Green -/+    [Z/X] Blue -/+",
            "   [E/R]      Speed -/+        [D/F] Glow -/+",
            "   [C/V]      Width -/+        [T/Y] Trail -/+    [G/H] Density -/+",
            "   [7/8/9]    Toggle layers (Far/Mid/Near)",
            "   [B]        Toggle transparency    [K/L] Opacity -/+",
            "   [-/+]      Deploy count -/+       [ENTER] Deploy windows",
            "   [0]        Reset to defaults       (all changes apply instantly)",
            "   [TAB]      Switch tabs            [ESC] Quit",
        ]
        for line in help_lines:
            R.append_padded_line(buf, cw, f" {R.DIM}{line}{R.RESET}")
        R.append_padded_line(buf, cw, "")

        R.append_padded_line(buf, cw, f" {R.DIM}SHIFT KEYS (local):{R.RESET}")
        R.append_padded_line(buf, cw, "")
        shift_lines = [
            "   [Shift+G]  Toggle Glitch (auto-snap to formation)",
            "   [Shift+L]  Cycle layout mode (Pillars/Quads/Overlap)",
            "   [Shift+H]  Configure global hotkey bindings",
            "   [Shift+S]  Save snapback position",
            "   [Shift+R]  Restore snapback position",
        ]
        for line in shift_lines:
            R.append_padded_line(buf, cw, f" {R.DIM}{line}{R.RESET}")
        R.append_padded_line(buf, cw, "")

        R.append_padded_line(buf, cw, f" {R.GREEN}GLOBAL HOTKEYS (active when Matrix windows exist):{R.RESET}")
        R.append_padded_line(buf, cw, "")
        global_lines = [
            "   Ctrl+Shift+L       Cycle layout mode",
            "   Ctrl+Shift+B       Toggle background transparency",
            "   Ctrl+Shift+K/O     Decrease/Increase opacity",
            "   Ctrl+Shift+Up/Down Cycle shader in library",
            "   Ctrl+Shift+, / .   Decrease/Increase rain speed",
            "   Ctrl+Shift+1/2/3   Toggle FAR/MID/NEAR layers",
        ]
        for line in global_lines:
            R.append_padded_line(buf, cw, f" {R.DIM}{line}{R.RESET}")
        R.append_padded_line(buf, cw, "")

        R.append_padded_line(buf, cw, f" {R.DIM}Press [Shift+H] to customize global hotkey bindings.{R.RESET}")
        R.append_padded_line(buf, cw, "")
        R.append_padded_line(buf, cw, f" Press any key to return...")

        # Fill remaining rows
        frame = "".join(buf)
        lines_written = frame.count("\n")
        max_rows = R.terminal_height()
        remaining = max_rows - lines_written - 1
        if remaining > 0:
            tail_buf = []
            R.append_blank_lines(tail_buf, cw, remaining)
            frame += "".join(tail_buf)

        # Clear screen and show help
        sys.stdout.write("\x1b[2J\x1b[H")
        sys.stdout.write(frame)
        sys.stdout.flush()

        # Wait for keypress
        read_key()

        # Clear for main screen to redraw
        sys.stdout.write("\x1b[2J")
        sys.stdout.flush()

    def _show_hotkey_config(self):
        """Launch the hotkey config screen (ANSI mode)."""
        try:
            from hotkey_config_screen import HotkeyConfigScreen
            screen = HotkeyConfigScreen()
            screen.run_ansi()
        except (ImportError, AttributeError):
            # Fallback: show simple message
            sys.stdout.write("\x1b[2J\x1b[H")
            sys.stdout.write(" Hotkey config screen not available.\n")
            sys.stdout.write(" Press any key to return...\n")
            sys.stdout.flush()
            read_key()
        sys.stdout.write("\x1b[2J")
        sys.stdout.flush()

    # -------------------------------------------------------------------
    # Main loop
    # -------------------------------------------------------------------

    def run(self):
        """Main loop: render -> read key -> dispatch -> repeat.

        Uses raw terminal mode (termios) instead of curses for input.
        """
        # Switch to alternate screen buffer, hide cursor, disable alt scroll, clear
        sys.stdout.write("\x1b[?1049h")  # alternate screen buffer
        sys.stdout.write("\x1b[?1007l")  # disable alternate scroll mode
        sys.stdout.write("\x1b[?25l")    # hide cursor
        sys.stdout.write("\x1b[2J")      # clear screen
        sys.stdout.flush()

        # Enter raw mode via redpill_keys helper
        old_settings = enter_raw_mode()

        try:
            self.refresh_tabs()

            while self.running:
                self.render()
                key_code = read_key()
                if key_code == -1:
                    continue
                action = process_key(key_code)
                if action:
                    self.handle_action(action)
        finally:
            # Restore terminal settings
            restore_mode(old_settings)
            self.save_full_state()

            # Show cursor, restore main screen buffer
            sys.stdout.write("\x1b[?25h")
            sys.stdout.write("\x1b[?1049l")
            sys.stdout.flush()


def _show_purchase_prompt():
    """Open purchase page in browser and prompt for key."""
    GREEN = "\x1b[32m"
    DIM = "\x1b[2m"
    RESET = "\x1b[0m"

    print()
    print(f" {GREEN}THE RED PILL{RESET}")
    print()
    print(f" {DIM}Opening purchase page...{RESET}")

    import platform
    opener = "open" if platform.system() == "Darwin" else "xdg-open"
    try:
        subprocess.Popen(
            [opener, "https://matrixshader.com/redpill"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass

    print()


def _handle_activation(key):
    """Activate a license key and print result. Returns exit code."""
    from license_service import activate, ActivationResult

    GREEN = "\x1b[32m"
    RED = "\x1b[31m"
    DIM = "\x1b[2m"
    RESET = "\x1b[0m"

    print()
    result = activate(key)

    if result == ActivationResult.SUCCESS:
        print(f" {GREEN}Welcome to the real world.{RESET}")
        print()
        print(f" {DIM}License activated. Run 'redpill' to open the control panel.{RESET}")
        print()
        return 0

    if result == ActivationResult.ACTIVATION_LIMIT_EXCEEDED:
        print(f" {RED}Activation limit reached.{RESET}")
        print()
        print(f" {DIM}This key has been activated on too many machines.{RESET}")
        print(f" {DIM}If this is your key, contact support for help.{RESET}")
        print()
        return 1

    if result == ActivationResult.SERVER_UNREACHABLE:
        YELLOW = "\x1b[33m"
        print(f" {YELLOW}Couldn't reach the activation server.{RESET}")
        print()
        print(f" {DIM}An internet connection is required for first-time activation.{RESET}")
        print(f" {DIM}After that, your license works fully offline — no phone-home ever.{RESET}")
        print(f" {DIM}Check your connection and try again.{RESET}")
        print()
        return 1

    # INVALID_KEY or SAVE_FAILED
    print(f" {RED}Invalid license key.{RESET}")
    print()
    print(f" {DIM}Format: REDPILL-XXXX-XXXX-XXXX-XXXX{RESET}")
    print(f" {DIM}Get your key at: https://matrixshader.com/redpill{RESET}")
    print()
    return 1


def main():
    # Handle --activate flag
    if "--activate" in sys.argv:
        idx = sys.argv.index("--activate")
        if idx + 1 < len(sys.argv):
            sys.exit(_handle_activation(sys.argv[idx + 1]))
        else:
            print(" Usage: redpill --activate REDPILL-XXXX-XXXX-XXXX-XXXX")
            sys.exit(1)

    # License gate — check before launching TUI
    from license_service import is_licensed

    if not is_licensed():
        _show_purchase_prompt()

        CYAN = "\x1b[36m"
        RESET = "\x1b[0m"

        print(f" {CYAN}Paste your key here after purchase (or press Enter to close): {RESET}", end="", flush=True)
        try:
            user_input = input().strip()
        except (EOFError, KeyboardInterrupt):
            user_input = ""

        if user_input:
            code = _handle_activation(user_input)
            if code == 0:
                print(" Close this window when ready.")
                import signal
                signal.pause()  # Wait forever — user closes window
            else:
                print(" Try again or close this window.")
                import signal
                signal.pause()
        sys.exit(0)

    tui = RedpillTUI()
    tui.run()


if __name__ == "__main__":
    main()
