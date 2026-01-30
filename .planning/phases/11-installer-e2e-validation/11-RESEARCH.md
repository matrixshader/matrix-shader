# Phase 11: Installer & E2E Validation - Research

**Researched:** 2026-01-30
**Domain:** Windows Installer (Inno Setup), Path Resolution, Windows Terminal Integration
**Confidence:** HIGH

## Summary

This phase requires fixing the gap between what the installer packages and what the code expects at runtime. The research identified three key technical domains: (1) Inno Setup installer configuration for proper file placement, (2) C# code path resolution patterns to find installed files, and (3) Windows Terminal profile creation pointing to correct paths.

The critical insight is that admin-mode installers cannot safely write to per-user paths like `%LOCALAPPDATA%`. The recommended pattern is: install to Program Files, let the application copy user-specific files (shaders, config) to LocalAppData on first run.

**Primary recommendation:** Install EXEs and template shaders to `{app}` (Program Files), then have the application detect first-run and copy shaders to `%LOCALAPPDATA%\MatrixShader\shaders\` where profiles will point.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Inno Setup | 6.7.0 | Windows installer framework | Free, well-documented, actively maintained, handles PATH and registry |
| .NET 8 Native AOT | 8.0 | Self-contained executables | No runtime dependency, fast cold-start |
| Windows Sandbox | Windows 11 | Clean-system testing | Isolated testing without VM overhead |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| winget | Windows Terminal installation | Install-time WT provisioning |
| PathMgr.dll | PATH environment updates | Alternative to custom registry code |
| SendMessageTimeout | WM_SETTINGCHANGE broadcast | Notify running apps of PATH change |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inno Setup | MSIX | Better isolation, but more complex, requires signing, Store distribution |
| Inno Setup | WiX | More powerful, but steeper learning curve |
| Windows Sandbox | Hyper-V VM | More realistic, but slower setup |

**Installation:**
```bash
# Inno Setup 6.7 - download from https://jrsoftware.org/isdl.php
# No package manager installation available
```

## Architecture Patterns

### Recommended Installation Architecture

```
Install-time (Admin):
C:\Program Files\MatrixShader\
├── wakeupneo.exe
├── bluepill.exe
├── redpill.exe
├── matrixlite.exe         # GAP-E01: MUST ADD
├── matrix-monitor.exe
└── shaders\               # Template shaders (read-only)
    ├── Matrix-1.hlsl
    ├── Matrix-2.hlsl
    └── ...

First-run (User):
%LOCALAPPDATA%\MatrixShader\
├── shaders\               # Copied from install dir on first run
│   ├── Matrix-1.hlsl
│   └── ...
├── config\
│   └── matrix_state.json
└── identity-registry.json

