"""Construct CLI service -- quick launch, white room picker, TransitionToRain.

Linux port of Windows Construct/Program.cs.
Provides:
  - find_next_slot(): lowest unused slot 1-8
  - quick_launch(color): create shader + Ghostty config for instant launch
  - transition_to_rain(slot, preset_idx): swap white-room to rain in same window
  - white_room_picker(): arrow-key color picker (reads /dev/tty)
  - show_help(): print --help output with colors and bonus shaders sections

Dependencies: Python 3 stdlib + shader_service.py (sibling module).
"""

import os
import re
import sys
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
    """Scan running Ghostty processes and return set of occupied slot numbers.

    Uses pgrep + /proc/PID/exe readlink to filter to real ghostty processes
    (same approach as wakeupneo.sh get_open_slots).
    """
    occupied = set()
    for slot in range(1, 9):
        conf = f"/tmp/ghostty-matrix-{slot}.conf"
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

def transition_to_rain(slot: int, preset_idx: int) -> bool:
    """Swap white-room shader to rain shader in the same Ghostty window.

    1. Create rain shader for the slot via create_slot_shader
    2. Rewrite Ghostty config: shader path + opacity
    3. Trigger D-Bus reload

    Args:
        slot: Window slot number (1-8).
        preset_idx: Color preset index (0-5).

    Returns:
        True on success, False on failure.
    """
    # 1. Create rain shader
    shader_path = shader_service.create_slot_shader(slot, preset_idx=preset_idx)

    # 2. Rewrite Ghostty config
    conf_path = f"/tmp/ghostty-matrix-{slot}.conf"
    try:
        with open(conf_path) as f:
            content = f.read()
    except FileNotFoundError:
        return False

    # Replace custom-shader line (from white-room to rain shader)
    content = re.sub(
        r"custom-shader = .*",
        f"custom-shader = {shader_path}",
        content,
    )

    # Replace background-opacity from 1.0 to 0.85
    content = re.sub(
        r"background-opacity = 1\.0",
        "background-opacity = 0.85",
        content,
    )

    # Atomic write
    dir_path = os.path.dirname(conf_path)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, conf_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        return False

    # 3. Trigger D-Bus reload
    mapping = shader_service.get_ghostty_bus_names()
    if slot in mapping:
        shader_service.reload_ghostty(mapping[slot]["bus_name"])

    return True


# ---------------------------------------------------------------------------
# White room picker
# ---------------------------------------------------------------------------

COLOR_NAMES = ["Green", "Blue", "Red", "Purple", "Gold", "Teal"]

# ANSI color codes for display
COLOR_ANSI = [
    "\033[0;32m",   # Green
    "\033[0;34m",   # Blue
    "\033[0;31m",   # Red
    "\033[0;35m",   # Purple
    "\033[0;33m",   # Gold
    "\033[0;36m",   # Teal
]


def white_room_picker() -> int | None:
    """Arrow-key color picker loop for white room mode.

    Reads input from /dev/tty, prints ANSI menu.
    Returns selected preset index (0-5), or None if cancelled.
    """
    selected = 0
    count = len(COLOR_NAMES)

    GREEN = "\033[0;32m"
    DIM = "\033[2m"
    RESET = "\033[0m"
    BRIGHT_GREEN = "\033[1;32m"

    try:
        tty = open("/dev/tty", "r")
    except (FileNotFoundError, OSError):
        # Fallback if no tty (testing, piped input)
        return 0

    # Hide cursor
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()

    # Initial draw
    print(file=sys.stderr)
    print(f" {DIM}Choose your color:{RESET}", file=sys.stderr)
    print(file=sys.stderr)
    for i in range(count):
        if i == selected:
            print(f"   {GREEN}>{RESET} {BRIGHT_GREEN}{COLOR_NAMES[i]}{RESET}", file=sys.stderr)
        else:
            print(f"     \033[90m{COLOR_NAMES[i]}\033[0m", file=sys.stderr)

    try:
        import termios
        import tty as tty_mod

        old_settings = termios.tcgetattr(tty)
        tty_mod.setraw(tty.fileno())

        try:
            while True:
                ch = tty.read(1)
                if ch == "\x1b":
                    ch2 = tty.read(1)
                    if ch2 == "[":
                        ch3 = tty.read(1)
                        if ch3 == "A":  # Up
                            selected = (selected - 1 + count) % count
                        elif ch3 == "B":  # Down
                            selected = (selected + 1) % count
                elif ch == "\r" or ch == "\n":  # Enter
                    break
                elif ch == "\x03":  # Ctrl+C
                    return None
                elif ch == "\x1b":  # Escape
                    return None
                else:
                    continue

                # Redraw
                sys.stderr.write(f"\033[{count}A")
                for i in range(count):
                    sys.stderr.write("\033[2K")
                    if i == selected:
                        sys.stderr.write(f"   {GREEN}>{RESET} {BRIGHT_GREEN}{COLOR_NAMES[i]}{RESET}\n")
                    else:
                        sys.stderr.write(f"     \033[90m{COLOR_NAMES[i]}\033[0m\n")
                sys.stderr.flush()
        finally:
            termios.tcsetattr(tty, termios.TCSADRAIN, old_settings)
    except (ImportError, termios.error):
        # Fallback for environments without termios
        pass
    finally:
        tty.close()
        # Show cursor
        sys.stdout.write("\033[?25h")
        sys.stdout.flush()

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
    sub.add_parser("white-room", help="Run the white room color picker")

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
        selected = white_room_picker()
        if selected is None:
            print("cancelled", file=sys.stderr)
            raise SystemExit(1)
        print(selected)

    elif args.command == "help":
        show_help()

    else:
        show_help()


if __name__ == "__main__":
    _cli()
