# Installer & End-to-End Deployment Gap Analysis

**Analysis Date:** 2026-01-30
**Focus:** Installer completeness, path mismatches, first-run experience, user flow gaps

---

## Executive Summary

The Matrix Shader v1.0 was declared complete but the installer was never fully validated. Critical gaps exist between what the installer packages and what the code expects at runtime. The most severe issue is that `matrixlite.exe` (the fallback for non-Windows-Terminal environments) is not included in the installer despite being a key feature of the dual-mode architecture.

---

## GAP-E01: matrixlite.exe Not Included in Installer

**Severity:** Critical

**Files:**
- `installer/MatrixShaderSetup.iss` (lines 23-27)
- `installer/build-installer.ps1` (lines 26-31, 43-49)
- `MatrixShader/src/MatrixShader.Cli/MatrixLite/MatrixShader.Cli.MatrixLite.csproj`

**Problem:**
The `MatrixLite` project exists in the solution and provides the text-based fallback mode, but:
1. It is NOT listed in `build-installer.ps1`'s `$projects` array
2. It is NOT listed in `MatrixShaderSetup.iss` `[Files]` section
3. It is NOT verified in the executable check list

**Current installer includes:**
```
wakeupneo.exe, redpill.exe, bluepill.exe, matrix-monitor.exe
```

**Missing:**
```
matrixlite.exe
```

**Impact:**
- Users without Windows Terminal cannot use the Lite fallback mode as a standalone tool
- The `wakeupneo.exe` and `bluepill.exe` can fall back to Lite mode internally, but there's no standalone entry point

**Fix Approach:**
1. Add `"MatrixShader.Cli\MatrixLite"` to `$projects` in `build-installer.ps1`
2. Add `Source: "publish\matrixlite.exe"; DestDir: "{app}"; Flags: ignoreversion` to `.iss` file
3. Add `"matrixlite.exe"` to verification list

---

## GAP-E02: monitor.exe vs matrix-monitor.exe Naming Mismatch

**Severity:** Important

**Files:**
- `MatrixShader/src/MatrixShader.Cli/Bluepill/Program.cs` (lines 151-156)
- `installer/MatrixShaderSetup.iss` (line 26)

**Problem:**
Bluepill tries to start the background monitor by looking for two names:
```csharp
var monitorPath = Path.Combine(AppContext.BaseDirectory, "MatrixShader.Monitor.exe");
if (!File.Exists(monitorPath))
{
    monitorPath = Path.Combine(AppContext.BaseDirectory, "monitor.exe");
}
```

But the installer packages it as `matrix-monitor.exe`. Neither expected name matches.

**Impact:**
- Background monitor for drag-snap functionality never starts
- User sees "Monitor executable not found, skipping" in debug logs
- Layout re-application on window drag does not work

**Fix Approach:**
Either:
1. Rename the output in `MatrixShader.Monitor.csproj` to match what code expects (`MatrixShader.Monitor.exe`)
2. Or update the code in `Bluepill/Program.cs` to look for `matrix-monitor.exe`

---

## GAP-E03: Shader Files Path Assumptions

**Severity:** Important

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/ShaderService.cs` (lines 58-74)
- `installer/MatrixShaderSetup.iss` (line 27)

**Problem:**
ShaderService searches for shaders in this priority order:
```csharp
var candidates = new[]
{
    Path.Combine(Environment.SpecialFolder.MyDocuments, "Matrix", "shaders"),  // User's Documents
    Path.Combine(AppContext.BaseDirectory, "shaders"),                          // Install directory
    Path.Combine(Directory.GetParent(AppContext.BaseDirectory), "shaders")      // Parent of install
};
```

The installer places shaders at:
```
{app}\shaders  (e.g., C:\Program Files\MatrixShader\shaders)
```

This SHOULD work via `AppContext.BaseDirectory`, but:
1. If user has existing `Documents\Matrix\shaders` folder (from dev/previous version), that takes precedence
2. The installer does NOT clean up or migrate existing user data

**Impact:**
- Old shader files may take precedence over new installed ones
- Version mismatch between shader format and CLI expectations

**Fix Approach:**
1. Add installer option to migrate/backup existing user Matrix folder
2. Or change priority order to prefer installed shaders over user folder
3. Or add version markers to shader files for compatibility checking

---

## GAP-E04: ConfigService Hardcoded Dev Path

**Severity:** Important

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/ConfigService.cs` (lines 24-31)

