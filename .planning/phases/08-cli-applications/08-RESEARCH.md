# Phase 8: CLI Applications - Research

**Researched:** 2026-01-28
**Domain:** CLI entry points, Windows Terminal bootstrap, Matrix-themed UX
**Confidence:** HIGH

## Summary

Phase 8 consolidates three CLI entry points (bluepill.exe, wakeupneo.exe, redpill.exe) with shared bootstrap logic, Matrix-themed presentation, and hidden easter eggs. The existing codebase already has partial implementations in each CLI project - this phase completes them to match PowerShell behavior while adding the theatrics (typewriter effects, Matrix quotes, easter eggs) specified in CONTEXT.md.

The core technical challenge is the shared bootstrap: detecting Windows Terminal, installing it if missing, and creating Matrix profiles on first run. The user-facing challenge is pixel-perfect matching of PowerShell presentation with proper typewriter effects and arrow-key menus.

**Primary recommendation:** Create a shared `CliBootstrap` class in MatrixShader.Core that all three CLIs call on startup. Each CLI keeps its unique behavior (bluepill restores, wakeupneo wizards, redpill controls) but shares the Windows Terminal detection/installation flow.

## Standard Stack

The project already uses the correct stack. No changes needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| .NET 8 | net8.0-windows | Console applications | Native AOT, Windows API access |
| System.Text.Json | Built-in | JSON serialization | AOT-compatible with source generators |
| System.Diagnostics.Process | Built-in | Launch external processes | Standard for CLI operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Microsoft.Extensions.DependencyInjection | Built-in | DI container | Service registration in Program.cs |
| Microsoft.Extensions.Logging | Built-in | Structured logging | Debug output when MATRIX_DEBUG=1 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Spectre.Console | Raw Console.Write | CONTEXT.md requires PowerShell matching; Spectre adds overhead |
| System.CommandLine | Manual arg parsing | Overkill for simple flags (--help, --debug, --morpheus) |

**Important Note:** Current projects reference Spectre.Console but CONTEXT.md specifies "No third-party libraries for TUI (pixel-perfect PowerShell matching)". Remove Spectre.Console dependency during implementation.

## Architecture Patterns

### Recommended Project Structure
```
MatrixShader/src/
├── MatrixShader.Core/
│   ├── Services/
│   │   ├── CliBootstrap.cs          # NEW: Shared bootstrap logic
│   │   ├── WindowLauncher.cs        # NEW: wt.exe launch helpers
│   │   └── [existing services]
│   └── Constants/
│       └── MatrixQuotes.cs          # NEW: Random quote collection
├── MatrixShader.Cli/
│   ├── Bluepill/
│   │   └── Program.cs               # MODIFY: Add theatrics, restore logic
│   ├── WakeupNeo/
│   │   └── Program.cs               # MODIFY: Arrow-key menu, wizard flow
│   └── Redpill/
│       └── Program.cs               # MODIFY: Add easter eggs
```

### Pattern 1: Shared Bootstrap with Result Type
**What:** Common startup logic that returns success/failure with diagnostic info
**When to use:** Every CLI's Main method before its specific behavior
**Example:**
```csharp
// Source: Design pattern for CLI applications
public record BootstrapResult(
    bool Success,
    string? ErrorMessage = null,
    bool WasFirstRun = false,
    int ProfilesCreated = 0);

public static class CliBootstrap
{
    public static async Task<BootstrapResult> InitializeAsync(bool verbose = false)
    {
        // 1. Check Windows Terminal installed
        if (!await IsWindowsTerminalInstalledAsync())
        {
            var installed = await TryInstallWindowsTerminalAsync(verbose);
            if (!installed)
                return new BootstrapResult(false, "Windows Terminal required but not installed");
        }

        // 2. Ensure directories exist
        EnsureDirectories();

        // 3. Create default profiles if first run
        var (wasFirstRun, profilesCreated) = await EnsureMatrixProfilesAsync();

        return new BootstrapResult(true, WasFirstRun: wasFirstRun, ProfilesCreated: profilesCreated);
    }
}
```

