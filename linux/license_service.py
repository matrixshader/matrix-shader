"""Offline license validation using HMAC-SHA256 with server-side activation tracking.

Port of MatrixShader.Core/Services/LicenseService.cs.

Key format: REDPILL-XXXX-XXXX-XXXX-XXXX where the last group is a truncated HMAC
of the first three groups, keyed with an embedded product secret.

Design philosophy: honest people pay, pirates never would have.
Don't punish paying customers with aggressive DRM.
Server check is best-effort — if unreachable, activation still succeeds.
"""

import hashlib
import hmac
import os
import sys
from enum import Enum
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import machine_fingerprint

# ---------------------------------------------------------------------------
# Product secret — loaded from gitignored file, matching C# build-time embed.
# ---------------------------------------------------------------------------

_SECRET_CANDIDATES = [
    # Dev: repo root
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MatrixShader", "license-secret.key"),
    # Installed: alongside this script
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "license-secret.key"),
]

_PRODUCT_SECRET = None

def _load_secret():
    global _PRODUCT_SECRET
    if _PRODUCT_SECRET is not None:
        return _PRODUCT_SECRET
    for path in _SECRET_CANDIDATES:
        try:
            with open(path) as f:
                val = f.read().strip()
                if val:
                    _PRODUCT_SECRET = val.encode("utf-8")
                    return _PRODUCT_SECRET
        except OSError:
            continue
    _PRODUCT_SECRET = b"DEV-PLACEHOLDER-NOT-FOR-PRODUCTION"
    return _PRODUCT_SECRET


# ---------------------------------------------------------------------------
# License storage
# ---------------------------------------------------------------------------

LICENSE_DIR = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "matrix-shader",
)
LICENSE_PATH = os.path.join(LICENSE_DIR, "license.key")

VALIDATE_URL = "https://matrixshader.com/api/validate"
SERVER_TIMEOUT = 8  # seconds


# ---------------------------------------------------------------------------
# ActivationResult enum — mirrors C# ActivationResult
# ---------------------------------------------------------------------------

class ActivationResult(Enum):
    SUCCESS = "success"
    INVALID_KEY = "invalid_key"
    ACTIVATION_LIMIT_EXCEEDED = "activation_limit_exceeded"
    SAVE_FAILED = "save_failed"


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

_BASE36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def _to_base36(data, offset, length):
    """Convert bytes to base36 string, matching C# ToBase36."""
    chars = []
    for i in range(length):
        idx = data[offset + i] % 36 if (offset + i) < len(data) else 0
        chars.append(_BASE36[idx])
    return "".join(chars)


def _compute_signature(payload):
    """HMAC-SHA256 of payload, truncated to 4 base36 chars."""
    secret = _load_secret()
    h = hmac.new(secret, payload.encode("utf-8"), hashlib.sha256).digest()
    return _to_base36(h, 0, 4)


def validate_key(key):
    """Validate a license key format and HMAC signature without saving.

    Returns True if key format is REDPILL-XXXX-XXXX-XXXX-XXXX and HMAC matches.
    """
    if not key or not key.strip():
        return False

    key = key.strip().upper()
    parts = key.split("-")

    if len(parts) != 5:
        return False
    if parts[0] != "REDPILL":
        return False

    # Each group after prefix should be 4 alphanumeric chars
    for i in range(1, 5):
        if len(parts[i]) != 4:
            return False
        if not parts[i].isalnum():
            return False

    # Payload is groups 0-3, signature is group 4
    payload = f"{parts[0]}-{parts[1]}-{parts[2]}-{parts[3]}"
    expected_sig = _compute_signature(payload)

    return parts[4] == expected_sig


def get_installed_key():
    """Get the installed license key, or None if none exists."""
    try:
        if not os.path.exists(LICENSE_PATH):
            return None
        with open(LICENSE_PATH) as f:
            key = f.read().strip()
        return key if key else None
    except OSError:
        return None


def is_licensed():
    """Check if a valid Red Pill license is installed."""
    key = get_installed_key()
    return key is not None and validate_key(key)


def _check_server_activation(key):
    """Call /api/validate to check activation count.

    Returns SUCCESS if server allows (or is unreachable),
    ACTIVATION_LIMIT_EXCEEDED if over limit.
    """
    try:
        import urllib.request
        import urllib.error
        import json

        fingerprint = machine_fingerprint.get()
        normalized = key.strip().upper()
        payload = json.dumps({"key": normalized, "fingerprint": fingerprint})

        req = urllib.request.Request(
            VALIDATE_URL,
            data=payload.encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            urllib.request.urlopen(req, timeout=SERVER_TIMEOUT)
        except urllib.error.HTTPError as e:
            if e.code == 403:
                return ActivationResult.ACTIVATION_LIMIT_EXCEEDED
            # Any other HTTP error = allow activation
        return ActivationResult.SUCCESS

    except Exception:
        # Network error, timeout, DNS failure — graceful degradation
        return ActivationResult.SUCCESS


def activate(key):
    """Validate and activate a license key.

    Performs offline HMAC check, then server activation tracking.
    Returns ActivationResult.
    """
    if not validate_key(key):
        return ActivationResult.INVALID_KEY

    # Server-side activation check (best-effort)
    server_result = _check_server_activation(key)
    if server_result == ActivationResult.ACTIVATION_LIMIT_EXCEEDED:
        return ActivationResult.ACTIVATION_LIMIT_EXCEEDED

    try:
        os.makedirs(LICENSE_DIR, exist_ok=True)
        with open(LICENSE_PATH, "w") as f:
            f.write(key.strip().upper())
        return ActivationResult.SUCCESS
    except OSError:
        return ActivationResult.SAVE_FAILED
