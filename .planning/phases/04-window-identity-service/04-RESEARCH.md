# Phase 4: Window Identity Service - Research

**Researched:** 2026-01-26
**Domain:** Window Identity Resolution, Process Inspection, UI Automation, Registry Persistence
**Confidence:** HIGH

## Summary

Phase 4 implements reliable window identity resolution for Matrix shader windows. The system must distinguish Matrix windows from other Windows Terminal instances, track identity through window lifecycle events, assign confidence scores, and persist mappings across application restarts.

The existing C# codebase already has a foundation (`IdentityService.cs`, 445 lines) implementing the 4-layer hierarchy. This research validates the approach, identifies gaps between the C# and PowerShell implementations, and provides guidance for completing the implementation to match PowerShell behavior exactly.

Key findings:
- WMI via `System.Management` is the correct approach for command line retrieval - no better alternative exists
- UI Automation via `System.Windows.Automation.AutomationElement.FromHandle()` works in .NET 8 Windows Desktop
- Windows Terminal exposes profile names in `TermControl` class elements (ClassName property condition)
- The existing IdentityService needs confidence scoring, AppData\Local persistence, and cleanup logic

**Primary recommendation:** Complete the existing IdentityService by adding confidence scoring (matching PowerShell values exactly), moving registry to `AppData\Local\MatrixShader`, adding 24-hour cleanup, and implementing UI Automation Layer 4 with TermControl/TabItem detection.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| System.Management | 10.0.2 | WMI queries for process command line | Only reliable way to get command line of another process |
| UIAutomationClient | .NET 8 WinDesktop | UI element inspection for profile detection | Built-in .NET assembly, works with FromHandle() |
| UIAutomationTypes | .NET 8 WinDesktop | UI Automation type definitions | Companion to UIAutomationClient |
| System.Text.Json | 8.0.x | JSON serialization with source generation | AOT-compatible, already used in project |
| user32.dll | System | Window handle validation (IsWindow, IsWindowVisible) | Required Windows APIs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| System.Diagnostics.Process | .NET 8 | Process existence validation | Validating PID entries |
| System.IO | .NET 8 | Atomic file writes for registry | Temp file + Move pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| System.Management (WMI) | NtQueryInformationProcess | WMI is supported/documented, NtQueryInformationProcess is undocumented |
| UIAutomationClient | FlaUI 5.0.0 | FlaUI adds NuGet dependency, built-in works fine |
| Manual JSON | JsonSerializerContext | Already using source-generated JSON in project |

**Installation:**
```xml
<!-- Add to MatrixShader.Core.csproj if not present -->
<PackageReference Include="System.Management" Version="10.0.2" />
<!-- UIAutomationClient/UIAutomationTypes are implicit with WindowsDesktop workload -->
```

## Architecture Patterns

### Recommended Project Structure
```
MatrixShader.Core/
├── Native/
│   └── WindowsApi.cs          # Window handle validation (IsWindow)
├── Models/
│   ├── WindowInfo.cs          # Extended with Confidence property
│   ├── IdentitySource.cs      # Enum with sub-variants
│   └── IdentityEntry.cs       # NEW: Registry entry model
├── Services/
│   ├── IIdentityService.cs    # Interface (existing)
│   └── IdentityService.cs     # Implementation (extend)
└── Serialization/
    └── MatrixJsonContext.cs   # Add IdentityRegistry serialization
```

