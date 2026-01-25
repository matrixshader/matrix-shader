# Phase 1: Shader Service Foundation - Research

**Researched:** 2026-01-25
**Domain:** HLSL file manipulation with #define injection and Windows Terminal hot-reload
**Confidence:** HIGH

## Summary

Phase 1 establishes the core shader manipulation capability - the heart of the Matrix Terminal Shader application. The existing C# implementation has a critical bug: regex patterns don't match the actual HLSL #define names used by the working PowerShell version. This research documents the exact HLSL format, identifies the necessary fixes, and provides patterns for correct implementation.

The shader system works by:
1. Reading current parameter values from HLSL #define statements
2. Applying user changes to a ShaderConfig model
3. Regenerating the HLSL file with updated #define values
4. Triggering Windows Terminal hot-reload via file timestamp change

**Primary recommendation:** Fix the ShaderService regex patterns to match actual HLSL #define names, then implement shader template generation for creating new shader files.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| System.Text.RegularExpressions | Built-in (.NET 8) | Regex parsing of #define statements | Source-generated regex via `[GeneratedRegex]` for AOT |
| System.IO | Built-in (.NET 8) | File read/write with atomic pattern | Native file operations |
| System.Text.Encoding | Built-in (.NET 8) | UTF-8 file encoding | HLSL files must be UTF-8 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Microsoft.Extensions.Logging | 8.0.x | Diagnostic logging | Debug mode ($env:MATRIX_DEBUG=1) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Regex parsing | Full HLSL parser | Massive overkill - we only manipulate #define lines |
| File.Move | File.Replace | Move is simpler and sufficient for atomic writes |
| Template strings | T4 templates | T4 adds complexity; string interpolation is sufficient |

**Installation:**
Already available in .NET 8 SDK - no additional packages needed for Phase 1.

## Architecture Patterns

### Recommended Project Structure
```
MatrixShader.Core/
├── Constants/
│   └── ColorPresets.cs        # 6 color presets (already exists, correct)
├── Models/
│   └── ShaderConfig.cs        # Shader parameter model (exists, needs validation range fixes)
└── Services/
    ├── IShaderService.cs      # Interface (exists, correct)
    └── ShaderService.cs       # Implementation (exists, NEEDS FIX: wrong regex patterns)
```

### Pattern 1: Regex-Based #define Extraction
**What:** Use source-generated regex to extract parameter values from HLSL #define statements
**When to use:** Parsing existing shader files for current parameter values
**Example:**
```csharp
// Source: Working PowerShell implementation in matrix_control.ps1 line 157-163
// The ACTUAL #define names used in Matrix-*.hlsl files:
[GeneratedRegex(@"#define\s+RAIN_R\s+([\d.]+)")]
private static partial Regex RainRRegex();

[GeneratedRegex(@"#define\s+RAIN_G\s+([\d.]+)")]
private static partial Regex RainGRegex();

[GeneratedRegex(@"#define\s+RAIN_B\s+([\d.]+)")]
private static partial Regex RainBRegex();

[GeneratedRegex(@"#define\s+RAIN_SPEED\s+([\d.]+)")]
private static partial Regex RainSpeedRegex();

[GeneratedRegex(@"#define\s+GLOW_STRENGTH\s+([\d.]+)")]
private static partial Regex GlowStrengthRegex();

[GeneratedRegex(@"#define\s+CHAR_WIDTH\s+([\d.]+)")]
private static partial Regex CharWidthRegex();

[GeneratedRegex(@"#define\s+TRAIL_POWER\s+([\d.]+)")]
private static partial Regex TrailPowerRegex();

[GeneratedRegex(@"#define\s+RAIN_DENSITY\s+([\d.]+)")]
private static partial Regex RainDensityRegex();

[GeneratedRegex(@"#define\s+SHOW_L1\s+([\d.]+)")]
private static partial Regex ShowL1Regex();

[GeneratedRegex(@"#define\s+SHOW_L2\s+([\d.]+)")]
private static partial Regex ShowL2Regex();

[GeneratedRegex(@"#define\s+SHOW_L3\s+([\d.]+)")]
private static partial Regex ShowL3Regex();
```

