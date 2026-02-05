# Phase 7: Terminal Integration - Research

**Researched:** 2026-01-28
**Domain:** Windows Terminal settings.json manipulation, profile management, PowerShell JSON handling
**Confidence:** HIGH

## Summary

This phase implements Windows Terminal configuration management for the Matrix Terminal Shader application. The core requirement is reading/writing settings.json to create Matrix-1 through Matrix-8 profiles with pixel shader paths, handle JSON errors gracefully with self-healing recovery, and provide diagnostic logging.

The existing PowerShell codebase already demonstrates the patterns needed. The install.ps1, MatrixUtils.ps1, and matrix_control.ps1 files contain working implementations for profile creation, shader path configuration, tab color sync, and atomic JSON writes. Phase 7 consolidates these patterns into a robust, service-oriented module with enhanced error recovery.

**Primary recommendation:** Create a dedicated `TerminalConfigService.ps1` module that encapsulates all settings.json operations, using the established atomic write pattern (temp file + Move-Item) and adding lenient JSON recovery via regex-based extraction when ConvertFrom-Json fails.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PowerShell 5.1+ | Built-in | JSON manipulation, file I/O | Matches existing codebase, no external dependencies |
| ConvertFrom-Json / ConvertTo-Json | Built-in | JSON parsing | Native PowerShell JSON support |
| System.IO.File | .NET | Atomic writes | Direct file operations for reliable saves |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| System.Text.RegularExpressions | .NET | Lenient JSON extraction | When ConvertFrom-Json fails on malformed JSON |
| Get-Content -Raw | Built-in | File reading | Always read entire file as single string |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ConvertFrom-Json | Newtonsoft.Json | More features but requires external dependency |
| Regex recovery | JSON.NET Lenient Mode | Requires .NET library, overkill for simple extraction |

**Installation:**
No external packages required. All functionality uses PowerShell built-ins and .NET Framework.

## Architecture Patterns

### Recommended Project Structure
```
Matrix/
├── TerminalConfigService.ps1    # NEW: Centralized settings.json management
├── MatrixLogging.ps1            # Existing: Diagnostic logging
├── MatrixUtils.ps1              # Existing: Shared utilities
├── install.ps1                  # Uses TerminalConfigService for profile creation
├── matrix_control.ps1           # Uses TerminalConfigService for profile updates
├── matrix_setup.ps1             # Uses TerminalConfigService for setup wizard
└── bluepill.ps1                 # Uses TerminalConfigService for state restoration
```

### Pattern 1: Atomic JSON Write
**What:** Write to temp file, then Move-Item to destination
**When to use:** Every settings.json modification
**Example:**
```powershell
# Source: Existing codebase (install.ps1, MatrixUtils.ps1)
function Save-TerminalSettings {
    param($Settings, $Path)

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $Settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding UTF8
        Move-Item -Path $tempFile -Destination $Path -Force
        return $true
    }
    catch {
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}
```

### Pattern 2: Three-Layer Error Recovery
**What:** Try normal parse, then lenient recovery, then fresh creation
**When to use:** Reading settings.json that may be corrupted
**Example:**
```powershell
# Source: CONTEXT.md decisions
function Read-TerminalSettings {
    param([string]$Path)

    $backupPath = "$Path.matrix-backup"

    # Layer 1: Normal parse
    try {
        $content = Get-Content $Path -Raw -ErrorAction Stop
        return $content | ConvertFrom-Json -ErrorAction Stop
    }
    catch [System.ArgumentException] {
        # Layer 2: Malformed JSON - backup and attempt recovery
        Copy-Item -Path $Path -Destination $backupPath -Force

        try {
            $profiles = Extract-ProfilesLenient -Content $content
            $settings = New-DefaultSettings -ExistingProfiles $profiles
            Save-TerminalSettings -Settings $settings -Path $Path
            return $settings
        }
        catch {
            # Layer 3: Complete failure - create fresh
            $settings = New-DefaultSettings
            Save-TerminalSettings -Settings $settings -Path $Path
            return $settings
        }
    }
    catch [System.IO.IOException] {
        throw  # File locked - cannot recover, user must close WT
    }
}
```

