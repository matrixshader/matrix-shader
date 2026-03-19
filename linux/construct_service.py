"""Construct CLI service -- quick launch, white room picker, TransitionToRain.

Linux port of Windows Construct/Program.cs.
Provides:
  - find_next_slot(): lowest unused slot 1-8
  - quick_launch(color): create shader + Ghostty config for instant launch
  - transition_to_rain(slot, preset_idx): swap white-room to rain in same window
  - white_room_picker(): ANSI bg-color state picker (shader reads terminal texture)
  - write_picker_state(selected, zoom_byte, power_off_byte): ANSI bg state writer
  - animate_zoom_in(): zoom-in animation (0->255 over 1.5s, ease-out cubic)
  - animate_power_off(selected): CRT power-off animation (1.0s)
  - show_help(): print --help output with colors and bonus shaders sections

Dependencies: Python 3 stdlib + shader_service.py (sibling module).
"""

import os
import re
import select
import sys
import time
import shutil
import subprocess
import tempfile

# Import sibling shader_service
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shader_service


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Standard color name -> preset index (matches shader_service.PRESET_COLORS)
COLOR_MAP = {
    "green":  0,
    "blue":   1,
    "red":    2,
    "purple": 3,
    "gold":   4,
    "teal":   5,
}

# Bonus shader name -> source filename (in shaders-glsl/)
BONUS_SHADERS = {
    "aurora":       "aurora-borealis-ghostty.glsl",
    "aurora-rain":  "aurora-rain-ghostty.glsl",
    "fireplace":    "fireplace-ghostty.glsl",
    "codevision":   "matrix-codevision-ghostty.glsl",
    "ultra":        "matrix-ultra-ghostty.glsl",
    "rain-on-glass": "rain-on-glass-ghostty.glsl",
}

# Foreground colors for each preset index (for Ghostty config)
PRESET_FOREGROUNDS = {
    0: "#00ff4d",   # Green
    1: "#0099ff",   # Blue
    2: "#ff1a1a",   # Red
    3: "#b300ff",   # Purple
    4: "#ffb300",   # Gold
    5: "#00e6e6",   # Teal
}

# Per-slot shader file directory (same as shader_service)
SLOT_SHADER_DIR = shader_service.SLOT_SHADER_DIR

# Template shader path (for create_slot_shader)
TEMPLATE_PATH = shader_service.TEMPLATE_PATH

# Bonus shader source directory
SHADER_SRC_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "shaders-glsl"
)


# ---------------------------------------------------------------------------
# Slot management
# ---------------------------------------------------------------------------

def _get_occupied_slots() -> set:
    """Return set of occupied slot numbers from window map + pgrep scan."""
    occupied = set()
    # Primary source: window_service mapping (has dead-PID purge + orphan recovery)
    try:
        import window_service
        mapping = window_service.load_mapping()
        for slot_str, entry in mapping.items():
            pid = entry.get('pid')
            if pid and window_service._pid_alive(pid):
                occupied.add(int(slot_str))
    except (ImportError, Exception):
        pass
    # Secondary source: pgrep scan (catches windows not yet registered)
    for slot in range(1, 9):
        if slot in occupied:
            continue
        for pattern in [f"ghostty-matrix-{slot}", f"ghostty-construct-{slot}"]:
            conf = f"/tmp/{pattern}.conf"
            if not os.path.isfile(conf):
                continue
            try:
                result = subprocess.run(
                    ["pgrep", "-f", f"config-file={conf}"],
                    capture_output=True, text=True, timeout=3,
                    stdin=subprocess.DEVNULL,
                )
                if result.returncode != 0:
                    continue
                for pid_str in result.stdout.strip().split():
                    try:
                        exe = os.readlink(f"/proc/{pid_str}/exe")
                        if "ghostty" in exe:
                            occupied.add(slot)
                            break
                    except (FileNotFoundError, PermissionError, OSError):
                        continue
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
    return occupied


def find_next_slot() -> int | None:
    """Return the lowest unused slot number (1-8), or None if all full."""
    occupied = _get_occupied_slots()
    for slot in range(1, 9):
        if slot not in occupied:
            return slot
    return None


# ---------------------------------------------------------------------------
# Quick launch
# ---------------------------------------------------------------------------

