using System.Runtime.InteropServices;

namespace MatrixShader.Core.Helpers;

/// <summary>
/// Console utilities for Matrix CLI applications.
/// Enables ANSI escape codes and provides Matrix-style output helpers.
/// </summary>
public static partial class ConsoleHelper
{
    private const int STD_OUTPUT_HANDLE = -11;
    private const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    // Matrix green ANSI code
    private const string MATRIX_GREEN = "\x1b[32m";
    private const string MATRIX_BRIGHT_GREEN = "\x1b[92m";
    private const string RESET = "\x1b[0m";
    private const string DIM = "\x1b[90m";
    private const string WARNING_YELLOW = "\x1b[33m";

    [LibraryImport("kernel32.dll", SetLastError = true)]
    private static partial IntPtr GetStdHandle(int nStdHandle);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    /// <summary>
    /// Enables ANSI escape code processing on Windows console.
    /// Must be called before using any ANSI escape codes.
    /// </summary>
    /// <returns>True if ANSI codes are now enabled</returns>
    public static bool EnableAnsiEscapeCodes()
    {
        if (!OperatingSystem.IsWindows())
            return true; // Unix terminals support ANSI natively

        try
        {
            var handle = GetStdHandle(STD_OUTPUT_HANDLE);
            if (handle == IntPtr.Zero)
                return false;

            if (!GetConsoleMode(handle, out uint mode))
                return false;

            return SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Writes text in Matrix green color.
    /// </summary>
    public static void WriteMatrixGreen(string text)
    {
        Console.Write($"{MATRIX_GREEN}{text}{RESET}");
    }

    /// <summary>
    /// Writes a line in Matrix green color.
    /// </summary>
    public static void WriteLineMatrixGreen(string text)
    {
        Console.WriteLine($"{MATRIX_GREEN}{text}{RESET}");
    }

    /// <summary>
    /// Writes text in bright Matrix green (for headers/emphasis).
    /// </summary>
    public static void WriteBrightGreen(string text)
    {
        Console.Write($"{MATRIX_BRIGHT_GREEN}{text}{RESET}");
    }

    /// <summary>
    /// Writes a line in bright Matrix green.
    /// </summary>
    public static void WriteLineBrightGreen(string text)
    {
        Console.WriteLine($"{MATRIX_BRIGHT_GREEN}{text}{RESET}");
    }

    /// <summary>
    /// Writes dimmed/gray text.
    /// </summary>
    public static void WriteDim(string text)
    {
        Console.Write($"{DIM}{text}{RESET}");
    }

    /// <summary>
    /// Writes a dimmed line.
    /// </summary>
    public static void WriteLineDim(string text)
    {
        Console.WriteLine($"{DIM}{text}{RESET}");
    }

    /// <summary>
    /// Clears the console and resets cursor.
    /// </summary>
    public static void ClearScreen()
    {
        Console.Clear();
        Console.SetCursorPosition(0, 0);
    }

    /// <summary>
    /// Writes a warning line in yellow color.
    /// </summary>
    public static void WriteLineWarning(string text)
    {
        Console.WriteLine($"{WARNING_YELLOW}{text}{RESET}");
    }

    /// <summary>
    /// Writes warning text in yellow color.
    /// </summary>
    public static void WriteWarning(string text)
    {
        Console.Write($"{WARNING_YELLOW}{text}{RESET}");
    }

    /// <summary>
    /// Displays the command reference banner shown at CLI exit points.
    /// </summary>
    public static void ShowCommandBanner()
    {
        Console.WriteLine();
        Console.WriteLine($" {DIM}COMMANDS{RESET}");
        Console.WriteLine($"  {MATRIX_GREEN}wakeupneo{RESET}          {DIM}Start here{RESET}");
        Console.WriteLine($"  {MATRIX_GREEN}construct{RESET}          {DIM}Launch individual Matrix terminal (--help for colors){RESET}");
        Console.WriteLine($"  {MATRIX_GREEN}bluepill{RESET}           {DIM}Quickly relaunch last saved settings{RESET}");
        Console.WriteLine($"  {MATRIX_GREEN}redpill{RESET}            {DIM}Full control panel (fine tuning){RESET}");
        Console.WriteLine($"  {MATRIX_GREEN}matrixlite{RESET}         {DIM}Visual effect only{RESET}");
    }
}
