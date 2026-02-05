# Architecture Patterns

**Domain:** C# Terminal Application with Windows API Integration
**Researched:** 2026-01-25
**Confidence:** HIGH (based on existing codebase patterns + verified best practices)

## Executive Summary

This architecture validates and extends the existing MatrixShader C# project structure. The current design follows industry patterns for .NET 8 console applications with Windows interop. Key recommendations: maintain the Core/CLI separation, use Microsoft.Extensions.DependencyInjection consistently, consider CsWin32 for future P/Invoke maintenance, and implement services with explicit lifetime management.

## Recommended Architecture

```
MatrixShader/
├── src/
│   ├── MatrixShader.Core/              # Shared library (services, models, native API)
│   │   ├── Constants/                  # ColorPresets, KatakanaChars
│   │   ├── Models/                     # ShaderConfig, WindowInfo, MonitorInfo, etc.
│   │   ├── Native/                     # WindowsApi P/Invoke declarations
│   │   └── Services/                   # Business logic services
│   │       ├── IShaderService.cs       # Shader file manipulation
│   │       ├── IConfigService.cs       # JSON state persistence
│   │       ├── ILayoutService.cs       # Window positioning algorithms
│   │       ├── IIdentityService.cs     # Window identity resolution
│   │       └── EnvironmentService.cs   # Render mode detection
│   │
│   ├── MatrixShader.Cli.Redpill/       # Control panel TUI
│   ├── MatrixShader.Cli.Bluepill/      # Quick launcher
│   ├── MatrixShader.Cli.WakeupNeo/     # Setup wizard
│   ├── MatrixShader.Lite/              # Text-based fallback renderer
│   └── MatrixShader.Monitor/           # Background window monitor service
│
└── tests/                              # Test projects (future)
```

### Component Boundaries

| Component | Responsibility | Communicates With | Lifetime |
|-----------|---------------|-------------------|----------|
| MatrixShader.Core | Shared services, models, Windows API | All CLI apps | Library (stateless) |
| MatrixShader.Cli.Redpill | Interactive TUI for shader control | Core services | Short-lived (user session) |
| MatrixShader.Cli.Bluepill | Quick launch with saved settings | Core services | Short-lived (seconds) |
| MatrixShader.Cli.WakeupNeo | First-time setup wizard | Core services | Short-lived (setup flow) |
| MatrixShader.Lite | Text-based Matrix rain fallback | Core constants only | Long-running animation |
| MatrixShader.Monitor | Background window position tracking | Core services | Long-running service |

### Data Flow

```
User Input (keyboard)
       │
       ▼
┌─────────────────┐
│  CLI App (TUI)  │  Redpill, Bluepill, WakeupNeo
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Core Services  │  ShaderService, LayoutService, IdentityService
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐  ┌───────────┐
│ Files │  │ WindowsApi │
└───┬───┘  └─────┬─────┘
    │            │
    ▼            ▼
┌───────┐  ┌─────────────────┐
│ .hlsl │  │ Window Handles  │
└───────┘  └─────────────────┘
    │
    ▼
┌──────────────────────┐
│ Windows Terminal     │
│ (Hot-reload shader)  │
└──────────────────────┘
```

## Component Details

### MatrixShader.Core (465+ lines already implemented)

**Purpose:** Shared library containing all reusable services, models, and Windows API declarations.

**Already Implemented:**
- `LayoutService` (465 lines) - Pillars/Quads/Overlap layout calculations
- `IdentityService` (445 lines) - 4-layer window identity resolution
- `WindowsApi` (344 lines) - P/Invoke declarations for user32.dll

**To Implement:**
- `ShaderService` - HLSL file read/write with #define injection
- `ConfigService` - Full JSON state persistence (matrix_state.json, registries)
- `TerminalSettingsService` - Windows Terminal settings.json manipulation

**Dependencies:**
```xml
<PackageReference Include="Microsoft.Extensions.Logging.Abstractions" />
<PackageReference Include="System.Management" />  <!-- WMI queries -->
<PackageReference Include="System.Text.Json" />
```

**Key Design Patterns:**
- Interface-based services (`IShaderService`, `ILayoutService`, `IIdentityService`)
- Record types for immutable data models (`WindowInfo`, `MonitorInfo`, `ShaderConfig`)
- Static utility class for P/Invoke (`WindowsApi`)
- Thread-safe registry with locking (`IdentityService._lock`)

### MatrixShader.Cli.Redpill

**Purpose:** Full-featured control panel TUI for shader parameter adjustment.

