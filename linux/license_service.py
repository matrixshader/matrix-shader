"""License validation with server-side activation tracking.

Key format: REDPILL-XXXX-XXXX-XXXX-XXXX

Design philosophy: honest people pay, pirates never would have.
Don't punish paying customers with aggressive DRM.
First activation requires server verification to enforce machine limits.
After activation, license is fully offline — no phone-home ever.

Security: HMAC validation is server-only. The client never sees the
signing secret. The activation server is the sole authority on whether
a key is valid.
"""

import os
import sys
from enum import Enum

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import machine_fingerprint


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
    SERVER_UNREACHABLE = "server_unreachable"
    SAVE_FAILED = "save_failed"


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

def _looks_like_key(key):
    """Check if a string has valid license key format (no HMAC check).

    Returns True if key format is REDPILL-XXXX-XXXX-XXXX-XXXX with
    alphanumeric groups of 4 characters each.
    """
    if not key or not key.strip():
        return False

    key = key.strip().upper()
    parts = key.split("-")

    if len(parts) != 5:
        return False
    if parts[0] != "REDPILL":
        return False

    for i in range(1, 5):
        if len(parts[i]) != 4:
            return False
        if not parts[i].isalnum():
            return False

    return True


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
    """Check if a valid Red Pill license is installed.

    After server-verified activation, the key file on disk is proof
    of activation. No client-side HMAC check — the server already
    validated the key during activation.
    """
    key = get_installed_key()
    return key is not None and _looks_like_key(key)


def _check_server_activation(key):
    """Call /api/validate to register activation with the server.

    The server performs HMAC validation and tracks machine activations.
    Returns SUCCESS if server confirms, ACTIVATION_LIMIT_EXCEEDED if over limit,
    INVALID_KEY if HMAC fails, or SERVER_UNREACHABLE if the server cannot be contacted.
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
                try:
                    body = json.loads(e.read().decode())
                    if body.get("error") == "activation_limit":
                        return ActivationResult.ACTIVATION_LIMIT_EXCEEDED
                except Exception:
                    pass
                return ActivationResult.INVALID_KEY
            # Server error (500, 503, etc.) — don't let activation bypass the check
            return ActivationResult.SERVER_UNREACHABLE
        return ActivationResult.SUCCESS

    except Exception:
        # Network error, timeout, DNS failure — require connectivity for activation
        return ActivationResult.SERVER_UNREACHABLE


def activate(key):
    """Activate a license key via server validation.

    Checks key format locally (fast reject), then sends to server for
    HMAC verification and activation tracking. Saves key on success.
    Returns ActivationResult.
    """
    if not _looks_like_key(key):
        return ActivationResult.INVALID_KEY

    # Server-side activation check (required — no offline bypass)
    server_result = _check_server_activation(key)
    if server_result != ActivationResult.SUCCESS:
        return server_result

    try:
        os.makedirs(LICENSE_DIR, exist_ok=True)
        with open(LICENSE_PATH, "w") as f:
            f.write(key.strip().upper())
        return ActivationResult.SUCCESS
    except OSError:
        return ActivationResult.SAVE_FAILED
