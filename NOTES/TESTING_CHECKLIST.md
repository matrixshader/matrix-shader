# Matrix Terminal Shader - Comprehensive Testing Checklist

**Document Version:** 1.0
**Author:** Quality Lead Agent
**Date:** January 7, 2026
**Status:** Active

---

## Purpose

This document provides a comprehensive manual testing checklist for the Matrix Terminal Shader project. Use this checklist before every release to ensure quality and catch regressions.

**Time to Complete:** ~30-45 minutes for full checklist

---

## Quick Reference: Critical Files & Line Numbers

| File | Critical Lines | Issue |
|------|----------------|-------|
| Matrix.hlsl | Line 33 | Division-by-zero risk |
| matrix_tool.ps1 | Lines 78-93 | Regex parse failures |
| matrix_tool.ps1 | Lines 96-103 | No error handling |
| matrix_tool.ps1 | Lines 106-170 | Cursor not restored |
| matrix_tool.ps1 | Lines 148-168 | Unbounded parameters |

---

## Pre-Testing Setup

Before running tests, prepare your environment:

- [ ] Windows Terminal installed and up to date
- [ ] PowerShell 5.1 or 7.x available
- [ ] Fresh copy of Matrix.hlsl in Documents folder
- [ ] Terminal settings.json backed up
- [ ] GPU drivers up to date
- [ ] Screen recording software ready (optional, for bug reports)

---

## 1. Installation & Setup Tests

### 1.1 Fresh Installation

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Copy shader file | Copy Matrix.hlsl to Documents folder | File copied without errors | [ ] |
| Copy controller | Copy matrix_tool.ps1 to Documents folder | File copied without errors | [ ] |
| Configure Terminal | Add shader path to settings.json | Settings saved successfully | [ ] |
| Restart Terminal | Close and reopen Windows Terminal | Terminal starts without errors | [ ] |
| Verify shader loads | Open new tab/window | Matrix rain effect visible | [ ] |

### 1.2 Settings.json Modification

```json
{
    "profiles": {
        "defaults": {
            "experimental.pixelShaderPath": "C:\\Users\\ehome\\Documents\\Matrix.hlsl"
        }
    }
}
```

- [ ] Path uses double backslashes
- [ ] Path is absolute, not relative
- [ ] JSON syntax is valid (no trailing commas)
- [ ] Terminal loads without "invalid shader" error

### 1.3 Controller Startup

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Run controller | Execute `.\matrix_tool.ps1` | TUI displays without errors | [ ] |
| Initial values shown | Check displayed parameters | Values match Matrix.hlsl defines | [ ] |
| Cursor hidden | Look at cursor | Cursor is invisible | [ ] |
| Clean exit | Press 'Q' | Cursor restored, script exits cleanly | [ ] |

---

## 2. PowerShell Controller Tests

### 2.1 Basic Controls

Test each control key:

| Key | Function | Expected Behavior | Pass |
|-----|----------|-------------------|------|
| `s` | Decrease Speed | Speed decreases by 0.1, visual slows | [ ] |
| `S` | Increase Speed | Speed increases by 0.1, visual speeds up | [ ] |
| `l` | Decrease Glow | Glow decreases by 0.2, dimmer effect | [ ] |
| `L` | Increase Glow | Glow increases by 0.2, brighter effect | [ ] |
| `c` | Decrease Scale | Scale decreases by 0.1, larger chars | [ ] |
| `C` | Increase Scale | Scale increases by 0.1, smaller chars | [ ] |
| `w` | Decrease Width | Width decreases by 0.5, narrower cols | [ ] |
| `W` | Increase Width | Width increases by 0.5, wider cols | [ ] |
| `t` | Decrease Trail | Trail decreases by 0.5, longer trails | [ ] |
| `T` | Increase Trail | Trail increases by 0.5, shorter trails | [ ] |
| `d` | Decrease Density | Density decreases by 0.05, fewer cols | [ ] |
| `D` | Increase Density | Density increases by 0.05, more cols | [ ] |
| `Q` | Quit | Script exits, cursor restored | [ ] |

### 2.2 Color Presets

| Key | Preset | Expected Color | Pass |
|-----|--------|----------------|------|
| `1` | Classic Green | RGB(0.0, 1.0, 0.3) - Matrix green | [ ] |
| `2` | Cyberpunk | RGB(1.0, 0.2, 0.8) - Pink/magenta | [ ] |
| `3` | Ocean | RGB(0.2, 0.8, 1.0) - Cyan/blue | [ ] |
| `4` | Fire | RGB(1.0, 0.4, 0.1) - Orange/red | [ ] |
| `5` | Ice | RGB(0.6, 0.9, 1.0) - Light blue | [ ] |
| `6` | Custom (if defined) | User-defined color | [ ] |

