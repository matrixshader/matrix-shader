"""Shader parameter read/write/create with targeted D-Bus reload.

Linux equivalent of MatrixShader.Core/Services/ShaderService.cs.
Provides runtime modification of all 11 GLSL shader parameters
(speed, glow, width, trail, density, RGB, layers) on any individual
Ghostty window.

Consumed by: hotkey listener (Phase 2), control panel (Phase 3).
Dependencies: Python 3 stdlib only (no pip packages).
"""

import os
import re
import json
import tempfile
import subprocess
from pathlib import Path


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Default values for all 11 shader parameters (matches matrix-green-ghostty.glsl)
PARAM_DEFAULTS = {
    "RAIN_R": 0.0,
    "RAIN_G": 1.0,
    "RAIN_B": 0.3,
    "RAIN_SPEED": 0.8,
    "GLOW_STRENGTH": 0.8,
    "CHAR_WIDTH": 10.0,
    "TRAIL_POWER": 8.0,
    "RAIN_DENSITY": 0.4,
    "SHOW_L1": 1.0,
    "SHOW_L2": 1.0,
    "SHOW_L3": 1.0,
}

# Valid ranges for each parameter (matches ShaderConfig.cs)
PARAM_RANGES = {
    "RAIN_R": (0.0, 1.0),
    "RAIN_G": (0.0, 1.0),
    "RAIN_B": (0.0, 1.0),
    "RAIN_SPEED": (0.1, 5.0),
    "GLOW_STRENGTH": (0.2, 3.0),
    "CHAR_WIDTH": (6.0, 20.0),
    "TRAIL_POWER": (4.0, 15.0),
    "RAIN_DENSITY": (0.2, 1.0),
    "SHOW_L1": (0.0, 1.0),
    "SHOW_L2": (0.0, 1.0),
    "SHOW_L3": (0.0, 1.0),
}

# 6 preset RGB tuples matching wakeupneo.sh PRESETS array
PRESET_COLORS = [
    (0.0, 1.0, 0.3),   # Classic Green
    (0.0, 0.6, 1.0),   # Cyber Blue
    (1.0, 0.1, 0.1),   # Blood Red
    (0.7, 0.0, 1.0),   # Purple
    (1.0, 0.7, 0.0),   # Gold
    (0.0, 0.9, 0.9),   # Teal
]

# Per-slot shader file directory
SLOT_SHADER_DIR = os.path.expanduser("~/.config/matrix-shader/shaders")

# Template shader file -- resolved relative to this script's location
# (same pattern as wakeupneo.sh SHADER_DIR)
TEMPLATE_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "shaders-glsl", "matrix-green-ghostty.glsl"
)


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

def replace_define(content: str, name: str, value: float) -> str:
    """Replace a #define value in shader source.

    Mirrors ShaderService.cs ReplaceDefine method.
    Preserves whitespace between name and value for readability.
    Formats floats with exactly one decimal place.

    Args:
        content: Full shader file content.
        name: Parameter name (e.g. "RAIN_SPEED").
        value: New float value.

    Returns:
        Modified content with the #define value replaced,
        or unchanged content if the parameter is not found.
    """
    pattern = rf"(#define\s+{re.escape(name)}\s+)[\d.]+"
    replacement = f"{value:.1f}"
    return re.sub(pattern, lambda m: m.group(1) + replacement, content)


def read_shader_config(slot: int) -> dict:
    """Read current #define values from a slot's shader file.

    Mirrors ShaderService.cs ParseConfig method.

    Args:
        slot: Window slot number (1-8).

    Returns:
        Dict of all 11 parameter names to their float values.
        Missing parameters get default values.
    """
    shader_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")

    try:
        with open(shader_path) as f:
            content = f.read()
    except FileNotFoundError:
        return dict(PARAM_DEFAULTS)

    config = {}
    for param, default in PARAM_DEFAULTS.items():
        match = re.search(rf"#define\s+{re.escape(param)}\s+([\d.]+)", content)
        if match:
            try:
                config[param] = float(match.group(1))
            except ValueError:
                config[param] = default
        else:
            config[param] = default

    return config


def clamp_value(param: str, value: float) -> float:
    """Clamp a parameter value to its valid range.

    Mirrors ShaderConfig.cs Clamp method.

    Args:
        param: Parameter name (e.g. "RAIN_SPEED").
        value: Value to clamp.

    Returns:
        Clamped value within the parameter's valid range.
    """
    lo, hi = PARAM_RANGES.get(param, (0.0, 1.0))
    return max(lo, min(hi, value))


