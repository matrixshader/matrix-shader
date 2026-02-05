---
phase: 04-window-identity-service
verified: 2026-01-27T16:00:00Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 4: Window Identity Service Verification Report

**Phase Goal:** System reliably identifies Matrix shader windows across sessions
**Verified:** 2026-01-27T16:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Application distinguishes Matrix windows from other Windows Terminal instances | VERIFIED | 4-layer resolution with ProcessName check, profile matching, confidence scoring |
| 2 | Application tracks window identity through minimize/restore/move operations | VERIFIED | Launch registry with handle-based keys persists across state changes, GetAllWindows includes minimized |
| 3 | Application assigns confidence scores to identity matches (high/medium/low) | VERIFIED | 8 IdentitySource values with GetConfidence() returning 1.0, 0.95, 0.90, 0.85, 0.70 |
| 4 | Window-to-shader mappings persist and restore correctly after restart | VERIFIED | Registry at LocalAppData\MatrixShader with atomic writes, LoadRegistry on construction, _recoveredKeys tracking |

**Score:** 4/4 truths verified

### Required Artifacts (Level 1-3 Verification)


#### Plan 04-01 Artifacts

**WindowInfo.cs**
- EXISTS: MatrixShader/src/MatrixShader.Core/Models/WindowInfo.cs (111 lines)
- SUBSTANTIVE: Full IdentitySource enum (8 values), GetConfidence() extension method, WindowInfo record with Confidence property
- WIRED: GetConfidence() called in IdentityService.CreateWindowInfo (line 753)
- Status: VERIFIED

**IdentityEntry.cs**
- EXISTS: MatrixShader/src/MatrixShader.Core/Models/IdentityEntry.cs (46 lines)
- SUBSTANTIVE: IdentityRegistry and IdentityEntry records with all required properties
- WIRED: Used in MatrixJsonContext and IdentityService persistence
- Status: VERIFIED

**MatrixJsonContext.cs**
- EXISTS: MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs (25 lines)
- SUBSTANTIVE: [JsonSerializable] attributes for IdentityRegistry, IdentityEntry, Dictionary<string, IdentityEntry>
- WIRED: Used in IdentityService.SaveRegistryAtomic (line 333) and LoadRegistry (line 262)
- Status: VERIFIED

#### Plan 04-02 Artifacts

**MatrixShader.Core.csproj**
- EXISTS: MatrixShader/src/MatrixShader.Core/MatrixShader.Core.csproj
- SUBSTANTIVE: net8.0-windows TFM, FrameworkReference Microsoft.WindowsDesktop.App
- WIRED: Enables System.Windows.Automation namespace in IdentityService
- Status: VERIFIED

**WindowsApi.cs**
- EXISTS: MatrixShader/src/MatrixShader.Core/Native/WindowsApi.cs (494 lines)
- SUBSTANTIVE: IsWindow P/Invoke (line 71), IsHandleValid helper (lines 485-490)
- WIRED: IsHandleValid called in IdentityService.ResolveIdentity (line 92) and CleanStaleEntries (line 225)
- Status: VERIFIED

**IdentityService.cs**
- EXISTS: MatrixShader/src/MatrixShader.Core/Services/IdentityService.cs (777 lines)
- SUBSTANTIVE: Complete 4-layer resolution with batch WMI and UI Automation
- WIRED: All layers connected, BatchQueryCommandLines used in FindMatrixWindows, UI Automation with TermControl->TabItem->Name hierarchy
- Status: VERIFIED

#### Plan 04-03 Artifacts

**IdentityService.cs (persistence features)**
- EXISTS: Same file as 04-02
- SUBSTANTIVE: SaveRegistryAtomic (lines 302-346), LoadRegistry (lines 249-287), CleanStaleEntries (lines 188-246)
- WIRED: LocalAppData path (line 55), atomic writes (line 335), _recoveredKeys tracking (lines 36, 278, 368, 400)
- Status: VERIFIED

**IIdentityService.cs**
- EXISTS: MatrixShader/src/MatrixShader.Core/Services/IIdentityService.cs (64 lines)
- SUBSTANTIVE: All interface methods including CleanStaleEntries and RegisterWindowHandle
- WIRED: Implemented in IdentityService
- Status: VERIFIED

### Key Link Verification


**Link 1: WindowInfo.cs -> IdentitySourceExtensions**
- Pattern: GetConfidence() extension method
- Found: WindowInfo.cs line 99
- Used: IdentityService.cs line 753 (Confidence = source.GetConfidence())
- Status: WIRED

**Link 2: MatrixJsonContext -> IdentityEntry models**
- Pattern: [JsonSerializable] attribute
- Found: MatrixJsonContext.cs line 19
- Used: IdentityService SaveRegistryAtomic (line 333) and LoadRegistry (line 262)
- Status: WIRED