### Pattern 2: Shader Template Generation
**What:** Generate complete HLSL shader file from template with parameter injection
**When to use:** Creating new shader files or regenerating corrupted ones
**Example:**
```csharp
// Source: PowerShell $shaderTemplate in matrix_control.ps1 lines 8-90
// This is the EXACT template that produces working shaders
private const string ShaderTemplate = @"// MATRIX SHADER - SLOT {SLOT}
#define RAIN_R         {R}
#define RAIN_G         {G}
#define RAIN_B         {B}
#define RAIN_SPEED     {SPEED}
#define GLOW_STRENGTH  {GLOW}
#define FONT_SCALE     1.0
#define CHAR_WIDTH     {WIDTH}
#define TRAIL_POWER    {TRAIL}
#define RAIN_DENSITY   {DENS}
#define SHOW_L1        {L1}
#define SHOW_L2        {L2}
#define SHOW_L3        {L3}

// ... rest of HLSL code (static, never changes)
";
```

### Pattern 3: Atomic File Write
**What:** Write to temp file, then move to target location
**When to use:** Any file write that could be interrupted
**Example:**
```csharp
// Source: PowerShell US-001 pattern in matrix_control.ps1 lines 455-464
public void WriteConfig(int shaderIndex, ShaderConfig config)
{
    var targetPath = GetShaderPath(shaderIndex);
    var tempPath = Path.GetTempFileName();

    try
    {
        var content = GenerateShaderContent(shaderIndex, config);
        File.WriteAllText(tempPath, content, Encoding.UTF8);
        File.Move(tempPath, targetPath, overwrite: true);
        _logger.LogDebug("Wrote shader config to {Path}", targetPath);
    }
    catch
    {
        if (File.Exists(tempPath))
            File.Delete(tempPath);
        throw;
    }
}
```

### Pattern 4: Hot-Reload Trigger
**What:** Touch file timestamp to trigger Windows Terminal shader reload
**When to use:** After writing shader file (but NOT needed if File.Move already changes timestamp)
**Example:**
```csharp
// Source: PowerShell mechanism - timestamp change triggers hot-reload
// File.Move already updates LastWriteTime, so explicit Touch may not be needed
// BUT explicit touch ensures reload even if content unchanged
public void TouchShader(int shaderIndex)
{
    var path = GetShaderPath(shaderIndex);
    if (File.Exists(path))
    {
        File.SetLastWriteTimeUtc(path, DateTime.UtcNow);
    }
}
```

### Anti-Patterns to Avoid
- **Wrong #define names:** The existing C# code uses `COLOR_R` but the actual shader uses `RAIN_R`
- **Layer toggle as int:** Layers use float values (1.0/0.0), not int (1/0) in the actual shaders
- **Missing FONT_SCALE:** The shader has a FONT_SCALE #define that's always 1.0 (not configurable but must be present)
- **Validation ranges too strict:** ShaderConfig.IsValid() has Speed max at 2.0 but PowerShell allows up to 3.0

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HLSL parsing | Full shader parser | Regex on #define lines | Only need parameter values, not full AST |
| File watching | Custom FileSystemWatcher | Windows Terminal built-in | WT already watches shader file timestamps |
| Color math | Custom RGB handling | MatrixColor record | Already exists in ColorPresets.cs |
| Atomic writes | Custom transaction | File.Move(overwrite: true) | Native atomic operation on Windows |

**Key insight:** The HLSL shader body never changes - only the #define values at the top. A full HLSL parser would be massive overkill. Simple regex extraction + template injection is the correct approach.

## Common Pitfalls