### Pattern 3: Profile Upsert
**What:** Find existing profile by name, update or create new
**When to use:** Creating/updating Matrix-N profiles
**Example:**
```powershell
# Source: Existing install.ps1 pattern
function Set-MatrixProfile {
    param([object]$Settings, [int]$Slot, [hashtable]$ProfileData)

    $profileName = "Matrix-$Slot"
    $existingIndex = -1

    for ($i = 0; $i -lt $Settings.profiles.list.Count; $i++) {
        if ($Settings.profiles.list[$i].name -eq $profileName) {
            $existingIndex = $i
            break
        }
    }

    if ($existingIndex -ge 0) {
        # Update existing
        foreach ($key in $ProfileData.Keys) {
            $Settings.profiles.list[$existingIndex] |
                Add-Member -NotePropertyName $key -NotePropertyValue $ProfileData[$key] -Force
        }
    }
    else {
        # Create new
        $newProfile = @{ name = $profileName } + $ProfileData
        $Settings.profiles.list = @($newProfile) + @($Settings.profiles.list)
    }

    return $Settings
}
```

### Pattern 4: Path Auto-Detection and Update
**What:** Detect Matrix folder location change, update settings.json paths
**When to use:** On application startup
**Example:**
```powershell
# Source: CONTEXT.md - portability requirement
function Update-ShaderPaths {
    param([object]$Settings, [string]$CurrentMatrixDir)

    $currentShadersDir = "$CurrentMatrixDir\shaders"
    $updated = $false

    foreach ($profile in $Settings.profiles.list) {
        if ($profile.name -match '^Matrix-\d+$' -or $profile.name -eq 'Redpill') {
            $shaderPath = $profile.'experimental.pixelShaderPath'
            if ($shaderPath -and $shaderPath -notlike "$currentShadersDir\*") {
                # Path mismatch - extract filename and update
                $filename = [System.IO.Path]::GetFileName($shaderPath)
                $newPath = "$currentShadersDir\$filename"
                $profile.'experimental.pixelShaderPath' = $newPath
                $updated = $true
            }
        }
    }

    return $updated
}
```

### Anti-Patterns to Avoid
- **Direct file overwrite:** Always use atomic write (temp + move) to prevent corruption on crash
- **ConvertTo-Json without -Depth:** Default depth of 2 truncates nested objects to "@{...}" strings
- **Ignoring file lock errors:** IOException means Windows Terminal has the file - user must be notified
- **Storing opacity in settings.json for restore:** Store in Matrix state, apply via Windows API
- **Hard-coded GUID patterns:** Use `[guid]::NewGuid()` for new profiles, not predictable GUIDs

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON pretty-printing | Manual string formatting | ConvertTo-Json -Depth 10 | Handles escaping, nesting correctly |
| GUID generation | Template GUIDs like "deadbeef-..." | [guid]::NewGuid().ToString() | Proper uniqueness, correct format |
| File locking detection | Retry loops with Sleep | catch [System.IO.IOException] | Direct error type tells you file is locked |
| Atomic file write | Delete + Write | Temp file + Move-Item -Force | Move is atomic on NTFS |
| Tab color conversion | Manual hex formatting | "{0:X2}{1:X2}{2:X2}" -f | Proper zero-padding |

**Key insight:** The existing codebase already solves these problems. Consolidate patterns, don't reinvent.

## Common Pitfalls

### Pitfall 1: ConvertTo-Json Depth Truncation
**What goes wrong:** Nested objects become "@{Key=Value}" strings in saved JSON
**Why it happens:** Default -Depth is 2, profiles.list.item properties exceed this
**How to avoid:** Always use `-Depth 10` (or higher) with ConvertTo-Json
**Warning signs:** After save/reload, profile properties are strings instead of objects

