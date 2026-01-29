# Phase 9: Native AOT & Polish - Research

**Researched:** 2026-01-29
**Domain:** .NET Native AOT Compilation, Windows Installer, Console UX
**Confidence:** HIGH

## Summary

This phase delivers production-ready single-file executables with instant startup. The codebase is well-prepared: all three CLI projects already have `<PublishAot>true</PublishAot>`, source-generated JSON serialization, and LibraryImport for P/Invoke (except one DllImport case documented in prior decisions). The main work involves: (1) adding missing AOT-specific project properties, (2) implementing Matrix-themed startup splash and error experience, (3) creating the installer package with PATH integration, and (4) validating in Windows Sandbox.

The project uses `Microsoft.Extensions.DependencyInjection` with concrete `AddSingleton<>` registrations (AOT-compatible) and `Microsoft.Extensions.Logging` (annotated for trimming). Both are safe when used without reflection-based patterns. The `AddSimpleConsole()` in Redpill is the only console logging provider and should work with Native AOT.

**Primary recommendation:** Add `<PublishSingleFile>true</PublishSingleFile>` and Windows-specific AOT properties to csproj files, implement Matrix splash animation before DI setup, and use Inno Setup for the installer with PATH modification.

## Standard Stack

The established tools for this phase:

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| .NET 8 SDK | 8.0.x | Native AOT compilation | LTS, mature AOT support |
| ILCompiler | (built-in) | AOT ahead-of-time compiler | .NET SDK component |
| Inno Setup | 6.7.0+ | Windows installer creation | Free, simple, PATH support |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Windows Sandbox | Built-in | Clean-room testing | Verify no runtime deps |
| Stopwatch.GetTimestamp | .NET 8 | Startup timing | Verify <500ms requirement |
| measure-startup | CLI tool | External timing | Cross-validate measurements |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inno Setup | WiX Toolset | WiX creates MSI (enterprise), but more complex XML authoring |
| Inno Setup | MSIX | Modern Windows packaging, but no PATH modification |
| Single splash | Per-exe splash | Simpler single implementation in Core, shared by all CLIs |

**Publication Command:**
```bash
dotnet publish -c Release -r win-x64
```

## Architecture Patterns

### Recommended Project Structure

The CLIs already follow a good structure. For this phase:

```
MatrixShader/
  src/
    MatrixShader.Core/
      Startup/
        MatrixSplash.cs       # NEW: Matrix number cascade animation
        MatrixErrorHandler.cs  # NEW: Themed error experience
    MatrixShader.Cli.*/
      Program.cs              # Add splash call at very start
```

### Pattern 1: Early Splash Before DI

**What:** Display Matrix splash animation before any DI container setup
**When to use:** At the very start of Main(), before ServiceCollection creation
**Why:** Ensures splash appears instantly while DI/logging initializes

```csharp
// Source: Pattern derived from requirement analysis
public static async Task<int> Main(string[] args)
{
    // Splash FIRST - no allocations or DI yet
    await MatrixSplash.ShowAsync();

    // Then normal bootstrap
    var services = new ServiceCollection();
    // ... rest of app
}
```

### Pattern 2: AOT-Safe DI Registration

**What:** Use factory registrations for complex types, concrete AddSingleton for simple types
**When to use:** Current codebase already follows this pattern
**Why:** `AddSingleton<TService, TImplementation>()` is properly annotated for trimming

```csharp
// Source: Microsoft.Extensions.DependencyInjection AOT docs
// Current code is correct - concrete type registrations work with AOT
services.AddSingleton<IShaderService, ShaderService>();
services.AddSingleton<EnvironmentService>(); // Also fine - concrete type
```

### Pattern 3: Windows Sandbox Validation

**What:** Automated .wsb configuration that maps build output and runs test script
**When to use:** CI/CD or manual release validation
**Why:** Proves no runtime dependencies exist on clean Windows

```xml
<!-- Source: Microsoft Learn Windows Sandbox docs -->
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\path\to\publish\output</HostFolder>
      <SandboxFolder>C:\test</SandboxFolder>
      <ReadOnly>True</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -ExecutionPolicy Bypass -File C:\test\validate.ps1</Command>
  </LogonCommand>
</Configuration>
```

