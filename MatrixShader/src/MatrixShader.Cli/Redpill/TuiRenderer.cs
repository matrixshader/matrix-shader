namespace MatrixShader.Cli.Redpill;

/// <summary>
/// Static rendering methods for pixel-perfect TUI output matching PowerShell format.
/// Uses raw ANSI escape codes for exact control over spacing, colors, and alignment.
/// </summary>
public static class TuiRenderer
{
    #region Constants

    /// <summary>Standard terminal width for padding lines to prevent content overlap.</summary>
    public const int ClearWidth = 80;

    #endregion

    #region ANSI Escape Codes

    /// <summary>Escape character for ANSI sequences.</summary>
    public const string ESC = "\x1b";

    /// <summary>Reset all formatting to defaults.</summary>
    public const string RESET = "\x1b[0m";

    /// <summary>Green foreground color.</summary>
    public const string GREEN = "\x1b[32m";

    /// <summary>Gray/bright black foreground color.</summary>
    public const string GRAY = "\x1b[90m";

    /// <summary>Yellow foreground color.</summary>
    public const string YELLOW = "\x1b[33m";

    /// <summary>Cyan foreground color.</summary>
    public const string CYAN = "\x1b[36m";

    /// <summary>Red foreground color.</summary>
    public const string RED = "\x1b[31m";

    /// <summary>White foreground color.</summary>
    public const string WHITE = "\x1b[37m";

    /// <summary>Dim/faint text modifier.</summary>
    public const string DIM = "\x1b[2m";

    #endregion

    #region Core Rendering Methods

    /// <summary>
    /// Creates a color swatch using RGB background color.
    /// Matches PowerShell Get-ColorSwatch function output.
    /// </summary>
    /// <param name="r">Red component (0.0 to 1.0).</param>
    /// <param name="g">Green component (0.0 to 1.0).</param>
    /// <param name="b">Blue component (0.0 to 1.0).</param>
    /// <param name="width">Number of space characters for swatch width.</param>
    /// <returns>ANSI escape sequence for colored background block.</returns>
    public static string ColorSwatch(float r, float g, float b, int width = 2)
    {
        var r8 = (int)Math.Clamp(r * 255, 0, 255);
        var g8 = (int)Math.Clamp(g * 255, 0, 255);
        var b8 = (int)Math.Clamp(b * 255, 0, 255);
        return $"\x1b[48;2;{r8};{g8};{b8}m{new string(' ', width)}\x1b[0m";
    }

    /// <summary>
    /// Creates a progress bar with green filled and gray empty portions.
    /// Matches PowerShell Bar function output.
    /// </summary>
    /// <param name="val">Current value.</param>
    /// <param name="min">Minimum value.</param>
    /// <param name="max">Maximum value.</param>
    /// <param name="width">Total bar width in characters.</param>
    /// <returns>ANSI escape sequence for progress bar.</returns>
    public static string ProgressBar(float val, float min, float max, int width = 15)
    {
        var pct = Math.Clamp((val - min) / (max - min), 0f, 1f);
        var filled = (int)(pct * width);
        var empty = width - filled;
        return $"\x1b[32m{new string('=', filled)}\x1b[90m{new string('-', empty)}\x1b[0m";
    }

    /// <summary>
    /// Writes a parameter row with consistent formatting.
    /// Format: " [keys] label  value bar"
    /// </summary>
    /// <param name="keys">Hotkey characters (e.g., "Q/W").</param>
    /// <param name="label">Parameter label (e.g., "Red").</param>
    /// <param name="value">Formatted value string.</param>
    /// <param name="val">Numeric value for progress bar.</param>
    /// <param name="min">Minimum value for progress bar.</param>
    /// <param name="max">Maximum value for progress bar.</param>
    public static void WriteParameterRow(string keys, string label, string value, float val, float min, float max)
    {
        // Format: " [keys] label  value bar"
        // Value is left-padded to 4 chars for alignment
        Console.Write($" [{keys}] {label,-8} {value,4} {ProgressBar(val, min, max)}\n");
    }