def atomic_write(path: str, content: str) -> None:
    """Write content to path atomically using temp file + os.replace.

    Creates parent directories if they don't exist.
    Mirrors ShaderService.cs WriteConfig atomic write pattern.

    Args:
        path: Destination file path.
        content: File content to write.
    """
    dir_path = os.path.dirname(path)
    os.makedirs(dir_path, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def create_slot_shader(slot: int, r=0.0, g=1.0, b=0.3, preset_idx=None) -> str:
    """Create a per-slot shader file from the green preset template.

    Mirrors ShaderTemplate.Template generation from C# codebase.

    Args:
        slot: Window slot number (1-8).
        r: Red component (0.0-1.0). Ignored if preset_idx is set.
        g: Green component (0.0-1.0). Ignored if preset_idx is set.
        b: Blue component (0.0-1.0). Ignored if preset_idx is set.
        preset_idx: If set, use PRESET_COLORS[preset_idx] for RGB values.

    Returns:
        Path to the created shader file.
    """
    if preset_idx is not None:
        r, g, b = PRESET_COLORS[preset_idx]

    with open(TEMPLATE_PATH) as f:
        content = f.read()

    content = replace_define(content, "RAIN_R", r)
    content = replace_define(content, "RAIN_G", g)
    content = replace_define(content, "RAIN_B", b)

    path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")
    atomic_write(path, content)
    return path


def write_shader_param(slot: int, param: str, value: float) -> None:
    """Modify a single #define parameter and trigger reload for that slot.

    Clamps value to valid range before writing.

    Args:
        slot: Window slot number (1-8).
        param: Parameter name (e.g. "RAIN_SPEED", "RAIN_R").
        value: New float value (will be clamped to valid range).
    """
    value = clamp_value(param, value)
    shader_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")

    with open(shader_path) as f:
        content = f.read()

    content = replace_define(content, param, value)
    atomic_write(shader_path, content)

    # Trigger targeted reload
    mapping = get_ghostty_bus_names()
    if slot in mapping:
        reload_ghostty(mapping[slot]["bus_name"])


def write_shader_params(slot: int, params: dict) -> None:
    """Modify multiple #define parameters with a single reload.

    More efficient than calling write_shader_param for each param
    because it does a single file read/write and a single D-Bus reload.

    Args:
        slot: Window slot number (1-8).
        params: Dict of parameter name -> value (values will be clamped).
    """
    shader_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")

    with open(shader_path) as f:
        content = f.read()

    for param, value in params.items():
        value = clamp_value(param, value)
        content = replace_define(content, param, value)

    atomic_write(shader_path, content)

    # Trigger targeted reload (single reload for all params)
    mapping = get_ghostty_bus_names()
    if slot in mapping:
        reload_ghostty(mapping[slot]["bus_name"])


def get_ghostty_bus_names() -> dict:
    """Map slot numbers to D-Bus bus names via PID correlation.

    Discovers which Ghostty PID owns which slot by inspecting
    /proc/{pid}/cmdline for the config file path pattern.

    Returns:
        Dict mapping slot -> {"pid": int, "bus_name": str}
    """
    mapping = {}

    try:
        result = subprocess.run(
            ["busctl", "--user", "list"],
            capture_output=True, text=True, timeout=5
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return mapping

    # Parse busctl output: find lines containing "ghostty"
    bus_entries = {}
    for line in result.stdout.splitlines():
        if "ghostty" not in line.lower():
            continue
        parts = line.split()
        if len(parts) >= 2:
            try:
                bus_name = parts[0]
                pid = int(parts[1])
                bus_entries[pid] = bus_name
            except (ValueError, IndexError):
                continue

    # Match PIDs to slots via /proc cmdline
    for pid, bus_name in bus_entries.items():
        try:
            with open(f"/proc/{pid}/cmdline") as f:
                cmdline = f.read()
            for slot in range(1, 9):
                if f"ghostty-matrix-{slot}" in cmdline:
                    mapping[slot] = {"pid": pid, "bus_name": bus_name}
                    break
        except (FileNotFoundError, PermissionError):
            continue

    return mapping


def reload_ghostty(bus_name: str) -> bool:
    """Trigger config reload for a specific Ghostty instance via D-Bus.

    Mirrors wakeupneo.sh go_transparent() D-Bus reload pattern.
    Targets ONLY the specified bus_name (not all instances).

    Args:
        bus_name: D-Bus bus name (e.g. ":1.118").

    Returns:
        True on success, False on timeout or error.
    """
    try:
        subprocess.run(
            [
                "gdbus", "call", "--session",
                "--dest", bus_name,
                "--object-path", "/com/mitchellh/ghostty",
                "--method", "org.gtk.Actions.Activate",
                "reload-config", "[]", "{}"
            ],
            capture_output=True,
            timeout=5
        )
        return True
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
        return False
