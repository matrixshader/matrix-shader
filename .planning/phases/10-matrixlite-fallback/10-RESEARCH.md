# Phase 10: MatrixLite Fallback - Research

**Researched:** 2026-01-30
**Domain:** ANSI Console Rendering / Graceful Degradation
**Confidence:** HIGH

## Summary

Research for Phase 10 reveals that MatrixLite implementation is substantially complete - approximately 80% of the functionality exists in the codebase. The `TextMatrixRenderer`, `Column`, and `FallbackMenu` classes in `MatrixShader.Lite` already provide movie-accurate Katakana characters, 24-bit RGB ANSI color support, all 6 color presets, and a functional interactive menu.

The primary remaining work is integration: extending graceful degradation to `bluepill.exe` and `wakeupneo.exe`, and optionally creating a standalone `matrixlite.exe` for explicit non-WT usage. The renderer's performance approach (StringBuilder buffering with single Console.Write per frame) is the correct pattern for ANSI terminal animation.

**Primary recommendation:** Complete integration of existing MatrixLite components into all CLI entry points, add terminal resize handling, and optionally create standalone matrixlite.exe.

## Standard Stack

The phase uses no external libraries - all functionality built on .NET 8 base class libraries.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| System.Console | .NET 8 | Terminal I/O | Built-in, AOT compatible |
| System.Text.StringBuilder | .NET 8 | Frame buffer construction | Built-in, pre-allocation support |
| System.Text.Encoding.UTF8 | .NET 8 | Katakana character support | Built-in, required for Unicode output |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| MatrixShader.Core | Internal | KatakanaChars, ColorPresets, ShaderConfig | Shared constants and models |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw Console.Write | Spectre.Console | Heavier dependency, not AOT friendly |
| StringBuilder | Span<char> stackalloc | More complex, marginal gains for this use case |
| Polling Console.WindowWidth | P/Invoke SIGWINCH/WINDOW_BUFFER_SIZE_EVENT | More complex, polling sufficient for resize adaptation |

**Installation:** No additional packages required.

## Architecture Patterns

### Existing Project Structure
```
MatrixShader/src/
├── MatrixShader.Core/
│   ├── Constants/
│   │   ├── KatakanaChars.cs     # Movie-accurate character set (63 chars)
│   │   └── ColorPresets.cs      # 6 presets + MatrixColor with ToRgb(), ToAnsiFg()
│   └── Services/
│       └── EnvironmentService.cs # IsWindowsTerminal(), HasAnsiSupport()
├── MatrixShader.Lite/
│   ├── TextMatrixRenderer.cs    # Core renderer (226 lines)
│   ├── Column.cs                # Single falling column (124 lines)
│   └── FallbackMenu.cs          # Interactive menu (231 lines)
└── MatrixShader.Cli/
    ├── Redpill/Program.cs       # Has graceful degradation
    ├── Bluepill/Program.cs      # NEEDS graceful degradation
    └── WakeupNeo/Program.cs     # NEEDS graceful degradation
```

### Pattern 1: Double-Buffered ANSI Rendering
**What:** Build entire frame in StringBuilder, output in single Console.Write
**When to use:** Any terminal animation to avoid flicker
**Example:**
```csharp
// Source: MatrixShader.Lite/TextMatrixRenderer.cs
private readonly StringBuilder _buffer;

public TextMatrixRenderer(int? width = null, int? height = null)
{
    _width = width ?? Console.WindowWidth;
    _height = height ?? Console.WindowHeight;
    // Pre-allocate for width * height * ~30 bytes per cell (ANSI codes)
    _buffer = new StringBuilder(_width * _height * 30);
}

public void RenderFrame()
{
    _buffer.Clear();
    _buffer.Append(Home);  // "\x1b[H"

    // Build frame content...

    // Single write minimizes flicker
    Console.Write(_buffer.ToString());
}
```

### Pattern 2: Environment Detection with Graceful Fallback
**What:** Check WT_SESSION env var, fall back to Lite mode if not present
**When to use:** Any CLI entry point
**Example:**
```csharp
// Source: MatrixShader.Core/Services/EnvironmentService.cs
public RenderMode DetectRenderMode()
{
    if (IsWindowsTerminal())
        return RenderMode.Full;

    if (OperatingSystem.IsWindows() && HasConsole())
        return RenderMode.Lite;

    if (HasAnsiSupport())
        return RenderMode.Lite;

    return RenderMode.Headless;
}

public static bool IsWindowsTerminal()
{
    var wtSession = Environment.GetEnvironmentVariable("WT_SESSION");
    return !string.IsNullOrEmpty(wtSession);
}
```

