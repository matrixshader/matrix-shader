# Domain Pitfalls: PowerShell-to-C# Port for Windows Terminal Shader Controller

**Domain:** PowerShell-to-C# porting, Windows Terminal shader control, Windows API interop
**Researched:** 2026-01-25
**Context:** Previous C# attempt FAILED - built only MatrixLite text fallback, didn't work in any terminal

---

## Critical Pitfalls

Mistakes that cause complete project failure or rewrites. These are the highest priority to prevent.

---

### Pitfall 1: Scope Creep Disguised as "Better Architecture"

**What goes wrong:** Instead of porting the working PowerShell functionality 1:1, the developer builds "improved" architecture with abstractions, interfaces, dependency injection, and fallback modes that obscure the core functionality. The previous attempt created a sophisticated `EnvironmentService.DetectRenderMode()`, `IShaderService`, `IConfigService`, and `TextMatrixRenderer` - but the actual shader control that makes the Matrix rain work was never properly implemented.

**Why it happens:**
- C# culture encourages clean architecture patterns
- PowerShell's "scripting style" feels "messy" to port directly
- It's more interesting to design abstractions than translate boring file I/O
- Context bloat during implementation causes AI/developer to lose track of what's actually required

**Consequences:**
- Core functionality (GPU shader control) is never implemented
- The "Lite" fallback becomes the only working mode
- Hours spent on architecture that doesn't serve the primary use case
- Product doesn't match user expectations (they want Matrix rain, not text animation)

**Prevention:**
1. **Phase 1 MUST be exact port** - Translate `matrix_control.ps1` line-by-line before any abstraction
2. **Define "done" as feature parity** - Not "cleaner code," but "does the same thing"
3. **Test against the working PowerShell version** - Side-by-side comparison
4. **Ban "Lite" mode until Full mode works** - Don't create fallbacks that become the default

**Detection:**
- Code review asks: "Where is the HLSL file being written?"
- If answer involves multiple layers of abstraction before hitting the disk, STOP
- If `TextMatrixRenderer` exists before `ShaderService.WriteConfig()` is tested, STOP

**Phase mapping:** Phase 1 (Core Port) - Enforce strict 1:1 translation

---

### Pitfall 2: Not Testing in Clean Environment Early

**What goes wrong:** Developer tests on their own machine where dependencies exist (correct .NET version, Windows Terminal configured, Matrix profiles already created). Application "works" locally but fails on fresh Windows install or Windows Sandbox.

**Why it happens:**
- Setting up clean test environments is friction
- "It works on my machine" feels like progress
- Deployment concerns feel like "later" problems
- Previous attempt never tested MatrixLite in Windows Sandbox until too late

**Consequences:**
- Hidden dependencies on local configuration
- App requires manual setup steps that aren't documented
- Fails for new users immediately
- Previous C# attempt failed in Windows Sandbox even with MatrixLite

**Prevention:**
1. **Windows Sandbox test in Phase 1** - Before any other development
2. **Use self-contained deployment** from day 1:
   ```bash
   dotnet publish -c release -r win-x64 --self-contained true
   ```
3. **Document all prerequisites** the installer must create
4. **Test BOTH scenarios**: fresh install AND existing Matrix user upgrade

**Detection:**
- No Windows Sandbox test script = Red flag
- "Assumes Windows Terminal is installed" without installer handling it = Red flag
- Self-contained deployment not in build script = Red flag

**Phase mapping:** Phase 1 (Core Port) - Include Sandbox test gate

---

### Pitfall 3: P/Invoke Declaration Mismatch

**What goes wrong:** The PowerShell `Add-Type` P/Invoke declarations work because PowerShell handles marshalling flexibly. Direct C# P/Invoke has stricter requirements - wrong calling convention, incorrect struct layouts, or mismatched types cause silent failures or crashes.

**Why it happens:**
- PowerShell's `Add-Type -TypeDefinition` is forgiving
- Copy-pasting from PowerShell to C# doesn't always work
- Windows API documentation is notoriously imprecise about parameter sizes
- 32-bit vs 64-bit pointer differences

**Consequences:**
- `EnumWindows` returns nothing
- `SetWindowPos` moves windows to wrong coordinates
- Memory corruption in struct marshalling
- Windows 10/11 border handling causes visual gaps

