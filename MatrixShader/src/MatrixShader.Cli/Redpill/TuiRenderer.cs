using System.Text;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// Static rendering methods for pixel-perfect TUI output matching PowerShell format.
/// Uses raw ANSI escape codes for exact control over spacing, colors, and alignment.
/// All methods return strings for buffered rendering (write-once pattern).
/// </summary>
public static class TuiRenderer
{
    #region Constants

    /// <summary>Dynamic terminal width for padding lines (minimum 80).</summary>
    public static int ClearWidth => Math.Max(80, Console.WindowWidth);

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

    /// <summary>Magenta foreground color.</summary>
    public const string MAGENTA = "\x1b[35m";

    #endregion

    #region Core Rendering Methods

    /// <summary>
    /// Creates a color swatch using RGB background color.
    /// </summary>
    public static string ColorSwatch(float r, float g, float b, int width = 2)
    {
        var r8 = (int)Math.Clamp(r * 255, 0, 255);
        var g8 = (int)Math.Clamp(g * 255, 0, 255);
        var b8 = (int)Math.Clamp(b * 255, 0, 255);
        return $"\x1b[48;2;{r8};{g8};{b8}m{new string(' ', width)}\x1b[0m";
    }

    /// <summary>
    /// Creates a progress bar with green filled and gray empty portions.
    /// </summary>
    public static string ProgressBar(float val, float min, float max, int width = 15)
    {
        var pct = Math.Clamp((val - min) / (max - min), 0f, 1f);
        var filled = (int)(pct * width);
        var empty = width - filled;
        return $"\x1b[32m{new string('=', filled)}\x1b[90m{new string('-', empty)}\x1b[0m";
    }

    /// <summary>
    /// Returns a parameter row string with consistent formatting.
    /// Format: " [keys] label  value bar"
    /// </summary>
    public static string FormatParameterRow(string keys, string label, string value, float val, float min, float max)
    {
        return $" [{keys}] {label,-8} {value,4} {ProgressBar(val, min, max)}";
    }

    /// <summary>
    /// Returns layer toggle status string with color-coded ON/off indicator.
    /// </summary>
    public static string FormatLayerStatus(string key, string name, bool enabled)
    {
        var status = enabled ? "ON " : "off";
        var color = enabled ? GREEN : GRAY;
        return $" [{key}] {name}: {color}{status}{RESET}";
    }

    /// <summary>
    /// Returns a section header string with white text.
    /// </summary>
    public static string FormatSectionHeader(string title)
    {
        return $" {WHITE}{title}{RESET}";
    }

    #endregion

    #region Tab and Preset Rendering Methods

    /// <summary>
    /// Returns the tab bar string showing all Matrix shader windows.
    /// </summary>
    public static string FormatTabBar(
        IReadOnlyList<(int slot, float r, float g, float b)> tabs,
        int activeSlot)
    {
        var sb = new StringBuilder();
        sb.Append(" TABS: ");
        if (tabs.Count == 0)
        {
            sb.Append($"{GRAY}(no Matrix windows detected){RESET}");
        }
        else
        {
            foreach (var (slot, r, g, b) in tabs)
            {
                if (slot == activeSlot)
                {
                    sb.Append($"{YELLOW}[{slot}]{RESET}");
                }
                else
                {
                    sb.Append($"{GRAY} {slot} {RESET}");
                }
                sb.Append(ColorSwatch(r, g, b, 1));
                sb.Append(' ');
            }
        }
        return sb.ToString();
    }

    /// <summary>
    /// Returns the color preset row string with numbered swatches.
    /// </summary>
    public static string FormatColorPresets()
    {
        return $" [1]{ColorSwatch(0, 1, 0.3f)}Green [2]{ColorSwatch(0, 0.6f, 1)}Blue [3]{ColorSwatch(1, 0.1f, 0.1f)}Red [4]{ColorSwatch(0.7f, 0, 1)}Purple [5]{ColorSwatch(1, 0.7f, 0)}Gold [6]{ColorSwatch(0, 0.9f, 0.9f)}Teal";
    }

    /// <summary>
    /// Returns the header string with title and dirty indicator.
    /// </summary>
    public static string FormatHeader(int slot, bool dirty)
    {
        var dirtyMark = dirty ? "*" : " ";
        return $" {RED}RED PILL{RESET}{dirtyMark}- Tab {slot}";
    }

    /// <summary>
    /// Appends the footer lines with launch, save controls, and hotkey help hint.
    /// </summary>
    public static void AppendFooter(StringBuilder sb, int cw, int launchCount, bool canLaunch, bool glitchEnabled)
    {
        var enterAction = launchCount > 0
            ? $"[ENTER] Deploy {launchCount} window(s)"
            : "[ENTER] (set count first)";
        var enterColor = launchCount > 0 ? YELLOW : GRAY;
        AppendPaddedLine(sb, cw, $" {enterColor}{enterAction}{RESET}  {GRAY}[0] Reset  [ESC] Quit{RESET}");
        AppendPaddedLine(sb, cw, $" {GRAY}[Shift+H] Configure hotkeys  [?] Help{RESET}");
        AppendPaddedLine(sb, cw, $" {GREEN}All changes apply instantly{RESET}");
    }

    #endregion

    #region Buffer Helpers

    /// <summary>
    /// Appends a line padded to ClearWidth to prevent residual text.
    /// Strips ANSI codes for accurate visible-length calculation.
    /// </summary>
    public static void AppendPaddedLine(StringBuilder sb, int cw, string content)
    {
        // Calculate visible length (strip ANSI escape sequences)
        var visibleLen = VisibleLength(content);
        var padding = Math.Max(0, cw - visibleLen);
        sb.Append(content);
        sb.Append(' ', padding);
        sb.Append('\n');
    }

    /// <summary>
    /// Calculates the visible length of a string (excluding ANSI escape sequences).
    /// </summary>
    private static int VisibleLength(string s)
    {
        int len = 0;
        bool inEscape = false;
        for (int i = 0; i < s.Length; i++)
        {
            if (s[i] == '\x1b')
            {
                inEscape = true;
                continue;
            }
            if (inEscape)
            {
                if (char.IsLetter(s[i]))
                    inEscape = false;
                continue;
            }
            len++;
        }
        return len;
    }

    /// <summary>
    /// Appends blank padded lines to fill remaining visible rows.
    /// </summary>
    public static void AppendBlankLines(StringBuilder sb, int cw, int count)
    {
        var blank = new string(' ', cw);
        for (int i = 0; i < count; i++)
        {
            sb.Append(blank);
            sb.Append('\n');
        }
    }

    #endregion
}