### Pitfall 2: Windows Terminal File Lock
**What goes wrong:** Save fails silently or corrupts file when WT has it open
**Why it happens:** WT monitors settings.json and may have read lock
**How to avoid:** Catch IOException specifically, use atomic write pattern
**Warning signs:** Intermittent save failures, especially when WT UI is open

### Pitfall 3: BOM in JSON Files
**What goes wrong:** Some tools fail to parse JSON with UTF-8 BOM
**Why it happens:** PowerShell Out-File adds BOM by default
**How to avoid:** Use `-Encoding UTF8` (adds BOM in PS5.1, but WT handles it)
**Warning signs:** Third-party tools report "unexpected character at position 0"

### Pitfall 4: PSObject Property Removal
**What goes wrong:** Trying to remove a property with `$obj.Remove('key')` fails
**Why it happens:** ConvertFrom-Json creates PSCustomObject, not hashtable
**How to avoid:** Use `$obj.PSObject.Properties.Remove('key')`
**Warning signs:** "Method invocation failed" errors when trying to remove properties

### Pitfall 5: Lost Profiles on Malformed JSON
**What goes wrong:** User's other profiles (WSL, Azure, etc.) disappear
**Why it happens:** Crash during save, or recovery creates fresh settings
**How to avoid:** Always backup before modify, extract ALL profiles during recovery
**Warning signs:** User reports missing profiles after Matrix installation

### Pitfall 6: Shader Path Drift
**What goes wrong:** Moving Matrix folder breaks all profiles
**Why it happens:** Paths are absolute, stored in settings.json
**How to avoid:** Detect on startup, auto-update paths to current location
**Warning signs:** Matrix windows launch but show no effect (shader not found)

## Code Examples

Verified patterns from existing codebase:

### Reading settings.json Safely
```powershell
# Source: install.ps1 lines 132-148
$wt = $null
try {
    $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
    $wt = $content | ConvertFrom-Json -ErrorAction Stop
} catch [System.IO.IOException] {
    Write-Host " [ERROR] Cannot read settings.json (file may be locked)" -ForegroundColor Red
    exit 1
} catch {
    Write-Host " [ERROR] Settings.json is malformed or corrupted" -ForegroundColor Red
    exit 1
}
```

### Creating Matrix Profile
```powershell
# Source: install.ps1 lines 163-175
$matrixProfiles = @()
for ($i = 1; $i -le 8; $i++) {
    $guid = "{$([guid]::NewGuid().ToString())}"
    $matrixProfiles += @{
        name = "Matrix-$i"
        guid = $guid
        commandline = "cmd.exe /k title Matrix-$i && pause >nul"
        hidden = $true
        opacity = 95
        "experimental.pixelShaderPath" = "$shadersDir\Matrix-$i.hlsl"
    }
}
```

### Updating Tab Color from Shader
```powershell
# Source: MatrixUtils.ps1 Sync-TabColorToShader function
$color = Get-ShaderColor -ShaderPath $ShaderPath
$hexColor = Convert-RGBToHex -R $color.R -G $color.G -B $color.B

foreach ($profile in $wt.profiles.list) {
    if ($profile.name -eq $ProfileName) {
        $profile | Add-Member -NotePropertyName 'tabColor' -NotePropertyValue $hexColor -Force
        break
    }
}
```

