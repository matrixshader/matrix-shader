#!/usr/bin/env python3
"""Matrix Shader OSD toast — transparent floating text overlay.

Usage: python3 matrix_toast.py "85%"

Nimbus Mono PS Bold, #03A062, bottom-center, no background.
GTK3 + Cairo with RGBA visual on XWayland for per-pixel transparency
and exact positioning. Auto-dismiss 1.5s. PID file for kill-and-replace.
"""

import os
import signal
import sys

PID_FILE = "/tmp/matrix-toast.pid"
DISMISS_MS = 1500
BOTTOM_OFFSET = 60


def kill_previous():
    try:
        with open(PID_FILE) as f:
            os.kill(int(f.read().strip()), signal.SIGTERM)
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        pass


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    text = sys.argv[1]
    kill_previous()
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    os.environ["GDK_BACKEND"] = "x11"

    import cairo
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib

    class Toast(Gtk.Window):
        def __init__(self):
            super().__init__(type=Gtk.WindowType.POPUP)
            self.text = text
            self.set_app_paintable(True)
            self.set_decorated(False)
            self.set_keep_above(True)

            screen = self.get_screen()
            visual = screen.get_rgba_visual()
            if visual:
                self.set_visual(visual)

            self.connect("draw", self.on_draw)
            self.set_size_request(300, 80)
            self.show_all()

            sw = screen.get_width()
            sh = screen.get_height()
            self.move((sw - 300) // 2, sh - 80 - BOTTOM_OFFSET)

            GLib.timeout_add(DISMISS_MS, Gtk.main_quit)

        def on_draw(self, widget, cr):
            cr.set_source_rgba(0, 0, 0, 0)
            cr.set_operator(cairo.OPERATOR_SOURCE)
            cr.paint()
            cr.set_operator(cairo.OPERATOR_OVER)
            cr.select_font_face(
                "Nimbus Mono PS", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD
            )
            cr.set_font_size(56)
            extents = cr.text_extents(self.text)
            w = widget.get_allocated_width()
            h = widget.get_allocated_height()
            x = (w - extents.width) / 2 - extents.x_bearing
            y = (h - extents.height) / 2 - extents.y_bearing
            cr.move_to(x, y)
            cr.set_source_rgba(0.012, 0.627, 0.384, 0.85)
            cr.show_text(self.text)
            return True

    Toast()
    Gtk.main()

    try:
        with open(PID_FILE) as f:
            if int(f.read().strip()) == os.getpid():
                os.unlink(PID_FILE)
    except (FileNotFoundError, ValueError):
        pass


if __name__ == "__main__":
    main()