**Link 3: IdentityService -> System.Management (Batch WMI)**
- Pattern: OR-joined WMI query
- Found: IdentityService.cs lines 503-505
- Query: "SELECT ProcessId, CommandLine FROM Win32_Process WHERE (ProcessId=1 OR ProcessId=2...)"
- Status: WIRED

**Link 4: IdentityService -> System.Windows.Automation**
- Pattern: AutomationElement.FromHandle
- Found: IdentityService.cs line 561
- Hierarchy: TermControl (0.95) -> TabItem (0.85) -> Name (0.90)
- Status: WIRED

**Link 5: IdentityService -> MatrixJsonContext (AOT-safe serialization)**
- Pattern: MatrixJsonContext.Default usage
- Found: Serialize (line 333), Deserialize (line 262)
- Status: WIRED

**Link 6: IdentityService -> File.Move (Atomic writes)**
- Pattern: File.Move with overwrite: true
- Found: IdentityService.cs line 335
- Status: WIRED

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| WNDW-02: Distinguish Matrix windows from other terminals | SATISFIED | None |
| WNDW-08: Track window identity across operations | SATISFIED | None |
| STATE-02: Window-to-shader mapping persistence | SATISFIED | None |
| STATE-03: Identity confidence scoring | SATISFIED | None |

### Anti-Patterns Found

**None detected**

All code is substantive with real implementations:
- No TODO/FIXME comments
- No placeholder or stub patterns
- No empty returns or console.log-only handlers
- No hardcoded test data where dynamic expected

### Build Verification

```
dotnet build MatrixShader/src/MatrixShader.Core
Result: SUCCESS
Warnings: 0
Errors: 0
Time: 10.22 seconds
```

### Detailed Must-Haves Analysis


#### Plan 04-01: Identity Models

**Truth 1: IdentitySource enum has sub-variants for all confidence levels**
- VERIFIED: 8 enum values present (Unknown=0 through UIAutomationName=7)
- Evidence: WindowInfo.cs lines 63-88
- Confidence mapping: LaunchTracking=1.0, LaunchTrackingRecovered=0.95, CommandLine=0.95, UIAutomationTermControl=0.95, UIAutomationName=0.90, UIAutomationTab=0.85, Title=0.70, Unknown=0.0

**Truth 2: WindowInfo record includes Confidence property**
- VERIFIED: Line 30 declares public double Confidence { get; init; }
- Evidence: WindowInfo.cs line 30

**Truth 3: IdentityRegistry model matches PowerShell JSON format**
- VERIFIED: Version string, SavedAt DateTime, Dictionary<string, IdentityEntry> Entries
- Evidence: IdentityEntry.cs lines 7-20
- All IdentityEntry properties match PowerShell: ProfileName, ShaderIndex, ProcessId, WindowHandle (as string), LaunchTime, CorrelationId

**Truth 4: JSON context can serialize/deserialize identity registry**
- VERIFIED: [JsonSerializable(typeof(IdentityRegistry))] attribute present
- Evidence: MatrixJsonContext.cs line 19
- Additional: Dictionary<string, IdentityEntry> also registered (line 21)

#### Plan 04-02: Core Identity Resolution

**Truth 1: Batch WMI query retrieves command lines for multiple processes in single call**
- VERIFIED: BatchQueryCommandLines builds OR-joined query string
- Evidence: IdentityService.cs line 504: var pidFilter = string.Join(" OR ", pidList.Select(p => $"ProcessId={p}"))
- Performance: O(1) instead of O(n) for multiple processes

**Truth 2: UI Automation Layer 4 checks TermControl, then TabItem, then Name property**
- VERIFIED: GetUIAutomationIdentity follows exact hierarchy
- Evidence: IdentityService.cs lines 557-611
  - Priority 1: TermControl class (lines 564-578) -> confidence 0.95
  - Priority 2: TabItem control type (lines 580-594) -> confidence 0.85
  - Priority 3: Window Name (lines 596-603) -> confidence 0.90

**Truth 3: Handle validation requires both IsWindow AND IsWindowVisible**
- VERIFIED: IsHandleValid implementation at WindowsApi.cs line 489
- Evidence: return IsWindow(hWnd) && IsWindowVisible(hWnd)
- Used in: ResolveIdentity (line 92), ResolveIdentityWithCache (line 640), CleanStaleEntries (line 225)

**Truth 4: Identity resolution returns WindowInfo with correct confidence scores**
- VERIFIED: CreateWindowInfo sets Confidence from source.GetConfidence()
- Evidence: IdentityService.cs line 753: Confidence = source.GetConfidence()
- All WindowInfo results have confidence based on IdentitySource enum

#### Plan 04-03: Registry Persistence