### 2.3 Layer Toggles

| Key | Layer | Action | Pass |
|-----|-------|--------|------|
| `7` | Layer 1 (Far) | Toggle on/off, depth visible | [ ] |
| `8` | Layer 2 (Mid) | Toggle on/off, mid-layer visible | [ ] |
| `9` | Layer 3 (Near) | Toggle on/off, foreground visible | [ ] |
| All off | Layers 1-3 | Disable all, no rain visible | [ ] |
| All on | Layers 1-3 | Enable all, full depth effect | [ ] |

### 2.4 Value Persistence

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Change value | Press 'S' multiple times | Speed increases | [ ] |
| Exit controller | Press 'Q' | Script exits cleanly | [ ] |
| Restart controller | Run `.\matrix_tool.ps1` again | Changed speed value persists | [ ] |
| Restart Terminal | Close and reopen Terminal | Effect uses persisted values | [ ] |

### 2.5 Real-time Updates

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Hot reload | Press any adjustment key | Effect updates within ~100ms | [ ] |
| Multiple rapid changes | Press 'S' 5 times quickly | All changes reflected smoothly | [ ] |
| Visual matches display | Check TUI values vs visual | Effect matches displayed values | [ ] |

---

## 3. Error Handling Tests

### 3.1 Missing Files

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Missing shader | Delete Matrix.hlsl, run controller | Graceful error message (no crash) | [ ] |
| Missing template | Corrupt shaderTemplate in ps1 | Graceful error or defaults | [ ] |
| Restore files | Copy files back | Controller resumes normally | [ ] |

### 3.2 Corrupted Files

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Empty shader | Replace Matrix.hlsl with empty file | Error message or defaults applied | [ ] |
| Invalid HLSL | Add syntax error to Matrix.hlsl | Terminal shows shader error | [ ] |
| Missing defines | Remove #define RAIN_SPEED line | Defaults applied, no crash | [ ] |
| Restore files | Copy correct files back | Normal operation resumes | [ ] |

### 3.3 File Permissions

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Read-only shader | Set Matrix.hlsl to read-only | Error message on Save-Shader | [ ] |
| Locked file | Open shader in another program | Error message, no crash | [ ] |
| Restore permissions | Remove read-only, close other program | Normal operation resumes | [ ] |

### 3.4 Cursor Restoration

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Normal exit | Press 'Q' | Cursor visible | [ ] |
| Ctrl+C | Press Ctrl+C during operation | Cursor visible (if try/finally fixed) | [ ] |
| Terminal close | Close Terminal window while running | New Terminal has visible cursor | [ ] |

---

## 4. GPU Compatibility Tests

### 4.1 NVIDIA GPUs

**Test System:** ____________________ (e.g., RTX 3060)
**Driver Version:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Shader loads | Matrix effect visible | [ ] |
| No artifacts | Clean character rendering | [ ] |
| Smooth animation | 60+ FPS, no stuttering | [ ] |
| All layers work | Depth effect visible with 3 layers | [ ] |
| Color accuracy | Colors match presets | [ ] |

### 4.2 AMD GPUs

**Test System:** ____________________ (e.g., RX 6600)
**Driver Version:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Shader loads | Matrix effect visible | [ ] |
| No artifacts | Clean character rendering | [ ] |
| Smooth animation | 60+ FPS, no stuttering | [ ] |
| All layers work | Depth effect visible with 3 layers | [ ] |
| Color accuracy | Colors match presets | [ ] |

### 4.3 Intel GPUs

**Test System:** ____________________ (e.g., Iris Xe)
**Driver Version:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Shader loads | Matrix effect visible | [ ] |
| No artifacts | Clean character rendering | [ ] |
| Acceptable animation | 30+ FPS minimum | [ ] |
| All layers work | Depth effect visible (may reduce for perf) | [ ] |
| Color accuracy | Colors match presets | [ ] |

### 4.4 Multi-GPU Systems

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Primary GPU | Run Terminal on primary display | Shader works | [ ] |
| Secondary GPU | Move Terminal to secondary display | Shader works (if applicable) | [ ] |

---

## 5. PowerShell Version Compatibility

### 5.1 PowerShell 5.1 (Windows Default)

**Test Command:** `powershell -version`
**Version:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Script starts | No syntax errors | [ ] |
| TUI displays correctly | All characters render | [ ] |
| Keyboard input works | All keys respond | [ ] |
| File operations work | Shader saves correctly | [ ] |
| Exit works | Clean exit with cursor | [ ] |

