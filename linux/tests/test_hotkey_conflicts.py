"""Tests for hotkey_conflicts: GNOME/KDE conflict detection and notification."""
import os
import sys
import subprocess
from unittest.mock import patch, MagicMock, call

import pytest

# Ensure linux/ is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import hotkey_conflicts


class TestParseGdkBinding:
    """parse_gdk_binding() parses GDK accelerator format."""

    def test_control_shift_l(self):
        result = hotkey_conflicts.parse_gdk_binding("<Control><Shift>l")
        assert result["modifiers"] == {"Ctrl", "Shift"}
        assert result["key"] == "l"

    def test_super_up(self):
        result = hotkey_conflicts.parse_gdk_binding("<Super>Up")
        assert result["modifiers"] == {"Super"}
        assert result["key"] == "up"

    def test_primary_is_ctrl(self):
        result = hotkey_conflicts.parse_gdk_binding("<Primary><Shift>h")
        assert result["modifiers"] == {"Ctrl", "Shift"}
        assert result["key"] == "h"

    def test_alt_modifier(self):
        result = hotkey_conflicts.parse_gdk_binding("<Alt>F4")
        assert result["modifiers"] == {"Alt"}
        assert result["key"] == "f4"

    def test_single_key_no_modifiers(self):
        result = hotkey_conflicts.parse_gdk_binding("F11")
        assert result["modifiers"] == set()
        assert result["key"] == "f11"

    def test_normalizes_key_to_lowercase(self):
        result = hotkey_conflicts.parse_gdk_binding("<Control>L")
        assert result["key"] == "l"

    def test_ctrl_alias(self):
        result = hotkey_conflicts.parse_gdk_binding("<Ctrl>a")
        assert result["modifiers"] == {"Ctrl"}
        assert result["key"] == "a"


class TestGetGnomeSystemShortcuts:
    """get_gnome_system_shortcuts() parses gsettings output."""

    def test_parses_gsettings_output(self):
        """Parses valid gsettings schema keys and values."""
        def mock_run(cmd, **kwargs):
            result = MagicMock()
            result.returncode = 0
            if cmd[1] == "list-keys":
                result.stdout = "maximize\nminimize\n"
            elif cmd[1] == "get":
                key_name = cmd[3]
                if key_name == "maximize":
                    result.stdout = "['<Super>Up']\n"
                elif key_name == "minimize":
                    result.stdout = "['<Super>Down']\n"
            return result

        with patch("hotkey_conflicts.subprocess.run", side_effect=mock_run):
            shortcuts = hotkey_conflicts.get_gnome_system_shortcuts()

        assert len(shortcuts) >= 2
        # Check that Super+Up was parsed
        found_super_up = False
        for s in shortcuts:
            if s["key"] == "up" and "Super" in s["modifiers"]:
                found_super_up = True
        assert found_super_up

    def test_handles_missing_gsettings(self):
        """Returns empty list if gsettings not installed."""
        with patch("hotkey_conflicts.subprocess.run", side_effect=FileNotFoundError):
            shortcuts = hotkey_conflicts.get_gnome_system_shortcuts()
        assert shortcuts == []

    def test_handles_timeout(self):
        """Returns empty list on timeout."""
        with patch("hotkey_conflicts.subprocess.run",
                   side_effect=subprocess.TimeoutExpired("gsettings", 5)):
            shortcuts = hotkey_conflicts.get_gnome_system_shortcuts()
        assert shortcuts == []

    def test_skips_disabled_bindings(self):
        """Bindings set to 'disabled' are not returned."""
        def mock_run(cmd, **kwargs):
            result = MagicMock()
            result.returncode = 0
            if cmd[1] == "list-keys":
                result.stdout = "some-key\n"
            elif cmd[1] == "get":
                result.stdout = "['disabled']\n"
            return result

        with patch("hotkey_conflicts.subprocess.run", side_effect=mock_run):
            shortcuts = hotkey_conflicts.get_gnome_system_shortcuts()
        assert shortcuts == []

    def test_handles_empty_binding_string(self):
        """Empty binding strings are skipped."""
        def mock_run(cmd, **kwargs):
            result = MagicMock()
            result.returncode = 0
            if cmd[1] == "list-keys":
                result.stdout = "some-key\n"
            elif cmd[1] == "get":
                result.stdout = "@as []\n"
            return result

        with patch("hotkey_conflicts.subprocess.run", side_effect=mock_run):
            shortcuts = hotkey_conflicts.get_gnome_system_shortcuts()
        assert shortcuts == []


class TestParseKdeShortcuts:
    """parse_kde_shortcuts() reads kglobalshortcutsrc INI format."""

    def test_parses_kde_shortcuts(self, tmp_path):
        """Parses valid KDE kglobalshortcutsrc file."""
        kde_config = tmp_path / "kglobalshortcutsrc"
        kde_config.write_text(
            "[kwin]\n"
            "Window Maximize=Meta+Up,Meta+Up,Maximize Window\n"
            "Window Minimize=Meta+Down,,Minimize Window\n"
            "\n"
            "[plasmashell]\n"
            "show-on-mouse-pos=Meta+Ctrl+V,Meta+V,Show Desktop\n"
        )
        shortcuts = hotkey_conflicts.parse_kde_shortcuts(path=str(kde_config))

        # Should have at least Meta+Up (Maximize) and Meta+Down (Minimize)
        assert len(shortcuts) >= 2
        found_meta_up = False
        for s in shortcuts:
            if s["key"] == "up" and "Super" in s["modifiers"]:
                found_meta_up = True
        assert found_meta_up

    def test_returns_empty_when_file_missing(self):
        shortcuts = hotkey_conflicts.parse_kde_shortcuts(path="/nonexistent/kglobalshortcutsrc")
        assert shortcuts == []

    def test_skips_empty_shortcuts(self, tmp_path):
        """Entries with empty shortcut (none set) are skipped."""
        kde_config = tmp_path / "kglobalshortcutsrc"
        kde_config.write_text(
            "[kwin]\n"
            "NoShortcut=,,No Shortcut Action\n"
        )
        shortcuts = hotkey_conflicts.parse_kde_shortcuts(path=str(kde_config))
        # The first field (before first comma) is empty string, should be skipped
        assert shortcuts == []