**Architecture:**
```csharp
// Program.cs - Entry point with DI setup
public static async Task<int> Main(string[] args)
{
    var services = new ServiceCollection();
    ConfigureServices(services);
    var provider = services.BuildServiceProvider();

    // Detect render mode (Full vs Lite)
    var envService = provider.GetRequiredService<EnvironmentService>();
    var mode = envService.DetectRenderMode();

    if (mode == RenderMode.Full)
    {
        var panel = provider.GetRequiredService<ControlPanel>();
        await panel.RunAsync();
    }
    else
    {
        // Fall back to MatrixLite text renderer
        var menu = new FallbackMenu();
        await menu.RunAsync(CancellationToken.None);
    }
}

// DI Configuration
private static void ConfigureServices(IServiceCollection services)
{
    services.AddLogging(...);
    services.AddSingleton<EnvironmentService>();
    services.AddSingleton<IShaderService, ShaderService>();
    services.AddSingleton<IConfigService, ConfigService>();
    services.AddSingleton<ILayoutService, LayoutService>();
    services.AddSingleton<IIdentityService, IdentityService>();
    services.AddSingleton<ControlPanel>();
}
```

**Dependencies:**
- `Spectre.Console` - Rich console output (tables, colors, markup)
- `MatrixShader.Core` - All services
- `MatrixShader.Lite` - Fallback renderer

### MatrixShader.Cli.Bluepill

**Purpose:** Quick launcher that starts Matrix with saved settings, no TUI.

**Architecture:** Minimal - just loads state, launches terminals, applies layout, exits.

```csharp
public class QuickLauncher
{
    private readonly IConfigService _configService;
    private readonly ILayoutService _layoutService;
    private readonly IIdentityService _identityService;

    public async Task LaunchAsync()
    {
        // Load saved state
        var state = _configService.LoadState();

        // Launch Windows Terminal windows
        foreach (var slot in state.LastSlots)
        {
            LaunchTerminalWithProfile($"Matrix-{slot}");
        }

        // Wait for windows and apply layout
        var windows = await WaitForWindowsAsync(state.LastSlots.Count);
        var positions = _layoutService.CalculateLayout(windows, state.LayoutConfig);
        _layoutService.ApplyLayout(positions);
    }
}
```

### MatrixShader.Monitor

**Purpose:** Background service that monitors window positions and re-applies layout on drag.

**Architecture:** Hosted service using `IHostedService` pattern.

```csharp
// Program.cs - Generic host for background service
public static async Task Main(string[] args)
{
    var builder = Host.CreateApplicationBuilder(args);

    builder.Services.AddHostedService<MonitorService>();
    builder.Services.AddSingleton<IConfigService, ConfigService>();

    var host = builder.Build();
    await host.RunAsync();
}

// MonitorService.cs - BackgroundService implementation
public class MonitorService : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            CheckWindows();
            await Task.Delay(PollIntervalMs, stoppingToken);
        }
    }
}
```

### MatrixShader.Lite

**Purpose:** Text-based Matrix rain renderer for terminals without shader support.

**Architecture:** Self-contained with minimal dependencies on Core.

```csharp
public class TextMatrixRenderer : IDisposable
{
    private readonly Column[] _columns;
    private readonly StringBuilder _buffer;

    // ANSI escape codes for cursor/color control
    private const string HideCursor = "\x1b[?25l";
    private const string ShowCursor = "\x1b[?25h";

    public async Task RunAsync(CancellationToken cancellationToken)
    {
        Initialize();
        while (!cancellationToken.IsCancellationRequested)
        {
            RenderFrame();
            await Task.Delay(frameDelay, cancellationToken);
        }
        Cleanup();
    }
}
```

## Patterns to Follow

### Pattern 1: Interface-Based Service Design

**What:** Define interfaces for all services; inject dependencies via constructor.

**When:** All service classes that have external dependencies or need testing.

**Example (from existing LayoutService):**
```csharp
public interface ILayoutService
{
    IReadOnlyList<MonitorInfo> GetMonitors();
    IReadOnlyList<WindowPosition> CalculateLayout(
        IReadOnlyList<WindowInfo> windows,
        LayoutConfig config);
    void ApplyLayout(IReadOnlyList<WindowPosition> positions);
    LayoutMode CycleMode(LayoutMode currentMode);
}

public class LayoutService : ILayoutService
{
    // Implementation calls WindowsApi static methods
    public IReadOnlyList<MonitorInfo> GetMonitors()
    {
        var monitors = WindowsApi.GetMonitors();
        // ... processing
    }
}
```

**Rationale:** Enables unit testing with mocks, supports DI container, follows SOLID principles.

