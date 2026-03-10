"""macOS hotkey configuration: CGEvent key codes, modifier flags, config builder.

Parallel to linux/hotkey_config.py but uses CGEvent (Quartz) key codes
instead of evdev codes. Shares DEFAULT_BINDINGS and config persistence
with the Linux version.

Consumed by: matrix_keys_mac.py
Dependencies: Python 3 stdlib only.
"""

import os
import sys

# Import platform-agnostic config functions from Linux version
_linux_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "linux")
if _linux_dir not in sys.path:
    sys.path.insert(0, _linux_dir)

from hotkey_config import (
    CONFIG_PATH,
    DEFAULT_BINDINGS,
    is_redpill,
    load_config,
    save_config,
)


# ---------------------------------------------------------------------------
# CGEvent key code mapping
# ---------------------------------------------------------------------------

# Map config key names to macOS CGKeyCode values
# Reference: Events.h / IOLLEvent.h
KEY_NAME_TO_CGEVENT = {
    "Left":  123,
    "Right": 124,
    "Up":    126,
    "Down":  125,
    "L":     37,
    "B":     11,
    "J":     38,
    "K":     40,
    "H":     4,
    "1":     18,
    "2":     19,
    "3":     20,
    "S":     1,
    "R":     15,
    "G":     5,
    "F5":    96,
}

# CGEventFlags bitmasks for modifier keys
MODIFIER_FLAGS = {
    "Ctrl":  0x00040000,  # kCGEventFlagMaskControl
    "Shift": 0x00020000,  # kCGEventFlagMaskShift
    "Alt":   0x00080000,  # kCGEventFlagMaskAlternate
    "Super": 0x00100000,  # kCGEventFlagMaskCommand
}

# Combined mask for Ctrl+Shift (our default modifier combo)
CTRL_SHIFT_MASK = MODIFIER_FLAGS["Ctrl"] | MODIFIER_FLAGS["Shift"]


# ---------------------------------------------------------------------------
# Runtime hotkey table (macOS version)
# ---------------------------------------------------------------------------

def build_hotkey_table_mac(config, is_redpill_flag=False):
    """Convert action-keyed config to CGEvent runtime lookup table.

    The lookup table maps (modifier_mask, cgevent_keycode) to action name,
    allowing O(1) dispatch from CGEvent callbacks.

    Simpler than the Linux version because CGEvent provides modifier flags
    as a bitmask (no need to track individual left/right modifier states).

    Args:
        config: Dict of action -> binding from load_config().
        is_redpill_flag: Whether the user has Red Pill upgrade.

    Returns:
        Dict mapping (int modifier_mask, int keycode) -> action name string.
    """
    source = config if is_redpill_flag else DEFAULT_BINDINGS
    table = {}

    for action, binding in source.items():
        if not binding.get("enabled", True):
            continue

        key_name = binding.get("key")
        if key_name not in KEY_NAME_TO_CGEVENT:
            continue

        key_code = KEY_NAME_TO_CGEVENT[key_name]

        # Build modifier mask from binding modifiers
        mod_mask = 0
        for mod_name in binding.get("modifiers", []):
            if mod_name in MODIFIER_FLAGS:
                mod_mask |= MODIFIER_FLAGS[mod_name]

        table[(mod_mask, key_code)] = action

    return table


# ---------------------------------------------------------------------------
# Config file watcher (kqueue-based for macOS)
# ---------------------------------------------------------------------------

class KqueueWatcher:
    """Watch a file for changes via kqueue (macOS/BSD).

    macOS equivalent of InotifyWatcher from hotkey_config.py.
    Watches the config file directly using kqueue NOTE_WRITE events.

    Provides fileno() for use with select.select().
    """

    def __init__(self, watch_path):
        """Initialize kqueue watcher.

        Args:
            watch_path: Full path to the file to watch.
        """
        import select as _select

        self._watch_path = watch_path
        self._kq = _select.kqueue()
        self._fd = -1

        try:
            self._fd = os.open(watch_path, os.O_RDONLY)
        except FileNotFoundError:
            # Create parent dir and empty file if needed
            os.makedirs(os.path.dirname(watch_path), exist_ok=True)
            with open(watch_path, "w") as f:
                f.write("{}")
            self._fd = os.open(watch_path, os.O_RDONLY)

        # Register for write events on the file
        ev = _select.kevent(
            self._fd,
            filter=_select.KQ_FILTER_VNODE,
            flags=_select.KQ_EV_ADD | _select.KQ_EV_CLEAR,
            fflags=_select.KQ_NOTE_WRITE | _select.KQ_NOTE_RENAME,
        )
        self._kq.control([ev], 0, 0)

    def fileno(self):
        """Return the kqueue file descriptor for select compatibility."""
        return self._kq.fileno()

    def check(self):
        """Check for pending file change events.

        Returns:
            True if the watched file was modified.
        """
        import select as _select

        events = self._kq.control(None, 4, 0)  # Non-blocking check
        return len(events) > 0

    def close(self):
        """Clean up kqueue and file descriptor."""
        if self._fd >= 0:
            os.close(self._fd)
            self._fd = -1
        if self._kq is not None:
            self._kq.close()
            self._kq = None
