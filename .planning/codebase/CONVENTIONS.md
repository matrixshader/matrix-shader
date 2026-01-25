# Coding Conventions

**Analysis Date:** 2026-01-25

## Naming Patterns

**Files:**
- PowerShell scripts: `camelCase` with descriptive full names (`matrix_control.ps1`, `WindowLayoutEngine.ps1`, `WindowIdentityService.ps1`)
- HLSL shaders: `Matrix-{N}.hlsl` or `Redpill-Neo.hlsl` (prefixed with intent, numbered for slots)
- Test files: `test-{feature}.ps1` or `test-{module}-{phase}.ps1` (kebab-case)
- Diagnostic scripts: `check-{target}.ps1`, `diagnose-{target}.ps1`, `debug-{target}.ps1`

**Functions:**
- PowerShell: PascalCase with verb-noun pattern (`Get-ScreenTopology`, `Write-MatrixLog`, `Test-WindowHandleValid`, `Enable-MatrixDebug`)
- Helper functions: Prefixed with scope (`Get-`, `Set-`, `Test-`, `Clear-`, `Register-`)
- Private/internal: Use `script:` scope prefix for module-level state

**Variables:**
- Script-level: `$camelCase` (`$matrixDir`, `$shadersDir`, `$currentSlot`, `$dirty`)
- Parameters: `$PascalCase` following PowerShell convention (`$Message`, `$Source`, $FilePath`)
- Constants/static: UPPERCASE or descriptive names (`$defaults`, `$presets`, `$LaunchRegistry`)
- Hashtable keys: Descriptive lowercase or PascalCase depending on external compatibility

**Types:**
- C# P/Invoke classes: PascalCase (`WindowLayoutAPI`, `MatrixWindowAPI`, `RECT`)
- Enum values: UPPERCASE with underscores (`WS_EX_LAYERED`, `SW_RESTORE`)

## Code Style

**Formatting:**
- No automatic formatter configured
- Consistent with PowerShell style guidelines: 4-space indentation
- CRLF line endings required (PowerShell on Windows)
- Consistent brace placement: opening brace on same line for one-liners, separate line for blocks

**Linting:**
- No static linter configured (no .eslintrc, no PSScriptAnalyzer config)
- Code quality enforced through manual review and testing

## Import Organization

**Order:**
1. Unified logging imports (MatrixLogging.ps1)
2. Utility imports (MatrixUtils.ps1)
3. Core service imports (WindowLayoutEngine.ps1, WindowIdentityService.ps1)
4. P/Invoke type definitions (inline Add-Type if not using precompiled DLL)

**Pattern (example from `matrix_setup.ps1`):**
```powershell
. "$PSScriptRoot\MatrixLogging.ps1"
. "$PSScriptRoot\MatrixUtils.ps1"
. "$PSScriptRoot\WindowLayoutEngine.ps1"
. "$PSScriptRoot\WindowIdentityService.ps1"
```

**Path Aliases:**
- `$PSScriptRoot` for relative script directory access (not `Split-Path -Parent`)
- Full paths for user-accessible locations: `$env:USERPROFILE\Documents\Matrix`
- All critical paths stored as module-level variables at script start

## Error Handling

**Patterns:**
- Comprehensive try-catch blocks around JSON operations (`ConvertFrom-Json`, `ConvertTo-Json`, file I/O)
- Specific exception handling where applicable:
  ```powershell
  try {
      $settings = $content | ConvertFrom-Json -ErrorAction Stop
  } catch [System.ArgumentException] {
      Write-Warning "JSON parse error: $_"
      return $null
  } catch {
      Write-Warning "Unexpected error: $_"
  }
  ```
- Silent failures for non-critical operations: `catch { }` in logging, temp file cleanup
- Graceful degradation: fallback values when external APIs fail (e.g., screen detection defaults to `1920x1040`)
- Error context preservation: always include actual exception in messages

**Validation:**
- Regex validation before writing shader values: `if ($value -match '^\d+(\.\d+)?$')`
- Handle validation with `Test-WindowHandleValid` before operations
- Screen dimension validation: check `Width > 0` and `Height > 0`

## Logging

**Framework:** Custom `Write-MatrixLog` (unified across all modules)

**Source Categories:**
- `CONTROL` - matrix_control.ps1 operations
- `LAYOUT` - WindowLayoutEngine operations
- `IDENTITY` - WindowIdentityService operations
- `HOTKEY` - Hotkey registration/handling
- `SETUP` - Setup wizard operations
- `GENERAL` - Fallback/miscellaneous

**Levels:**
- `DEBUG` - Detailed diagnostic info (only when `$env:MATRIX_DEBUG = "1"`)
- `INFO` - Operational milestones (default visible)
- `WARN` - Issues that don't block (always visible)
- `ERROR` - Failures (always visible)

**Pattern:**
```powershell
Write-MatrixLog "Screen topology: $($sorted.Count) screens, primary at index 0" -Source LAYOUT -Level DEBUG
Write-MatrixLog "Window not found" -Source IDENTITY -Level WARN -Force
```

**Control:**
- Master switch: `$env:MATRIX_DEBUG = "1"` enables all debug output
- File logging: writes to `$env:USERPROFILE\Documents\Matrix\debug.log` when debug enabled
- Console color coding: DEBUG=DarkGray, INFO=Gray, WARN=Yellow, ERROR=Red

## Comments

**When to Comment:**
- Complex P/Invoke declarations (explain Windows API purpose)
- Algorithm explanations (e.g., multi-monitor distribution logic)
- Non-obvious workarounds or platform-specific code
- Section headers for major code blocks (e.g., `# --- SCREEN TOPOLOGY DETECTION ---`)

**JSDoc/TSDoc:**
- PowerShell Comment-Based Help (CBH) with `<#.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE` tags
- Used in all public functions in utility modules
- Example from `WindowLayoutEngine.ps1`:
  ```powershell
  <#
  .SYNOPSIS
      Detect all monitors and return their working areas (excludes taskbar).

  .OUTPUTS
      Array of @{ Index, Left, Top, Width, Height, IsPrimary }

  .EXAMPLE
      $screens = Get-ScreenTopology
  #>
  ```

## Function Design

**Size:**
- Small focused functions (< 50 lines typical)
- Complex functions allowed for multi-phase algorithms (WindowLayoutEngine phases)
- Single responsibility principle: each function does one thing well

**Parameters:**
- Use `[CmdletBinding()]` for pipeline support
- Mandatory parameters marked with `[Parameter(Mandatory)]`
- Type hints where possible: `[string]`, `[int]`, `[bool]`, `[System.Collections.Hashtable]`
- Default values for optional parameters: `[string]$Source = 'GENERAL'`

**Return Values:**
- Return appropriate types: arrays, hashtables, objects, or strings (not mixed)
- Empty returns: `@()` for arrays, `@{}` for hashtables, `$null` for absent values
- Pipeline-friendly: return objects that can be piped to other cmdlets

**Patterns:**
```powershell
function Get-ScreenTopology {
    [CmdletBinding()]
    param()

    try {
        $screens = [System.Windows.Forms.Screen]::AllScreens
        return $screens | Select-Object Index, Left, Top, Width, Height, IsPrimary
    }
    catch {
        Write-Warning "Failed to detect: $_"
        return @()  # Return empty array on failure
    }
}
```

## Module Design

**Exports:**
- All public functions available after dot-sourcing (`. .\Module.ps1`)
- Global scope aliases for backward compatibility: `Set-Alias -Name Swatch -Value Get-ColorSwatch -Scope Global`
- Module-level state in `script:` scope: `$script:LaunchRegistry`, `$script:IdentityRegistryPath`

**Barrel Files:**
- Not used; prefer direct dot-sourcing of specific files
- Entry points explicitly import required modules in order

**Shared Utilities (`MatrixUtils.ps1`):**
- Contains color output helpers (`Get-ColorSwatch`)
- Screen dimension detection (`Get-PrimaryScreenDimensions`)
- Reused across multiple entry points (setup, control, bluepill)

**Singleton Services:**
- `WindowLayoutEngine.ps1`: Stateless layout algorithms with P/Invoke wrappers
- `WindowIdentityService.ps1`: Maintains runtime launch registry + identity resolution
- `MatrixLogging.ps1`: Stateless logging with environment variable control

## JSON Handling

**Patterns:**
- All JSON operations wrapped in try-catch
- Atomic writes using temp file + `Move-Item -Force`:
  ```powershell
  $tempFile = "$path.tmp"
  $data | ConvertTo-Json | Out-File -FilePath $tempFile -Encoding UTF8
  Move-Item -Path $tempFile -Destination $path -Force
  ```
- Explicit error handling for parse failures: `-ErrorAction Stop` then catch
- Graceful degradation: provide defaults when JSON missing or corrupted

## Regex Patterns

**Shader Value Validation:**
- Reject values outside valid ranges: `^[01](\.\d+)?$` for 0.0-1.0 values
- Slot validation: `^\d+$` for integer slots
- Shader file detection: `Matrix-(\d+)\.hlsl` to extract slot number

---

*Convention analysis: 2026-01-25*