### Pattern 2: Record Types for Immutable Models

**What:** Use C# records for data models that should be immutable with value semantics.

**When:** Configuration objects, window information, calculated positions.

**Example (from existing code):**
```csharp
public record WindowInfo
{
    public nint Handle { get; init; }
    public string Title { get; init; } = string.Empty;
    public int ProcessId { get; init; }
    public string ProfileName { get; init; } = string.Empty;
    public int ShaderIndex { get; init; }
    public WindowRect Position { get; init; }
    public IdentitySource Source { get; init; }
    public bool IsControlPanel { get; init; }
}

public record WindowPosition
{
    public required WindowInfo Window { get; init; }
    public required WindowRect Target { get; init; }
    public required MonitorInfo Monitor { get; init; }
}
```

**Rationale:** Records provide `with` expressions for immutable updates, value equality, and clean syntax.

### Pattern 3: Static P/Invoke Wrapper Class

**What:** Centralize all P/Invoke declarations in a static partial class.

**When:** Any Windows API interop.

**Example (from existing WindowsApi):**
```csharp
public static partial class WindowsApi
{
    // LibraryImport for source-generated P/Invoke (faster than DllImport)
    [LibraryImport("user32.dll")]
    public static partial nint GetForegroundWindow();

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsWindowVisible(nint hWnd);

    // Helper methods wrapping raw P/Invoke
    public static string GetWindowTitle(nint hWnd)
    {
        int length = GetWindowTextLength(hWnd);
        if (length == 0) return string.Empty;
        var sb = new StringBuilder(length + 1);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }
}
```

**Rationale:** Single location for all native interop, uses modern `LibraryImport` for better performance.

### Pattern 4: Dependency Injection with ServiceCollection

**What:** Use `Microsoft.Extensions.DependencyInjection` for service registration and resolution.

**When:** All CLI application entry points.

**Example (from existing Redpill):**
```csharp
private static void ConfigureServices(IServiceCollection services)
{
    // Logging
    services.AddLogging(builder =>
    {
        builder.SetMinimumLevel(LogLevel.Information);
        builder.AddSimpleConsole(options =>
        {
            options.SingleLine = true;
            options.TimestampFormat = "HH:mm:ss ";
        });
    });

    // Services - all singletons for this application type
    services.AddSingleton<EnvironmentService>();
    services.AddSingleton<IShaderService, ShaderService>();
    services.AddSingleton<IConfigService, ConfigService>();
    services.AddSingleton<ILayoutService, LayoutService>();
    services.AddSingleton<IIdentityService, IdentityService>();
    services.AddSingleton<ControlPanel>();
}
```

**Rationale:** Standard .NET pattern, enables testing, supports logging and configuration integration.

### Pattern 5: Thread-Safe Registry with Locking

**What:** Use lock objects for mutable shared state in services.

**When:** Services that maintain in-memory state accessed from multiple paths.

**Example (from existing IdentityService):**
```csharp
public class IdentityService : IIdentityService
{
    private readonly Dictionary<string, LaunchEntry> _launchRegistry = new();
    private readonly object _lock = new();

    public void RegisterLaunch(int processId, string profileName, int shaderIndex)
    {
        lock (_lock)
        {
            var entry = new LaunchEntry { ... };
            _launchRegistry[processId.ToString()] = entry;
            SaveRegistry();
        }
    }
}
```

**Rationale:** Services are singletons; multiple operations may access registry concurrently.

### Pattern 6: Atomic File Writes

**What:** Write to temp file, then move/rename to target.

**When:** Any persistent file that could be corrupted by partial write.

**Example:**
```csharp
public void SaveRegistry()
{
    try
    {
        var tempFile = Path.GetTempFileName();
        var json = JsonSerializer.Serialize(_launchRegistry, new JsonSerializerOptions
        {
            WriteIndented = true
        });
        File.WriteAllText(tempFile, json);
        File.Move(tempFile, _registryPath, overwrite: true);
    }
    catch (Exception)
    {
        // Silently fail - registry is optional, log if logging available
    }
}
```

**Rationale:** Prevents corruption if write is interrupted; mirrors PowerShell US-001 pattern.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Inline P/Invoke in Business Logic

**What:** Declaring P/Invoke methods directly in service classes.

**Why bad:** Duplicated declarations, harder to test, inconsistent error handling.

**Instead:** Centralize all P/Invoke in `WindowsApi` static class.

### Anti-Pattern 2: Hardcoded Paths

**What:** Embedding absolute file paths in code.

**Why bad:** Breaks on different machines, different user profiles.

