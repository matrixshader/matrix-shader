"""Deterministic machine fingerprint for license activation tracking.

Port of MatrixShader.Core/Services/MachineFingerprint.cs.
SHA256 of (hostname | username | OS version), truncated to 16 hex chars.
"""

import hashlib
import os
import platform

_cached = None


def get():
    """Return a 16-char hex fingerprint for this machine."""
    global _cached
    if _cached is not None:
        return _cached

    raw = "|".join([
        platform.node(),           # hostname (Environment.MachineName)
        os.getenv("USER", os.getenv("USERNAME", "")),  # Environment.UserName
        platform.platform(),       # Environment.OSVersion.ToString()
    ])

    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    _cached = digest[:16]
    return _cached
