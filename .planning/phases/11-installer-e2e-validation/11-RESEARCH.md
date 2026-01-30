# Phase 11: Installer & E2E Validation - Research

**Researched:** 2026-01-30
**Domain:** Windows Installer (Inno Setup), Path Resolution, E2E Validation
**Confidence:** HIGH

## Summary

Phase 11 addresses 14 identified gaps in the installer and deployment system that prevent v1.0 from shipping. The existing Inno Setup installer framework is functional but incomplete - missing executables, incorrect path resolution, and no clean-system validation.

The research confirms Inno Setup as the correct tool (per user decision), identifies the standard patterns for handling user data in LocalAppData, and documents the winget + Store fallback pattern for Windows Terminal installation. Windows Sandbox provides an adequate manual testing environment for clean-system validation.

**Primary recommendation:** Fix path resolution architecture to use `%LOCALAPPDATA%\MatrixShader\` as the canonical user data location, update installer to copy shaders there at install time, and validate the complete flow in Windows Sandbox before release.

## Standard Stack

The established tools/libraries for this domain:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Inno Setup | 6.x | Windows installer creation | User decision; mature, widely-used, supports Pascal scripting for custom logic |
| Windows Sandbox | Built-in | Clean system testing | Zero-setup disposable environment, .wsb config files for automation |
| winget | CLI | WT installation at install time | Microsoft's official package manager, supports silent mode |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| dotnet publish | Build self-contained executables | During installer build process |
| ISCC.exe | Inno Setup Compiler CLI | Automated/CI builds |
| WM_SETTINGCHANGE | Broadcast env var changes | After PATH modification without restart |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inno Setup | MSIX/WinGet | Modern distribution but more complex, deferred to v2 |
| Windows Sandbox | Hyper-V VM | More control but heavier setup, overkill for manual testing |
| winget | Chocolatey | Alternative package manager but winget is now standard |

**Installation:**
```powershell
# Inno Setup (if not already installed)
winget install JRSoftware.InnoSetup --silent --accept-source-agreements --accept-package-agreements
```

## Architecture Patterns

### Recommended File Layout (Post-Install)

```
C:\Program Files\MatrixShader\           # {app} - Executables
    wakeupneo.exe
    bluepill.exe
    redpill.exe
    matrixlite.exe                       # MISSING - GAP-E01
    matrix-monitor.exe

%LOCALAPPDATA%\MatrixShader\             # User data (created at first run OR install)
    shaders\
        Matrix-1.hlsl through Matrix-8.hlsl
        Redpill-Neo.hlsl
    matrix_state.json
    identity-registry.json
    debug.log (if enabled)
```

### Pattern 1: Dual-Location Architecture
**What:** Executables in Program Files, user data in LocalAppData
**When to use:** Always for Windows desktop apps that need user-writable config
**Rationale:** Per [Inno Setup best practices](https://jrsoftware.org/ishelp/topic_consts.htm), installer should NOT write to user paths during admin install. App creates user data on first run.

**Current Problem:** Code expects shaders in `Documents\Matrix\shaders\`, but installer puts them in `{app}\shaders`. CONTEXT.md decision says installer should copy to LocalAppData during install.

### Pattern 2: Install-time WT Detection + winget
**What:** Check if Windows Terminal exists, install via winget if not
**When to use:** During installer execution, not at runtime
**Implementation:**
```pascal
// In Inno Setup [Code] section
function WindowsTerminalExists(): Boolean;
var
  SettingsPath: String;
begin
  SettingsPath := ExpandConstant('{localappdata}\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json');
  Result := FileExists(SettingsPath);
end;

procedure InstallWindowsTerminal();
var
  ResultCode: Integer;
