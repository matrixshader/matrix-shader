"""Window positioning service for Matrix Shader on Linux.

Provides programmatic window positioning via:
1. GNOME Shell Extension D-Bus API (primary, Wayland-native)
2. xdotool on XWayland (fallback)

Usage:
    python3 window_service.py register <slot> <pid>
    python3 window_service.py move <slot> <x> <y> <width> <height>
    python3 window_service.py get <slot>
    python3 window_service.py list
    python3 window_service.py monitors
    python3 window_service.py measure-offset <slot>
"""

import json
import os
import re
import subprocess
import sys

MATRIX_TMP = f"/tmp/matrixshader-{os.getuid()}"
os.makedirs(MATRIX_TMP, exist_ok=True)
MAP_FILE = f'{MATRIX_TMP}/matrix-window-map.json'

# GNOME Shell Extension D-Bus coordinates
DBUS_DEST = 'org.gnome.Shell'
DBUS_PATH = '/org/matrix/WindowManager'
DBUS_IFACE = 'org.matrix.WindowManager'


# --- Slot-to-PID Mapping ---

def load_mapping():
    """Read slot-to-PID mapping, purge dead PIDs, and recover orphans.

    VACCINE 1: Purges dead PIDs (ghost slots).
    VACCINE 2: Scans for running Ghostty matrix/construct windows that
    aren't in the mapping and auto-registers them. Prevents orphans.
    """
    try:
        with open(MAP_FILE) as f:
            raw = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        raw = {}
    # Purge dead PIDs
    clean = {}
    for slot, entry in raw.items():
        pid = entry.get('pid')
        if pid and _pid_alive(pid):
            clean[slot] = entry

    # VACCINE 2: Recover orphaned matrix windows not in mapping
    # Only scan when using the real production map file
    _do_orphan_scan = ("matrixshader-" in MAP_FILE)
    if not _do_orphan_scan:
        if clean != raw:
            try:
                with open(MAP_FILE, 'w') as f:
                    json.dump(clean, f)
            except OSError:
                pass
        return clean
    mapped_pids = {entry['pid'] for entry in clean.values()}
    try:
        result = subprocess.run(
            ["pgrep", "-u", str(os.getuid()), "-f", "ghostty.*ghostty-matrix-[0-9]"],
            capture_output=True, text=True, timeout=3,
            stdin=subprocess.DEVNULL,
        )
        for pid_str in result.stdout.strip().split():
            if not pid_str:
                continue
            pid = int(pid_str)
            if pid in mapped_pids:
                continue
            # Found orphan — determine its slot from cmdline
            try:
                with open(f"/proc/{pid}/cmdline") as f:
                    cmdline = f.read()
                for s in range(1, 9):
                    if f"ghostty-matrix-{s}" in cmdline and str(s) not in clean:
                        clean[str(s)] = {'pid': pid}
                        break
            except (FileNotFoundError, PermissionError):
                continue
        # Also check construct windows (post-transition)
        result2 = subprocess.run(
            ["pgrep", "-u", str(os.getuid()), "-f", "ghostty.*ghostty-construct-[0-9]"],
            capture_output=True, text=True, timeout=3,
            stdin=subprocess.DEVNULL,
        )
        for pid_str in result2.stdout.strip().split():
            if not pid_str:
                continue
            pid = int(pid_str)
            if pid in mapped_pids:
                continue
            try:
                with open(f"/proc/{pid}/cmdline") as f:
                    cmdline = f.read()
                for s in range(1, 9):
                    if f"ghostty-construct-{s}" in cmdline and str(s) not in clean:
                        clean[str(s)] = {'pid': pid}
                        break
            except (FileNotFoundError, PermissionError):
                continue
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # VACCINE 3: Recover missing config files for registered windows.
    # If a Ghostty process is alive but its config was deleted, recreate it
    # so hotkeys/reloads don't crash with config errors.
    for slot, entry in clean.items():
        pid = entry.get('pid')
        if not pid or not _pid_alive(pid):
            continue
        slot_num = int(slot)
        matrix_conf = f"{MATRIX_TMP}/ghostty-matrix-{slot_num}.conf"
        construct_conf = f"{MATRIX_TMP}/ghostty-construct-{slot_num}.conf"
        if not os.path.isfile(matrix_conf) and not os.path.isfile(construct_conf):
            _recover_config(slot_num)
        # Also check construct config (post-transition it mirrors matrix config)
        construct_conf = f"{MATRIX_TMP}/ghostty-construct-{slot_num}.conf"
        # Only recover construct conf if the process was launched with it
        try:
            with open(f"/proc/{pid}/cmdline") as f:
                cmdline = f.read()
            if f"ghostty-construct-{slot_num}" in cmdline and not os.path.isfile(construct_conf):
                # Copy matrix config — post-transition they're identical
                if os.path.isfile(matrix_conf):
                    import shutil
                    shutil.copy2(matrix_conf, construct_conf)
        except (FileNotFoundError, PermissionError, OSError):
            pass

    # Write back if anything changed
    if clean != raw:
        try:
            with open(MAP_FILE, 'w') as f:
                json.dump(clean, f)
        except OSError:
            pass
    return clean


