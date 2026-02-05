---
phase: 04-window-identity-service
plan: 01
subsystem: identity-models
tags: [identity, confidence, models, json, aot]

dependency-graph:
  requires: [03-windows-api-layer]
  provides: [identity-models, confidence-scoring, identity-registry-format]
  affects: [04-02, 04-03]

tech-stack:
  added: []
  patterns: [extension-methods, confidence-scoring]

key-files:
  created:
    - MatrixShader/src/MatrixShader.Core/Models/IdentityEntry.cs
  modified:
    - MatrixShader/src/MatrixShader.Core/Models/WindowInfo.cs
    - MatrixShader/src/MatrixShader.Core/Serialization/MatrixJsonContext.cs

decisions:
  - id: "04-01-a"
    choice: "IdentitySource enum values 0-7 with confidence mapping via extension method"
    reason: "Matches PowerShell exactly, allows confidence lookup without reflection"
  - id: "04-01-b"
    choice: "WindowHandle stored as string in IdentityEntry"
    reason: "nint is not JSON-friendly, string serializes cleanly"
  - id: "04-01-c"
    choice: "Dictionary<string, IdentityEntry> for registry entries"
    reason: "Matches PowerShell JSON format with handle keys"

metrics:
  duration: 4 min
  completed: 2026-01-27
---

# Phase 04 Plan 01: Identity Models Summary

**One-liner:** Extended IdentitySource enum with 8 confidence-scored sub-variants and IdentityRegistry persistence models

## What Was Built

### Task 1: Extended IdentitySource Enum
Extended the IdentitySource enum from 4 basic values to 8 sub-variants matching PowerShell confidence levels:

| Value | Confidence | Description |
|-------|------------|-------------|
| Unknown | 0.0 | No identity source |
| LaunchTracking | 1.0 | Fresh from process launch |
| LaunchTrackingRecovered | 0.95 | Recovered from disk |
| CommandLine | 0.95 | Parsed from args |
| UIAutomationTermControl | 0.95 | TermControl element |
| UIAutomationName | 0.90 | Name property |
| UIAutomationTab | 0.85 | Tab element |
| Title | 0.70 | Window title match |

Added `GetConfidence()` extension method for efficient confidence lookup.

### Task 2: IdentityRegistry and IdentityEntry Models
Created persistence models matching PowerShell JSON format:

```csharp
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
    public string WindowHandle { get; init; } = string.Empty;
    public DateTime LaunchTime { get; init; }
    public string CorrelationId { get; init; } = string.Empty;
}
```

### Task 3: JSON Context Registration
Added AOT-safe serialization support:
- `[JsonSerializable(typeof(IdentityRegistry))]`
- `[JsonSerializable(typeof(IdentityEntry))]`
- `[JsonSerializable(typeof(Dictionary<string, IdentityEntry>))]`

## Commits

| Hash | Description |
|------|-------------|
| 4d14513 | feat(04-01): extend IdentitySource enum with sub-variants and confidence method |
| e2a1903 | feat(04-01): create IdentityRegistry and IdentityEntry models |
| 8d34353 | feat(04-01): register identity types in JSON context |

## Verification Results

- [x] All three files compile without errors
- [x] `dotnet build MatrixShader/src/MatrixShader.Core` succeeds
- [x] IdentitySource has 8 values with distinct confidence scores
- [x] WindowInfo includes Confidence property
- [x] IdentityRegistry/IdentityEntry models match PowerShell JSON format
- [x] JSON context can serialize identity types (AOT-compatible)

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

Ready for 04-02-PLAN.md (Layer 1: Launch Tracking Implementation):
- IdentitySource enum has LaunchTracking and LaunchTrackingRecovered values
- IdentityRegistry/IdentityEntry models ready for persistence
- JSON serialization context registered for AOT-safe file operations