### Pattern 1: 4-Layer Identity Resolution (Port from PowerShell)
**What:** Hierarchical identity resolution with early exit on match
**When to use:** Every window identity query
**Example:**
```csharp
// Source: WindowIdentityService.ps1 lines 904-980
public WindowInfo? ResolveIdentity(nint hwnd)
{
    // Validate handle first - both IsWindow AND IsWindowVisible
    if (!WindowsApi.IsWindow(hwnd) || !WindowsApi.IsWindowVisible(hwnd))
        return null;

    var processId = WindowsApi.GetWindowProcessId(hwnd);
    var title = WindowsApi.GetWindowTitle(hwnd);

    // Layer 1: Launch Tracking (confidence 1.0 fresh, 0.95 from disk)
    var identity = GetLaunchRegistryIdentity(hwnd, processId);
    if (identity != null) return identity;

    // Layer 2: Command Line Parsing (confidence 0.95)
    identity = GetCommandLineIdentity(processId);
    if (identity != null) return identity;

    // Layer 3: Title Matching (confidence 0.70)
    identity = GetTitleIdentity(hwnd, title);
    if (identity != null) return identity;

    // Layer 4: UI Automation (confidence 0.85-0.95)
    identity = GetUIAutomationIdentity(hwnd);
    return identity;
}
```

### Pattern 2: Batch WMI Query (Performance Optimization)
**What:** Query all process command lines in single WMI call
**When to use:** FindMatrixWindows when multiple windows exist
**Example:**
```csharp
// Source: WindowIdentityService.ps1 lines 527-607 Get-CommandLineIdentities
private Dictionary<int, string> BatchQueryCommandLines(IEnumerable<int> processIds)
{
    var results = new Dictionary<int, string>();
    if (!processIds.Any()) return results;

    // Build WMI query: SELECT ProcessId, CommandLine FROM Win32_Process WHERE ProcessId=1 OR ProcessId=2...
    var pidFilter = string.Join(" OR ", processIds.Select(p => $"ProcessId={p}"));
    var query = $"SELECT ProcessId, CommandLine FROM Win32_Process WHERE ({pidFilter})";

    using var searcher = new ManagementObjectSearcher(query);
    foreach (ManagementObject obj in searcher.Get())
    {
        var pid = Convert.ToInt32(obj["ProcessId"]);
        var cmdLine = obj["CommandLine"]?.ToString();
        if (!string.IsNullOrEmpty(cmdLine))
        {
            results[pid] = cmdLine;
        }
    }
    return results;
}
```

### Pattern 3: UI Automation TermControl Detection
**What:** Find profile name from TermControl element's Name property
**When to use:** Layer 4 fallback when other layers fail
**Example:**
```csharp
// Source: WindowIdentityService.ps1 lines 752-787
private WindowInfo? GetUIAutomationIdentity(nint hwnd)
{
    var element = AutomationElement.FromHandle(hwnd);
    if (element == null) return null;

    // Priority 1: TermControl has profile name in Name property (confidence 0.95)
    var classCondition = new PropertyCondition(
        AutomationElement.ClassNameProperty,
        "TermControl");

    var termControls = element.FindAll(TreeScope.Descendants, classCondition);
    foreach (AutomationElement tc in termControls)
    {
        var name = tc.Current.Name;
        if (TryParseMatrixProfile(name, out var shaderIndex))
        {
            return CreateWindowInfo(hwnd, name, shaderIndex,
                IdentitySource.UIAutomationTermControl, 0.95);
        }
    }

    // Priority 2: TabItem fallback (confidence 0.85)
    var tabCondition = new PropertyCondition(
        AutomationElement.ControlTypeProperty,
        ControlType.TabItem);

    var tabs = element.FindAll(TreeScope.Descendants, tabCondition);
    foreach (AutomationElement tab in tabs)
    {
        var name = tab.Current.Name;
        if (TryParseMatrixProfile(name, out var shaderIndex))
        {
            return CreateWindowInfo(hwnd, name, shaderIndex,
                IdentitySource.UIAutomationTab, 0.85);
        }
    }

    // Priority 3: Window Name fallback (confidence 0.90)
    var windowName = element.Current.Name;
    if (TryParseMatrixProfile(windowName, out var idx))
    {
        return CreateWindowInfo(hwnd, windowName, idx,
            IdentitySource.UIAutomationName, 0.90);
    }

    return null;
}
```