def save_mapping(mapping):
    """Write slot-to-PID mapping to file."""
    with open(MAP_FILE, 'w') as f:
        json.dump(mapping, f)


def register_window(slot, pid):
    """Register a slot-to-PID mapping after launching a window.

    Purges any stale entries first to prevent ghost slots.
    SAFETY: refuses to overwrite a slot that has a DIFFERENT live PID.
    """
    mapping = load_mapping()  # auto-purges dead PIDs
    slot_str = str(slot)
    pid = int(pid)
    existing = mapping.get(slot_str)
    if existing:
        existing_pid = existing.get('pid')
        if existing_pid and existing_pid != pid and _pid_alive(existing_pid):
            # Slot occupied by a different live process — find a free slot instead
            for alt in range(1, 9):
                if str(alt) not in mapping:
                    slot_str = str(alt)
                    break
            else:
                # All slots full — refuse registration
                return
    mapping[slot_str] = {'pid': pid}
    save_mapping(mapping)


def unregister_window(slot):
    """Remove a slot from the mapping."""
    mapping = load_mapping()
    mapping.pop(str(slot), None)
    save_mapping(mapping)


def get_focused_slot():
    """Get the slot of the currently focused Ghostty window.

    Strategy (tried in order):
    1. GNOME Shell extension GetFocusedPid (Wayland-native, needs extension reload)
    2. GNOME Shell extension ListWindows with focused field (works after extension update)
    3. Ghostty is-focused D-Bus action (poll each instance, works immediately)
    4. state.json active_tab (stale fallback)
    """
    # Strategy 1: GNOME Shell extension GetFocusedPid D-Bus call
    try:
        result = subprocess.run(
            ["gdbus", "call", "--session",
             "--dest", DBUS_DEST,
             "--object-path", DBUS_PATH,
             "--method", f"{DBUS_IFACE}.GetFocusedPid"],
            capture_output=True, text=True, timeout=2,
            stdin=subprocess.DEVNULL,
        )
        if result.returncode == 0 and result.stdout.strip():
            import re as _re
            match = _re.search(r'\d+', result.stdout)
            if match:
                focused_pid = int(match.group())
                if focused_pid > 0:
                    mapping = load_mapping()
                    for slot_str, entry in mapping.items():
                        if entry.get('pid') == focused_pid:
                            return int(slot_str)
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError, ValueError):
        pass

    # Strategy 2: ListWindows with focused field (works once extension is reloaded)
    focused_slot = _check_list_windows_focus()
    if focused_slot is not None:
        return focused_slot

    # Strategy 3: Poll Ghostty instances via is-focused D-Bus action
    focused_pid = _poll_ghostty_focus()
    if focused_pid:
        mapping = load_mapping()
        for slot_str, entry in mapping.items():
            if entry.get('pid') == focused_pid:
                return int(slot_str)

    # Strategy 4: state.json active_tab (stale fallback)
    try:
        import state_service
        state = state_service.load_state()
        return state.get("active_tab")
    except Exception:
        return None