**Problem:**
ConfigService has a hardcoded development path as a fallback:
```csharp
var candidates = new[]
{
    Path.Combine(Environment.SpecialFolder.MyDocuments, "Matrix"),
    Path.Combine(AppContext.BaseDirectory, "config"),
    @"C:\Users\ehome\Documents\Matrix"  // <-- HARDCODED DEV PATH
};
```

**Impact:**
- Code smell / unprofessional
- Would never actually be used in production (earlier paths would match first)
- Could theoretically cause issues on a system where the dev's path exists

**Fix Approach:**
Remove the hardcoded path entirely, or replace with a truly generic fallback.

---

## GAP-E05: Identity Registry Path Not Installed-Aware

**Severity:** Minor

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/IdentityService.cs` (lines 53-57)

**Problem:**
Identity registry is stored at:
```csharp
var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
_registryPath = Path.Combine(localAppData, "MatrixShader", "identity-registry.json");
```

This is actually CORRECT for Windows apps (LocalAppData is the right place). However:
1. The `MatrixShader` subfolder is never explicitly created by installer
2. First-time registration will create it, but there's no cleanup on uninstall

**Impact:**
- Minor: orphaned data remains after uninstall

**Fix Approach:**
Add cleanup section to installer for uninstall.

---

## GAP-E06: Windows Terminal Detection Does Not Verify Shader Support

**Severity:** Important

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/EnvironmentService.cs` (lines 62-69)
- `MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs` (lines 92-94)

**Problem:**
The code detects Windows Terminal installation by checking if `settings.json` exists:
```csharp
public static bool IsWindowsTerminalInstalled()
{
    return File.Exists(SettingsPath);  // Just checks file exists
}
```

And attempts to detect shader support by checking for `WT_PROFILE_ID`:
```csharp
public bool CanUseShaders()
{
    if (!IsWindowsTerminal()) return false;
    var wtProfile = Environment.GetEnvironmentVariable("WT_PROFILE_ID");
    return !string.IsNullOrEmpty(wtProfile);
}
```

**Issues:**
1. `settings.json` existing doesn't mean WT is usable (could be corrupted/incomplete)
2. WT version check is not implemented (shaders require WT 1.12+)
3. `CanUseShaders()` is never actually called in the user flow

**Impact:**
- User with old WT version gets launched into shader mode which fails silently
- No graceful degradation to Lite mode based on WT version

**Fix Approach:**
1. Parse `settings.json` to extract WT version or check for shader-related keys
2. Actually use `CanUseShaders()` in the decision flow
3. Add version detection via WT's `--version` flag

---

## GAP-E07: First-Run Experience - No Profile Creation Verification