**Prevention:**
1. **Use PInvoke.net or dotnet/pinvoke library** - Don't hand-roll declarations
2. **Test each P/Invoke individually** before integrating
3. **Compare results to PowerShell version** - Same API, same result expected
4. **Be explicit about struct packing:** `[StructLayout(LayoutKind.Sequential)]`
5. **Use `IntPtr` for handles**, not `int` or `long`

**Detection:**
- Window positioning off by ~7 pixels = Windows 10/11 border issue
- `GetWindowRect` returns different values than PowerShell = struct mismatch
- EnumWindows callback never fires = calling convention wrong

**Phase mapping:** Phase 2 (Window Management) - Extensive P/Invoke testing

---

### Pitfall 4: Regex Pattern Differences Between PowerShell and C#

**What goes wrong:** PowerShell regex has different defaults than C# `Regex`. Patterns that work in PowerShell `-match` operator fail or match differently in C#.

**Why it happens:**
- PowerShell `-match` is case-insensitive by default; C# `Regex.Match` is case-sensitive
- PowerShell allows `/` or `\` in patterns; C# requires proper escaping
- Capture group access differs: `$Matches[1]` vs `match.Groups[1].Value`

**Consequences:**
- Shader parameter parsing fails silently
- Profile detection returns wrong matches
- Configuration file corruption

**Prevention:**
1. **Use `RegexOptions.IgnoreCase`** explicitly in C#
2. **Test regex patterns in isolation** with known inputs
3. **Previous code has working patterns** - extract and test them:
   ```csharp
   // PowerShell: $m = [regex]::Match($c, "#define $($map[$k])\s+([\d\.]+)")
   // C#: var m = Regex.Match(content, @"#define RAIN_R\s+([\d.]+)");
   ```

**Detection:**
- Shader files written with `0` values when they should have floats
- Profile matching returns null when profile exists
- Add unit tests for EVERY regex pattern

**Phase mapping:** Phase 1 (Core Port) - Regex unit test suite required

---

### Pitfall 5: File Encoding and Line Ending Mismatch

**What goes wrong:** PowerShell files require CRLF line endings (as noted in CLAUDE.md). C# `File.WriteAllText` defaults to platform default, which might differ. Shader files may get corrupted or fail to hot-reload.

**Why it happens:**
- .NET Core defaults are cross-platform focused
- Developer doesn't think about line endings
- Git autocrlf settings can mask the problem in development
- Windows Terminal shader parser may be sensitive to encoding

**Consequences:**
- Shader files fail to compile
- Hot-reload stops working
- JSON files become unreadable
- Settings changes don't persist correctly

**Prevention:**
1. **Explicit UTF-8 with BOM for settings.json**
2. **Use `Environment.NewLine` or explicit `"\r\n"` for CRLF**
3. **Atomic write pattern** (write to temp, then move - already in PowerShell code)
4. **Test: Write file, read file, compare byte-for-byte**

**Detection:**
- Shader works in PowerShell but not C# version
- `git diff` shows every line changed (line ending change)
- JSON parse errors on valid-looking JSON

**Phase mapping:** Phase 1 (Core Port) - File I/O validation tests

---

## Moderate Pitfalls

Mistakes that cause delays or significant rework but are recoverable.

---

### Pitfall 6: TUI Framework Choice Lock-in

**What goes wrong:** Developer picks Spectre.Console because it's popular, then discovers it's NOT a TUI framework but a "draw static things to console" library. The control panel needs interactive keyboard input with live updates - Spectre.Console requires different patterns than Terminal.Gui.

**Why it happens:**
- Spectre.Console has great marketing and documentation
- "Console UI" sounds like what we need
- Terminal.Gui sounds legacy but is actually the right tool
- Previous attempt used Spectre.Console incorrectly

**Consequences:**
- Control panel UX feels clunky
- Keyboard handling is non-obvious
- Live updates require workarounds
- May need to switch frameworks mid-project

**Prevention:**
1. **Evaluate frameworks against PowerShell's ReadKey loop pattern**
2. **Terminal.Gui** is the better match for this use case:
   - Keyboard input handling built-in
   - Windows/panels/forms model
   - Live refresh support
3. **Prototype the control panel UI FIRST** before committing

**Detection:**
- Using `await Task.Delay(50)` in render loop = Spectre.Console limitation
- No native way to handle Shift+Key combinations = wrong framework
- UI flickers on redraw = wrong framework

**Phase mapping:** Phase 3 (Control Panel) - Framework evaluation spike first

---

### Pitfall 7: Windows Terminal Settings.json Race Conditions

**What goes wrong:** Windows Terminal has its settings.json open and watches for changes. C# code writes to it while Terminal is reading, causing corruption or ignored changes.

**Why it happens:**
- No file locking coordination
- Multiple processes (C# app, Windows Terminal, possibly VS Code) all touching the file
- PowerShell version got lucky or has implicit timing

**Consequences:**
- Profile changes don't apply
- Settings.json becomes corrupted
- User has to manually restore settings
- Intermittent failures that are hard to reproduce

**Prevention:**
1. **Read-modify-write with minimal time window**
2. **Atomic write pattern**: Write to `.tmp`, then `Move-Item -Force`
3. **Consider retry logic** if file is locked
4. **Test with Windows Terminal actively running**

**Detection:**
- Changes work sometimes but not always
- Profile colors don't update after shader color change
- JSON parse errors in Windows Terminal

**Phase mapping:** Phase 1 (Core Port) - Concurrency testing

---

### Pitfall 8: Window Identity Service Complexity

**What goes wrong:** The PowerShell `WindowIdentityService.ps1` implements a sophisticated 4-layer identity hierarchy (Launch Tracking -> Command Line -> Title -> UI Automation). Porting this naively creates a maintenance nightmare. But simplifying it loses window tracking reliability.

**Why it happens:**
- 1287 lines of identity service code
- Multiple fallback strategies
- WMI queries, UI Automation, regex patterns
- Easy to miss a case or introduce timing bugs

**Consequences:**
- Windows assigned wrong shader slots
- Layout engine positions windows incorrectly
- Ghost entries in registry
- Inconsistent behavior across sessions

**Prevention:**
1. **Port identity service AS A UNIT** - not piecemeal
2. **Keep the 4-layer fallback design** - it exists for good reasons
3. **Integration tests with real windows** - not mocks
4. **Performance budget**: 120ms for 6 windows (documented target)

**Detection:**
- Test: Launch 4 windows, verify each gets correct shader slot
- Test: Rename window title, verify identity still resolves
- Test: Close/reopen windows, verify registry cleanup works

**Phase mapping:** Phase 2 (Window Management) - Dedicated identity service phase

---

### Pitfall 9: Hot-Reload Timing Sensitivity

**What goes wrong:** Windows Terminal detects shader file changes via file timestamp, but the detection interval is undocumented. Writing too fast may miss the detection window. Writing too slow makes the UI feel laggy.

**Why it happens:**
- Windows Terminal's internal polling interval is unknown (~100ms per CLAUDE.md)
- File timestamp resolution on Windows is ~15ms
- Network drives have different timing
- PowerShell's timing "just works" but C# async patterns may differ

**Consequences:**
- Shader changes don't appear
- Need to toggle shader off/on to see updates
- Inconsistent behavior across machines

**Prevention:**
1. **Touch file timestamp explicitly** after write
2. **Add small delay** (50-100ms) after write before confirming to user
3. **Consider FileSystemWatcher** feedback if available
4. **Test with slow storage** (USB drive, network share)

**Detection:**
- User changes color, nothing happens
- Changes appear after a random delay
- Works on SSD, fails on HDD

**Phase mapping:** Phase 1 (Core Port) - Hot-reload stress testing

---

## Minor Pitfalls

Mistakes that cause annoyance but are easily fixed.

---

### Pitfall 10: Console Input Handling Platform Differences

**What goes wrong:** `Console.ReadKey()` behaves differently on different terminals. Windows Console vs Windows Terminal vs PowerShell ISE vs SSH session all have quirks.

**Prevention:**
1. **Target Windows Terminal specifically** (it's in the product name)
2. **Document: "Run in Windows Terminal"**
3. **Graceful degradation** for other consoles

**Phase mapping:** Phase 3 (Control Panel)

---

### Pitfall 11: Color Code Translation

**What goes wrong:** PowerShell uses `Write-Host -ForegroundColor Green` while C# uses ANSI escape codes or framework-specific APIs. Color appearance may differ.

**Prevention:**
1. **Use TrueColor ANSI codes** for consistency
2. **Test color presets visually** against PowerShell version

**Phase mapping:** Phase 3 (Control Panel)

---

### Pitfall 12: Path Handling Across Environments

**What goes wrong:** Hardcoded paths like `C:\Users\ehome\Documents\Matrix` don't work for other users. `Environment.SpecialFolder.MyDocuments` has edge cases.

**Prevention:**
1. **Use `Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)`**
2. **Allow path override** via environment variable
3. **Handle OneDrive folder redirection** (common on Windows 11)

**Phase mapping:** Phase 1 (Core Port)

---

## Previous Failure Mode Analysis

Based on the context provided, the previous C# attempt failed for these specific reasons:

### Failure 1: MatrixLite Priority Inversion
**What happened:** Built `TextMatrixRenderer.cs` (226 lines) before GPU shader control worked.
**Root cause:** "Lite mode" seemed like a good fallback, became the only mode.
**Lesson:** Core functionality first. Fallbacks later. Test Full mode before building Lite mode.

### Failure 2: Environment Detection Over-Engineering
**What happened:** Created `EnvironmentService.DetectRenderMode()` to choose between Full/Lite/None modes.
**Root cause:** Solving a problem that doesn't exist - Windows Terminal always supports shaders.
**Lesson:** The target environment is KNOWN. Don't abstract for environments you're not targeting.

### Failure 3: No Incremental Testing
**What happened:** Built complete architecture, tested at the end, nothing worked in Sandbox.
**Root cause:** Assumed dependencies would "just be there."
**Lesson:** Test in clean environment after EVERY phase, not just at the end.

### Failure 4: Context Bloat
**What happened:** Implementation lost track of what features were actually required.
**Root cause:** AI context window filled with architecture decisions, lost sight of requirements.
**Lesson:** Keep explicit checklist of PowerShell features. Check off as each is verified working.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Core Port | Scope creep to "better" architecture | Enforce 1:1 translation first |
| Core Port | Regex pattern differences | Unit test every pattern |
| Core Port | File encoding mismatch | Explicit encoding, CRLF |
| Window Management | P/Invoke declaration errors | Use dotnet/pinvoke library |
| Window Management | Identity service complexity | Port as unit, integration tests |
| Control Panel | TUI framework mismatch | Evaluate Terminal.Gui vs Spectre |
| Control Panel | Keyboard input handling | Test Shift+Key combinations |
| Integration | Settings.json race conditions | Atomic writes, retry logic |
| Testing | Works on dev machine only | Windows Sandbox every phase |

---

## Quality Gates

Each phase should include these verification steps:

### Phase 1 Quality Gate
- [ ] PowerShell feature checklist: all items checked
- [ ] Side-by-side comparison with `matrix_control.ps1` output
- [ ] Windows Sandbox: fresh install test passes
- [ ] Shader hot-reload: change persists within 500ms
- [ ] NO "Lite mode" code exists yet

### Phase 2 Quality Gate
- [ ] Window detection matches PowerShell output exactly
- [ ] Window positioning pixel-accurate (account for borders)
- [ ] Identity service: 120ms budget for 6 windows
- [ ] Layout modes: Pillars and Quads both work

### Phase 3 Quality Gate
- [ ] All keyboard shortcuts from PowerShell version work
- [ ] UI refresh doesn't flicker
- [ ] Tab switching preserves dirty state
- [ ] Exit saves state correctly

---

## Sources

- [Microsoft Learn: Prerequisites to port from .NET Framework](https://learn.microsoft.com/en-us/dotnet/core/porting/premigration-needed-changes)
- [GitHub: Windows Terminal Pixel Shader Issues #9338](https://github.com/microsoft/terminal/issues/9338)
- [GitHub: Windows Terminal Shaders Repository](https://github.com/Hammster/windows-terminal-shaders)
- [Microsoft Learn: P/Invoke Platform Invoke](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke)
- [Microsoft Learn: Native Interoperability Best Practices](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/best-practices)
- [PInvoke.net: SetWindowPos](https://www.pinvoke.net/default.aspx/user32.setwindowpos)
- [Microsoft Learn: SetWindowPos Function](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos)
- [GitHub: Terminal.Gui](https://github.com/gui-cs/Terminal.Gui)
- [Spectre.Console Documentation](https://spectreconsole.net/)
- [Running .NET Core apps on Windows Sandbox](https://gunnarpeipman.com/dotnet-core-windows-sandbox/)
- [Microsoft Learn: Add-Type cmdlet](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type)
- Existing codebase analysis: `matrix_control.ps1`, `WindowIdentityService.ps1`, `WindowLayoutEngine.ps1`
- Previous C# attempt analysis: `MatrixShader/` directory
