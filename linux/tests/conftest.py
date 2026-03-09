"""Shared test fixtures for shader_service tests."""
import os
import sys
import pytest


# ---------------------------------------------------------------------------
# Guard against module poisoning across test files.
#
# Some test files (test_redpill_tui, test_layout_controls, test_control_panel_polish)
# replace shader_service functions with MagicMock or inject a fake module into
# sys.modules.  This fixture ensures the real shader_service module and its
# original attributes are restored before each test so later test files
# (test_shader_service, test_hotkey_dispatch, etc.) are not affected.
# ---------------------------------------------------------------------------

# Ensure linux/ is on path so we can import the real shader_service
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import shader_service as _real_shader_service
import hotkey_config as _real_hotkey_config
import matrix_keys as _real_matrix_keys

# Snapshot original callable attributes once at import time
_ORIGINAL_ATTRS = {}
for _attr in dir(_real_shader_service):
    _obj = getattr(_real_shader_service, _attr)
    if callable(_obj) and not _attr.startswith("_"):
        _ORIGINAL_ATTRS[_attr] = _obj

_HOTKEY_CONFIG_ATTRS = {}
for _attr in dir(_real_hotkey_config):
    _obj = getattr(_real_hotkey_config, _attr)
    if callable(_obj) and not _attr.startswith("_"):
        _HOTKEY_CONFIG_ATTRS[_attr] = _obj

_MATRIX_KEYS_ATTRS = {}
for _attr in dir(_real_matrix_keys):
    _obj = getattr(_real_matrix_keys, _attr)
    if callable(_obj) and not _attr.startswith("_"):
        _MATRIX_KEYS_ATTRS[_attr] = _obj


@pytest.fixture(autouse=True)
def _restore_shader_service():
    """Restore the real shader_service and hotkey_config modules after each test."""
    yield
    # Ensure sys.modules points to the real modules
    sys.modules["shader_service"] = _real_shader_service
    sys.modules["hotkey_config"] = _real_hotkey_config
    # Restore any functions that were replaced with mocks
    for attr, original in _ORIGINAL_ATTRS.items():
        setattr(_real_shader_service, attr, original)
    for attr, original in _HOTKEY_CONFIG_ATTRS.items():
        setattr(_real_hotkey_config, attr, original)
    sys.modules["matrix_keys"] = _real_matrix_keys
    for attr, original in _MATRIX_KEYS_ATTRS.items():
        setattr(_real_matrix_keys, attr, original)


SAMPLE_SHADER = """\
// MATRIX SHADER - Classic Green (Ghostty / Shadertoy API)
// Ported from HLSL Windows Terminal version

#define RAIN_R         0.0
#define RAIN_G         1.0
#define RAIN_B         0.3
#define RAIN_SPEED     0.8
#define GLOW_STRENGTH  0.8
#define FONT_SCALE     1.0
#define CHAR_WIDTH     10.0
#define TRAIL_POWER    8.0
#define RAIN_DENSITY   0.4
#define SHOW_L1        1.0
#define SHOW_L2        1.0
#define SHOW_L3        1.0
// Per-pixel transparency: background-opacity=0 + alpha from content

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
"""


@pytest.fixture
def shader_content():
    """Return sample shader content with known #define values."""
    return SAMPLE_SHADER


@pytest.fixture
def tmp_shader_file(tmp_path, shader_content):
    """Create a temporary shader file and return its path."""
    shader_path = tmp_path / "matrix-1.glsl"
    shader_path.write_text(shader_content)
    return str(shader_path)


@pytest.fixture
def tmp_slot_dir(tmp_path):
    """Create a temporary directory to use as SLOT_SHADER_DIR."""
    slot_dir = tmp_path / "shaders"
    slot_dir.mkdir()
    return str(slot_dir)


@pytest.fixture
def mock_busctl_output():
    """Sample busctl --user list output with ghostty entries."""
    return """\
NAME                              PID PROCESS         USER             CONNECTION    UNIT                      SESSION DESCRIPTION
:1.0                                1 systemd         neo              -             -                         -       -
:1.118                           4016 ghostty         neo              :1.118        app-ghostty-matrix-1.scope -       -
:1.119                           4070 ghostty         neo              :1.119        app-ghostty-matrix-2.scope -       -
:1.120                           4139 ghostty         neo              :1.120        app-ghostty-matrix-3.scope -       -
:1.50                            1234 firefox         neo              :1.50         app-firefox.scope          -       -
"""
