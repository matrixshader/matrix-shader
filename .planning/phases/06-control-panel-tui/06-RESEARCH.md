# Phase 6: Control Panel TUI - Research

**Researched:** 2026-01-27
**Domain:** Terminal User Interface with Spectre.Console and raw Console API
**Confidence:** HIGH

## Summary

This phase ports the PowerShell `matrix_control.ps1` TUI to C#. The goal is **pixel-perfect visual replication** of the PowerShell output, which may require mixing Spectre.Console with raw `Console.Write` calls.

Key findings:
- Spectre.Console supports 24-bit RGB colors via `[rgb(r,g,b)]` markup and `new Color(r, g, b)` Style constructors
- Console keyboard input uses `Console.ReadKey(true)` with `ConsoleKeyInfo.Modifiers.HasFlag(ConsoleModifiers.Shift)` for shift-key detection
- The existing C# `ControlPanel` class (370 lines) provides a starting point but uses table-based layouts that differ from PowerShell output
- Services from Phases 1-5 (ShaderService, ConfigService, IdentityService, LayoutService) are wired and ready for integration

**Primary recommendation:** Rewrite the render method to use raw `Console.Write` with ANSI escape codes for pixel-perfect matching, while keeping Spectre.Console for complex widgets (Tables) if exact spacing allows.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| System.Console | Built-in | Keyboard input, raw output | Direct control over terminal I/O |
| Spectre.Console | 0.54.0 | Markup rendering, colors | Already in project, AOT-compatible |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Microsoft.Extensions.DependencyInjection | 8.0.x | Service injection | Already in use for ControlPanel |
| Microsoft.Extensions.Logging | 8.0.x | Diagnostic logging | Debug output via MATRIX_DEBUG |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Spectre.Console Tables | Raw Console.Write | Tables add spacing; raw gives exact control |
| AnsiConsole.Markup | Console.Write + ANSI | Markup parses slowly; raw is faster |
| Terminal.Gui | - | Overkill, not pixel-perfect for simple TUI |

**Installation:** Already present in project - no new packages needed.

## Architecture Patterns

### Recommended Project Structure

The ControlPanel lives in the CLI project with a clear separation:

```
src/MatrixShader.Cli/Redpill/
    Program.cs              # Entry point, DI setup
    ControlPanel.cs         # Main TUI controller (rewrite target)
    TuiRenderer.cs          # NEW: Pixel-perfect rendering functions
    KeyHandler.cs           # NEW: Input handling with shift-key support
```

### Pattern 1: Raw ANSI Output for Pixel-Perfect Rendering

**What:** Use raw Console.Write with ANSI escape codes for exact character positioning
**When to use:** Color swatches, progress bars, value displays where spacing must match PowerShell exactly
**Example:**
```csharp
// Source: PowerShell Get-ColorSwatch function (MatrixUtils.ps1:28-47)
public static string ColorSwatch(float r, float g, float b, int width = 2)
{
    var r8 = (int)Math.Clamp(r * 255, 0, 255);
    var g8 = (int)Math.Clamp(g * 255, 0, 255);
    var b8 = (int)Math.Clamp(b * 255, 0, 255);
    return $"\x1b[48;2;{r8};{g8};{b8}m{new string(' ', width)}\x1b[0m";
}

// Source: PowerShell Bar function (matrix_control.ps1:255-259)
public static string ProgressBar(float val, float min, float max, int width = 15)
{
    var pct = (val - min) / (max - min);
    var filled = (int)(pct * width);
    var empty = width - filled;
    return $"\x1b[32m{new string('=', filled)}\x1b[90m{new string('-', empty)}\x1b[0m";
}
```

### Pattern 2: Spectre.Console for Complex Widgets

**What:** Use Spectre.Console Markup for inline colors where exact spacing isn't critical
**When to use:** Footer instructions, error messages, status text
**Example:**
```csharp
// Source: Spectre.Console documentation
AnsiConsole.MarkupLine("[red]Error:[/] Could not save shader");
AnsiConsole.MarkupLine("[dim][ESC] Quit[/]");
```

### Pattern 3: Keyboard Input Handling with Shift Detection

