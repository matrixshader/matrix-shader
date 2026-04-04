using System.Text;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// TUI screen for configuring global hotkeys.
/// Matches Linux hotkey_config_screen.py for full cross-platform parity.
/// </summary>
public class HotkeyConfigScreen
{
    private readonly IHotkeyConfigService _configService;
    private HotkeyConfig _config;
    private int _selectedIndex;
    private bool _editMode;
    private string? _statusMessage;
    private List<HotkeyAction> _actionOrder;

    /// <summary>
    /// Default actions shown in the config screen (matches Linux ACTION_ORDER).
    /// </summary>
    private static readonly HotkeyAction[] DefaultActions =
    {
        HotkeyAction.SwapLeft, HotkeyAction.SwapRight, HotkeyAction.CycleLayout,
        HotkeyAction.ToggleTransparency, HotkeyAction.OpacityDown, HotkeyAction.OpacityUp,
        HotkeyAction.SpeedUp, HotkeyAction.SpeedDown,
        HotkeyAction.ToggleFar, HotkeyAction.ToggleMid, HotkeyAction.ToggleNear,
        HotkeyAction.ShowHelp, HotkeyAction.ManualReload,
        HotkeyAction.SnapbackSave, HotkeyAction.SnapbackRestore
    };

    /// <summary>
    /// All possible actions including user-addable ones with no default binding.
    /// Matches Linux ALL_ACTIONS.
    /// </summary>
    private static readonly HotkeyAction[] AllActions = DefaultActions.Concat(new[]
    {
        HotkeyAction.GlowUp, HotkeyAction.GlowDown,
        HotkeyAction.WidthUp, HotkeyAction.WidthDown,
        HotkeyAction.TrailUp, HotkeyAction.TrailDown,
        HotkeyAction.DensityUp, HotkeyAction.DensityDown,
        HotkeyAction.RedUp, HotkeyAction.RedDown,
        HotkeyAction.GreenUp, HotkeyAction.GreenDown,
        HotkeyAction.BlueUp, HotkeyAction.BlueDown
    }).ToArray();

    public HotkeyConfigScreen(IHotkeyConfigService configService)
    {
        _configService = configService;
        _config = _configService.LoadConfig();
        // Start with actions that have bindings, plus defaults
        _actionOrder = new List<HotkeyAction>(DefaultActions);
        // Add any extra actions that are in the saved config but not in defaults
        foreach (var action in _config.Bindings.Keys)
        {
            if (!_actionOrder.Contains(action))
                _actionOrder.Add(action);
        }
    }

    public void Run()
    {
        Console.CursorVisible = false;
        Console.Clear();

        try
        {
            while (true)
            {
                Render();
                var result = HandleInput();
                if (result == InputResult.Exit)
                    break;
            }
        }
        finally
        {
            Console.CursorVisible = true;
            Console.Clear();
        }
    }

    private void Render()
    {
        Console.SetCursorPosition(0, 0);
        var sb = new StringBuilder();

        sb.AppendLine();
        sb.AppendLine("\x1b[38;2;110;220;170m HOTKEY CONFIGURATION \x1b[0m");
        sb.AppendLine("\x1b[90m Arrows to navigate, Enter to edit, A to add, ESC to exit \x1b[0m");
        sb.AppendLine();

        for (int i = 0; i < _actionOrder.Count; i++)
        {
            var action = _actionOrder[i];
            var isSelected = i == _selectedIndex;

            sb.Append(isSelected ? "\x1b[38;2;110;220;170m > \x1b[0m" : "   ");

            var actionName = GetActionDisplayName(action);
            sb.Append($"{actionName,-24}");

            if (_config.Bindings.TryGetValue(action, out var binding))
            {
                if (isSelected && _editMode)
                {
                    sb.Append("\x1b[33m[Press key (Ctrl+Shift auto-added)...]\x1b[0m");
                }
                else if (!binding.Enabled)
                {
                    sb.Append("\x1b[90m[Disabled]           \x1b[0m");
                }
                else
                {
                    sb.Append($"\x1b[36m{binding.DisplayName,-20}\x1b[0m");
                }
            }
            else
            {
                if (isSelected && _editMode)
                {
                    sb.Append("\x1b[33m[Press key (Ctrl+Shift auto-added)...]\x1b[0m");
                }
                else
                {
                    sb.Append("\x1b[90m[No binding]         \x1b[0m");
                }
            }

            sb.AppendLine();
        }

        sb.AppendLine();
        if (!string.IsNullOrEmpty(_statusMessage))
            sb.AppendLine($"\x1b[33m{_statusMessage}\x1b[0m");
        else
            sb.AppendLine();

        sb.AppendLine();
        sb.AppendLine("\x1b[90m [Enter] Edit  [A] Add  [D] Disable  [X] Remove  [R] Reset  [S] Save  [ESC] Exit \x1b[0m");
        sb.AppendLine();

        var lines = sb.ToString().Split('\n');
        foreach (var line in lines)
            Console.WriteLine(line.TrimEnd().PadRight(80));
    }

