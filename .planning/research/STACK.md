# Technology Stack

**Project:** Matrix Terminal Shader C# Implementation
**Researched:** 2026-01-25
**Confidence:** HIGH (versions verified via NuGet/official sources)

## Executive Summary

The standard 2025/2026 stack for building native C# terminal applications with Windows API integration centers on:
- **.NET 8/9** with Native AOT for instant startup (<500ms target)
- **Spectre.Console** for rich TUI rendering (NOT Spectre.Console.Cli)
- **LibraryImport** (source-generated P/Invoke) for Windows API calls
- **ConsoleAppFramework** for AOT-safe CLI argument parsing

The existing codebase is already well-aligned with these choices. Key upgrades: consider .NET 10 LTS when stable, and adopt ConsoleAppFramework for CLI entry points.

---

## Recommended Stack

### Core Runtime

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| .NET | 8.0 (current) or 9.0 | Runtime/SDK | .NET 8 is LTS (support until Nov 2026). .NET 9 is STS with improved AOT. Project already uses .NET 8 which is appropriate. |
| C# | 12 (current) or 13 | Language | C# 12 is stable. C# 13 required for ConsoleAppFramework 5.x features. |
| Native AOT | Enabled | Compilation | Instant startup (<500ms), single-file deployment, no runtime dependency. Already configured in project. |

**Recommendation:** Stay on .NET 8 LTS for stability. Upgrade to .NET 10 LTS (November 2025 release, supported until November 2028) when ready to adopt latest features.

**Source:** [Microsoft .NET Support Policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core) - HIGH confidence

---

### TUI/Console Output Library

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **Spectre.Console** | 0.54.0 | Rich console rendering | Tables, colors, markup, progress bars. Native AOT compatible. Already in project. |

**Version verified:** NuGet 0.54.0, last updated November 12, 2025

**Native AOT Status:** COMPATIBLE - Core Spectre.Console library supports Native AOT. Add `<PublishAot>true</PublishAot>` to project file.

**What NOT to use:**

