# Requirements: Matrix Terminal Shader C# Rebuild

**Defined:** 2026-01-25
**Updated:** 2026-01-30 — Added E2E requirements after gap discovery
**Core Value:** The C# version must work exactly like the PowerShell version does today

## v1 Requirements (Phases 1-10)

See archived: `.planning/milestones/v1.0-REQUIREMENTS.md`

All 38 original requirements implemented but NOT VALIDATED on clean system.

## v1.1 Requirements (Phase 11)

Requirements for installer and end-to-end validation.

### End-to-End Installation

- [ ] **E2E-01**: Installer includes all 5 executables (wakeupneo, redpill, bluepill, matrixlite, matrix-monitor)
- [ ] **E2E-02**: Installer includes all shader files in accessible location
- [ ] **E2E-03**: Installed executables can find shader files without user intervention
- [ ] **E2E-04**: Installed executables can find each other (bluepill → matrix-monitor)
- [ ] **E2E-05**: Fresh Windows Sandbox install completes with working Matrix effect
- [ ] **E2E-06**: PATH integration works (or Start Menu shortcuts provided)
- [ ] **E2E-07**: User documentation explains post-install steps

### Path Resolution

- [ ] **PATH-01**: ShaderService finds shaders from installed location (not just Documents)
- [ ] **PATH-02**: TerminalSettingsService creates profiles with correct shader paths
- [ ] **PATH-03**: Bluepill finds matrix-monitor.exe by correct name
- [ ] **PATH-04**: No hardcoded developer paths in production code

### First-Run Experience

- [ ] **FRX-01**: wakeupneo works on fresh Windows Terminal (no prior config)
- [ ] **FRX-02**: Profile creation is verified before launching windows
- [ ] **FRX-03**: Graceful error messages when Windows Terminal not installed

### Build & Distribution

- [ ] **BUILD-01**: Installer can be built without proprietary tools (or tool is documented)
- [ ] **BUILD-02**: Build script is clear and documented
- [ ] **BUILD-03**: Alternative distribution method available (zip, winget, etc.)

## Traceability

| Requirement | Gap | Severity |
|-------------|-----|----------|
| E2E-01 | GAP-E01 | Critical |
| E2E-02 | GAP-E03, GAP-E12 | Critical |
| E2E-03 | GAP-E12 | Critical |
| E2E-04 | GAP-E02 | Important |
| E2E-05 | GAP-E09 | Critical |
| E2E-06 | GAP-E10 | Minor |
| E2E-07 | GAP-E08 | Important |
| PATH-01 | GAP-E03 | Important |
| PATH-02 | GAP-E12 | Critical |
| PATH-03 | GAP-E02 | Important |
| PATH-04 | GAP-E04 | Important |
| FRX-01 | GAP-E06, GAP-E07 | Important |
| FRX-02 | GAP-E07 | Important |
| FRX-03 | GAP-E06 | Important |
| BUILD-01 | GAP-E09 | Critical |
| BUILD-02 | GAP-E14 | Minor |
| BUILD-03 | GAP-E09 | Important |

---
*Requirements defined: 2026-01-25*
*Updated: 2026-01-30 — E2E requirements added for Phase 11*
