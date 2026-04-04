using System.Text;
using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// TUI screen for configuring global hotkeys.
/// Per CONTEXT.md: "Like Cubase - prevents invalid selections before they happen"
/// </summary>
public class HotkeyConfigScreen
{
    private readonly IHotkeyConfigService _configService;
    private HotkeyConfig _config;
    private int _selectedIndex;
    private bool _editMode;
    private string? _statusMessage;
    private readonly List<HotkeyAction> _actionOrder;

    public HotkeyConfigScreen(IHotkeyConfigService configService)
    {
        _configService = configService;
        _config = _configService.LoadConfig();
        _actionOrder = Enum.GetValues<HotkeyAction>().ToList();
    }

    /// <summary>
    /// Runs the hotkey config screen. Returns when user exits.
    /// </summary>
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

        // Header
        sb.AppendLine();
        sb.AppendLine("\x1b[38;2;110;220;170m HOTKEY CONFIGURATION \x1b[0m");
        sb.AppendLine("\x1b[90m Use arrows to navigate, Enter to edit, D to disable, R to reset all \x1b[0m");
        sb.AppendLine();

        // Hotkey list
        for (int i = 0; i < _actionOrder.Count; i++)
        {
            var action = _actionOrder[i];
            var binding = _config.Bindings[action];
            var isSelected = i == _selectedIndex;

            // Selection indicator
            sb.Append(isSelected ? "\x1b[38;2;110;220;170m > \x1b[0m" : "   ");

            // Action name (padded)
            var actionName = GetActionDisplayName(action);
            sb.Append($"{actionName,-24}");

            // Binding display
            if (binding.Enabled)
            {
                var keyDisplay = binding.DisplayName;
                if (isSelected && _editMode)
                {
                    sb.Append("\x1b[33m[Press key (Ctrl+Shift auto-added)...]\x1b[0m");
                }
                else
                {
                    sb.Append($"\x1b[36m{keyDisplay,-20}\x1b[0m");
                }
            }
            else
            {
                sb.Append("\x1b[90m[Disabled]           \x1b[0m");
            }

            sb.AppendLine();
        }

        // Status message
        sb.AppendLine();
        if (!string.IsNullOrEmpty(_statusMessage))
        {
            sb.AppendLine($"\x1b[33m{_statusMessage}\x1b[0m");
        }
        else
        {
            sb.AppendLine(); // Blank line for consistent layout
        }

        // Footer
        sb.AppendLine();
        sb.AppendLine("\x1b[90m [Enter] Edit  [D] Toggle disable  [R] Reset all  [S] Save  [Esc] Exit \x1b[0m");
        sb.AppendLine();

