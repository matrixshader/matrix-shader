---
phase: 08-cli-applications
plan: 01
subsystem: cli-infrastructure
tags: [cli, ansi, bootstrap, console, quotes]
dependency-graph:
  requires: [07-terminal-integration]
  provides: [cli-bootstrap, console-helper, matrix-quotes]
  affects: [08-02, 08-03]
tech-stack:
  added: []
  patterns: [static-class-utilities, p-invoke-library-import, record-types]
key-files:
  created:
    - MatrixShader/src/MatrixShader.Core/Helpers/ConsoleHelper.cs
    - MatrixShader/src/MatrixShader.Core/Constants/MatrixQuotes.cs
    - MatrixShader/src/MatrixShader.Core/Services/CliBootstrap.cs
  modified: []
decisions:
  - id: "08-01-D1"
    choice: "DiagnosticLogger.Initialize() over non-existent Enable()"
    rationale: "DiagnosticLogger API uses Initialize(debugFlag) pattern"
  - id: "08-01-D2"
    choice: "LibraryImport for P/Invoke declarations"
    rationale: "AOT compatibility, matches project convention from Phase 03"
  - id: "08-01-D3"
    choice: "Static class for CliBootstrap (not DI)"
    rationale: "Matches DiagnosticLogger pattern, CLI entry point simplicity"
metrics:
  duration: 5 min
  completed: 2026-01-29
---

# Phase 08 Plan 01: CLI Bootstrap Infrastructure Summary

Shared CLI bootstrap with Windows Terminal detection, ANSI escape codes, Matrix quotes, and typewriter effects.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| d6c6cc1 | feat | ConsoleHelper for ANSI escape code support |
| 26a43f1 | feat | MatrixQuotes collection for CLI aesthetics |
| 9df3dc5 | feat | CliBootstrap shared CLI initialization service |

## What Was Built

### ConsoleHelper (114 lines)
Static utility class for Windows console ANSI support:
- **EnableAnsiEscapeCodes()**: P/Invoke to kernel32.dll for ENABLE_VIRTUAL_TERMINAL_PROCESSING
- **WriteMatrixGreen/WriteDim/WriteBrightGreen**: ANSI color output helpers
- **ClearScreen**: Console clear with cursor reset
- LibraryImport pattern for AOT compatibility

### MatrixQuotes (39 lines)
Collection of 14 iconic Matrix movie quotes:
- "The Matrix has you..."
- "There is no spoon."
- "Follow the white rabbit."
- etc.
- **GetRandom()**: Returns random quote using Random.Shared
- **All**: Read-only access to complete collection

### CliBootstrap (329 lines)
Shared bootstrap logic for all CLI entry points:
- **InitializeAsync()**: Full CLI initialization
  - Enables ANSI escape codes
  - Initializes DiagnosticLogger
  - Checks Windows Terminal installation
  - Creates Matrix directories if missing
- **IsWindowsTerminalInstalled()**: Checks settings.json existence
- **TryInstallWindowsTerminalAsync()**: winget install with Microsoft Store fallback
- **TypewriterAsync()**: Character-by-character output with configurable delay (150ms default)
- **ArrowKeyMenu()**: Interactive Up/Down/Enter/Escape menu selection
- **ShowRandomQuote()**: Displays random Matrix quote
- **ParseArgs()**: Common CLI options (--help, --debug, --morpheus, --agent-smith)
- **BootstrapResult record**: Success/failure with first-run detection
- **CliOptions record**: Parsed CLI flags

## Key Links

```
CliBootstrap.InitializeAsync()
    ├── ConsoleHelper.EnableAnsiEscapeCodes()
    ├── DiagnosticLogger.Initialize()
    ├── IsWindowsTerminalInstalled() [checks settings.json]
    ├── TryInstallWindowsTerminalAsync() [winget + Store fallback]
    └── EnsureDirectories() [Matrix/ and shaders/]

CliBootstrap.ShowRandomQuote()
    └── MatrixQuotes.GetRandom()
```

## Verification Results

- [x] Build succeeds with no warnings
- [x] ConsoleHelper.EnableAnsiEscapeCodes has P/Invoke declarations
- [x] ConsoleHelper.WriteMatrixGreen and WriteDim helper methods present
- [x] MatrixQuotes has 14 iconic movie quotes
- [x] MatrixQuotes.GetRandom() returns random quote
- [x] CliBootstrap.InitializeAsync() checks for Windows Terminal
- [x] CliBootstrap offers winget install with Microsoft Store fallback
- [x] CliBootstrap.TypewriterAsync() supports cancellation and configurable delay
- [x] CliBootstrap.ArrowKeyMenu() handles Up/Down/Enter/Escape keys
- [x] CliBootstrap.ParseArgs() handles --help, --debug, --morpheus, --agent-smith
- [x] DiagnosticLogger integration for debug output

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DiagnosticLogger.Enable() does not exist**
- **Found during:** Task 3
- **Issue:** Plan specified `DiagnosticLogger.Enable()` but actual API is `Initialize(bool debugFlag)`
- **Fix:** Changed to `DiagnosticLogger.Initialize(debugEnabled)`
- **Files modified:** CliBootstrap.cs
- **Commit:** 9df3dc5

## Next Phase Readiness

- [x] ConsoleHelper ready for use by bluepill, wakeupneo, redpill CLIs
- [x] MatrixQuotes available for theatrical startup messages
- [x] CliBootstrap provides complete initialization for all three CLIs
- [x] ArrowKeyMenu ready for wakeupneo Blue/Red Pill selection
- [x] TypewriterAsync ready for bluepill "There is no spoon..." effect

---
*Plan 08-01 executed: 2026-01-29*
*Duration: 5 minutes*