    /// <summary>
    /// Writes layer toggle status with color-coded ON/off indicator.
    /// </summary>
    /// <param name="key">Hotkey for the layer.</param>
    /// <param name="name">Layer name (e.g., "Far", "Mid", "Near").</param>
    /// <param name="enabled">Whether the layer is enabled.</param>
    public static void WriteLayerStatus(string key, string name, bool enabled)
    {
        var status = enabled ? "ON " : "off";
        var color = enabled ? GREEN : GRAY;
        Console.Write($" [{key}] {name}: {color}{status}{RESET}");
    }

    /// <summary>
    /// Writes a section header with white text.
    /// </summary>
    /// <param name="title">Section title text.</param>
    public static void WriteSectionHeader(string title)
    {
        Console.WriteLine($" {WHITE}{title}{RESET}");
    }

    #endregion

    #region Tab and Preset Rendering Methods

    /// <summary>
    /// Writes the tab bar showing all Matrix shader windows.
    /// Active tab shows in yellow brackets, inactive tabs in gray.
    /// Each tab has a color swatch showing the shader's current color.
    /// </summary>
    /// <param name="tabs">List of tabs with slot number and RGB color values.</param>
    /// <param name="activeSlot">Currently active slot number.</param>
    public static void WriteTabBar(
        IReadOnlyList<(int slot, float r, float g, float b)> tabs,
        int activeSlot)
    {
        Console.Write(" TABS: ");
        if (tabs.Count == 0)
        {
            Console.Write($"{GRAY}(no Matrix windows detected){RESET}");
        }
        else
        {
            foreach (var (slot, r, g, b) in tabs)
            {
                if (slot == activeSlot)
                {
                    Console.Write($"{YELLOW}[{slot}]{RESET}");
                }
                else
                {
                    Console.Write($"{GRAY} {slot} {RESET}");
                }
                Console.Write(ColorSwatch(r, g, b, 1));
                Console.Write(" ");
            }
        }
        Console.WriteLine();
    }

    /// <summary>
    /// Writes the color preset row with numbered swatches.
    /// </summary>
    public static void WriteColorPresets()
    {
        Console.WriteLine($" [1]{ColorSwatch(0, 1, 0.3f)}Green [2]{ColorSwatch(0, 0.6f, 1)}Cyan [3]{ColorSwatch(1, 0.1f, 0.1f)}Red [4]{ColorSwatch(0.7f, 0, 1)}Purple [5]{ColorSwatch(1, 0.7f, 0)}Gold [6]{ColorSwatch(0, 0.9f, 0.9f)}Teal");
    }

    /// <summary>
    /// Writes the header line with title and dirty indicator.
    /// </summary>
    /// <param name="slot">Current tab slot number.</param>
    /// <param name="dirty">Whether there are unsaved changes.</param>
    public static void WriteHeader(int slot, bool dirty)
    {
        var dirtyMark = dirty ? "*" : " ";
        Console.WriteLine($" {RED}RED PILL{RESET}{dirtyMark}- Tab {slot}");
        Console.WriteLine();
    }

    /// <summary>
    /// Writes the footer with launch, save controls, and hotkey help hint.
    /// </summary>
    /// <param name="launchCount">Number of windows to launch (0 shows disabled).</param>
    /// <param name="canLaunch">Whether launching is available.</param>
    public static void WriteFooter(int launchCount, bool canLaunch)
    {
        var enterAction = launchCount > 0
            ? $"[ENTER] Launch {launchCount} window(s)"
            : "[ENTER] (set count first)";
        var enterColor = launchCount > 0 ? YELLOW : GRAY;
        Console.WriteLine($" {enterColor}{enterAction}{RESET}  {YELLOW}[P] Save shader{RESET}".PadRight(ClearWidth));
        Console.WriteLine($" {GRAY}[0] Reset  [ESC] Quit{RESET}".PadRight(ClearWidth));
        Console.WriteLine();
        Console.WriteLine($" {GRAY}[Shift+H] Configure hotkeys  [?] Help{RESET}".PadRight(ClearWidth));
        Console.WriteLine($" {GRAY}Shader changes apply automatically when saved (hot-reload){RESET}".PadRight(ClearWidth));
    }

    #endregion
}