        // Clear any remaining content from previous render
        var lines = sb.ToString().Split('\n');
        foreach (var line in lines)
        {
            // Pad each line to clear old content
            Console.WriteLine(line.TrimEnd().PadRight(80));
        }
    }

    private enum InputResult { Continue, Exit }

    private InputResult HandleInput()
    {
        var key = Console.ReadKey(intercept: true);

        if (_editMode)
        {
            return HandleEditMode(key);
        }

        return key.Key switch
        {
            ConsoleKey.UpArrow => MoveSelection(-1),
            ConsoleKey.DownArrow => MoveSelection(1),
            ConsoleKey.Enter => EnterEditMode(),
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
        // User presses 'T', we register Ctrl+Shift+T. This avoids firing the
        // global hotkey during edit (pressing the real combo triggers the action).
        var vk = GetVirtualKeyCode(key.Key);
        if (vk == 0)
        {
            _statusMessage = "Invalid key - use letter, number, arrow, or F-key";
            return InputResult.Continue;
        }

        uint modifiers = HotkeyApi.MOD_CONTROL | HotkeyApi.MOD_SHIFT;

        // Test if hotkey is available (try to register, then unregister)
        if (!TestHotkeyAvailable(modifiers, vk))
        {
            _statusMessage = "Ctrl+Shift+" + GetKeyName(key.Key) + " already in use";
            return InputResult.Continue;
        }

        // Update binding
        var action = _actionOrder[_selectedIndex];
        var displayName = "Ctrl+Shift+" + GetKeyName(key.Key);
        var newBinding = _config.Bindings[action] with
        {
            Modifiers = modifiers | HotkeyApi.MOD_NOREPEAT,
            VirtualKey = vk,
            DisplayName = displayName
        };

        var newBindings = new Dictionary<HotkeyAction, HotkeyBinding>(_config.Bindings)
        {
            [action] = newBinding
        };
        _config = _config with { Bindings = newBindings };

        _editMode = false;
        _statusMessage = $"Changed to {displayName} (press S to save)";
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
        if (!_config.Bindings[action].Enabled)
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
        var binding = _config.Bindings[action];
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

    /// <summary>
    /// Tests if a hotkey is available for registration.
    /// Cubase-style: Try to register, then immediately unregister.
    /// </summary>
    private bool TestHotkeyAvailable(uint modifiers, uint vk)
    {
        // Get console window handle for testing
        var testHwnd = WindowsApi.GetConsoleWindow();
        if (testHwnd == nint.Zero)
            return true; // Can't test, assume available

        var testId = 9999;
        var result = HotkeyApi.RegisterHotKey(testHwnd, testId, modifiers | HotkeyApi.MOD_NOREPEAT, vk);
        if (result)
        {
            HotkeyApi.UnregisterHotKey(testHwnd, testId);
        }
        return result;
    }

    /// <summary>
    /// Gets human-readable display name for a hotkey action.
    /// </summary>
    private static string GetActionDisplayName(HotkeyAction action) => action switch
    {
        HotkeyAction.SwapLeft => "Swap Window Left",
        HotkeyAction.SwapRight => "Swap Window Right",
        HotkeyAction.CycleLayout => "Cycle Layout Mode",
        HotkeyAction.ToggleTransparency => "Toggle Transparency",
        HotkeyAction.OpacityDown => "Decrease Opacity",
        HotkeyAction.OpacityUp => "Increase Opacity",
        // CycleShader REMOVED - corrupts shader parameters (BUG-SHADER04, BUG-SHADER05)
        HotkeyAction.SpeedUp => "Increase Speed",
        HotkeyAction.SpeedDown => "Decrease Speed",
        HotkeyAction.ToggleFar => "Toggle Far Layer",
        HotkeyAction.ToggleMid => "Toggle Mid Layer",
        HotkeyAction.ToggleNear => "Toggle Near Layer",
        HotkeyAction.ShowHelp => "Show Help",
        HotkeyAction.ManualReload => "Force Reload",
        _ => action.ToString()
    };

    /// <summary>
    /// Converts ConsoleKey to Windows virtual key code.
    /// </summary>
    private static uint GetVirtualKeyCode(ConsoleKey key) => key switch
    {
        ConsoleKey.LeftArrow => HotkeyApi.VK_LEFT,
        ConsoleKey.RightArrow => HotkeyApi.VK_RIGHT,
        ConsoleKey.UpArrow => HotkeyApi.VK_UP,
        ConsoleKey.DownArrow => HotkeyApi.VK_DOWN,
        >= ConsoleKey.A and <= ConsoleKey.Z => (uint)(0x41 + (key - ConsoleKey.A)),
        >= ConsoleKey.D0 and <= ConsoleKey.D9 => (uint)(0x30 + (key - ConsoleKey.D0)),
        >= ConsoleKey.NumPad0 and <= ConsoleKey.NumPad9 => (uint)(0x60 + (key - ConsoleKey.NumPad0)),
        ConsoleKey.F1 => 0x70,
        ConsoleKey.F2 => 0x71,
        ConsoleKey.F3 => 0x72,
        ConsoleKey.F4 => 0x73,
        ConsoleKey.F5 => 0x74,
        ConsoleKey.F6 => 0x75,
        ConsoleKey.F7 => 0x76,
        ConsoleKey.F8 => 0x77,
        ConsoleKey.F9 => 0x78,
        ConsoleKey.F10 => 0x79,
        ConsoleKey.F11 => 0x7A,
        ConsoleKey.F12 => 0x7B,
        _ => 0
    };

    /// <summary>
    /// Gets human-readable name for a console key.
    /// </summary>
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