### Pattern 2: Typewriter Effect with Cancellation
**What:** Async character-by-character output with Matrix green color
**When to use:** bluepill "There is no spoon...", wakeupneo "Wake up, Neo..."
**Example:**
```csharp
// Source: Console application UX pattern
public static async Task TypewriterAsync(
    string text,
    int charDelayMs = 150,
    CancellationToken ct = default)
{
    Console.Write("\x1b[32m"); // Matrix green
    foreach (char c in text)
    {
        if (ct.IsCancellationRequested) break;
        Console.Write(c);
        await Task.Delay(charDelayMs, ct);
    }
    Console.WriteLine("\x1b[0m"); // Reset
}
```

### Pattern 3: Arrow-Key Menu
**What:** Interactive menu with up/down navigation and Enter selection
**When to use:** wakeupneo Blue Pill/Red Pill choice, window count selection
**Example:**
```csharp
// Source: Console application UX pattern
public static int ArrowKeyMenu(string[] options, string prompt)
{
    int selected = 0;
    ConsoleKey key;

    do
    {
        Console.Clear();
        Console.WriteLine($"\x1b[32m{prompt}\x1b[0m\n");

        for (int i = 0; i < options.Length; i++)
        {
            if (i == selected)
                Console.WriteLine($" > \x1b[1;32m{options[i]}\x1b[0m");
            else
                Console.WriteLine($"   \x1b[90m{options[i]}\x1b[0m");
        }

        key = Console.ReadKey(true).Key;

        if (key == ConsoleKey.UpArrow)
            selected = (selected - 1 + options.Length) % options.Length;
        else if (key == ConsoleKey.DownArrow)
            selected = (selected + 1) % options.Length;

    } while (key != ConsoleKey.Enter);

    return selected;
}
```

### Anti-Patterns to Avoid
- **Using Console.ReadLine for menus:** Breaks the cinematic feel; use ReadKey for immediate response
- **Missing color reset:** Always pair `\x1b[32m` (green) with `\x1b[0m` (reset)
- **Blocking calls in typewriter:** Use async/await to allow cancellation
- **Hardcoding paths:** Use EnvironmentService and ConfigService for all paths

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Windows Terminal detection | Check registry | EnvironmentService.IsWindowsTerminal() + settings.json exists | Already implemented, handles edge cases |
| Profile creation | Direct JSON manipulation | TerminalSettingsService.CreateMatrixProfiles() | Handles atomic writes, recovery |
| Window positioning | Direct SetWindowPos | LayoutService.ApplyLayout() | Border compensation, multi-monitor |
| Window identity | Title parsing | IdentityService.ResolveIdentity() | 4-layer hierarchy, confidence scoring |
| JSON serialization | JsonSerializer.Deserialize | MatrixJsonContext (source-gen) | AOT compatibility |

**Key insight:** The existing services in MatrixShader.Core handle all the hard problems. CLI apps should be thin wrappers that orchestrate these services with appropriate UX.

## Common Pitfalls

### Pitfall 1: winget Silent Failure
**What goes wrong:** winget install fails but returns exit code 0 in some edge cases
**Why it happens:** winget exit codes are not fully documented; user may decline UAC prompt
**How to avoid:** After winget, verify settings.json exists; offer Microsoft Store fallback
**Warning signs:** Bootstrap succeeds but Matrix profiles don't appear in Terminal dropdown

### Pitfall 2: wt.exe Launch vs Runtime Detection
**What goes wrong:** Launching `wt.exe -p "Matrix-1"` succeeds but can't detect the window
**Why it happens:** wt.exe is a launcher that exits immediately; real window is a different process
**How to avoid:** Use Wait-ForNewMatrixWindow pattern from PowerShell (poll for new handle)
**Warning signs:** Window opens but IdentityService.FindMatrixWindows() returns empty

### Pitfall 3: Console Encoding Issues
**What goes wrong:** ANSI escape codes appear as garbage characters
**Why it happens:** Console output mode not set to virtual terminal processing
**How to avoid:** Call SetConsoleMode with ENABLE_VIRTUAL_TERMINAL_PROCESSING on Windows
**Warning signs:** Text shows `[32m` instead of green color

