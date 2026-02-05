using System.Text;
using MatrixShader.Lite;

namespace MatrixShader.Cli.MatrixLite;

/// <summary>
/// MatrixLite - Standalone text-based Matrix rain effect.
/// Works in any terminal with ANSI and Unicode support.
/// </summary>
public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        // Handle help
        if (args.Contains("--help") || args.Contains("-h"))
        {
            ShowHelp();
            return 0;
        }

        try
        {
            Console.OutputEncoding = Encoding.UTF8;

            // Skip intro if --quiet flag or --menu flag
            var skipIntro = args.Contains("--quiet") || args.Contains("-q");
            var directMenu = args.Contains("--menu") || args.Contains("-m");
            var directRain = args.Contains("--rain") || args.Contains("-r");

            if (directRain)
            {
                // Direct rain mode (for background/scripted use)
                // This mode exits when user presses ESC/Q/Ctrl+C
                var directRenderer = new FallbackMenu();
                await directRenderer.StartRainDirectAsync(CancellationToken.None);
                return 0;
            }

            if (directMenu)
            {
                // Direct to menu (skip intro entirely)
                // Returns to pill choice when user exits menu
                await RunMenuLoopAsync(skipIntro: true);
                return 0;
            }

            // Normal flow: intro -> pill choice -> effect/menu -> back to pill choice
            await RunMenuLoopAsync(skipIntro);

            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mError: {ex.Message}\x1b[0m");
            return 1;
        }
    }

    /// <summary>
    /// Runs the main menu loop. User can choose Blue Pill / Red Pill / Exit.
    /// After effects stop (ESC/Q/Ctrl+C), returns to pill choice.
    /// </summary>
    private static async Task RunMenuLoopAsync(bool skipIntro)
    {
        var showIntro = !skipIntro;

        while (true)
        {
            if (showIntro)
            {
                await ShowIntro();
            }
            showIntro = false; // Only show intro once

            // Show pill choice (or exit option)
            var choice = await ShowPillChoiceAsync(showExitOption: true);

            if (choice == PillChoice.Exit)
            {
                Console.Clear();
                Console.WriteLine("\x1b[32m  You take the exit... The story ends.\x1b[0m");
                Console.WriteLine();
                break;
            }

            if (choice == PillChoice.BluePill)
            {
                // Blue Pill: Straight to the Matrix - start rain immediately
                // Returns here when user presses ESC/Q/Ctrl+C
                Console.Clear();
                var blueMenu = new FallbackMenu();
                await blueMenu.StartRainDirectAsync(CancellationToken.None);
                // After effect ends, loop continues to show pill choice again
            }
            else // RedPill
            {
                // Red Pill: show full control menu
                // Returns here when user presses Q/ESC from menu
                var redMenu = new FallbackMenu();
                await redMenu.RunAsync(CancellationToken.None);
                // After menu exits, loop continues to show pill choice again
            }

            Console.Clear();
        }
    }

    private enum PillChoice { BluePill, RedPill, Exit }

    private static async Task ShowIntro()
    {
        Console.Clear();
        Console.WriteLine();

        // Matrix-style intro
        Console.Write("\x1b[32m");
        await TypewriterAsync(" Wake up, Neo...", 80);
        await Task.Delay(800);

        await TypewriterAsync(" The Matrix has you...", 60);
        await Task.Delay(800);

        await TypewriterAsync(" Follow the white rabbit.", 60);
        await Task.Delay(1000);

        Console.WriteLine();
        Console.Write("\x1b[0m");
    }

    private static async Task<PillChoice> ShowPillChoiceAsync(bool showExitOption = false)
    {
        Console.Clear();
        Console.WriteLine();
        Console.WriteLine("\x1b[32m  +==================================================+\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m  \x1b[1;32m\"This is your last chance. After this,\x1b[0m          \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m   \x1b[1;32mthere is no turning back.\"\x1b[0m                     \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  +--------------------------------------------------+\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m  \x1b[34m[B] BLUE PILL\x1b[0m - Straight to the Matrix          \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m      Start the rain immediately                  \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m  \x1b[31m[R] RED PILL\x1b[0m - Control the Code                  \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m      Open the control menu                       \x1b[32m|\x1b[0m");
        Console.WriteLine("\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m");
        if (showExitOption)
        {
            Console.WriteLine("\x1b[32m  |\x1b[0m  \x1b[90m[Q] EXIT\x1b[0m - Leave the Matrix                     \x1b[32m|\x1b[0m");
            Console.WriteLine("\x1b[32m  |\x1b[0m                                                  \x1b[32m|\x1b[0m");
        }
        Console.WriteLine("\x1b[32m  +==================================================+\x1b[0m");
        Console.WriteLine();
        var promptSuffix = showExitOption ? "[B/R/Q]: " : "[B/R]: ";
        Console.Write($"  \x1b[90mChoose your path {promptSuffix}\x1b[0m");

        while (true)
        {
            var key = Console.ReadKey(intercept: true);
            if (key.Key == ConsoleKey.B)
            {
                Console.WriteLine("\x1b[34mBlue Pill\x1b[0m");
                await Task.Delay(500);
                return PillChoice.BluePill;
            }
            if (key.Key == ConsoleKey.R)
            {
                Console.WriteLine("\x1b[31mRed Pill\x1b[0m");
                await Task.Delay(500);
                return PillChoice.RedPill;
            }
            // Enter defaults to Blue Pill
            if (key.Key == ConsoleKey.Enter)
            {
                Console.WriteLine("\x1b[34mBlue Pill\x1b[0m");
                await Task.Delay(500);
                return PillChoice.BluePill;
            }
            // Q or Escape to exit (if option is shown)
            if (showExitOption && (key.Key == ConsoleKey.Q || key.Key == ConsoleKey.Escape))
            {
                Console.WriteLine("\x1b[90mExit\x1b[0m");
                await Task.Delay(500);
                return PillChoice.Exit;
            }
        }
    }

    private static async Task TypewriterAsync(string text, int charDelayMs)
    {
        foreach (char c in text)
        {
            Console.Write(c);
            await Task.Delay(charDelayMs);
        }
        Console.WriteLine();
    }

    private static void ShowHelp()
    {
        Console.WriteLine();
        Console.WriteLine("\x1b[32m MATRIXLITE - Text-based Matrix Rain\x1b[0m");
        Console.WriteLine();
        Console.WriteLine("\x1b[90m Usage: matrixlite [options]\x1b[0m");
        Console.WriteLine();
        Console.WriteLine("\x1b[90m Options:\x1b[0m");
        Console.WriteLine("\x1b[90m   --help, -h     Show this help message\x1b[0m");
        Console.WriteLine("\x1b[90m   --quiet, -q    Skip intro animation\x1b[0m");
        Console.WriteLine("\x1b[90m   --menu, -m     Go directly to control menu\x1b[0m");
        Console.WriteLine("\x1b[90m   --rain, -r     Start rain immediately (for scripts)\x1b[0m");
        Console.WriteLine();
        Console.WriteLine("\x1b[90m Controls (during animation):\x1b[0m");
        Console.WriteLine("\x1b[90m   [1-6]          Color presets\x1b[0m");
        Console.WriteLine("\x1b[90m   [E/R]          Speed -/+\x1b[0m");
        Console.WriteLine("\x1b[90m   [D/F]          Density -/+\x1b[0m");
        Console.WriteLine("\x1b[90m   [Q/Escape]     Return to menu / Quit\x1b[0m");
        Console.WriteLine();
    }
}
