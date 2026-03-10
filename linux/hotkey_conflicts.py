"""Conflict detection for GNOME and KDE system shortcuts.

Detects when our hotkey bindings overlap with system-level keyboard shortcuts
on GNOME (via gsettings) and KDE (via kglobalshortcutsrc). Reports conflicts
via a single desktop notification using notify-send.

Detection runs once on config load (startup and hotkeys.json reload),
not per-keypress. Conflicting bindings are flagged but still registered --
the user decides whether to rebind.

Consumed by: matrix-keys.py on config load (Plan 03).
Dependencies: Python 3 stdlib only (subprocess for gsettings/notify-send).
"""

import configparser
import logging
import os
import re
import subprocess

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# GDK modifier name -> our normalized format
GDK_MOD_MAP = {
    "<Control>": "Ctrl",
    "<Ctrl>":    "Ctrl",
    "<Shift>":   "Shift",
    "<Alt>":     "Alt",
    "<Super>":   "Super",
    "<Primary>": "Ctrl",  # GTK alias for Control
}

# GNOME keybinding schemas to check
GNOME_KEYBINDING_SCHEMAS = [
    "org.gnome.desktop.wm.keybindings",
    "org.gnome.mutter.keybindings",
    "org.gnome.shell.keybindings",
    "org.gnome.settings-daemon.plugins.media-keys",
]

# KDE modifier name -> our normalized format
KDE_MOD_MAP = {
    "Ctrl":  "Ctrl",
    "Shift": "Shift",
    "Alt":   "Alt",
    "Meta":  "Super",
}

# Default KDE shortcuts config path
KDE_SHORTCUTS_PATH = os.path.expanduser("~/.config/kglobalshortcutsrc")


# ---------------------------------------------------------------------------
# GDK binding parsing
# ---------------------------------------------------------------------------

def parse_gdk_binding(gdk_str):
    """Parse GDK accelerator format into normalized modifiers and key.

    Examples:
        '<Control><Shift>l' -> {'modifiers': {'Ctrl', 'Shift'}, 'key': 'l'}
        '<Super>Up'         -> {'modifiers': {'Super'}, 'key': 'up'}
        '<Primary><Shift>h' -> {'modifiers': {'Ctrl', 'Shift'}, 'key': 'h'}

    Args:
        gdk_str: GDK accelerator string (e.g. '<Control><Shift>l').

    Returns:
        Dict with 'modifiers' (set of str) and 'key' (lowercase str).
    """
    modifiers = set()
    remaining = gdk_str

    for gdk_name, our_name in GDK_MOD_MAP.items():
        if gdk_name.lower() in remaining.lower():
            modifiers.add(our_name)
            remaining = re.sub(re.escape(gdk_name), "", remaining, flags=re.IGNORECASE)

    key = remaining.strip().lower()
    return {"modifiers": modifiers, "key": key}


# ---------------------------------------------------------------------------
# KDE binding parsing
# ---------------------------------------------------------------------------

def _parse_kde_binding(binding_str):
    """Parse a KDE shortcut string into normalized modifiers and key.

    KDE format: 'Meta+Up', 'Ctrl+Shift+L', '' (empty = no shortcut).

    Args:
        binding_str: KDE shortcut string.

    Returns:
        Dict with 'modifiers' (set) and 'key' (lowercase str), or None if empty.
    """
    binding_str = binding_str.strip()
    if not binding_str or binding_str.lower() == "none":
        return None

    parts = binding_str.split("+")
    modifiers = set()
    key = None

    for part in parts:
        part = part.strip()
        if part in KDE_MOD_MAP:
            modifiers.add(KDE_MOD_MAP[part])
        elif part:
            key = part.lower()

    if not key:
        return None

    return {"modifiers": modifiers, "key": key}


# ---------------------------------------------------------------------------
# System shortcut discovery
# ---------------------------------------------------------------------------