def _check_list_windows_focus():
    """Check ListWindows response for a focused Ghostty window.

    The GNOME extension's ListWindows includes a 'focused' boolean per window
    (added after the GetFocusedPid method). Returns the slot number of the
    focused window, or None if ListWindows doesn't include focus data.
    """
    try:
        result = subprocess.run(
            ["gdbus", "call", "--session",
             "--dest", DBUS_DEST,
             "--object-path", DBUS_PATH,
             "--method", f"{DBUS_IFACE}.ListWindows"],
            capture_output=True, text=True, timeout=2,
            stdin=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            return None
        # Response format: ('[ { "pid": 123, "focused": true, ... }, ... ]',)
        import json as _json
        raw = result.stdout.strip()
        # Extract the JSON string from GVariant tuple
        start = raw.find("'")
        end = raw.rfind("'")
        if start < 0 or end <= start:
            return None
        json_str = raw[start + 1:end].replace("\\'", "'")
        windows = _json.loads(json_str)
        # Find the focused window
        focused_pid = None
        for w in windows:
            if w.get('focused'):
                focused_pid = w.get('pid')
                break
        if not focused_pid:
            return None
        # Map PID to slot
        mapping = load_mapping()
        for slot_str, entry in mapping.items():
            if entry.get('pid') == focused_pid:
                return int(slot_str)
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError, ValueError,
            KeyError, _json.JSONDecodeError):
        pass
    return None


