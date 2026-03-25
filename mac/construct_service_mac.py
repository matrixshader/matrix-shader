"""macOS-adapted construct service for Matrix Shader.

Wraps linux/construct_service.py with macOS-specific reload mechanism
and process discovery (ps instead of /proc).

Consumed by: construct_mac.sh
Dependencies: Python 3 stdlib, linux/construct_service.py, platform_mac.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

MATRIX_TMP = f"/tmp/matrixshader-{os.getuid()}"
os.makedirs(MATRIX_TMP, exist_ok=True)

# Add linux/ and mac/ to path for imports
_linux_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "linux")
if _linux_dir not in sys.path:
    sys.path.insert(0, _linux_dir)

_mac_dir = os.path.dirname(os.path.abspath(__file__))
if _mac_dir not in sys.path:
    sys.path.insert(0, _mac_dir)

# Import shared constants and logic from Linux construct_service
from construct_service import (
    COLOR_MAP,
    BONUS_SHADERS,
    PRESET_FOREGROUNDS,
    SLOT_SHADER_DIR,
    SHADER_SRC_DIR,
    white_room_picker,
    show_help,
)

# Import core shader service (Linux)
import shader_service

# Import Mac platform functions
from platform_mac import get_ghostty_pids, reload_ghostty_mac


# ---------------------------------------------------------------------------
# Mac-specific slot discovery (ps instead of /proc)
# ---------------------------------------------------------------------------

def _get_occupied_slots_mac() -> set:
    """Scan running Ghostty processes on macOS for occupied slots.

    Uses `ps -eo pid,args` instead of /proc/PID/exe (Linux-only).
    """
    occupied = set()
    try:
        result = subprocess.run(
            ["ps", "-eo", "pid,args"],
            capture_output=True, text=True, timeout=5,
            stdin=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            return occupied
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return occupied

    for line in result.stdout.splitlines():
        line = line.strip()
        match = re.search(r"ghostty-matrix-(\d+)\.conf", line)
        if match:
            slot = int(match.group(1))
            if 1 <= slot <= 8:
                occupied.add(slot)

    return occupied


def find_next_slot_mac() -> int | None:
    """Return the lowest unused slot number (1-8), or None if all full."""
    occupied = _get_occupied_slots_mac()
    for slot in range(1, 9):
        if slot not in occupied:
            return slot
    return None


# ---------------------------------------------------------------------------
# Mac Ghostty config writer
# ---------------------------------------------------------------------------

def _write_ghostty_config_mac(slot: int, shader_path: str,
                               fg_color: str = "#00ff4d",
                               opacity: str = "0.85") -> str:
    """Write a Ghostty config file for a matrix slot (macOS version).

    Uses macos-titlebar-style instead of gtk-titlebar.
    Returns the config file path.
    """
    conf_path = f"{MATRIX_TMP}/ghostty-matrix-{slot}.conf"
    content = (
        f"custom-shader = {shader_path}\n"
        f"background = #000000\n"
        f"foreground = {fg_color}\n"
        f"font-family = SF Mono\n"
        f"font-style = Bold\n"
        f"background-opacity = {opacity}\n"
        f"macos-titlebar-style = hidden\n"
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


# ---------------------------------------------------------------------------
# Quick launch (Mac version)
# ---------------------------------------------------------------------------

def quick_launch(color: str) -> dict:
    """Create shader + Ghostty config for instant single-window launch.

    Mac version: uses find_next_slot_mac and _write_ghostty_config_mac.

    Args:
        color: Color name (e.g. "green", "aurora").

    Returns:
        {"slot": int, "conf": str, "shader": str} on success.
        {"error": str} on failure.
    """
    slot = find_next_slot_mac()
    if slot is None:
        return {"error": "All 8 shader slots are in use. Close a Matrix window first."}

    # Determine if standard color or bonus shader
    if color in COLOR_MAP:
        preset_idx = COLOR_MAP[color]
        shader_path = shader_service.create_slot_shader(slot, preset_idx=preset_idx)
        fg_color = PRESET_FOREGROUNDS.get(preset_idx, "#00ff4d")
    elif color in BONUS_SHADERS:
        src_name = BONUS_SHADERS[color]
        src_path = os.path.join(SHADER_SRC_DIR, src_name)
        os.makedirs(SLOT_SHADER_DIR, exist_ok=True)
        dest_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")
        shutil.copy2(src_path, dest_path)
        shader_path = dest_path
        fg_color = "#00ff4d"
    else:
        return {"error": f"Unknown color: {color}"}

    conf_path = _write_ghostty_config_mac(slot, shader_path, fg_color=fg_color)

    return {"slot": slot, "conf": conf_path, "shader": shader_path}


# ---------------------------------------------------------------------------
# TransitionToRain (Mac version -- SIGHUP instead of D-Bus)
# ---------------------------------------------------------------------------

def transition_to_rain_mac(slot: int, preset_idx: int) -> bool:
    """Swap white-room shader to rain shader in the same Ghostty window.

    Mac version: uses SIGHUP instead of D-Bus for reload.

    1. Create rain shader for the slot via create_slot_shader
    2. Rewrite Ghostty config: shader path + opacity
    3. Trigger SIGHUP reload

    Args:
        slot: Window slot number (1-8).
        preset_idx: Color preset index (0-5).

    Returns:
        True on success, False on failure.
    """
    # 1. Create rain shader
    shader_path = shader_service.create_slot_shader(slot, preset_idx=preset_idx)

    # 2. Rewrite Ghostty config
    conf_path = f"{MATRIX_TMP}/ghostty-matrix-{slot}.conf"
    try:
        with open(conf_path) as f:
            content = f.read()
    except FileNotFoundError:
        return False

    # Replace custom-shader line
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

    # 3. Trigger SIGHUP reload (Mac-specific)
    mapping = get_ghostty_pids()
    if slot in mapping:
        reload_ghostty_mac(mapping[slot]["pid"])

    return True


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _cli():
    """CLI entry point for construct_service_mac.py.

    Commands:
      quick-launch --color <name>   Create shader + config for a color
      white-room                    Run the white room picker
      help                          Show help text
    """
    import argparse

    parser = argparse.ArgumentParser(description="Construct service for Matrix Shader (macOS)")
    sub = parser.add_subparsers(dest="command")

    p_launch = sub.add_parser("quick-launch", help="Quick launch with a color")
    p_launch.add_argument("--color", required=True, help="Color name")

    sub.add_parser("white-room", help="Run the white room color picker")
    sub.add_parser("help", help="Show help text")

    args = parser.parse_args()

    if args.command == "quick-launch":
        result = quick_launch(args.color)
        if "error" in result:
            print(result["error"], file=sys.stderr)
            raise SystemExit(1)
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
