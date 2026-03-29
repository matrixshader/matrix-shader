using System.Text;
using MatrixShader.Core.Models;
using MatrixShader.Core.Services;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// TUI screen for managing shader presets (save, load, delete).
/// Follows the same pattern as HotkeyConfigScreen.
/// </summary>
public class PresetScreen
{
    private readonly IPresetService _presetService;
    private readonly IShaderService _shaderService;
    private readonly ITerminalSettingsService _terminalSettingsService;
    private readonly TabManager _tabManager;

    private List<ShaderPreset> _presets;
    private int _selectedIndex;
    private string? _statusMessage;

    public PresetScreen(
        IPresetService presetService,
        IShaderService shaderService,
        ITerminalSettingsService terminalSettingsService,
        TabManager tabManager)
    {
        _presetService = presetService;
        _shaderService = shaderService;
        _terminalSettingsService = terminalSettingsService;
        _tabManager = tabManager;
        _presets = _presetService.ListPresets();
    }

    /// <summary>
    /// Runs the preset screen. Returns when user exits with ESC.
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
                var key = Console.ReadKey(intercept: true);
                if (!HandleInput(key))
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
        var cw = TuiRenderer.ClearWidth;
        var sb = new StringBuilder(cw * 30);

        // Header
        TuiRenderer.AppendPaddedLine(sb, cw, "");
        TuiRenderer.AppendPaddedLine(sb, cw, TuiRenderer.FormatSectionHeader("PRESETS"));
        TuiRenderer.AppendPaddedLine(sb, cw, "");

        if (_presets.Count == 0)
        {
            TuiRenderer.AppendPaddedLine(sb, cw,
                $" {TuiRenderer.GRAY}No presets saved yet. Press [S] to save your current config.{TuiRenderer.RESET}");
            TuiRenderer.AppendPaddedLine(sb, cw, "");
        }
        else
        {
            for (int i = 0; i < _presets.Count; i++)
            {
                var preset = _presets[i];
                var swatch = TuiRenderer.ColorSwatch(preset.R, preset.G, preset.B, 2);
                var dateStr = preset.SavedAt.ToString("MMM dd");
                var name = preset.Name;

                string marker, nameStr;
                if (i == _selectedIndex)
                {
                    marker = $"{TuiRenderer.YELLOW}[>]{TuiRenderer.RESET}";
                    nameStr = $"{TuiRenderer.YELLOW}{name}{TuiRenderer.RESET}";
                }
                else
                {
                    marker = $"{TuiRenderer.GRAY}[ ]{TuiRenderer.RESET}";
                    nameStr = $"{TuiRenderer.GRAY}{name}{TuiRenderer.RESET}";
                }

                TuiRenderer.AppendPaddedLine(sb, cw,
                    $" {marker} {nameStr}  {swatch}  {TuiRenderer.GRAY}{dateStr}{TuiRenderer.RESET}");
            }
            TuiRenderer.AppendPaddedLine(sb, cw, "");
        }

        // Footer
        TuiRenderer.AppendPaddedLine(sb, cw,
            $" {TuiRenderer.GRAY}[S] Save  [ENTER] Load  [D] Delete  [ESC] Back{TuiRenderer.RESET}");

        // Status message
        if (!string.IsNullOrEmpty(_statusMessage))
        {
            TuiRenderer.AppendPaddedLine(sb, cw,
                $" {TuiRenderer.GREEN}{_statusMessage}{TuiRenderer.RESET}");
        }
        else
        {
            TuiRenderer.AppendPaddedLine(sb, cw, "");
        }

        // Fill remaining rows
        var linesWritten = 0;
        for (int i = 0; i < sb.Length; i++)
            if (sb[i] == '\n') linesWritten++;
        var maxRows = Console.WindowHeight;
        var remaining = maxRows - linesWritten - 1;
        if (remaining > 0)
        {
            TuiRenderer.AppendBlankLines(sb, cw, remaining);
        }

