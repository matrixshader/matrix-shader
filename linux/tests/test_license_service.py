"""Tests for license_service.py and machine_fingerprint.py."""

import hashlib
import os
import sys
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import machine_fingerprint
import license_service
from license_service import (
    ActivationResult,
    activate,
    get_installed_key,
    is_licensed,
    _looks_like_key,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A format-valid key (server would check HMAC; client only checks format)
VALID_FORMAT_KEY = "REDPILL-AAAA-BBBB-CCCC-DDDD"


@pytest.fixture(autouse=True)
def _reset_fingerprint():
    """Reset cached fingerprint between tests."""
    machine_fingerprint._cached = None
    yield
    machine_fingerprint._cached = None


# ---------------------------------------------------------------------------
# MachineFingerprint
# ---------------------------------------------------------------------------

class TestMachineFingerprint:
    def test_returns_16_hex_chars(self):
        fp = machine_fingerprint.get()
        assert len(fp) == 16
        assert all(c in "0123456789abcdef" for c in fp)

    def test_deterministic(self):
        fp1 = machine_fingerprint.get()
        machine_fingerprint._cached = None
        fp2 = machine_fingerprint.get()
        assert fp1 == fp2

    def test_uses_hostname_user_platform(self):
        with patch("machine_fingerprint.platform") as mock_plat, \
             patch.dict(os.environ, {"USER": "neo"}):
            mock_plat.node.return_value = "nebuchadnezzar"
            mock_plat.platform.return_value = "Linux-6.1"
            machine_fingerprint._cached = None
            fp = machine_fingerprint.get()

            raw = "nebuchadnezzar|neo|Linux-6.1"
            expected = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
            assert fp == expected


# ---------------------------------------------------------------------------
# _looks_like_key (format check only, no HMAC)
# ---------------------------------------------------------------------------

class TestLooksLikeKey:
    def test_valid_format_accepted(self):
        assert _looks_like_key("REDPILL-AAAA-BBBB-CCCC-DDDD") is True

    def test_empty_rejected(self):
        assert _looks_like_key("") is False
        assert _looks_like_key(None) is False
        assert _looks_like_key("   ") is False

    def test_wrong_prefix_rejected(self):
        assert _looks_like_key("BLUEPILL-AAAA-BBBB-CCCC-DDDD") is False

    def test_wrong_part_count_rejected(self):
        assert _looks_like_key("REDPILL-AAAA-BBBB") is False
        assert _looks_like_key("REDPILL-AAAA-BBBB-CCCC-DDDD-EEEE") is False

    def test_non_alnum_rejected(self):
        assert _looks_like_key("REDPILL-AA!A-BBBB-CCCC-DDDD") is False

    def test_wrong_length_group_rejected(self):
        assert _looks_like_key("REDPILL-AAA-BBBB-CCCC-DDDD") is False
        assert _looks_like_key("REDPILL-AAAAA-BBBB-CCCC-DDDD") is False

    def test_case_insensitive(self):
        assert _looks_like_key("redpill-aaaa-bbbb-cccc-dddd") is True

    def test_whitespace_stripped(self):
        assert _looks_like_key("  REDPILL-AAAA-BBBB-CCCC-DDDD  ") is True


# ---------------------------------------------------------------------------
# GetInstalledKey
# ---------------------------------------------------------------------------

class TestGetInstalledKey:
    def test_no_file_returns_none(self, tmp_path):
        with patch.object(license_service, "LICENSE_PATH", str(tmp_path / "nope.key")):
            assert get_installed_key() is None

    def test_reads_key(self, tmp_path):
        keyfile = tmp_path / "license.key"
        keyfile.write_text("REDPILL-AAAA-BBBB-CCCC-DDDD")
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert get_installed_key() == "REDPILL-AAAA-BBBB-CCCC-DDDD"

    def test_empty_file_returns_none(self, tmp_path):
        keyfile = tmp_path / "license.key"
        keyfile.write_text("   ")
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert get_installed_key() is None


# ---------------------------------------------------------------------------
# IsLicensed
# ---------------------------------------------------------------------------

class TestIsLicensed:
    def test_no_key_not_licensed(self, tmp_path):
        with patch.object(license_service, "LICENSE_PATH", str(tmp_path / "nope.key")):
            assert is_licensed() is False

    def test_valid_format_key_is_licensed(self, tmp_path):
        keyfile = tmp_path / "license.key"
        keyfile.write_text(VALID_FORMAT_KEY)
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert is_licensed() is True

    def test_garbage_key_not_licensed(self, tmp_path):
        keyfile = tmp_path / "license.key"
        keyfile.write_text("not-a-valid-key")
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert is_licensed() is False

    def test_empty_key_not_licensed(self, tmp_path):
        keyfile = tmp_path / "license.key"
        keyfile.write_text("")
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert is_licensed() is False


# ---------------------------------------------------------------------------
# Activate
# ---------------------------------------------------------------------------

class TestActivate:
    def test_bad_format_returns_invalid(self):
        result = activate("REDPILL-BAD-KEY")
        assert result == ActivationResult.INVALID_KEY

    def test_valid_key_saves_to_disk(self, tmp_path):
        license_dir = tmp_path / "config"
        license_path = license_dir / "license.key"
        with patch.object(license_service, "LICENSE_DIR", str(license_dir)), \
             patch.object(license_service, "LICENSE_PATH", str(license_path)), \
             patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.SUCCESS):
            result = activate(VALID_FORMAT_KEY)
            assert result == ActivationResult.SUCCESS
            assert license_path.read_text() == VALID_FORMAT_KEY.upper()

    def test_activation_limit_exceeded(self, tmp_path):
        with patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.ACTIVATION_LIMIT_EXCEEDED):
            result = activate(VALID_FORMAT_KEY)
            assert result == ActivationResult.ACTIVATION_LIMIT_EXCEEDED

    def test_server_unreachable(self):
        with patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.SERVER_UNREACHABLE):
            result = activate(VALID_FORMAT_KEY)
            assert result == ActivationResult.SERVER_UNREACHABLE

    def test_save_failure(self, tmp_path):
        with patch.object(license_service, "LICENSE_DIR", "/dev/null/impossible"), \
             patch.object(license_service, "LICENSE_PATH", "/dev/null/impossible/key"), \
             patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.SUCCESS):
            result = activate(VALID_FORMAT_KEY)
            assert result == ActivationResult.SAVE_FAILED


