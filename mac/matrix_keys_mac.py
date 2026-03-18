#!/usr/bin/env python3
"""
matrix-keys-mac: CGEvent tap global hotkey listener for Matrix Shader (macOS).

macOS equivalent of linux/matrix_keys.py. Uses Quartz CGEvent tap for
system-wide keyboard event capture. Dispatches to the same ACTION_MAP
from hotkey_actions.py.

Requires Accessibility or Input Monitoring permission.
"""

import ctypes
import ctypes.util
import os
import signal
import sys
import time

# Add paths for imports
_script_dir = os.path.dirname(os.path.abspath(__file__))
_linux_dir = os.path.join(_script_dir, "..", "linux")
if _script_dir not in sys.path:
    sys.path.insert(0, _script_dir)
if _linux_dir not in sys.path:
    sys.path.insert(0, _linux_dir)

# Override shader_service module for macOS BEFORE importing hotkey_actions
# This ensures hotkey_actions.py uses macOS reload instead of D-Bus
import importlib
import shader_service_mac
sys.modules["shader_service"] = shader_service_mac
import window_service_mac
sys.modules["window_service"] = window_service_mac

from hotkey_actions import ACTION_MAP
from hotkey_config_mac import (
    CONFIG_PATH,
    KqueueWatcher,
    build_hotkey_table_mac,
    is_redpill,
    load_config,
)
from platform_mac import (
    check_accessibility_permission,
    request_accessibility_permission,
    show_toast_mac,
)

# Override the toast function in hotkey_actions
import hotkey_actions
hotkey_actions.show_toast = show_toast_mac


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PIDFILE = "/tmp/matrix-keys.pid"

# CGEvent constants
kCGHIDEventTap = 0
kCGHeadInsertEventTap = 0
kCGEventTapOptionListenOnly = 0x00000001
kCGEventKeyDown = 10
kCGEventFlagsChanged = 12
kCGKeyboardEventKeycode = 9  # CGEventField for key code

# Modifier flag masks (for extracting just the modifier bits)
kCGEventFlagMaskShift = 0x00020000
kCGEventFlagMaskControl = 0x00040000
kCGEventFlagMaskAlternate = 0x00080000
kCGEventFlagMaskCommand = 0x00100000
MODIFIER_MASK = (kCGEventFlagMaskShift | kCGEventFlagMaskControl |
                 kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand)


# ---------------------------------------------------------------------------
# CGEvent tap callback
# ---------------------------------------------------------------------------

# Global state for the callback
_state = {
    "hotkey_table": {},
}

# Define the callback type for CGEvent tap
# typedef CGEventRef (*CGEventTapCallBack)(CGEventTapProxy proxy,
#     CGEventType type, CGEventRef event, void *userInfo);
CGEventTapCallBack = ctypes.CFUNCTYPE(
    ctypes.c_void_p,   # return: CGEventRef
    ctypes.c_void_p,   # proxy
    ctypes.c_uint32,   # type (CGEventType)
    ctypes.c_void_p,   # event (CGEventRef)
    ctypes.c_void_p,   # userInfo
)


def _cgevent_callback(proxy, event_type, event, user_info):
    """CGEvent tap callback -- dispatches hotkeys.

    Called by the system for every key down event.
    Checks modifier flags and key code against the hotkey table.
    """
    try:
        if event_type == kCGEventKeyDown:
            # Get the key code
            keycode = _cg.CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode)

            # Get modifier flags (mask to just the modifier bits)
            flags = _cg.CGEventGetFlags(event)
            mod_flags = flags & MODIFIER_MASK

            # Look up in hotkey table
            action = _state["hotkey_table"].get((mod_flags, keycode))
            if action and action in ACTION_MAP:
                try:
                    ACTION_MAP[action]()
                except Exception as e:
                    print(f"matrix-keys-mac: action {action} error: {e}",
                          file=sys.stderr, flush=True)

        elif event_type == 0xFFFFFFFE:
            # Tap was disabled by timeout -- re-enable it
            if _tap:
                _cg.CGEventTapEnable(_tap, True)

    except Exception as e:
        print(f"matrix-keys-mac: callback error: {e}", file=sys.stderr, flush=True)

    return event


