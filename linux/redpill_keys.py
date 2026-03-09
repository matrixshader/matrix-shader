"""Key-to-action mapping for the Red Pill TUI control panel.

Direct port of MatrixShader.Cli.Redpill/KeyHandler.cs.
Maps curses getch() return values to action strings.

Shift+letter combinations detected via uppercase char codes
BEFORE lowercase fallback -- this is critical for distinguishing
Shift+L (LayoutCycle) from lowercase l (OpacityIncrease).
"""


def process_key(key):
    """Map a curses getch() key code to an action string.

    Args:
        key: Integer key code from curses stdscr.getch().

    Returns:
        Action string, or None for unrecognized keys.
    """
    # Special keys
    if key == 9:    return "Tab"
    if key == 10:   return "Launch"
    if key == 27:   return "Quit"
    if key == 353:  return "ShiftTab"       # curses KEY_BTAB

    # Shift combinations (uppercase letters) -- check BEFORE lowercase
    if key == ord('L'):  return "LayoutCycle"
    if key == ord('S'):  return "SnapbackSave"
    if key == ord('R'):  return "SnapbackRestore"
    if key == ord('G'):  return "GlitchToggle"
    if key == ord('H'):  return "HotkeyConfig"
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
