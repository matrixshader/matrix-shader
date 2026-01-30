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

            // Skip splash if --quiet flag
            if (!args.Contains("--quiet") && !args.Contains("-q"))
            {
                await ShowIntro();
            }

            // Launch directly into FallbackMenu
            var menu = new FallbackMenu();
            await menu.RunAsync(CancellationToken.None);

            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\x1b[31mError: {ex.Message}\x1b[0m");
            return 1;
        }
    }

    private static async Task ShowIntro()
    {
        Console.Clear();
        Console.WriteLine();

        // Simple Matrix-style intro
        Console.Write("\x1b[32m");
        await TypewriterAsync(" Wake up, Neo...", 80);
        await Task.Delay(500);

        await TypewriterAsync(" The Matrix has you...", 60);
        await Task.Delay(500);

        Console.WriteLine();
        Console.WriteLine(" MATRIXLITE - Text-based Matrix Rain");
        Console.WriteLine(" ------------------------------------");
        Console.Write("\x1b[0m");

        await Task.Delay(1000);
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
        Console.WriteLine();
        Console.WriteLine("\x1b[90m Controls (during animation):\x1b[0m");
        Console.WriteLine("\x1b[90m   [1-6]          Color presets\x1b[0m");
        Console.WriteLine("\x1b[90m   [E/R]          Speed -/+\x1b[0m");
        Console.WriteLine("\x1b[90m   [D/F]          Density -/+\x1b[0m");
        Console.WriteLine("\x1b[90m   [Enter]        Toggle animation\x1b[0m");
        Console.WriteLine("\x1b[90m   [Q/Escape]     Return to menu / Quit\x1b[0m");
        Console.WriteLine();
    }
}