### Pitfall 4: Spectre.Console and Native AOT
**What goes wrong:** Runtime trimming warnings or crashes with Native AOT
**Why it happens:** Spectre.Console uses reflection features incompatible with AOT
**How to avoid:** Use raw ANSI escape codes as specified in CONTEXT.md
**Warning signs:** PublishAot build fails or produces oversized executable

### Pitfall 5: Race Condition in Window Restore
**What goes wrong:** bluepill launches windows but positioning fails
**Why it happens:** Windows not fully initialized when ApplyLayout called
**How to avoid:** Wait for each window handle before proceeding; use polling with timeout
**Warning signs:** Windows appear but overlap or aren't positioned correctly

## Code Examples

Verified patterns from existing codebase and official sources:

### Windows Terminal Detection
```csharp
// Source: Existing EnvironmentService.cs
public static bool IsWindowsTerminalInstalled()
{
    var settingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Packages",
        "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
        "LocalState",
        "settings.json");
    return File.Exists(settingsPath);
}
```

### winget Installation with Fallback
```csharp
// Source: Design pattern from winget documentation
public static async Task<bool> TryInstallWindowsTerminalAsync(bool verbose)
{
    // Try winget first
    try
    {
        var psi = new ProcessStartInfo
        {
            FileName = "winget",
            Arguments = "install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements",
            RedirectStandardOutput = !verbose,
            RedirectStandardError = !verbose,
            UseShellExecute = false,
            CreateNoWindow = !verbose
        };

        using var process = Process.Start(psi);
        if (process == null) return false;

        await process.WaitForExitAsync();

        // Verify installation succeeded
        await Task.Delay(1000); // Allow settings.json to be created
        if (IsWindowsTerminalInstalled())
            return true;
    }
    catch
    {
        // winget not available or failed
    }

    // Fallback: Prompt for Microsoft Store
    Console.Write("\x1b[33mWindows Terminal not found. Install from Microsoft Store? [Y/N]: \x1b[0m");
    var key = Console.ReadKey(intercept: true);
    Console.WriteLine();

    if (key.Key == ConsoleKey.Y)
    {
        // Open Microsoft Store page
        Process.Start(new ProcessStartInfo
        {
            FileName = "ms-windows-store://pdp/?ProductId=9N0DX20HK701",
            UseShellExecute = true
        });

        Console.WriteLine("\x1b[90mPress any key after installation completes...\x1b[0m");
        Console.ReadKey(intercept: true);
        return IsWindowsTerminalInstalled();
    }

    return false;
}
```

### Enable ANSI Escape Codes on Windows
```csharp
// Source: Microsoft Console Virtual Terminal documentation
using System.Runtime.InteropServices;

public static class ConsoleHelper
{
    private const int STD_OUTPUT_HANDLE = -11;
    private const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    [LibraryImport("kernel32.dll", SetLastError = true)]
    private static partial IntPtr GetStdHandle(int nStdHandle);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    public static void EnableAnsiEscapeCodes()
    {
        var handle = GetStdHandle(STD_OUTPUT_HANDLE);
        if (GetConsoleMode(handle, out uint mode))
        {
            SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        }
    }
}
```

### Matrix Quotes Collection
```csharp
// Source: Discretionary implementation per CONTEXT.md
public static class MatrixQuotes
{
    private static readonly string[] Quotes =
    {
        "The Matrix has you...",
        "Follow the white rabbit.",
        "There is no spoon.",
        "Free your mind.",
        "I know kung fu.",
        "Welcome to the real world.",
        "What is the Matrix?",
        "You've been living in a dream world, Neo.",
        "Unfortunately, no one can be told what the Matrix is.",
        "The body cannot live without the mind.",
        "Dodge this.",
        "I can only show you the door.",
        "Everything begins with choice.",
        "There's a difference between knowing the path and walking the path."
    };

    public static string GetRandom()
    {
        return Quotes[Random.Shared.Next(Quotes.Length)];
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Console.ForegroundColor | ANSI escape codes | Windows 10 1511 | 24-bit color support, no flicker |
| Spectre.Console for TUI | Raw Console.Write + ANSI | CONTEXT.md decision | Pixel-perfect PowerShell match, AOT-safe |
| Sleep-based window polling | Async Task.Delay + timeout | .NET 5+ | Cancellable, non-blocking |
| JsonSerializer reflection | Source-generated context | .NET 6+ | Native AOT compatibility |

**Deprecated/outdated:**
- Console.ForegroundColor/BackgroundColor: Limited to 16 colors, causes flicker on color changes
- Thread.Sleep: Blocks the thread, use Task.Delay for async code
- JsonSerializer without source generation: Incompatible with Native AOT

## Claude's Discretion Recommendations

Based on CONTEXT.md's "Claude's Discretion" areas:

### 1. Shared Bootstrap Architecture
**Recommendation:** Common init in CliBootstrap class, minimal per-CLI overrides

Create `MatrixShader.Core.Services.CliBootstrap` with static methods. Each CLI calls `CliBootstrap.InitializeAsync()` before its specific logic. This keeps the bootstrap testable and avoids code duplication while allowing CLIs to remain thin entry points.

### 2. --debug Flag Placement
**Recommendation:** All CLIs support --debug, also honor MATRIX_DEBUG=1

```csharp
// Check both flag and environment variable
bool debugEnabled = args.Contains("--debug") ||
                    Environment.GetEnvironmentVariable("MATRIX_DEBUG") == "1";