**What:** Use ConsoleKeyInfo with Modifiers check before ToLower normalization
**When to use:** All key handling - Shift+L, Shift+G, Shift+M, Shift+S, Shift+R, Shift+P require case-sensitivity
**Example:**
```csharp
// Source: Microsoft Learn Console.ReadKey documentation
var key = Console.ReadKey(intercept: true);

// Check shift combinations FIRST (before normalizing to lowercase)
if (key.KeyChar == 'L' && key.Modifiers.HasFlag(ConsoleModifiers.Shift))
{
    // Shift+L: Layout mode cycle
    CycleLayoutMode();
    return;
}

// THEN normalize for case-insensitive handling
var normalizedChar = char.ToLower(key.KeyChar);
switch (normalizedChar)
{
    case 'l': AdjustOpacity(+5); break;  // lowercase 'l' = opacity up
    // ...
}
```

### Pattern 4: Tab Cycling Through Open Windows

**What:** Tab key cycles through detected Matrix windows, not all slots 1-8
**When to use:** Tab key handler
**Example:**
```csharp
// Source: matrix_control.ps1 lines 928-946
if (key.Key == ConsoleKey.Tab)
{
    // Auto-save before switching
    if (_dirty)
    {
        SaveCurrentShader();
        _dirty = false;
    }

    // Get open windows from IdentityService
    var openWindows = _identityService.FindMatrixWindows();
    if (openWindows.Count > 0)
    {
        var currentIndex = openWindows.FindIndex(w => w.ShaderIndex == _currentSlot);
        if (currentIndex < 0) currentIndex = 0;
        var nextIndex = (currentIndex + 1) % openWindows.Count;
        _currentSlot = openWindows[nextIndex].ShaderIndex;
        LoadSlot(_currentSlot);
    }
}
```

### Anti-Patterns to Avoid
- **Using Spectre.Console Tables for the entire UI:** Tables add their own borders and spacing that won't match PowerShell output
- **Checking VirtualKeyCode alone:** PowerShell uses both `$key.Character` and `$key.VirtualKeyCode`; C# must check both `KeyChar` and `Key`
- **Normalizing to lowercase before shift checks:** This loses Shift+letter detection since `key.KeyChar` for Shift+L is 'L' not 'l'
- **Polling with Task.Delay:** Current code polls every 50ms; should use blocking `Console.ReadKey()` for responsive input

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ANSI color codes | String concatenation | Use constant strings or helper methods | Error-prone escape sequences |
| Window detection | Manual EnumWindows | IIdentityService.FindMatrixWindows() | Already handles 4-layer identity hierarchy |
| Layout positioning | Manual SetWindowPos | ILayoutService.ApplyLayout() | Already handles DWM borders, minimized windows |
| State persistence | Manual JSON | IConfigService.SaveState() | Already handles atomic writes |

**Key insight:** Phases 1-5 built all the services. Phase 6 is purely UI/input handling that calls those services.

## Common Pitfalls

### Pitfall 1: Spectre.Console Cursor Interference

**What goes wrong:** Spectre.Console's AnsiConsole.Write can move the cursor unexpectedly
**Why it happens:** Spectre manages its own output buffer
**How to avoid:** Set cursor position explicitly before each render with `Console.SetCursorPosition(0, 0)`
**Warning signs:** UI elements appear in wrong positions after using AnsiConsole

### Pitfall 2: Shift+Key Character Case

**What goes wrong:** Shift+L detected as lowercase 'l' or not detected at all
**Why it happens:** `key.KeyChar` is 'L' when shift is held, not 'l'
**How to avoid:** Check `key.KeyChar == 'L'` (case-sensitive) BEFORE normalizing to lowercase
**Warning signs:** Layout toggle not working, opacity changing instead

### Pitfall 3: Tab Key VirtualKeyCode

**What goes wrong:** Tab key not detected in switch on KeyChar
**Why it happens:** Tab's KeyChar is '\t' which is awkward to match
**How to avoid:** Check `key.Key == ConsoleKey.Tab` instead of KeyChar
**Warning signs:** Tab cycling doesn't work

### Pitfall 4: Number Keys with Shift (Color Presets)

**What goes wrong:** Pressing Shift+1 through Shift+6 should trigger color presets, not tab switches
**Why it happens:** PowerShell maps 1-6 without modifiers to tabs, with modifiers to colors
**How to avoid:** Current C# code checks `key.Modifiers == 0` for tabs - this is correct pattern
**Warning signs:** Color presets don't work or tabs switch unexpectedly

### Pitfall 5: Dirty State Lost on Crash

**What goes wrong:** Changes lost if application crashes
**Why it happens:** Dirty flag only saves on explicit save or tab switch
**How to avoid:** Consider auto-saving shader to file immediately on each change (current behavior via WriteConfig)
**Warning signs:** Already handled - current code calls WriteConfig immediately in UpdateConfig

