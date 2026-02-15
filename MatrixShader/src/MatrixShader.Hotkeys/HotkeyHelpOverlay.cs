using System.Diagnostics;
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
    private const string GREEN = "\x1b[32m";
    private const string DIM = "\x1b[90m";
    private const string YELLOW = "\x1b[33m";
    private const string CYAN = "\x1b[36m";
    private const string RESET = "\x1b[0m";
    private const string BOLD = "\x1b[1m";

    /// <summary>
    /// Shows the help overlay in the current console.
    /// Called from the hotkeys process via a spawned conhost.
    /// </summary>
    public static void Show()
    {
        try
        {
            // Enable ANSI
            Console.OutputEncoding = Encoding.UTF8;

            Console.Clear();
            Console.CursorVisible = false;

            var sb = new StringBuilder();

            sb.AppendLine();
            sb.AppendLine($" {GREEN}{BOLD}MATRIX SHADER — HOTKEY REFERENCE{RESET}");
            sb.AppendLine($" {DIM}════════════════════════════════════════════{RESET}");
            sb.AppendLine();

            sb.AppendLine($" {GREEN}GLOBAL HOTKEYS{RESET} {DIM}(active when Matrix windows exist){RESET}");
            sb.AppendLine();
            sb.AppendLine($"   {CYAN}Ctrl+Shift+Left/Right{RESET}   Rotate windows left/right");
            sb.AppendLine($"   {CYAN}Ctrl+Shift+L{RESET}            Cycle layout mode (Pillars/Quads)");
            sb.AppendLine($"   {CYAN}Ctrl+Shift+B{RESET}            Toggle transparency (85%/100%)");
            sb.AppendLine($"   {CYAN}Ctrl+Shift+J/K{RESET}          Decrease/Increase opacity");
            sb.AppendLine($"   {CYAN}Ctrl+Shift+Up/Down{RESET}      Increase/Decrease rain speed");
            sb.AppendLine($"   {CYAN}Ctrl+Shift+1/2/3{RESET}        Toggle Far/Mid/Near layers");
            sb.AppendLine($"   {CYAN}Ctrl+Shift+H{RESET}            This help overlay");
            sb.AppendLine();

            sb.AppendLine($" {GREEN}CONTROL PANEL KEYS{RESET} {DIM}(inside redpill TUI){RESET}");
            sb.AppendLine();
            sb.AppendLine($"   {CYAN}[1-6]{RESET}       Agent colors (Green/Blue/Red/Purple/Gold/Teal)");
            sb.AppendLine($"   {CYAN}[Q/W]{RESET}       Red -/+      {CYAN}[A/S]{RESET} Green -/+    {CYAN}[Z/X]{RESET} Blue -/+");
            sb.AppendLine($"   {CYAN}[E/R]{RESET}       Speed -/+    {CYAN}[D/F]{RESET} Glow -/+");
            sb.AppendLine($"   {CYAN}[C/V]{RESET}       Width -/+    {CYAN}[T/Y]{RESET} Trail -/+    {CYAN}[G/H]{RESET} Density -/+");
            sb.AppendLine($"   {CYAN}[7/8/9]{RESET}     Toggle layers (Far/Mid/Near)");
            sb.AppendLine($"   {CYAN}[B]{RESET}         Transparency  {CYAN}[K/L]{RESET} Opacity -/+");
            sb.AppendLine($"   {CYAN}[-/+]{RESET}       Deploy count  {CYAN}[Enter]{RESET} Deploy windows");
            sb.AppendLine($"   {CYAN}[P]{RESET}         Save shader   {CYAN}[0]{RESET} Reset to defaults");
            sb.AppendLine($"   {CYAN}[Shift+G]{RESET}   Toggle Glitch {CYAN}[Shift+L]{RESET} Cycle layout");
            sb.AppendLine($"   {CYAN}[TAB]{RESET}       Switch tabs   {CYAN}[ESC]{RESET} Quit");
            sb.AppendLine();

            // Check license for upsell footer
            var licenseService = new LicenseService();
            if (!licenseService.IsLicensed)
            {
                sb.AppendLine($" {DIM}════════════════════════════════════════════{RESET}");
                sb.AppendLine($" {YELLOW}Unlock the Red Pill control panel — $5{RESET}");
                sb.AppendLine($" {CYAN}https://matrixshader.com/redpill{RESET}");
                sb.AppendLine();
            }

            sb.AppendLine($" {DIM}Press any key to close...{RESET}");

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
    /// Spawns a new console window showing the help overlay.
    /// This is called from the background hotkeys process which has no console.
    /// </summary>
    public static void SpawnOverlay()
    {
        try
        {
            // Find our own exe to re-invoke with --help-overlay flag
            var exePath = Environment.ProcessPath;
            if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath))
            {
                DiagnosticLogger.Warn("HELP", "Cannot find own exe path for overlay");
                return;
            }

            var psi = new ProcessStartInfo
            {
                FileName = exePath,
                Arguments = "--help-overlay",
                UseShellExecute = true,  // Creates new console window
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
