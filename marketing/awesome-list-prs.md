# Awesome-List PR Drafts — Ready for Eric's Review

*Do not submit until Eric approves. These are drafts.*

---

## PR #1: awesome-windows (0PandaDEV/awesome-windows)

**Repo:** https://github.com/0PandaDEV/awesome-windows
**Stars:** 30k+
**Section:** Terminal
**Format:** `- [Name](url) - Description. badge`

### Entry to add (in Terminal section, alphabetical order):

```markdown
- [MatrixShader](https://github.com/matrixshader/matrix-shader) - GPU-powered Matrix rain shader for Windows Terminal with multi-window color presets and hotkeys.
```

### PR Title:
`Add MatrixShader to Terminal section`

### PR Description:
```
MatrixShader is a GPU-powered terminal shader tool for Windows Terminal that renders real-time Matrix rain effects using HLSL pixel shaders. It supports multiple simultaneous windows with distinct color presets, global hotkeys, and automatic window positioning.

- Windows 10/11
- Source-available (BUSL-1.1, converts to MIT in 2030)
- One-liner install: `irm matrixshader.com/install.ps1 | iex`
- Website: https://matrixshader.com
```

### Contribution notes:
- Read their CONTRIBUTING.md — they reject "vibecoded slop" so emphasize genuine utility
- Entry format matches their existing Terminal section entries (ConEmu, Windows Terminal, etc.)
- Do NOT use any license badges. BSL is source-available. Skip badges entirely; many entries have none

---

## PR #2: terminals-are-sexy (k4m4/terminals-are-sexy)

**Repo:** https://github.com/k4m4/terminals-are-sexy
**Stars:** 12.9k
**Section:** Tools and Plugins
**Format:** `- [Name](url) - Description.`

### Entry to add (in Tools and Plugins section, alphabetical order):

```markdown
- [MatrixShader](https://github.com/matrixshader/matrix-shader) - GPU-powered Matrix rain for Windows Terminal with multi-window color coding and live parameter control.
```

### PR Title:
`Add MatrixShader to Tools and Plugins`

### PR Description:
```
MatrixShader renders real-time GPU-accelerated Matrix rain effects in Windows Terminal using HLSL pixel shaders. Features include 6 color presets, multi-window support (up to 8 independent windows), global hotkeys, and a live parameter control TUI.

- GitHub: https://github.com/matrixshader/matrix-shader
- Website: https://matrixshader.com
- Install: `irm matrixshader.com/install.ps1 | iex`
```

### Contribution notes:
- Their bar is subjective ("sexy enough") — the visual nature of MatrixShader plays well here
- Keep description concise, one line, matching existing format
- Read their contributing.md and code-of-conduct.md before submitting

---

## PR #3: awesome-cli-apps (agarrharr/awesome-cli-apps)

**Repo:** https://github.com/agarrharr/awesome-cli-apps
**Stars:** 15k+
**Section:** Entertainment > Media or Utilities > Theming
**Format:** `- [Name](url) - Description.`

### Entry to add (in Utilities > Theming section):

```markdown
- [MatrixShader](https://github.com/matrixshader/matrix-shader) - GPU-powered Matrix rain shader for Windows Terminal with color presets, hotkeys, and multi-window layouts.
```

### PR Title:
`Add MatrixShader to Utilities > Theming`

### PR Description:
```
MatrixShader is a CLI tool that renders GPU-accelerated Matrix rain effects in Windows Terminal using HLSL pixel shaders. Includes 6 color presets, multi-window management, global hotkeys, auto-layout modes (Pillars/Quads), and a live parameter control TUI.

Commands: `wakeupneo` (setup), `bluepill` (quick launch), `redpill` (control panel), `matrixlite` (text fallback)

- GitHub: https://github.com/matrixshader/matrix-shader
- Website: https://matrixshader.com
```

### Contribution notes:
- Read their contributing.md — they have formal protocols
- The Theming section under Utilities is the best fit
- If no Theming section exists, Entertainment or Just for Fun could work

---

## PR #4: awesome-tuis (rothgar/awesome-tuis)