### Pattern 3: Color with 24-bit ANSI
**What:** Use \x1b[38;2;R;G;Bm for true color foreground
**When to use:** Any colored text in ANSI-capable terminal
**Example:**
```csharp
// Source: MatrixShader.Lite/TextMatrixRenderer.cs
// Head character - bright white
_buffer.Append($"\x1b[38;2;255;255;255m{c}");

// Trail character - fading color
byte r = (byte)(baseR * brightness);
byte g = (byte)(baseG * brightness);
byte bl = (byte)(baseB * brightness);
_buffer.Append($"\x1b[38;2;{r};{g};{bl}m{c}");
```

### Anti-Patterns to Avoid
- **Multiple Console.Write per frame:** Causes visible flicker, especially over SSH
- **String concatenation in render loop:** Allocates on every frame, triggers GC pauses
- **Fixed frame delay without speed factor:** Animation speed becomes machine-dependent
- **Blocking Console.ReadKey during animation:** Use KeyAvailable check pattern instead

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Katakana characters | Own character set | KatakanaChars.cs | Movie-accurate, pre-validated |
| Color presets | Hardcoded RGB values | ColorPresets.cs | Consistent with shader colors |
| ANSI foreground codes | String formatting | MatrixColor.ToAnsiFg() | Centralized, testable |
| Terminal detection | OS checks | EnvironmentService | Already handles WT_SESSION, TERM, COLORTERM |

**Key insight:** The existing codebase has solved these problems. Reuse, don't rebuild.

## Common Pitfalls

### Pitfall 1: Forgetting Console.OutputEncoding for Katakana
**What goes wrong:** Katakana characters display as `?` or garbage
**Why it happens:** Windows console defaults to current code page, not UTF-8
**How to avoid:** Set encoding before any output:
```csharp
Console.OutputEncoding = Encoding.UTF8;
```
**Warning signs:** Characters render as `?`, `??`, or boxes

### Pitfall 2: Not Hiding Cursor During Animation
**What goes wrong:** Cursor flickers rapidly, distracting visual effect
**Why it happens:** Cursor visible while frame is being written
**How to avoid:** Hide at start, restore on exit/error:
```csharp
Console.Write("\x1b[?25l");  // Hide cursor
try { /* animation */ }
finally { Console.Write("\x1b[?25h"); }  // Show cursor
```
**Warning signs:** Visible cursor blinking during animation

### Pitfall 3: Not Handling Terminal Resize
**What goes wrong:** Animation overflows or leaves garbage on edges after resize
**Why it happens:** Column array sized at startup, never updated
**How to avoid:** Poll dimensions periodically:
```csharp
// Every N frames, check if dimensions changed
if (frameCount % 60 == 0)
{
    int newWidth = Console.WindowWidth;
    int newHeight = Console.WindowHeight;
    if (newWidth != _width || newHeight != _height)
        ReinitializeColumns(newWidth, newHeight);
}
```
**Warning signs:** Visual artifacts after resizing terminal window

### Pitfall 4: Environment.Exit in Library Code
**What goes wrong:** Application exits without proper cleanup
**Why it happens:** FallbackMenu.cs calls Environment.Exit(0) on Q/Escape
**How to avoid:** Use cancellation tokens and return, let caller decide:
```csharp
// Instead of:
case ConsoleKey.Q:
    Environment.Exit(0);  // BAD: bypasses cleanup

// Use:
case ConsoleKey.Q:
    return;  // Let RunAsync complete naturally
```
**Warning signs:** Console cursor still hidden after exit

### Pitfall 5: Frame Timing Ignores Speed Parameter
**What goes wrong:** Speed adjustment has no effect on animation
**Why it happens:** Fixed Task.Delay without speed factor
**How to avoid:** Scale frame delay by speed:
```csharp
// Current correct pattern from TextMatrixRenderer:
int frameDelay = (int)(1000 / (targetFps * _speed));
```
**Warning signs:** E/R keys change display value but animation unchanged

## Code Examples

### Complete Frame Render (Verified Pattern)
```csharp
// Source: MatrixShader.Lite/TextMatrixRenderer.cs (lines 90-174)
public void RenderFrame()
{
    _buffer.Clear();
    _buffer.Append(Home);

    var screen = new char[_height, _width];
    var brightness = new float[_height, _width];

    // Update and collect from all columns
    foreach (var col in _columns)
    {
        col.Update();

        if (!col.IsActive && _random.NextDouble() < _density * 0.1)
            col.Reset();

        if (!col.IsActive) continue;

        // Head (bright white)
        if (col.HeadY >= 0 && col.HeadY < _height)
        {
            screen[col.HeadY, col.X] = col.HeadChar;
            brightness[col.HeadY, col.X] = 1.5f;
        }

        // Trail (fading)
        for (int i = 0; i < col.TrailLength; i++)
        {
            int y = col.HeadY - i - 1;
            if (y >= 0 && y < _height)
            {
                screen[y, col.X] = col.TrailChars[i];
                brightness[y, col.X] = col.GetBrightness(i);
            }
        }
    }

    // Render with ANSI colors
    var (baseR, baseG, baseB) = _color.ToRgb();

    for (int y = 0; y < _height; y++)
    {
        for (int x = 0; x < _width; x++)
        {
            char c = screen[y, x];
            float b = brightness[y, x];

            if (c == '\0' || b <= 0)
            {
                _buffer.Append(' ');
                continue;
            }

            if (b > 1.0f)
                _buffer.Append($"\x1b[38;2;255;255;255m{c}");  // Head
            else
            {
                byte r = (byte)(baseR * b);
                byte g = (byte)(baseG * b);
                byte bl = (byte)(baseB * b);
                _buffer.Append($"\x1b[38;2;{r};{g};{bl}m{c}");  // Trail
            }
        }

        if (y < _height - 1)
        {
            _buffer.Append(Reset);
            _buffer.AppendLine();
        }
    }

    _buffer.Append(Reset);
    Console.Write(_buffer.ToString());
}
```

### Graceful Degradation Entry Point (Redpill Pattern)
```csharp
// Source: MatrixShader.Cli/Redpill/Program.cs (lines 59-83)
var envService = provider.GetRequiredService<EnvironmentService>();
var mode = envService.DetectRenderMode();

logger.LogInformation("Starting Matrix Shader in {Mode} mode", mode);

if (mode == RenderMode.Full)
{
    // Full mode with shader control
    var panel = provider.GetRequiredService<ControlPanel>();
    await panel.RunAsync();
}
else if (mode == RenderMode.Lite)
{
    // Lite mode with text renderer
    var menu = new FallbackMenu();
    await menu.RunAsync(CancellationToken.None);
}
else
{
    Console.WriteLine("\x1b[31mNo display available.\x1b[0m");
    return 1;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 256-color ANSI | 24-bit true color | Windows 10 1607 | Full RGB palette available |
| Console.ForegroundColor | ANSI escape codes | Always for animation | Direct to buffer, no mode switch |
| Fixed columns | Console.WindowWidth | .NET Core | Dynamic width adaptation |

**Deprecated/outdated:**
- ConsoleColor enum: Limited to 16 colors, use ANSI \x1b[38;2;R;G;Bm instead
- Console.SetCursorPosition per character: Too slow, use Home (\x1b[H) + buffer

## Open Questions

### 1. Standalone matrixlite.exe Required?
- **What we know:** CONTEXT.md specifies "Separate executable: matrixlite.exe (standalone tool)" but current architecture has Lite as a library referenced by CLIs
- **What's unclear:** Is the library approach sufficient, or is a separate CLI mandatory?
- **Recommendation:** Create matrixlite.exe for explicit standalone usage, keep library for graceful degradation in other CLIs

### 2. Terminal Resize Frequency
- **What we know:** No event-based resize detection in .NET Console API; requires polling
- **What's unclear:** Optimal polling frequency for resize checks
- **Recommendation:** Check every 60 frames (~2 seconds at 30fps), reinitialize columns on change

### 3. Trail Parameter Mapping
- **What we know:** ShaderConfig.Trail range is 4-15, Column.TrailLength is 8-25
- **What's unclear:** Whether ranges should match exactly
- **Recommendation:** Acceptable difference - trail length variety adds visual interest

## Sources

### Primary (HIGH confidence)
- MatrixShader.Lite source code - TextMatrixRenderer.cs, Column.cs, FallbackMenu.cs
- MatrixShader.Core source code - KatakanaChars.cs, ColorPresets.cs, EnvironmentService.cs
- MatrixShader.Cli.Redpill/Program.cs - Working graceful degradation pattern
- .planning/phases/08.1-gap-closure/DIGEST-REQUIREMENTS.md - Gap analysis

### Secondary (MEDIUM confidence)
- [Microsoft Learn: Native AOT deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/) - AOT compatibility
- [High-performance string formatting in .NET](https://mijailovic.net/2025/05/14/high-performance-strings/) - StringBuilder patterns
- [ANSI escape code (Wikipedia)](https://en.wikipedia.org/wiki/ANSI_escape_code) - 24-bit color syntax

### Tertiary (LOW confidence)
- [termstandard/colors](https://github.com/termstandard/colors) - Terminal true color support matrix
- [.NET runtime issue #19533](https://github.com/dotnet/runtime/issues/19533) - Console resize event API proposal (still open)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components verified in codebase
- Architecture: HIGH - working patterns exist in TextMatrixRenderer
- Pitfalls: HIGH - verified through code review and documented issues

**Research date:** 2026-01-30
**Valid until:** 2026-02-28 (stable domain, no breaking changes expected)

## Implementation Gap Summary

Based on research, the remaining work for Phase 10:

| Requirement | Current Status | Remaining Work |
|-------------|----------------|----------------|
| LITE-01 | Complete (TextMatrixRenderer) | Integration into bluepill/wakeupneo |
| LITE-02 | Complete (KatakanaChars used) | None |
| LITE-03 | Complete (6 presets in FallbackMenu) | None |
| LITE-04 | Partial (redpill only) | Add to bluepill/wakeupneo |

**Effort estimate:** ~3-4 hours total
- 10-01: Extend graceful degradation to bluepill.exe (30 min)
- 10-02: Extend graceful degradation to wakeupneo.exe (30 min)
- 10-03: (Optional) Create standalone matrixlite.exe CLI (1-2 hours)
- 10-04: Add terminal resize handling to TextMatrixRenderer (1 hour)
