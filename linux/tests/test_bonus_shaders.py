"""Tests for bonus GLSL shader compilation via SPIR-V pipeline.

Verifies that all 7 bonus shaders (6 ports + white room) compile
from GLSL to SPIR-V and cross-compile from SPIR-V to MSL.
"""
import subprocess
import os
import pytest
import tempfile

SHADER_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "shaders-glsl")
GHOSTTY_PREFIX = os.path.expanduser(
    "~/ghostty-build/src/renderer/shaders/shadertoy_prefix.glsl"
)
GLSLANG = "/usr/bin/glslangValidator"
SPIRV_CROSS = "/tmp/SPIRV-Cross/build/spirv-cross"

BONUS_SHADERS = [
    "aurora-borealis-ghostty.glsl",
    "aurora-rain-ghostty.glsl",
    "fireplace-ghostty.glsl",
    "matrix-codevision-ghostty.glsl",
    "matrix-ultra-ghostty.glsl",
    "rain-on-glass-ghostty.glsl",
    "white-room-ghostty.glsl",
]


def _has_glslang():
    return os.path.isfile(GLSLANG) and os.access(GLSLANG, os.X_OK)


def _has_spirv_cross():
    return os.path.isfile(SPIRV_CROSS) and os.access(SPIRV_CROSS, os.X_OK)


def _has_ghostty_prefix():
    return os.path.isfile(GHOSTTY_PREFIX)


def _prepend_prefix(shader_path, output_path):
    """Prepend the Ghostty shadertoy prefix to a shader file."""
    with open(GHOSTTY_PREFIX, "r") as pf:
        prefix = pf.read()
    with open(shader_path, "r") as sf:
        shader = sf.read()
    with open(output_path, "w") as of:
        of.write(prefix)
        of.write(shader)


@pytest.mark.parametrize("shader", BONUS_SHADERS)
def test_shader_file_exists(shader):
    """Each bonus shader file must exist in shaders-glsl/."""
    path = os.path.join(SHADER_DIR, shader)
    assert os.path.isfile(path), f"Shader file missing: {shader}"


@pytest.mark.parametrize("shader", BONUS_SHADERS)
def test_shader_has_main_image(shader):
    """Each shader must have a void mainImage entry point."""
    path = os.path.join(SHADER_DIR, shader)
    with open(path, "r") as f:
        content = f.read()
    assert "void mainImage" in content, f"Missing mainImage in {shader}"


@pytest.mark.parametrize("shader", BONUS_SHADERS)
def test_shader_no_hlsl_syntax(shader):
    """No HLSL-specific syntax should remain in GLSL shaders."""
    path = os.path.join(SHADER_DIR, shader)
    with open(path, "r") as f:
        content = f.read()

    hlsl_patterns = [
        "Texture2D",
        "SamplerState",
        "cbuffer",
        "SV_TARGET",
        "SV_POSITION",
        "TEXCOORD",
    ]
    for pattern in hlsl_patterns:
        assert pattern not in content, (
            f"HLSL syntax '{pattern}' found in {shader}"
        )


@pytest.mark.parametrize("shader", BONUS_SHADERS)
@pytest.mark.skipif(not _has_glslang(), reason="glslangValidator not found")
@pytest.mark.skipif(not _has_ghostty_prefix(), reason="Ghostty prefix not found")
def test_glsl_compiles_to_spirv(shader):
    """Each shader must compile from GLSL to SPIR-V."""
    shader_path = os.path.join(SHADER_DIR, shader)
    assert os.path.isfile(shader_path), f"Shader file missing: {shader}"

    with tempfile.TemporaryDirectory() as tmpdir:
        combined = os.path.join(tmpdir, "test-shader.frag")
        spv_out = os.path.join(tmpdir, "test-shader.spv")

        _prepend_prefix(shader_path, combined)

        result = subprocess.run(
            [GLSLANG, "-V", "--target-env", "opengl", "-S", "frag",
             combined, "-o", spv_out],
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, (
            f"GLSL compilation failed for {shader}:\n{result.stdout}\n{result.stderr}"
        )
        assert os.path.isfile(spv_out), f"SPIR-V output missing for {shader}"


@pytest.mark.parametrize("shader", BONUS_SHADERS)
@pytest.mark.skipif(not _has_glslang(), reason="glslangValidator not found")
@pytest.mark.skipif(not _has_spirv_cross(), reason="spirv-cross not found")
@pytest.mark.skipif(not _has_ghostty_prefix(), reason="Ghostty prefix not found")
def test_spirv_crosscompiles_to_msl(shader):
    """Each shader must cross-compile from SPIR-V to MSL."""
    shader_path = os.path.join(SHADER_DIR, shader)
    assert os.path.isfile(shader_path), f"Shader file missing: {shader}"

    with tempfile.TemporaryDirectory() as tmpdir:
        combined = os.path.join(tmpdir, "test-shader.frag")
        spv_out = os.path.join(tmpdir, "test-shader.spv")

        _prepend_prefix(shader_path, combined)

        # First compile GLSL -> SPIR-V
        result = subprocess.run(
            [GLSLANG, "-V", "--target-env", "opengl", "-S", "frag",
             combined, "-o", spv_out],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, (
            f"GLSL compilation failed for {shader} (prerequisite for MSL test)"
        )

        # Then cross-compile SPIR-V -> MSL
        result = subprocess.run(
            [SPIRV_CROSS, "--msl", spv_out],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, (
            f"MSL cross-compilation failed for {shader}:\n{result.stderr}"
        )
        # Verify output contains MSL code
        assert "using namespace metal" in result.stdout, (
            f"MSL output doesn't look like Metal code for {shader}"
        )