## Code Examples

Verified patterns from official sources:

### Render Loop (Blocking Input)
```csharp
// Better than polling - blocking input is more responsive
public async Task RunAsync()
{
    Console.CursorVisible = false;
    Console.Clear();

    try
    {
        while (_running)
        {
            Render();
            var key = Console.ReadKey(intercept: true); // Blocking
            HandleKey(key);
        }
    }
    finally
    {
        if (_dirty) SaveAll();
        Console.CursorVisible = true;
        Console.Clear();
    }
}
```

### Color Swatch Rendering
```csharp
// Source: MatrixUtils.ps1 Get-ColorSwatch
public static void WriteColorSwatch(float r, float g, float b, int width = 2)
{
    var r8 = (int)Math.Clamp(r * 255, 0, 255);
    var g8 = (int)Math.Clamp(g * 255, 0, 255);
    var b8 = (int)Math.Clamp(b * 255, 0, 255);
    Console.Write($"\x1b[48;2;{r8};{g8};{b8}m{new string(' ', width)}\x1b[0m");
}
```

### Progress Bar Rendering
```csharp
// Source: matrix_control.ps1 Bar function
public static void WriteProgressBar(float val, float min, float max, int width = 15)
{
    var pct = Math.Clamp((val - min) / (max - min), 0f, 1f);
    var filled = (int)(pct * width);
    var empty = width - filled;
    Console.Write($"\x1b[32m{new string('=', filled)}\x1b[90m{new string('-', empty)}\x1b[0m");
}
```

### Tab Display with Color Swatches
```csharp
// Source: matrix_control.ps1 UI function lines 750-777
public void RenderTabs()
{
    Console.Write(" TABS: ");
    var windows = _identityService.FindMatrixWindows();

    if (windows.Count == 0)
    {
        Console.Write("\x1b[90m(no Matrix windows detected)\x1b[0m");
    }
    else
    {
        foreach (var win in windows)
        {
            var config = _shaderService.ReadConfig(win.ShaderIndex);
            if (win.ShaderIndex == _currentSlot)
            {
                Console.Write($"\x1b[33m[{win.ShaderIndex}]\x1b[0m");
            }
            else
            {
                Console.Write($"\x1b[90m {win.ShaderIndex} \x1b[0m");
            }
            WriteColorSwatch(config.R, config.G, config.B, 1);
            Console.Write(" ");
        }
    }
    Console.WriteLine();
}
```