**Severity:** Important

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` (lines 180-214)
- `MatrixShader/src/MatrixShader.Cli/WakeupNeo/Program.cs` (lines 305-308)

**Problem:**
`wakeupneo` creates Matrix profiles in Windows Terminal settings:
```csharp
var terminalSettings = _terminalService.LoadSettings();
_terminalService.CreateMatrixProfiles(terminalSettings, 8, shadersDir);
_terminalService.SaveSettings(terminalSettings);
```

But there's no verification that:
1. The profiles were actually written successfully
2. The settings.json is valid after modification
3. Windows Terminal can actually parse the modified settings

**Impact:**
- If settings.json write fails silently, user gets "profile not found" errors
- Corrupted settings.json requires manual recovery

**Fix Approach:**
1. Read back settings after save and verify profile exists
2. Test profile existence via `wt.exe -p "Matrix-1" --help` or similar
3. Add rollback capability using the backup mechanism

---

## GAP-E08: Documentation Mismatches

**Severity:** Important

**Files:**
- `README.md` (root)
- `MatrixShader/README.md`

**Problem:**
Root README says:
```markdown
## Install
npm install -g matrix-shader
```

This is incorrect - the project uses .NET/Inno Setup, not npm.

Also mentions:
```markdown
## Hotkeys
Run `matrix-hotkeys` in the background for global shortcuts
```

No `matrix-hotkeys` executable exists.

`MatrixShader/README.md` is accurate but references development paths, not installed paths.

**Impact:**
- Users cannot follow install instructions
- Confusion about what product actually provides

**Fix Approach:**
1. Update root README with actual install method (download installer / winget)
2. Remove or implement `matrix-hotkeys` feature
3. Add user-facing documentation separate from dev README

---

## GAP-E09: No Installer Verification on Clean System

**Severity:** Critical

**Files:**
- `installer/build-installer.ps1`
- `installer/MatrixShaderSetup.iss`

**Problem:**
The installer has never been tested on a clean Windows system. The build script:
1. Requires Inno Setup 6.x at a specific hardcoded path
2. Does not handle Inno Setup not being installed
3. Does not produce a portable installer alternative

**Impact:**
- Contributors cannot build installer without Inno Setup
- No CI/CD pipeline for automated installer builds
- No validation that installer actually works end-to-end

**Fix Approach:**
1. Add Inno Setup to project dependencies or provide download script
2. Create GitHub Actions workflow for installer building
3. Add VM-based E2E test for installer
4. Consider MSIX/WinGet as alternative distribution

---

## GAP-E10: PATH Registration Not Verified

**Severity:** Minor

**Files:**
- `installer/MatrixShaderSetup.iss` (lines 29-48)

**Problem:**
The installer adds `{app}` to system PATH via registry modification:
```pascal
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment";
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}";
    Check: NeedsAddPath(ExpandConstant('{app}'))
```

But:
1. Requires restart or `refreshenv` for PATH changes to take effect
2. Installer doesn't notify user about this
3. `NeedsAddPath` function doesn't handle case where PATH is very long (8192 char limit)

**Impact:**
- User tries `wakeupneo` immediately after install, command not found
- Confusion about whether install succeeded

**Fix Approach:**
1. Add post-install message about restart/new terminal needed
2. Or use `SendMessageTimeout` to broadcast `WM_SETTINGCHANGE`
3. Or add Start Menu shortcuts that don't rely on PATH

---

## GAP-E11: No Uninstall Cleanup

**Severity:** Minor

**Files:**
- `installer/MatrixShaderSetup.iss`

**Problem:**
The installer only has `[UninstallRegistry]` for PATH cleanup (line 51). It does not clean:
1. `%LOCALAPPDATA%\MatrixShader\` (identity registry)
2. `%USERPROFILE%\Documents\Matrix\` (shaders, state)
3. Windows Terminal profile entries

**Impact:**
- Reinstall may pick up stale data
- User data persists after uninstall (could be feature, not bug)

**Fix Approach:**
1. Add optional cleanup prompt during uninstall
2. Or document that user data is preserved
3. Add `[UninstallDelete]` section for app-generated files in AppData

---

## GAP-E12: TerminalSettingsService Creates Profiles with Wrong Shader Path

**Severity:** Critical

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` (lines 196-206)

**Problem:**
When creating Matrix profiles, the shader path is set to:
```csharp
PixelShaderPath = Path.Combine(shadersDirectory, $"Matrix-{i}.hlsl")
```

Where `shadersDirectory` comes from `CliBootstrap.GetShadersDirectory()`:
```csharp
private static readonly string ShadersDir = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
    "Matrix", "shaders");
```

But the installer puts shaders in:
```
C:\Program Files\MatrixShader\shaders\
```

