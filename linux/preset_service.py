"""Preset CRUD operations with JSON file storage.

Persists and retrieves shader configurations as individual JSON files
in ~/.config/matrix-shader/presets/.

Consumed by: TUI (Phase 2), CLI tools (Phase 3).
Dependencies: Python 3 stdlib only (json, os, tempfile, re, logging).
"""

import json
import logging
import os
import re
import tempfile
from datetime import datetime, timezone

from shader_service import PARAM_DEFAULTS

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PRESETS_DIR = os.path.expanduser("~/.config/matrix-shader/presets")


# ---------------------------------------------------------------------------
# Name sanitization
# ---------------------------------------------------------------------------

def sanitize_name(name: str) -> str:
    """Sanitize a preset name for use as a filename.

    - Strips leading/trailing whitespace
    - Lowercases
    - Replaces spaces with dashes
    - Removes non-alphanumeric characters (except dashes)
    - Collapses multiple dashes to one
    - Strips leading/trailing dashes

    Args:
        name: Raw preset name from user input.

    Returns:
        Sanitized name suitable for use as a filename stem.

    Raises:
        ValueError: If name is empty or reduces to nothing after sanitization.
    """
    if not name or not name.strip():
        raise ValueError("Preset name cannot be empty")

    result = name.strip().lower()
    result = result.replace(" ", "-")
    result = re.sub(r"[^a-z0-9-]", "", result)
    result = re.sub(r"-+", "-", result)
    result = result.strip("-")

    if not result:
        raise ValueError(f"Preset name '{name}' contains no valid characters")

    return result


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

def save_preset(name: str, params: dict, presets_dir: str = None) -> str:
    """Save a preset as a JSON file.

    Creates the presets directory if it does not exist. Fills missing
    parameters from PARAM_DEFAULTS and drops unknown parameters.
    Overwrites if a preset with the same sanitized name already exists.
    Uses atomic write (tempfile + os.replace) to prevent partial writes.

    Args:
        name: Preset name (will be sanitized).
        params: Dict of shader parameter name -> float value.
            May be partial; missing params filled from PARAM_DEFAULTS.
            Unknown params are silently dropped.
        presets_dir: Directory for preset files. Defaults to PRESETS_DIR.

    Returns:
        Path to the saved preset file.
    """
    if presets_dir is None:
        presets_dir = PRESETS_DIR

    sanitized = sanitize_name(name)

    # Build full params: start from defaults, overlay known params
    full_params = dict(PARAM_DEFAULTS)
    for key, value in params.items():
        if key in PARAM_DEFAULTS:
            full_params[key] = value

    data = {
        "name": sanitized,
        "params": full_params,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "version": 1,
    }

    os.makedirs(presets_dir, exist_ok=True)

    path = os.path.join(presets_dir, f"{sanitized}.json")
    content = json.dumps(data, indent=2) + "\n"

    # Atomic write
    fd, tmp_path = tempfile.mkstemp(dir=presets_dir, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

    return path


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

def load_preset(name: str, presets_dir: str = None) -> dict:
    """Load a preset's shader parameters from its JSON file.

    Looks up by sanitized name, so load_preset("Night Mode") finds
    night-mode.json.

    Args:
        name: Preset name (will be sanitized for lookup).
        presets_dir: Directory for preset files. Defaults to PRESETS_DIR.

    Returns:
        Dict of all 11 shader parameter name -> float value.

    Raises:
        FileNotFoundError: If no preset with that name exists.
        ValueError: If the JSON file is corrupt.
    """
    if presets_dir is None:
        presets_dir = PRESETS_DIR

    sanitized = sanitize_name(name)
    path = os.path.join(presets_dir, f"{sanitized}.json")

    if not os.path.isfile(path):
        raise FileNotFoundError(f"Preset '{sanitized}' not found at {path}")

    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, ValueError) as e:
        raise ValueError(f"Corrupt preset file '{sanitized}': {e}") from e

    return data["params"]


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

def list_presets(presets_dir: str = None) -> list:
    """List all saved presets with metadata.

    Returns a sorted list of preset info dicts. Ignores non-.json files
    and skips corrupt JSON files with a warning.

    Args:
        presets_dir: Directory for preset files. Defaults to PRESETS_DIR.

    Returns:
        List of dicts, each with keys:
            - name (str): Preset name
            - filename (str): Filename on disk
            - color (tuple): (r, g, b) from RAIN_R/G/B params
            - saved_at (str): ISO 8601 timestamp
        Sorted alphabetically by name. Empty list if no presets.
    """
    if presets_dir is None:
        presets_dir = PRESETS_DIR

    if not os.path.isdir(presets_dir):
        return []

    presets = []
    for filename in os.listdir(presets_dir):
        if not filename.endswith(".json"):
            continue

        path = os.path.join(presets_dir, filename)
        try:
            with open(path) as f:
                data = json.load(f)
        except (json.JSONDecodeError, ValueError, OSError) as e:
            logger.warning("Skipping corrupt preset file %s: %s", filename, e)
            continue

        params = data.get("params", {})
        presets.append({
            "name": data.get("name", filename[:-5]),
            "filename": filename,
            "color": (
                params.get("RAIN_R", 0.0),
                params.get("RAIN_G", 1.0),
                params.get("RAIN_B", 0.3),
            ),
            "saved_at": data.get("saved_at"),
        })

    presets.sort(key=lambda p: p["name"])
    return presets


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

def delete_preset(name: str, presets_dir: str = None) -> None:
    """Delete a preset's JSON file.

    Looks up by sanitized name, so delete_preset("Night Mode") removes
    night-mode.json.

    Args:
        name: Preset name (will be sanitized for lookup).
        presets_dir: Directory for preset files. Defaults to PRESETS_DIR.

    Raises:
        FileNotFoundError: If no preset with that name exists.
    """
    if presets_dir is None:
        presets_dir = PRESETS_DIR

    sanitized = sanitize_name(name)
    path = os.path.join(presets_dir, f"{sanitized}.json")

    if not os.path.isfile(path):
        raise FileNotFoundError(f"Preset '{sanitized}' not found at {path}")

    os.remove(path)
