#!/usr/bin/env python3
"""Matrix Shader macOS notification -- osascript-based toast.

Usage: python3 matrix_toast_mac.py "85%"

Uses macOS display notification (Notification Center).
Auto-dismisses after system default timeout.
"""

import subprocess
import sys


def show_toast(message, title="Matrix Shader"):
    """Show a macOS notification via osascript.

    Fire-and-forget. Uses display notification which appears
    in Notification Center.

    Args:
        message: Notification body text.
        title: Notification title.
    """
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


if __name__ == "__main__":
    if len(sys.argv) > 1:
        show_toast(sys.argv[1])
