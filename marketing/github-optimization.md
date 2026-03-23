# GitHub Repo Optimization — Ready for Eric's Review

*All artifacts below are drafts. Eric reviews and approves before any are applied.*

---

## 1. RECOMMENDED GITHUB TOPICS/TAGS

Add these topics to the repository settings (Settings > General > Topics):

```
terminal-shader
windows-terminal
matrix
gpu-shader
hlsl
terminal-customization
developer-tools
ai-agents
pixel-shader
cli
dotnet
csharp
```

**Why these specific topics:**
- `terminal-shader` — no one owns this topic yet. First mover.
- `windows-terminal` — direct platform match, active community
- `matrix` — huge topic, drives discovery from aesthetic seekers
- `gpu-shader` / `hlsl` / `pixel-shader` — technical audience, lower competition for trending
- `terminal-customization` — the r/unixporn crowd searches this
- `developer-tools` — broad but high-traffic
- `ai-agents` — hot topic in 2026, connects to the multi-agent value prop
- `cli` / `dotnet` / `csharp` — language/platform discoverability

---

## 2. CONTRIBUTING.md

Save as `.github/CONTRIBUTING.md`:

```markdown
# Contributing to MatrixShader

Welcome to the simulation, operator. We're glad you followed the white rabbit this far.

## The Rules of the Matrix

**Before you contribute:**
- Check [existing issues](https://github.com/matrixshader/matrix-shader/issues) to see if someone's already on it
- Open an issue to discuss major changes before writing code
- Keep pull requests focused — one fix or feature per PR

## Setting Up Your Environment

**Windows (shader development):**
1. Windows 10/11 with Windows Terminal
2. .NET 9 SDK
3. A GPU with DirectX 11+ support
4. Clone and build: `dotnet build`

**Linux (Ghostty shader development):**
1. See `linux/patches/README.md` for the patched Ghostty build
2. GLSL shaders live in `linux/shaders/`

## Code Style

- Follow existing patterns — if you see how something's done, do it that way
- HLSL shaders: use `#define` constants at the top for tunable parameters
- C#: standard .NET conventions, no unnecessary abstractions
- Commit messages: present tense, concise ("Add teal color preset" not "Added a new color preset for teal")

## What We Need Help With

- **Shader effects** — new visual effects, optimizations, accessibility shaders
- **Platform support** — macOS Metal shader port, Linux testing
- **Bug reports** — especially from different GPU vendors (AMD, Intel, NVIDIA)
- **Documentation** — usage guides, shader development tutorials

## What We Don't Need

- Refactoring for the sake of refactoring
- Dependency additions without clear justification
- AI-generated boilerplate PRs

## Submitting a PR

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-fix-name`
3. Make your changes
4. Test manually (run the shader, verify it works)
5. Push and open a PR with a clear description of what and why

## Reporting Glitches in the Matrix

Use the [Bug Report](https://github.com/matrixshader/matrix-shader/issues/new?template=bug_report.md) template. Include:
- Your OS and GPU
- Windows Terminal version
- What happened vs. what you expected
- Screenshots or recordings if it's a visual glitch

## The Path of the ONE

Not sure where to start? Look for issues labeled `good first issue`. These are scoped, well-defined tasks perfect for your first contribution.

---

There is no spoon. But there is a `git push`.
```

---

## 3. ISSUE TEMPLATES

### Bug Report Template

Save as `.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
---
name: Glitch in the Matrix
about: Something isn't rendering correctly or behaving as expected
title: "[Glitch] "
labels: bug
assignees: ''
---

## What happened

A clear description of the glitch.

## What you expected

What should have happened instead.

## Steps to reproduce

1. Run `...`
2. Press `...`
3. See the glitch

## Your system

- **OS:** Windows 10 / Windows 11 / Linux (distro)
- **GPU:** NVIDIA / AMD / Intel (model if known)
- **Windows Terminal version:** (Help > About)
- **MatrixShader version:** (check with `bluepill --version` or installer version)

## Screenshots / recordings

If it's a visual glitch, a screenshot or screen recording helps enormously.

## Additional context

Anything else an operator should know.
```

### Feature Request Template

Save as `.github/ISSUE_TEMPLATE/feature_request.md`:

```markdown
---
name: Enter the Rabbit Hole
about: Suggest a new shader effect, feature, or improvement
title: "[Request] "
labels: enhancement
assignees: ''
---

## The vision

What would you like to see? Describe the feature or shader effect.

## Why it matters

How would this improve the simulation for operators?

## Possible approach

If you have ideas on implementation, share them. Shader code snippets welcome.

## Alternatives considered

Have you tried other approaches or workarounds?
```

---

## 4. PR TEMPLATE

Save as `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## What this changes

Brief description of the modification.

## Why

What problem does this solve or what does it improve?

## How to test

Steps to verify this works:
1. ...
2. ...

## Screenshots

If this is a visual change, before/after screenshots.

## Checklist

- [ ] Tested manually on Windows Terminal
- [ ] No new dependencies added (or justified if so)
- [ ] Shader parameters use `#define` constants
- [ ] Commit messages are concise and present tense
```

---

## 5. GITHUB DISCUSSIONS RECOMMENDATION

**Enable GitHub Discussions** with these categories:

| Category | Purpose | Icon |
|----------|---------|------|
| Announcements | Release notes, updates (maintainer only) | Megaphone |
| Shader Ideas | "What shader effects would you want?" | Light bulb |
| Show Your Setup | Operators share their MatrixShader configurations | Star |
| Q&A | Installation help, troubleshooting | Question mark |
| General | Everything else | Chat bubble |

**Pinned Discussion (post immediately after enabling):**

Title: `What shader effects would you want to see?`

Body:
```
MatrixShader currently ships with Matrix rain, Aurora Borealis, Aurora Rain, Rain on Glass, Fireplace, and MatrixCodeVision.

What effects would make your terminal setup complete? Some ideas floating around:

- CRT scanline effect
- Cyberpunk neon rain
- Binary cascade
- Starfield / hyperspace
- Custom color gradients

Drop your ideas. If you can write HLSL, even better — PRs welcome.
```

This seeds community engagement and gives early visitors something to interact with beyond just starring the repo.