if (debugEnabled)
    DiagnosticLogger.Enable();
```

### 3. Exit Codes
**Recommendation:** Standard Unix-style exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error (missing Windows Terminal, invalid args) |
| 2 | User cancelled (pressed Escape or N at prompt) |

### 4. Matrix Quotes Selection
**Recommendation:** 14 iconic movie quotes (see Code Examples above)

Selected for recognizability and thematic fit. Excludes quotes that require context or are less memorable.

### 5. --morpheus Flag Phrasing
**Recommendation:** "Let me tell you why you're here..." style intro with dramatic pauses

```csharp
if (args.Contains("--morpheus"))
{
    await TypewriterAsync("Let me tell you why you're here...", 100);
    await Task.Delay(500);
    await TypewriterAsync("You're here because you know something.", 80);
    await Task.Delay(300);
    // Continue before each major action
}
```

### 6. --agent-smith Chaos Mode
**Recommendation:** Randomize all windows to random colors and speeds, then rapidly cycle

```csharp
// Agent Smith mode: chaos
if (args.Contains("--agent-smith"))
{
    var windows = identityService.FindMatrixWindows();
    foreach (var window in windows)
    {
        var chaosConfig = new ShaderConfig()
            .WithColor(Random.Shared.NextSingle(), Random.Shared.NextSingle(), Random.Shared.NextSingle())
            with { Speed = (float)(Random.Shared.NextDouble() * 2.5 + 0.5) };
        shaderService.SaveShader(window.ShaderIndex, chaosConfig);
    }
    // Optionally: loop and re-randomize every 2 seconds
}
```

## Open Questions

Things that couldn't be fully resolved:

1. **winget Exit Codes**
   - What we know: Exit code 0 generally means success
   - What's unclear: Exact codes for user cancellation vs actual failure
   - Recommendation: Always verify with file existence check, don't rely solely on exit code

2. **Windows Terminal First-Launch Behavior**
   - What we know: settings.json is created when Terminal first runs
   - What's unclear: Whether winget install creates it automatically or requires Terminal launch
   - Recommendation: If settings.json missing after install, launch `wt.exe` once and wait

## Sources

### Primary (HIGH confidence)
- Existing codebase: EnvironmentService.cs, TerminalSettingsService.cs, TuiRenderer.cs
- [Microsoft Console Virtual Terminal Sequences](https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences)
- [winget list command](https://learn.microsoft.com/en-us/windows/package-manager/winget/list)

### Secondary (MEDIUM confidence)
- [winget-cli GitHub](https://github.com/microsoft/winget-cli)
- [ANSI escape code - Wikipedia](https://en.wikipedia.org/wiki/ANSI_escape_code)

### Tertiary (LOW confidence)
- General .NET 8 console application patterns (training data)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - using existing codebase patterns
- Architecture: HIGH - extending proven service architecture
- Pitfalls: HIGH - documented from PowerShell experience in CLAUDE.md

**Research date:** 2026-01-28
**Valid until:** 2026-02-28 (30 days - stable .NET ecosystem)