| Library | Why Not |
|---------|---------|
| **Spectre.Console.Cli** | Relies on reflection for type discovery. NOT AOT-compatible. Will produce runtime errors. |
| **Terminal.Gui v1** | Stable but v2 has better AOT support. Requires graphical stack (won't work on headless Linux). |
| **Terminal.Gui v2** | Still in alpha (2.0.0-alpha). Has AOT support but not production-ready. Only consider if building full windowed TUI. |

**Source:** [Spectre.Console 0.50 Release Blog](https://spectreconsole.net/blog/posts/2025-04-08-spectre-console-0.50-released), [NuGet Package](https://www.nuget.org/packages/Spectre.Console) - HIGH confidence

---

### CLI Argument Parsing

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **ConsoleAppFramework** | 5.7.13 | CLI argument parsing | Zero reflection, source-generated, AOT-safe. 280x faster than System.CommandLine. |

**Version verified:** NuGet 5.7.13, last updated November 26, 2025

**Requirements:** .NET 8+, C# 13 (for params arrays in lambdas)

**Native AOT Status:** FULLY COMPATIBLE - Uses source generators, no reflection.

**Why this over alternatives:**

| Alternative | Why Not for This Project |
|-------------|--------------------------|
| **Spectre.Console.Cli** | Reflection-based, not AOT-compatible |
| **System.CommandLine** | Complex API, AOT support unclear, still in preview |
| **CommandLineParser** | Reflection-based, not AOT-compatible |
| **Manual parsing** | Viable for simple CLIs but ConsoleAppFramework adds zero overhead |

**Usage Example:**
```csharp
// Program.cs - ConsoleAppFramework style
ConsoleApp.Run(args, (string? profile, bool verbose) =>
{
    // Your CLI logic here
});
```

**Source:** [ConsoleAppFramework GitHub](https://github.com/Cysharp/ConsoleAppFramework), [NuGet Package](https://www.nuget.org/packages/ConsoleAppFramework) - HIGH confidence

---

### Windows API / P/Invoke

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **LibraryImport** | Built-in (.NET 7+) | P/Invoke declarations | Source-generated marshalling, AOT-compatible, already in use. |
| **CsWin32** (optional) | 0.3.269 | Generated Win32 bindings | Microsoft-maintained source generator. Alternative to manual P/Invoke. |

**Current approach is correct:** The existing `WindowsApi.cs` uses `[LibraryImport]` which is the modern, AOT-compatible approach. This is preferred over `[DllImport]`.

**LibraryImport vs DllImport:**
```csharp
// OLD (DllImport) - runtime marshalling, not AOT-optimal
[DllImport("user32.dll")]
static extern bool SetWindowPos(IntPtr hWnd, ...);

// NEW (LibraryImport) - source-generated, AOT-compatible
[LibraryImport("user32.dll")]
static partial bool SetWindowPos(nint hWnd, ...);
```

**CsWin32 Option:**

If you need many Windows APIs, consider CsWin32:
- Creates `NativeMethods.txt` listing needed APIs
- Source generator creates type-safe wrappers
- Maintains SafeHandle types automatically
- Microsoft-maintained, always current

**Installation:**
```bash
dotnet add package Microsoft.Windows.CsWin32 --version 0.3.269
```

Then create `NativeMethods.txt`:
```
EnumWindows
SetWindowPos
GetWindowRect
EnumDisplayMonitors
GetMonitorInfo
```

**Recommendation:** Keep current manual LibraryImport approach - it's working well and gives full control. Only adopt CsWin32 if adding many new Windows APIs.

**Source:** [Microsoft CsWin32 GitHub](https://github.com/microsoft/CsWin32), [Platform Invoke Docs](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke) - HIGH confidence

---

### JSON Serialization

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **System.Text.Json** | Built-in | Config files, state | AOT-compatible with source generators. Already in project. |

**Native AOT Requirement:** Use source-generated serialization context:

```csharp
[JsonSourceGenerationOptions(WriteIndented = true)]
[JsonSerializable(typeof(MatrixState))]
[JsonSerializable(typeof(ShaderConfig))]
internal partial class AppJsonContext : JsonSerializerContext { }

// Usage
var state = JsonSerializer.Deserialize(json, AppJsonContext.Default.MatrixState);
```

**What NOT to use:**

| Library | Why Not |
|---------|---------|
| Newtonsoft.Json | Reflection-based, not AOT-compatible |
| Dynamic System.Text.Json | Works but larger binary, slower startup |

**Source:** [Native AOT Docs](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/) - HIGH confidence

---

### Dependency Injection (Optional)

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **Microsoft.Extensions.DependencyInjection** | 8.0.x | Service container | AOT-compatible with some constraints. Currently in Redpill.csproj. |

**AOT Considerations:**
- Avoid `GetService<T>()` with open generics
- Prefer constructor injection
- Register concrete types, not just interfaces

**Alternative for CLI tools:** Skip DI entirely for simple CLIs. Direct instantiation is faster and simpler for small apps.

**Source:** [ASP.NET Core AOT Docs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/native-aot) - MEDIUM confidence

---

### Logging

| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **Microsoft.Extensions.Logging** | 8.0.x | Structured logging | Standard .NET logging. AOT-compatible. |

**For CLI tools:** Consider `Console.WriteLine` for simplicity, or `ILogger` if you need log levels and filtering.

**Source:** Built-in .NET library - HIGH confidence

---

## Native AOT Configuration

### Required Project Settings

```xml
<PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <PublishAot>true</PublishAot>
    <InvariantGlobalization>true</InvariantGlobalization>
    <IlcOptimizationPreference>Size</IlcOptimizationPreference>
    <TrimMode>link</TrimMode>
</PropertyGroup>
```

### AOT Compatibility Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| P/Invoke (LibraryImport) | COMPATIBLE | Source-generated marshalling |
| System.Text.Json | COMPATIBLE | Requires JsonSerializerContext |
| Spectre.Console | COMPATIBLE | Core library only |
| ConsoleAppFramework | COMPATIBLE | Fully source-generated |
| Microsoft.Extensions.DI | COMPATIBLE | With constraints |
| Reflection | LIMITED | Avoid Type.GetType(), Assembly.Load() |
| Dynamic code gen | NOT COMPATIBLE | No Reflection.Emit, Expression.Compile() |

### Publishing Commands

```bash
# Windows x64 Native AOT
dotnet publish -c Release -r win-x64 --self-contained

# Size-optimized
dotnet publish -c Release -r win-x64 -p:IlcOptimizationPreference=Size

# Speed-optimized (larger binary)
dotnet publish -c Release -r win-x64 -p:IlcOptimizationPreference=Speed
```

**Expected output:** Single `.exe` file, ~9-15MB, instant startup.

**Source:** [Native AOT Deployment Overview](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/) - HIGH confidence

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Runtime | .NET 8 LTS | .NET 9 STS | 9 has newer AOT but shorter support window |
| TUI | Spectre.Console | Terminal.Gui | Terminal.Gui v2 still alpha, overkill for this use case |
| CLI Parsing | ConsoleAppFramework | Spectre.Console.Cli | Not AOT-compatible |
| CLI Parsing | ConsoleAppFramework | System.CommandLine | Complex API, unclear AOT status |
| P/Invoke | LibraryImport | CsWin32 | Manual approach working fine, CsWin32 adds complexity |
| P/Invoke | LibraryImport | DllImport | DllImport uses runtime marshalling, not AOT-optimal |
| JSON | System.Text.Json | Newtonsoft.Json | Newtonsoft requires reflection |

---

## Installation Commands

### New Project Setup

```bash
# Create solution
dotnet new sln -n MatrixShader

# Create projects
dotnet new classlib -n MatrixShader.Core
dotnet new console -n MatrixShader.Cli.Redpill

# Add packages
cd MatrixShader.Core
dotnet add package System.Text.Json
dotnet add package Microsoft.Extensions.Logging.Abstractions

cd ../MatrixShader.Cli.Redpill
dotnet add package Spectre.Console --version 0.54.0
dotnet add package ConsoleAppFramework --version 5.7.13
```

### Existing Project Upgrade

```bash
# Update Spectre.Console to latest
dotnet add package Spectre.Console --version 0.54.0

# Add ConsoleAppFramework for CLI parsing
dotnet add package ConsoleAppFramework --version 5.7.13

# Optional: Add CsWin32 for more Windows APIs
dotnet add package Microsoft.Windows.CsWin32 --version 0.3.269
```

---

## Migration Notes for Existing Codebase

### What's Already Good

1. **LibraryImport usage** in `WindowsApi.cs` - Modern, AOT-compatible
2. **Spectre.Console** for TUI - Correct library choice
3. **.NET 8** target - LTS with good AOT support
4. **PublishAot enabled** - Already configured correctly
5. **Service structure** - Clean separation of concerns

### Recommended Changes

1. **Add ConsoleAppFramework** for CLI argument parsing
   - Replace manual argument handling in `Program.cs` files
   - Zero overhead, fully AOT-safe

2. **Add JsonSerializerContext** for AOT-safe JSON
   - Create `AppJsonContext.cs` with all serializable types
   - Update ConfigService to use source-generated serialization

3. **Consider removing DI** for simple CLI tools
   - Bluepill, WakeupNeo are simple enough for direct instantiation
   - Reduces startup time and binary size

4. **Upgrade to .NET 10 LTS** when available and stable
   - Better AOT, smaller binaries
   - Supported until November 2028

---

## Sources

### Primary (HIGH confidence)
- [Microsoft .NET Support Policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)
- [Native AOT Deployment Overview](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/)
- [Platform Invoke (P/Invoke)](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke)
- [Spectre.Console NuGet](https://www.nuget.org/packages/Spectre.Console) - v0.54.0
- [ConsoleAppFramework NuGet](https://www.nuget.org/packages/ConsoleAppFramework) - v5.7.13
- [CsWin32 NuGet](https://www.nuget.org/packages/Microsoft.Windows.CsWin32) - v0.3.269

### Secondary (MEDIUM confidence)
- [ConsoleAppFramework v5 Announcement](https://neuecc.medium.com/consoleappframework-v5-zero-overhead-native-aot-compatible-cli-framework-for-c-8f496df8d9d1)
- [Spectre.Console AOT Issue #1332](https://github.com/spectreconsole/spectre.console/issues/1332)
- [Terminal.Gui v2 What's New](https://gui-cs.github.io/Terminal.Gui/docs/newinv2.html)

---

## Version Summary Table

| Package | Recommended Version | Native AOT | Last Verified |
|---------|---------------------|------------|---------------|
| .NET SDK | 8.0.x (or 9.0.x) | Yes | 2026-01-25 |
| Spectre.Console | 0.54.0 | Yes | 2026-01-25 |
| ConsoleAppFramework | 5.7.13 | Yes | 2026-01-25 |
| Microsoft.Windows.CsWin32 | 0.3.269 | Yes | 2026-01-25 |
| System.Text.Json | 8.0.x (built-in) | Yes* | 2026-01-25 |

*Requires JsonSerializerContext for full AOT compatibility
