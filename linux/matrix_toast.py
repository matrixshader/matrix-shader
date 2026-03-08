#!/usr/bin/env python3
"""Matrix Shader OSD toast — transparent floating text overlay.

Usage: python3 matrix_toast.py "85%"

Nimbus Mono PS Bold, #03A062, bottom-center, no background.
GTK3 + Cairo on XWayland. Auto-dismiss 1.5s. PID file for replacement.
"""

import os
import signal
import sys

PID_FILE = "/tmp/matrix-toast.pid"
DISMISS_MS = 1500
BOTTOM_OFFSET = 60


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    text = sys.argv[1]

    # Kill previous toast
    try:
        with open(PID_FILE) as f:
            os.kill(int(f.read().strip()), signal.SIGTERM)
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        pass
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    os.environ["GDK_BACKEND"] = "x11"

    import cairo
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib

    # No Gtk.Application — just a plain window. No D-Bus registration.
    win = Gtk.Window(type=Gtk.WindowType.POPUP)
    win.set_app_paintable(True)
    win.set_decorated(False)
    win.set_keep_above(True)
    win.set_skip_taskbar_hint(True)
    win.set_skip_pager_hint(True)

    screen = win.get_screen()
    visual = screen.get_rgba_visual()
    if visual:
        win.set_visual(visual)

    def on_draw(widget, cr):
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)
        cr.select_font_face(
            "Nimbus Mono PS", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD
        )
        cr.set_font_size(56)
        extents = cr.text_extents(text)
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        x = (w - extents.width) / 2 - extents.x_bearing
        y = (h - extents.height) / 2 - extents.y_bearing
        cr.move_to(x, y)
        cr.set_source_rgba(0.012, 0.627, 0.384, 0.85)
        cr.show_text(text)
        return True

    win.connect("draw", on_draw)
    win.set_size_request(300, 80)
    win.show_all()

    sw = screen.get_width()
    sh = screen.get_height()
    win.move((sw - 300) // 2, sh - 80 - BOTTOM_OFFSET)

    def dismiss(*_a):
        Gtk.main_quit()
        return False

    GLib.timeout_add(DISMISS_MS, dismiss)
    signal.signal(signal.SIGTERM, lambda *_: GLib.idle_add(dismiss))

    Gtk.main()

    try:
        with open(PID_FILE) as f:
            if int(f.read().strip()) == os.getpid():
                os.unlink(PID_FILE)
    except (FileNotFoundError, ValueError):
        pass


if __name__ == "__main__":
    main()
