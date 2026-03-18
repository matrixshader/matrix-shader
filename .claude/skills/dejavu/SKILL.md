---
name: dejavu
description: "Ship a new Matrix Shader release. Bumps version across ALL project files, rebuilds C# executables, rebuilds installer, creates GitHub release with assets, and deploys. Usage: /dejavu [patch|minor|major] or /dejavu 1.2.3"
user_invocable: true
---

# Deja Vu — Matrix Shader Release Skill

"Whoa... deja vu." — Everything updates at once. Version bump, rebuild, release, deploy.

## Usage

```
/dejavu patch      # 1.0.0 → 1.0.1
/dejavu minor      # 1.0.0 → 1.1.0
/dejavu major      # 1.0.0 → 2.0.0
/dejavu 1.2.3      # explicit version
```

If no argument provided, default to `patch`.

---

## Release Checklist (Execute in Order)

### Step 1: Determine Version

Parse the argument to figure out the new version number.

- Read current version from `MatrixShader/Directory.Build.props` (the `<Version>` tag)
- If argument is `patch`, `minor`, or `major` — bump accordingly
- If argument is a semver string like `1.2.3` — use that directly
- If no argument — default to `patch`

Display to user:
```
Release: v{OLD} → v{NEW}
```

### Step 2: Update ALL Version References

Update version in ALL of these files (use Edit tool for each):

| File | Repo | What to Change |
|------|------|---------------|
| `MatrixShader/Directory.Build.props` | public | `<Version>X.Y.Z</Version>`, `<AssemblyVersion>X.Y.Z.0</AssemblyVersion>`, `<FileVersion>X.Y.Z.0</FileVersion>` |
| `installer/MatrixShaderSetup.iss` | public | `AppVersion=X.Y.Z` |
| `installer/install.ps1` | public | `'DisplayVersion' -Value 'X.Y.Z'` |
| `index.html` | **private** (`~/Documents/matrixshader.com/`) | `<span class="version">vX.Y.Z</span>` |
| `package.json` | **private** (`~/Documents/matrixshader.com/`) | `"version": "X.Y.Z"` |
| `admin/emails/onboarding/welcome-operator.html` | **private** | `vX.Y.Z \| Windows 10/11` |
| `303h4rdl1n3/emails/onboarding/welcome-operator.html` | **private** | `vX.Y.Z \| Windows 10/11` |

**CRITICAL**: Files span TWO repos. Public repo is at `~/Documents/MATRIX/`. Private website repo is at `~/Documents/matrixshader.com/`. Both must be updated, committed, and pushed separately.

**TIP**: Use `grep -r` to scan for the OLD version string across the entire private website repo to catch any other references.

### Step 3: Rebuild C# Projects

Run the publish script to rebuild all executables:

```bash
cd "$PROJECT_ROOT" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File installer/publish-all.ps1
```

This publishes all 7 C# projects (wakeupneo, bluepill, redpill, matrixlite, matrix-hotkeys, matrix-monitor, matrixlite-standalone).

**If build fails**: STOP and show the error. Do NOT continue with a broken build.

### Step 4: Stage Installer Files

Use the `copy-fresh-build.ps1` script to gather all publish outputs into `installer/publish/`. This handles the varying TFM paths (`net8.0-windows`, `net8.0-windows10.0.17763.0`, etc.) automatically.

```bash
cd "$PROJECT_ROOT" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File installer/copy-fresh-build.ps1
```

The script copies all executables, DLLs, and shaders, then verifies key executables exist:
- wakeupneo.exe
- bluepill.exe
- redpill.exe
- matrixlite.exe
- matrix-hotkeys.exe
- matrix-monitor.exe

**If any are MISSING**: STOP and investigate the build output.

### Step 5: Create ZIP Archive

```bash
cd "$PROJECT_ROOT"/installer && mkdir -p output && powershell.exe -NoProfile -Command "Compress-Archive -Path 'publish\*' -DestinationPath 'output\MatrixShader.zip' -Force"
```

**Note**: Use PowerShell `Compress-Archive` — the `zip` command may not be available in MSYS/Git Bash.