### Anti-Patterns to Avoid

- **Reflection-based DI:** Never use `services.AddSingleton(typeof(IService), typeof(Implementation))` with Type objects
- **Dynamic assembly loading:** `Assembly.LoadFile` will fail at runtime
- **Runtime code generation:** `System.Reflection.Emit` not supported
- **Late splash:** Showing splash after DI setup defeats the purpose - user sees delay first

## Don't Hand-Roll

Problems that have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PATH modification | Custom registry code | Inno Setup `[Registry]` with ModPath pattern | Battle-tested, handles duplicates |
| Environment broadcast | Manual `SendMessage` | Inno Setup `ChangesEnvironment=yes` | Notifies Explorer automatically |
| Console ANSI colors | Custom VT100 parser | Existing `ConsoleHelper` with ANSI codes | Already implemented in Core |
| Startup timing | DateTime.Now | Stopwatch.GetTimestamp/GetElapsedTime | Monotonic, high-resolution |
| JSON serialization | Manual string building | MatrixJsonContext (existing) | Already source-generated |

**Key insight:** The codebase already has AOT-safe implementations. This phase is about publishing correctly and adding polish, not architectural changes.

## Common Pitfalls

### Pitfall 1: Missing Visual Studio C++ Workload
**What goes wrong:** `dotnet publish` fails with cryptic ILC errors
**Why it happens:** Native AOT requires C++ toolchain for linking
**How to avoid:** Ensure "Desktop development with C++" is installed in VS2022
**Warning signs:** Errors mentioning `link.exe` or `cl.exe` not found

### Pitfall 2: Suppressing AOT Warnings
**What goes wrong:** App publishes but crashes at runtime
**Why it happens:** Warnings indicate code that will fail under AOT
**How to avoid:** Never suppress IL2XXX warnings; fix the root cause instead
**Warning signs:** `#pragma warning disable IL2XXX` or `<NoWarn>IL2XXX</NoWarn>`

### Pitfall 3: Console Logging Provider Reflection
**What goes wrong:** `AddSimpleConsole()` fails with trimming
**Why it happens:** Some logging providers use reflection internally
**How to avoid:** Test AOT build early and often; current `AddSimpleConsole` should work
**Warning signs:** `TypeLoadException` at startup mentioning logging types

### Pitfall 4: PATH Not Taking Effect
**What goes wrong:** User installs, opens new terminal, commands not found
**Why it happens:** Missing `ChangesEnvironment=yes` in Inno Setup
**How to avoid:** Always include this directive when modifying PATH
**Warning signs:** Works after system restart but not immediately

### Pitfall 5: Splash Delays Perceived Startup
**What goes wrong:** App feels slower despite faster actual startup
**Why it happens:** Mandatory 1-2 second splash adds perceived delay
**How to avoid:** Run splash animation concurrently with initialization where possible
**Warning signs:** User complaints about "slowness" despite meeting 500ms target

### Pitfall 6: Windows Sandbox Memory Errors
**What goes wrong:** Sandbox fails to start or app crashes in sandbox
**Why it happens:** Default 2GB memory may be insufficient
**How to avoid:** Add `<MemoryInMB>4096</MemoryInMB>` to .wsb config
**Warning signs:** Sandbox closes immediately or shows out-of-memory errors

## Code Examples

Verified patterns from official sources:

### Enabling Native AOT Single-File Publishing
```xml
<!-- Source: https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/ -->
<PropertyGroup>
  <OutputType>Exe</OutputType>
  <TargetFramework>net8.0-windows</TargetFramework>

  <!-- Native AOT -->
  <PublishAot>true</PublishAot>
  <PublishSingleFile>true</PublishSingleFile>

  <!-- Size optimizations (already present in csproj files) -->
  <InvariantGlobalization>true</InvariantGlobalization>
  <IlcOptimizationPreference>Size</IlcOptimizationPreference>

  <!-- Additional AOT safety -->
  <JsonSerializerIsReflectionEnabledByDefault>false</JsonSerializerIsReflectionEnabledByDefault>

  <!-- Windows-specific for single-file -->
  <RuntimeIdentifier>win-x64</RuntimeIdentifier>
  <SelfContained>true</SelfContained>
</PropertyGroup>
```

