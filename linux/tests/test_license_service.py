"""Tests for license_service.py and machine_fingerprint.py."""

import hashlib
import hmac
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
    validate_key,
    _compute_signature,
    _to_base36,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

DEV_SECRET = b"DEV-PLACEHOLDER-NOT-FOR-PRODUCTION"


def _make_valid_key(secret=DEV_SECRET):
    """Generate a valid key using the given secret."""
    # Use a known payload
    g1, g2, g3 = "AAAA", "BBBB", "CCCC"
    payload = f"REDPILL-{g1}-{g2}-{g3}"
    h = hmac.new(secret, payload.encode("utf-8"), hashlib.sha256).digest()
    base36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    sig = "".join(base36[h[i] % 36] for i in range(4))
    return f"{payload}-{sig}"


@pytest.fixture(autouse=True)
def _reset_secret():
    """Reset cached secret between tests."""
    license_service._PRODUCT_SECRET = None
    yield
    license_service._PRODUCT_SECRET = None


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
# ToBase36
# ---------------------------------------------------------------------------

class TestToBase36:
    def test_basic(self):
        data = bytes([0, 1, 35, 36, 37])
        result = _to_base36(data, 0, 5)
        assert result[0] == "0"  # 0 % 36 = 0
        assert result[1] == "1"  # 1 % 36 = 1
        assert result[2] == "Z"  # 35 % 36 = 35
        assert result[3] == "0"  # 36 % 36 = 0
        assert result[4] == "1"  # 37 % 36 = 1

    def test_offset(self):
        data = bytes([99, 99, 0, 1])
        result = _to_base36(data, 2, 2)
        assert result == "01"

    def test_out_of_bounds_pads_zero(self):
        data = bytes([5])
        result = _to_base36(data, 0, 3)
        assert result[0] == "5"
        assert result[1] == "0"  # out of bounds
        assert result[2] == "0"


# ---------------------------------------------------------------------------
# ValidateKey
# ---------------------------------------------------------------------------

class TestValidateKey:
    def test_valid_key_accepted(self):
        key = _make_valid_key()
        # Force dev secret
        license_service._PRODUCT_SECRET = DEV_SECRET
        assert validate_key(key) is True

    def test_empty_rejected(self):
        assert validate_key("") is False
        assert validate_key(None) is False
        assert validate_key("   ") is False

    def test_wrong_prefix_rejected(self):
        assert validate_key("BLUEPILL-AAAA-BBBB-CCCC-DDDD") is False

    def test_wrong_part_count_rejected(self):
        assert validate_key("REDPILL-AAAA-BBBB") is False
        assert validate_key("REDPILL-AAAA-BBBB-CCCC-DDDD-EEEE") is False

    def test_non_alnum_rejected(self):
        assert validate_key("REDPILL-AA!A-BBBB-CCCC-DDDD") is False

    def test_wrong_length_group_rejected(self):
        assert validate_key("REDPILL-AAA-BBBB-CCCC-DDDD") is False
        assert validate_key("REDPILL-AAAAA-BBBB-CCCC-DDDD") is False

    def test_wrong_signature_rejected(self):
        license_service._PRODUCT_SECRET = DEV_SECRET
        assert validate_key("REDPILL-AAAA-BBBB-CCCC-ZZZZ") is False

    def test_case_insensitive(self):
        key = _make_valid_key()
        license_service._PRODUCT_SECRET = DEV_SECRET
        assert validate_key(key.lower()) is True

    def test_whitespace_stripped(self):
        key = _make_valid_key()
        license_service._PRODUCT_SECRET = DEV_SECRET
        assert validate_key(f"  {key}  ") is True


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

    def test_valid_key_is_licensed(self, tmp_path):
        license_service._PRODUCT_SECRET = DEV_SECRET
        key = _make_valid_key()
        keyfile = tmp_path / "license.key"
        keyfile.write_text(key)
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert is_licensed() is True

    def test_invalid_key_not_licensed(self, tmp_path):
        license_service._PRODUCT_SECRET = DEV_SECRET
        keyfile = tmp_path / "license.key"
        keyfile.write_text("REDPILL-AAAA-BBBB-CCCC-ZZZZ")
        with patch.object(license_service, "LICENSE_PATH", str(keyfile)):
            assert is_licensed() is False


# ---------------------------------------------------------------------------
# Activate
# ---------------------------------------------------------------------------

class TestActivate:
    def test_invalid_key_returns_invalid(self):
        license_service._PRODUCT_SECRET = DEV_SECRET
        result = activate("REDPILL-BAD-KEY")
        assert result == ActivationResult.INVALID_KEY

    def test_valid_key_saves_to_disk(self, tmp_path):
        license_service._PRODUCT_SECRET = DEV_SECRET
        key = _make_valid_key()
        license_dir = tmp_path / "config"
        license_path = license_dir / "license.key"
        with patch.object(license_service, "LICENSE_DIR", str(license_dir)), \
             patch.object(license_service, "LICENSE_PATH", str(license_path)), \
             patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.SUCCESS):
            result = activate(key)
            assert result == ActivationResult.SUCCESS
            assert license_path.read_text() == key.upper()

    def test_activation_limit_exceeded(self, tmp_path):
        license_service._PRODUCT_SECRET = DEV_SECRET
        key = _make_valid_key()
        with patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.ACTIVATION_LIMIT_EXCEEDED):
            result = activate(key)
            assert result == ActivationResult.ACTIVATION_LIMIT_EXCEEDED

    def test_save_failure(self, tmp_path):
        license_service._PRODUCT_SECRET = DEV_SECRET
        key = _make_valid_key()
        with patch.object(license_service, "LICENSE_DIR", "/dev/null/impossible"), \
             patch.object(license_service, "LICENSE_PATH", "/dev/null/impossible/key"), \
             patch.object(license_service, "_check_server_activation",
                          return_value=ActivationResult.SUCCESS):
            result = activate(key)
            assert result == ActivationResult.SAVE_FAILED


