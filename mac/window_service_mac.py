"""Window positioning service for Matrix Shader on macOS.

Provides programmatic window positioning via AppleScript/osascript.
Same high-level API as linux/window_service.py so layout_engine.py works
on both platforms.

Usage:
    python3 window_service_mac.py register <slot> <pid>
    python3 window_service_mac.py move <slot> <x> <y> <width> <height>
    python3 window_service_mac.py get <slot>
    python3 window_service_mac.py list
    python3 window_service_mac.py monitors
"""

import json
import os
import re
import subprocess
import sys

MATRIX_TMP = f"/tmp/matrixshader-{os.getuid()}"
os.makedirs(MATRIX_TMP, exist_ok=True)
MAP_FILE = f'{MATRIX_TMP}/matrix-window-map.json'


# --- Slot-to-PID Mapping ---

def load_mapping():
    """Read slot-to-PID mapping from file."""
    try:
        with open(MAP_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_mapping(mapping):
    """Write slot-to-PID mapping to file."""
    with open(MAP_FILE, 'w') as f:
        json.dump(mapping, f)


def register_window(slot, pid):
    """Register a slot-to-PID mapping after launching a window."""
    mapping = load_mapping()
    mapping[str(slot)] = {'pid': int(pid)}
    save_mapping(mapping)


def unregister_window(slot):
    """Remove a slot from the mapping."""
    mapping = load_mapping()
    mapping.pop(str(slot), None)
    save_mapping(mapping)


def get_pid_for_slot(slot):
    """Get the PID for a given slot number. Returns None if not found or dead."""
    mapping = load_mapping()
    entry = mapping.get(str(slot))
    if entry and _pid_alive(entry['pid']):
        return entry['pid']
    return None


def _pid_alive(pid):
    """Check if a PID is still running."""
    try:
        os.kill(int(pid), 0)
        return True
    except (ProcessLookupError, PermissionError, ValueError, TypeError):
        return False


# --- AppleScript Window Positioning ---

def _osascript(script):
    """Run an AppleScript and return (stdout, success)."""
    try:
        result = subprocess.run(
            ['osascript', '-e', script],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip(), result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return '', False


def move_resize_window(pid, x, y, width, height):
    """Move and resize a window by PID via AppleScript System Events."""
    script = f'''
    tell application "System Events"
        set targetProc to first process whose unix id is {pid}
        tell targetProc
            set position of window 1 to {{{x}, {y}}}
            set size of window 1 to {{{width}, {height}}}
        end tell
    end tell
    '''
    _, ok = _osascript(script)
    return ok


def get_geometry_window(pid):
    """Get window geometry by PID via AppleScript System Events."""
    script = f'''
    tell application "System Events"
        set targetProc to first process whose unix id is {pid}
        tell targetProc
            set winPos to position of window 1
            set winSize to size of window 1
        end tell
    end tell
    return (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
    '''
    out, ok = _osascript(script)
    if not ok or not out:
        return None
    try:
        parts = out.split(',')
        return {
            'x': int(parts[0]),
            'y': int(parts[1]),
            'width': int(parts[2]),
            'height': int(parts[3]),
        }
    except (ValueError, IndexError):
        return None


def list_ghostty_windows():
    """List all Ghostty windows via AppleScript."""
    script = '''
    tell application "System Events"
        if exists process "Ghostty" then
            tell process "Ghostty"
                set winList to {}
                repeat with w in windows
                    set winPos to position of w
                    set winSize to size of w
                    set end of winList to (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
                end repeat
            end tell
        end if
    end tell
    set AppleScript's text item delimiters to "|"
    return winList as text
    '''
    out, ok = _osascript(script)
    if not ok or not out:
        return []
    windows = []
    for entry in out.split('|'):
        try:
            parts = entry.strip().split(',')
            windows.append({
                'x': int(parts[0]),
                'y': int(parts[1]),
                'width': int(parts[2]),
                'height': int(parts[3]),
            })
        except (ValueError, IndexError):
            continue
    return windows


# --- High-Level API (matches linux/window_service.py) ---

def position_window(slot, x, y, width, height):
    """Move a Matrix window to exact coordinates."""
    pid = get_pid_for_slot(slot)
    if pid is None:
        return False
    return move_resize_window(pid, x, y, width, height)


def get_position(slot):
    """Get current window geometry for a slot."""
    pid = get_pid_for_slot(slot)
    if pid is None:
        return None
    return get_geometry_window(pid)


# --- Monitor Discovery ---

def get_monitors():
    """Get monitor geometry on macOS via system_profiler.

    Returns list of dicts with name, x, y, width, height, scale, primary.
    """
    try:
        result = subprocess.run(
            ['system_profiler', 'SPDisplaysDataType', '-json'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            return _parse_system_profiler(result.stdout)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return _fallback_monitors()


def _parse_system_profiler(output):
    """Parse display info from system_profiler JSON output."""
    monitors = []
    try:
        data = json.loads(output)
        displays_data = data.get('SPDisplaysDataType', [])
        x_offset = 0
        for gpu in displays_data:
            for display in gpu.get('spdisplays_ndrvs', []):
                res = display.get('_spdisplays_resolution', '')
                match = re.match(r'(\d+)\s*x\s*(\d+)', res)
                width = int(match.group(1)) if match else 1920
                height = int(match.group(2)) if match else 1080
                is_main = display.get('spdisplays_main', '') == 'spdisplays_yes'
                monitors.append({
                    'name': display.get('_name', 'unknown'),
                    'x': 0 if is_main else x_offset,
                    'y': 0,
                    'width': width,
                    'height': height,
                    'scale': 2.0 if 'Retina' in res else 1.0,
                    'primary': is_main,
                })
                if not is_main:
                    x_offset += width
    except (json.JSONDecodeError, KeyError, TypeError):
        pass
    return monitors if monitors else _fallback_monitors()


def _fallback_monitors():
    """Fallback monitor info when system_profiler is unavailable."""
    return [{
        'name': 'unknown',
        'x': 0,
        'y': 0,
        'width': 1920,
        'height': 1080,
        'scale': 1.0,
        'primary': True,
    }]


# --- Decoration Offset Measurement ---

def measure_decoration_offset(slot):
    """Measure decoration offset. macOS titlebar is ~28px."""
    return {
        'titlebar_height': 28,
        'shadow_left': 0,
        'shadow_right': 0,
        'shadow_top': 0,
        'shadow_bottom': 0,
    }


# --- CLI Interface ---

def main():
    if len(sys.argv) < 2:
        print("Usage: window_service_mac.py <command> [args]")
        print("Commands: register, move, get, list, monitors, measure-offset")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'register':
        if len(sys.argv) != 4:
            print("Usage: window_service_mac.py register <slot> <pid>")
            sys.exit(1)
        register_window(int(sys.argv[2]), int(sys.argv[3]))

    elif cmd == 'unregister':
        if len(sys.argv) != 3:
            print("Usage: window_service_mac.py unregister <slot>")
            sys.exit(1)
        unregister_window(int(sys.argv[2]))

    elif cmd == 'move':
        if len(sys.argv) != 7:
            print("Usage: window_service_mac.py move <slot> <x> <y> <width> <height>")
            sys.exit(1)
        slot, x, y, w, h = (int(a) for a in sys.argv[2:7])
        success = position_window(slot, x, y, w, h)
        if not success:
            print("Failed to move window", file=sys.stderr)
            sys.exit(1)

    elif cmd == 'get':
        if len(sys.argv) != 3:
            print("Usage: window_service_mac.py get <slot>")
            sys.exit(1)
        geo = get_position(int(sys.argv[2]))
        print(json.dumps(geo) if geo else '{}')

    elif cmd == 'list':
        print(json.dumps(list_ghostty_windows(), indent=2))

    elif cmd == 'monitors':
        print(json.dumps(get_monitors(), indent=2))

    elif cmd == 'measure-offset':
        if len(sys.argv) != 3:
            print("Usage: window_service_mac.py measure-offset <slot>")
            sys.exit(1)
        offset = measure_decoration_offset(int(sys.argv[2]))
        print(json.dumps(offset, indent=2))

    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