def _poll_ghostty_focus():
    """Poll all Ghostty D-Bus instances to find which one is focused.

    Calls Activate("is-focused") to refresh state, then Describe("is-focused")
    to read it. Returns the PID of the focused instance, or None.
    """
    # Get all Ghostty bus names and their PIDs
    try:
        result = subprocess.run(
            ["busctl", "--user", "list"],
            capture_output=True, text=True, timeout=2,
            stdin=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            return None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None

    bus_entries = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2 and 'ghostty' in line:
            bus_name = parts[0]
            try:
                pid = int(parts[1])
                bus_entries.append((bus_name, pid))
            except (ValueError, IndexError):
                continue

    for bus_name, pid in bus_entries:
        try:
            # Activate is-focused to refresh its state
            subprocess.run(
                ["gdbus", "call", "--session",
                 "--dest", bus_name,
                 "--object-path", "/com/mitchellh/ghostty",
                 "--method", "org.gtk.Actions.Activate",
                 "is-focused", "[]", "{}"],
                capture_output=True, text=True, timeout=1,
                stdin=subprocess.DEVNULL,
            )
            # Read the updated state
            desc = subprocess.run(
                ["gdbus", "call", "--session",
                 "--dest", bus_name,
                 "--object-path", "/com/mitchellh/ghostty",
                 "--method", "org.gtk.Actions.Describe",
                 "is-focused"],
                capture_output=True, text=True, timeout=1,
                stdin=subprocess.DEVNULL,
            )
            if desc.returncode == 0 and 'true' in desc.stdout.lower():
                return pid
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue
    return None


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


def _recover_config(slot):
    """Recreate a missing ghostty-matrix-{slot}.conf from state or defaults.

    VACCINE 3 helper: rebuilds the config file so hotkeys/reloads don't crash.
    Uses foreground color from state.json shader_configs if available.
    """
    shader_dir = os.path.expanduser("~/.config/matrix-shader/shaders")
    shader_path = os.path.join(shader_dir, f"matrix-{slot}.glsl")
    fg_color = "#00ff4d"  # Default green

    # Try to read foreground from the existing config of a related process
    # (e.g., construct conf might exist even if matrix conf doesn't)
    for pattern in [f"{MATRIX_TMP}/ghostty-matrix-{slot}.conf", f"{MATRIX_TMP}/ghostty-construct-{slot}.conf"]:
        try:
            with open(pattern) as f:
                for line in f:
                    if line.strip().startswith("foreground"):
                        fg_color = line.split("=", 1)[1].strip()
                        break
                if fg_color != "#00ff4d":
                    break
        except FileNotFoundError:
            continue

    # Fallback: map RAIN RGB from state.json to nearest preset foreground
    if fg_color == "#00ff4d":
        try:
            state_file = os.path.expanduser("~/.config/matrix-shader/state.json")
            with open(state_file) as f:
                state = json.load(f)
            sc = state.get("shader_configs", {}).get(str(slot), {})
            r = sc.get("RAIN_R", 0.0)
            g = sc.get("RAIN_G", 1.0)
            b = sc.get("RAIN_B", 0.3)
            presets = [
                (0.0, 1.0, 0.3, "#00ff4d"),   # Green
                (0.0, 0.6, 1.0, "#0099ff"),   # Blue
                (1.0, 0.1, 0.1, "#ff1a1a"),   # Red
                (0.7, 0.0, 1.0, "#b300ff"),   # Purple
                (1.0, 0.7, 0.0, "#ffb300"),   # Gold
                (0.0, 0.9, 0.9, "#00e6e6"),   # Teal
            ]
            best_dist = float('inf')
            for pr, pg, pb, color in presets:
                dist = (r - pr)**2 + (g - pg)**2 + (b - pb)**2
                if dist < best_dist:
                    best_dist = dist
                    fg_color = color
        except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError):
            pass

    conf_path = f"{MATRIX_TMP}/ghostty-matrix-{slot}.conf"
    content = (
        f"custom-shader = {shader_path}\n"
        f"background = #000000\n"
        f"foreground = {fg_color}\n"
        f"font-family = Nimbus Mono PS\n"
        f"font-style = Bold\n"
        f"background-opacity = 0\n"
        f"gtk-titlebar = true\n"
        f"window-decoration = client\n"
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
    try:
        with open(conf_path, "w") as f:
            f.write(content)
    except OSError:
        pass


# --- GNOME Shell Extension D-Bus Client ---

def _gdbus_call(method, *args):
    """Call a method on the GNOME Shell extension D-Bus interface.

    Returns (stdout, success) tuple.
    """
    cmd = [
        'gdbus', 'call', '--session',
        '--dest', DBUS_DEST,
        '--object-path', DBUS_PATH,
        '--method', f'{DBUS_IFACE}.{method}',
    ] + [str(a) for a in args]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return result.stdout.strip(), result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return '', False


def _parse_bool_response(response):
    """Parse D-Bus boolean response like '(true,)' or '(false,)'."""
    return 'true' in response.lower()


def _parse_string_response(response):
    """Parse D-Bus string response like '(\\'{"x":0}\\',)'.

    The gdbus output wraps strings in ('...',) with possible escaping.
    """
    # Remove outer parentheses and trailing comma
    s = response.strip()
    if s.startswith('(') and s.endswith(')'):
        s = s[1:-1].rstrip(',').strip()
    # Remove outer quotes
    if (s.startswith("'") and s.endswith("'")) or \
       (s.startswith('"') and s.endswith('"')):
        s = s[1:-1]
    return s


def gnome_extension_available():
    """Check if the GNOME Shell extension is responding."""
    response, ok = _gdbus_call('Ping')
    return ok and _parse_bool_response(response)


def move_resize_gnome(pid, x, y, width, height):
    """Move and resize a window by PID via GNOME Shell extension."""
    response, ok = _gdbus_call('MoveResize', pid, x, y, width, height)
    return ok and _parse_bool_response(response)


def get_geometry_gnome(pid):
    """Get window geometry by PID via GNOME Shell extension."""
    response, ok = _gdbus_call('GetGeometry', pid)
    if not ok:
        return None
    json_str = _parse_string_response(response)
    try:
        data = json.loads(json_str)
        return data if data else None
    except (json.JSONDecodeError, TypeError):
        return None


def list_ghostty_windows():
    """List all Ghostty windows via GNOME Shell extension."""
    response, ok = _gdbus_call('ListWindows')
    if not ok:
        return []
    json_str = _parse_string_response(response)
    try:
        return json.loads(json_str)
    except (json.JSONDecodeError, TypeError):
        return []


# --- XWayland Fallback (xdotool) ---

def _find_xwayland_window(pid):
    """Find XWayland window ID by PID using xdotool."""
    try:
        result = subprocess.run(
            ['xdotool', 'search', '--pid', str(pid)],
            capture_output=True, text=True, timeout=5
        )
        wids = result.stdout.strip().split('\n')
        if wids and wids[0]:
            return int(wids[0])
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError):
        pass
    return None


def move_resize_xwayland(pid, x, y, width, height):
    """Move and resize via xdotool (XWayland fallback)."""
    wid = _find_xwayland_window(pid)
    if wid is None:
        return False
    try:
        subprocess.run(
            ['xdotool', 'windowmove', str(wid), str(x), str(y)],
            check=True, capture_output=True, timeout=5
        )
        subprocess.run(
            ['xdotool', 'windowsize', str(wid), str(width), str(height)],
            check=True, capture_output=True, timeout=5
        )
        return True
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return False