begin
  // Try winget first
  Exec('winget', 'install Microsoft.WindowsTerminal --silent --accept-source-agreements --accept-package-agreements',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  if not WindowsTerminalExists() then
  begin
    // Fallback: open Store page
    ShellExec('open', 'ms-windows-store://pdp/?ProductId=9N0DX20HK701', '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
  end;
end;
```

### Pattern 3: PATH Environment Variable with Broadcast
**What:** Add install directory to PATH and broadcast change
**When to use:** To enable CLI commands from any terminal immediately
**Implementation:**
```pascal
// In Inno Setup [Code] section - called after install
procedure BroadcastEnvironmentChange();
var
  Dummy: Integer;
begin
  // Tell Windows to refresh environment (avoids restart requirement)
  SendBroadcastMessage(WM_SETTINGCHANGE, 0, 'Environment');
end;
```

Note: Inno Setup's `ChangesEnvironment=yes` directive already handles broadcasting, but users should be informed that a new terminal window is needed.

### Anti-Patterns to Avoid
- **Hardcoded development paths:** ConfigService.cs has `C:\Users\ehome\Documents\Matrix` - must remove
- **Installing to user paths from admin installer:** Inno Setup warns against `{localappdata}` in `[Files]` during admin install
- **Assuming PATH works immediately:** New PATH only visible in new terminal sessions
- **Writing profiles with Documents path:** TerminalSettingsService creates profiles pointing to Documents, but shaders are in Program Files

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Silent WT install | Custom download script | `winget install --silent` | Handles updates, dependencies, Store integration |
| PATH modification | Manual registry edits | Inno Setup `[Registry]` section + `ChangesEnvironment=yes` | Proper escaping, uninstall cleanup, WM_SETTINGCHANGE |
| Clean system testing | Custom VM setup | Windows Sandbox `.wsb` file | Zero-setup, ephemeral, maps host folders |
| Uninstall cleanup | Manual file deletion | Inno Setup `[UninstallDelete]` section | Proper order, error handling |

**Key insight:** Inno Setup provides all the building blocks needed. The gaps are about using them correctly, not building alternatives.

## Common Pitfalls

### Pitfall 1: Admin Install vs User Data
**What goes wrong:** Admin installer tries to write to `{localappdata}` or `{userappdata}`, but these resolve to the admin user's profile, not the actual user
**Why it happens:** `{localappdata}` in Inno Setup refers to the user running setup (often elevated admin)
**How to avoid:**
1. Install executables and "template" data to `{app}`
2. Have the application copy user data on first run
3. Or use `{localappdata}` with `Flags: onlyifdoesntexist` and create at first run anyway
**Warning signs:** Works for developer (same user), fails for other users

### Pitfall 2: Profile Creation Points to Wrong Path
**What goes wrong:** Windows Terminal profiles have `pixelShaderPath` pointing to non-existent location
**Why it happens:** CliBootstrap.GetShadersDirectory() returns Documents path, but installer puts shaders elsewhere
**How to avoid:**
1. Make all code use `%LOCALAPPDATA%\MatrixShader\shaders` as canonical path
2. Or fix installer to actually copy shaders there
**Warning signs:** "Shader not found" errors, blank terminal screens

### Pitfall 3: Monitor Executable Name Mismatch (GAP-E02)
**What goes wrong:** Bluepill looks for `MatrixShader.Monitor.exe` or `monitor.exe`, but installer provides `matrix-monitor.exe`
**Why it happens:** Disconnect between csproj `<AssemblyName>` and code assumptions
**How to avoid:** Verify executable names in code match csproj AssemblyName
**Warning signs:** Debug log shows "Monitor executable not found"

### Pitfall 4: PATH Not Effective Until New Terminal
**What goes wrong:** User runs `wakeupneo` immediately after install, gets "command not found"
**Why it happens:** PATH changes require new process to see them
**How to avoid:**
1. Display post-install message: "Open a new terminal to use commands"
2. Or create Start Menu shortcuts that don't rely on PATH
3. `ChangesEnvironment=yes` broadcasts change, but existing terminals don't update
**Warning signs:** "wakeupneo is not recognized" immediately after install

### Pitfall 5: matrixlite.exe Missing (GAP-E01)
**What goes wrong:** Non-WT fallback mode unavailable
**Why it happens:** MatrixLite project exists but not included in build-installer.ps1 or .iss
**How to avoid:** Audit all CLI projects in solution, verify each is published and packaged
**Warning signs:** User without Windows Terminal has no fallback option

## Code Examples

Verified patterns for this phase:

### Inno Setup: Copy Shaders to LocalAppData
```ini
; Source: [Code] section at [Run] time
[Run]
Filename: "{cmd}"; Parameters: "/c xcopy ""{app}\shaders"" ""{localappdata}\MatrixShader\shaders"" /E /I /Y"; \
    Flags: runhidden waituntilterminated; StatusMsg: "Copying shaders..."
```

Alternative using Pascal Script for more control:
```pascal
[Code]
procedure CopyShadersToLocalAppData();
var
  SourceDir, DestDir: String;
begin
  SourceDir := ExpandConstant('{app}\shaders');
  DestDir := ExpandConstant('{localappdata}\MatrixShader\shaders');

  if not DirExists(DestDir) then
    ForceDirectories(DestDir);

  // DirectoryCopy is available in Inno Setup 6
  DirectoryCopy(SourceDir, DestDir);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    CopyShadersToLocalAppData();
end;
```

### winget Silent Install Command
```powershell
# Full command for Windows Terminal installation
winget install --id Microsoft.WindowsTerminal --exact --silent --accept-source-agreements --accept-package-agreements
```
Source: [Microsoft winget install documentation](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)

### Windows Sandbox Configuration (.wsb)
```xml
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>  <!-- Enable for winget to work -->
  <MemoryInMB>4096</MemoryInMB>

  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\path\to\installer\output</HostFolder>
      <SandboxFolder>C:\Installer</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>

  <LogonCommand>
    <Command>powershell.exe -ExecutionPolicy Bypass -Command "Start-Process 'C:\Installer\MatrixShaderSetup.exe' -Wait; C:\Test\validate.ps1"</Command>
  </LogonCommand>
</Configuration>
```
Source: [Microsoft Windows Sandbox documentation](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/)

### Uninstall Cleanup Section
```ini
[UninstallDelete]
; Clean up LocalAppData files
Type: filesandordirs; Name: "{localappdata}\MatrixShader"

; Note: Documents\Matrix is user-created data, leave it (or prompt)
```

### PATH Addition with Check
```ini
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
  // Case-insensitive check for path
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;
```
Source: Existing MatrixShaderSetup.iss (verified correct pattern)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Documents folder for user data | LocalAppData | Windows best practice | Proper isolation, roaming support |
| Manual WT download | winget install | winget stable (2021+) | Automated, silent, updatable |
| Restart after PATH change | WM_SETTINGCHANGE broadcast | Always available | New terminals see PATH immediately |
| Manual VM testing | Windows Sandbox | Windows 10 1903+ | Ephemeral, fast, .wsb automation |

**Deprecated/outdated:**
- `npm install` mentioned in README - this is a .NET project, not Node.js
- `matrix-hotkeys` command - does not exist, remove from docs

## Open Questions

Things that couldn't be fully resolved:

1. **Windows Terminal minimum version for shaders**
   - What we know: Pixel shaders work in recent WT versions (1.12+), experimental.pixelShaderPath setting
   - What's unclear: Exact minimum version, how to detect version programmatically
   - Recommendation: Check for settings.json existence (current approach) + add fallback message if shader doesn't load

2. **Self-contained vs Framework-dependent publish**
   - What we know: Current build uses confusing `--no-self-contained:false` syntax
   - What's unclear: Whether .NET 8 runtime is available on target machines
   - Recommendation: Use `--self-contained true` explicitly for widest compatibility

3. **Profile creation timing**
   - What we know: Profiles need correct shader paths
   - What's unclear: Should installer create profiles (risky, modifies user settings) or should app do it on first run?
   - Recommendation: App creates profiles on first run (safer, can handle updates)

## Sources

### Primary (HIGH confidence)
- [Inno Setup Constants Documentation](https://jrsoftware.org/ishelp/topic_consts.htm) - `{localappdata}`, `{app}` behavior
- [Inno Setup ChangesEnvironment](https://jrsoftware.org/ishelp/topic_setup_changesenvironment.htm) - PATH broadcast
- [Inno Setup UninstallDelete](https://jrsoftware.org/ishelp/topic_uninstalldeletesection.htm) - Cleanup patterns
- [winget install command](https://learn.microsoft.com/en-us/windows/package-manager/winget/install) - Silent install flags
- [Windows Sandbox Documentation](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/) - .wsb configuration

### Secondary (MEDIUM confidence)
- [Windows Terminal Pixel Shaders README](https://github.com/microsoft/terminal/blob/main/samples/PixelShaders/README.md) - Shader configuration
- [Advanced Installer Testing in Sandbox](https://www.advancedinstaller.com/test-msi-msix-exe-installers-in-windows-sandbox.html) - Testing methodology
- Existing project files: MatrixShaderSetup.iss, build-installer.ps1, validate.ps1

### Tertiary (LOW confidence)
- Various forum posts about Inno Setup best practices (general guidance only)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Inno Setup documented, winget official docs, Sandbox well-documented
- Architecture: MEDIUM - Patterns verified against existing code and official docs, but path resolution needs testing
- Pitfalls: HIGH - All derived from actual GAP-ANALYSIS.md findings with code evidence

**Research date:** 2026-01-30
**Valid until:** 60 days (Inno Setup stable, patterns established)

---

## Gap-Specific Technical Notes

### GAP-E01: matrixlite.exe Missing
- **Fix location:** `installer/build-installer.ps1` line 26-31, `installer/MatrixShaderSetup.iss` line 23-27
- **Verified:** MatrixLite.csproj exists with `<AssemblyName>matrixlite</AssemblyName>`

### GAP-E02: Monitor Name Mismatch
- **Current:** Bluepill looks for `MatrixShader.Monitor.exe` or `monitor.exe`
- **Actual:** csproj has `<AssemblyName>matrix-monitor</AssemblyName>`
- **Fix:** Update Bluepill code to use `matrix-monitor.exe`

### GAP-E04: Hardcoded Dev Path
- **Location:** `ConfigService.cs` line 28
- **Fix:** Remove the line `@"C:\Users\ehome\Documents\Matrix"`

### GAP-E12: Wrong Shader Path in Profiles
- **Root cause:** `CliBootstrap.GetShadersDirectory()` returns Documents path
- **Fix:** Update to return `%LOCALAPPDATA%\MatrixShader\shaders` and ensure installer copies shaders there

### GAP-E08: README Incorrect
- **Issues:** npm install (wrong), matrix-hotkeys (doesn't exist), Node.js requirement (wrong)
- **Fix:** Rewrite README for actual install method