### Pitfall 1: Wrong #define Names (CRITICAL - Existing Bug)
**What goes wrong:** ShaderService regex patterns don't match actual HLSL #define names
**Why it happens:** C# implementation was written without referencing the actual shader files
**How to avoid:** Map C# regex directly from working PowerShell code:
| PowerShell | Actual HLSL | Current C# (WRONG) |
|------------|-------------|-------------------|
| RAIN_R | `#define RAIN_R` | `#define COLOR_R` |
| RAIN_G | `#define RAIN_G` | `#define COLOR_G` |
| RAIN_B | `#define RAIN_B` | `#define COLOR_B` |
| RAIN_SPEED | `#define RAIN_SPEED` | `#define SPEED` |
| GLOW_STRENGTH | `#define GLOW_STRENGTH` | `#define GLOW` |
| CHAR_WIDTH | `#define CHAR_WIDTH` | `#define WIDTH` |
| TRAIL_POWER | `#define TRAIL_POWER` | `#define TRAIL` |
| RAIN_DENSITY | `#define RAIN_DENSITY` | `#define DENSITY` |
| SHOW_L1 | `#define SHOW_L1` | `#define LAYER1` |
| SHOW_L2 | `#define SHOW_L2` | `#define LAYER2` |
| SHOW_L3 | `#define SHOW_L3` | `#define LAYER3` |
**Warning signs:** ReadConfig returns all defaults, WriteConfig changes nothing

### Pitfall 2: Layer Toggle Type Mismatch
**What goes wrong:** Parsing/writing layers as 0/1 integers instead of 0.0/1.0 floats
**Why it happens:** The regex pattern `@"#define\s+LAYER1\s+(\d)"` expects single digit
**How to avoid:** Use float pattern `@"#define\s+SHOW_L1\s+([\d.]+)"` and compare against 0.5 threshold
**Warning signs:** Layer toggles don't work; shader may have compile errors

### Pitfall 3: Missing Shader Template
**What goes wrong:** WriteConfig fails when shader file doesn't exist
**Why it happens:** Current implementation requires existing file to modify
**How to avoid:** Implement CreateShader method using full template (the PowerShell $shaderTemplate)
**Warning signs:** Launch-MatrixWindows fails for new slots

### Pitfall 4: Validation Ranges Don't Match PowerShell
**What goes wrong:** User can't set Speed=2.5 even though PowerShell allows it
**Why it happens:** ShaderConfig.IsValid() hard-codes different ranges
**How to avoid:** Match exact PowerShell ranges from matrix_control.ps1 Adj function:
| Parameter | PowerShell Range | C# ShaderConfig |
|-----------|------------------|-----------------|
| R, G, B | 0.0 - 1.0 | 0.0 - 1.0 (correct) |
| Speed | 0.1 - 3.0 | 0.1 - 2.0 (WRONG) |
| Glow | 0.2 - 3.0 | 0.0 - 2.0 (WRONG) |
| Width | 6.0 - 20.0 | 5.0 - 20.0 (close) |
| Trail | 4.0 - 15.0 | 1.0 - 20.0 (too wide) |
| Density | 0.2 - 1.0 | 0.1 - 1.0 (close) |
**Warning signs:** Changes clamped unexpectedly

### Pitfall 5: UTF-8 BOM Issues
**What goes wrong:** Shader file has incorrect encoding, Windows Terminal fails to parse
**Why it happens:** .NET default encoding may add BOM or use wrong encoding
**How to avoid:** Use `new UTF8Encoding(false)` to avoid BOM
**Warning signs:** Shader appears blank or shows garbage characters

## Code Examples

Verified patterns from the working PowerShell implementation:

### Reading Shader Configuration
```csharp
// Source: Derived from matrix_control.ps1 Load-Shader function (lines 151-177)
public ShaderConfig ReadConfig(int shaderIndex)
{
    var path = GetShaderPath(shaderIndex);
    if (!File.Exists(path))
    {
        _logger.LogWarning("Shader file not found: {Path}, using defaults", path);
        return new ShaderConfig(); // Return defaults
    }

    try
    {
        var content = File.ReadAllText(path);
        return new ShaderConfig
        {
            R = ParseFloat(content, RainRRegex(), 0f),
            G = ParseFloat(content, RainGRegex(), 1f),
            B = ParseFloat(content, RainBRegex(), 0.3f),
            Speed = ParseFloat(content, RainSpeedRegex(), 0.8f),
            Glow = ParseFloat(content, GlowStrengthRegex(), 0.8f),
            Width = ParseFloat(content, CharWidthRegex(), 10f),
            Trail = ParseFloat(content, TrailPowerRegex(), 8f),
            Density = ParseFloat(content, RainDensityRegex(), 0.4f),
            Layer1 = ParseFloat(content, ShowL1Regex(), 1f) > 0.5f,
            Layer2 = ParseFloat(content, ShowL2Regex(), 0f) > 0.5f,
            Layer3 = ParseFloat(content, ShowL3Regex(), 1f) > 0.5f
        };
    }
    catch (Exception ex)
    {
        _logger.LogWarning(ex, "Could not read shader file: {Path}", path);
        return new ShaderConfig();
    }
}

private static float ParseFloat(string content, Regex regex, float defaultValue)
{
    var match = regex.Match(content);
    if (match.Success)
    {
        var valueStr = match.Groups[1].Value;
        // Validate: must be valid float format (digits, optional single decimal, more digits)
        if (Regex.IsMatch(valueStr, @"^\d+\.?\d*$") &&
            float.TryParse(valueStr, out var value))
        {
            return value;
        }
    }
    return defaultValue;
}
```

