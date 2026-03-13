"""macOS-adapted shader parameter service for Matrix Shader.

Wraps linux/shader_service.py core functions with macOS-specific
Ghostty reload mechanism (replaces D-Bus with SIGHUP/osascript).

Consumed by: matrix_keys_mac.py, wakeupneo_mac.sh
Dependencies: Python 3 stdlib only, linux/shader_service.py for core logic.
"""

import os
import sys

# Add linux/ to path for importing core shader_service
_linux_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "linux")
if _linux_dir not in sys.path:
    sys.path.insert(0, _linux_dir)

# Import all core functions from Linux shader_service
from shader_service import (
    PARAM_DEFAULTS,
    PARAM_RANGES,
    PRESET_COLORS,
    REDPILL_NEO_PATH,
    SLOT_SHADER_DIR,
    TEMPLATE_PATH,
    atomic_write,
    clamp_value,
    create_slot_shader,
    read_shader_config,
    replace_define,
)

# Import macOS platform functions
_mac_dir = os.path.dirname(os.path.abspath(__file__))
if _mac_dir not in sys.path:
    sys.path.insert(0, _mac_dir)

from platform_mac import get_ghostty_pids, reload_ghostty_mac


# ---------------------------------------------------------------------------
# Compatibility aliases — hotkey_actions.py imports these from "shader_service"
# On Mac, sys.modules["shader_service"] points here, so we must export them.
# ---------------------------------------------------------------------------

def get_ghostty_bus_names():
    """Mac equivalent: returns {slot: {"bus_name": pid}} for compatibility."""
    mapping = get_ghostty_pids()
    return {slot: {"bus_name": info["pid"]} for slot, info in mapping.items()}


def reload_ghostty(pid_or_bus):
    """Mac equivalent: reload via SIGHUP instead of D-Bus."""
    reload_ghostty_mac(int(pid_or_bus))


# ---------------------------------------------------------------------------
# macOS-adapted shader write functions
# ---------------------------------------------------------------------------

def write_shader_param(slot: int, param: str, value: float) -> None:
    """Modify a single #define parameter and trigger reload for that slot.

    macOS version: uses SIGHUP/osascript instead of D-Bus.

    Args:
        slot: Window slot number (1-8).
        param: Parameter name (e.g. "RAIN_SPEED").
        value: New float value (will be clamped).
    """
    value = clamp_value(param, value)
    shader_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")

    with open(shader_path) as f:
        content = f.read()

    content = replace_define(content, param, value)
    atomic_write(shader_path, content)

    # Trigger reload via macOS mechanism
    mapping = get_ghostty_pids()
    if slot in mapping:
        reload_ghostty_mac(mapping[slot]["pid"])


def write_shader_params(slot: int, params: dict) -> None:
    """Modify multiple #define parameters with a single reload.

    macOS version: uses SIGHUP/osascript instead of D-Bus.

    Args:
        slot: Window slot number (1-8).
        params: Dict of parameter name -> value.
    """
    shader_path = os.path.join(SLOT_SHADER_DIR, f"matrix-{slot}.glsl")

    with open(shader_path) as f:
        content = f.read()

    for param, value in params.items():
        value = clamp_value(param, value)
        content = replace_define(content, param, value)

    atomic_write(shader_path, content)

    # Trigger reload via macOS mechanism (single reload for all params)
    mapping = get_ghostty_pids()
    if slot in mapping:
        reload_ghostty_mac(mapping[slot]["pid"])


def reload_all() -> None:
    """Trigger config reload on all Ghostty instances."""
    mapping = get_ghostty_pids()
    for info in mapping.values():
        reload_ghostty_mac(info["pid"])


# ---------------------------------------------------------------------------
# CLI interface (same as Linux version)
# ---------------------------------------------------------------------------

def _cli():
    """Command-line interface for shader_service_mac.py."""
    import argparse
    import json

    parser = argparse.ArgumentParser(
        description="Shader parameter service for Matrix Shader (macOS)"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_create = sub.add_parser("create", help="Create a per-slot shader file")
    p_create.add_argument("--slot", type=int, required=True)
    p_create.add_argument("--preset", type=int, default=None)
    p_create.add_argument("--r", type=float, default=0.0)
    p_create.add_argument("--g", type=float, default=1.0)
    p_create.add_argument("--b", type=float, default=0.3)

    p_write = sub.add_parser("write", help="Modify a shader parameter")
    p_write.add_argument("--slot", type=int, required=True)
    p_write.add_argument("--param", type=str, required=True)
    p_write.add_argument("--value", type=float, required=True)

    p_read = sub.add_parser("read", help="Read current config")
    p_read.add_argument("--slot", type=int, required=True)

    p_reload = sub.add_parser("reload", help="Trigger reload for a slot")
    p_reload.add_argument("--slot", type=int, required=True)

    args = parser.parse_args()

    if args.command == "create":
        path = create_slot_shader(
            slot=args.slot, r=args.r, g=args.g, b=args.b,
            preset_idx=args.preset,
        )
        print(path)

    elif args.command == "write":
        if args.param not in PARAM_DEFAULTS:
            print(f"Error: unknown parameter '{args.param}'", file=sys.stderr)
            raise SystemExit(1)
        write_shader_param(slot=args.slot, param=args.param, value=args.value)

    elif args.command == "read":
        config = read_shader_config(slot=args.slot)
        print(json.dumps(config, indent=2))

    elif args.command == "reload":
        mapping = get_ghostty_pids()
        if args.slot in mapping:
            ok = reload_ghostty_mac(mapping[args.slot]["pid"])
            if not ok:
                print(f"Error: reload failed for slot {args.slot}", file=sys.stderr)
                raise SystemExit(1)
        else:
            print(f"Warning: no Ghostty instance found for slot {args.slot}", file=sys.stderr)
            raise SystemExit(1)


if __name__ == "__main__":
    _cli()
