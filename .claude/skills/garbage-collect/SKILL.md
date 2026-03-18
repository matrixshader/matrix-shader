---
name: garbage-collect
description: "Scan the repo for bloat — build artifacts tracked in git, large binaries, stale files, things committed before .gitignore rules existed. Shows a report and lets Eric approve removals. Usage: /garbage-collect or /garbage-collect --deep"
user_invocable: true
---

# Garbage Collect — Repo Hygiene Audit

"There's a difference between knowing the path and walking the path." — Clean up what shouldn't be here.

## Usage

```
/garbage-collect          # Standard scan — tracked files that match .gitignore patterns + large files
/garbage-collect --deep   # Deep scan — adds git history bloat analysis (slower)
```

If no argument provided, default to standard scan.

---

## Scan Checklist (Execute in Order)

### Step 1: Set Project Root

```bash
PROJECT_ROOT="C:/Users/ehome/Documents/MATRIX"
```

### Step 2: Find Build Artifacts Tracked in Git

These are files that `.gitignore` would exclude but were committed before the rules existed.

```bash
cd "$PROJECT_ROOT"

# Check each .gitignore pattern against tracked files
echo "=== Build Artifacts Tracked in Git ==="

# bin/ — .gitignore says bin/ but files were committed before
git ls-files -- "bin/" | head -50
echo "... $(git ls-files -- 'bin/' | wc -l) total files in bin/"

# obj/ — should never be tracked
git ls-files -- "**/obj/" | head -20

# publish/ — build outputs
git ls-files -- "**/publish/" | head -20

# node_modules/ — should never be tracked
git ls-files -- "node_modules/" | head -10
```

For each category found, calculate size:

```bash
# Size of tracked bin/native/ (the big one — compiled .NET DLLs)
git ls-files -- "bin/native/" | xargs -I{} wc -c "{}" 2>/dev/null | tail -1

# Or use du if files are on disk
du -sh bin/native/ 2>/dev/null
```

### Step 3: Find Large Binary Files

Scan tracked files for binaries that don't belong in source control:

```bash
cd "$PROJECT_ROOT"

echo "=== Large Tracked Files (>1MB) ==="
git ls-files -z | xargs -0 -I{} bash -c 'size=$(wc -c < "{}" 2>/dev/null); if [ "$size" -gt 1048576 ]; then echo "$size {}"; fi' | sort -rn | head -30
```

Flag these file types as suspicious when tracked:
- `.dll`, `.pdb`, `.exe` — compiled binaries (should be build artifacts)
- `.mp4`, `.webm`, `.avi` — video files (should be in CDN/releases, not git)
- `.zip`, `.tar.gz`, `.tgz` — archives
- `.woff`, `.woff2`, `.ttf` — fonts (acceptable in Website/ but large)
- `.jpg`, `.png`, `.webp` over 500KB — oversized images

### Step 4: Find Stale/Dead Files

Look for patterns that indicate abandoned or test artifacts:

```bash
cd "$PROJECT_ROOT"

echo "=== Potentially Stale Tracked Files ==="

# Test/debug artifacts
git ls-files | grep -iE "(test|debug|tmp|temp|old|backup|deprecated|disabled|archive)" | head -30

# Duplicate or vestigial config files
git ls-files | grep -iE "\.(bak|orig|swp|swo)$" | head -10

# Files with "TODO: remove" or "DEPRECATED" in them
git grep -l "TODO.*remove\|DEPRECATED\|HACK.*temporary" -- "*.cs" "*.js" "*.ps1" | head -20
```

### Step 5: Find .gitignore Orphans

Files that match current `.gitignore` patterns but are still tracked (committed before the rule):

```bash
cd "$PROJECT_ROOT"

echo "=== Tracked Files That Match .gitignore Patterns ==="

# Read .gitignore patterns and check each against tracked files
# Key patterns from this repo's .gitignore:
git ls-files -- "bin/"           # .gitignore has: bin/
git ls-files -- "**/obj/"        # .gitignore has: obj/
git ls-files -- "*.tgz"          # .gitignore has: *.tgz
git ls-files -- "*.tmp"          # .gitignore has: *.tmp
git ls-files -- "*.log"          # .gitignore has: *.log
git ls-files -- "*.bak"          # .gitignore has: *.bak
git ls-files -- ".vercel/"       # .gitignore has: .vercel
git ls-files -- "Website/.vercel/"
```

### Step 6: Deep Scan — Git History Bloat (only with --deep)

**Skip this step unless `--deep` was specified.** It's slow on large repos.