**Impact:**
- Created profiles point to `Documents\Matrix\shaders\` which may not exist
- Shaders in Program Files are never used
- Windows Terminal shows blank/error because shader file not found

**Fix Approach:**
1. Update `CliBootstrap.GetShadersDirectory()` to check installed location first
2. Or copy shaders from install dir to user Documents on first run
3. Or use installed path directly for profile creation

---

## GAP-E13: Redpill Profile Creation References Non-Existent Control Panel Path

**Severity:** Important

**Files:**
- `MatrixShader/src/MatrixShader.Core/Services/TerminalSettingsService.cs` (lines 216-239)

**Problem:**
`CreateRedpillProfile` takes a `controlPanelPath` parameter:
```csharp
Commandline = $"\"{controlPanelPath}\"",
```

But this expects an executable path. The caller needs to provide the correct path to `redpill.exe`, but:
1. There's no standardized way to find installed `redpill.exe`
2. If installed via PATH, could use just `redpill.exe` but that doesn't work in WT profiles

**Impact:**
- Redpill profile may have invalid/broken command line

**Fix Approach:**
1. Use `{app}` install path when creating profile during install
2. Or use a known path like `%PROGRAMFILES%\MatrixShader\redpill.exe`
3. Or update profiles when executable location changes

---

## GAP-E14: Build Script Uses --no-self-contained:false

**Severity:** Minor

**Files:**
- `installer/build-installer.ps1` (line 36)

**Problem:**
```powershell
dotnet publish $csproj -c Release -o $PublishDir --no-self-contained:false
```

This syntax is confusing (double negative). Should be:
```powershell
dotnet publish $csproj -c Release -o $PublishDir --self-contained
```

Or for framework-dependent:
```powershell
dotnet publish $csproj -c Release -o $PublishDir
```

**Impact:**
- Unclear whether build is self-contained or framework-dependent
- May include unnecessary runtime files or missing required ones

**Fix Approach:**
Clarify intent and use explicit `--self-contained true` or `--self-contained false`.

---

## Summary Table

| Gap ID | Severity | Category | Short Description |
|--------|----------|----------|-------------------|
| GAP-E01 | Critical | Installer | matrixlite.exe not included |
| GAP-E02 | Important | Path | Monitor exe name mismatch |
| GAP-E03 | Important | Path | Shader path priority issues |
| GAP-E04 | Important | Code | Hardcoded dev path in ConfigService |
| GAP-E05 | Minor | Cleanup | Identity registry not in installer cleanup |
| GAP-E06 | Important | Detection | No WT version/shader support check |
| GAP-E07 | Important | First-Run | No profile creation verification |
| GAP-E08 | Important | Docs | README has wrong install instructions |
| GAP-E09 | Critical | Build | No clean-system installer validation |
| GAP-E10 | Minor | Install | PATH change requires restart |
| GAP-E11 | Minor | Cleanup | No uninstall cleanup for user data |
| GAP-E12 | Critical | Path | Profiles point to wrong shader location |
| GAP-E13 | Important | Path | Redpill profile command path issue |
| GAP-E14 | Minor | Build | Confusing self-contained flag |

---

## Recommended Priority Order

1. **GAP-E01** - Add matrixlite.exe to installer (Critical, quick fix)
2. **GAP-E12** - Fix shader path in profile creation (Critical, architectural)
3. **GAP-E02** - Fix monitor exe naming (Important, quick fix)
4. **GAP-E08** - Update README documentation (Important, quick fix)
5. **GAP-E09** - Set up CI/CD for installer (Critical, infrastructure)
6. **GAP-E06** - Add WT version checking (Important, user experience)
7. **GAP-E07** - Add profile verification (Important, reliability)
8. **GAP-E03** - Clarify shader path priority (Important, architectural)
9. **GAP-E13** - Fix Redpill profile path (Important)
10. **GAP-E04** - Remove hardcoded dev path (Important, cleanup)
11. Remaining Minor issues

---

*Gap analysis completed: 2026-01-30*