### Matrix Number Cascade Animation
```csharp
// Concept pattern - implementation details at Claude's discretion
// Source: ANSI escape codes + Matrix movie aesthetic
public static class MatrixSplash
{
    private static readonly Random _rng = new();
    private static readonly char[] _chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray();

    public static async Task ShowAsync(int durationMs = 1500)
    {
        Console.Clear();
        Console.CursorVisible = false;

        var width = Console.WindowWidth;
        var height = Console.WindowHeight;
        var startTime = Stopwatch.GetTimestamp();

        // Column drop positions
        var columns = new int[width];
        for (int i = 0; i < width; i++)
            columns[i] = _rng.Next(-height, 0);

        while (Stopwatch.GetElapsedTime(startTime).TotalMilliseconds < durationMs)
        {
            // Update columns
            for (int x = 0; x < width; x++)
            {
                columns[x]++;
                if (columns[x] >= height)
                    columns[x] = _rng.Next(-5, 0);

                int y = columns[x];
                if (y >= 0 && y < height)
                {
                    // Lead character (bright)
                    Console.SetCursorPosition(x, y);
                    Console.Write($"\x1b[97m{_chars[_rng.Next(_chars.Length)]}\x1b[0m");

                    // Trail (green, fading)
                    if (y > 0)
                    {
                        Console.SetCursorPosition(x, y - 1);
                        Console.Write($"\x1b[32m{_chars[_rng.Next(_chars.Length)]}\x1b[0m");
                    }
                }
            }

            await Task.Delay(50);
        }

        Console.Clear();
    }
}
```

### Matrix-Themed Error Handler
```csharp
// Source: 09-CONTEXT.md requirements - late 90s telnet hacker aesthetic
public static class MatrixErrorHandler
{
    public static void ShowError(string message, string? actionUrl = null)
    {
        Console.Clear();
        Console.WriteLine();
        Console.WriteLine("\x1b[31m ██████ ██    ██ ██████ ████████ ███████ ███    ███ \x1b[0m");
        Console.WriteLine("\x1b[31m██       ██  ██  ██         ██    ██      ████  ████ \x1b[0m");
        Console.WriteLine("\x1b[31m █████    ████   ██████     ██    █████   ██ ████ ██ \x1b[0m");
        Console.WriteLine("\x1b[31m     ██    ██        ██     ██    ██      ██  ██  ██ \x1b[0m");
        Console.WriteLine("\x1b[31m██████     ██    ██████     ██    ███████ ██      ██ \x1b[0m");
        Console.WriteLine();
        Console.WriteLine("\x1b[31m ███████  █████  ██ ██      ██    ██ ██████  ███████ \x1b[0m");
        Console.WriteLine("\x1b[31m ██      ██   ██ ██ ██      ██    ██ ██   ██ ██      \x1b[0m");
        Console.WriteLine("\x1b[31m █████   ███████ ██ ██      ██    ██ ██████  █████   \x1b[0m");
        Console.WriteLine("\x1b[31m ██      ██   ██ ██ ██      ██    ██ ██   ██ ██      \x1b[0m");
        Console.WriteLine("\x1b[31m ██      ██   ██ ██ ███████  ██████  ██   ██ ███████ \x1b[0m");
        Console.WriteLine();
        Console.WriteLine($"\x1b[32m > {message}\x1b[0m");
        Console.WriteLine();

        if (!string.IsNullOrEmpty(actionUrl))
        {
            Console.WriteLine($"\x1b[90m Jack in at: {actionUrl}\x1b[0m");
            Console.WriteLine();
        }

        Console.WriteLine("\x1b[90m Press any key to exit the simulation...\x1b[0m");
        Console.ReadKey(intercept: true);
    }
}
```