### 5.2 PowerShell 7.x

**Test Command:** `pwsh -version`
**Version:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Script starts | No syntax errors | [ ] |
| TUI displays correctly | All characters render | [ ] |
| Keyboard input works | All keys respond | [ ] |
| File operations work | Shader saves correctly | [ ] |
| Exit works | Clean exit with cursor | [ ] |

### 5.3 PowerShell Execution Policy

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Restricted policy | Set-ExecutionPolicy Restricted | Script blocked with clear message | [ ] |
| RemoteSigned | Set-ExecutionPolicy RemoteSigned | Script runs if local | [ ] |
| Bypass | pwsh -ExecutionPolicy Bypass -File | Script runs | [ ] |

---

## 6. Windows Version Compatibility

### 6.1 Windows 11

**Version:** ____________________ (e.g., 23H2)
**Build:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Terminal shader support | Shader loads | [ ] |
| Hot reload works | Changes apply in ~100ms | [ ] |
| Modern Terminal features | All features work | [ ] |

### 6.2 Windows 10

**Version:** ____________________ (e.g., 22H2)
**Build:** ____________________

| Test | Expected Result | Pass |
|------|-----------------|------|
| Terminal from Store | Shader loads | [ ] |
| Hot reload works | Changes apply in ~100ms | [ ] |
| All features work | No compatibility issues | [ ] |

---

## 7. Performance Benchmarks

### 7.1 Startup Performance

| Metric | Target | Actual | Pass |
|--------|--------|--------|------|
| Controller startup | <2 seconds | ______ | [ ] |
| First shader load | <500ms | ______ | [ ] |
| Hot reload latency | <100ms | ______ | [ ] |

### 7.2 Runtime Performance

| Resolution | Layers | Target FPS | Actual FPS | Pass |
|------------|--------|------------|------------|------|
| 1080p | 3 | 60+ | ______ | [ ] |
| 1080p | 1 | 60+ | ______ | [ ] |
| 1440p | 3 | 60+ | ______ | [ ] |
| 4K | 3 | 30+ | ______ | [ ] |
| 4K | 1 | 60+ | ______ | [ ] |

### 7.3 Resource Usage

| Metric | Target | Actual | Pass |
|--------|--------|--------|------|
| Controller memory | <50MB | ______ | [ ] |
| Controller CPU (idle) | <5% | ______ | [ ] |
| GPU memory | <100MB | ______ | [ ] |

### 7.4 Stress Tests

| Test | Duration | Expected Result | Pass |
|------|----------|-----------------|------|
| Long run | 30 min | No memory leak, stable FPS | [ ] |
| Rapid toggles | 100 keypresses | No lag, all changes apply | [ ] |
| Window resize | Multiple resizes | Shader adapts, no artifacts | [ ] |

---

## 8. Edge Cases & Regression Tests

### 8.1 Extreme Values

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Speed = 0.1 (min) | Decrease speed to minimum | Very slow rain, no freeze | [ ] |
| Speed = 5.0 (max) | Increase speed to maximum | Fast rain, no visual break | [ ] |
| Glow = 0.0 (min) | Decrease glow to minimum | Rain invisible but no crash | [ ] |
| Glow = 10.0 (max) | Increase glow to maximum | Very bright, no artifacts | [ ] |
| Density = 0.1 (min) | Decrease density to minimum | Very few columns | [ ] |
| Density = 1.0 (max) | Increase density to maximum | All columns active | [ ] |
| Trail = 1.0 (min) | Decrease trail to minimum | Very long trails | [ ] |
| Trail = 30.0 (max) | Increase trail to maximum | Short, crisp trails | [ ] |

### 8.2 Division-by-Zero Test (Bug #1)

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| FONT_SCALE = 0.0 | Manually edit shader, set FONT_SCALE 0.0 | No crash (if fix applied) | [ ] |
| CHAR_WIDTH = 0.0 | Manually edit shader, set CHAR_WIDTH 0.0 | No crash (if fix applied) | [ ] |

### 8.3 Boundary Conditions

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Very small window | Resize Terminal to ~200x100 px | Shader scales, no crash | [ ] |
| Very large window | Maximize on 4K display | Shader scales, acceptable perf | [ ] |
| Ultrawide aspect | Resize to 21:9 aspect ratio | No horizontal artifacts | [ ] |
| Portrait orientation | Resize taller than wide | Shader adapts | [ ] |

### 8.4 Special Characters in Path

