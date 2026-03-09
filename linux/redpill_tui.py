#!/usr/bin/env python3
"""Red Pill TUI Control Panel for Matrix Shader (Linux/Ghostty).

Full-screen curses application for live adjustment of all shader parameters.
Direct port of MatrixShader.Cli.Redpill (C#/.NET).

Launch via `redpill` command (shell wrapper with Ghostty self-relaunch).
"""

import curses
import glob as _glob
import json
import os
import re
import subprocess
import sys
import tempfile

# Ensure linux/ directory is in sys.path for sibling imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from redpill_keys import PARAM_DELTAS, process_key
from shader_service import (
    PARAM_DEFAULTS,
    PARAM_RANGES,
    PRESET_COLORS,
    SLOT_SHADER_DIR,
    clamp_value,
    create_slot_shader,
    get_ghostty_bus_names,
    read_shader_config,
    reload_ghostty,
    write_shader_param,
    write_shader_params,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

GHOSTTY_BIN = "/home/neo/ghostty-build/zig-out/bin/ghostty"

# Color pair indices
CP_GREEN = 1
CP_YELLOW = 2
CP_RED = 3
CP_CYAN = 4
CP_MAGENTA = 5
CP_WHITE = 6

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
# Rendering helpers
# ---------------------------------------------------------------------------

def color_swatch(r, g, b, width=2):
    """Create ANSI 24-bit background color swatch string."""
    ri = int(max(0, min(255, r * 255)))
    gi = int(max(0, min(255, g * 255)))
    bi = int(max(0, min(255, b * 255)))
    return f"\033[48;2;{ri};{gi};{bi}m{' ' * width}\033[0m"


def progress_bar(val, min_val, max_val, width=15):
    """Create text progress bar: ====-------."""
    if max_val <= min_val:
        return "-" * width
    pct = max(0.0, min(1.0, (val - min_val) / (max_val - min_val)))
    filled = int(pct * width)
    empty = width - filled
    return "=" * filled + "-" * empty


def _safe_addstr(stdscr, row, col, text, attr=0):
    """addstr with bounds checking -- silently ignores out-of-bounds."""
    try:
        stdscr.addstr(row, col, text, attr)
    except curses.error:
        pass


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
        """Discover open Matrix windows and their colors."""
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
        """Read current opacity from first Ghostty config."""
        configs = sorted(_glob.glob("/tmp/ghostty-matrix-*.conf"))
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
    # Rendering
    # -------------------------------------------------------------------

    def render(self, stdscr):
        """Full screen render."""
        stdscr.erase()
        height, width = stdscr.getmaxyx()

        if height < 20 or width < 50:
            _safe_addstr(stdscr, 0, 0, "Terminal too small. Resize to 50x20+.", curses.A_BOLD)
            stdscr.refresh()
            return

        row = 0
        cfg = self.config

        # Header
        row += 1
        _safe_addstr(stdscr, row, 1, "RED PILL", curses.color_pair(CP_RED) | curses.A_BOLD)
        dirty_mark = "*" if self.dirty else " "
        slot_str = f"{dirty_mark}- Tab {self.active_slot}" if self.active_slot else " - No windows"
        _safe_addstr(stdscr, row, 9, slot_str)
        row += 2

        # Tab bar
        _safe_addstr(stdscr, row, 1, "TABS: ", curses.A_DIM)
        col = 7
        if not self.tabs:
            _safe_addstr(stdscr, row, col, "(no Matrix windows detected)", curses.A_DIM)
        else:
            for slot, r, g, b in self.tabs:
                if slot == self.active_slot:
                    _safe_addstr(stdscr, row, col, f"[{slot}]",
                                 curses.color_pair(CP_YELLOW) | curses.A_BOLD)
                else:
                    _safe_addstr(stdscr, row, col, f" {slot} ", curses.A_DIM)
                col += 4
                swatch = color_swatch(r, g, b, 1)
                _safe_addstr(stdscr, row, col, swatch)
                col += 3
        row += 1
        _safe_addstr(stdscr, row, 1, "[TAB] next tab", curses.A_DIM)
        row += 2

        # Agent Colors
        _safe_addstr(stdscr, row, 1, "AGENT COLORS", curses.color_pair(CP_WHITE) | curses.A_BOLD)
        row += 1
        col = 1
        for i, (pr, pg, pb) in enumerate(PRESET_COLORS):
            label = f"[{i+1}]"
            _safe_addstr(stdscr, row, col, label)
            col += len(label)
            swatch = color_swatch(pr, pg, pb, 2)
            _safe_addstr(stdscr, row, col, swatch)
            col += 2
            name = PRESET_NAMES[i]
            _safe_addstr(stdscr, row, col, name)
            col += len(name) + 1
        row += 2

        # Current Color
        cr, cg, cb = cfg.get("RAIN_R", 0), cfg.get("RAIN_G", 1), cfg.get("RAIN_B", 0.3)
        _safe_addstr(stdscr, row, 1, "CURRENT ")
        _safe_addstr(stdscr, row, 9, color_swatch(cr, cg, cb, 3))
        row += 1
        row = self._render_param_row(stdscr, row, "Q/W", "Red",   cr, 0, 1)
        row = self._render_param_row(stdscr, row, "A/S", "Green", cg, 0, 1)
        row = self._render_param_row(stdscr, row, "Z/X", "Blue",  cb, 0, 1)
        row += 1

        # Rain Parameters
        _safe_addstr(stdscr, row, 1, "RAIN PARAMETERS", curses.color_pair(CP_WHITE) | curses.A_BOLD)
        row += 1
        row = self._render_param_row(stdscr, row, "E/R", "Speed",
                                     cfg.get("RAIN_SPEED", 0.8), 0.1, 5.0)
        row = self._render_param_row(stdscr, row, "D/F", "Glow",
                                     cfg.get("GLOW_STRENGTH", 0.8), 0.2, 3.0)
        row = self._render_param_row(stdscr, row, "C/V", "Width",
                                     cfg.get("CHAR_WIDTH", 10.0), 6.0, 20.0, fmt="%.0f")
        row = self._render_param_row(stdscr, row, "T/Y", "Trail",
                                     cfg.get("TRAIL_POWER", 8.0), 4.0, 15.0, fmt="%.0f")
        row = self._render_param_row(stdscr, row, "G/H", "Density",
                                     cfg.get("RAIN_DENSITY", 0.4), 0.2, 1.0)
        row += 1

        # Layers
        _safe_addstr(stdscr, row, 1, "LAYERS", curses.color_pair(CP_WHITE) | curses.A_BOLD)
        row += 1
        l1 = cfg.get("SHOW_L1", 1.0) >= 0.5
        l2 = cfg.get("SHOW_L2", 1.0) >= 0.5
        l3 = cfg.get("SHOW_L3", 1.0) >= 0.5
        col = 1
        for key, name, on in [("7", "Far", l1), ("8", "Mid", l2), ("9", "Near", l3)]:
            label = f"[{key}] {name}: "
            _safe_addstr(stdscr, row, col, label)
            col += len(label)
            status = "ON " if on else "off"
            attr = curses.color_pair(CP_GREEN) if on else curses.A_DIM
            _safe_addstr(stdscr, row, col, status, attr)
            col += len(status) + 2
        row += 2

        # Window Effects
        _safe_addstr(stdscr, row, 1, "WINDOW EFFECTS", curses.color_pair(CP_WHITE) | curses.A_BOLD)
        row += 1
        trans_status = "ON " if self.transparency else "off"
        trans_attr = curses.color_pair(CP_CYAN) if self.transparency else curses.A_DIM
        _safe_addstr(stdscr, row, 1, "[B] Transparency: ")
        _safe_addstr(stdscr, row, 19, trans_status, trans_attr)
        row += 1
        bar = progress_bar(self.opacity, 0, 100)
        _safe_addstr(stdscr, row, 1, f"[K/L] Opacity: {self.opacity:3d}% {bar}", curses.A_DIM)
        row += 2

        # Combat Training
        _safe_addstr(stdscr, row, 1, "COMBAT TRAINING", curses.color_pair(CP_WHITE) | curses.A_BOLD)
        row += 1
        glitch_on = self.layout.get("glitch_enabled", False)
        glitch_status = "ON " if glitch_on else "off"
        glitch_attr = curses.color_pair(CP_CYAN) if glitch_on else curses.A_DIM
        _safe_addstr(stdscr, row, 1, " [Shift+G] Glitch:  ")
        _safe_addstr(stdscr, row, 21, glitch_status, glitch_attr)
        _safe_addstr(stdscr, row, 25, "(windows auto-snap to formation)", curses.A_DIM)
        row += 1
        layout_mode = self.layout.get("mode", "Pillars")
        layout_attr = curses.color_pair(CP_YELLOW) if layout_mode == "Pillars" else curses.color_pair(CP_MAGENTA)
        _safe_addstr(stdscr, row, 1, " [Shift+L] Layout:  ")
        _safe_addstr(stdscr, row, 21, layout_mode, layout_attr)
        _safe_addstr(stdscr, row, 21 + len(layout_mode) + 1, "(Pillars=columns, Quads=2x2)", curses.A_DIM)
        row += 2

        # Deploy
        _safe_addstr(stdscr, row, 1, "DEPLOY", curses.color_pair(CP_MAGENTA) | curses.A_BOLD)
        row += 1
        if self.tabs:
            open_str = ",".join(str(t[0]) for t in self.tabs)
        else:
            open_str = "none"
        _safe_addstr(stdscr, row, 1, "Open: ", curses.A_DIM)
        _safe_addstr(stdscr, row, 7, open_str, curses.color_pair(CP_GREEN))
        row += 1
        count_str = f"{self.launch_count} window(s)" if self.launch_count > 0 else "0"
        count_attr = curses.color_pair(CP_MAGENTA) if self.launch_count > 0 else curses.A_DIM
        _safe_addstr(stdscr, row, 1, "[-/+] Count: ")
        _safe_addstr(stdscr, row, 14, count_str, count_attr)
        row += 2

        # Footer
        enter_attr = curses.color_pair(CP_YELLOW) if self.launch_count > 0 else curses.A_DIM
        _safe_addstr(stdscr, row, 1, "[ENTER] Deploy", enter_attr)
        _safe_addstr(stdscr, row, 17, "  [0] Reset  [ESC] Quit", curses.A_DIM)
        row += 1
        _safe_addstr(stdscr, row, 1, "[?] Help  [Shift+H] Hotkeys  [Shift+S] Save pos  [Shift+R] Restore", curses.A_DIM)
        row += 1
        _safe_addstr(stdscr, row, 1, "All changes apply instantly", curses.color_pair(CP_GREEN))

        stdscr.refresh()

    def _render_param_row(self, stdscr, row, keys, label, val, min_val, max_val, fmt="%.1f"):
        """Render a parameter row: [E/R] Speed   0.8 ====-------"""
        bar = progress_bar(val, min_val, max_val)
        val_str = fmt % val
        line = f" [{keys}] {label:<8s} {val_str:>4s} {bar}"
        _safe_addstr(stdscr, row, 0, line)
        return row + 1

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
            self.opacity = max(0, self.opacity - 5)
            if self.transparency:
                self._apply_opacity(self.opacity)
            return
        if action == "OpacityIncrease":
            self.opacity = min(100, self.opacity + 5)
            if self.transparency:
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
            # Restore is a no-op if nothing saved; actual repositioning deferred to Phase 6
            return
        if action == "PriorityToggle":
            self.layout["priority_lock"] = not self.layout.get("priority_lock", False)
            self._save_layout()
            return
        if action == "MonitorChange":
            # Re-apply layout -- actual repositioning deferred to Phase 6
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
            self._show_help(self._stdscr)
            return

        # Hotkey config screen
        if action == "HotkeyConfig":
            self._show_hotkey_config(self._stdscr)
            return

    def _update_tab_color(self):
        """Update the active tab's color in the tabs list after RGB change."""
        if self.active_slot is None:
            return
        r = self.config.get("RAIN_R", 0)
        g = self.config.get("RAIN_G", 1)
        b = self.config.get("RAIN_B", 0.3)
        self.tabs = [
            (slot, r, g, b) if slot == self.active_slot else (slot, tr, tg, tb)
            for slot, tr, tg, tb in self.tabs
        ]

    def _apply_opacity(self, percent):
        """Write opacity to all matrix config files and reload."""
        value = f"{percent / 100:.2f}"
        if value == "0.00":
            value = "0"
        if value == "1.00":
            value = "1"

        for conf in _glob.glob("/tmp/ghostty-matrix-*.conf"):
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
        conf_path = f"/tmp/ghostty-matrix-{slot}.conf"

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
            # Fallback: try PATH
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
    # Main loop
    # -------------------------------------------------------------------

    def _show_help(self, stdscr):
        """Show full help screen, wait for any keypress to return."""
        if stdscr is None:
            return
        stdscr.erase()
        row = 0
        _safe_addstr(stdscr, row, 1, "HOTKEY HELP", curses.color_pair(CP_GREEN) | curses.A_BOLD)
        row += 2
        _safe_addstr(stdscr, row, 1, "CONTROL PANEL KEYS (local):", curses.A_DIM)
        row += 2
        help_lines = [
            "  [1-6]      Agent colors (Green/Blue/Red/Purple/Gold/Teal)",
            "  [Q/W]      Red -/+          [A/S] Green -/+    [Z/X] Blue -/+",
            "  [E/R]      Speed -/+        [D/F] Glow -/+",
            "  [C/V]      Width -/+        [T/Y] Trail -/+    [G/H] Density -/+",
            "  [7/8/9]    Toggle layers (Far/Mid/Near)",
            "  [B]        Toggle transparency    [K/L] Opacity -/+",
            "  [-/+]      Deploy count -/+       [ENTER] Deploy windows",
            "  [0]        Reset to defaults       (all changes apply instantly)",
            "  [TAB]      Switch tabs            [ESC] Quit",
        ]
        for line in help_lines:
            _safe_addstr(stdscr, row, 0, line)
            row += 1
        row += 1
        _safe_addstr(stdscr, row, 1, "SHIFT KEYS (local):", curses.A_DIM)
        row += 2
        shift_lines = [
            "  [Shift+G]  Toggle Glitch (auto-snap to formation)",
            "  [Shift+L]  Cycle layout mode (Pillars/Quads/Overlap)",
            "  [Shift+H]  Configure global hotkey bindings",
            "  [Shift+S]  Save snapback position",
            "  [Shift+R]  Restore snapback position",
        ]
        for line in shift_lines:
            _safe_addstr(stdscr, row, 0, line)
            row += 1
        row += 1
        _safe_addstr(stdscr, row, 1, "GLOBAL HOTKEYS (active when Matrix windows exist):", curses.color_pair(CP_GREEN))
        row += 2
        global_lines = [
            "  Ctrl+Shift+L       Cycle layout mode",
            "  Ctrl+Shift+B       Toggle background transparency",
            "  Ctrl+Shift+J/K     Decrease/Increase opacity",
            "  Ctrl+Shift+Up/Down Decrease/Increase rain speed",
            "  Ctrl+Shift+1/2/3   Toggle FAR/MID/NEAR layers",
            "  Ctrl+Shift+H       Show help overlay",
            "  Ctrl+Shift+F5      Force reload all shaders",
        ]
        for line in global_lines:
            _safe_addstr(stdscr, row, 0, line)
            row += 1
        row += 2
        _safe_addstr(stdscr, row, 1, "Press [Shift+H] to customize global hotkey bindings.", curses.A_DIM)
        row += 2
        _safe_addstr(stdscr, row, 1, "Press any key to return...", curses.color_pair(CP_GREEN))
        stdscr.refresh()
        stdscr.getch()

    def _show_hotkey_config(self, stdscr):
        """Launch the hotkey config screen (if available)."""
        try:
            from hotkey_config_screen import HotkeyConfigScreen
            screen = HotkeyConfigScreen()
            screen.run(stdscr)
        except ImportError:
            if stdscr:
                _safe_addstr(stdscr, 0, 0, "Hotkey config screen not available.", curses.A_BOLD)
                stdscr.refresh()
                stdscr.getch()

    def run(self, stdscr):
        """Main curses loop: render -> getch -> dispatch -> repeat."""
        self._stdscr = stdscr
        curses.curs_set(0)
        stdscr.keypad(True)
        curses.start_color()
        curses.use_default_colors()

        curses.init_pair(CP_GREEN, curses.COLOR_GREEN, -1)
        curses.init_pair(CP_YELLOW, curses.COLOR_YELLOW, -1)
        curses.init_pair(CP_RED, curses.COLOR_RED, -1)
        curses.init_pair(CP_CYAN, curses.COLOR_CYAN, -1)
        curses.init_pair(CP_MAGENTA, curses.COLOR_MAGENTA, -1)
        curses.init_pair(CP_WHITE, curses.COLOR_WHITE, -1)

        self.refresh_tabs()

        try:
            while self.running:
                self.render(stdscr)
                key = stdscr.getch()
                action = process_key(key)
                if action:
                    self.handle_action(action)
        finally:
            self.save_full_state()


def main():
    tui = RedpillTUI()
    curses.wrapper(tui.run)


if __name__ == "__main__":
    main()
