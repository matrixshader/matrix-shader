"""Tests for state_service.py — state persistence, migration, debounce."""

import json
import os
import sys
import time
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from state_service import (
    DEFAULT_LAYOUT,
    DEFAULT_STATE,
    StateService,
    _ensure_keys,
    _migrate_state,
    load_state,
    save_state,
    snapshot_shader_configs,
)


# ---------------------------------------------------------------------------
# TestLoadSave
# ---------------------------------------------------------------------------

class TestLoadSave:
    def test_load_nonexistent_returns_defaults(self, tmp_path):
        path = str(tmp_path / "missing.json")
        state = load_state(path)
        assert state["active_tab"] == 1
        assert state["shader_configs"] == {}
        assert state["layout"]["mode"] == "pillars"
        assert state["opacity"] == 85
        assert state["last_saved"] is None

    def test_save_then_load_roundtrip(self, tmp_path):
        path = str(tmp_path / "state.json")
        state = {
            "active_tab": 3,
            "shader_configs": {
                "1": {"RAIN_R": 0.5, "RAIN_G": 0.5, "RAIN_B": 0.5},
            },
            "layout": {"mode": "quads", "gap_size": 60},
            "window_slots": {},
            "opacity": 70,
            "last_saved": None,
        }
        save_state(state, path)
        loaded = load_state(path)
        assert loaded["active_tab"] == 3
        assert loaded["shader_configs"]["1"]["RAIN_R"] == 0.5
        assert loaded["layout"]["mode"] == "quads"
        assert loaded["opacity"] == 70
        assert loaded["last_saved"] is not None  # save_state sets it

    def test_save_creates_directories(self, tmp_path):
        path = str(tmp_path / "deep" / "nested" / "state.json")
        save_state(dict(DEFAULT_STATE), path)
        assert os.path.exists(path)

    def test_load_corrupt_json_returns_defaults(self, tmp_path):
        path = str(tmp_path / "state.json")
        with open(path, "w") as f:
            f.write("{{{{not json!!")
        state = load_state(path)
        assert state["active_tab"] == 1
        assert state["shader_configs"] == {}

    def test_save_updates_last_saved_timestamp(self, tmp_path):
        path = str(tmp_path / "state.json")
        state = dict(DEFAULT_STATE)
        assert state["last_saved"] is None
        save_state(state, path)
        assert state["last_saved"] is not None
        assert "T" in state["last_saved"]  # ISO 8601 format


# ---------------------------------------------------------------------------
# TestMigration
# ---------------------------------------------------------------------------

class TestMigration:
    def test_migrate_old_format(self, tmp_path):
        """Old format with windows array should migrate to shader_configs."""
        old_state = {
            "windows": [
                {"preset": 0, "slot": 1},  # Classic Green
                {"preset": 2, "slot": 3},  # Blood Red
            ]
        }
        path = str(tmp_path / "state.json")
        with open(path, "w") as f:
            json.dump(old_state, f)
        state = load_state(path)

        assert "shader_configs" in state
        assert "windows" not in state
        assert "1" in state["shader_configs"]
        assert "3" in state["shader_configs"]
        # Classic Green: R=0.0, G=1.0, B=0.3
        assert state["shader_configs"]["1"]["RAIN_R"] == 0.0
        assert state["shader_configs"]["1"]["RAIN_G"] == 1.0
        assert state["shader_configs"]["1"]["RAIN_B"] == 0.3
        # Blood Red: R=1.0, G=0.1, B=0.1
        assert state["shader_configs"]["3"]["RAIN_R"] == 1.0
        assert state["shader_configs"]["3"]["RAIN_G"] == 0.1
        assert state["shader_configs"]["3"]["RAIN_B"] == 0.1

    def test_migrate_new_format_unchanged(self, tmp_path):
        """New format should pass through without modification."""
        new_state = {
            "active_tab": 2,
            "shader_configs": {"1": {"RAIN_R": 0.5}},
            "layout": {"mode": "quads"},
            "window_slots": {},
            "opacity": 90,
            "last_saved": "2026-03-09T00:00:00Z",
        }
        path = str(tmp_path / "state.json")
        with open(path, "w") as f:
            json.dump(new_state, f)
        state = load_state(path)
        assert state["active_tab"] == 2
        assert state["shader_configs"]["1"]["RAIN_R"] == 0.5

    def test_migrate_preserves_extra_keys(self):
        """Extra keys in old format should be preserved."""
        old = {
            "windows": [{"preset": 0, "slot": 1}],
            "custom_field": "keep_me",
        }
        migrated = _migrate_state(old)
        assert "custom_field" in migrated
        assert migrated["custom_field"] == "keep_me"

    def test_ensure_keys_adds_missing(self):
        """Missing top-level keys should be filled from defaults."""
        partial = {"active_tab": 5}
        result = _ensure_keys(partial)
        assert result["active_tab"] == 5  # Kept
        assert result["shader_configs"] == {}  # Added
        assert result["layout"]["mode"] == "pillars"  # Added
        assert result["opacity"] == 85  # Added