### Pattern 4: Atomic Registry Persistence
**What:** Safe JSON file writes with temp file + move
**When to use:** All registry save operations
**Example:**
```csharp
// Source: ConfigService.cs lines 65-103 (existing pattern)
private void SaveRegistryAtomic(IdentityRegistry registry)
{
    var tempPath = _registryPath + ".tmp";
    try
    {
        var dir = Path.GetDirectoryName(_registryPath);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        registry = registry with { SavedAt = DateTime.UtcNow };
        var json = JsonSerializer.Serialize(registry, IdentityJsonContext.Default.IdentityRegistry);
        File.WriteAllText(tempPath, json, new UTF8Encoding(false));
        File.Move(tempPath, _registryPath, overwrite: true);
    }
    catch
    {
        try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { }
        throw;
    }
}
```

### Anti-Patterns to Avoid
- **Calling UI Automation first:** UI Automation is 100-300ms per window - always try faster layers first
- **Single-process WMI queries in loop:** Batch all PIDs into one WMI query for O(1) vs O(n) calls
- **Trusting IsWindow alone:** Window handles are recycled - always validate with IsWindowVisible too
- **Storing handles in registry:** Handles are per-session - store by correlation ID or process/launch time
- **Reflection-based JSON:** Use source-generated serialization for AOT compatibility

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Process command line | NtQueryInformationProcess | System.Management WMI | WMI is documented, supported, handles access rights |
| UI element tree walking | Manual hwnd traversal | AutomationElement.FindAll | UI Automation handles accessibility tree correctly |
| JSON serialization for AOT | Reflection serializer | JsonSerializerContext | Required for Native AOT, project already uses it |
| Handle validation | Just IsWindow | IsWindow + IsWindowVisible | Handle recycling means visible check is required |
| Profile name parsing | Ad-hoc string parsing | Compiled Regex | Performance and correctness for repeated calls |

**Key insight:** The PowerShell implementation has already solved these problems with battle-tested code. The C# port should match the exact logic, not reinvent it.

## Common Pitfalls

### Pitfall 1: Window Handle Recycling
**What goes wrong:** Code assumes a saved handle still refers to the same window
**Why it happens:** Windows recycles handles; old handle may now be a different window
**How to avoid:** Validate with `IsWindow() && IsWindowVisible()` before using; clear stale entries immediately
**Warning signs:** Identity registry returns wrong profile for a window

### Pitfall 2: UI Automation Performance
**What goes wrong:** Application hangs or becomes sluggish
**Why it happens:** UI Automation tree walking is expensive (100-300ms per window)
**How to avoid:** Only use as Layer 4 fallback; batch queries where possible; cache results
**Warning signs:** 3+ seconds to enumerate 6 windows (target: 120ms)

### Pitfall 3: WMI Query Blocking
**What goes wrong:** Main thread blocks during WMI queries
**Why it happens:** WMI queries can take 20-50ms per call
**How to avoid:** Batch all PIDs into single query; consider async for larger window counts
**Warning signs:** UI freezes briefly when refreshing window list

### Pitfall 4: Registry Corruption on Crash
**What goes wrong:** Registry file is empty or partially written after crash
**Why it happens:** Direct file write interrupted mid-operation
**How to avoid:** Atomic write pattern: temp file + File.Move (move is atomic on same volume)
**Warning signs:** JSON parse errors on startup

### Pitfall 5: Stale Registry Entries Accumulating
**What goes wrong:** Registry grows indefinitely with dead entries
**Why it happens:** No cleanup when processes exit
**How to avoid:** Clean entries older than 24 hours on app startup; remove immediately when process gone
**Warning signs:** Registry file grows to megabytes over time

### Pitfall 6: Confidence Score Drift
**What goes wrong:** C# and PowerShell report different confidence values
**Why it happens:** Hardcoding different confidence values than PowerShell
**How to avoid:** Use exact values from PowerShell: Launch=1.0/0.95, CmdLine=0.95, Title=0.70, UIA=0.85-0.95
**Warning signs:** Test comparisons between implementations fail