def get_gnome_system_shortcuts():
    """Query GNOME keybinding schemas via gsettings.

    Returns list of parsed binding dicts. Handles missing gsettings and timeouts
    gracefully by returning an empty list for failed schemas.

    Returns:
        List of dicts, each with 'modifiers' (set), 'key' (str), 'source' (str).
    """
    shortcuts = []

    for schema in GNOME_KEYBINDING_SCHEMAS:
        try:
            result = subprocess.run(
                ["gsettings", "list-keys", schema],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode != 0:
                continue

            for key_name in result.stdout.strip().split("\n"):
                key_name = key_name.strip()
                if not key_name:
                    continue

                try:
                    val = subprocess.run(
                        ["gsettings", "get", schema, key_name],
                        capture_output=True, text=True, timeout=2,
                    )
                except subprocess.TimeoutExpired:
                    continue

                # Parse GVariant string list: ['<Control><Shift>l', ...]
                for binding_str in re.findall(r"'([^']+)'", val.stdout):
                    if not binding_str or binding_str == "disabled":
                        continue
                    parsed = parse_gdk_binding(binding_str)
                    if parsed["key"]:
                        parsed["source"] = schema
                        shortcuts.append(parsed)

        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue

    return shortcuts


def parse_kde_shortcuts(path=None):
    """Parse KDE kglobalshortcutsrc file for system shortcuts.

    The file is INI-format. Each entry is:
        ActionName=ActiveShortcut,DefaultShortcut,FriendlyName

    Args:
        path: Path to kglobalshortcutsrc. If None, uses default KDE path.

    Returns:
        List of dicts, each with 'modifiers' (set), 'key' (str), 'source' (str).
    """
    if path is None:
        path = KDE_SHORTCUTS_PATH

    if not os.path.exists(path):
        return []

    shortcuts = []

    config = configparser.ConfigParser(strict=False)
    try:
        config.read(path)
    except (configparser.Error, OSError) as e:
        logger.warning("Failed to parse KDE shortcuts: %s", e)
        return []

    for section in config.sections():
        for key, value in config.items(section):
            # Value format: ActiveShortcut,DefaultShortcut,FriendlyName
            parts = value.split(",")
            if not parts:
                continue

            # First field is the active shortcut
            active_shortcut = parts[0].strip()
            parsed = _parse_kde_binding(active_shortcut)
            if parsed:
                parsed["source"] = f"kde:{section}"
                shortcuts.append(parsed)

    return shortcuts


# ---------------------------------------------------------------------------
# Conflict detection
# ---------------------------------------------------------------------------

def detect_conflicts(our_bindings):
    """Detect conflicts between our hotkey bindings and system shortcuts.

    Compares by normalizing modifier sets and key names to lowercase.
    Checks both GNOME gsettings and KDE kglobalshortcutsrc.

    Args:
        our_bindings: Dict of action -> binding from hotkeys.json.

    Returns:
        List of conflict dicts: {'action', 'key', 'modifiers', 'system_source'}.
    """
    system_shortcuts = get_gnome_system_shortcuts() + parse_kde_shortcuts()
    if not system_shortcuts:
        return []

    conflicts = []

    for action, binding in our_bindings.items():
        if not binding.get("enabled", True):
            continue

        our_key = binding.get("key", "").lower()
        our_mods = set(binding.get("modifiers", []))

        for sys_shortcut in system_shortcuts:
            sys_key = sys_shortcut.get("key", "").lower()
            sys_mods = sys_shortcut.get("modifiers", set())

            if our_key == sys_key and our_mods == sys_mods:
                conflicts.append({
                    "action": action,
                    "key": binding.get("key", ""),
                    "modifiers": binding.get("modifiers", []),
                    "system_source": sys_shortcut.get("source", "unknown"),
                })

    return conflicts


# ---------------------------------------------------------------------------
# Notification
# ---------------------------------------------------------------------------

def notify_conflicts(conflicts):
    """Disabled — no popups in Matrix Shader. Conflicts logged to stderr only."""
    if not conflicts:
        return
    import logging
    logger = logging.getLogger(__name__)
    for c in conflicts:
        logger.warning("Hotkey conflict: %s", c)
    return

    count = len(conflicts)
    combos = []
    for c in conflicts:
        mods = "+".join(c.get("modifiers", []))
        key = c.get("key", "")
        combos.append(f"{mods}+{key}" if mods else key)

    combo_str = ", ".join(combos)
    body = (
        f"Matrix Shader: {count} hotkey conflict(s) found "
        f"({combo_str}). Check hotkeys.json."
    )

    try:
        subprocess.Popen(
            [
                "notify-send",
                "--app-name=Matrix Shader",
                "--expire-time=10000",
                "Hotkey Conflicts",
                body,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        logger.warning("notify-send not found, cannot show conflict notification")