    private enum InputResult { Continue, Exit }

    private InputResult HandleInput()
    {
        var key = Console.ReadKey(intercept: true);

        if (_editMode)
            return HandleEditMode(key);

        return key.Key switch
        {
            ConsoleKey.UpArrow => MoveSelection(-1),
            ConsoleKey.DownArrow => MoveSelection(1),
            ConsoleKey.Enter => EnterEditMode(),
            ConsoleKey.A => DoAdd(),
            ConsoleKey.X => DoRemove(),
            ConsoleKey.D => ToggleDisable(),
            ConsoleKey.R => ResetToDefaults(),
            ConsoleKey.S => SaveConfig(),
            ConsoleKey.Escape => InputResult.Exit,
            _ => InputResult.Continue
        };
    }

    private InputResult HandleEditMode(ConsoleKeyInfo key)
    {
        if (key.Key == ConsoleKey.Escape)
        {
            _editMode = false;
            _statusMessage = null;
            return InputResult.Continue;
        }

        // Capture just the key — Ctrl+Shift is auto-applied (matches Linux behavior).
        var vk = GetVirtualKeyCode(key.Key);
        if (vk == 0)
        {
            _statusMessage = "Invalid key - use letter, number, arrow, or F-key";
            return InputResult.Continue;
        }

        uint modifiers = HotkeyApi.MOD_CONTROL | HotkeyApi.MOD_SHIFT;

        if (!TestHotkeyAvailable(modifiers, vk))
        {
            _statusMessage = "Ctrl+Shift+" + GetKeyName(key.Key) + " already in use";
            return InputResult.Continue;
        }

        var action = _actionOrder[_selectedIndex];
        var displayName = "Ctrl+Shift+" + GetKeyName(key.Key);
        var newBinding = new HotkeyBinding(
            action, displayName, modifiers | HotkeyApi.MOD_NOREPEAT, vk, true);

        var newBindings = new Dictionary<HotkeyAction, HotkeyBinding>(_config.Bindings)
        {
            [action] = newBinding
        };
        _config = _config with { Bindings = newBindings };

        _editMode = false;
        _statusMessage = $"Changed to {displayName} (press S to save)";
        return InputResult.Continue;
    }

    /// <summary>
    /// Shows picker of all unbound actions. User selects one to add.
    /// Matches Linux _do_add() implementation.
    /// </summary>
    private InputResult DoAdd()
    {
        var bound = new HashSet<HotkeyAction>(_actionOrder);
        var unbound = AllActions.Where(a => !bound.Contains(a)).ToList();

        if (unbound.Count == 0)
        {
            _statusMessage = "All actions are already bound";
            return InputResult.Continue;
        }

        int sel = 0;
        while (true)
        {
            Console.SetCursorPosition(0, 0);
            Console.Clear();
            Console.WriteLine();
            Console.WriteLine("\x1b[38;2;110;220;170m ADD HOTKEY \x1b[0m");
            Console.WriteLine("\x1b[97m Arrows to navigate, Enter to select, ESC to cancel \x1b[0m");
            Console.WriteLine();

            for (int i = 0; i < unbound.Count; i++)
            {
                var name = GetActionDisplayName(unbound[i]);
                if (i == sel)
                    Console.WriteLine($"\x1b[38;2;110;220;170m > \x1b[33m{name}\x1b[0m");
                else
                    Console.WriteLine($"   \x1b[97m{name}\x1b[0m");
            }

            var addKey = Console.ReadKey(intercept: true);
            if (addKey.Key == ConsoleKey.Escape)
                return InputResult.Continue;
            if (addKey.Key == ConsoleKey.UpArrow)
                sel = (sel - 1 + unbound.Count) % unbound.Count;
            else if (addKey.Key == ConsoleKey.DownArrow)
                sel = (sel + 1) % unbound.Count;
            else if (addKey.Key == ConsoleKey.Enter)
            {
                var chosen = unbound[sel];
                _actionOrder.Add(chosen);
                _selectedIndex = _actionOrder.Count - 1;
                _statusMessage = $"Added {GetActionDisplayName(chosen)} — press Enter to assign a key";
                return InputResult.Continue;
            }
        }
    }