Windows Terminal profiles point to:
%LOCALAPPDATA%\MatrixShader\shaders\Matrix-1.hlsl
```

### Pattern 1: First-Run Shader Copy

**What:** Application detects missing user shaders on startup and copies from install location.

**When to use:** Every CLI entry point (wakeupneo, bluepill, redpill) on first run.

**Example (from CliBootstrap.cs pattern):**
```csharp
// Search order: LocalAppData first (user), then install dir (fallback)
private static string GetShadersDirectory()
{
    var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    var userShadersDir = Path.Combine(localAppData, "MatrixShader", "shaders");

    // If user shaders exist, use them
    if (Directory.Exists(userShadersDir) && Directory.GetFiles(userShadersDir, "*.hlsl").Length > 0)
        return userShadersDir;

    // Otherwise, use install location as source
    var installShadersDir = Path.Combine(AppContext.BaseDirectory, "shaders");
    if (Directory.Exists(installShadersDir))
    {
        // First-run: copy to user location
        EnsureShadersInUserDirectory(installShadersDir, userShadersDir);
        return userShadersDir;
    }

    // Fallback to install location if copy fails
    return installShadersDir;
}
```

### Pattern 2: Monitor Executable Discovery

**What:** Bluepill finds matrix-monitor.exe in same directory as itself.

**When to use:** When launching background processes.

**Example:**
```csharp
// GAP-E02: Use actual output name from csproj
private static string GetMonitorPath()
{
    // Check for matrix-monitor.exe (actual assembly name from csproj)
    var candidates = new[]
    {
        Path.Combine(AppContext.BaseDirectory, "matrix-monitor.exe"),
        Path.Combine(AppContext.BaseDirectory, "MatrixShader.Monitor.exe"),
        Path.Combine(AppContext.BaseDirectory, "monitor.exe")
    };

    return candidates.FirstOrDefault(File.Exists);
}
```

### Pattern 3: Windows Terminal Profile Creation

**What:** Create profiles pointing to user's LocalAppData shader path.

**When to use:** During wakeupneo setup wizard.

**Example:**
```csharp
// GAP-E12: Always use LocalAppData path for profiles
public int CreateMatrixProfiles(TerminalSettings settings, int count)
{
    var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    var shadersDir = Path.Combine(localAppData, "MatrixShader", "shaders");

    for (int i = 1; i <= count; i++)
    {
        var profile = new TerminalProfile
        {
            Name = $"Matrix-{i}",
            PixelShaderPath = Path.Combine(shadersDir, $"Matrix-{i}.hlsl"),
            // ...
        };
        UpsertProfile(settings, profile);
    }
}
```

### Anti-Patterns to Avoid

- **Hardcoded developer paths:** Never use absolute paths like `C:\Users\ehome\Documents\Matrix` (GAP-E04)
- **Installing to user directories as admin:** When installer runs as admin, `{localappdata}` resolves to admin's profile, not current user
- **PATH without notification:** Adding to PATH requires restart or WM_SETTINGCHANGE broadcast
- **Mixed install locations:** Don't split between Program Files AND LocalAppData at install time

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PATH environment updates | Custom registry + broadcast | Inno Setup built-in + `ChangesEnvironment=yes` | Handles edge cases, uninstall cleanup |
| Windows Terminal detection | Parse version strings | Check for `settings.json` existence | Shader support added in 1.12, but checking file is reliable enough |
| First-run detection | Custom registry flag | Check if user shaders directory exists | Self-describing, no state to manage |
| Installer builds | Manual ISCC invocation | PowerShell build script | Documented, repeatable |

**Key insight:** Inno Setup has 25+ years of edge case handling. The `[Registry]` section with `ChangesEnvironment=yes` properly notifies the system via `WM_SETTINGCHANGE` on modern Inno Setup versions.

## Common Pitfalls

### Pitfall 1: Admin Install to User Paths

**What goes wrong:** Installer runs as admin, writes to `{localappdata}`, files end up in admin's profile.

**Why it happens:** Inno Setup resolves `{localappdata}` in the context of the running process (admin), not the logged-in user.

**How to avoid:** Install only to machine-wide paths (`{app}`, `{commonappdata}`). Let application handle user-specific file creation at runtime.

**Warning signs:** Works on dev machine, fails on clean install where user != admin.

### Pitfall 2: Monitor Executable Name Mismatch

**What goes wrong:** Bluepill looks for `MatrixShader.Monitor.exe` but installer packages `matrix-monitor.exe`.

**Why it happens:** .csproj has `<AssemblyName>matrix-monitor</AssemblyName>` but code uses different name.

**How to avoid:** Check .csproj for actual `<AssemblyName>`, update code to match, or rename output.

**Warning signs:** "Monitor executable not found, skipping" in debug logs.

### Pitfall 3: Profile Shader Path Mismatch

**What goes wrong:** Windows Terminal profiles point to `Documents\Matrix\shaders\` but shaders are in `Program Files\MatrixShader\shaders\`.

**Why it happens:** CliBootstrap.GetShadersDirectory() returns Documents path, profile creation uses that.

**How to avoid:** Profile creation must use LocalAppData path. Application must ensure shaders are copied there before profile creation.

**Warning signs:** Blank terminal with no Matrix effect, shader file not found errors.

### Pitfall 4: PATH Changes Require Restart

**What goes wrong:** User installs, opens new terminal, types `wakeupneo`, command not found.

**Why it happens:** PATH changes via registry don't take effect in already-running processes.

**How to avoid:** Either broadcast `WM_SETTINGCHANGE` or show post-install message about opening new terminal. Also provide Start Menu shortcuts.

**Warning signs:** Works in admin PowerShell during install, fails in user's terminal after.

### Pitfall 5: Missing matrixlite.exe

**What goes wrong:** User without Windows Terminal cannot use standalone Lite mode.

**Why it happens:** MatrixLite project not in build script's `$projects` array.

**How to avoid:** Add `"MatrixShader.Cli\MatrixLite"` to build script, `matrixlite.exe` to installer.

**Warning signs:** 4 executables in publish folder instead of 5.

## Code Examples

### Inno Setup: Files Section with LocalAppData Template Shaders

```pascal
; Source: verified pattern from jrsoftware.org documentation
[Files]
; Install executables to Program Files
Source: "publish\wakeupneo.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\bluepill.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\redpill.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\matrixlite.exe"; DestDir: "{app}"; Flags: ignoreversion  ; GAP-E01
Source: "publish\matrix-monitor.exe"; DestDir: "{app}"; Flags: ignoreversion

