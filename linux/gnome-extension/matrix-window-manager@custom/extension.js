// Matrix Window Manager - GNOME Shell Extension
// Exposes Mutter's window positioning API via D-Bus for Matrix Shader.
//
// Deployment:
//   cp -r linux/gnome-extension/matrix-window-manager@custom ~/.local/share/gnome-shell/extensions/
//   gnome-extensions enable matrix-window-manager@custom
//   # Then restart GNOME Shell (logout/login on Wayland, Alt+F2 'r' on X11)

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

const DBUS_INTERFACE_XML = `
<node>
  <interface name="org.matrix.WindowManager">
    <method name="MoveResize">
      <arg type="u" direction="in" name="pid"/>
      <arg type="i" direction="in" name="x"/>
      <arg type="i" direction="in" name="y"/>
      <arg type="i" direction="in" name="width"/>
      <arg type="i" direction="in" name="height"/>
      <arg type="b" direction="out" name="success"/>
    </method>
    <method name="GetGeometry">
      <arg type="u" direction="in" name="pid"/>
      <arg type="s" direction="out" name="json"/>
    </method>
    <method name="ListWindows">
      <arg type="s" direction="out" name="json"/>
    </method>
    <method name="GetFocusedPid">
      <arg type="u" direction="out" name="pid"/>
    </method>
    <method name="Ping">
      <arg type="b" direction="out" name="alive"/>
    </method>
  </interface>
</node>`;

class MatrixWindowManager {
    enable() {
        const nodeInfo = Gio.DBusNodeInfo.new_for_xml(DBUS_INTERFACE_XML);
        this._dbusId = Gio.DBus.session.register_object(
            '/org/matrix/WindowManager',
            nodeInfo.interfaces[0],
            this._onMethodCall.bind(this),
            null,
            null
        );
        if (this._dbusId === 0) {
            log('MatrixWindowManager: Failed to register D-Bus object');
            this._dbusId = null;
        }
    }

    disable() {
        if (this._dbusId) {
            Gio.DBus.session.unregister_object(this._dbusId);
            this._dbusId = null;
        }
    }

    _findWindowByPid(pid) {
        for (const actor of global.get_window_actors()) {
            const win = actor.get_meta_window();
            if (win && win.get_pid() === pid)
                return win;
        }
        return null;
    }

    _findGhosttyWindows() {
        const windows = [];
        for (const actor of global.get_window_actors()) {
            const win = actor.get_meta_window();
            if (!win) continue;
            const wmClass = win.get_wm_class();
            if (wmClass && wmClass.toLowerCase().includes('ghostty'))
                windows.push(win);
        }
        return windows;
    }

    _isMaximized(win) {
        // GNOME 49+ removed get_maximized() — use maximized_horizontally/vertically
        if (typeof win.get_maximized === 'function')
            return win.get_maximized() !== 0;
        return !!(win.maximizedHorizontally || win.maximizedVertically);
    }

    _windowToJson(win, focusedWin) {
        const rect = win.get_frame_rect();
        return {
            pid: win.get_pid(),
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
            maximized: this._isMaximized(win),
            focused: focusedWin ? win === focusedWin : false,
            title: win.get_title() || '',
            wm_class: win.get_wm_class() || '',
        };
    }

    _onMethodCall(connection, sender, objectPath, interfaceName, methodName, parameters, invocation) {
        switch (methodName) {
            case 'MoveResize': {
                const [pid, x, y, width, height] = parameters.deep_unpack();
                const win = this._findWindowByPid(pid);
                if (win) {
                    // Unmaximize before repositioning
                    if (this._isMaximized(win))
                        win.unmaximize(Meta.MaximizeFlags.BOTH);
                    win.move_resize_frame(false, x, y, width, height);
                    invocation.return_value(new GLib.Variant('(b)', [true]));
                } else {
                    invocation.return_value(new GLib.Variant('(b)', [false]));
                }
                break;
            }

            case 'GetGeometry': {
                const [pid] = parameters.deep_unpack();
                const win = this._findWindowByPid(pid);
                if (win) {
                    invocation.return_value(
                        new GLib.Variant('(s)', [JSON.stringify(this._windowToJson(win, null))])
                    );
                } else {
                    invocation.return_value(new GLib.Variant('(s)', ['{}']));
                }
                break;
            }

            case 'ListWindows': {
                const focusedWin = global.display.get_focus_window();
                const windows = this._findGhosttyWindows().map(w => this._windowToJson(w, focusedWin));
                invocation.return_value(
                    new GLib.Variant('(s)', [JSON.stringify(windows)])
                );
                break;
            }

            case 'GetFocusedPid': {
                const focused = global.display.get_focus_window();
                const pid = focused ? focused.get_pid() : 0;
                invocation.return_value(new GLib.Variant('(u)', [pid]));
                break;
            }

            case 'Ping': {
                invocation.return_value(new GLib.Variant('(b)', [true]));
                break;
            }

            default:
                invocation.return_dbus_error(
                    'org.freedesktop.DBus.Error.UnknownMethod',
                    `Unknown method: ${methodName}`
                );
        }
    }
}

export default class Extension extends MatrixWindowManager {}