### Writing Shader Configuration
```csharp
// Source: Derived from matrix_control.ps1 Save-Shader function (lines 179-207)
public void WriteConfig(int shaderIndex, ShaderConfig config)
{
    var path = GetShaderPath(shaderIndex);
    var tempPath = Path.GetTempFileName();

    try
    {
        string content;

        if (File.Exists(path))
        {
            // Modify existing file
            content = File.ReadAllText(path);
            content = ApplyConfig(content, config);
        }
        else
        {
            // Generate from template
            content = GenerateShader(shaderIndex, config);
        }

        // Atomic write: temp file then move
        File.WriteAllText(tempPath, content, new UTF8Encoding(false));
        File.Move(tempPath, path, overwrite: true);
        _logger.LogDebug("Shader saved successfully: {Path}", path);
    }
    catch (Exception ex)
    {
        if (File.Exists(tempPath))
            File.Delete(tempPath);
        _logger.LogError(ex, "ERROR saving shader: {Path}", path);
        throw;
    }
}

private static string ApplyConfig(string content, ShaderConfig config)
{
    // Replace each #define with new value
    content = ReplaceDefine(content, "RAIN_R", config.R);
    content = ReplaceDefine(content, "RAIN_G", config.G);
    content = ReplaceDefine(content, "RAIN_B", config.B);
    content = ReplaceDefine(content, "RAIN_SPEED", config.Speed);
    content = ReplaceDefine(content, "GLOW_STRENGTH", config.Glow);
    content = ReplaceDefine(content, "CHAR_WIDTH", config.Width);
    content = ReplaceDefine(content, "TRAIL_POWER", config.Trail);
    content = ReplaceDefine(content, "RAIN_DENSITY", config.Density);
    content = ReplaceDefine(content, "SHOW_L1", config.Layer1 ? 1.0f : 0.0f);
    content = ReplaceDefine(content, "SHOW_L2", config.Layer2 ? 1.0f : 0.0f);
    content = ReplaceDefine(content, "SHOW_L3", config.Layer3 ? 1.0f : 0.0f);
    return content;
}

private static string ReplaceDefine(string content, string name, float value)
{
    // Match #define NAME followed by whitespace and value
    var pattern = $@"(#define\s+{name}\s+)[\d.]+";
    return Regex.Replace(content, pattern, $"$1{value:F1}");
}
```