**Instead:**
```csharp
// Good
var documentsPath = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
var registryPath = Path.Combine(documentsPath, "Matrix", "identity-registry.json");

// Bad
var registryPath = @"C:\Users\ehome\Documents\Matrix\identity-registry.json";
```

### Anti-Pattern 3: Synchronous File I/O in UI Loop

**What:** Blocking file reads/writes in the main render loop.

**Why bad:** Causes UI stuttering, especially with slow disks.

**Instead:** Use async I/O for file operations, or do heavy I/O on background thread.

### Anti-Pattern 4: Service Locator Pattern

**What:** Resolving services via `ServiceProvider.GetService<T>()` throughout code.

**Why bad:** Hidden dependencies, harder to test, defeats DI benefits.

**Instead:** Always inject dependencies via constructor.

### Anti-Pattern 5: Swallowing Exceptions Silently

**What:** Empty catch blocks with no logging.

**Why bad:** Hides bugs, makes debugging impossible.

**Instead:**
```csharp
// Good
catch (Exception ex)
{
    _logger.LogWarning(ex, "Failed to load registry, using defaults");
    // Continue with defaults
}

// Bad
catch (Exception)
{
    // Silent fail
}
```

## Service Lifetime Patterns

| Service | Lifetime | Rationale |
|---------|----------|-----------|
| ILayoutService | Singleton | Stateless calculations, expensive to create (P/Invoke setup) |
| IIdentityService | Singleton | Maintains launch registry in memory |
| IShaderService | Singleton | File paths don't change during execution |
| IConfigService | Singleton | State loaded once, updated in place |
| EnvironmentService | Singleton | Detects environment once at startup |
| ControlPanel | Singleton | Single UI instance per application |

**Key insight:** For CLI applications with short lifespans, Singleton is appropriate for nearly all services. Transient would work but adds unnecessary object creation overhead.

## Build Order (Dependencies)

Build order must respect project dependencies:

```
Phase 1: MatrixShader.Core (no other project deps)
    ├── Models/
    ├── Constants/
    ├── Native/WindowsApi.cs
    └── Services/ (interfaces + implementations)

Phase 2: MatrixShader.Lite (depends only on Core.Constants)
    ├── Column.cs
    ├── TextMatrixRenderer.cs
    └── FallbackMenu.cs

Phase 3: CLI Applications (depend on Core + optionally Lite)
    ├── MatrixShader.Cli.Bluepill   (depends: Core)
    ├── MatrixShader.Cli.WakeupNeo  (depends: Core)
    └── MatrixShader.Cli.Redpill    (depends: Core, Lite)

Phase 4: MatrixShader.Monitor (depends on Core)
    └── Background service for window monitoring
```

**Implementation priority for remaining services:**

1. **ShaderService** - Required by all CLI apps for shader manipulation
2. **ConfigService** (full implementation) - Required for state persistence
3. **CLI apps completion** - Redpill needs TUI completion, others need launch logic
4. **MatrixLite polish** - Already implemented, may need refinement
5. **Monitor service** - Already implemented, may need integration

## Cross-Platform Considerations

**Current:** Windows-only due to Windows Terminal shader dependency and P/Invoke.

**Future potential:**
- MatrixLite is already cross-platform (ANSI escape codes)
- Core models are platform-agnostic
- Only `WindowsApi` and Window Terminal integration are Windows-specific

**Architecture supports this:** Platform-specific code isolated in `Native/` namespace.

## Sources

**Official Documentation (HIGH confidence):**
- [Microsoft Learn: P/Invoke Source Generation](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke-source-generation)
- [Microsoft Learn: Dependency Injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)
- [Microsoft Learn: Worker Services](https://learn.microsoft.com/en-us/dotnet/core/extensions/workers)
- [Microsoft Learn: Create Windows Service using BackgroundService](https://learn.microsoft.com/en-us/dotnet/core/extensions/windows-service)

**Project Sources (HIGH confidence):**
- Existing `LayoutService.cs` (465 lines) - Reference implementation
- Existing `IdentityService.cs` (445 lines) - Reference implementation
- Existing `WindowsApi.cs` (344 lines) - Reference implementation
- Existing `Program.cs` files in CLI projects - DI patterns

**Community Patterns (MEDIUM confidence):**
- [Spectre.Console Documentation](https://spectreconsole.net/) - TUI library patterns
- [GitHub: CsWin32](https://github.com/microsoft/CsWin32) - P/Invoke source generator (consider for future)
- [Steve Gordon: Worker Services](https://www.stevejgordon.co.uk/what-are-dotnet-worker-services) - Background service patterns

---

*Architecture research: 2026-01-25*
