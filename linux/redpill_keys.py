"""Key-to-action mapping for the Red Pill TUI control panel.

Direct port of MatrixShader.Cli.Redpill/KeyHandler.cs.
Maps raw key codes (from tty.setraw / sys.stdin) to action strings.

Shift+letter combinations detected via uppercase char codes
BEFORE lowercase fallback -- this is critical for distinguishing
Shift+L (LayoutCycle) from lowercase l (OpacityIncrease).
"""

import select
import sys
import termios
import tty


def read_key(fd=None):
    """Read a single keypress from raw terminal input.

    Handles multi-byte escape sequences (arrow keys, Shift+Tab, etc.)
    by checking if more bytes are available after reading ESC.

    Args:
        fd: File descriptor to read from. Defaults to sys.stdin.

    Returns:
        Integer key code compatible with process_key().
        Special return values:
          - 27 for bare Escape
          - -2 for Shift+Tab (ESC [ Z)
          - -3 for Up arrow
          - -4 for Down arrow
          - -5 for Right arrow
          - -6 for Left arrow
          - Regular ord() values for printable characters
    """
    if fd is None:
        fd = sys.stdin

    ch = fd.read(1)
    if not ch:
        return -1

    if ch == '\x1b':
        # Check if more bytes follow (escape sequence vs bare Escape)
        if _has_more(fd):
            seq = ch + fd.read(1)
            if len(seq) == 2 and seq[1] == '[':
                # CSI sequence -- read the final byte
                if _has_more(fd):
                    seq += fd.read(1)
                    if seq == '\x1b[A':
                        return -3   # Up
                    if seq == '\x1b[B':
                        return -4   # Down
                    if seq == '\x1b[C':
                        return -5   # Right
                    if seq == '\x1b[D':
                        return -6   # Left
                    if seq == '\x1b[Z':
                        return -2   # Shift+Tab
                    # Drain any remaining bytes in the sequence
                    while _has_more(fd):
                        fd.read(1)
                    return -1
            # Unknown escape sequence -- drain and ignore
            while _has_more(fd):
                fd.read(1)
            return -1
        # Bare Escape
        return 27

    return ord(ch)


def _has_more(fd, timeout=0.1):
    """Check if more input is available on fd within timeout seconds.

    100ms timeout handles mouse scroll sequences that arrive slightly
    delayed (Ghostty on Wayland). Too short = scroll \x1b bytes get
    treated as bare ESC and close the TUI.
    """
    if hasattr(fd, 'fileno'):
        r, _, _ = select.select([fd], [], [], timeout)
        return bool(r)
    return False


def enter_raw_mode(fd=None):
    """Put terminal into raw mode, returning old settings for restore.

    Args:
        fd: File descriptor. Defaults to sys.stdin.fileno().

    Returns:
        Old termios settings (pass to restore_mode).
    """
    if fd is None:
        fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    tty.setraw(fd)
    return old


def restore_mode(old_settings, fd=None):
    """Restore terminal to previous mode.

    Args:
        old_settings: Settings returned by enter_raw_mode().
        fd: File descriptor. Defaults to sys.stdin.fileno().
    """
    if fd is None:
        fd = sys.stdin.fileno()
    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