def get_geometry_xwayland(pid):
    """Get window geometry via xdotool."""
    wid = _find_xwayland_window(pid)
    if wid is None:
        return None
    try:
        result = subprocess.run(
            ['xdotool', 'getwindowgeometry', '--shell', str(wid)],
            capture_output=True, text=True, timeout=5
        )
        geo = {}
        for line in result.stdout.strip().splitlines():
            if '=' in line:
                k, v = line.split('=', 1)
                geo[k.strip().lower()] = int(v.strip())
        if geo:
            return {
                'x': geo.get('x', 0),
                'y': geo.get('y', 0),
                'width': geo.get('width', 0),
                'height': geo.get('height', 0),
            }
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError, ValueError):
        pass
    return None


# --- High-Level API (auto-selects backend) ---

_extension_cache = None


def _check_extension():
    """Check GNOME extension availability (cached)."""
    global _extension_cache
    if _extension_cache is None:
        _extension_cache = gnome_extension_available()
    return _extension_cache


def _position_via_ghostty_config(slot, x, y, width, height):
    """Move window by writing position to Ghostty config and triggering reload.

    Works without GNOME extension — uses Ghostty's native window-position config
    and D-Bus reload-config (same mechanism used for shader changes).
    """
    conf_path = f"{MATRIX_TMP}/ghostty-matrix-{slot}.conf"
    if not os.path.isfile(conf_path):
        return False
    try:
        with open(conf_path) as f:
            lines = f.readlines()
        # Remove existing position lines
        lines = [l for l in lines if not l.strip().startswith(('window-position-x', 'window-position-y', 'window-width', 'window-height'))]
        # Add new position
        lines.append(f"window-position-x = {x}\n")
        lines.append(f"window-position-y = {y}\n")
        lines.append(f"window-width = {width}\n")
        lines.append(f"window-height = {height}\n")
        with open(conf_path, 'w') as f:
            f.writelines(lines)
        # Trigger Ghostty to reload config via D-Bus
        pid = get_pid_for_slot(slot)
        if pid:
            from shader_service import reload_ghostty, get_ghostty_bus_names
            mapping = get_ghostty_bus_names()
            if slot in mapping:
                reload_ghostty(mapping[slot]["bus_name"])
                return True
    except (OSError, ImportError):
        pass
    return False


def position_window(slot, x, y, width, height):
    """Move a Matrix window to exact coordinates.

    Tries GNOME Shell extension first, then xdotool, then Ghostty config reload.
    """
    pid = get_pid_for_slot(slot)
    if pid is None:
        return False
    if _check_extension():
        return move_resize_gnome(pid, x, y, width, height)
    result = move_resize_xwayland(pid, x, y, width, height)
    if result:
        return True
    # Last resort: write position to Ghostty config and reload
    return _position_via_ghostty_config(slot, x, y, width, height)


def get_position(slot):
    """Get current window geometry for a slot."""
    pid = get_pid_for_slot(slot)
    if pid is None:
        return None
    if _check_extension():
        return get_geometry_gnome(pid)
    return get_geometry_xwayland(pid)


# --- Monitor Discovery ---