### Diagnostic Logging
```powershell
# Source: MatrixLogging.ps1
function Write-MatrixLog {
    param([string]$Message, [string]$Source = 'GENERAL', [string]$Level = 'INFO')

    if ($env:MATRIX_DEBUG -ne "1") { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Source] [$Level] $Message"

    # Console with color
    $color = switch ($Level) { 'DEBUG' {'DarkGray'} 'INFO' {'Gray'} 'WARN' {'Yellow'} 'ERROR' {'Red'} }
    Write-Host $logEntry -ForegroundColor $color

    # File logging
    $logFile = "$env:USERPROFILE\Documents\Matrix\debug.log"
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| profiles.json | settings.json | WT 1.0 (2020) | Filename changed |
| fontFace, fontSize, fontWeight | font.face, font.size, font.weight | WT 1.10 | Nested object structure |
| Experimental only shader | experimental.pixelShaderPath stable | WT 1.15+ | Still "experimental" prefix but stable |
| Global settings only | Per-profile settings | WT 1.0 | profiles.list supports all appearance settings |

**Deprecated/outdated:**
- profiles.json: Renamed to settings.json in early WT versions
- Old font properties: Still work but nested `font` object is preferred
- Manual backup commands: WT now auto-backs up on every change

## Open Questions

Things that couldn't be fully resolved:

1. **JSON Comment Handling**
   - What we know: PowerShell 6+ supports JSON with comments, WT settings.json may have comments
   - What's unclear: Does PowerShell 5.1 (Windows built-in) strip or error on comments?
   - Recommendation: Test with commented JSON, may need regex stripping pre-parse

2. **Lenient JSON Parsing Specifics**
   - What we know: ConvertFrom-Json has no "lenient mode" in PowerShell
   - What's unclear: Exact regex patterns needed to extract profiles from malformed JSON
   - Recommendation: Implement extraction using profile block detection (name/guid pairs)

3. **Settings.json Schema Versioning**
   - What we know: WT has `$schema` property pointing to schema URL
   - What's unclear: Whether schema changes break backward compatibility
   - Recommendation: Don't modify `$schema`, preserve whatever user has

## Sources

### Primary (HIGH confidence)
- Existing codebase: install.ps1, MatrixUtils.ps1, matrix_control.ps1, MatrixLogging.ps1
- [Windows Terminal Profile Appearance Settings](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance) - Microsoft Learn
- [Windows Terminal profiles.schema.json](https://github.com/microsoft/terminal/blob/main/doc/cascadia/profiles.schema.json) - Official schema

### Secondary (MEDIUM confidence)
- [ConvertTo-Json Documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json) - Microsoft Learn
- [ConvertFrom-Json Documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json) - Microsoft Learn
- [Windows Terminal Pixel Shaders README](https://github.com/microsoft/terminal/blob/main/samples/PixelShaders/README.md) - Official samples

### Tertiary (LOW confidence)
- [PowerShell JSON best practices](https://thinkpowershell.com/powershell-and-json-a-practical-guide/) - Community article
- [Backup/restore Windows Terminal settings](https://pureinfotech.com/backup-restore-settings-windows-terminal/) - Tutorial article

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing codebase patterns, native PowerShell
- Architecture: HIGH - Patterns already proven in current implementation
- Pitfalls: HIGH - Documented from actual codebase issues and code review findings

**Research date:** 2026-01-28
**Valid until:** 60 days (stable domain, Windows Terminal schema rarely changes)

## Recommendations Summary

### Claude's Discretion Items (from CONTEXT.md)

1. **Shader Path Strategy:** Use absolute paths with auto-detection on startup
   - Reason: Existing codebase uses absolute paths, auto-detection handles portability
   - Implementation: Check paths on service initialization, update if Matrix folder moved

2. **Backup File Location:** Same directory as settings.json (`settings.json.matrix-backup`)
   - Reason: Matches Windows Terminal's own backup behavior, easy to find
   - Implementation: Single backup, overwrite previous (per CONTEXT.md decision)

3. **Log File Location:** `$env:USERPROFILE\Documents\Matrix\debug.log`
   - Reason: Matches existing MatrixLogging.ps1 implementation
   - Implementation: Already implemented, no change needed

4. **Validation Timing:** Validate on every settings.json read, not proactively
   - Reason: Matches PowerShell approach - errors surface at use time
   - Implementation: Validation happens in Read-TerminalSettings function
