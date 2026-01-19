# Matrix Terminal Shader - Quality Gates & Standards

**Document Version:** 1.0
**Author:** Quality Lead Agent
**Date:** January 7, 2026
**Status:** Active

---

## Table of Contents

1. [Quality Philosophy](#1-quality-philosophy)
2. [Pre-Release Checklist (MVP)](#2-pre-release-checklist-mvp)
3. [GUI App Quality Requirements](#3-gui-app-quality-requirements)
4. [Test Strategy](#4-test-strategy)
5. [CI/CD Pipeline Design](#5-cicd-pipeline-design)
6. [Code Review Process](#6-code-review-process)
7. [Performance Requirements](#7-performance-requirements)
8. [Compatibility Matrix](#8-compatibility-matrix)
9. [Hotfix/Rollback Process](#9-hotfixrollback-process)
10. [User Feedback Loop](#10-user-feedback-loop)
11. [Metrics & Success Criteria](#11-metrics--success-criteria)
12. [Appendix: Tools & Automation](#12-appendix-tools--automation)

---

## 1. Quality Philosophy

### Core Principle: Ship Fast, Ship Safe

Quality is an **enabler**, not a blocker. Our philosophy balances speed with safety:

```
Quality = (User Value Delivered) / (Time + Risk)
```

### "Good Enough" is Context-Dependent

| Phase | Quality Bar | Time Investment | Rationale |
|-------|-------------|-----------------|-----------|
| **MVP (v0.1)** | Functional + Safe | 25% on quality | Get it out, learn fast |
| **v0.5** | Stable + Documented | 35% on quality | Growing user base |
| **v1.0** | Polished + Tested | 50% on quality | Production-grade |

### Speed vs Quality Balance

**When to prioritize speed:**
- Initial MVP validation
- Experimental features behind flags
- Internal/alpha releases
- Responding to critical user feedback

**When to prioritize quality:**
- Public releases
- Anything touching user files/settings
- Security-related changes
- Features with high visibility

### Non-Negotiables (Never Ship Without These)

Regardless of phase, these are **absolute blockers**:

| Non-Negotiable | Rationale |
|----------------|-----------|
| No data loss | User's terminal settings are precious |
| No crashes | Crashes = uninstalls |
| No security holes | Even shaders can expose system info |
| Rollback capability | Must be able to undo any change |
| Clear documentation | Users need to know how to install/use |

### The 25% Rule for MVP

For MVP, spend 25% of development time on quality:
- 10% - Error handling and edge cases
- 8% - Testing (manual for MVP)
- 5% - Documentation
- 2% - Code review

---

## 2. Pre-Release Checklist (MVP)

### The 5 CRITICAL Bugs to Fix Before Any Release

These are **blockers** - do not release until all are fixed:

#### Bug 1: Division-by-Zero Risk
- **File:** `Matrix.hlsl:33`
- **Severity:** CRITICAL
- **Issue:** If `FONT_SCALE` is 0.0, `baseCharSize` becomes `float2(0.0, 0.0)`, causing shader crash
- **Current Code:**
  ```hlsl
  float2 baseCharSize = float2(CHAR_WIDTH, 20.0) * FONT_SCALE;
  float2 grid_dims = Resolution / baseCharSize;  // Division by zero!
  ```
- **Required Fix:**
  ```hlsl
  float2 baseCharSize = max(float2(CHAR_WIDTH, 20.0) * FONT_SCALE, float2(0.1, 0.1));
  ```
- **Test:** Set FONT_SCALE to 0.0 and verify no crash

#### Bug 2: No Error Handling for File Operations
- **File:** `matrix_tool.ps1:96-103`
- **Severity:** CRITICAL
- **Issue:** No try-catch around file I/O. Script crashes on locked files, full disk, or permission denied
- **Current Code:**
  ```powershell
  function Save-Shader {
      $out = $shaderTemplate -replace "{R}",$s.R ...
      Set-Content -Path $shaderPath -Value $out
      (Get-Item $shaderPath).LastWriteTime = Get-Date
  }
  ```
- **Required Fix:**
  ```powershell
  function Save-Shader {
      try {
          $out = $shaderTemplate -replace "{R}",$s.R ...
          Set-Content -Path $shaderPath -Value $out -ErrorAction Stop
          (Get-Item $shaderPath).LastWriteTime = Get-Date
      } catch {
          Write-Host "ERROR: Could not save shader: $_" -ForegroundColor Red
          Start-Sleep -Seconds 2
      }
  }
  ```
- **Test:** Make shader file read-only, verify graceful error message

#### Bug 3: Regex Parse Failures
- **File:** `matrix_tool.ps1:78-93`
- **Severity:** CRITICAL
- **Issue:** If shader file is corrupted, regex matches return empty strings, creating invalid HLSL
- **Example of corrupt output:**
  ```hlsl
  #define RAIN_SPEED   // Missing value!
  ```
- **Required Fix:**
  ```powershell
  $speedMatch = [regex]::Match($c, "#define RAIN_SPEED\s+([\d\.]+)").Groups[1].Value
  $s.Speed = if ($speedMatch) { $speedMatch } else { "1.0" }  # Default fallback
  ```
- **Test:** Corrupt the HLSL file, verify defaults are applied

#### Bug 4: Unbounded Parameter Input
- **File:** `matrix_tool.ps1:148-168`
- **Severity:** HIGH
- **Issue:** Parameters can be increased indefinitely, causing GPU hangs or visual artifacts
- **Current Code:**
  ```powershell
  'L' { $s.Glow = "{0:N1}" -f ([float]$s.Glow + 0.2) }  # No upper bound!
  ```
- **Required Fix:**
  ```powershell
  'L' {
      $newGlow = [float]$s.Glow + 0.2
      if ($newGlow -le 10.0) {
          $s.Glow = "{0:N1}" -f $newGlow
          Save-Shader
      }
  }
  ```
- **Bounds to implement:**
  | Parameter | Min | Max | Step |
  |-----------|-----|-----|------|
  | Speed | 0.1 | 5.0 | 0.1 |
  | Glow | 0.0 | 10.0 | 0.2 |
  | Trail | 1.0 | 30.0 | 0.5 |
  | Density | 0.1 | 1.0 | 0.05 |
  | Width | 5.0 | 30.0 | 0.5 |
  | Scale | 0.5 | 3.0 | 0.1 |

#### Bug 5: Cursor Not Restored on Error
- **File:** `matrix_tool.ps1:106-170`
- **Severity:** HIGH
- **Issue:** Cursor hidden at line 106 but only restored on clean exit at line 170. Crashes leave cursor invisible.
- **Current Code:**
  ```powershell
  [System.Console]::CursorVisible = $false  # Line 106
  while ($true) { ... }
  [System.Console]::CursorVisible = $true   # Line 170 - only on clean exit!
  ```
- **Required Fix:**
  ```powershell
  try {
      [System.Console]::CursorVisible = $false
      while ($true) {
          # ... main loop ...
      }
  } finally {
      [System.Console]::CursorVisible = $true  # Always executed!
  }
  ```
- **Test:** Ctrl+C during execution, verify cursor is visible

### MVP Release Checklist

- [ ] All 5 critical bugs fixed and tested
- [ ] README.md exists with installation instructions
- [ ] LICENSE file present (MIT recommended)
- [ ] Tested on at least 1 NVIDIA and 1 AMD GPU
- [ ] Tested on Windows 10 and Windows 11
- [ ] Tested on PowerShell 5.1 and 7.x
- [ ] Manual sanity test of all keyboard controls
- [ ] No console errors during normal operation
- [ ] Clean uninstall documented (remove shader path from settings.json)

---

## 3. GUI App Quality Requirements

### When to Build the GUI

The GUI configurator should be built when:
1. PowerShell TUI limitations become a barrier (accessibility, discoverability)
2. User feedback indicates demand for visual configuration
3. MVP has proven the concept works
4. Resources are available for ongoing maintenance

**Recommended timing:** After v0.5, targeting v1.0

### GUI Quality Bar

| Category | MVP (v0.5) | Production (v1.0) |
|----------|------------|-------------------|
| Installation | Run from folder | MSI/MSIX installer |
| Error handling | Try-catch all operations | Full error reporting |
| Accessibility | Basic keyboard nav | WCAG 2.1 AA compliance |
| Performance | <1s startup | <500ms startup |
| Testing | Manual tests | Automated UI tests |
| Telemetry | None | Opt-in crash reports |

### GUI-Specific Requirements

1. **Settings Validation**
   - All values validated before saving
   - Preview before apply
   - Undo last change capability

2. **File Handling**
   - Backup settings.json before modification
   - Detect and warn about locked files
   - Handle multiple Terminal installations

3. **Error Recovery**
   - "Reset to defaults" button
   - Import/export configuration
   - Automatic backup on crash

---

## 4. Test Strategy

### Testing Pyramid

```
                /\
               /  \  E2E Tests (5%)
              /----\  - Full installation test
             /      \ - Complete user workflow
            /--------\  Integration Tests (15%)
           /          \ - PowerShell + Shader interaction
          /            \ - Settings.json modification
         /--------------\  Unit Tests (30%)
        /                \ - Parameter validation
       /                  \ - Regex parsing
      /--------------------\  Manual Tests (50% for MVP)
     /                      \ - Visual verification
    /                        \ - Keyboard controls
   /--------------------------\
```

### MVP: Manual Test Focus

For MVP, rely on structured manual testing:

**Pre-Release Manual Tests:**
1. Fresh installation on clean system
2. All keyboard controls respond
3. All color presets work
4. All layer toggles work
5. Values persist after script restart
6. Terminal text remains readable
7. No errors in PowerShell console
8. Ctrl+C exits cleanly with cursor restored

**Time Investment:** ~30 minutes before each release

### v1.0: Automated Test Suite

**Unit Tests (Pester for PowerShell):**
```powershell
Describe "Parameter Validation" {
    It "Clamps Speed to valid range" {
        $result = Clamp-Speed 99.0
        $result | Should -BeLessOrEqual 5.0
    }

    It "Handles missing shader file gracefully" {
        { Load-ShaderValues "nonexistent.hlsl" } | Should -Not -Throw
    }
}
```

**Integration Tests:**
```powershell
Describe "Shader Hot-Reload" {
    It "Updates shader file within 100ms of Save-Shader" {
        $before = (Get-Item $shaderPath).LastWriteTime
        Save-Shader
        $after = (Get-Item $shaderPath).LastWriteTime
        ($after - $before).TotalMilliseconds | Should -BeGreaterThan 0
    }
}
```

**E2E Test (Manual with checklist):**
- See TESTING_CHECKLIST.md for comprehensive manual test suite

---

## 5. CI/CD Pipeline Design

### Phase 1: Manual (MVP)

**Current Process:**
1. Developer tests locally
2. Developer commits to main branch
3. Manual tag for releases (e.g., `v0.1.0`)
4. Manual upload to GitHub releases

**Checklist before commit:**
- [ ] All 5 critical bugs verified fixed
- [ ] Manual tests pass
- [ ] README updated
- [ ] Version number bumped

### Phase 2: GitHub Actions (v0.5)

**Workflow: `.github/workflows/ci.yml`**

```yaml
name: Matrix Shader CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [created]

jobs:
  validate:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate HLSL Syntax
        shell: pwsh
        run: |
          # Use fxc.exe from Windows SDK for syntax validation
          $fxc = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\fxc.exe"
          if (Test-Path $fxc) {
            & $fxc /T ps_4_0 /E main Matrix.hlsl /Fo NUL 2>&1
            if ($LASTEXITCODE -ne 0) { exit 1 }
          } else {
            Write-Warning "fxc.exe not found, skipping shader validation"
          }

      - name: Run PowerShell Lint
        shell: pwsh
        run: |
          Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          $results = Invoke-ScriptAnalyzer -Path .\matrix_tool.ps1 -Severity Error
          if ($results) {
            $results | Format-Table -AutoSize
            exit 1
          }

      - name: Run Pester Tests
        shell: pwsh
        run: |
          Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0
          Invoke-Pester -Path .\tests\ -CI

  package:
    needs: validate
    if: github.event_name == 'release'
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create Release Package
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Path release -Force
          Copy-Item Matrix.hlsl release/
          Copy-Item matrix_tool.ps1 release/
          Copy-Item README.md release/
          Copy-Item LICENSE release/
          Compress-Archive -Path release/* -DestinationPath MatrixShader-${{ github.ref_name }}.zip

      - name: Upload Release Asset
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          upload_url: ${{ github.event.release.upload_url }}
          asset_path: ./MatrixShader-${{ github.ref_name }}.zip
          asset_name: MatrixShader-${{ github.ref_name }}.zip
          asset_content_type: application/zip
```

### Phase 3: Full Pipeline (v1.0+)

Additional capabilities:
- Automated changelog generation
- Version bumping
- Multi-platform testing (Windows 10, 11)
- GPU compatibility tests (if GitHub-hosted GPU runners available)
- Automated security scanning
- Code coverage requirements (minimum 60%)

---

## 6. Code Review Process

### AI-Assisted Review

Use Claude or similar AI for initial review, but human approval required for:
- Any changes to file I/O
- Any changes to settings.json modification
- Security-related changes
- Public API changes

### Confidence Thresholds

| AI Confidence | Action Required |
|---------------|-----------------|
| 95%+ | Auto-approve (style, formatting) |
| 80-95% | Quick human scan |
| 60-80% | Full human review |
| <60% | Pair review with explanation |

### Review Checklist

**Code Reviewer must verify:**
- [ ] No new instances of 5 critical bug patterns
- [ ] Error handling on all I/O operations
- [ ] Input validation on user-controlled values
- [ ] Cursor restoration in try/finally
- [ ] No hardcoded paths (use environment variables)
- [ ] Comments on non-obvious logic
- [ ] Version updated if public-facing change

### Pre-Merge Requirements

| Branch Type | Requirements |
|-------------|--------------|
| main | 1 human approval + AI review + all tests pass |
| feature/* | AI review + manual test |
| hotfix/* | 1 human approval + regression test |

---

## 7. Performance Requirements

### Shader Performance Targets

| Metric | Target | Maximum | Measurement |
|--------|--------|---------|-------------|
| Frame time impact | <2ms at 1080p | <5ms | GPU profiler |
| VRAM usage | <50MB | <100MB | Task Manager |
| Startup time | <100ms | <500ms | Stopwatch |

### Performance by Resolution

| Resolution | Target FPS Impact | Notes |
|------------|-------------------|-------|
| 1080p (1920x1080) | <5% drop | Primary target |
| 1440p (2560x1440) | <10% drop | Well supported |
| 4K (3840x2160) | <15% drop | May need reduced layers |
| Ultrawide (3440x1440) | <10% drop | Test horizontal scaling |

### PowerShell Controller Targets

| Metric | Target | Maximum |
|--------|--------|---------|
| Input latency | <50ms | <100ms |
| File write time | <20ms | <50ms |
| Memory usage | <30MB | <50MB |
| CPU usage (idle) | <1% | <5% |

### Performance Testing Commands

```powershell
# Measure file write latency
Measure-Command { Save-Shader } | Select-Object TotalMilliseconds

# Check memory usage
Get-Process -Name pwsh | Select-Object WorkingSet64

# Monitor CPU during idle
Get-Counter '\Process(pwsh)\% Processor Time' -Continuous
```

---

## 8. Compatibility Matrix

### Operating System Support

| OS Version | Support Level | Notes |
|------------|---------------|-------|
| Windows 11 23H2+ | Full | Primary development target |
| Windows 11 21H2-22H2 | Full | Tested |
| Windows 10 22H2 | Full | Tested |
| Windows 10 21H2 | Supported | May require updates |
| Windows 10 <21H2 | Best Effort | Not actively tested |
| Windows Server 2022 | Untested | Should work |
| macOS/Linux | Not Supported | Windows Terminal only |

### Windows Terminal Versions

| Version | Support Level | Notes |
|---------|---------------|-------|
| 1.19+ (2024) | Full | Shader hot-reload works |
| 1.16-1.18 | Full | Tested |
| 1.12-1.15 | Supported | May have slower reload |
| <1.12 | Not Supported | Shader feature too old |

### PowerShell Versions

| Version | Support Level | Notes |
|---------|---------------|-------|
| PowerShell 7.4+ | Full | Recommended |
| PowerShell 7.0-7.3 | Full | Tested |
| PowerShell 5.1 | Full | Windows default |
| PowerShell Core 6.x | Untested | Should work |

### GPU Vendor Compatibility

| Vendor | Support Level | Known Issues |
|--------|---------------|--------------|
| NVIDIA (GTX 10xx+) | Full | None |
| NVIDIA (GTX 9xx) | Supported | Test thoroughly |
| AMD (RX 5000+) | Full | None |
| AMD (RX 400-500) | Supported | Driver-dependent |
| Intel (Iris Xe) | Full | None |
| Intel (UHD 600+) | Supported | May be slower |
| Intel (HD 4000-6000) | Best Effort | Performance concerns |

### Comprehensive Testing Matrix

**Minimum required testing before release:**

| | Win11 + NVIDIA | Win11 + AMD | Win10 + Intel | Win10 + NVIDIA |
|---|:---:|:---:|:---:|:---:|
| **PS 5.1** | MUST | SHOULD | SHOULD | COULD |
| **PS 7.4** | MUST | MUST | SHOULD | COULD |

**Legend:**
- MUST = Required for release
- SHOULD = Should test if time permits
- COULD = Nice to have

---

## 9. Hotfix/Rollback Process

### Hotfix Triggers

A hotfix is warranted when:
1. **Crash on common scenario** - >1% users affected
2. **Data loss** - Any user settings corrupted
3. **Security vulnerability** - Any severity
4. **Blocking regression** - Feature worked before, now broken

### Hotfix Timeline

| Severity | Response Time | Fix Target | Communication |
|----------|---------------|------------|---------------|
| Critical (crash/security) | 4 hours | 24 hours | Immediate disclosure |
| High (data loss) | 12 hours | 48 hours | Same-day notice |
| Medium (major bug) | 24 hours | 1 week | Changelog note |
| Low (minor issue) | 48 hours | Next release | Changelog note |

### Rollback Procedure

**For Users:**
1. Delete `Matrix.hlsl` from Documents
2. Remove `experimental.pixelShaderPath` from Terminal settings.json
3. Restart Windows Terminal
4. Download previous version from GitHub releases
5. Follow installation instructions

**For Developers:**
```bash
# Revert to previous release
git checkout v0.x.y
git tag v0.x.z-rollback
git push origin v0.x.z-rollback

# Create GitHub release from tag
# Notify users via GitHub issue
```

### Communication Templates

**Critical Issue Template:**
```markdown
## Critical Issue Detected in vX.Y.Z

**Impact:** [Description of impact]
**Affected:** [Who is affected]
**Workaround:** [Temporary fix if available]

We are working on a fix. ETA: [Time]

To rollback:
1. [Steps]
```

---

## 10. User Feedback Loop

### Feedback Channels

| Channel | Response Time | Purpose |
|---------|---------------|---------|
| GitHub Issues | 24-48 hours | Bug reports, feature requests |
| GitHub Discussions | 48-72 hours | Q&A, ideas |
| Reddit (if applicable) | Best effort | Community feedback |
| Email (if provided) | 48-72 hours | Private reports |

### Issue Triage Process

**Triage Labels:**
- `bug` - Something isn't working
- `enhancement` - New feature request
- `documentation` - Docs improvement needed
- `duplicate` - Already reported
- `wontfix` - Out of scope
- `good-first-issue` - Good for contributors

### Severity Classification

| Severity | Criteria | Response |
|----------|----------|----------|
| **S1 - Critical** | Crash, data loss, security | Hotfix ASAP |
| **S2 - High** | Major feature broken | Fix in next release |
| **S3 - Medium** | Minor feature broken | Prioritize for next release |
| **S4 - Low** | Cosmetic, edge case | Backlog |

### Bug Report Template

```markdown
## Bug Report

**Environment:**
- Windows Version: [e.g., Windows 11 23H2]
- Terminal Version: [e.g., 1.19.0]
- PowerShell Version: [e.g., 7.4.0]
- GPU: [e.g., NVIDIA RTX 3060]

**Description:**
[Clear description of the bug]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Screenshots/Logs:**
[If applicable]
```

### Feature Request Evaluation

| Criteria | Weight | Description |
|----------|--------|-------------|
| User demand | 30% | How many users want this? |
| Implementation effort | 25% | How hard to build? |
| Maintenance burden | 20% | How hard to maintain? |
| Strategic fit | 15% | Does it fit our vision? |
| Risk | 10% | What could go wrong? |

**Scoring:**
- 0-3: Reject or defer indefinitely
- 4-6: Consider for future release
- 7-8: Prioritize for next release
- 9-10: Implement immediately

---

## 11. Metrics & Success Criteria

### Key Metrics

| Metric | MVP Target | v1.0 Target | How to Measure |
|--------|------------|-------------|----------------|
| GitHub Stars | 50 | 500 | GitHub UI |
| Downloads | 100 | 1000 | GitHub release stats |
| Open Issues | <10 | <20 | GitHub UI |
| Issue Response Time | <48h | <24h | GitHub labels + dates |
| Critical Bugs | 0 | 0 | Issue labels |
| Test Coverage | N/A | 60% | Pester coverage |

### Quality Indicators

| Indicator | Green | Yellow | Red |
|-----------|-------|--------|-----|
| Open critical bugs | 0 | 1 | 2+ |
| Issue close rate | >80%/month | 50-80%/month | <50%/month |
| User-reported crashes | 0 | 1-2/month | 3+/month |
| Time to first response | <24h avg | 24-48h avg | >48h avg |

### Success Criteria by Phase

**MVP Success:**
- [ ] 25+ GitHub stars in first month
- [ ] 0 critical bugs reported after release
- [ ] 50+ downloads
- [ ] Positive feedback on r/windowsterminal (if posted)

**v0.5 Success:**
- [ ] 100+ GitHub stars
- [ ] <5 open issues at any time
- [ ] Active user discussions
- [ ] At least 1 external contribution

**v1.0 Success:**
- [ ] 500+ GitHub stars
- [ ] Featured in Windows Terminal showcase
- [ ] 60% test coverage
- [ ] GUI app available

---

## 12. Appendix: Tools & Automation

### Pre-Commit Hook Script

Save as `.git/hooks/pre-commit` (make executable):

```bash
#!/bin/bash
echo "Running pre-commit checks..."

# Check PowerShell syntax
pwsh -Command "
    \$errors = \$null
    [System.Management.Automation.Language.Parser]::ParseFile(
        'matrix_tool.ps1',
        [ref]\$null,
        [ref]\$errors
    ) | Out-Null
    if (\$errors) {
        Write-Error 'PowerShell syntax errors found'
        \$errors | ForEach-Object { Write-Error \$_.Message }
        exit 1
    }
    Write-Host 'PowerShell syntax OK'
"

# Check for console.log or debug statements
if grep -rn "Write-Debug\|Write-Verbose" matrix_tool.ps1; then
    echo "Warning: Debug statements found (may be intentional)"
fi

# Ensure version is updated
if git diff --cached --name-only | grep -q "matrix_tool.ps1"; then
    echo "Reminder: Did you update the version number?"
fi

echo "Pre-commit checks passed!"
```

### Release Packager Script

Save as `scripts/package-release.ps1`:

```powershell
<#
.SYNOPSIS
    Package Matrix Shader for release

.PARAMETER Version
    Version number (e.g., 0.1.0)

.EXAMPLE
    .\package-release.ps1 -Version 0.1.0
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Validate version format
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid version format. Use semantic versioning (e.g., 0.1.0)"
}

$releaseDir = "release-$Version"
$zipName = "MatrixShader-v$Version.zip"

Write-Host "Creating release package for v$Version..." -ForegroundColor Cyan

# Create release directory
if (Test-Path $releaseDir) {
    Remove-Item $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null

# Copy files
$files = @(
    "Matrix.hlsl",
    "matrix_tool.ps1",
    "README.md",
    "LICENSE"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Copy-Item $file $releaseDir/
        Write-Host "  Copied: $file" -ForegroundColor Green
    } else {
        Write-Warning "  Missing: $file"
    }
}

# Create version file
"v$Version - $(Get-Date -Format 'yyyy-MM-dd')" | Out-File "$releaseDir/VERSION.txt"

# Create zip
if (Test-Path $zipName) {
    Remove-Item $zipName
}
Compress-Archive -Path "$releaseDir/*" -DestinationPath $zipName
Write-Host "Created: $zipName" -ForegroundColor Green

# Cleanup
Remove-Item $releaseDir -Recurse -Force

# Calculate checksum
$hash = (Get-FileHash $zipName -Algorithm SHA256).Hash
Write-Host "SHA256: $hash" -ForegroundColor Yellow
$hash | Out-File "$zipName.sha256"

Write-Host "`nRelease package ready!" -ForegroundColor Green
Write-Host "1. Create GitHub release for v$Version"
Write-Host "2. Upload $zipName"
Write-Host "3. Paste SHA256 in release notes"
```

### Quick Test Script

Save as `scripts/quick-test.ps1`:

```powershell
<#
.SYNOPSIS
    Run quick sanity tests before commit
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Matrix Shader Quick Test ===" -ForegroundColor Cyan

# Test 1: PowerShell syntax
Write-Host "`n[1/5] Checking PowerShell syntax..." -NoNewline
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "matrix_tool.ps1",
    [ref]$null,
    [ref]$errors
) | Out-Null
if ($errors) {
    Write-Host " FAIL" -ForegroundColor Red
    $errors | ForEach-Object { Write-Error $_.Message }
    exit 1
}
Write-Host " PASS" -ForegroundColor Green

# Test 2: HLSL file exists
Write-Host "[2/5] Checking HLSL file exists..." -NoNewline
if (Test-Path "Matrix.hlsl") {
    Write-Host " PASS" -ForegroundColor Green
} else {
    Write-Host " FAIL" -ForegroundColor Red
    exit 1
}

# Test 3: Required defines present
Write-Host "[3/5] Checking HLSL defines..." -NoNewline
$hlsl = Get-Content "Matrix.hlsl" -Raw
$requiredDefines = @("RAIN_SPEED", "GLOW_STRENGTH", "RAIN_DENSITY", "TRAIL_POWER")
$missing = $requiredDefines | Where-Object { $hlsl -notmatch "#define $_" }
if ($missing) {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "Missing defines: $($missing -join ', ')"
    exit 1
}
Write-Host " PASS" -ForegroundColor Green

# Test 4: No debug output
Write-Host "[4/5] Checking for debug statements..." -NoNewline
$ps1 = Get-Content "matrix_tool.ps1" -Raw
if ($ps1 -match "Write-Debug") {
    Write-Host " WARN (Write-Debug found)" -ForegroundColor Yellow
} else {
    Write-Host " PASS" -ForegroundColor Green
}

# Test 5: README exists
Write-Host "[5/5] Checking documentation..." -NoNewline
if (Test-Path "README.md") {
    Write-Host " PASS" -ForegroundColor Green
} else {
    Write-Host " WARN (README.md missing)" -ForegroundColor Yellow
}

Write-Host "`n=== All critical checks passed ===" -ForegroundColor Green
```

### Quality Gates Summary Table

| Gate | When | Pass Criteria | Block Release? |
|------|------|---------------|----------------|
| Syntax Check | Pre-commit | No parse errors | Yes |
| Lint Check | Pre-commit | No errors (warnings OK) | No |
| Unit Tests | CI | 100% pass | Yes |
| Integration Tests | CI | 100% pass | Yes |
| Manual Tests | Pre-release | Checklist complete | Yes |
| Code Review | Pre-merge | 1 approval | Yes |
| Security Scan | Pre-release | No high/critical | Yes |
| Performance | Pre-release | Meets targets | No (with exception) |
| Documentation | Pre-release | README complete | Yes |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-07 | Quality Lead Agent | Initial comprehensive version |

---

*This document is the source of truth for quality standards on the Matrix Terminal Shader project.*
