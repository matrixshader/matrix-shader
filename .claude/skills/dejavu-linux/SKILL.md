---
name: dejavu-linux
description: "Build and release Linux/Mac Matrix Shader tarballs. Runs tests, builds tarballs via build-release.sh, creates/uploads GitHub release assets. Usage: /dejavu-linux [patch|minor|major|build-only]"
user_invocable: true
---

# Deja Vu Linux — Matrix Shader Linux/Mac Release

"Whoa... deja vu." — Linux and Mac tarballs built, tested, and shipped.

## Usage

```
/dejavu-linux patch       # bump version + build + release
/dejavu-linux minor       # bump version + build + release
/dejavu-linux major       # bump version + build + release
/dejavu-linux 1.2.3       # explicit version + build + release
/dejavu-linux build-only  # just build tarballs, no version bump or release
```

If no argument provided, default to `build-only` (safest — version bumps should be coordinated with Windows Claude).

---

## Release Checklist (Execute in Order)

### Step 1: Determine Version

- Read current version from `MatrixShader/Directory.Build.props` (`<Version>` tag)
- If `build-only` — skip version bump, just build
- If `patch`/`minor`/`major` — bump accordingly
- If explicit semver — use that

Display:
```
Release: v{OLD} → v{NEW}
```

### Step 2: Pre-flight Checks

```bash
# 1. Patched Ghostty binary must exist
[ -x ~/ghostty-build/zig-out/bin/ghostty ] || echo "BLOCKED: No patched Ghostty binary"

# 2. Tests must pass
python -m pytest linux/tests/ -q --tb=short
python -m pytest mac/tests/ -q --tb=short

# 3. Secret must NOT be in any build artifact (server-only validation since 2026-03-29)
# If _license_secret.py exists in the build tree, STOP — it should not be bundled
```

**If any check fails**: STOP. Do not build.

### Step 3: Update Version (skip if build-only)

```bash
# Update Directory.Build.props
# Update VERSION file
echo "X.Y.Z" > VERSION
```

### Step 4: Build Linux Tarball

```bash
./linux/build-release.sh
```

**Verify:**
```bash
# Shaders keep -ghostty suffix
tar tzf matrixshader-linux-x86_64.tar.gz | grep "\.glsl" | head -5
# Secret must NOT be in tarball (server-only validation)
tar tzf matrixshader-linux-x86_64.tar.gz | grep "_license_secret" && echo "FAIL: secret in tarball!" || echo "OK: no secret"
# Preset system files must be present
tar tzf matrixshader-linux-x86_64.tar.gz | grep "preset_service\|preset_menu"
# All scripts present
tar tzf matrixshader-linux-x86_64.tar.gz | grep "scripts/" | head -20
```

### Step 5: Build Mac Tarball (if possible)

```bash
./mac/build-release.sh
```

**Note:** Requires patched Ghostty.app. If not available, skip and note for Mac build later.

### Step 6: Commit + Push (skip if build-only)

```bash
git add VERSION MatrixShader/Directory.Build.props
git commit -m "release: v{NEW} — Linux/Mac tarballs

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin master
```

### Step 7: GitHub Release

**If Windows Claude already created the release tag:**
```bash
# Upload Linux tarball to existing release
gh release upload "v{NEW}" matrixshader-linux-x86_64.tar.gz
```

**If no release exists yet:**
```bash
gh release create "v{NEW}" \
  matrixshader-linux-x86_64.tar.gz \
  --title "Matrix Shader v{NEW}" \
  --notes "$(cat <<'NOTES'
## What's New

{CHANGELOG}

## Install

**Linux:**
```bash
curl -sL matrixshader.com/linux | bash
```

**Windows:**
```powershell
irm matrixshader.com/install.ps1 | iex
```
NOTES
)"
```

### Step 8: Pin i.sh URL

```bash
sed -i "s|releases/latest/download|releases/download/v{NEW}|" linux/i.sh
git add linux/i.sh && git commit -m "fix: pin i.sh to v{NEW}" && git push
```

### Step 9: Verify

```bash
echo "=== Verify ==="
echo "Version: $(cat VERSION)"
echo "Tarball: $(ls -lh matrixshader-linux-x86_64.tar.gz)"
echo "Release: $(gh release view v{NEW} --json tagName,assets -q '{tag: .tagName, assets: [.assets[].name]}')"
curl -sLI "https://github.com/matrixshader/matrix-shader/releases/download/v{NEW}/matrixshader-linux-x86_64.tar.gz" | head -3
```

---

## Coordination with Windows Claude

- **Version bumps:** Coordinate via openmind. Don't bump independently.
- **GitHub release:** One Claude creates, the other uploads. Check if release exists first with `gh release view v{NEW}`.
- **Website version:** Windows Claude handles the private website repo (`Ehomey/matrixshader.com`).

---

## Error Recovery

- **Build fails**: Fix error, re-run `/dejavu-linux build-only`
- **Release exists**: Use `gh release upload` to add assets
- **Secret found in build**: Remove it — client is server-only validation since 2026-03-29
- **No Ghostty binary**: Build it: `cd ~/ghostty-build && PATH="/tmp/zig-linux-x86_64-0.13.0:$PATH" zig build -Doptimize=ReleaseFast -Dapp-runtime=gtk`