def _write_ghostty_config(slot: int, shader_path: str,
                          fg_color: str = "#00ff4d",
                          opacity: str = "0.85") -> str:
    """Write a Ghostty config file for a matrix slot.

    Returns the config file path.
    """
    conf_path = f"/tmp/ghostty-matrix-{slot}.conf"
    content = (
        f"custom-shader = {shader_path}\n"
        f"background = #000000\n"
        f"foreground = {fg_color}\n"
        f"font-family = Nimbus Mono PS\n"
        f"font-style = Bold\n"
        f"background-opacity = {opacity}\n"
        f"gtk-titlebar = true\n"
        f"window-decoration = client\n"
        f"custom-shader-animation = always\n"
        f"desktop-notifications = false\n"
        f"keybind = ctrl+shift+j=unbind\n"
        f"keybind = ctrl+shift+k=unbind\n"
        f"keybind = ctrl+shift+b=unbind\n"
        f"keybind = ctrl+shift+h=unbind\n"
        f"keybind = ctrl+shift+l=unbind\n"
        f"keybind = ctrl+shift+one=unbind\n"
        f"keybind = ctrl+shift+two=unbind\n"
        f"keybind = ctrl+shift+three=unbind\n"
        f"keybind = ctrl+shift+up=unbind\n"
        f"keybind = ctrl+shift+down=unbind\n"
        f"keybind = ctrl+shift+left=unbind\n"
        f"keybind = ctrl+shift+right=unbind\n"
        f"keybind = ctrl+shift+f5=unbind\n"
        f"keybind = ctrl+shift+s=unbind\n"
        f"keybind = ctrl+shift+r=unbind\n"
        f"keybind = ctrl+shift+g=unbind\n"
    )
    with open(conf_path, "w") as f:
        f.write(content)
    return conf_path


def quick_launch(color: str) -> dict:
    """Create shader + Ghostty config for instant single-window launch.

    Args:
        color: Color name (e.g. "green", "aurora").

    Returns:
        {"slot": int, "conf": str, "shader": str} on success.
        {"error": str} on failure.
    """
    slot = find_next_slot()
    if slot is None:
        return {"error": "All 8 shader slots are in use. Close a Matrix window first."}

    # Determine if standard color or bonus shader
    if color in COLOR_MAP:
        preset_idx = COLOR_MAP[color]
        shader_path = shader_service.create_slot_shader(slot, preset_idx=preset_idx)
        fg_color = PRESET_FOREGROUNDS.get(preset_idx, "#00ff4d")
    elif color in BONUS_SHADERS:
        # Copy bonus shader to slot directory as matrix-{slot}.glsl
        # (per RESEARCH.md Pitfall 6: slot naming convention must be maintained)
        src_name = BONUS_SHADERS[color]
        src_path = os.path.join(SHADER_SRC_DIR, src_name)
        os.makedirs(SLOT_SHADER_DIR, exist_ok=True)
        dest_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")
        shutil.copy2(src_path, dest_path)
        shader_path = dest_path
        fg_color = "#00ff4d"  # Default green for bonus shaders
    else:
        return {"error": f"Unknown color: {color}"}

    conf_path = _write_ghostty_config(slot, shader_path, fg_color=fg_color)

    return {"slot": slot, "conf": conf_path, "shader": shader_path}


# ---------------------------------------------------------------------------
# TransitionToRain
# ---------------------------------------------------------------------------

