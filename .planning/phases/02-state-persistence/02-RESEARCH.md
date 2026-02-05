# Phase 2: State Persistence - Research

**Researched:** 2026-01-26
**Domain:** JSON configuration persistence with atomic file writes and Native AOT compatibility
**Confidence:** HIGH

## Summary

Phase 2 implements reliable state persistence for shader configurations. The existing codebase already has partial implementations: `ConfigService` with atomic file writes (temp + File.Move pattern) and `MatrixState` model with `ShaderConfig` dictionary. The primary gap is Native AOT compatibility via System.Text.Json source generators.

The critical requirements are:
1. **STATE-01**: Shader configuration persists to JSON (already partially implemented)
2. **STATE-05**: Atomic file writes prevent corruption (already implemented in Phase 1's ShaderService)

Phase 1 established the atomic write pattern (`Path.GetTempFileName()` + `File.Move(overwrite: true)`). Phase 2 extends this to JSON state files with source-generated serialization for Native AOT compatibility.

**Primary recommendation:** Add `JsonSerializerContext` with `[JsonSerializable]` attributes for all model types, enable `UseStringEnumConverter`, and ensure all JSON operations use the source-generated context.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| System.Text.Json | Built-in (.NET 8) | JSON serialization | Native, AOT-compatible with source generators |
| System.IO | Built-in (.NET 8) | File operations | Native atomic operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Microsoft.Extensions.Logging | 8.0.x | Diagnostic logging | Debug mode ($env:MATRIX_DEBUG=1) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| System.Text.Json | Newtonsoft.Json | Newtonsoft has no source generators; incompatible with Native AOT |
| File.Move | File.Replace | File.Replace is safer with backup but more complex; File.Move sufficient for this use case |
| Source generators | Reflection | Reflection breaks Native AOT; source generators are mandatory |

**Installation:**
Already available in .NET 8 SDK - no additional packages needed.

## Architecture Patterns

### Recommended Project Structure
```
MatrixShader.Core/
├── Models/
│   ├── ShaderConfig.cs        # Shader parameter model (exists)
│   ├── MatrixState.cs         # Complete application state (exists)
│   └── LayoutConfig.cs        # Layout configuration (exists)
├── Services/
│   ├── IConfigService.cs      # Interface (exists)
│   └── ConfigService.cs       # Implementation (needs source gen update)
└── Serialization/
    └── MatrixJsonContext.cs   # NEW: Source-generated JSON context
```

### Pattern 1: Source-Generated JsonSerializerContext
**What:** Define all serializable types in a single context for AOT compatibility
**When to use:** All JSON serialization/deserialization operations
**Example:**
```csharp
// Source: Microsoft Learn - System.Text.Json source generation
using System.Text.Json.Serialization;

namespace MatrixShader.Core.Serialization;

[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    UseStringEnumConverter = true)]
[JsonSerializable(typeof(MatrixState))]
[JsonSerializable(typeof(ShaderConfig))]
[JsonSerializable(typeof(LayoutConfig))]
[JsonSerializable(typeof(Dictionary<int, ShaderConfig>))]
internal partial class MatrixJsonContext : JsonSerializerContext
{
}
```

### Pattern 2: Atomic File Write with Source Generation
**What:** Write JSON using source-generated context with atomic temp+move pattern
**When to use:** Any state persistence operation
**Example:**
```csharp
// Source: Phase 1 ShaderService pattern + source generation
public void SaveState(MatrixState state)
{
    var tempPath = Path.GetTempFileName();
    try
    {
        state = state with { LastModified = DateTime.UtcNow };

        // Use source-generated context for AOT compatibility
        var json = JsonSerializer.Serialize(state, MatrixJsonContext.Default.MatrixState);
        File.WriteAllText(tempPath, json, new UTF8Encoding(false));

        // Atomic move
        File.Move(tempPath, StatePath, overwrite: true);
        _logger.LogDebug("Saved state to {Path}", StatePath);
    }
    catch
    {
        if (File.Exists(tempPath))
            File.Delete(tempPath);
        throw;
    }
}
```

### Pattern 3: Graceful Fallback on Corrupt JSON
**What:** Return defaults when JSON parsing fails, never crash
**When to use:** All state loading operations
**Example:**
```csharp
// Source: Existing ConfigService.LoadState pattern
public MatrixState LoadState()
{
    if (!StateExists)
    {
        _logger.LogInformation("No state file found, using defaults");
        return new MatrixState();
    }

    try
    {
        var json = File.ReadAllText(StatePath);
        var state = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.MatrixState);
        return state ?? new MatrixState();
    }
    catch (JsonException ex)
    {
        _logger.LogError(ex, "Failed to parse state file, using defaults");
        return new MatrixState();
    }
    catch (IOException ex)
    {
        _logger.LogError(ex, "Failed to read state file, using defaults");
        return new MatrixState();
    }
}
```

### Pattern 4: Enum Serialization for Native AOT
**What:** Use generic `JsonStringEnumConverter<TEnum>` instead of non-generic version
**When to use:** Any enum types that need string serialization
**Example:**
```csharp
// Source: .NET 8 System.Text.Json blog
// The generic converter is source-generator friendly
[JsonConverter(typeof(JsonStringEnumConverter<RenderMode>))]
public enum RenderMode
{
    Full,
    Lite,
    Headless
}

// Or use UseStringEnumConverter = true in JsonSourceGenerationOptions (preferred)
```

### Anti-Patterns to Avoid
- **Runtime reflection:** Never use `JsonSerializer.Serialize<T>()` without a context in AOT apps
- **Non-generic enum converter:** `JsonStringEnumConverter` (non-generic) breaks Native AOT
- **Direct file write:** Never write directly to target file; always use temp+move pattern
- **Swallowing exceptions silently:** Always log errors before falling back to defaults

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON serialization | Custom serializer | System.Text.Json + source gen | AOT-compatible, fast, maintained |
| Atomic writes | Custom transaction system | File.Move(overwrite: true) | Native atomic operation on Windows |
| Enum to string | Custom ToString/Parse | JsonStringEnumConverter<T> | Handles all edge cases |
| Config path resolution | Hardcoded paths | Environment.GetFolderPath | Cross-user compatibility |

**Key insight:** The existing ConfigService already has the correct atomic write pattern. The main work is adding the source-generated JSON context and updating Serialize/Deserialize calls to use it.

## Common Pitfalls

### Pitfall 1: Using Reflection-Based Serialization
**What goes wrong:** Native AOT app crashes at runtime with cryptic errors
**Why it happens:** Default `JsonSerializer.Serialize<T>()` uses reflection
**How to avoid:** Always pass `MatrixJsonContext.Default.TypeName` to serialization calls
**Warning signs:** Works in debug, crashes in Release/AOT builds

### Pitfall 2: Missing [JsonSerializable] for Collection Types
**What goes wrong:** Serialization fails for `Dictionary<int, ShaderConfig>`
**Why it happens:** Source generator needs explicit type registration
**How to avoid:** Add `[JsonSerializable(typeof(Dictionary<int, ShaderConfig>))]` to context
**Warning signs:** "Missing type info" exceptions at runtime

### Pitfall 3: Temp File in Wrong Directory
**What goes wrong:** Atomic move fails with "different volume" error
**Why it happens:** `Path.GetTempFileName()` uses system temp, target may be different drive
**How to avoid:** Use `StatePath + ".tmp"` instead of system temp for atomic safety
**Warning signs:** IOException during File.Move

### Pitfall 4: Non-Generic Enum Converter
**What goes wrong:** Source generator emits SYSLIB1034 warning; AOT breaks
**Why it happens:** `JsonStringEnumConverter` requires runtime code generation
**How to avoid:** Use `JsonStringEnumConverter<TEnum>` or `UseStringEnumConverter = true` in options
**Warning signs:** Warning during build, crash in AOT

### Pitfall 5: File Locked by Another Process
**What goes wrong:** Save fails when another process (antivirus, editor) has file open
**Why it happens:** Windows file locking during write operations
**How to avoid:** Catch IOException, retry with exponential backoff, log warning
**Warning signs:** Intermittent save failures, especially on slow systems

## Code Examples

Verified patterns from official sources and existing codebase:

### Complete JsonSerializerContext Definition
```csharp
// Source: Microsoft Learn + existing models
using System.Text.Json.Serialization;
using MatrixShader.Core.Models;

namespace MatrixShader.Core.Serialization;

/// <summary>
/// Source-generated JSON serializer context for Native AOT compatibility.
/// </summary>
[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    UseStringEnumConverter = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
[JsonSerializable(typeof(MatrixState))]
[JsonSerializable(typeof(ShaderConfig))]
[JsonSerializable(typeof(LayoutConfig))]
[JsonSerializable(typeof(Dictionary<int, ShaderConfig>))]
internal partial class MatrixJsonContext : JsonSerializerContext
{
}
```

### Updated SaveState with Source Generation
```csharp
// Source: Existing ConfigService + source gen pattern
public void SaveState(MatrixState state)
{
    var tempPath = StatePath + ".tmp";  // Same directory for atomic safety
    try
    {
        // Ensure directory exists
        var dir = Path.GetDirectoryName(StatePath);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
        {
            Directory.CreateDirectory(dir);
        }

        // Update timestamp
        state = state with { LastModified = DateTime.UtcNow };

        // Serialize with source-generated context (AOT-safe)
        var json = JsonSerializer.Serialize(state, MatrixJsonContext.Default.MatrixState);
        File.WriteAllText(tempPath, json, new UTF8Encoding(false));

        // Atomic move
        File.Move(tempPath, StatePath, overwrite: true);
        _logger.LogDebug("Saved state to {Path}", StatePath);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Failed to save state to {Path}", StatePath);

        // Clean up temp file
        try { if (File.Exists(tempPath)) File.Delete(tempPath); }
        catch { /* ignore cleanup failures */ }

        throw;
    }
}
```

### Updated LoadState with Source Generation
```csharp
// Source: Existing ConfigService + source gen pattern
public MatrixState LoadState()
{
    if (!StateExists)
    {
        _logger.LogInformation("No state file found at {Path}, using defaults", StatePath);
        return new MatrixState();
    }

    try
    {
        var json = File.ReadAllText(StatePath);

        // Deserialize with source-generated context (AOT-safe)
        var state = JsonSerializer.Deserialize(json, MatrixJsonContext.Default.MatrixState);

        if (state is null)
        {
            _logger.LogWarning("State file parsed as null, using defaults");
            return new MatrixState();
        }

        _logger.LogDebug("Loaded state from {Path}", StatePath);
        return state;
    }
    catch (JsonException ex)
    {
        _logger.LogError(ex, "Invalid JSON in state file {Path}, using defaults", StatePath);
        return new MatrixState();
    }
    catch (IOException ex)
    {
        _logger.LogError(ex, "Could not read state file {Path}, using defaults", StatePath);
        return new MatrixState();
    }
}
```

### Disable Reflection-Based Serialization (Project File)
```xml
<!-- Source: Microsoft Learn - Disabling reflection for AOT -->
<PropertyGroup>
    <!-- Ensure AOT safety by disabling reflection-based JSON -->
    <JsonSerializerIsReflectionEnabledByDefault>false</JsonSerializerIsReflectionEnabledByDefault>
</PropertyGroup>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Newtonsoft.Json | System.Text.Json | .NET Core 3.0 (2019) | Native, faster, AOT-compatible |
| Reflection serialization | Source generators | .NET 6 (2021) | AOT support, faster startup |
| JsonStringEnumConverter | JsonStringEnumConverter<T> | .NET 8 (2023) | AOT-safe enum handling |
| Manual JSON options | JsonSourceGenerationOptionsAttribute | .NET 8 (2023) | Compile-time configuration |

**Deprecated/outdated:**
- `Newtonsoft.Json`: Not AOT-compatible; use System.Text.Json
- Non-generic `JsonStringEnumConverter`: Use `JsonStringEnumConverter<TEnum>` for AOT
- Reflection-based serialization: Disable with `JsonSerializerIsReflectionEnabledByDefault=false`

## Open Questions

Things that couldn't be fully resolved:

1. **Backup file strategy**
   - What we know: `File.Replace` can create backup files; PowerShell uses temp+move without backup
   - What's unclear: Is backup worth the complexity for user config files?
   - Recommendation: Skip backup for now (temp+move is sufficient); add if users report data loss

2. **Retry logic for locked files**
   - What we know: Antivirus can lock files briefly; Windows has transient lock issues
   - What's unclear: Optimal retry count and backoff timing
   - Recommendation: Add 3 retries with 100ms delay; log warning on retry

3. **State file location**
   - What we know: PowerShell uses `$env:USERPROFILE\Documents\Matrix`
   - What's unclear: Should C# version use `AppData\Local` instead (more standard)?
   - Recommendation: Keep Documents\Matrix for compatibility with existing PowerShell users

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn - System.Text.Json source generation](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/source-generation) - Context definition patterns
- [.NET Blog - System.Text.Json in .NET 8](https://devblogs.microsoft.com/dotnet/system-text-json-in-dotnet-8/) - JsonStringEnumConverter<T>, AOT improvements
- [Microsoft Learn - Atomic file writes](https://learn.microsoft.com/en-us/archive/blogs/adioltean/how-to-do-atomic-writes-in-a-file) - Temp+move pattern
- Existing `ConfigService.cs` - Current implementation with atomic writes
- Existing `ShaderService.cs` - Phase 1 atomic write pattern

### Secondary (MEDIUM confidence)
- [Microsoft Learn - File.Replace](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace?view=net-10.0) - Backup file option
- [Atomic File Writes on Windows](https://antonymale.co.uk/windows-atomic-file-writes.html) - Windows-specific considerations

### Tertiary (LOW confidence)
- Retry timing (3 retries, 100ms) - Community convention, not officially documented

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - built-in .NET 8 libraries, well-documented source generators
- Architecture: HIGH - patterns from Microsoft Learn, existing codebase already implements correctly
- Pitfalls: HIGH - documented AOT issues, verified with official sources

**Research date:** 2026-01-26
**Valid until:** Indefinite (patterns stable, no external library changes expected)

---

## Implementation Checklist

Based on this research, Phase 2 implementation must:

- [ ] **Create MatrixJsonContext** with [JsonSerializable] for all model types
- [ ] **Update ConfigService.SaveState** to use source-generated context
- [ ] **Update ConfigService.LoadState** to use source-generated context
- [ ] **Fix temp file path** to use StatePath + ".tmp" instead of system temp
- [ ] **Add JsonSerializerIsReflectionEnabledByDefault=false** to csproj for AOT safety
- [ ] **Ensure RenderMode enum** uses generic JsonStringEnumConverter or UseStringEnumConverter
- [ ] **Verify graceful fallback** when JSON is corrupt (already implemented, verify works)
- [ ] **Test atomic write** by interrupting save (verify original file intact)

## Key File References

| File | Location | Purpose |
|------|----------|---------|
| ConfigService | `MatrixShader/src/MatrixShader.Core/Services/ConfigService.cs` | Update serialization calls |
| MatrixState | `MatrixShader/src/MatrixShader.Core/Models/MatrixState.cs` | State model (already correct) |
| ShaderConfig | `MatrixShader/src/MatrixShader.Core/Models/ShaderConfig.cs` | Shader model (already correct) |
| LayoutConfig | `MatrixShader/src/MatrixShader.Core/Models/LayoutConfig.cs` | Layout model (already correct) |
| NEW: MatrixJsonContext | `MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs` | Source-generated context |
| Project file | `MatrixShader/src/MatrixShader.Core/MatrixShader.Core.csproj` | Add AOT settings |
