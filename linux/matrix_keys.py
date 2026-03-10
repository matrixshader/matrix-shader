#!/usr/bin/env python3
"""
matrix-keys: evdev-based global hotkey listener for Matrix Shader.
Config-driven dispatch for all 13 hotkeys. Multiplexes evdev keyboard fd
and inotify config-watch fd via select.select(). Auto-reconnects on
keyboard disconnect. Runs as a background daemon.
"""

import fcntl
import os
import select
import signal
import sys
import time

import evdev
from evdev import ecodes

from hotkey_actions import ACTION_MAP
from hotkey_config import (
    CONFIG_PATH,
    InotifyWatcher,
    build_hotkey_table,
    is_redpill,
    load_config,
)
from hotkey_conflicts import detect_conflicts, notify_conflicts


PIDFILE = "/tmp/matrix-keys.pid"

# Single-instance lock file descriptor (kept open for lifetime of process)
_lock_fd = None


def acquire_single_instance():
    """Acquire single-instance lock via fcntl.flock on PID file.

    Uses LOCK_EX | LOCK_NB (exclusive, non-blocking).
    If another instance holds the lock, returns False.
    On success, writes our PID to the file and returns True.

    The kernel automatically releases advisory locks on process death,
    including kill -9, making this crash-safe.
    """
    global _lock_fd
    try:
        _lock_fd = open(PIDFILE, "w")
        fcntl.flock(_lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        _lock_fd.write(str(os.getpid()))
        _lock_fd.flush()
        return True
    except (IOError, OSError):
        if _lock_fd is not None:
            _lock_fd.close()
            _lock_fd = None
        return False


def release_single_instance():
    """Release the single-instance lock and clean up PID file."""
    global _lock_fd
    if _lock_fd is not None:
        try:
            fcntl.flock(_lock_fd, fcntl.LOCK_UN)
            _lock_fd.close()
        except OSError:
            pass
        _lock_fd = None
    try:
        os.unlink(PIDFILE)
    except OSError:
        pass

# Modifier keys used for matching — any left/right variant counts
MODIFIER_KEYS = {
    ecodes.KEY_LEFTCTRL, ecodes.KEY_RIGHTCTRL,
    ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT,
    ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT,
    ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA,
}

# Map individual modifier key codes to their group name for lookup
_MODIFIER_GROUPS = {
    ecodes.KEY_LEFTCTRL:  "Ctrl",
    ecodes.KEY_RIGHTCTRL: "Ctrl",
    ecodes.KEY_LEFTSHIFT: "Shift",
    ecodes.KEY_RIGHTSHIFT: "Shift",
    ecodes.KEY_LEFTALT:   "Alt",
    ecodes.KEY_RIGHTALT:  "Alt",
    ecodes.KEY_LEFTMETA:  "Super",
    ecodes.KEY_RIGHTMETA: "Super",
}

# Shared mutable state for the hotkey table (updated by startup_init and handle_config_reload)
_state = {
    "config": {},
    "hotkey_table": {},
    "watcher": None,
}


def find_keyboard():
    """Find a real keyboard (not ydotool/virtual)."""
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except (PermissionError, OSError):
            continue
        caps = dev.capabilities()
        if ecodes.EV_KEY in caps:
            keys = caps[ecodes.EV_KEY]
            if ecodes.KEY_SPACE in keys and ecodes.KEY_LEFTCTRL in keys:
                name_lower = dev.name.lower()
                if "ydotool" not in name_lower and "virtual" not in name_lower:
                    return dev
    return None


def dispatch_key_event(event, held_keys, hotkey_table, action_map):
    """Dispatch a single evdev key event through the hotkey table.

    Only fires on key press (value==1). Ignores release (0) and repeat (2).
    Matches held modifiers against the hotkey table entries.

    Args:
        event: evdev InputEvent with .type, .code, .value.
        held_keys: Set of currently held key codes.
        hotkey_table: Dict of (frozenset(mod_codes), key_code) -> action_name.
        action_map: Dict of action_name -> callable.
    """
    if event.value != 1:
        return

    key = event.code

    # Skip if the pressed key is itself a modifier
    if key in MODIFIER_KEYS:
        return

    # Check each hotkey table entry for a match
    for (mod_set, hotkey_code), action_name in hotkey_table.items():
        if hotkey_code != key:
            continue

        # Check that at least one key from each required modifier group is held.
        # mod_set contains all left+right codes for required modifiers.
        # Group them and check each group has at least one held.
        required_groups = set()
        for mod_code in mod_set:
            group = _MODIFIER_GROUPS.get(mod_code)
            if group:
                required_groups.add(group)

        all_groups_held = True
        for group in required_groups:
            # Get all codes for this group from held_keys
            group_held = False
            for held_code in held_keys:
                if _MODIFIER_GROUPS.get(held_code) == group:
                    group_held = True
                    break
            if not group_held:
                all_groups_held = False
                break

        if all_groups_held and action_name in action_map:
            try:
                action_map[action_name]()
            except Exception as e:
                print(f"matrix-keys: action {action_name} error: {e}",
                      file=sys.stderr, flush=True)
            return


def startup_init():
    """Initialize config, hotkey table, and conflict detection.

    Called once at daemon start. Sets up shared state.

    Returns:
        Dict with 'config', 'hotkey_table', and 'redpill' keys.
    """
    config = load_config()
    redpill = is_redpill()
    hotkey_table = build_hotkey_table(config, redpill)

    conflicts = detect_conflicts(config)
    notify_conflicts(conflicts)

    _state["config"] = config
    _state["hotkey_table"] = hotkey_table

    return {"config": config, "hotkey_table": hotkey_table, "redpill": redpill}


def handle_config_reload(watcher):
    """Handle inotify config change: reload config and rebuild hotkey table.

    Called when watcher.check() returns True.

    Args:
        watcher: InotifyWatcher instance (check() already returned True).

    Returns:
        Dict with 'config', 'hotkey_table', and 'redpill' keys.
    """
    config = load_config()
    redpill = is_redpill()
    hotkey_table = build_hotkey_table(config, redpill)

    conflicts = detect_conflicts(config)
    notify_conflicts(conflicts)

    _state["config"] = config
    _state["hotkey_table"] = hotkey_table

    print("matrix-keys: config reloaded", flush=True)
    return {"config": config, "hotkey_table": hotkey_table, "redpill": redpill}


def _try_glitch_check():
    """Disabled — glitch snap needs redesign (event-driven, not polling)."""
    pass


def event_loop(kbd, hotkey_table, watcher):
    """Unified select loop: multiplexes evdev keyboard fd + inotify watcher fd.

    Replaces the old listen() function. Handles keyboard events, config
    changes, and glitch auto-snap checks in a single loop.

    Args:
        kbd: evdev InputDevice for the keyboard.
        hotkey_table: Dict of (frozenset, keycode) -> action_name.
        watcher: InotifyWatcher instance.

    Raises:
        OSError: On keyboard disconnect (caught by caller for reconnect).
    """
    held_keys = set()

    while True:
        fds = [kbd.fd, watcher.fileno()]
        readable, _, _ = select.select(fds, [], [], 1.0)

        if kbd.fd in readable:
            for event in kbd.read():
                if event.type != ecodes.EV_KEY:
                    continue

                key = event.code
                value = event.value  # 1=press, 0=release, 2=repeat

                if value == 1:
                    held_keys.add(key)
                elif value == 0:
                    held_keys.discard(key)
                # value == 2 (repeat): update held_keys but do NOT dispatch

                dispatch_key_event(event, held_keys, hotkey_table, ACTION_MAP)

        if watcher.fileno() in readable:
            if watcher.check():
                result = handle_config_reload(watcher)
                hotkey_table = result["hotkey_table"]

        # Glitch mode: periodically check for window drift and snap back.
        # check_and_snap() internally rate-limits to every 3 seconds.
        _try_glitch_check()


def main():
    """Main entry point: PID file, signal handlers, startup, event loop."""
    if not acquire_single_instance():
        print("matrix-keys: another instance is already running, exiting", flush=True)
        sys.exit(0)

    watcher = None

    def cleanup(sig=None, frame=None):
        release_single_instance()
        if watcher is not None:
            try:
                watcher.close()
            except Exception:
                pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    # Startup: load config, build table, detect conflicts
    result = startup_init()
    hotkey_table = result["hotkey_table"]

    # Create inotify watcher for config directory
    config_dir = os.path.dirname(os.path.expanduser(CONFIG_PATH))
    os.makedirs(config_dir, exist_ok=True)
    watcher = InotifyWatcher(config_dir)
    _state["watcher"] = watcher

    # Keyboard discovery + listen loop with auto-reconnect
    while True:
        kbd = find_keyboard()
        if not kbd:
            time.sleep(2)
            continue

        print(f"matrix-keys: listening on {kbd.name} ({kbd.path})", flush=True)

        try:
            event_loop(kbd, hotkey_table, watcher)
        except OSError:
            # Keyboard disconnected -- retry
            print("matrix-keys: keyboard disconnected, reconnecting...", flush=True)
            time.sleep(1)
            continue
        except Exception as e:
            print(f"matrix-keys: error: {e}", file=sys.stderr, flush=True)
            time.sleep(1)
            continue

    cleanup()


if __name__ == "__main__":
    main()