class TestDetectConflicts:
    """detect_conflicts() finds overlapping bindings."""

    def test_detects_matching_bindings(self):
        """Finds conflicts when system bindings match our config."""
        our_bindings = {
            "SpeedDown": {"key": "Up", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        # Mock system shortcuts that conflict: Ctrl+Shift+Up
        system_shortcuts = [
            {"modifiers": {"Ctrl", "Shift"}, "key": "up", "source": "org.gnome.desktop.wm.keybindings"},
        ]

        with patch("hotkey_conflicts.get_gnome_system_shortcuts", return_value=system_shortcuts):
            with patch("hotkey_conflicts.parse_kde_shortcuts", return_value=[]):
                conflicts = hotkey_conflicts.detect_conflicts(our_bindings)

        assert len(conflicts) == 1
        assert conflicts[0]["action"] == "SpeedDown"

    def test_normalizes_key_names_to_lowercase(self):
        """Keys are compared case-insensitively."""
        our_bindings = {
            "ShowHelp": {"key": "H", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        system_shortcuts = [
            {"modifiers": {"Ctrl", "Shift"}, "key": "h", "source": "test"},
        ]

        with patch("hotkey_conflicts.get_gnome_system_shortcuts", return_value=system_shortcuts):
            with patch("hotkey_conflicts.parse_kde_shortcuts", return_value=[]):
                conflicts = hotkey_conflicts.detect_conflicts(our_bindings)

        assert len(conflicts) == 1

    def test_no_conflicts_returns_empty(self):
        """Returns empty list when no overlaps exist."""
        our_bindings = {
            "SpeedUp": {"key": "Down", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        system_shortcuts = [
            {"modifiers": {"Super"}, "key": "up", "source": "test"},
        ]

        with patch("hotkey_conflicts.get_gnome_system_shortcuts", return_value=system_shortcuts):
            with patch("hotkey_conflicts.parse_kde_shortcuts", return_value=[]):
                conflicts = hotkey_conflicts.detect_conflicts(our_bindings)

        assert conflicts == []

    def test_conflict_has_required_fields(self):
        """Each conflict dict has action, key, modifiers, system_source."""
        our_bindings = {
            "SpeedDown": {"key": "Up", "modifiers": ["Ctrl", "Shift"], "enabled": True},
        }
        system_shortcuts = [
            {"modifiers": {"Ctrl", "Shift"}, "key": "up", "source": "org.gnome.desktop.wm.keybindings"},
        ]

        with patch("hotkey_conflicts.get_gnome_system_shortcuts", return_value=system_shortcuts):
            with patch("hotkey_conflicts.parse_kde_shortcuts", return_value=[]):
                conflicts = hotkey_conflicts.detect_conflicts(our_bindings)

        c = conflicts[0]
        assert "action" in c
        assert "key" in c
        assert "modifiers" in c
        assert "system_source" in c


class TestNotifyConflicts:
    """notify_conflicts() sends desktop notification."""

    def test_sends_notification_when_conflicts(self):
        """Calls notify-send with summary message."""
        conflicts = [
            {"action": "ShowHelp", "key": "H", "modifiers": ["Ctrl", "Shift"],
             "system_source": "gnome"},
        ]
        with patch("hotkey_conflicts.subprocess.Popen") as mock_popen:
            hotkey_conflicts.notify_conflicts(conflicts)
            mock_popen.assert_called_once()
            cmd = mock_popen.call_args[0][0]
            assert "notify-send" in cmd[0]
            # Should mention conflict count or key combo
            full_cmd = " ".join(cmd)
            assert "1" in full_cmd or "conflict" in full_cmd.lower()

    def test_does_nothing_when_no_conflicts(self):
        """Does not call notify-send with empty conflicts list."""
        with patch("hotkey_conflicts.subprocess.Popen") as mock_popen:
            hotkey_conflicts.notify_conflicts([])
            mock_popen.assert_not_called()

    def test_handles_missing_notify_send(self):
        """Silently handles FileNotFoundError when notify-send not installed."""
        conflicts = [
            {"action": "ShowHelp", "key": "H", "modifiers": ["Ctrl", "Shift"],
             "system_source": "gnome"},
        ]
        with patch("hotkey_conflicts.subprocess.Popen", side_effect=FileNotFoundError):
            # Should not raise
            hotkey_conflicts.notify_conflicts(conflicts)

    def test_sends_single_notification_for_multiple_conflicts(self):
        """Multiple conflicts produce one notification, not one per conflict."""
        conflicts = [
            {"action": "ShowHelp", "key": "H", "modifiers": ["Ctrl", "Shift"],
             "system_source": "gnome"},
            {"action": "SpeedDown", "key": "Up", "modifiers": ["Ctrl", "Shift"],
             "system_source": "gnome"},
        ]
        with patch("hotkey_conflicts.subprocess.Popen") as mock_popen:
            hotkey_conflicts.notify_conflicts(conflicts)
            assert mock_popen.call_count == 1