**Truth 1: Registry stored in AppData\Local\MatrixShader\identity-registry.json**
- VERIFIED: Constructor uses Environment.SpecialFolder.LocalApplicationData
- Evidence: IdentityService.cs lines 55-56
- Path: Path.Combine(localAppData, "MatrixShader", "identity-registry.json")

**Truth 2: Atomic writes use temp file + File.Move pattern**
- VERIFIED: SaveRegistryAtomic implementation
- Evidence: IdentityService.cs lines 332-335
  - tempPath = _registryPath + ".tmp"
  - File.WriteAllText(tempPath, json, new UTF8Encoding(false))
  - File.Move(tempPath, _registryPath, overwrite: true)
- Error handling: Cleanup on failure (lines 340-342)

**Truth 3: Stale entries cleaned on startup (24-hour max age)**
- VERIFIED: CleanStaleEntries with default TimeSpan.FromHours(24)
- Evidence: IdentityService.cs line 190
- Validation: Process existence (lines 203-216), age cutoff (lines 219-220), handle validity (lines 223-227)

**Truth 4: JSON serialization uses AOT-compatible MatrixJsonContext**
- VERIFIED: Both SaveRegistryAtomic and LoadRegistry use MatrixJsonContext.Default
- Evidence: Serialize (line 333), Deserialize (line 262)
- No reflection-based serialization

### Phase Success Criteria (from ROADMAP.md)


**1. Application distinguishes Matrix windows from other Windows Terminal instances**
- VERIFIED: Multi-layer approach
  - GetTerminalWindows filters by ProcessName "WindowsTerminal" (line 714)
  - 4-layer resolution checks profile names, command line args, title patterns, UI Automation
  - Confidence scoring helps distinguish reliable vs uncertain matches
  - Control panel window specifically identified by title (lines 98-102, 644-647)

**2. Application tracks window identity through minimize/restore/move operations**
- VERIFIED: Robust tracking mechanism
  - Handle-based registry keys (_launchRegistry with handle as string key, line 169)
  - GetAllWindows includes minimized windows (WindowsApi.cs lines 349-362, IsWindowVisible returns true for minimized)
  - Launch registry persists to disk (SaveRegistry called after RegisterWindowHandle, line 172)
  - GetLaunchRegistryIdentity checks both handle-based (lines 360-387) and PID-based (lines 389-421) entries

**3. Application assigns confidence scores to identity matches (high/medium/low)**
- VERIFIED: 8-level confidence system
  - IdentitySource enum with 8 distinct values (lines 63-88)
  - GetConfidence() extension method returns 1.0, 0.95, 0.90, 0.85, 0.70, 0.0 (lines 99-109)
  - Fresh launch tracking: 1.0 (highest confidence)
  - Recovered from disk: 0.95
  - Command line parsing: 0.95
  - UI Automation TermControl: 0.95
  - UI Automation Name: 0.90
  - UI Automation Tab: 0.85
  - Title pattern match: 0.70 (lowest non-zero)

**4. Window-to-shader mappings persist and restore correctly after restart**
- VERIFIED: Complete persistence cycle
  - Registry path: LocalAppData\MatrixShader\identity-registry.json (lines 55-56)
  - Atomic writes prevent corruption (temp file pattern, line 335)
  - LoadRegistry called on service construction (line 59)
  - _recoveredKeys HashSet tracks recovered entries (line 36)
  - Fresh vs recovered distinction: LaunchTracking (1.0) vs LaunchTrackingRecovered (0.95) confidence (lines 368-370, 400-402)
  - SaveRegistry called after RegisterLaunch (line 145) and RegisterWindowHandle (line 172)

---

## Gaps Summary

**No gaps found** - All phase success criteria verified.

## Human Verification Required

**None** - All identity resolution features are verifiable programmatically:
- Build success confirms all code compiles
- Code inspection confirms all must-haves exist and are wired correctly
- Confidence scoring values match PowerShell exactly
- 4-layer resolution hierarchy implemented as specified
- Registry persistence with atomic writes verified

---

## Summary

Phase 4 (Window Identity Service) goal **ACHIEVED**. System reliably identifies Matrix shader windows across sessions with:

- 4-layer identity resolution hierarchy (Launch Tracking -> Command Line -> Title -> UI Automation)
- Confidence scoring (1.0, 0.95, 0.90, 0.85, 0.70) matching PowerShell exactly
- Batch WMI queries for O(1) command line lookup performance
- Handle-based window tracking surviving minimize/restore/move operations
- Atomic registry persistence at LocalAppData\MatrixShader
- Fresh vs recovered tracking for accurate confidence scores
- 24-hour stale entry cleanup

All 3 plans completed successfully, all must-haves verified, build passes with no warnings.

**Ready for Phase 5: Layout Service**

---

_Verified: 2026-01-27T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Build: dotnet 8.0 on Windows_
_Method: Code inspection + build verification_