### Step 6: Build Inno Setup Installer

```bash
ISCC "{PROJECT_ROOT}\installer\MatrixShaderSetup.iss"
```

ISCC is available via Chocolatey (`C:\ProgramData\chocolatey\bin\ISCC.exe`). This creates `installer/output/MatrixShaderSetup.exe`.

**If Inno Setup is not installed**: Tell the user to install it (`choco install innosetup`), or skip this step and note it in the release.

### Step 7: Commit Version Bump

**Public repo** (`~/Documents/MATRIX/`):
```bash
cd "$PROJECT_ROOT"
git add MatrixShader/Directory.Build.props installer/MatrixShaderSetup.iss installer/install.ps1
git commit -m "release: v{NEW}

Bump version across all project files.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

**Private website repo** (`~/Documents/matrixshader.com/`):
```bash
cd ~/Documents/matrixshader.com
git add index.html package.json admin/emails/onboarding/welcome-operator.html 303h4rdl1n3/emails/onboarding/welcome-operator.html
git commit -m "release: v{NEW} — version bump"
git push
```

Vercel auto-deploys from the private repo on push.

### Step 8: Create GitHub Release

```bash
cd "$PROJECT_ROOT"
gh release create "v{NEW}" \
  installer/output/MatrixShader.zip \
  installer/output/MatrixShaderSetup.exe \
  --title "Matrix Shader v{NEW}" \
  --notes "$(cat <<'NOTES'
## What's New

{CHANGELOG — summarize recent commits since last release}

## Install

**One-liner (recommended):**
```powershell
irm https://matrixshader.com/install.ps1 | iex
```

**Or download:**
- `MatrixShader.zip` — Portable (extract and run `wakeupneo.exe`)
- `MatrixShaderSetup.exe` — GUI installer (adds to PATH, start menu)
NOTES
)"
```

**Before creating the release**: Look at `git log` since the last tag to generate changelog bullet points.

### Step 9: Deploy Website

Website deploys automatically via Vercel when the private repo (`Ehomey/matrixshader.com`) is pushed. The push in Step 7 triggers this. Verify deployment:

```bash
# Wait a moment for Vercel to deploy, then verify
sleep 10
curl -s https://matrixshader.com | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+'
```

### Step 10: Verify

Confirm everything is in sync:

```bash
echo "=== Version Check ==="
echo "Directory.Build.props: $(grep '<Version>' MatrixShader/Directory.Build.props)"
echo "MatrixShaderSetup.iss: $(grep 'AppVersion=' installer/MatrixShaderSetup.iss)"
echo "install.ps1: $(grep 'DisplayVersion' installer/install.ps1 | head -1)"
echo "Website: $(grep 'class=\"version\"' ~/Documents/matrixshader.com/index.html)"
echo "package.json: $(grep '\"version\"' ~/Documents/matrixshader.com/package.json | head -1)"
echo "GitHub Release: $(gh release view --json tagName -q '.tagName')"
```

All should show the same version. Report any mismatches.

---

## Error Recovery

- **Build fails**: Fix the build error, then re-run `/dejavu` with the same version
- **GitHub release already exists**: Use `gh release delete v{NEW}` then re-create, OR append `-rc2` suffix
- **Inno Setup not found**: Skip installer step, upload only the zip to GitHub release, note that installer is missing
- **Version already bumped but not released**: Just run the build + release steps (skip version bump)

---

## What This Does NOT Do

- Does NOT run tests (run those separately before releasing)
- Does NOT merge branches (release from whatever branch you're on)
- Does NOT update CLAUDE.md or roadmap files (update those manually)
- Does NOT update the UNIFIED-ROADMAP.md release history (remind user to do this)

---

## Post-Release Reminders

After a successful release, remind the user:
1. Update `.planning/UNIFIED-ROADMAP.md` release history table
2. Test the install script: `irm https://matrixshader.com/install.ps1 | iex` (in a clean environment)
3. Verify UpdateChecker will detect the new version (it checks GitHub releases API)