## Code Examples

Verified patterns from official sources and PowerShell reference:

### Handle Validation (Matching PowerShell)
```csharp
// Source: WindowIdentityService.ps1 lines 842-868 Test-WindowHandleValid
// WindowsApi.cs already has IsWindow and IsWindowVisible

public static bool IsHandleValid(nint hwnd)
{
    if (hwnd == nint.Zero)
        return false;

    // BOTH must pass (context decision from 04-CONTEXT.md)
    return WindowsApi.IsWindow(hwnd) && WindowsApi.IsWindowVisible(hwnd);
}
```

### Confidence Scoring Enum
```csharp
// Source: 04-CONTEXT.md confidence thresholds section

/// <summary>
/// Identity resolution source with associated confidence.
/// </summary>
public enum IdentitySource
{
    Unknown = 0,
    LaunchTracking = 1,          // Confidence: 1.0 (fresh) or 0.95 (from disk)
    LaunchTrackingRecovered = 2, // Confidence: 0.95 (recovered from disk)
    CommandLine = 3,             // Confidence: 0.95
    Title = 4,                   // Confidence: 0.70
    UIAutomationTermControl = 5, // Confidence: 0.95
    UIAutomationTab = 6,         // Confidence: 0.85
    UIAutomationName = 7,        // Confidence: 0.90
}

public static class IdentitySourceExtensions
{
    public static double GetConfidence(this IdentitySource source) => source switch
    {
        IdentitySource.LaunchTracking => 1.0,
        IdentitySource.LaunchTrackingRecovered => 0.95,
        IdentitySource.CommandLine => 0.95,
        IdentitySource.UIAutomationTermControl => 0.95,
        IdentitySource.UIAutomationName => 0.90,
        IdentitySource.UIAutomationTab => 0.85,
        IdentitySource.Title => 0.70,
        _ => 0.0
    };
}
```

### Registry Model for JSON Serialization
```csharp
// Source: WindowIdentityService.ps1 lines 1104-1133 Save-IdentityRegistry

/// <summary>
/// Persisted identity registry format.
/// </summary>
public record IdentityRegistry
{
    public string Version { get; init; } = "1.0";
    public DateTime SavedAt { get; init; }
    public Dictionary<string, IdentityEntry> Entries { get; init; } = new();
}

public record IdentityEntry
{
    public string ProfileName { get; init; } = string.Empty;
    public int ShaderIndex { get; init; }
    public int ProcessId { get; init; }
    public string WindowHandle { get; init; } = string.Empty; // Stored as string for JSON
    public DateTime LaunchTime { get; init; }
    public string CorrelationId { get; init; } = string.Empty;
}

// Add to MatrixJsonContext.cs:
[JsonSerializable(typeof(IdentityRegistry))]
[JsonSerializable(typeof(IdentityEntry))]
[JsonSerializable(typeof(Dictionary<string, IdentityEntry>))]
```

### Registry Path (AppData\Local per Context Decision)
```csharp
// Source: 04-CONTEXT.md - deviation from PowerShell (Documents -> LocalAppData)

public IdentityService()
{
    var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    _registryPath = Path.Combine(localAppData, "MatrixShader", "identity-registry.json");
}
```