# ---------------------------------------------------------------------------
# TestSnapshot
# ---------------------------------------------------------------------------

class TestSnapshot:
    @patch("shader_service.get_ghostty_bus_names")
    @patch("shader_service.read_shader_config")
    def test_snapshot_shader_configs(self, mock_read, mock_bus):
        mock_bus.return_value = {
            1: {"pid": 1000, "bus_name": ":1.100"},
            3: {"pid": 1001, "bus_name": ":1.101"},
        }
        mock_read.side_effect = lambda slot: {
            "RAIN_R": float(slot) / 10.0,
            "RAIN_G": 1.0,
        }
        configs = snapshot_shader_configs()
        assert "1" in configs
        assert "3" in configs
        assert configs["1"]["RAIN_R"] == 0.1
        assert configs["3"]["RAIN_R"] == 0.3

    @patch("shader_service.get_ghostty_bus_names")
    def test_snapshot_empty_mapping(self, mock_bus):
        mock_bus.return_value = {}
        configs = snapshot_shader_configs()
        assert configs == {}


# ---------------------------------------------------------------------------
# TestStateService
# ---------------------------------------------------------------------------

class TestStateService:
    def test_update_shader_config(self, tmp_path):
        path = str(tmp_path / "state.json")
        svc = StateService(path=path, debounce_ms=10000)  # Long debounce, won't fire
        svc.update_shader_config(1, {"RAIN_R": 0.7, "RAIN_G": 0.3})
        assert svc.state["shader_configs"]["1"]["RAIN_R"] == 0.7

    def test_update_opacity(self, tmp_path):
        path = str(tmp_path / "state.json")
        svc = StateService(path=path, debounce_ms=10000)
        svc.update_opacity(42)
        assert svc.state["opacity"] == 42

    def test_update_layout(self, tmp_path):
        path = str(tmp_path / "state.json")
        svc = StateService(path=path, debounce_ms=10000)
        svc.update_layout({"mode": "overlap"})
        assert svc.state["layout"]["mode"] == "overlap"
        # Other layout keys preserved
        assert svc.state["layout"]["gap_size"] == 120

    @patch("state_service.snapshot_shader_configs")
    def test_flush_saves_immediately(self, mock_snap, tmp_path):
        mock_snap.return_value = {}
        path = str(tmp_path / "state.json")
        svc = StateService(path=path, debounce_ms=10000)
        svc.update_opacity(55)
        svc.flush()
        # File should exist now
        assert os.path.exists(path)
        with open(path) as f:
            saved = json.load(f)
        assert saved["opacity"] == 55

    @patch("state_service.snapshot_shader_configs")
    def test_mark_dirty_debounce(self, mock_snap, tmp_path):
        """Multiple rapid mark_dirty calls result in a single file write."""
        mock_snap.return_value = {}
        path = str(tmp_path / "state.json")
        svc = StateService(path=path, debounce_ms=100)

        # Call mark_dirty multiple times rapidly
        svc._state["opacity"] = 10
        svc.mark_dirty()
        svc._state["opacity"] = 20
        svc.mark_dirty()
        svc._state["opacity"] = 30
        svc.mark_dirty()

        # Not yet written (debounce hasn't fired)
        assert not os.path.exists(path)

        # Wait for debounce to fire
        time.sleep(0.3)

        # Now it should be written with the final value
        assert os.path.exists(path)
        with open(path) as f:
            saved = json.load(f)
        assert saved["opacity"] == 30

    def test_state_property(self, tmp_path):
        path = str(tmp_path / "state.json")
        svc = StateService(path=path)
        assert svc.state["active_tab"] == 1
        assert isinstance(svc.state, dict)