    /// <summary>
    /// Remove the selected action from the config (only user-added ones).
    /// Matches Linux _do_remove() implementation.
    /// </summary>
    private InputResult DoRemove()
    {
        if (_selectedIndex < 0 || _selectedIndex >= _actionOrder.Count)
            return InputResult.Continue;

        var action = _actionOrder[_selectedIndex];

        // Don't allow removing default-bound actions
        if (DefaultActions.Contains(action))
        {
            _statusMessage = "Can't remove default hotkeys — use D to disable";
            return InputResult.Continue;
        }

        _actionOrder.RemoveAt(_selectedIndex);
        var newBindings = new Dictionary<HotkeyAction, HotkeyBinding>(_config.Bindings);
        newBindings.Remove(action);
        _config = _config with { Bindings = newBindings };

        if (_selectedIndex >= _actionOrder.Count)
            _selectedIndex = Math.Max(0, _actionOrder.Count - 1);

        _statusMessage = $"Removed {GetActionDisplayName(action)}";
        return InputResult.Continue;
    }

    private InputResult MoveSelection(int delta)
    {
        _selectedIndex = Math.Clamp(_selectedIndex + delta, 0, _actionOrder.Count - 1);
        _statusMessage = null;
        return InputResult.Continue;
    }

    private InputResult EnterEditMode()
    {
        var action = _actionOrder[_selectedIndex];
        if (_config.Bindings.TryGetValue(action, out var binding) && !binding.Enabled)
        {
            _statusMessage = "Enable hotkey first (press D)";
            return InputResult.Continue;
        }

        _editMode = true;
        _statusMessage = null;
        return InputResult.Continue;
    }

    private InputResult ToggleDisable()
    {
        var action = _actionOrder[_selectedIndex];
        if (!_config.Bindings.TryGetValue(action, out var binding))
            return InputResult.Continue;

        var newBinding = binding with { Enabled = !binding.Enabled };
        var newBindings = new Dictionary<HotkeyAction, HotkeyBinding>(_config.Bindings)
        {
            [action] = newBinding
        };
        _config = _config with { Bindings = newBindings };

        _statusMessage = newBinding.Enabled ? "Enabled (press S to save)" : "Disabled (press S to save)";
        return InputResult.Continue;
    }

    private InputResult ResetToDefaults()
    {
        _config = _configService.ResetToDefaults();
        _actionOrder = new List<HotkeyAction>(DefaultActions);
        _statusMessage = "Reset to defaults (press S to save)";
        return InputResult.Continue;
    }

    private InputResult SaveConfig()
    {
        try
        {
            _configService.SaveConfig(_config);
            _statusMessage = "Saved! Restart hotkeys to apply changes.";
        }
        catch (Exception ex)
        {
            _statusMessage = $"Save failed: {ex.Message}";
        }
        return InputResult.Continue;
    }

    private bool TestHotkeyAvailable(uint modifiers, uint vk)
    {
        var testHwnd = WindowsApi.GetConsoleWindow();
        if (testHwnd == nint.Zero) return true;

        var testId = 9999;
        var result = HotkeyApi.RegisterHotKey(testHwnd, testId, modifiers | HotkeyApi.MOD_NOREPEAT, vk);
        if (result)
            HotkeyApi.UnregisterHotKey(testHwnd, testId);
        return result;
    }