; Install template shaders (app copies to LocalAppData on first run)
Source: "..\shaders\*.hlsl"; DestDir: "{app}\shaders"; Flags: ignoreversion
```

### Inno Setup: PATH Registration with Broadcast

```pascal
; Source: verified pattern from jrsoftware.org/isfaq.php
[Setup]
ChangesEnvironment=yes  ; This enables WM_SETTINGCHANGE broadcast

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
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;
```

### C#: Unified Path Resolution

```csharp
// Source: derived from existing codebase patterns, aligned with Inno Setup decisions
public static class PathResolver
{
    private static readonly string LocalAppDataRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MatrixShader");

    private static readonly string InstallDir = AppContext.BaseDirectory;

    /// <summary>
    /// Gets the shaders directory, copying from install if needed.
    /// </summary>
    public static string GetShadersDirectory()
    {
        var userShaders = Path.Combine(LocalAppDataRoot, "shaders");
        var installShaders = Path.Combine(InstallDir, "shaders");

        // User shaders exist? Use them.
        if (Directory.Exists(userShaders) && Directory.EnumerateFiles(userShaders, "*.hlsl").Any())
            return userShaders;

        // First run: copy from install location
        if (Directory.Exists(installShaders))
        {
            Directory.CreateDirectory(userShaders);
            foreach (var hlsl in Directory.GetFiles(installShaders, "*.hlsl"))
            {
                var destPath = Path.Combine(userShaders, Path.GetFileName(hlsl));
                if (!File.Exists(destPath))
                    File.Copy(hlsl, destPath);
            }
            return userShaders;
        }

        // Fallback (dev scenario): use Documents path
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "Matrix", "shaders");
    }

    /// <summary>
    /// Gets the config directory.
    /// </summary>
    public static string GetConfigDirectory()
    {
        var configDir = Path.Combine(LocalAppDataRoot, "config");
        Directory.CreateDirectory(configDir);
        return configDir;
    }
}
```

### winget: Silent Windows Terminal Install

```csharp
// Source: Microsoft Learn documentation
private static async Task<bool> TryInstallWindowsTerminalAsync()
{
    try
    {
        var psi = new ProcessStartInfo
        {
            FileName = "winget",
            Arguments = "install --id Microsoft.WindowsTerminal --exact --silent " +
                        "--accept-source-agreements --accept-package-agreements",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(psi);
        if (process == null) return false;

        await process.WaitForExitAsync();

        // Give WT time to create settings.json
        await Task.Delay(2000);

        return File.Exists(GetSettingsPath());
    }
    catch
    {
        return false;
    }
}

// Fallback: Open Store page
private static void OpenWindowsTerminalStore()
{
    Process.Start(new ProcessStartInfo
    {
        FileName = "ms-windows-store://pdp/?ProductId=9N0DX20HK701",
        UseShellExecute = true
    });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `PrivilegesRequired=admin` always | Use `PrivilegesRequired=lowest` for user-only apps | Inno Setup 5.5+ | Avoids UAC prompt, installs to user folder |
| `{localappdata}` in admin install | `{app}` + app-level first-run copy | Best practice (not new) | Correct multi-user support |
| Custom PATH broadcast | `ChangesEnvironment=yes` | Inno Setup 5.6+ | Built-in WM_SETTINGCHANGE |
| Framework-dependent | Native AOT self-contained | .NET 7+ | No runtime needed |

**Deprecated/outdated:**
- `--no-self-contained:false` syntax: Confusing double negative, use `--self-contained` instead
- Hardcoded `Documents\Matrix\` paths: Replace with `%LOCALAPPDATA%\MatrixShader\`

## Open Questions

1. **Windows Terminal Version Check**
   - What we know: Shaders require WT 1.12+. Code checks `WT_PROFILE_ID` env var.
   - What's unclear: Is `WT_PROFILE_ID` a reliable proxy for shader support? Official docs don't specify.
   - Recommendation: Keep current check. If it works, don't complicate. Add version detection later if users report issues.

2. **Uninstall Cleanup**
   - What we know: User data persists after uninstall (LocalAppData).
   - What's unclear: Should we prompt to clean? Risk of data loss vs. stale files on reinstall.
   - Recommendation: Document that user data is preserved. Add optional cleanup prompt if users request.

3. **Start Menu Shortcuts**
   - What we know: PATH requires new terminal. Shortcuts don't require PATH.
   - What's unclear: Should we add shortcuts? What about Desktop?
   - Recommendation: Add Start Menu shortcuts (no Desktop). Low cost, high value for users who don't use terminal directly.

## Sources

### Primary (HIGH confidence)
- [Inno Setup Constants Documentation](https://jrsoftware.org/ishelp/topic_consts.htm) - Directory constants, auto constants
- [Inno Setup FAQ](https://jrsoftware.org/isfaq.php) - WM_SETTINGCHANGE broadcast, PATH handling
- [winget install Documentation](https://learn.microsoft.com/en-us/windows/package-manager/winget/install) - Silent install flags
- Codebase analysis: `MatrixShader.Monitor.csproj` (line 10: `<AssemblyName>matrix-monitor</AssemblyName>`)
- Codebase analysis: `MatrixShader.Cli.MatrixLite.csproj` (line 10: `<AssemblyName>matrixlite</AssemblyName>`)

### Secondary (MEDIUM confidence)
- [Stack Overflow/Tek-Tips consensus](https://www.tek-tips.com/threads/registry-path-change-update-without-restart.686382/) - WM_SETTINGCHANGE broadcast patterns
- [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/794169/installer-access-to-appdata) - Admin install to user paths issues

### Tertiary (LOW confidence)
- Windows Terminal shader version requirement (1.12) - Not officially documented, inferred from feature release notes
- Code signing impact - Mentioned but not tested

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Inno Setup is mature, well-documented
- Architecture: HIGH - First-run copy pattern is established best practice
- Pitfalls: HIGH - All derived from actual GAP-ANALYSIS.md findings and verified against codebase
- Windows Terminal: MEDIUM - Version requirements not officially documented

**Research date:** 2026-01-30
**Valid until:** 2026-03-30 (60 days - stable domain, Inno Setup 6.x unlikely to change significantly)