def process_key(key):
    """Map a raw key code to an action string.

    Args:
        key: Integer key code from read_key().

    Returns:
        Action string, or None for unrecognized keys.
    """
    # Special keys
    if key == 9:    return "Tab"
    if key == 10 or key == 13:  return "Launch"    # LF or CR (raw mode sends CR)
    if key == 27:   return "Quit"
    if key == -2 or key == 353:  return "ShiftTab"  # ESC [ Z (raw) or KEY_BTAB (curses)

    # Arrow keys (for sub-screens like hotkey config)
    if key == -3:   return "ArrowUp"
    if key == -4:   return "ArrowDown"
    if key == -5:   return "ArrowRight"
    if key == -6:   return "ArrowLeft"

    # Shift combinations (uppercase letters) -- check BEFORE lowercase
    if key == ord('L'):  return "LayoutCycle"
    if key == ord('S'):  return "SnapbackSave"
    if key == ord('R'):  return "SnapbackRestore"
    if key == ord('G'):  return "GlitchToggle"
    if key == ord('H'):  return "HotkeyConfig"
    if key == ord('P'):  return "PresetsMenu"
    if key == ord('M'):  return "MonitorChange"
    if key == ord('?'):  return "Help"

    # Color presets (1-6)
    if key == ord('1'):  return "PresetGreen"
    if key == ord('2'):  return "PresetBlue"
    if key == ord('3'):  return "PresetRed"
    if key == ord('4'):  return "PresetPurple"
    if key == ord('5'):  return "PresetGold"
    if key == ord('6'):  return "PresetTeal"

    # RGB fine-tune (Q/W, A/S, Z/X)
    if key == ord('q'):  return "RedDecrease"
    if key == ord('w'):  return "RedIncrease"
    if key == ord('a'):  return "GreenDecrease"
    if key == ord('s'):  return "GreenIncrease"
    if key == ord('z'):  return "BlueDecrease"
    if key == ord('x'):  return "BlueIncrease"

    # Rain parameters (paired keys for -/+)
    if key == ord('e'):  return "SpeedDecrease"
    if key == ord('r'):  return "SpeedIncrease"
    if key == ord('d'):  return "GlowDecrease"
    if key == ord('f'):  return "GlowIncrease"
    if key == ord('c'):  return "WidthDecrease"
    if key == ord('v'):  return "WidthIncrease"
    if key == ord('t'):  return "TrailDecrease"
    if key == ord('y'):  return "TrailIncrease"
    if key == ord('g'):  return "DensityDecrease"
    if key == ord('h'):  return "DensityIncrease"

    # Layer toggles (7/8/9)
    if key == ord('7'):  return "Layer1Toggle"
    if key == ord('8'):  return "Layer2Toggle"
    if key == ord('9'):  return "Layer3Toggle"

    # Window effects
    if key == ord('b'):  return "TransparencyToggle"
    if key == ord('k'):  return "OpacityDecrease"
    if key == ord('l'):  return "OpacityIncrease"

    # Deploy count controls
    if key == ord('-'):  return "LaunchDecrease"
    if key == ord('+') or key == ord('='):  return "LaunchIncrease"

    # Primary monitor window count
    if key == ord(','):  return "PrimaryDecrease"
    if key == ord('.'):  return "PrimaryIncrease"
    if key == ord(')'):  return "PrimaryReset"     # Shift+0

    # Reset
    if key == ord('0'):  return "Reset"

    return None


# Parameter adjustment deltas -- maps action names to (shader_param, delta) tuples.
# Matches Windows ControlPanel.HandleKey() deltas exactly.
PARAM_DELTAS = {
    "SpeedDecrease":   ("RAIN_SPEED",    -0.1),
    "SpeedIncrease":   ("RAIN_SPEED",     0.1),
    "GlowDecrease":   ("GLOW_STRENGTH", -0.1),
    "GlowIncrease":   ("GLOW_STRENGTH",  0.1),
    "WidthDecrease":   ("CHAR_WIDTH",    -1.0),
    "WidthIncrease":   ("CHAR_WIDTH",     1.0),
    "TrailDecrease":   ("TRAIL_POWER",   -0.5),
    "TrailIncrease":   ("TRAIL_POWER",    0.5),
    "DensityDecrease": ("RAIN_DENSITY",  -0.1),
    "DensityIncrease": ("RAIN_DENSITY",   0.1),
    "RedDecrease":     ("RAIN_R",        -0.05),
    "RedIncrease":     ("RAIN_R",         0.05),
    "GreenDecrease":   ("RAIN_G",        -0.05),
    "GreenIncrease":   ("RAIN_G",         0.05),
    "BlueDecrease":    ("RAIN_B",        -0.05),
    "BlueIncrease":    ("RAIN_B",         0.05),
}