### Full Key Mapping (matching matrix_control.ps1)
```csharp
// Source: matrix_control.ps1 lines 1093-1215
private void HandleKey(ConsoleKeyInfo key)
{
    var config = GetCurrentConfig();

    // Tab key (VK 9)
    if (key.Key == ConsoleKey.Tab)
    {
        AutoSaveAndSwitchTab();
        return;
    }

    // Enter key (VK 13)
    if (key.Key == ConsoleKey.Enter)
    {
        if (_launchCount > 0) LaunchWindows();
        return;
    }

    // Escape key (VK 27)
    if (key.Key == ConsoleKey.Escape)
    {
        SaveCurrentState();
        _running = false;
        return;
    }

    // Shift+ combinations BEFORE lowercase normalization
    switch (key.KeyChar)
    {
        case 'L': CycleLayoutMode(); return;
        case 'S': SaveSnapback(); return;
        case 'R': RestoreSnapback(); return;
        case 'P': TogglePriorityLock(); return;
        case 'G': ToggleGlitch(); return;
        case 'M': ChangeMonitorCount(); return;
    }

    // Normalize for case-insensitive handling
    var ch = char.ToLower(key.KeyChar);

    switch (ch)
    {
        // Color presets (1-6)
        case '1': SetColor(ColorPresets.Green); break;
        case '2': SetColor(ColorPresets.Cyan); break;
        case '3': SetColor(ColorPresets.Red); break;
        case '4': SetColor(ColorPresets.Purple); break;
        case '5': SetColor(ColorPresets.Gold); break;
        case '6': SetColor(ColorPresets.Teal); break;

        // RGB controls (Q/W, A/S, Z/X)
        case 'q': Adjust(c => c with { R = c.R - 0.05f }); break;
        case 'w': Adjust(c => c with { R = c.R + 0.05f }); break;
        case 'a': Adjust(c => c with { G = c.G - 0.05f }); break;
        case 's': Adjust(c => c with { G = c.G + 0.05f }); break;
        case 'z': Adjust(c => c with { B = c.B - 0.05f }); break;
        case 'x': Adjust(c => c with { B = c.B + 0.05f }); break;

        // Effects
        case 'e': Adjust(c => c with { Speed = c.Speed - 0.1f }); break;
        case 'r': Adjust(c => c with { Speed = c.Speed + 0.1f }); break;
        case 'd': Adjust(c => c with { Glow = c.Glow - 0.1f }); break;
        case 'f': Adjust(c => c with { Glow = c.Glow + 0.1f }); break;
        case 'c': Adjust(c => c with { Width = c.Width - 1f }); break;
        case 'v': Adjust(c => c with { Width = c.Width + 1f }); break;
        case 't': Adjust(c => c with { Trail = c.Trail - 0.5f }); break;
        case 'y': Adjust(c => c with { Trail = c.Trail + 0.5f }); break;
        case 'g': Adjust(c => c with { Density = c.Density - 0.1f }); break;
        case 'h': Adjust(c => c with { Density = c.Density + 0.1f }); break;

        // Layers
        case '7': Adjust(c => c with { Layer1 = !c.Layer1 }); break;
        case '8': Adjust(c => c with { Layer2 = !c.Layer2 }); break;
        case '9': Adjust(c => c with { Layer3 = !c.Layer3 }); break;

        // Transparency
        case 'b': ToggleTransparency(); break;
        case 'k': AdjustOpacity(-5); break;
        case 'l': AdjustOpacity(+5); break;

        // Launch count
        case '-': if (_launchCount > 0) _launchCount--; break;
        case '+': case '=': if (CanLaunchMore()) _launchCount++; break;

        // Reset
        case '0': ResetToDefaults(); break;

        // Save
        case 'p': SaveShader(); break;

        // Primary monitor controls
        case ',': DecreasePrimaryWindows(); break;
        case '.': IncreasePrimaryWindows(); break;
        case ')': ResetPrimaryToAuto(); break;
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DllImport P/Invoke | LibraryImport | .NET 7+ | Source-generated, AOT-safe |
| Reflection-based DI | Constructor injection | Current | AOT-compatible |
| Polling input loop | Blocking ReadKey | Always | More responsive |

**Deprecated/outdated:**
- Spectre.Console.Cli: Reflection-based, not AOT-compatible
- System.CommandLine: Still preview, complex API

## Open Questions

Things that couldn't be fully resolved:

1. **Spectre.Console Table Column Widths**
   - What we know: Tables auto-size columns based on content
   - What's unclear: Can we force exact column widths to match PowerShell spacing?
   - Recommendation: Use raw Console.Write for parameter tables, Spectre only for decorative elements

2. **Windows Terminal Opacity via settings.json**
   - What we know: PowerShell modifies profile opacity in settings.json
   - What's unclear: Does WT file watching cause race conditions with our writes?
   - Recommendation: Implement in Phase 7 (Terminal Integration) with atomic writes

3. **Monitor Count Detection at Runtime**
   - What we know: LayoutService.GetMonitors() returns connected monitors
   - What's unclear: Does hot-plugging monitors require refresh?
   - Recommendation: Call GetMonitors() on each Shift+M press, not cached

## Sources

### Primary (HIGH confidence)
- Microsoft Learn: [Console.ReadKey](https://learn.microsoft.com/en-us/dotnet/api/system.console.readkey)
- Microsoft Learn: [ConsoleKeyInfo.Modifiers](https://learn.microsoft.com/en-us/dotnet/api/system.consolekeyinfo.modifiers)
- PowerShell source: `matrix_control.ps1` (1,221 lines) - authoritative specification
- PowerShell source: `MatrixUtils.ps1` (343 lines) - Swatch and Bar implementations

### Secondary (MEDIUM confidence)
- [Spectre.Console GitHub Discussion #1270](https://github.com/spectreconsole/spectre.console/discussions/1270) - Custom RGB colors
- [Spectre.Console Markup Documentation](https://spectreconsole.net/markup) - RGB syntax

### Tertiary (LOW confidence)
- Web search results for Spectre.Console raw output - no definitive source found

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - .NET Console API is stable, well-documented
- Architecture: HIGH - Pattern directly mirrors working PowerShell code
- Pitfalls: MEDIUM - Based on analysis of PowerShell behavior, not direct experience

**Research date:** 2026-01-27
**Valid until:** 2026-02-27 (30 days - stable domain)