def get_monitors():
    """Get monitor geometry from Mutter DisplayConfig.

    Returns list of dicts with name, x, y, width, height, scale, primary.
    """
    try:
        result = subprocess.run([
            'gdbus', 'call', '--session',
            '--dest', 'org.gnome.Mutter.DisplayConfig',
            '--object-path', '/org/gnome/Mutter/DisplayConfig',
            '--method', 'org.gnome.Mutter.DisplayConfig.GetCurrentState'
        ], capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            return _fallback_monitors()
        return _parse_mutter_monitors(result.stdout)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return _fallback_monitors()


def _parse_mutter_monitors(output):
    """Parse logical monitors from Mutter DisplayConfig GetCurrentState.

    The logical_monitors section format in GVariant text:
    [(x, y, scale, transform, primary, [(connector, vendor, product, serial)], {})]
    """
    monitors = []
    # Find the logical monitors section - it's between the monitors array and properties
    # Look for patterns like (0, 0, 1.0, uint32 0, true, [('eDP-1', ...)])
    # Each logical monitor starts with (int, int, double, uint32 int, bool, [connectors])
    pattern = r'\((\-?\d+),\s*(\-?\d+),\s*([\d.]+),\s*uint32\s+\d+,\s*(true|false),\s*\[\(\'([^\']+)\''
    for m in re.finditer(pattern, output):
        x, y, scale, primary, connector = m.groups()
        # Find the resolution for this connector from the monitors section
        width, height = _find_monitor_resolution(output, connector)
        monitors.append({
            'name': connector,
            'x': int(x),
            'y': int(y),
            'width': width,
            'height': height,
            'scale': float(scale),
            'primary': primary == 'true',
        })
    if not monitors:
        return _fallback_monitors()
    return monitors


def _find_monitor_resolution(output, connector):
    """Find the current resolution for a monitor connector from Mutter output."""
    # Look for the monitor section with this connector and find 'is-current': <true>
    # The format is: ('WxH@rate', W, H, rate, scale, [scales], {'is-current': <true>})
    # Find the section for this connector
    connector_pos = output.find(f"'{connector}'")
    if connector_pos == -1:
        return 0, 0
    # Search forward from connector for is-current: <true>
    search_area = output[connector_pos:connector_pos + 2000]
    # Find mode entries with is-current
    current_pattern = r"'[^']+',\s*(\d+),\s*(\d+),\s*[\d.]+,\s*[\d.]+,\s*\[[\d.,\s]*\],\s*\{[^}]*'is-current':\s*<true>"
    m = re.search(current_pattern, search_area)
    if m:
        return int(m.group(1)), int(m.group(2))
    return 0, 0


def _fallback_monitors():
    """Fallback monitor info when Mutter D-Bus is unavailable."""
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
    """Measure decoration offset by comparing frame rect with configured size.

    Returns dict with titlebar_height and shadow offsets.
    Defaults to reasonable GNOME Adwaita values if measurement fails.
    """
    defaults = {
        'titlebar_height': 37,
        'shadow_left': 0,
        'shadow_right': 0,
        'shadow_top': 0,
        'shadow_bottom': 0,
    }
    geo = get_position(slot)
    if not geo:
        return defaults
    # For now, return defaults — accurate measurement requires comparing
    # frame rect to content rect, which needs the extension to report both.
    # The frame rect from move_resize_frame is what we use for positioning,
    # so offsets only matter for Phase 6 edge-flush calculations.
    return defaults


# --- CLI Interface ---

def main():
    if len(sys.argv) < 2:
        print("Usage: window_service.py <command> [args]")
        print("Commands: register, move, get, list, monitors, measure-offset, ping")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'register':
        if len(sys.argv) != 4:
            print("Usage: window_service.py register <slot> <pid>")
            sys.exit(1)
        register_window(int(sys.argv[2]), int(sys.argv[3]))

    elif cmd == 'unregister':
        if len(sys.argv) != 3:
            print("Usage: window_service.py unregister <slot>")
            sys.exit(1)
        unregister_window(int(sys.argv[2]))

    elif cmd == 'move':
        if len(sys.argv) != 7:
            print("Usage: window_service.py move <slot> <x> <y> <width> <height>")
            sys.exit(1)
        slot, x, y, w, h = (int(a) for a in sys.argv[2:7])
        success = position_window(slot, x, y, w, h)
        if not success:
            print("Failed to move window", file=sys.stderr)
            sys.exit(1)

    elif cmd == 'get':
        if len(sys.argv) != 3:
            print("Usage: window_service.py get <slot>")
            sys.exit(1)
        geo = get_position(int(sys.argv[2]))
        print(json.dumps(geo) if geo else '{}')

    elif cmd == 'list':
        print(json.dumps(list_ghostty_windows(), indent=2))

    elif cmd == 'monitors':
        print(json.dumps(get_monitors(), indent=2))

    elif cmd == 'measure-offset':
        if len(sys.argv) != 3:
            print("Usage: window_service.py measure-offset <slot>")
            sys.exit(1)
        offset = measure_decoration_offset(int(sys.argv[2]))
        print(json.dumps(offset, indent=2))

    elif cmd == 'ping':
        available = gnome_extension_available()
        print(f"GNOME extension: {'available' if available else 'not available'}")
        sys.exit(0 if available else 1)

    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