def transition_to_rain(slot: int, preset_idx: int,
                       construct_conf: str = None) -> bool:
    """Swap white-room shader to rain shader in the SAME Ghostty window.

    Matches Windows TransitionToRain: modifies the construct config IN PLACE,
    swapping shader path, opacity, fullscreen, and decorations. Ghostty detects
    the config change on D-Bus reload and renders the new shader in the
    already-open window. No new window spawned.

    After transition, registers the window in window_service so redpill,
    hotkeys, glitch snap, and layout engine can all find it.

    Args:
        slot: Window slot number (1-8).
        preset_idx: Color preset index (0-5).
        construct_conf: Path to the CONSTRUCT Ghostty config file that the
                        running Ghostty process is actually reading.

    Returns:
        True on success, False on failure.
    """
    # 1. Create rain shader for this slot
    shader_path = shader_service.create_slot_shader(slot, preset_idx=preset_idx)
    fg_color = PRESET_FOREGROUNDS.get(preset_idx, "#00ff4d")

    # 2. Find the construct config that Ghostty is ACTUALLY reading
    if construct_conf is None:
        for s in range(1, 9):
            p = f"/tmp/ghostty-construct-{s}.conf"
            if os.path.isfile(p):
                construct_conf = p
                break
    if construct_conf is None:
        return False

    # 3. Write a proper matrix rain config (not patching — full rewrite)
    #    This matches what _write_ghostty_config produces for quick-launch
    matrix_conf = f"/tmp/ghostty-matrix-{slot}.conf"
    _write_ghostty_config(slot, shader_path, fg_color=fg_color, opacity="0")

    # 4. ALSO overwrite the construct config with the same content
    #    (Ghostty is reading THIS file — the matrix config is for future use)
    try:
        import shutil
        shutil.copy2(matrix_conf, construct_conf)
    except OSError:
        return False

    # 5. Trigger D-Bus reload on the construct window ONLY
    bus_name = _find_construct_bus_name()
    if bus_name:
        shader_service.reload_ghostty(bus_name)

    # 6. Register window in window_service for system integration
    #    (redpill, hotkeys, glitch, layout engine)
    try:
        import window_service
        # Find the construct Ghostty PID
        result = subprocess.run(
            ["pgrep", "-f", f"config-file={construct_conf}"],
            capture_output=True, text=True, timeout=3,
            stdin=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            for pid_str in result.stdout.strip().split():
                try:
                    exe = os.readlink(f"/proc/{pid_str}/exe")
                    if "ghostty" in exe:
                        window_service.register_window(slot, int(pid_str))
                        break
                except (FileNotFoundError, PermissionError, OSError):
                    continue
    except ImportError:
        pass

    # 7. Save shader config to state
    try:
        import state_service
        state = state_service.load_state()
        preset_colors = [
            {"RAIN_R": 0.0, "RAIN_G": 1.0, "RAIN_B": 0.3},   # Green
            {"RAIN_R": 0.0, "RAIN_G": 0.6, "RAIN_B": 1.0},   # Blue
            {"RAIN_R": 1.0, "RAIN_G": 0.0, "RAIN_B": 0.0},   # Red
            {"RAIN_R": 0.6, "RAIN_G": 0.0, "RAIN_B": 0.8},   # Purple
            {"RAIN_R": 0.85, "RAIN_G": 0.65, "RAIN_B": 0.0},  # Gold
            {"RAIN_R": 0.0, "RAIN_G": 0.75, "RAIN_B": 0.8},   # Teal
        ]
        if 0 <= preset_idx < len(preset_colors):
            config = {
                **preset_colors[preset_idx],
                "RAIN_SPEED": 1.8, "GLOW_STRENGTH": 0.8,
                "CHAR_WIDTH": 10.0, "TRAIL_POWER": 8.0,
                "RAIN_DENSITY": 0.2,
                "SHOW_L1": 1.0, "SHOW_L2": 1.0, "SHOW_L3": 1.0,
            }
            state.setdefault("shader_configs", {})[str(slot)] = config
            state["active_tab"] = slot
            state_service.save_state(state)
    except ImportError:
        pass

    return True


# ---------------------------------------------------------------------------
# White room picker -- ANSI bg-color state communication
# ---------------------------------------------------------------------------
#
# The shader reads the terminal texture (iChannel0) to get picker state:
#   R channel = (selected + 1) * 40   -> swatch index 0-5
#   G channel = zoom level 0-255      -> far to close
#   B channel = power-off level 0-255 -> normal to black
#
# Python writes ANSI 24-bit background color to the first row of the terminal.
# The shader samples those pixels to determine selection, zoom, and power-off.

COLOR_NAMES = ["Green", "Blue", "Red", "Purple", "Gold", "Teal"]

_cached_construct_bus_name = None


def _warm_bus_cache():
    """Pre-discover bus name before entering the picker loop."""
    global _cached_construct_bus_name
    _cached_construct_bus_name = None  # force refresh
    _find_construct_bus_name()


def _find_construct_bus_name():
    """Find the D-Bus name for the construct Ghostty window ONLY (cached).

    Uses busctl to list Ghostty D-Bus names, then matches PID to the
    construct process via /proc/PID/cmdline containing 'ghostty-construct'.
    Returns bus_name string or None.
    """
    global _cached_construct_bus_name
    if _cached_construct_bus_name is not None:
        return _cached_construct_bus_name
    try:
        result = subprocess.run(
            ["busctl", "--user", "list"],
            capture_output=True, text=True, timeout=5,
            stdin=subprocess.DEVNULL,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None

    # Build PID -> bus_name map for Ghostty processes
    bus_entries = {}
    for line in result.stdout.splitlines():
        if "ghostty" not in line.lower():
            continue
        parts = line.split()
        if len(parts) >= 2:
            try:
                bus_entries[int(parts[1])] = parts[0]
            except (ValueError, IndexError):
                continue

    # Find which PID has "ghostty-construct" in its cmdline
    for pid, bus_name in bus_entries.items():
        try:
            with open(f"/proc/{pid}/cmdline") as f:
                cmdline = f.read()
            if "ghostty-construct" in cmdline:
                _cached_construct_bus_name = bus_name
                return bus_name
        except (FileNotFoundError, PermissionError):
            continue

    return None


def _write_shader_defines(shader_path, selected, state, state_time):
    """Rewrite #define values in the white room shader COPY and trigger D-Bus reload."""
    try:
        with open(shader_path) as f:
            content = f.read()
    except FileNotFoundError:
        return

    content = re.sub(r"(#define\s+SELECTED\s+)\S+", f"\\g<1>{selected}", content)
    content = re.sub(r"(#define\s+STATE\s+)\S+", f"\\g<1>{state}", content)
    content = re.sub(r"(#define\s+STATE_TIME\s+)\S+", f"\\g<1>{state_time:.3f}", content)

    # Atomic write
    dir_path = os.path.dirname(shader_path)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, shader_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        return

    # Reload ONLY the construct window (cached bus name)
    bus_name = _find_construct_bus_name()
    if bus_name:
        shader_service.reload_ghostty(bus_name)


def write_picker_state(selected, state, shader_path, state_time=None):
    """Write picker state to shader copy via #define rewrite + targeted D-Bus reload."""
    if state_time is None:
        state_time = _approx_itime()
    _write_shader_defines(shader_path, selected, state, state_time)


_ghostty_start_monotonic = 0.0


def _init_time_tracking():
    """Initialize time tracking for iTime approximation.

    Called once when the picker starts inside Ghostty. Walks up the process
    tree to find the Ghostty parent and reads its start time from /proc.
    """
    global _ghostty_start_monotonic
    try:
        ghostty_pid = os.getppid()
        # Walk up to find Ghostty
        while ghostty_pid > 1:
            try:
                exe = os.readlink(f"/proc/{ghostty_pid}/exe")
                if "ghostty" in exe:
                    break
            except (FileNotFoundError, PermissionError, OSError):
                pass
            try:
                stat_data = open(f"/proc/{ghostty_pid}/stat").read()
                # Field 22 (0-indexed after ')' split, index 19) is starttime
                ghostty_pid = int(stat_data.split(')')[1].split()[1])  # ppid is field 4, index 1 after ')'
            except (FileNotFoundError, PermissionError, OSError, ValueError, IndexError):
                break
        stat = open(f"/proc/{ghostty_pid}/stat").read()
        # Field 22 (0-indexed 21) is starttime in clock ticks
        starttime_ticks = int(stat.split(')')[1].split()[19])
        clock_ticks = os.sysconf('SC_CLK_TCK')
        uptime = float(open("/proc/uptime").read().split()[0])
        process_start_seconds_ago = uptime - (starttime_ticks / clock_ticks)
        _ghostty_start_monotonic = time.monotonic() - process_start_seconds_ago
    except Exception:
        # Fallback: assume Ghostty started ~2 seconds ago
        _ghostty_start_monotonic = time.monotonic() - 2.0


def _approx_itime():
    """Return approximate iTime value for the running Ghostty."""
    return time.monotonic() - _ghostty_start_monotonic


def animate_zoom_in(selected, shader_path):
    """Trigger GPU-driven zoom-in by setting STATE=1, STATE_TIME=current iTime."""
    # STATE=1 tells the shader to compute zoom from iTime
    # Use _approx_itime() so the animation starts from the current moment
    state_time = _approx_itime()
    write_picker_state(selected, 1, shader_path, state_time=state_time)
    # Wait for the animation to complete before handing control to the picker
    time.sleep(3.0)
    # Transition to browsing state
    write_picker_state(selected, 2, shader_path, state_time=0.0)


def animate_power_off(selected, shader_path):
    """Trigger GPU-driven power-off by setting STATE=3."""
    state_time = _approx_itime()
    write_picker_state(selected, 3, shader_path, state_time=state_time)
    # Wait for the 1-second animation to complete
    time.sleep(1.2)


def white_room_picker(shader_path=None) -> int | None:
    """Shader-driven picker for the white room CRT TV.

    The shader renders the 3D CRT TV with color swatches. This function
    captures arrow keys and rewrites #define values in the shader COPY
    (in /tmp/), triggering a targeted D-Bus reload on the construct window only.

    Args:
        shader_path: Path to the shader COPY to rewrite. Must be a temp copy,
                     never the source file in shaders-glsl/.

    Returns:
        Selected preset index (0-5), or None if cancelled.
    """
    selected = 0
    count = len(COLOR_NAMES)
    if shader_path is None:
        # Fallback: find any construct shader copy in /tmp
        for s in range(1, 9):
            p = f"/tmp/ghostty-construct-{s}-shader.glsl"
            if os.path.isfile(p):
                shader_path = p
                break
    if shader_path is None:
        return 0  # Can't find shader, bail

    try:
        tty = open("/dev/tty", "r")
    except (FileNotFoundError, OSError):
        return 0

    # Hide cursor
    sys.stderr.write("\033[?25l")
    sys.stderr.flush()

    try:
        # Pre-cache bus name and init time tracking
        _warm_bus_cache()
        _init_time_tracking()

        # Zoom-in animation (GPU-driven, one write)
        animate_zoom_in(selected, shader_path)

        import termios
        import tty as tty_mod

        def _has_more(fd, timeout=0.1):
            """Check if more input is available within timeout."""
            if hasattr(fd, 'fileno'):
                r, _, _ = select.select([fd], [], [], timeout)
                return bool(r)
            return False

        old_settings = termios.tcgetattr(tty)
        tty_mod.setraw(tty.fileno())

        try:
            while True:
                ch = tty.read(1)
                if ch == "\x1b":
                    if _has_more(tty, 0.05):
                        ch2 = tty.read(1)
                        if ch2 == "[" and _has_more(tty, 0.05):
                            ch3 = tty.read(1)
                            if ch3 == "A":    # Up
                                selected = (selected + 3) % count
                            elif ch3 == "B":  # Down
                                selected = (selected + 3) % count
                            elif ch3 == "C":  # Right
                                selected = (selected + 1) % count
                            elif ch3 == "D":  # Left
                                selected = (selected - 1 + count) % count
                            else:
                                continue
                        else:
                            # Bare ESC or unknown sequence
                            animate_power_off(selected, shader_path)
                            return None
                    else:
                        # Bare ESC — no more bytes within timeout
                        animate_power_off(selected, shader_path)
                        return None
                elif ch == "\r" or ch == "\n":  # Enter
                    animate_power_off(selected, shader_path)
                    break
                elif ch == "\x03":  # Ctrl+C
                    animate_power_off(selected, shader_path)
                    return None
                else:
                    continue

                # Update shader with new selection (only SELECTED changes, not state)
                write_picker_state(selected, 2, shader_path, state_time=0.0)
        finally:
            termios.tcsetattr(tty, termios.TCSADRAIN, old_settings)
    except (ImportError, termios.error):
        write_picker_state(selected, 2, shader_path, state_time=0.0)
    finally:
        tty.close()
        sys.stderr.write("\033[?25h")
        sys.stderr.flush()

    return selected


# ---------------------------------------------------------------------------
# Help output
# ---------------------------------------------------------------------------

def show_help():
    """Print --help output with colors section and bonus shaders section."""
    print()
    print("Matrix Shader - Construct")
    print()
    print("Usage: construct [--color]")
    print()
    print("Colors:")
    print("  --green, --red, --blue, --purple, --gold, --teal")
    print()
    print("Bonus Shaders:")
    print("  --aurora, --aurora-rain, --fireplace")
    print("  --codevision, --ultra, --rain-on-glass")
    print()
    print("No arguments: opens the white room color picker")
    print()


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _cli():
    """CLI entry point for construct_service.py.

    Commands:
      quick-launch --color <name>   Create shader + config for a color
      white-room                    Run the white room picker
      help                          Show help text
    """
    import argparse

    parser = argparse.ArgumentParser(description="Construct service for Matrix Shader")
    sub = parser.add_subparsers(dest="command")

    # quick-launch
    p_launch = sub.add_parser("quick-launch", help="Quick launch with a color")
    p_launch.add_argument("--color", required=True, help="Color name")

    # white-room
    p_wr = sub.add_parser("white-room", help="Run the white room color picker")
    p_wr.add_argument("--shader-path", help="Path to shader COPY to rewrite (in /tmp)")

    # help
    sub.add_parser("help", help="Show help text")

    args = parser.parse_args()

    if args.command == "quick-launch":
        result = quick_launch(args.color)
        if "error" in result:
            print(result["error"], file=sys.stderr)
            raise SystemExit(1)
        # Print slot and conf path for shell to capture
        print(f"{result['slot']}:{result['conf']}")

    elif args.command == "white-room":
        selected = white_room_picker(shader_path=getattr(args, 'shader_path', None))
        if selected is None:
            raise SystemExit(1)
        print(selected)

    elif args.command == "help":
        show_help()

    else:
        show_help()


if __name__ == "__main__":
    _cli()
