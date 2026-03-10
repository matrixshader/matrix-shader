"""macOS platform abstraction for Matrix Shader.

Provides macOS-specific Ghostty interaction, window positioning,
and notification functions. Replaces Linux D-Bus/evdev/GTK mechanisms.

Consumed by: shader_service_mac.py, matrix_keys_mac.py, wakeupneo_mac.sh
Dependencies: Python 3 stdlib only (ctypes for macOS frameworks).
"""

import os
import re
import signal
import subprocess
import sys


# ---------------------------------------------------------------------------
# Ghostty binary discovery
# ---------------------------------------------------------------------------

_GHOSTTY_SEARCH_PATHS = [
    "/Applications/Ghostty.app/Contents/MacOS/ghostty",
    os.path.expanduser("~/Applications/Ghostty.app/Contents/MacOS/ghostty"),
    os.path.expanduser("~/ghostty-build/zig-out/bin/ghostty"),
]


def get_ghostty_bin() -> str:
    """Find the Ghostty binary on macOS.

    Checks standard application locations, then falls back to PATH.

    Returns:
        Path to Ghostty binary, or "ghostty" if not found (will fail at runtime).
    """
    for path in _GHOSTTY_SEARCH_PATHS:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path

    # Check PATH
    try:
        result = subprocess.run(
            ["which", "ghostty"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return "ghostty"  # Fallback; will fail clearly at launch time


# ---------------------------------------------------------------------------
# Ghostty process discovery
# ---------------------------------------------------------------------------

def get_ghostty_pids() -> dict:
    """Map slot numbers to Ghostty PIDs on macOS.

    Uses `ps` to find Ghostty processes with per-slot config files.
    macOS equivalent of get_ghostty_bus_names() from shader_service.py.

    Returns:
        Dict mapping slot -> {"pid": int}
    """
    mapping = {}

    try:
        result = subprocess.run(
            ["ps", "-eo", "pid,args"],
            capture_output=True, text=True, timeout=5
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return mapping

    for line in result.stdout.splitlines():
        line = line.strip()
        if "ghostty-matrix-" not in line:
            continue
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        try:
            pid = int(parts[0])
        except ValueError:
            continue

        # Extract slot number from config file path
        match = re.search(r"ghostty-matrix-(\d+)", parts[1])
        if match:
            slot = int(match.group(1))
            mapping[slot] = {"pid": pid}

    return mapping


# ---------------------------------------------------------------------------
# Config reload
# ---------------------------------------------------------------------------

def reload_ghostty_mac(pid: int = None) -> bool:
    """Trigger Ghostty config reload on macOS.

    Tries SIGHUP first (simple Unix signal), then falls back to osascript.

    Args:
        pid: Specific Ghostty PID to reload. If None, reloads all.

    Returns:
        True on success, False on error.
    """
    if pid is not None:
        return _reload_by_signal(pid)
    else:
        return _reload_all()


def _reload_by_signal(pid: int) -> bool:
    """Send SIGHUP to a specific Ghostty process."""
    try:
        os.kill(pid, signal.SIGHUP)
        return True
    except (ProcessLookupError, PermissionError, OSError):
        # Fall back to osascript
        return _reload_by_osascript()


def _reload_all() -> bool:
    """Reload all Ghostty instances via osascript menu action."""
    mapping = get_ghostty_pids()
    if not mapping:
        return False

    success = True
    for info in mapping.values():
        if not _reload_by_signal(info["pid"]):
            success = False
    return success


def _reload_by_osascript() -> bool:
    """Trigger Ghostty config reload via AppleScript menu automation."""
    script = '''
    tell application "System Events"
        if exists process "ghostty" then
            tell process "ghostty"
                click menu item "Reload Configuration" of menu "Ghostty" of menu bar 1
            end tell
        end if
    end tell
    '''
    try:
        subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, timeout=5
        )
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


# ---------------------------------------------------------------------------
# Toast notifications
# ---------------------------------------------------------------------------

def show_toast_mac(message: str, title: str = "Matrix Shader") -> None:
    """Show a macOS notification via osascript.

    Fire-and-forget. Auto-dismisses after system default timeout.

    Args:
        message: Notification body text.
        title: Notification title.
    """
    # Escape double quotes in message/title
    message = message.replace('"', '\\"')
    title = title.replace('"', '\\"')
    script = f'display notification "{message}" with title "{title}"'
    try:
        subprocess.Popen(
            ["osascript", "-e", script],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


# ---------------------------------------------------------------------------
# Window positioning (AppleScript primary)
# ---------------------------------------------------------------------------

def position_window(pid: int, x: int, y: int, width: int, height: int) -> bool:
    """Move and resize a window by its application PID.

    Uses AppleScript via System Events. Requires Accessibility permission.

    Args:
        pid: Process ID of the application.
        x: Target X coordinate.
        y: Target Y coordinate.
        width: Target window width.
        height: Target window height.

    Returns:
        True on success, False on error.
    """
    script = f'''
    tell application "System Events"
        set targetProc to first process whose unix id is {pid}
        tell targetProc
            set position of window 1 to {{{x}, {y}}}
            set size of window 1 to {{{width}, {height}}}
        end tell
    end tell
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=5
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def get_screen_size() -> tuple:
    """Get the main screen dimensions on macOS.

    Returns:
        Tuple of (width, height) in pixels.
    """
    script = '''
    tell application "Finder"
        set screenBounds to bounds of window of desktop
        set screenWidth to item 3 of screenBounds
        set screenHeight to item 4 of screenBounds
    end tell
    return (screenWidth as text) & "," & (screenHeight as text)
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            parts = result.stdout.strip().split(",")
            return (int(parts[0]), int(parts[1]))
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError, IndexError):
        pass

    # Fallback: common default
    return (1920, 1080)


# ---------------------------------------------------------------------------
# Accessibility permission
# ---------------------------------------------------------------------------

def check_accessibility_permission() -> bool:
    """Check if this process has Accessibility permission.

    On macOS, CGEvent tap and AXUIElement API require Accessibility
    or Input Monitoring permission.

    Returns:
        True if permission is granted.
    """
    if sys.platform != "darwin":
        return False

    try:
        import ctypes
        appserv = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        )
        appserv.AXIsProcessTrusted.restype = ctypes.c_bool
        return appserv.AXIsProcessTrusted()
    except (OSError, AttributeError):
        return False


def request_accessibility_permission() -> None:
    """Open System Settings to the Accessibility pane.

    Prints instructions and opens the settings panel.
    """
    print("Matrix Shader needs Accessibility permission for global hotkeys.")
    print("Please grant access in: System Settings > Privacy & Security > Accessibility")
    print()
    try:
        subprocess.Popen(
            ["open", "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass
