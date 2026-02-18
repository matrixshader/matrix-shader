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

| File | What to Change |
|------|---------------|
| `MatrixShader/Directory.Build.props` | `<Version>X.Y.Z</Version>`, `<AssemblyVersion>X.Y.Z.0</AssemblyVersion>`, `<FileVersion>X.Y.Z.0</FileVersion>` |
| `installer/MatrixShaderSetup.iss` | `AppVersion=X.Y.Z` |
| `installer/install.ps1` | `'DisplayVersion' -Value 'X.Y.Z'` |
| `Website/index.html` | `<span class="version">vX.Y.Z</span>` |
| `package.json` (root) | `"version": "X.Y.Z"` |
| `Website/package.json` | `"version": "X.Y.Z"` |

**CRITICAL**: All 6 files MUST be updated. Read each file first, then edit. If any file is missing or the pattern doesn't match, STOP and tell the user.

### Step 3: Rebuild C# Projects

Run the publish script to rebuild all executables:

```bash
cd /c/Users/ehome/Documents/MATRIX && powershell.exe -NoProfile -ExecutionPolicy Bypass -File installer/publish-all.ps1
```

This publishes all 7 C# projects (wakeupneo, bluepill, redpill, matrixlite, matrix-hotkeys, matrix-monitor, matrixlite-standalone).

**If build fails**: STOP and show the error. Do NOT continue with a broken build.

### Step 4: Stage Installer Files

The publish output goes to each project's `bin/Release/net8.0/win-x64/publish/` directory. The installer needs all executables and shaders gathered into `installer/publish/`:

```bash
cd /c/Users/ehome/Documents/MATRIX

# Clean previous publish staging
rm -rf installer/publish
mkdir -p installer/publish/shaders

# Copy all executables from their publish directories
PROJECTS=(
  "MatrixShader.Cli/WakeupNeo:wakeupneo"
  "MatrixShader.Cli/Bluepill:bluepill"
  "MatrixShader.Cli/Redpill:redpill"
  "MatrixShader.Cli/MatrixLite:matrixlite"
  "MatrixShader.Hotkeys:matrix-hotkeys"
  "MatrixShader.Monitor:matrix-monitor"
  "MatrixShader.Lite:matrixlite"
)

SRC_BASE="MatrixShader/src"
for entry in "${PROJECTS[@]}"; do
  proj="${entry%%:*}"
  pubdir="$SRC_BASE/$proj/bin/Release/net8.0/win-x64/publish"
  if [ -d "$pubdir" ]; then
    cp -r "$pubdir"/* installer/publish/
  fi
done

# Copy shaders
cp MatrixShader/shaders/*.hlsl installer/publish/shaders/
```

**Verify** the key executables exist in `installer/publish/`:
- wakeupneo.exe
- bluepill.exe
- redpill.exe
- matrixlite.exe
- matrix-hotkeys.exe
- matrix-monitor.exe

### Step 5: Create ZIP Archive

```bash
cd /c/Users/ehome/Documents/MATRIX/installer
rm -f output/MatrixShader.zip
mkdir -p output
cd publish && zip -r ../output/MatrixShader.zip . && cd ..
```

### Step 6: Build Inno Setup Installer

```bash
cd /c/Users/ehome/Documents/MATRIX/installer
"/c/Program Files (x86)/Inno Setup 6/ISCC.exe" MatrixShaderSetup.iss
```

This creates `installer/output/MatrixShaderSetup.exe`.

**If Inno Setup is not installed**: Tell the user to install it from https://jrsoftware.org/isdl.php, or skip this step and note it in the release.

### Step 7: Commit Version Bump

```bash
cd /c/Users/ehome/Documents/MATRIX
git add MatrixShader/Directory.Build.props installer/MatrixShaderSetup.iss installer/install.ps1 Website/index.html package.json Website/package.json
git commit -m "release: v{NEW}

Bump version across all project files.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

### Step 8: Create GitHub Release

```bash
cd /c/Users/ehome/Documents/MATRIX
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
irm matrixshader.com/install.ps1 | iex
```

**Or download:**
- `MatrixShader.zip` — Portable (extract and run `wakeupneo.exe`)
- `MatrixShaderSetup.exe` — GUI installer (adds to PATH, start menu)
NOTES
)"
```

**Before creating the release**: Look at `git log` since the last tag to generate changelog bullet points.

### Step 9: Deploy Website

Website deploys automatically via Vercel when pushed to master. Verify deployment:

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
echo "Website: $(grep 'class=\"version\"' Website/index.html)"
echo "package.json: $(grep '\"version\"' package.json | head -1)"
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
2. Test the install script: `irm matrixshader.com/install.ps1 | iex` (in a clean environment)
3. Verify UpdateChecker will detect the new version (it checks GitHub releases API)
