using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using MatrixShader.Core.Services;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Matrix-styled hotkey help overlay.
/// Spawns a new console window showing all active hotkey bindings.
/// Auto-closes when user presses any key.
/// </summary>
public static class HotkeyHelpOverlay
{
    // ANSI color codes
    private const string GREEN = "\x1b[38;2;110;220;170m";
    private const string BRIGHT_GREEN = "\x1b[38;2;110;220;170m";
    private const string DIM = "\x1b[90m";
    private const string YELLOW = "\x1b[33m";
    private const string CYAN = "\x1b[36m";
    private const string RED = "\x1b[31m";
    private const string WHITE = "\x1b[97m";
    private const string RESET = "\x1b[0m";
    private const string BOLD = "\x1b[1m";

    // Box-drawing characters
    private const char TL = '\u2554'; // ╔
    private const char TR = '\u2557'; // ╗
    private const char BL = '\u255A'; // ╚
    private const char BR = '\u255D'; // ╝
    private const char H  = '\u2550'; // ═
    private const char V  = '\u2551'; // ║
    private const char ML = '\u2560'; // ╠
    private const char MR = '\u2563'; // ╣

    private const int BOX_WIDTH = 54;

    /// <summary>
    /// Shows the help overlay in the current console.
    /// Called from the hotkeys process via a spawned conhost.
    /// </summary>
    public static void Show()
    {
        try
        {
            Console.OutputEncoding = Encoding.UTF8;
            Console.Title = "MatrixShader \u2014 Hotkey Reference";

            // Try to set console size (Windows only, fail silently)
            try
            {
                Console.SetWindowSize(Math.Min(60, Console.LargestWindowWidth), Math.Min(32, Console.LargestWindowHeight));
                Console.SetBufferSize(60, 32);
            }
            catch { /* Non-critical */ }

            Console.Clear();
            Console.CursorVisible = false;

            // Set background to black
            Console.Write("\x1b[40m");

            var sb = new StringBuilder();
            var inner = BOX_WIDTH - 2; // inside the border

            // Top border
            sb.AppendLine($"  {GREEN}{TL}{new string(H, inner)}{TR}{RESET}");

            // Title
            sb.AppendLine(BoxLine($"{BRIGHT_GREEN}{BOLD}  M A T R I X   S H A D E R{RESET}"));
            sb.AppendLine(BoxLine($"{DIM}  Hotkey Reference{RESET}"));

            // Separator
            sb.AppendLine($"  {GREEN}{ML}{new string(H, inner)}{MR}{RESET}");
            sb.AppendLine(BoxLine(""));

            // Window Controls
            sb.AppendLine(BoxLine($"{GREEN}{BOLD}  WINDOW CONTROLS{RESET}"));
            sb.AppendLine(BoxLine(""));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+Left/Right", "Rotate windows"));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+L", "Cycle layout mode"));
            sb.AppendLine(BoxLine(""));

            // Visual Controls
            sb.AppendLine(BoxLine($"{GREEN}{BOLD}  VISUAL CONTROLS{RESET}"));
            sb.AppendLine(BoxLine(""));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+B", "Cycle: Off / Custom / Full transparent"));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+J / K", "Opacity down / up (sets custom level)"));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+Down/Up", "Speed up / down"));
            sb.AppendLine(BoxLine(""));

            // Layer Controls
            sb.AppendLine(BoxLine($"{GREEN}{BOLD}  LAYER CONTROLS{RESET}"));
            sb.AppendLine(BoxLine(""));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+1", "Toggle Far layer"));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+2", "Toggle Mid layer"));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+3", "Toggle Near layer"));
            sb.AppendLine(BoxLine(""));

            // System
            sb.AppendLine(BoxLine($"{GREEN}{BOLD}  SYSTEM{RESET}"));
            sb.AppendLine(BoxLine(""));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+F5", "Force shader reload"));
            sb.AppendLine(HotkeyLine("Ctrl+Shift+H", "This overlay"));
            sb.AppendLine(BoxLine(""));

            // Separator
            sb.AppendLine($"  {GREEN}{ML}{new string(H, inner)}{MR}{RESET}");

            // License check for upsell or thank-you
            var licenseService = new LicenseService();
            if (!licenseService.IsLicensed)
            {
                sb.AppendLine(BoxLine(""));
                sb.AppendLine(BoxLine($"  {YELLOW}Unlock the full control panel{RESET}"));
                sb.AppendLine(BoxLine($"  {CYAN}matrixshader.com/redpill{RESET}"));
            }
            else
            {
                sb.AppendLine(BoxLine(""));
                sb.AppendLine(BoxLine($"  {GREEN}Red Pill active. Full control unlocked.{RESET}"));
            }

            // Bottom
            sb.AppendLine(BoxLine(""));
            sb.AppendLine($"  {GREEN}{BL}{new string(H, inner)}{BR}{RESET}");
            sb.AppendLine();
            sb.AppendLine($"  {DIM}Press any key to close...{RESET}");

            Console.Write(sb.ToString());
            Console.ReadKey(intercept: true);
            Console.CursorVisible = true;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("HELP", $"Help overlay error: {ex.Message}");
        }
    }

    /// <summary>
    /// Wraps text in box-drawing side borders.
    /// </summary>
    private static string BoxLine(string content)
    {
        // Strip ANSI to calculate visible width
        var visible = StripAnsi(content);
        var padding = BOX_WIDTH - 2 - visible.Length;
        if (padding < 0) padding = 0;
        return $"  {GREEN}{V}{RESET}{content}{new string(' ', padding)}{GREEN}{V}{RESET}";
    }

    /// <summary>
    /// Formats a hotkey line with aligned columns.
    /// </summary>
    private static string HotkeyLine(string key, string desc)
    {
        var keyPadded = key.PadRight(22);
        return BoxLine($"  {CYAN}{keyPadded}{RESET}{WHITE}{desc}{RESET}");
    }

    /// <summary>
    /// Strips ANSI escape sequences for width calculation.
    /// </summary>
    private static string StripAnsi(string input)
    {
        var result = new StringBuilder();
        bool inEscape = false;
        foreach (var c in input)
        {
            if (c == '\x1b') { inEscape = true; continue; }
            if (inEscape) { if (char.IsLetter(c)) inEscape = false; continue; }
            result.Append(c);
        }
        return result.ToString();
    }

    /// <summary>
    /// Spawns a new console window showing the help overlay.
    /// This is called from the background hotkeys process which has no console.
    /// </summary>
    public static void SpawnOverlay()
    {
        try
        {
            var exePath = Environment.ProcessPath;
            if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath))
            {
                DiagnosticLogger.Warn("HELP", "Cannot find own exe path for overlay");
                return;
            }

            var psi = new ProcessStartInfo
            {
                FileName = "wt.exe",
                Arguments = $"-w -1 \"{exePath}\" --help-overlay",
                UseShellExecute = true,
                CreateNoWindow = false
            };

            Process.Start(psi);
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("HELP", $"Failed to spawn overlay: {ex.Message}");
        }
    }
}
