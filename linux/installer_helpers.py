"""Helper functions for installer/uninstaller — testable Python equivalents.

Used by tests and called inline from wakeupneo.sh for notifications.
"""

import subprocess


def notify_matrix_running(window_count):
    """Send desktop notification after Matrix windows launch.

    Args:
        window_count: Number of Matrix windows deployed.
    """
    try:
        subprocess.run([
            'notify-send',
            '--app-name=Matrix Shader',
            '--expire-time=5000',
            'The Matrix has you',
            f'{window_count} window(s) deployed',
        ])
    except FileNotFoundError:
        pass  # notify-send not installed — silently skip