    private static string GetActionDisplayName(HotkeyAction action) => action switch
    {
        HotkeyAction.SwapLeft => "Swap Window Left",
        HotkeyAction.SwapRight => "Swap Window Right",
        HotkeyAction.CycleLayout => "Cycle Layout Mode",
        HotkeyAction.ToggleTransparency => "Toggle Transparency",
        HotkeyAction.OpacityDown => "Decrease Opacity",
        HotkeyAction.OpacityUp => "Increase Opacity",
        HotkeyAction.SpeedUp => "Increase Speed",
        HotkeyAction.SpeedDown => "Decrease Speed",
        HotkeyAction.ToggleFar => "Toggle Far Layer",
        HotkeyAction.ToggleMid => "Toggle Mid Layer",
        HotkeyAction.ToggleNear => "Toggle Near Layer",
        HotkeyAction.ShowHelp => "Show Help",
        HotkeyAction.ManualReload => "Force Reload",
        HotkeyAction.SnapbackSave => "Save Snapback",
        HotkeyAction.SnapbackRestore => "Restore Snapback",
        HotkeyAction.GlowUp => "Increase Glow",
        HotkeyAction.GlowDown => "Decrease Glow",
        HotkeyAction.WidthUp => "Increase Width",
        HotkeyAction.WidthDown => "Decrease Width",
        HotkeyAction.TrailUp => "Increase Trail",
        HotkeyAction.TrailDown => "Decrease Trail",
        HotkeyAction.DensityUp => "Increase Density",
        HotkeyAction.DensityDown => "Decrease Density",
        HotkeyAction.RedUp => "Increase Red",
        HotkeyAction.RedDown => "Decrease Red",
        HotkeyAction.GreenUp => "Increase Green",
        HotkeyAction.GreenDown => "Decrease Green",
        HotkeyAction.BlueUp => "Increase Blue",
        HotkeyAction.BlueDown => "Decrease Blue",
        _ => action.ToString()
    };

    private static uint GetVirtualKeyCode(ConsoleKey key) => key switch
    {
        ConsoleKey.LeftArrow => HotkeyApi.VK_LEFT,
        ConsoleKey.RightArrow => HotkeyApi.VK_RIGHT,
        ConsoleKey.UpArrow => HotkeyApi.VK_UP,
        ConsoleKey.DownArrow => HotkeyApi.VK_DOWN,
        >= ConsoleKey.A and <= ConsoleKey.Z => (uint)(0x41 + (key - ConsoleKey.A)),
        >= ConsoleKey.D0 and <= ConsoleKey.D9 => (uint)(0x30 + (key - ConsoleKey.D0)),
        >= ConsoleKey.NumPad0 and <= ConsoleKey.NumPad9 => (uint)(0x60 + (key - ConsoleKey.NumPad0)),
        ConsoleKey.F1 => 0x70, ConsoleKey.F2 => 0x71, ConsoleKey.F3 => 0x72,
        ConsoleKey.F4 => 0x73, ConsoleKey.F5 => 0x74, ConsoleKey.F6 => 0x75,
        ConsoleKey.F7 => 0x76, ConsoleKey.F8 => 0x77, ConsoleKey.F9 => 0x78,
        ConsoleKey.F10 => 0x79, ConsoleKey.F11 => 0x7A, ConsoleKey.F12 => 0x7B,
        _ => 0
    };

    private static string GetKeyName(ConsoleKey key) => key switch
    {
        ConsoleKey.LeftArrow => "Left",
        ConsoleKey.RightArrow => "Right",
        ConsoleKey.UpArrow => "Up",
        ConsoleKey.DownArrow => "Down",
        >= ConsoleKey.D0 and <= ConsoleKey.D9 => (key - ConsoleKey.D0).ToString(),
        >= ConsoleKey.NumPad0 and <= ConsoleKey.NumPad9 => $"Num{key - ConsoleKey.NumPad0}",
        >= ConsoleKey.F1 and <= ConsoleKey.F12 => key.ToString(),
        _ => key.ToString()
    };
}