```bash
cd "$PROJECT_ROOT"

echo "=== Git Object Size Analysis ==="
echo "Total .git size: $(du -sh .git | cut -f1)"

# Find largest objects in git history (even if deleted from HEAD)
# This finds blobs that were committed and still bloat the pack
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  grep '^blob' | \
  sort -t' ' -k3 -rn | \
  head -30 | \
  while read type hash size path; do
    sizeMB=$(echo "scale=1; $size/1048576" | bc 2>/dev/null || echo "$size bytes")
    echo "${sizeMB}MB  $path"
  done
```

If large deleted files are found in history, note that `git rm` only removes from HEAD. Full cleanup requires BFG Repo Cleaner or `git filter-repo`:

```bash
# Example BFG command (DO NOT RUN — show to user for approval)
# java -jar bfg.jar --delete-folders bin/native --no-blob-protection "$PROJECT_ROOT"
# git reflog expire --expire=now --all && git gc --prune=now --aggressive
# git push --force
```

**WARNING:** Force-push rewrites history for all collaborators. Only do this during a maintenance window, never during active launch prep.

### Step 7: Generate Report

Present findings in this format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GARBAGE COLLECT — Repo Hygiene Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Build Artifacts in Git

| Path | Files | Size | Risk | Recommendation |
|------|-------|------|------|---------------|
| bin/native/ | {N} | {size} | HIGH | `git rm -r bin/native/` — compiled .NET DLLs, rebuilt by /dejavu |
| bin/*.js | {N} | {size} | MEDIUM | `git rm` if npm distribution abandoned |
| ... | ... | ... | ... | ... |

## Large Binary Files

| File | Size | Type | Recommendation |
|------|------|------|---------------|
| ... | ... | ... | ... |

## Stale/Dead Files

| File | Why Flagged | Recommendation |
|------|-------------|---------------|
| ... | ... | ... |

## .gitignore Orphans

| Pattern | Tracked Files | Recommendation |
|---------|--------------|---------------|
| bin/ | {N} files | `git rm -r` — .gitignore already excludes new additions |
| ... | ... | ... |

## Summary

| Category | Files | Size | Action |
|----------|-------|------|--------|
| Build artifacts | {N} | {size} | Remove from HEAD |
| Large binaries | {N} | {size} | Evaluate per-file |
| Stale files | {N} | {size} | Remove from HEAD |
| .gitignore orphans | {N} | {size} | Remove from HEAD |
| **Total recoverable** | **{N}** | **{size}** | |

{If --deep: History bloat analysis}
| Git history bloat | — | {size in .git} | BFG Repo Cleaner (requires force-push) |
```

### Step 8: Present for Approval

**NEVER delete anything automatically.** Present the report and wait for Eric to approve.

For each category, offer:
1. **Approve all** — `git rm -r` everything in that category
2. **Review individually** — go through files one by one
3. **Skip** — leave it for later

After approval:

```bash
cd "$PROJECT_ROOT"

# Stage removals (only approved files)
git rm -r {approved_paths}

# Commit
git commit -m "chore: garbage collect — remove {description}

Removed {N} files ({size}) of tracked build artifacts/stale files.
Files were committed before .gitignore rules existed.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

**Do NOT push automatically.** Let Eric review the commit and push when ready.

---

## Known Issues in This Repo

These are pre-identified by the engineering audit. The scan will find them, but they're documented here for context:

| Issue | Details | Size |
|-------|---------|------|
| `bin/native/` | 214 compiled .NET DLLs — committed before `bin/` gitignore rule | ~73MB on disk |
| `bin/*.js` | 5 vestigial npm wrappers from abandoned npm distribution | <1KB each |
| Website videos | `.mp4`/`.webm` assets tracked in `Website/assets/` | Large — in git history even after repo split |
| `.vercel/` dirs | Vercel project config — two copies (root + Website/) | Tiny but shouldn't be tracked |

## What This Does NOT Do

- Does NOT delete files automatically (always requires approval)
- Does NOT run BFG/filter-repo (shows the command, user runs it)
- Does NOT modify `.gitignore` (that's a separate concern)
- Does NOT scan untracked files (those aren't in git, they're not the problem)
- Does NOT force-push (ever)

## Error Handling

- If `git ls-files` returns nothing: repo may not be initialized. Check `git status`.
- If `du` fails on a path: file may be deleted from working tree but still tracked. Use `git show HEAD:{path} | wc -c` instead.
- If `bc` is not available for size calculations: fall back to raw byte counts.
