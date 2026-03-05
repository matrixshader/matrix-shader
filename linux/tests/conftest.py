"""Shared test fixtures for shader_service tests."""
import os
import pytest


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
