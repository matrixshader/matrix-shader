---
name: dejavu
description: "Ship a new Matrix Shader release. Cross-platform: builds Linux tarball, Mac tarball, bumps version, creates GitHub release. Usage: /dejavu [patch|minor|major] or /dejavu 1.2.3"
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
/dejavu linux      # build Linux tarball only (no version bump)
/dejavu mac        # build Mac tarball only (no version bump)
```

If no argument provided, default to `patch`.

---

## Platform Detection

This skill runs on BOTH Windows and Linux. Detect the platform:
- If `powershell.exe` exists → Windows flow (C# build, Inno Setup)
- If on Linux/Mac → Linux/Mac flow (tarball builds)

**Cross-platform release:** When running on Linux, this skill handles Linux + Mac tarballs. Windows builds are handled by the Windows instance running the Windows version of this skill.

---

## Release Checklist — Linux/Mac (Execute in Order)

### Step 1: Determine Version

Parse the argument to figure out the new version number.

- Read current version from `MatrixShader/Directory.Build.props` (the `<Version>` tag)
- If argument is `patch`, `minor`, or `major` — bump accordingly
- If argument is a semver string like `1.2.3` — use that directly
- If argument is `linux` or `mac` — skip version bump, just build
- If no argument — default to `patch`

Display to user:
```
Release: v{OLD} → v{NEW}
```

### Step 2: Update Version References (Linux/Mac files)

These files in the PUBLIC repo need version updates:

| File | What to Change |
|------|---------------|
| `MatrixShader/Directory.Build.props` | `<Version>X.Y.Z</Version>`, `<AssemblyVersion>X.Y.Z.0</AssemblyVersion>`, `<FileVersion>X.Y.Z.0</FileVersion>` |
| `linux/build-release.sh` | `VERSION=` line (if it has one), or rely on VERSION file |
| `mac/build-release.sh` | Same |

Also create/update `VERSION` file in repo root:
```bash
echo "X.Y.Z" > VERSION
```

**NOTE:** Website version files are in the PRIVATE repo (`Ehomey/matrixshader.com`). Windows Claude handles those. If you have the private repo cloned, update it too. Otherwise, note it for Windows Claude.

### Step 3: Run Tests

```bash
cd /home/neo/matrix-shader
python -m pytest linux/tests/ -q --tb=short
python -m pytest mac/tests/ -q --tb=short
```

**If tests fail**: STOP. Fix the failures before releasing.

### Step 4: Build Linux Tarball

```bash
cd /home/neo/matrix-shader

# LICENSE_SECRET must be set (or MatrixShader/license-secret.key must exist)
# Check:
[ -n "$LICENSE_SECRET" ] || [ -f MatrixShader/license-secret.key ] || echo "NO SECRET — cannot build"

# Build:
./linux/build-release.sh
```

This creates `matrixshader-linux-x86_64.tar.gz` containing:
- `bin/ghostty` — patched Ghostty binary
- `shaders/` — all GLSL shader files (with -ghostty suffix)
- `scripts/` — all Python modules + bash scripts
- `scripts/_license_secret.py` — embedded HMAC secret
- `install.sh` — installer
- `VERSION` — version file

**Verify tarball contents:**
```bash
tar tzf matrixshader-linux-x86_64.tar.gz | head -30
# Check: shaders should have -ghostty suffix
tar tzf matrixshader-linux-x86_64.tar.gz | grep "\.glsl"
# Check: license secret should be present
tar tzf matrixshader-linux-x86_64.tar.gz | grep "_license_secret"
```

**If build fails**: STOP and show the error.

### Step 5: Build Mac Tarball (optional — if on Mac or if patched Ghostty.app exists)

```bash
cd /home/neo/matrix-shader
./mac/build-release.sh
```

**NOTE:** Mac tarball requires a patched Ghostty.app binary. If building on Linux without Mac hardware, use `--skip-ghostty` flag if available, or skip this step and note that Mac tarball needs to be built on Mac.

### Step 6: Commit Version Bump

```bash
cd /home/neo/matrix-shader
git add VERSION MatrixShader/Directory.Build.props
git commit -m "release: v{NEW}

Bump version across project files.
Linux + Mac tarballs built.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin master
```

### Step 7: Create GitHub Release

```bash
cd /home/neo/matrix-shader

# Generate changelog from recent commits
git log $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --oneline

gh release create "v{NEW}" \
  matrixshader-linux-x86_64.tar.gz \
  --title "Matrix Shader v{NEW}" \
  --notes "$(cat <<'NOTES'
## What's New

{CHANGELOG — summarize recent commits since last release}

## Install

**Linux (one-liner):**
```bash
curl -sL matrixshader.com/linux | bash
```

**Linux (manual):**
Download `matrixshader-linux-x86_64.tar.gz`, extract, run `./install.sh`

**Windows:**
```powershell
irm matrixshader.com/install.ps1 | iex
```
NOTES
)"
```

**If Mac tarball was built**, add it to the release:
```bash
gh release upload "v{NEW}" matrix-shader-mac-*.tar.gz
```

**IMPORTANT:** If Windows Claude is also creating a release with the same tag, coordinate. One of you creates, the other uploads additional assets with `gh release upload`.

### Step 8: Update i.sh Download URL

After the release is created, update `linux/i.sh` to use the explicit release tag:

```bash
# Change from releases/latest to explicit tag
sed -i "s|releases/latest/download|releases/download/v{NEW}|" linux/i.sh
git add linux/i.sh
git commit -m "fix: pin i.sh download URL to v{NEW}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin master
```

### Step 9: Verify

```bash
echo "=== Version Check ==="
echo "Directory.Build.props: $(grep '<Version>' MatrixShader/Directory.Build.props)"
echo "VERSION file: $(cat VERSION)"
echo "GitHub Release: $(gh release view --json tagName -q '.tagName')"
echo "Tarball exists: $(ls -lh matrixshader-linux-x86_64.tar.gz)"
echo "=== Download Test ==="
curl -sLI "https://github.com/matrixshader/matrix-shader/releases/download/v{NEW}/matrixshader-linux-x86_64.tar.gz" | head -3
```

---

## Error Recovery

- **Build fails**: Fix the build error, then re-run `/dejavu` with the same version
- **GitHub release already exists**: Use `gh release upload` to add assets, or `gh release delete v{NEW}` and recreate
- **No LICENSE_SECRET**: Cannot build. Get the secret from Vercel env vars or MatrixShader/license-secret.key
- **No patched Ghostty binary**: Build it first: `cd ~/ghostty-build && PATH="/tmp/zig-linux-x86_64-0.13.0:$PATH" zig build -Doptimize=ReleaseFast -Dapp-runtime=gtk`
- **Version already bumped but not released**: Skip to Step 4 (build) and continue

---

## What This Does NOT Do

- Does NOT build Windows executables (Windows Claude handles that)
- Does NOT update the private website repo (Windows Claude handles that)
- Does NOT run tests automatically (run them in Step 3)
- Does NOT merge branches (release from whatever branch you're on)

---

## Post-Release Reminders

After a successful release, remind the user:
1. Test the install script: `curl -sL matrixshader.com/linux | bash` (in a clean environment or VM)
2. Verify the download link works from GitHub releases page
3. Coordinate with Windows Claude if both platforms release simultaneously
4. Update openmind with release notes
