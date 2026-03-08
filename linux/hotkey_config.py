"""Hotkey configuration: defaults, persistence, inotify watcher, Red Pill gate.

Linux equivalent of MatrixShader.Core/Models/HotkeyConfig.cs +
MatrixShader.Core/Services/HotkeyConfigService.cs.

Provides:
  - DEFAULT_BINDINGS: all 13 default hotkeys (action-keyed dict)
  - KEY_NAME_TO_EVDEV / MODIFIER_NAME_TO_EVDEV: config key names -> evdev codes
  - load_config / save_config: JSON persistence with atomic write
  - build_hotkey_table: convert config to evdev runtime lookup table
  - is_redpill: check Red Pill upgrade status (file existence)
  - InotifyWatcher: inotify wrapper for config file change detection

Consumed by: matrix-keys.py event loop (Plan 03).
Dependencies: Python 3 stdlib + evdev.
"""

import ctypes
import ctypes.util
import json
import logging
import os
import struct
import tempfile

from evdev import ecodes


logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CONFIG_PATH = os.path.expanduser("~/.config/matrix-shader/hotkeys.json")

_REDPILL_PATH = os.path.expanduser("~/.config/matrix-shader/redpill.json")

# All 13 default hotkeys matching Windows HotkeyConfig.cs DefaultBindings().
# NOTE: CycleShader was removed from Windows (BUG-SHADER04/05) -- NOT included.
DEFAULT_BINDINGS = {
    "SwapLeft":           {"key": "Left",  "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "SwapRight":          {"key": "Right", "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "CycleLayout":        {"key": "L",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleTransparency": {"key": "B",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "OpacityDown":        {"key": "J",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "OpacityUp":          {"key": "K",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "SpeedUp":            {"key": "Down",  "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "SpeedDown":          {"key": "Up",    "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleFar":          {"key": "1",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleMid":          {"key": "2",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ToggleNear":         {"key": "3",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ShowHelp":           {"key": "H",     "modifiers": ["Ctrl", "Shift"], "enabled": True},
    "ManualReload":       {"key": "F5",    "modifiers": ["Ctrl", "Shift"], "enabled": True},
}

# Map config key names to evdev key codes
KEY_NAME_TO_EVDEV = {
    "Left":  ecodes.KEY_LEFT,    # 105
    "Right": ecodes.KEY_RIGHT,   # 106
    "Up":    ecodes.KEY_UP,      # 103
    "Down":  ecodes.KEY_DOWN,    # 108
    "L":     ecodes.KEY_L,       # 38
    "B":     ecodes.KEY_B,       # 48
    "J":     ecodes.KEY_J,       # 36
    "K":     ecodes.KEY_K,       # 37
    "H":     ecodes.KEY_H,       # 35
    "1":     ecodes.KEY_1,       # 2
    "2":     ecodes.KEY_2,       # 3
    "3":     ecodes.KEY_3,       # 4
    "F5":    ecodes.KEY_F5,      # 63
}

# Map modifier names to sets of left + right evdev codes
MODIFIER_NAME_TO_EVDEV = {
    "Ctrl":  {ecodes.KEY_LEFTCTRL,  ecodes.KEY_RIGHTCTRL},
    "Shift": {ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT},
    "Alt":   {ecodes.KEY_LEFTALT,   ecodes.KEY_RIGHTALT},
    "Super": {ecodes.KEY_LEFTMETA,  ecodes.KEY_RIGHTMETA},
}


# ---------------------------------------------------------------------------
# inotify constants (from linux/inotify.h)
# ---------------------------------------------------------------------------

IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO    = 0x00000080
IN_NONBLOCK    = 0x00000800
IN_CLOEXEC     = 0x00080000

_EVENT_FMT = "iIII"
_EVENT_SIZE = struct.calcsize(_EVENT_FMT)


# ---------------------------------------------------------------------------
# Config persistence
# ---------------------------------------------------------------------------

def load_config(path=None):
    """Load hotkey config from JSON file.

    If the file doesn't exist, creates it with DEFAULT_BINDINGS.
    If the file contains corrupt JSON, logs a warning and returns defaults.

    Args:
        path: Config file path. If None, uses CONFIG_PATH.

    Returns:
        Dict of action -> binding.
    """
    if path is None:
        path = CONFIG_PATH

    if not os.path.exists(path):
        save_config(DEFAULT_BINDINGS, path=path)
        return dict(DEFAULT_BINDINGS)

    try:
        with open(path) as f:
            config = json.load(f)
        return config
    except (json.JSONDecodeError, ValueError) as e:
        logger.warning("Corrupt hotkeys.json, using defaults: %s", e)
        return dict(DEFAULT_BINDINGS)


def save_config(config, path=None):
    """Save hotkey config to JSON file with atomic write.

    Uses tempfile + os.replace to prevent partial reads during
    inotify-triggered reloads.

    Args:
        config: Dict of action -> binding to save.
        path: Config file path. If None, uses CONFIG_PATH.
    """
    if path is None:
        path = CONFIG_PATH

    dir_path = os.path.dirname(path)
    if dir_path:
        os.makedirs(dir_path, exist_ok=True)

    content = json.dumps(config, indent=2) + "\n"

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


# ---------------------------------------------------------------------------
# Runtime hotkey table
# ---------------------------------------------------------------------------

def build_hotkey_table(config, is_redpill=False):
    """Convert action-keyed config to evdev runtime lookup table.

    The lookup table maps (frozenset(modifier_evdev_codes), key_evdev_code) to
    action name, allowing O(1) dispatch from evdev key events.

    If is_redpill is False, ignores config and uses DEFAULT_BINDINGS
    (free users get defaults only).

    Args:
        config: Dict of action -> binding from load_config().
        is_redpill: Whether the user has Red Pill upgrade.

    Returns:
        Dict mapping (frozenset, int) -> action name string.
    """
    source = config if is_redpill else DEFAULT_BINDINGS
    table = {}

    for action, binding in source.items():
        if not binding.get("enabled", True):
            continue

        key_name = binding.get("key")
        if key_name not in KEY_NAME_TO_EVDEV:
            logger.warning("Unknown key '%s' for action '%s', skipping", key_name, action)
            continue

        key_code = KEY_NAME_TO_EVDEV[key_name]

        # Build modifier set: union of all left+right variants for each modifier
        mod_codes = set()
        for mod_name in binding.get("modifiers", []):
            if mod_name in MODIFIER_NAME_TO_EVDEV:
                mod_codes.update(MODIFIER_NAME_TO_EVDEV[mod_name])

        table[(frozenset(mod_codes), key_code)] = action

    return table


# ---------------------------------------------------------------------------
# Red Pill gate
# ---------------------------------------------------------------------------

def is_redpill():
    """Check if the user has Red Pill upgrade.

    Phase 2 just checks file existence. Actual licensing is deferred.

    Returns:
        True if ~/.config/matrix-shader/redpill.json exists.
    """
    return os.path.exists(_REDPILL_PATH)


# ---------------------------------------------------------------------------
# InotifyWatcher
# ---------------------------------------------------------------------------

class InotifyWatcher:
    """Watch a directory for config file changes via inotify.

    Watches the DIRECTORY (not the file) to handle atomic writes
    (temp + os.replace) which replace the inode.

    Provides fileno() for use with select.select() in the main event loop.
    """

    def __init__(self, watch_dir, filename="hotkeys.json"):
        """Initialize inotify watcher.

        Args:
            watch_dir: Directory to watch (e.g. ~/.config/matrix-shader/).
            filename: Filename to filter events for.
        """
        self._watch_dir = watch_dir
        self._filename = filename
        self._fd = -1
        self._wd = -1

        libc_name = ctypes.util.find_library("c")
        self._libc = ctypes.CDLL(libc_name, use_errno=True)

        self._fd = self._libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if self._fd < 0:
            errno = ctypes.get_errno()
            raise OSError(errno, f"inotify_init1 failed: {os.strerror(errno)}")

        mask = IN_CLOSE_WRITE | IN_MOVED_TO
        self._wd = self._libc.inotify_add_watch(
            self._fd,
            watch_dir.encode("utf-8"),
            mask,
        )
        if self._wd < 0:
            errno = ctypes.get_errno()
            os.close(self._fd)
            self._fd = -1
            raise OSError(errno, f"inotify_add_watch failed for {watch_dir}: {os.strerror(errno)}")

    def fileno(self):
        """Return the inotify file descriptor for select.select().

        Returns:
            int: The inotify fd.
        """
        return self._fd

    def check(self):
        """Read and drain pending inotify events.

        Returns True if the watched filename was modified
        (IN_CLOSE_WRITE or IN_MOVED_TO).

        Returns:
            bool: True if config file was modified, False otherwise.
        """
        found = False
        try:
            data = os.read(self._fd, 4096)
        except BlockingIOError:
            return False

        offset = 0
        while offset < len(data):
            wd, mask, cookie, name_len = struct.unpack_from(_EVENT_FMT, data, offset)
            offset += _EVENT_SIZE
            name = data[offset:offset + name_len].rstrip(b"\x00").decode("utf-8", errors="replace")
            offset += name_len

            if name == self._filename:
                found = True

        return found

    def close(self):
        """Clean up the inotify file descriptor."""
        if self._fd >= 0:
            os.close(self._fd)
            self._fd = -1
            self._wd = -1