# ---------------------------------------------------------------------------
# Server activation
# ---------------------------------------------------------------------------

class TestServerActivation:
    def test_403_activation_limit_exceeded(self):
        import io
        import urllib.error
        body = io.BytesIO(b'{"error": "activation_limit"}')
        err = urllib.error.HTTPError(
            "url", 403, "Forbidden", {}, body
        )
        with patch("urllib.request.urlopen", side_effect=err):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.ACTIVATION_LIMIT_EXCEEDED

    def test_403_invalid_key(self):
        import io
        import urllib.error
        body = io.BytesIO(b'{"error": "invalid_key"}')
        err = urllib.error.HTTPError(
            "url", 403, "Forbidden", {}, body
        )
        with patch("urllib.request.urlopen", side_effect=err):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.INVALID_KEY

    def test_500_returns_server_unreachable(self):
        import urllib.error
        err = urllib.error.HTTPError(
            "url", 500, "Server Error", {}, None
        )
        with patch("urllib.request.urlopen", side_effect=err):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.SERVER_UNREACHABLE

    def test_network_error_returns_server_unreachable(self):
        with patch("urllib.request.urlopen", side_effect=OSError("no network")):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.SERVER_UNREACHABLE

    def test_200_returns_success(self):
        mock_response = MagicMock()
        mock_response.status = 200
        with patch("urllib.request.urlopen", return_value=mock_response):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.SUCCESS


# ---------------------------------------------------------------------------
# TUI gating
# ---------------------------------------------------------------------------

class TestTUIGating:
    def test_main_exits_if_unlicensed(self, tmp_path, monkeypatch):
        """main() should show purchase prompt and exit without launching TUI."""
        monkeypatch.setattr(license_service, "LICENSE_PATH", str(tmp_path / "nope.key"))
        monkeypatch.setattr("sys.argv", ["redpill_tui.py"])

        from redpill_tui import main
        # Simulate user pressing Enter (empty input)
        monkeypatch.setattr("builtins.input", lambda: "")

        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 0

    def test_main_activates_inline(self, tmp_path, monkeypatch):
        """main() should accept key paste and activate."""
        license_dir = tmp_path / "config"
        license_path = license_dir / "license.key"
        monkeypatch.setattr(license_service, "LICENSE_DIR", str(license_dir))
        monkeypatch.setattr(license_service, "LICENSE_PATH", str(license_path))
        monkeypatch.setattr("sys.argv", ["redpill_tui.py"])
        monkeypatch.setattr("builtins.input", lambda: VALID_FORMAT_KEY)

        # Mock server check
        monkeypatch.setattr(license_service, "_check_server_activation",
                            lambda k: ActivationResult.SUCCESS)

        from redpill_tui import main
        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 0
        assert license_path.exists()

    def test_activate_flag(self, tmp_path, monkeypatch):
        """--activate KEY should activate and exit."""
        license_dir = tmp_path / "config"
        license_path = license_dir / "license.key"
        monkeypatch.setattr(license_service, "LICENSE_DIR", str(license_dir))
        monkeypatch.setattr(license_service, "LICENSE_PATH", str(license_path))
        monkeypatch.setattr("sys.argv", ["redpill_tui.py", "--activate", VALID_FORMAT_KEY])

        monkeypatch.setattr(license_service, "_check_server_activation",
                            lambda k: ActivationResult.SUCCESS)

        from redpill_tui import main
        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 0
        assert license_path.read_text() == VALID_FORMAT_KEY.upper()