### Applying Color Presets
```csharp
// Source: matrix_control.ps1 color preset handlers (lines 1095-1100)
// Usage: Apply preset then write config
public void ApplyColorPreset(int shaderIndex, MatrixColor preset)
{
    var config = ReadConfig(shaderIndex);
    var newConfig = config.WithColor(preset.R, preset.G, preset.B);
    WriteConfig(shaderIndex, newConfig);
}

// Preset values from matrix_control.ps1:
// 1: Green   R=0.0, G=1.0, B=0.3
// 2: Cyan    R=0.0, G=0.6, B=1.0
// 3: Red     R=1.0, G=0.1, B=0.1
// 4: Purple  R=0.7, G=0.0, B=1.0
// 5: Gold    R=1.0, G=0.7, B=0.0
// 6: Teal    R=0.0, G=0.9, B=0.9
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DllImport P/Invoke | LibraryImport source-gen | .NET 7 (2022) | Better AOT, faster marshalling |
| Newtonsoft.Json | System.Text.Json | .NET 3.0+ (2019) | Native, AOT-compatible |
| Manual regex | [GeneratedRegex] | .NET 7 (2022) | Source-gen, faster, AOT-safe |

**Deprecated/outdated:**
- DllImport: Still works but LibraryImport is preferred for new code
- Regex compiled at runtime: Use [GeneratedRegex] for AOT compatibility

## Open Questions

Things that couldn't be fully resolved:

1. **Hot-reload timing guarantee**
   - What we know: Windows Terminal hot-reloads "within ~100ms" per CLAUDE.md
   - What's unclear: Is this documented officially or empirical observation?
   - Recommendation: Accept ~100ms as target, add configurable delay if users report issues

2. **Maximum shader count**
   - What we know: PowerShell supports 1-8 slots, code validates shaderIndex 1-8
   - What's unclear: Is 8 a Windows Terminal limit or arbitrary choice?
   - Recommendation: Keep 8 for now; extend later if there's demand

3. **Shader template embedding**
   - What we know: PowerShell embeds template as here-string in matrix_control.ps1
   - What's unclear: Should C# embed as const string or load from resource file?
   - Recommendation: Embed as const string for simplicity and AOT compatibility

## Sources

### Primary (HIGH confidence)
- **matrix_control.ps1** - Working PowerShell implementation (1220 lines)
  - Load-Shader function (lines 151-177)
  - Save-Shader function (lines 179-207)
  - $shaderTemplate (lines 8-90)
  - Color presets (lines 1095-1100)
  - Parameter adjustment (lines 1103-1119)
- **shaders/Matrix-1.hlsl** - Actual HLSL file showing real #define names
- **ShaderService.cs** - Existing C# implementation (needs fixes)
- **ColorPresets.cs** - Existing C# color presets (correct)

### Secondary (MEDIUM confidence)
- **.planning/research/STACK.md** - Technology stack research (verified)
- **.planning/research/ARCHITECTURE.md** - Architecture patterns (validated)

### Tertiary (LOW confidence)
- Windows Terminal hot-reload timing (~100ms) - Empirical, not officially documented

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - built-in .NET 8 libraries, no external deps needed
- Architecture: HIGH - patterns derived from working PowerShell code
- Pitfalls: HIGH - critical bug identified with evidence (regex comparison)

**Research date:** 2026-01-25
**Valid until:** Indefinite (patterns stable, no external library changes expected)

---

## Implementation Checklist

Based on this research, Phase 1 implementation must:

- [ ] **Fix ShaderService regex patterns** to match actual HLSL #define names (RAIN_R not COLOR_R, etc.)
- [ ] **Fix layer parsing** to use float comparison (>0.5) not int parsing
- [ ] **Add shader template** constant for generating new shader files
- [ ] **Fix ShaderConfig validation ranges** to match PowerShell (Speed max 3.0, Glow min 0.2, etc.)
- [ ] **Ensure UTF-8 encoding** without BOM on file writes
- [ ] **Add CreateShader method** that generates complete shader from template
- [ ] **Verify hot-reload** works by timing file write to visible shader change

## Key File References

| File | Location | Purpose |
|------|----------|---------|
| Working PowerShell | `C:\Users\ehome\documents\matrix\matrix_control.ps1` | Reference implementation |
| HLSL shader | `C:\Users\ehome\documents\matrix\shaders\Matrix-1.hlsl` | Actual #define format |
| C# ShaderService | `C:\Users\ehome\documents\matrix\MatrixShader\src\MatrixShader.Core\Services\ShaderService.cs` | Fix target |
| C# ShaderConfig | `C:\Users\ehome\documents\matrix\MatrixShader\src\MatrixShader.Core\Models\ShaderConfig.cs` | Validation fix target |
| C# ColorPresets | `C:\Users\ehome\documents\matrix\MatrixShader\src\MatrixShader.Core\Constants\ColorPresets.cs` | Already correct |