# ---------------------------------------------------------------------------
# Server activation
# ---------------------------------------------------------------------------

class TestServerActivation:
    def test_403_returns_limit_exceeded(self):
        import urllib.error
        err = urllib.error.HTTPError(
            "url", 403, "Forbidden", {}, None
        )
        with patch("urllib.request.urlopen", side_effect=err):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.ACTIVATION_LIMIT_EXCEEDED

    def test_500_returns_success(self):
        import urllib.error
        err = urllib.error.HTTPError(
            "url", 500, "Server Error", {}, None
        )
        with patch("urllib.request.urlopen", side_effect=err):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.SUCCESS

    def test_network_error_returns_success(self):
        with patch("urllib.request.urlopen", side_effect=OSError("no network")):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.SUCCESS

    def test_200_returns_success(self):
        mock_response = MagicMock()
        mock_response.status = 200
        with patch("urllib.request.urlopen", return_value=mock_response):
            result = license_service._check_server_activation("KEY")
            assert result == ActivationResult.SUCCESS


# ---------------------------------------------------------------------------
# Secret loading
# ---------------------------------------------------------------------------

class TestSecretLoading:
    def test_loads_from_embedded_module(self):
        """_license_secret.py import path (build-time embed)."""
        license_service._PRODUCT_SECRET = None
        fake_module = MagicMock()
        fake_module.SECRET = "MY-PRODUCTION-SECRET"
        with patch.dict("sys.modules", {"_license_secret": fake_module}):
            secret = license_service._load_secret()
            assert secret == b"MY-PRODUCTION-SECRET"

    def test_fallback_to_dev_placeholder(self):
        license_service._PRODUCT_SECRET = None
        # No embedded module, no key file → dev placeholder
        with patch.dict("sys.modules", {"_license_secret": None}):
            secret = license_service._load_secret()
            assert secret == b"DEV-PLACEHOLDER-NOT-FOR-PRODUCTION"

    def test_caches_result(self):
        license_service._PRODUCT_SECRET = b"cached"
        secret = license_service._load_secret()
        assert secret == b"cached"


# ---------------------------------------------------------------------------
# Cross-platform key compatibility
# ---------------------------------------------------------------------------

class TestCrossPlatformCompat:
    """Keys generated by C# must validate in Python and vice versa."""

    def test_same_secret_same_signature(self):
        """Verify our HMAC + base36 matches the C# implementation."""
        license_service._PRODUCT_SECRET = b"test-secret"
        payload = "REDPILL-AAAA-BBBB-CCCC"
        sig = _compute_signature(payload)
        assert len(sig) == 4
        assert all(c in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" for c in sig)

        # Compute manually to verify
        h = hmac.new(b"test-secret", payload.encode("utf-8"), hashlib.sha256).digest()
        base36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        expected = "".join(base36[h[i] % 36] for i in range(4))
        assert sig == expected

    def test_key_roundtrip(self):
        """Generate and validate a key."""
        license_service._PRODUCT_SECRET = b"roundtrip-secret"
        # Build a key manually (mimicking C# GenerateKey)
        seed_hash = hashlib.sha256(b"test-seed").digest()
        g1 = _to_base36(seed_hash, 0, 4)
        g2 = _to_base36(seed_hash, 4, 4)
        g3 = _to_base36(seed_hash, 8, 4)
        payload = f"REDPILL-{g1}-{g2}-{g3}"
        sig = _compute_signature(payload)
        key = f"{payload}-{sig}"

        assert validate_key(key) is True
        # Tamper and verify rejection
        assert validate_key(key[:-1] + "Z") is False


# ---------------------------------------------------------------------------
# TUI gating
# ---------------------------------------------------------------------------

class TestTUIGating:
    def test_main_exits_if_unlicensed(self, tmp_path, monkeypatch):
        """main() should show purchase prompt and exit without launching TUI."""
        license_service._PRODUCT_SECRET = DEV_SECRET
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
        license_service._PRODUCT_SECRET = DEV_SECRET
        key = _make_valid_key()
        license_dir = tmp_path / "config"
        license_path = license_dir / "license.key"
        monkeypatch.setattr(license_service, "LICENSE_DIR", str(license_dir))
        monkeypatch.setattr(license_service, "LICENSE_PATH", str(license_path))
        monkeypatch.setattr("sys.argv", ["redpill_tui.py"])
        monkeypatch.setattr("builtins.input", lambda: key)

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
        license_service._PRODUCT_SECRET = DEV_SECRET
        key = _make_valid_key()
        license_dir = tmp_path / "config"
        license_path = license_dir / "license.key"
        monkeypatch.setattr(license_service, "LICENSE_DIR", str(license_dir))
        monkeypatch.setattr(license_service, "LICENSE_PATH", str(license_path))
        monkeypatch.setattr("sys.argv", ["redpill_tui.py", "--activate", key])

        monkeypatch.setattr(license_service, "_check_server_activation",
                            lambda k: ActivationResult.SUCCESS)

        from redpill_tui import main
        with pytest.raises(SystemExit) as exc_info:
            main()
        assert exc_info.value.code == 0
        assert license_path.read_text() == key.upper()