### 24-Hour Cleanup Logic
```csharp
// Source: WindowIdentityService.ps1 lines 1197-1253 Clean-WindowIdentityRegistry
// Trigger: On app startup (not periodic background)

public int CleanStaleEntries(TimeSpan maxAge = default)
{
    if (maxAge == default) maxAge = TimeSpan.FromHours(24);
    var cutoff = DateTime.UtcNow - maxAge;
    var removed = 0;
    var keysToRemove = new List<string>();

    lock (_lock)
    {
        foreach (var (key, entry) in _launchRegistry)
        {
            var shouldRemove = false;

            // Check if process still exists
            if (entry.ProcessId > 0)
            {
                try { Process.GetProcessById(entry.ProcessId); }
                catch { shouldRemove = true; }
            }

            // Check age
            if (!shouldRemove && entry.LaunchTime < cutoff)
                shouldRemove = true;

            if (shouldRemove)
                keysToRemove.Add(key);
        }

        foreach (var key in keysToRemove)
        {
            _launchRegistry.Remove(key);
            removed++;
        }

        if (removed > 0)
            SaveRegistry();
    }

    return removed;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DllImport | LibraryImport | .NET 7 (2022) | AOT-compatible P/Invoke |
| Reflection JSON | Source-generated JSON | .NET 6 (2021) | AOT-compatible serialization |
| Documents folder | LocalApplicationData | Current project | Better isolation, not synced |
| Single WMI calls | Batch WMI queries | PowerShell optimization | O(1) instead of O(n) performance |
| Title matching first | Launch tracking first | PowerShell 4-layer | 100% reliability for spawned windows |

**Deprecated/outdated:**
- `DllImport` for new P/Invoke: Use `LibraryImport` for AOT compatibility
- Reflection-based JsonSerializer: Use `JsonSerializerContext` for AOT compatibility
- `Documents\Matrix` for registry: Use `LocalApplicationData\MatrixShader` (context decision)

## Open Questions

Things that couldn't be fully resolved:

1. **TermControl class name stability**
   - What we know: PowerShell uses "TermControl" className successfully
   - What's unclear: Whether Windows Terminal updates might change this class name
   - Recommendation: Implement with "TermControl", add fallback to TabItem if not found

2. **Multi-tab window identity**
   - What we know: Windows Terminal can have multiple tabs; TermControl returns active tab profile
   - What's unclear: Behavior when user switches tabs after identity resolved
   - Recommendation: Track by window handle, re-resolve on demand if needed

3. **Handle vs PID for registry key**
   - What we know: PowerShell uses both handle-based and PID-based lookups
   - What's unclear: Which is more reliable for C# wt.exe launcher scenario
   - Recommendation: Prefer handle-based (more reliable), fall back to PID

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn: AutomationElement.FromHandle](https://learn.microsoft.com/en-us/dotnet/api/system.windows.automation.automationelement.fromhandle?view=windowsdesktop-8.0) - UI Automation API
- [Microsoft Learn: Win32_Process class](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process) - WMI CommandLine property
- [Microsoft Learn: IsWindow function](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-iswindow) - Handle validation
- [Microsoft Learn: System.Text.Json Source Generation](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/source-generation) - AOT JSON
- [NuGet: System.Management](https://www.nuget.org/packages/System.Management/) - WMI package for .NET
- Existing `WindowIdentityService.ps1` (1,287 lines) - Reference implementation
- Existing `IdentityService.cs` (445 lines) - Foundation to extend
- Existing `ConfigService.cs` - Atomic write pattern

### Secondary (MEDIUM confidence)
- [GitHub: FlaUI](https://github.com/FlaUI/FlaUI) - Alternative UI Automation library (not using, but validated approach)
- [Microsoft Learn: Obtaining UI Automation Elements](https://learn.microsoft.com/en-us/dotnet/framework/ui-automation/obtaining-ui-automation-elements) - Element retrieval patterns
- [Jonathan Crozier: Getting Process Command Line](https://jonathancrozier.com/blog/getting-the-command-line-of-a-running-process-using-c-sharp) - WMI approach validation

### Tertiary (LOW confidence)
- Community discussions about Windows Terminal UI Automation structure - TermControl class name may change in future versions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - WMI and UI Automation are well-documented, existing project patterns established
- Architecture: HIGH - PowerShell reference provides proven patterns, existing C# foundation is solid
- Pitfalls: HIGH - PowerShell code has solved these problems, patterns are documented

**Research date:** 2026-01-26
**Valid until:** 60 days (stable Windows APIs, Windows Terminal updates may affect TermControl)