# Keep a reference to prevent garbage collection
_callback_ref = CGEventTapCallBack(_cgevent_callback)

# Global framework references (set in main)
_cg = None
_cf = None
_tap = None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    global _cg, _cf, _tap

    # Check platform
    if sys.platform != "darwin":
        print("matrix-keys-mac: This script only runs on macOS", file=sys.stderr)
        sys.exit(1)

    # Write PID file
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))

    def cleanup(sig=None, frame=None):
        try:
            os.unlink(PIDFILE)
        except OSError:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    # Check accessibility permission
    if not check_accessibility_permission():
        print("matrix-keys-mac: Accessibility permission not granted", flush=True)
        request_accessibility_permission()
        print("matrix-keys-mac: Waiting for permission... (restart after granting)", flush=True)
        # Don't exit -- user might grant permission while we wait
        time.sleep(5)
        if not check_accessibility_permission():
            print("matrix-keys-mac: Still no permission. Please grant Accessibility access and restart.", flush=True)
            cleanup()

    # Load frameworks
    try:
        _cg = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreGraphics"))
        _cf = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreFoundation"))
    except OSError as e:
        print(f"matrix-keys-mac: Failed to load frameworks: {e}", file=sys.stderr)
        cleanup()
        return

    # Set return types for CGEvent functions
    _cg.CGEventGetIntegerValueField.restype = ctypes.c_int64
    _cg.CGEventGetIntegerValueField.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    _cg.CGEventGetFlags.restype = ctypes.c_uint64
    _cg.CGEventGetFlags.argtypes = [ctypes.c_void_p]
    _cg.CGEventTapCreate.restype = ctypes.c_void_p
    _cg.CGEventTapCreate.argtypes = [
        ctypes.c_uint32,   # tap
        ctypes.c_uint32,   # place
        ctypes.c_uint32,   # options
        ctypes.c_uint64,   # eventsOfInterest
        CGEventTapCallBack, # callback
        ctypes.c_void_p,   # userInfo
    ]
    _cg.CGEventTapEnable.argtypes = [ctypes.c_void_p, ctypes.c_bool]
    _cf.CFMachPortCreateRunLoopSource.restype = ctypes.c_void_p
    _cf.CFMachPortCreateRunLoopSource.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long]
    _cf.CFRunLoopGetCurrent.restype = ctypes.c_void_p
    _cf.CFRunLoopAddSource.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]

    # kCFRunLoopDefaultMode
    _cf.CFRunLoopGetCurrent.restype = ctypes.c_void_p
    kCFRunLoopDefaultMode = ctypes.c_void_p.in_dll(_cf, "kCFRunLoopDefaultMode")

    # Load config and build hotkey table
    config = load_config()
    redpill = is_redpill()
    _state["hotkey_table"] = build_hotkey_table_mac(config, redpill)

    print(f"matrix-keys-mac: {len(_state['hotkey_table'])} hotkeys loaded", flush=True)

    # Create CGEvent tap
    # Listen for key down events
    event_mask = (1 << kCGEventKeyDown)

    _tap = _cg.CGEventTapCreate(
        kCGHIDEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionListenOnly,
        event_mask,
        _callback_ref,
        None,
    )

    if not _tap:
        print("matrix-keys-mac: Failed to create event tap. Check Accessibility permission.", flush=True)
        request_accessibility_permission()
        cleanup()
        return

    # Create run loop source
    source = _cf.CFMachPortCreateRunLoopSource(None, _tap, 0)
    if not source:
        print("matrix-keys-mac: Failed to create run loop source", file=sys.stderr)
        cleanup()
        return

    # Add to current run loop
    run_loop = _cf.CFRunLoopGetCurrent()
    _cf.CFRunLoopAddSource(run_loop, source, kCFRunLoopDefaultMode)

    # Enable the tap
    _cg.CGEventTapEnable(_tap, True)

    print("matrix-keys-mac: listening for hotkeys (CGEvent tap)", flush=True)

    # Run the event loop
    _cf.CFRunLoopRun()

    cleanup()


if __name__ == "__main__":
    main()