**Repo:** https://github.com/rothgar/awesome-tuis
**Stars:** 7k+
**Section:** Miscellaneous (or Dashboards)
**Format:** Varies — linked name with description

### Entry to add:

```markdown
- [MatrixShader](https://github.com/matrixshader/matrix-shader) - GPU-powered Matrix rain for Windows Terminal with a TUI control panel for live shader parameter tuning.
```

### PR Title:
`Add MatrixShader to Miscellaneous`

### PR Description:
```
MatrixShader includes a TUI control panel (`redpill` command) for live adjustment of GPU shader parameters — speed, glow, character width, trail power, density, RGB color, and depth layers. The TUI runs in-terminal and updates the shader in real-time via HLSL #define injection and Windows Terminal's hot-reload mechanism.

- GitHub: https://github.com/matrixshader/matrix-shader
- Website: https://matrixshader.com
```

### Contribution notes:
- The TUI control panel (Redpill) is the angle here — this is a real TUI, not just a visual effect
- Dashboards section could also work if the maintainer prefers

---

## PR #5: awesome-windows-terminal (bennettdams/awesome-windows-terminal)

**Repo:** https://github.com/bennettdams/awesome-windows-terminal
**Stars:** 40
**Section:** Appearance (or new "Shaders" section)
**Format:** Bulleted list with linked titles

### Entry to add:

```markdown
- [MatrixShader](https://github.com/matrixshader/matrix-shader) - GPU-powered Matrix rain shader with multi-window color presets, hotkeys, and live parameter TUI. Install: `irm matrixshader.com/install.ps1 | iex`
```

### PR Title:
`Add MatrixShader to Appearance section`

### PR Description:
```
MatrixShader is a Windows Terminal shader tool that renders GPU-accelerated Matrix rain effects using HLSL pixel shaders. It manages shader deployment, multi-window profiles, color presets, and live parameter tuning — all through a CLI interface.

Unlike raw shader files, MatrixShader handles installation, configuration, and Windows Terminal profile management automatically.

- GitHub: https://github.com/matrixshader/matrix-shader
- Website: https://matrixshader.com
```

### Contribution notes:
- Small repo (40 stars) but highly targeted — specifically for Windows Terminal
- CC0 license means open contribution model
- This is the most directly relevant awesome list for MatrixShader

---

## PR #6: awesome-shell (alebcay/awesome-shell)

**Repo:** https://github.com/alebcay/awesome-shell
**Stars:** 30k+
**Section:** Customization or Applications
**Format:** `- [name](url) - Description`

### Entry to add:

```markdown
- [MatrixShader](https://github.com/matrixshader/matrix-shader) - GPU-powered Matrix rain shader for Windows Terminal with multi-window color presets, hotkeys, and live parameter tuning.
```

### PR Title:
`Add MatrixShader to Customization`

### PR Description:
```
MatrixShader renders real-time GPU-accelerated Matrix rain effects in Windows Terminal using HLSL pixel shaders. Features 6 color presets, multi-window management (up to 8 windows), global hotkeys, auto-positioning layouts, and a TUI control panel for live shader parameter adjustment.

- GitHub: https://github.com/matrixshader/matrix-shader
- Website: https://matrixshader.com
- Install: `irm matrixshader.com/install.ps1 | iex`
```

---

## SUBMISSION ORDER (by expected impact)

1. **awesome-windows** (30k+ stars) — highest visibility, direct match
2. **awesome-shell** (30k+ stars) — massive audience, customization fit
3. **awesome-cli-apps** (15k+ stars) — large, well-maintained
4. **terminals-are-sexy** (12.9k stars) — good fit, subjective curation
5. **awesome-tuis** (7k+ stars) — TUI angle differentiates
6. **awesome-windows-terminal** (40 stars) — small but perfectly targeted

**Total estimated time:** 1-2 hours to submit all 6 PRs.
**Expected merge rate:** Based on the Mantra case study, ~70% (28 of 41 PRs merged). Expect 4-5 of these 6 to be accepted.