| Test | Steps | Expected Result | Pass |
|------|-------|-----------------|------|
| Space in path | Move shader to "My Documents" | Still works | [ ] |
| Unicode in path | Move to folder with unicode name | Still works (or clear error) | [ ] |
| Long path | Move to deeply nested folder | Still works (or clear error) | [ ] |

### 8.5 Regression: Previous Bug Fixes

| Bug | Line | Test | Pass |
|-----|------|------|------|
| Div-by-zero | Matrix.hlsl:33 | FONT_SCALE=0 doesn't crash | [ ] |
| No error handling | ps1:96-103 | Read-only file shows error | [ ] |
| Regex failures | ps1:78-93 | Corrupted file uses defaults | [ ] |
| Unbounded params | ps1:148-168 | Values clamp at limits | [ ] |
| Cursor restore | ps1:106-170 | Ctrl+C restores cursor | [ ] |

---

## 9. Documentation Verification

### 9.1 README.md

| Check | Present | Accurate | Pass |
|-------|---------|----------|------|
| Project description | [ ] | [ ] | [ ] |
| Prerequisites listed | [ ] | [ ] | [ ] |
| Installation steps | [ ] | [ ] | [ ] |
| Configuration example | [ ] | [ ] | [ ] |
| Usage instructions | [ ] | [ ] | [ ] |
| Keyboard controls | [ ] | [ ] | [ ] |
| Troubleshooting section | [ ] | [ ] | [ ] |
| Screenshots/GIFs | [ ] | [ ] | [ ] |

### 9.2 Code Comments

| File | Adequate Comments | Pass |
|------|-------------------|------|
| Matrix.hlsl header | Explains shader purpose | [ ] |
| Matrix.hlsl DrawLayer | Explains algorithm | [ ] |
| matrix_tool.ps1 header | Explains controller purpose | [ ] |
| matrix_tool.ps1 functions | Each function documented | [ ] |

### 9.3 Error Messages

| Scenario | Message Clear? | Pass |
|----------|----------------|------|
| File not found | Tells user which file | [ ] |
| Permission denied | Suggests fix | [ ] |
| Shader error | Points to log/docs | [ ] |

---

## Test Execution Log

### Test Session Details

| Field | Value |
|-------|-------|
| Tester | __________________ |
| Date | __________________ |
| Duration | __________________ |
| Build/Version | __________________ |
| System | __________________ |
| Overall Result | PASS / FAIL |

### Issues Found

| # | Section | Description | Severity | Bug Filed? |
|---|---------|-------------|----------|------------|
| 1 | | | | [ ] |
| 2 | | | | [ ] |
| 3 | | | | [ ] |
| 4 | | | | [ ] |
| 5 | | | | [ ] |

### Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Tester | | | |
| Reviewer | | | |

---

## Appendix A: Quick Smoke Test (5 min)

For rapid pre-commit testing, run only these:

1. [ ] Script starts without errors
2. [ ] 'S' key increases speed
3. [ ] '1' key applies green preset
4. [ ] '7' key toggles layer
5. [ ] 'Q' exits with cursor visible
6. [ ] Rerun: values persisted

If all pass, safe to commit. Full checklist required before release.

---

## Appendix B: Automated Test Commands

```powershell
# Run automated portion of tests (when available)
Invoke-Pester -Path .\tests\ -Output Detailed

# Check PowerShell syntax
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "matrix_tool.ps1", [ref]$null, [ref]$errors
) | Out-Null
if (-not $errors) { Write-Host "Syntax OK" -ForegroundColor Green }

# Validate HLSL defines
$hlsl = Get-Content "Matrix.hlsl" -Raw
@("RAIN_SPEED", "GLOW_STRENGTH", "RAIN_DENSITY") | ForEach-Object {
    if ($hlsl -match "#define $_") {
        Write-Host "$_ found" -ForegroundColor Green
    } else {
        Write-Host "$_ MISSING" -ForegroundColor Red
    }
}
```

---

## Appendix C: Bug Report Template

When tests fail, use this template:

```markdown
## Bug Report

**Test Section:** [e.g., 2.1 Basic Controls]
**Test Case:** [e.g., 'S' key increases speed]
**Expected:** Speed increases by 0.1
**Actual:** [What actually happened]

**Environment:**
- Windows: [Version]
- Terminal: [Version]
- PowerShell: [Version]
- GPU: [Model]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Logs/Screenshots:**
[Attach if applicable]

**Severity:** Critical / High / Medium / Low
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-07 | Quality Lead Agent | Initial comprehensive version |

---

*Use this checklist before every release. Document any deviations or skipped tests.*