        Console.Write("\x1b[H");
        Console.Write(sb.ToString());
    }

    /// <summary>
    /// Returns false to exit, true to continue.
    /// </summary>
    private bool HandleInput(ConsoleKeyInfo key)
    {
        _statusMessage = null;

        if (key.Key == ConsoleKey.Escape)
            return false;

        if (key.Key == ConsoleKey.UpArrow)
        {
            if (_presets.Count > 0)
                _selectedIndex = (_selectedIndex - 1 + _presets.Count) % _presets.Count;
            return true;
        }

        if (key.Key == ConsoleKey.DownArrow)
        {
            if (_presets.Count > 0)
                _selectedIndex = (_selectedIndex + 1) % _presets.Count;
            return true;
        }

        var ch = char.ToLower(key.KeyChar);

        if (ch == 's')
        {
            DoSave();
            return true;
        }

        if (key.Key == ConsoleKey.Enter)
        {
            DoLoad();
            return true;
        }

        if (ch == 'd')
        {
            DoDelete();
            return true;
        }

        return true;
    }

    private void DoSave()
    {
        // Show prompt
        Console.Write("\x1b[H\x1b[2J");
        Console.Write("\n Preset name: ");
        Console.CursorVisible = true;

        var nameBuf = new StringBuilder();
        while (true)
        {
            var key = Console.ReadKey(intercept: true);

            if (key.Key == ConsoleKey.Escape)
            {
                Console.CursorVisible = false;
                return;
            }

            if (key.Key == ConsoleKey.Enter)
                break;

            if (key.Key == ConsoleKey.Backspace)
            {
                if (nameBuf.Length > 0)
                {
                    nameBuf.Remove(nameBuf.Length - 1, 1);
                    Console.Write("\b \b");
                }
                continue;
            }

            // Printable characters
            if (key.KeyChar >= 32 && key.KeyChar <= 126)
            {
                nameBuf.Append(key.KeyChar);
                Console.Write(key.KeyChar);
            }
        }
        Console.CursorVisible = false;

        var name = nameBuf.ToString().Trim();
        if (string.IsNullOrEmpty(name))
        {
            _statusMessage = "Name cannot be empty";
            return;
        }

        // Check for duplicate
        if (_presetService.PresetExists(name))
        {
            Console.Write($"\n Overwrite '{name}'? [Y/N] ");
            var confirm = Console.ReadKey(intercept: true);
            if (confirm.KeyChar != 'y' && confirm.KeyChar != 'Y')
            {
                _statusMessage = "Cancelled";
                return;
            }
        }

        try
        {
            var currentConfig = _tabManager.CurrentConfig;
            _presetService.Save(name, currentConfig);
            RefreshPresets();
            _statusMessage = $"Saved '{name}'";
        }
        catch (ArgumentException ex)
        {
            _statusMessage = ex.Message;
        }
        catch (Exception ex)
        {
            _statusMessage = $"Save failed: {ex.Message}";
        }
    }

    private void DoLoad()
    {
        if (_presets.Count == 0 || _selectedIndex < 0 || _selectedIndex >= _presets.Count)
            return;

        var presetName = _presets[_selectedIndex].Name;
        var preset = _presetService.Load(presetName);

        if (preset == null)
        {
            _statusMessage = "Preset not found (may have been deleted)";
            return;
        }

        var config = preset.ToConfig();
        _tabManager.UpdateConfig(config);
        _statusMessage = $"Loaded '{presetName}'";
    }

    private void DoDelete()
    {
        if (_presets.Count == 0 || _selectedIndex < 0 || _selectedIndex >= _presets.Count)
            return;

        var presetName = _presets[_selectedIndex].Name;
        Console.Write($"\n Delete '{presetName}'? [Y/N] ");
        var confirm = Console.ReadKey(intercept: true);

        if (confirm.KeyChar != 'y' && confirm.KeyChar != 'Y')
        {
            _statusMessage = "Cancelled";
            return;
        }

        if (_presetService.Delete(presetName))
        {
            RefreshPresets();
            if (_presets.Count > 0)
                _selectedIndex = Math.Min(_selectedIndex, _presets.Count - 1);
            else
                _selectedIndex = 0;
            _statusMessage = $"Deleted '{presetName}'";
        }
        else
        {
            _statusMessage = "Delete failed (preset may have been removed)";
        }
    }

    private void RefreshPresets()
    {
        _presets = _presetService.ListPresets();
    }
}