### Inno Setup Script with PATH
```iss
; Source: Inno Setup docs + LegRoom.net ModPath pattern
[Setup]
AppName=Matrix Shader
AppVersion=2.0.0
DefaultDirName={autopf}\MatrixShader
DefaultGroupName=Matrix Shader
OutputBaseFilename=MatrixShaderSetup
Compression=lzma2
SolidCompression=yes
ChangesEnvironment=yes
PrivilegesRequired=admin

[Files]
Source: "publish\wakeupneo.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\redpill.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\bluepill.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "shaders\*"; DestDir: "{app}\shaders"; Flags: ignoreversion recursesubdirs

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
    Check: NeedsAddPath(ExpandConstant('{app}'))

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  { Ensure path not already present }
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;
```

### Startup Time Validation Script
```powershell
# validate.ps1 - Run in Windows Sandbox
$ErrorActionPreference = 'Stop'

$exes = @('wakeupneo.exe', 'bluepill.exe', 'redpill.exe')

foreach ($exe in $exes) {
    $path = "C:\test\$exe"
    if (!(Test-Path $path)) {
        Write-Error "Missing: $path"
        exit 1
    }

    # Measure startup time (run with --help to avoid interactive mode)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $path --help | Out-Null
    $sw.Stop()

    $ms = $sw.ElapsedMilliseconds
    Write-Host "$exe startup: ${ms}ms"

    if ($ms -gt 500) {
        Write-Error "$exe exceeded 500ms startup target: ${ms}ms"
        exit 1
    }
}

Write-Host "`nAll executables validated successfully!" -ForegroundColor Green
exit 0
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DllImport | LibraryImport | .NET 7+ | Source-generated, AOT-safe |
| Newtonsoft.Json | System.Text.Json + source gen | .NET 6+ | No reflection, AOT-safe |
| Self-contained publish | Native AOT publish | .NET 7+ (stable .NET 8) | Single native binary |
| IL trim only | Full AOT compilation | .NET 7+ | No JIT needed at runtime |

**Deprecated/outdated:**
- `ILCompiler` NuGet package: Now built into .NET SDK, no separate package needed
- `rd.xml` runtime directives: Replaced by source-generation attributes and compile-time analysis
- `Assembly.GetEntryAssembly().Location`: Returns empty string in single-file; use `AppContext.BaseDirectory` instead

## Open Questions

Things that couldn't be fully resolved:

1. **Exact splash duration vs initialization time**
   - What we know: Splash should be 1-2 seconds minimum OR until app ready
   - What's unclear: How long does DI setup actually take post-AOT?
   - Recommendation: Implement splash with configurable minimum, measure actual init time during testing

2. **AddSimpleConsole AOT behavior**
   - What we know: Microsoft.Extensions.Logging 8.0 is annotated for trimming
   - What's unclear: No explicit AOT test results found for SimpleConsole provider
   - Recommendation: Test early in implementation; fall back to direct Console.Write if issues

3. **Installer uninstall PATH cleanup**
   - What we know: Adding to PATH is straightforward with ModPath pattern
   - What's unclear: Inno Setup uninstall behavior for PATH entries
   - Recommendation: Test uninstall flow explicitly; may need `[UninstallRegistry]` section

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn: Native AOT deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/) - Core AOT properties and requirements
- [Microsoft Learn: Trimming options](https://learn.microsoft.com/en-us/dotnet/core/deploying/trimming/trimming-options) - All trimming MSBuild properties
- [Microsoft Learn: Single-file deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview) - Single-file publish behavior
- [Microsoft Learn: Windows Sandbox configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file) - WSB file format

### Secondary (MEDIUM confidence)
- [Inno Setup FAQ](https://jrsoftware.org/isfaq.php) - Official Inno Setup documentation
- [LegRoom.net ModPath](https://www.legroom.net/software/modpath) - PATH modification script for Inno Setup
- [GitHub: dotnet/runtime discussion on MEDI AOT](https://github.com/dotnet/runtime/discussions/110386) - DI AOT compatibility

### Tertiary (LOW confidence)
- WebSearch results for startup time benchmarks - Varied claims, need local validation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Microsoft documentation verified
- Architecture: HIGH - Existing codebase patterns already AOT-ready
- Pitfalls: HIGH - Well-documented in official sources
- Installer: MEDIUM - Inno Setup is mature but PATH modification is script-based
- Splash animation: MEDIUM - Concept verified, exact implementation at discretion

**Research date:** 2026-01-29
**Valid until:** 60 days (Native AOT is stable in .NET 8 LTS)
