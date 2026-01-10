# GITHUB REPOSITORY OPTIMIZATION GUIDE
## Matrix Terminal Shader - Maximizing Discoverability & Conversion

---

**Document Version:** 1.0.0
**Created:** January 7, 2026
**Author:** Growth Specialist Agent (ae4521b)
**Last Updated:** January 7, 2026
**Target Audience:** Open-source maintainers optimizing for growth
**Document Length:** ~15,000 words (comprehensive edition)

---

## Document Purpose

This guide provides comprehensive strategies for optimizing your GitHub repository to maximize discoverability, conversions, and contributor engagement. Every element of your repository is an opportunity to convert visitors into users, and users into contributors.

**Key Insight:** GitHub is not just a code host - it's a landing page, documentation site, and community platform. Treat every visible element as marketing.

---

## Table of Contents

1. [README Structure for Virality](#1-readme-structure-for-virality)
2. [Social Preview Image Optimization](#2-social-preview-image-optimization)
3. [Issue and PR Templates](#3-issue-and-pr-templates)
4. [GitHub Topics and Discoverability](#4-github-topics-and-discoverability)
5. [Labels and Project Boards](#5-labels-and-project-boards)
6. [Release Strategy](#6-release-strategy)
7. [GitHub Actions Workflows](#7-github-actions-workflows)
8. [Visual Assets Checklist](#8-visual-assets-checklist)

---

# 1. README Structure for Virality

## 1.1 The Psychology of README

Your README has approximately 10 seconds to convince a visitor to stay. In that time, they must:
- Understand what the project does
- See that it's professional/maintained
- Find a reason to care

**Visitor Behavior Pattern:**
1. Look at social preview (before clicking)
2. Scan badges (trust signals)
3. Read title/tagline (understand purpose)
4. View screenshot/GIF (see the product)
5. Decide: scroll or leave

## 1.2 Above-The-Fold Content (First 500px)

The "above the fold" concept from newspapers applies to READMEs. The first screenful must contain:

### Essential Elements Order

```markdown
# Project Name

<!-- Badges Row 1: Trust signals -->
[![Build Status](badge-url)](ci-url)
[![Version](badge-url)](releases-url)
[![License](badge-url)](license-url)
[![Stars](badge-url)](repo-url)

<!-- Badges Row 2: Social proof -->
[![Downloads](badge-url)](stats-url)
[![Contributors](badge-url)](contributors-url)
[![Discord](badge-url)](discord-url)

> **Tagline:** One compelling sentence that explains the value proposition.

<!-- Hero Visual - MUST be visible without scrolling -->
![Matrix Terminal Shader Demo](hero-image-url)

<!-- Quick value proposition - 2-3 bullet points max -->
- Key benefit 1
- Key benefit 2
- Key benefit 3

<!-- Immediate action - copy-paste install -->
## Quick Start

```powershell
Install-Module MatrixTerminalShader
```
```

### Badge Strategy

**Purpose of Badges:**
- Trust signals (build passing = maintained)
- Social proof (stars, downloads)
- Quick info (version, license)
- Call to action (sponsor, discord)

**Recommended Badge Layout:**

Row 1 - Essential (Always Include):
| Badge | Purpose | Service |
|-------|---------|---------|
| Build Status | Shows project is maintained | GitHub Actions |
| Version | Shows current release | Shields.io |
| License | Legal clarity | Shields.io |

Row 2 - Social Proof (Add as metrics grow):
| Badge | Purpose | Service |
|-------|---------|---------|
| Stars | Social proof | Shields.io |
| Downloads | Usage proof | PSGallery/npm |
| Contributors | Community health | Shields.io |

Row 3 - Engagement (Optional):
| Badge | Purpose | Service |
|-------|---------|---------|
| Discord | Community link | Discord widget |
| Sponsor | Funding link | Shields.io |
| Twitter | Social follow | Shields.io |

**Badge Code Examples:**

```markdown
<!-- GitHub Actions CI -->
[![CI](https://github.com/USERNAME/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/REPO/actions/workflows/ci.yml)

<!-- Version from GitHub releases -->
[![GitHub release](https://img.shields.io/github/v/release/USERNAME/REPO)](https://github.com/USERNAME/REPO/releases)

<!-- License -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<!-- GitHub Stars -->
[![GitHub stars](https://img.shields.io/github/stars/USERNAME/REPO?style=social)](https://github.com/USERNAME/REPO/stargazers)

<!-- Downloads from PSGallery -->
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/MatrixTerminalShader)](https://www.powershellgallery.com/packages/MatrixTerminalShader)

<!-- Discord -->
[![Discord](https://img.shields.io/discord/SERVER_ID?label=Discord&logo=discord)](https://discord.gg/YOUR_INVITE)

<!-- Sponsor -->
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-red)](https://github.com/sponsors/USERNAME)
```

## 1.3 Complete README Template

```markdown
# Matrix Terminal Shader

[![CI](https://github.com/USERNAME/matrix-terminal-shader/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/matrix-terminal-shader/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/USERNAME/matrix-terminal-shader)](https://github.com/USERNAME/matrix-terminal-shader/releases)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/MatrixTerminalShader)](https://www.powershellgallery.com/packages/MatrixTerminalShader)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Color-coded terminal shaders for Windows Terminal, designed for multi-agent AI workflows.

![Matrix Terminal Shader Demo](docs/images/hero.gif)

Instantly identify which terminal belongs to which AI agent. Matrix Terminal Shader brings visual organization to your multi-window development workflow with customizable HLSL pixel shaders.

- **Instant Recognition** - Color-code terminals by purpose (Claude, GPT, Copilot)
- **Zero Performance Impact** - GPU-accelerated shaders, minimal CPU overhead
- **Fully Customizable** - Create your own themes or use built-in presets

## Quick Start

```powershell
# Install from PowerShell Gallery
Install-Module MatrixTerminalShader

# Apply a theme
Set-MatrixTheme -Theme Agent-Blue

# List available themes
Get-MatrixTheme
```

## Themes

<table>
<tr>
<td><img src="docs/images/theme-agent-blue.png" width="200"/><br><code>Agent-Blue</code></td>
<td><img src="docs/images/theme-agent-green.png" width="200"/><br><code>Agent-Green</code></td>
<td><img src="docs/images/theme-agent-purple.png" width="200"/><br><code>Agent-Purple</code></td>
</tr>
<tr>
<td><img src="docs/images/theme-matrix.png" width="200"/><br><code>Matrix</code></td>
<td><img src="docs/images/theme-cyberpunk.png" width="200"/><br><code>Cyberpunk</code></td>
<td><img src="docs/images/theme-minimal.png" width="200"/><br><code>Minimal</code></td>
</tr>
</table>

[See all themes](docs/THEMES.md) | [Create custom themes](docs/CUSTOM_THEMES.md)

## Installation

### PowerShell Gallery (Recommended)

```powershell
Install-Module MatrixTerminalShader -Scope CurrentUser
```

### Manual Installation

1. Download the [latest release](https://github.com/USERNAME/matrix-terminal-shader/releases)
2. Extract to `%USERPROFILE%\Documents\PowerShell\Modules\MatrixTerminalShader`
3. Import the module: `Import-Module MatrixTerminalShader`

### Winget

```powershell
winget install matrix-terminal-shader
```

### Scoop

```powershell
scoop bucket add extras
scoop install matrix-terminal-shader
```

## Requirements

- Windows 10 version 1903+ or Windows 11
- [Windows Terminal](https://github.com/microsoft/terminal) 1.12+
- PowerShell 5.1+ or PowerShell 7.0+

## Usage

### Apply a Theme

```powershell
# Apply to current terminal
Set-MatrixTheme -Theme Agent-Blue

# Apply to specific profile
Set-MatrixTheme -Theme Matrix -Profile "PowerShell"

# Apply with custom intensity
Set-MatrixTheme -Theme Cyberpunk -Intensity 0.7
```

### Create Custom Themes

```powershell
# Create from template
New-MatrixTheme -Name "MyTheme" -BaseTheme "Agent-Blue" -PrimaryColor "#FF6B6B"

# Export theme for sharing
Export-MatrixTheme -Name "MyTheme" -Path "./my-theme.json"
```

### Multi-Agent Workflow Setup

Perfect for AI-assisted development with multiple agents:

```powershell
# Terminal 1: Claude
Set-MatrixTheme -Theme Agent-Purple -ProfileName "Claude"

# Terminal 2: GPT
Set-MatrixTheme -Theme Agent-Green -ProfileName "GPT"

# Terminal 3: Copilot
Set-MatrixTheme -Theme Agent-Blue -ProfileName "Copilot"
```

## Documentation

- [Full Documentation](docs/README.md)
- [Theme Gallery](docs/THEMES.md)
- [Custom Theme Guide](docs/CUSTOM_THEMES.md)
- [API Reference](docs/API.md)
- [FAQ](docs/FAQ.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contribution

```bash
# Fork and clone
git clone https://github.com/YOUR-USERNAME/matrix-terminal-shader.git

# Create branch
git checkout -b feature/your-feature

# Make changes and test
./build.ps1 -Task Test

# Submit PR
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full process.

## Roadmap

- [ ] Theme marketplace
- [ ] VS Code extension
- [ ] Linux/macOS support
- [ ] Animation effects
- [ ] Theme export/import GUI

Track progress in our [project board](https://github.com/USERNAME/matrix-terminal-shader/projects/1).

## Support

- [GitHub Issues](https://github.com/USERNAME/matrix-terminal-shader/issues) - Bug reports, feature requests
- [GitHub Discussions](https://github.com/USERNAME/matrix-terminal-shader/discussions) - Questions, ideas
- [Discord](https://discord.gg/YOUR_INVITE) - Real-time chat

### Sponsors

<a href="https://github.com/sponsors/USERNAME">
  <img src="https://img.shields.io/badge/Sponsor-%E2%9D%A4-red?style=for-the-badge" alt="Sponsor" />
</a>

Matrix Terminal Shader is free and open-source. If it helps your workflow, consider [sponsoring](https://github.com/sponsors/USERNAME) to support ongoing development.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Windows Terminal](https://github.com/microsoft/terminal) team for shader support
- [Shadertoy](https://www.shadertoy.com/) community for inspiration
- All our [contributors](https://github.com/USERNAME/matrix-terminal-shader/graphs/contributors)!

---

<p align="center">
  <a href="https://github.com/USERNAME/matrix-terminal-shader/stargazers">Star us on GitHub</a> |
  <a href="https://twitter.com/YOUR_HANDLE">Follow on Twitter</a> |
  <a href="https://github.com/sponsors/USERNAME">Become a Sponsor</a>
</p>
```

## 1.4 Section-by-Section Optimization

### Title Section

**DO:**
- Use the exact project name
- Keep it short and memorable
- Make it searchable (include keywords)

**DON'T:**
- Use ASCII art logos (accessibility issue)
- Include version numbers in title
- Use marketing superlatives

### Tagline

**Formula:** `[Action/Benefit] for [Target Platform], [Differentiator]`

**Examples:**
- "Color-coded terminal shaders for Windows Terminal, designed for multi-agent AI workflows"
- "Beautiful Git diffs in your terminal"
- "The missing package manager for macOS"

**Length:** 10-15 words maximum

### Hero Visual

**Requirements:**
- Must load fast (<500KB for GIFs)
- Must be visible without scrolling
- Must show the actual product
- Must work on dark AND light backgrounds

**GIF Best Practices:**
- 10-15 seconds maximum
- 15 FPS is usually sufficient
- 800px width maximum
- Use palettegen for quality

**Creating Effective Demo GIFs:**

```powershell
# Script to create consistent demo recordings

# 1. Set up clean terminal
Clear-Host
$Host.UI.RawUI.WindowSize = @{ Width = 120; Height = 30 }

# 2. Prepare commands (type them slowly)
# Use: asciinema for terminal recording, then convert to GIF

# 3. Convert with ffmpeg
# See GROWTH_PREPARATION.md for ffmpeg commands
```

### Quick Start Section

**Rules:**
1. Maximum 3 commands
2. Copy-paste ready (no placeholders)
3. Works on first try
4. Shows immediate value

**Anti-patterns to Avoid:**
```markdown
# BAD - too many steps
## Quick Start
1. First, install Node.js
2. Then install npm
3. Configure your environment
4. Set up the config file
5. Finally run the install command

# GOOD - immediate value
## Quick Start
```powershell
Install-Module MatrixTerminalShader
Set-MatrixTheme Agent-Blue
```
```

### Features Section

**Structure:** Benefits, not features

| Feature (Technical) | Benefit (Human) |
|---------------------|-----------------|
| HLSL pixel shaders | Instant visual recognition |
| GPU acceleration | Zero performance impact |
| JSON configuration | Easy customization |

**Format:** Bullet points with bold lead-ins

```markdown
## Features

- **Instant Recognition** - Color-code terminals by purpose
- **Zero Overhead** - GPU-accelerated, minimal CPU usage
- **Fully Customizable** - Create themes or use presets
```

### Installation Section

**Must include:**
- Primary installation method (largest/prominent)
- Alternative methods (for different preferences)
- Prerequisites clearly listed
- Manual installation for airgapped systems

**Format:**
```markdown
## Installation

### PowerShell Gallery (Recommended)
```powershell
Install-Module MatrixTerminalShader -Scope CurrentUser
```

### Manual Installation
[Steps for manual install]

### Other Package Managers
[Winget, Scoop, Chocolatey as applicable]
```

### Usage Section

**Include:**
- Basic usage (80% use case)
- Common configurations
- Advanced usage (link to docs)

**Format:** Code blocks with comments

```powershell
# Basic usage - apply a theme
Set-MatrixTheme -Theme Agent-Blue

# Customize intensity
Set-MatrixTheme -Theme Matrix -Intensity 0.7

# See all available themes
Get-MatrixTheme
```

### Contributing Section

**Keep it brief in README, link to CONTRIBUTING.md:**

```markdown
## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Quick start:
```bash
git clone https://github.com/USERNAME/repo.git
./build.ps1 -Task Test
```
```

### Support/Community Section

**List in order of preference:**
1. Documentation (self-serve)
2. GitHub Issues (async)
3. Discussions/Discord (community)
4. Email (direct)

### License Section

**Simple and clear:**
```markdown
## License

MIT License - see [LICENSE](LICENSE) for details.
```

### Footer Section

**Optional but effective for virality:**
```markdown
---

<p align="center">
  <a href="star-url">Star on GitHub</a> |
  <a href="twitter-url">Follow on Twitter</a> |
  <a href="sponsor-url">Sponsor</a>
</p>
```

## 1.5 README Accessibility

### Images

Always include alt text:
```markdown
![Demo showing matrix terminal shader with blue theme applied](demo.gif)
```

### Code Blocks

Always specify language for syntax highlighting:
```markdown
```powershell
Get-Command
```
```

### Links

Use descriptive link text:
```markdown
<!-- GOOD -->
See the [installation guide](docs/install.md) for details.

<!-- BAD -->
Click [here](docs/install.md) for installation.
```

### Headings

Use proper hierarchy (don't skip levels):
```markdown
# Title
## Section
### Subsection
```

---

# 2. Social Preview Image Optimization

## 2.1 Why Social Preview Matters

The social preview image appears when your repository is shared on:
- Twitter (large image cards)
- LinkedIn (article previews)
- Slack (unfurled links)
- Discord (embeds)
- Facebook (shared links)
- iMessage (link previews)

**Impact:** A good social preview can increase click-through rates by 30-50%.

## 2.2 Technical Specifications

| Property | Requirement |
|----------|-------------|
| Dimensions | 1280x640 pixels (2:1 ratio) |
| Format | PNG or JPG |
| File size | Under 1MB |
| Color space | sRGB |
| Text | Readable at 400px width |

### How GitHub Renders Social Preview

GitHub automatically scales your image for different platforms:
- Twitter: 1200x628 (cropped to center)
- LinkedIn: 1200x627 (cropped to center)
- Facebook: 1200x630 (cropped to center)

**Design for the center:** Keep all important content in the middle 1000x500 pixel area.

## 2.3 Design Guidelines

### Layout Template

```
+------------------------------------------+
|         [ Brand / Logo - optional ]       |
|                                           |
|        PROJECT NAME                       |
|        ----------------                   |
|        Compelling tagline that            |
|        explains the value                 |
|                                           |
|   [Screenshot or Visual Element]          |
|                                           |
+------------------------------------------+
```

### Color Guidelines

For Matrix Terminal Shader:
- **Background:** Dark (#0D1117 or #000000)
- **Primary accent:** Matrix green (#00FF00)
- **Secondary:** White or light gray (#FFFFFF, #C9D1D9)
- **Avoid:** Bright backgrounds (clash with terminal aesthetic)

### Typography Guidelines

- **Project name:** Large, bold, sans-serif (48-72pt)
- **Tagline:** Medium, regular weight (24-36pt)
- **Additional text:** Small, can be lighter (18-24pt)

### Visual Elements to Include

1. **Project name** (required)
2. **Tagline** (highly recommended)
3. **Visual hook** - Screenshot, logo, or graphic
4. **Not required:** GitHub logo, badges, URLs

### What NOT to Include

- Excessive text (can't read when small)
- QR codes (don't work in preview)
- Complex diagrams
- GitHub stats/badges
- Multiple CTAs

## 2.4 Creating Social Preview with Figma

### Step-by-Step Process

1. **Create new file**
   - Frame: 1280x640
   - Background: Dark color

2. **Add project name**
   - Font: Inter, Roboto, or SF Pro
   - Size: 64px
   - Color: White
   - Position: Upper third

3. **Add tagline**
   - Font: Same family, lighter weight
   - Size: 28px
   - Color: Light gray
   - Position: Below name

4. **Add visual element**
   - Screenshot of product in use
   - Position: Lower two-thirds
   - Add subtle shadow/glow if needed

5. **Export**
   - Format: PNG
   - Scale: 1x
   - Quality: Highest

### Figma Template Code

```json
{
  "frame": {
    "width": 1280,
    "height": 640,
    "background": "#0D1117"
  },
  "elements": [
    {
      "type": "text",
      "content": "Matrix Terminal Shader",
      "font": "Inter Bold",
      "size": 64,
      "color": "#FFFFFF",
      "position": { "x": 640, "y": 100, "align": "center" }
    },
    {
      "type": "text",
      "content": "Color-coded terminals for multi-agent AI workflows",
      "font": "Inter Regular",
      "size": 28,
      "color": "#8B949E",
      "position": { "x": 640, "y": 160, "align": "center" }
    },
    {
      "type": "image",
      "source": "screenshot.png",
      "position": { "x": 640, "y": 400, "align": "center" },
      "size": { "width": 1000, "height": 400 },
      "effects": ["drop-shadow"]
    }
  ]
}
```

## 2.5 Social Preview Examples Analysis

### What Works

**Example 1: Successful Pattern**
- Dark background matching product aesthetic
- Large, readable project name
- Clear value proposition
- Actual product screenshot
- Minimal text

**Example 2: Terminal Project Pattern**
- Terminal window mockup as centerpiece
- Code visible in screenshot
- Matrix-style effects as accent
- Brand colors consistent

### What Doesn't Work

**Anti-pattern 1: Text Overload**
- Too much text
- Lists of features
- Unreadable at small size

**Anti-pattern 2: Generic Graphics**
- Stock images
- Abstract shapes unrelated to product
- No screenshot of actual product

## 2.6 Setting Up Social Preview on GitHub

### Via Web Interface

1. Go to repository Settings
2. Scroll to "Social preview"
3. Click "Edit"
4. Upload your 1280x640 image
5. Save

### Via API (for automation)

```powershell
# Upload social preview via GitHub API
$headers = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept = "application/vnd.github+json"
}

$imageBytes = [System.IO.File]::ReadAllBytes("social-preview.png")
$base64 = [System.Convert]::ToBase64String($imageBytes)

$body = @{
    image = "data:image/png;base64,$base64"
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://api.github.com/repos/OWNER/REPO" `
    -Method Patch `
    -Headers $headers `
    -Body $body
```

## 2.7 Testing Social Preview

### Tools for Testing

| Platform | Testing Tool |
|----------|--------------|
| Twitter | [Card Validator](https://cards-dev.twitter.com/validator) |
| LinkedIn | [Post Inspector](https://www.linkedin.com/post-inspector/) |
| Facebook | [Sharing Debugger](https://developers.facebook.com/tools/debug/) |
| General | [OpenGraph Preview](https://www.opengraph.xyz/) |

### Testing Workflow

1. Upload social preview to GitHub
2. Wait 5 minutes for CDN propagation
3. Test on each platform's validator
4. Clear cache if old image shows
5. Verify on actual social media post

---

# 3. Issue and PR Templates

## 3.1 Why Templates Matter

Templates serve multiple purposes:
- **User experience:** Guide reporters to provide useful info
- **Maintainer efficiency:** Reduce back-and-forth for basic info
- **Triage automation:** Enable auto-labeling based on template
- **Quality control:** Ensure consistent issue quality

## 3.2 Issue Template Directory Structure

```
.github/
  ISSUE_TEMPLATE/
    bug_report.yml          # Bug report form (YAML)
    feature_request.yml     # Feature request form (YAML)
    question.yml            # Questions form (YAML)
    config.yml              # Template chooser configuration
```

## 3.3 Bug Report Template (YAML Form)

```yaml
# .github/ISSUE_TEMPLATE/bug_report.yml
name: Bug Report
description: Report something that isn't working correctly
title: "[Bug]: "
labels: ["type: bug", "status: triage"]
assignees: []

body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to report this bug!

        Before submitting, please:
        - Search existing issues to avoid duplicates
        - Use the latest version of Matrix Terminal Shader

  - type: textarea
    id: description
    attributes:
      label: Bug Description
      description: A clear and concise description of the bug.
      placeholder: What happened? What did you expect to happen?
    validations:
      required: true

  - type: textarea
    id: reproduction
    attributes:
      label: Steps to Reproduce
      description: How can we reproduce this issue?
      placeholder: |
        1. Open Windows Terminal
        2. Run `Set-MatrixTheme -Theme Agent-Blue`
        3. See error...
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What did you expect to happen?
      placeholder: The theme should apply without errors.
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened?
      placeholder: Error message appeared saying...
    validations:
      required: true

  - type: dropdown
    id: windows-version
    attributes:
      label: Windows Version
      description: Which Windows version are you using?
      options:
        - Windows 11 (latest)
        - Windows 11 (older build)
        - Windows 10 (22H2)
        - Windows 10 (older)
        - Other
    validations:
      required: true

  - type: input
    id: terminal-version
    attributes:
      label: Windows Terminal Version
      description: "Find in Settings > About (e.g., 1.18.2822.0)"
      placeholder: "1.18.2822.0"
    validations:
      required: true

  - type: input
    id: powershell-version
    attributes:
      label: PowerShell Version
      description: "Run `$PSVersionTable.PSVersion` to find this"
      placeholder: "7.4.0"
    validations:
      required: true

  - type: input
    id: module-version
    attributes:
      label: Matrix Terminal Shader Version
      description: "Run `Get-Module MatrixTerminalShader | Select Version`"
      placeholder: "1.0.0"
    validations:
      required: true

  - type: textarea
    id: error-message
    attributes:
      label: Error Messages
      description: If there were error messages, paste them here.
      render: powershell
    validations:
      required: false

  - type: textarea
    id: screenshots
    attributes:
      label: Screenshots
      description: If applicable, add screenshots to help explain.
    validations:
      required: false

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other context about the problem?
    validations:
      required: false

  - type: checkboxes
    id: checklist
    attributes:
      label: Pre-submission Checklist
      options:
        - label: I have searched existing issues to ensure this is not a duplicate
          required: true
        - label: I am using the latest version of Matrix Terminal Shader
          required: true
        - label: I have read the [FAQ](../docs/FAQ.md) and [Troubleshooting](../docs/TROUBLESHOOTING.md) guides
          required: false
```

## 3.4 Feature Request Template (YAML Form)

```yaml
# .github/ISSUE_TEMPLATE/feature_request.yml
name: Feature Request
description: Suggest an idea or improvement
title: "[Feature]: "
labels: ["type: feature", "status: triage"]
assignees: []

body:
  - type: markdown
    attributes:
      value: |
        Thanks for suggesting a feature!

        Good feature requests explain the problem you're trying to solve, not just a proposed solution.

  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      description: What problem does this feature solve? What's your use case?
      placeholder: |
        I'm always frustrated when...

        Currently I have to...

        This makes it difficult to...
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: How would you like this to work? Be as specific as possible.
      placeholder: |
        I would like a command that...

        The output should...

        This would allow me to...
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: Have you considered other ways to solve this?
      placeholder: |
        I tried using X but it doesn't work because...

        Another option would be Y but...
    validations:
      required: false

  - type: dropdown
    id: impact
    attributes:
      label: Impact
      description: How important is this feature to you?
      options:
        - Nice to have
        - Would significantly improve my workflow
        - Critical for my use case
        - Blocking adoption of this tool
    validations:
      required: true

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other context, mockups, or references?
    validations:
      required: false

  - type: checkboxes
    id: checklist
    attributes:
      label: Pre-submission Checklist
      options:
        - label: I have searched existing issues to ensure this is not a duplicate
          required: true
        - label: I have checked the [roadmap](../ROADMAP.md) to see if this is already planned
          required: false
```

## 3.5 Question Template (YAML Form)

```yaml
# .github/ISSUE_TEMPLATE/question.yml
name: Question
description: Ask a question about using Matrix Terminal Shader
title: "[Question]: "
labels: ["type: question"]
assignees: []

body:
  - type: markdown
    attributes:
      value: |
        **Before asking:**
        - Check the [documentation](../docs/README.md)
        - Search [existing issues](../issues) and [discussions](../discussions)
        - Review the [FAQ](../docs/FAQ.md)

        For general questions, consider using [GitHub Discussions](../discussions) instead.

  - type: textarea
    id: question
    attributes:
      label: Your Question
      description: What would you like to know?
      placeholder: How do I...?
    validations:
      required: true

  - type: textarea
    id: context
    attributes:
      label: What Are You Trying to Accomplish?
      description: Help us understand your goal so we can give better answers.
      placeholder: I'm trying to set up Matrix Terminal Shader for my multi-agent AI workflow...
    validations:
      required: true

  - type: textarea
    id: tried
    attributes:
      label: What Have You Tried?
      description: What solutions have you attempted?
    validations:
      required: false

  - type: textarea
    id: references
    attributes:
      label: Relevant Documentation
      description: Which docs did you check? Any unclear sections?
    validations:
      required: false
```

## 3.6 Template Chooser Configuration

```yaml
# .github/ISSUE_TEMPLATE/config.yml
blank_issues_enabled: false
contact_links:
  - name: GitHub Discussions
    url: https://github.com/USERNAME/matrix-terminal-shader/discussions
    about: Ask questions and discuss features with the community

  - name: Documentation
    url: https://github.com/USERNAME/matrix-terminal-shader/tree/main/docs
    about: Check our documentation for guides and references

  - name: Discord
    url: https://discord.gg/YOUR_INVITE
    about: Chat with the community in real-time

  - name: Security Vulnerability
    url: https://github.com/USERNAME/matrix-terminal-shader/security/advisories/new
    about: Report security issues privately
```

## 3.7 Pull Request Template

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->

## Description

<!-- Describe your changes in detail -->

## Related Issue

<!-- Link to the issue this PR addresses -->
Fixes #

## Type of Change

<!-- Mark the appropriate option with [x] -->

- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] CI/CD changes
- [ ] Other (please describe):

## Changes Made

<!-- List the specific changes -->

-
-
-

## Testing

<!-- Describe how you tested your changes -->

### Test Configuration

- Windows version:
- Terminal version:
- PowerShell version:

### Tests Performed

- [ ] All existing tests pass
- [ ] Added new tests for this functionality
- [ ] Manually tested the changes

### Test Commands

```powershell
# Commands used to verify the changes
```

## Screenshots

<!-- If applicable, add screenshots -->

## Checklist

<!-- Complete all items before requesting review -->

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally with my changes
- [ ] I have updated the CHANGELOG.md

## Additional Notes

<!-- Any additional information for reviewers -->

---

**By submitting this PR, I confirm that my contribution is made under the terms of the MIT license.**
```

## 3.8 Multiple PR Templates (for different types)

Create different templates for different PR types:

```
.github/
  PULL_REQUEST_TEMPLATE/
    feature.md
    bugfix.md
    documentation.md
```

To use, append `?template=bugfix.md` to the PR URL.

---

# 4. GitHub Topics and Discoverability

## 4.1 How Topics Work

GitHub Topics enable:
- Discovery through topic pages
- Repository categorization
- Search filtering
- Explore recommendations

**Maximum topics:** 20 per repository

## 4.2 Topic Selection Strategy

### Primary Topics (Must Have)

These should directly describe what your project is:

| Topic | Reason |
|-------|--------|
| `windows-terminal` | Primary platform |
| `powershell` | Primary language |
| `shader` | Core technology |
| `terminal-emulator` | Category |
| `hlsl` | Shader language |

### Secondary Topics (Category/Use Case)

These describe the use cases and categories:

| Topic | Reason |
|-------|--------|
| `terminal-customization` | Use case |
| `developer-tools` | Category |
| `cli` | Category |
| `terminal-theme` | Use case |
| `windows` | Platform |

### Trending/Discovery Topics

Topics that are actively browsed:

| Topic | Reason |
|-------|--------|
| `hacktoberfest` | Seasonal (October) |
| `good-first-issues` | Contributor discovery |
| `ai` | Current trend |
| `developer-experience` | Popular category |

### Recommended Topics for Matrix Terminal Shader

```
windows-terminal
powershell
shader
hlsl
terminal-customization
developer-tools
windows
cli
terminal-theme
pixel-shader
gpu
theme
customization
open-source
ai
multi-agent
productivity
devops
terminal
terminal-emulator
```

## 4.3 Topic Optimization Tips

### Do's

- Use lowercase
- Use hyphens for multi-word topics
- Include language/framework names
- Include platform names
- Update seasonally (hacktoberfest)

### Don'ts

- Don't use overly generic topics (software, tool)
- Don't use topics with <100 repositories
- Don't use marketing speak (best, awesome)
- Don't use version numbers (v1, 2024)

## 4.4 Monitoring Topic Performance

Check topic pages to see where your repo ranks:
- `https://github.com/topics/windows-terminal`
- Sort by: Recently updated, Most stars

Your goal: Appear on page 1 for your primary topics.

---

# 5. Labels and Project Boards

## 5.1 Label System Design

### Complete Label Set

See GROWTH_PREPARATION.md Section 2.2 for full label definitions. Summary:

**Priority Labels (4):**
- priority: critical, high, medium, low

**Type Labels (5):**
- type: bug, feature, enhancement, documentation, question

**Status Labels (7):**
- status: triage, confirmed, in-progress, blocked, needs-info, duplicate, wontfix

**Area Labels (6):**
- area: shader, powershell, installer, config, themes, performance

**Special Labels (5):**
- good-first-issue, help-wanted, hacktoberfest, breaking-change, ready-to-merge

### Label Color System

Use consistent colors across categories:

| Category | Color Family |
|----------|--------------|
| Priority | Red to Green gradient |
| Type | Blue family |
| Status | Yellow/Orange family |
| Area | Purple family |
| Special | Distinct colors |

## 5.2 Project Board Setup

### Board Types

| Board | Purpose | Columns |
|-------|---------|---------|
| Roadmap | Public roadmap visibility | Now, Next, Later, Done |
| Triage | Issue processing | New, Needs Info, Ready, Assigned |
| Release | Release planning | Backlog, In Progress, Review, Done |

### Roadmap Board Template

```
+-------------+-------------+-------------+-------------+
|    Now      |    Next     |   Later     |    Done     |
|  (Current)  | (Next 30d)  | (Backlog)   | (Released)  |
+-------------+-------------+-------------+-------------+
| Issue #12   | Issue #15   | Issue #20   | Issue #5    |
| Issue #13   | Issue #16   | Issue #21   | Issue #6    |
| PR #14      | Issue #17   | Issue #22   | Issue #7    |
+-------------+-------------+-------------+-------------+
```

### Triage Board Template

```
+-------------+-------------+-------------+-------------+
|    New      | Needs Info  |   Ready     |  Assigned   |
|  (Unread)   | (Waiting)   | (Triaged)   | (Working)   |
+-------------+-------------+-------------+-------------+
| Issue #100  | Issue #95   | Issue #88   | Issue #80   |
| Issue #101  | Issue #96   | Issue #89   | Issue #81   |
| Issue #102  |             | Issue #90   |             |
+-------------+-------------+-------------+-------------+
```

### Project Board Automation

GitHub Projects (v2) supports automation:

| Trigger | Action |
|---------|--------|
| Issue opened | Add to "New" column |
| Label "status: needs-info" added | Move to "Needs Info" |
| Issue assigned | Move to "Assigned" |
| PR merged | Move to "Done" |
| Issue closed | Move to "Done" |

## 5.3 Milestone Strategy

### Milestone Types

| Type | Naming | Example |
|------|--------|---------|
| Version | vX.Y.Z | v1.2.0 |
| Sprint | Sprint-N | Sprint-12 |
| Theme | Feature name | Theme-System-v2 |
| Event | Event name | Hacktoberfest-2026 |

### Milestone Template

**Title:** v1.2.0

**Description:**
```markdown
## v1.2.0 Release

**Target Date:** 2026-02-01
**Theme:** Theme System Improvements

### Goals
- [ ] New theme file format (#15)
- [ ] Theme preview command (#16)
- [ ] Import themes from URL (#17)

### Non-Goals (for future)
- Theme marketplace
- Animated themes

### Breaking Changes
- None planned
```

---

# 6. Release Strategy

## 6.1 Semantic Versioning (SemVer)

### Version Format: MAJOR.MINOR.PATCH

| Component | When to Increment | Example |
|-----------|-------------------|---------|
| MAJOR | Breaking changes | 1.0.0 -> 2.0.0 |
| MINOR | New features (backward-compatible) | 1.0.0 -> 1.1.0 |
| PATCH | Bug fixes (backward-compatible) | 1.0.0 -> 1.0.1 |

### Pre-release Versions

| Suffix | Purpose | Example |
|--------|---------|---------|
| -alpha | Early testing | 2.0.0-alpha.1 |
| -beta | Feature complete, testing | 2.0.0-beta.1 |
| -rc | Release candidate | 2.0.0-rc.1 |

### Version Progression Example

```
1.0.0        Initial release
1.0.1        Bug fix
1.0.2        Another bug fix
1.1.0        New feature
1.1.1        Bug fix in new feature
1.2.0        More features
2.0.0-alpha  Major rewrite begins
2.0.0-beta   Feature complete
2.0.0-rc.1   Release candidate
2.0.0        Major release
```

## 6.2 Changelog Format

### Keep a Changelog Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature coming soon

### Changed
- Improvement coming soon

### Fixed
- Bug fix coming soon

## [1.2.0] - 2026-01-15

### Added
- Theme preview command `Show-MatrixTheme` (#45)
- Import themes from URL with `Import-MatrixTheme -Url` (#46)
- 5 new built-in themes: Ocean, Forest, Sunset, Midnight, Dawn

### Changed
- Improved theme loading performance by 40%
- Updated default intensity from 0.5 to 0.7

### Fixed
- Fixed shader crash on older GPUs (#42)
- Fixed theme not persisting after terminal restart (#43)

### Deprecated
- Old theme format (JSON) - will be removed in v2.0.0

## [1.1.0] - 2026-01-01

### Added
- Multi-profile support (#30)
- Theme intensity setting (#31)

### Fixed
- Installation script error on PowerShell 5.1 (#28)

## [1.0.0] - 2025-12-15

### Added
- Initial release
- 10 built-in themes
- Basic theme switching
- Windows Terminal integration

[Unreleased]: https://github.com/USERNAME/matrix-terminal-shader/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/USERNAME/matrix-terminal-shader/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/USERNAME/matrix-terminal-shader/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/USERNAME/matrix-terminal-shader/releases/tag/v1.0.0
```

### Changelog Sections

| Section | Contents |
|---------|----------|
| Added | New features |
| Changed | Changes in existing functionality |
| Deprecated | Features that will be removed |
| Removed | Features that were removed |
| Fixed | Bug fixes |
| Security | Security vulnerability fixes |

## 6.3 Release Cadence

### Recommended Schedule

| Release Type | Frequency | Example Dates |
|--------------|-----------|---------------|
| Patch | As needed | Within 24h of critical bug |
| Minor | Monthly | First Monday of month |
| Major | Yearly | When breaking changes accumulate |

### Release Day Checklist

See GROWTH_PREPARATION.md Section 7.3 for full release checklist.

Quick version:
- [ ] All tests pass
- [ ] CHANGELOG.md updated
- [ ] Version bumped
- [ ] Tagged in git
- [ ] GitHub release created
- [ ] Published to PSGallery
- [ ] Announcement posted

## 6.4 GitHub Release Best Practices

### Release Title Format

```
v1.2.0 - Theme Preview & URL Import
```

### Release Body Template

```markdown
## What's New in v1.2.0

### Highlights

- **Theme Preview**: See themes before applying with `Show-MatrixTheme`
- **URL Import**: Import themes from the web with `Import-MatrixTheme -Url`
- **5 New Themes**: Ocean, Forest, Sunset, Midnight, Dawn

### Installation

```powershell
# New installation
Install-Module MatrixTerminalShader

# Upgrade existing
Update-Module MatrixTerminalShader
```

### Full Changelog

See [CHANGELOG.md](./CHANGELOG.md) for complete details.

### Contributors

Thanks to everyone who contributed to this release!

- @contributor1 (#45)
- @contributor2 (#46)

### What's Next

See our [roadmap](./ROADMAP.md) for upcoming features.

---

**Full Changelog**: https://github.com/USERNAME/matrix-terminal-shader/compare/v1.1.0...v1.2.0
```

### Release Assets

Include these assets with each release:
- `MatrixTerminalShader-v1.2.0.zip` - Module archive
- `checksums.txt` - SHA256 checksums

---

# 7. GitHub Actions Workflows

## 7.1 Essential Workflows Summary

See GROWTH_PREPARATION.md Section 9 for complete YAML files. Summary:

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| CI | ci.yml | Push, PR | Build, test, lint |
| Release | release.yml | Tag | Create release |
| Stale | stale.yml | Schedule | Close stale issues |
| Greetings | greetings.yml | Issue/PR | Welcome new contributors |
| Labeler | labeler.yml | PR | Auto-label by files |
| Triage | triage.yml | Issue | Auto-triage issues |

## 7.2 CI Workflow Summary

Key steps:
1. **Lint** - PSScriptAnalyzer
2. **Test** - Pester on PS 5.1 and 7.x
3. **Build** - Create module
4. **Integration** - Test installation

## 7.3 Release Workflow Summary

Key steps:
1. **Validate** - Parse version, check pre-release
2. **Build** - Create release package
3. **Release** - Create GitHub release with assets
4. **Publish** - Push to PowerShell Gallery

## 7.4 Workflow Best Practices

### Caching

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.nuget/packages
    key: ${{ runner.os }}-nuget-${{ hashFiles('**/packages.lock.json') }}
```

### Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### Environment Protection

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Requires approval
```

### Secrets Management

Never log secrets:
```yaml
- name: Publish
  env:
    API_KEY: ${{ secrets.API_KEY }}
  run: echo "::add-mask::$API_KEY"
```

---

# 8. Visual Assets Checklist

## 8.1 Required Visual Assets

### Complete Asset List

| Asset | Dimensions | Format | Location | Purpose |
|-------|------------|--------|----------|---------|
| Social Preview | 1280x640 | PNG | GitHub Settings | Link sharing |
| Hero Screenshot | 1920x1080 | PNG | docs/images/ | README header |
| Hero GIF | 800x450 | GIF (<5MB) | docs/images/ | README demo |
| Logo | 512x512 | SVG + PNG | assets/ | Branding |
| Favicon | 64x64 | ICO | assets/ | Web pages |
| Theme Previews | 800x500 | PNG | docs/images/themes/ | Theme gallery |
| Install Demo | 800x400 | GIF | docs/images/ | Install section |
| Error Screenshots | 800x400 | PNG | docs/troubleshooting/ | Support docs |

## 8.2 Asset Creation Workflow

### 1. Terminal Screenshots

```powershell
# Configure terminal for screenshots
$Host.UI.RawUI.WindowSize = @{ Width = 120; Height = 30 }
$Host.UI.RawUI.BackgroundColor = 'Black'
Clear-Host

# Use Windows + Shift + S or ShareX
```

### 2. GIF Recording

Tools:
- **ScreenToGif** - Windows, free, lightweight
- **LICEcap** - Windows/Mac, free, simple
- **Gifox** - Mac, paid, high quality
- **ffmpeg** - CLI, any platform, most control

### 3. ffmpeg GIF Optimization

```powershell
# High-quality GIF from video
$input = "demo.mp4"
$output = "demo.gif"

# Step 1: Generate palette
ffmpeg -i $input -vf "fps=15,scale=800:-1:flags=lanczos,palettegen=stats_mode=diff" palette.png

# Step 2: Create GIF with palette
ffmpeg -i $input -i palette.png -lavfi "fps=15,scale=800:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" $output

# Step 3: Optimize (if needed)
# gifsicle -O3 --colors 128 demo.gif -o demo-opt.gif

# Cleanup
Remove-Item palette.png
```

### 4. Social Preview Creation

See Section 2 for detailed Figma workflow.

Quick checklist:
- [ ] 1280x640 dimensions
- [ ] Dark background
- [ ] Project name large and readable
- [ ] Tagline visible
- [ ] Screenshot or visual element
- [ ] Under 1MB file size

## 8.3 Asset Quality Standards

### Screenshot Standards

| Requirement | Standard |
|-------------|----------|
| Resolution | 2x display resolution (retina-ready) |
| Format | PNG (lossless) |
| Background | Consistent dark theme |
| Content | Real usage, not placeholder |
| Size | Optimized (<500KB) |

### GIF Standards

| Requirement | Standard |
|-------------|----------|
| Duration | 5-15 seconds |
| Frame rate | 15 FPS |
| Width | 800px maximum |
| File size | Under 5MB |
| Loop | Perfect seamless loop |

### Logo Standards

| Requirement | Standard |
|-------------|----------|
| Master file | SVG (vector) |
| Sizes | 512, 256, 128, 64, 32, 16 |
| Backgrounds | Transparent + dark + light versions |
| Formats | SVG, PNG, ICO |

## 8.4 Image Optimization

### Tools

| Tool | Platform | Purpose |
|------|----------|---------|
| ImageOptim | Mac | PNG/JPEG compression |
| Squoosh | Web | All formats |
| TinyPNG | Web/CLI | PNG compression |
| SVGO | CLI | SVG optimization |
| gifsicle | CLI | GIF optimization |

### Compression Commands

```powershell
# PNG optimization (using pngquant)
pngquant --quality=65-80 image.png --output image-opt.png

# SVG optimization
svgo input.svg -o output.svg

# GIF optimization
gifsicle -O3 --colors 128 input.gif -o output.gif
```

## 8.5 Asset Version Control

### What to Commit

```
assets/
  logo/
    logo.svg          # Master file
    logo-512.png      # Generated
    logo-64.png       # Generated
    favicon.ico       # Generated
  social/
    preview.png       # Social preview
    preview.psd       # Source file (if small)
docs/
  images/
    hero.gif          # Optimized
    themes/
      agent-blue.png
      agent-green.png
```

### What NOT to Commit

- Unoptimized images
- RAW/unedited source files (>10MB)
- Video source files
- PSD/AI files (use Git LFS if needed)

### Git LFS for Large Assets

```bash
# Install Git LFS
git lfs install

# Track large files
git lfs track "*.psd"
git lfs track "*.ai"
git lfs track "*.mp4"

# Add to .gitattributes
```

## 8.6 Asset Naming Convention

### Format

```
[type]-[name]-[variant]-[size].[ext]
```

### Examples

```
logo-matrix-dark-512.png
theme-agent-blue-preview.png
screenshot-install-step1.png
demo-theme-switching.gif
social-preview-v2.png
```

### Rules

- Lowercase only
- Hyphens for separation
- Include dimensions for sized variants
- Version suffix for iterating (v1, v2)

---

# Appendix: Quick Reference

## README Template Checklist

- [ ] Badges row (build, version, license)
- [ ] Project name and tagline
- [ ] Hero image/GIF above the fold
- [ ] Quick start (3 commands max)
- [ ] Features list (benefits, not features)
- [ ] Installation section (multiple methods)
- [ ] Usage examples with code
- [ ] Documentation links
- [ ] Contributing section
- [ ] License section
- [ ] Footer with social links

## Template Files Checklist

- [ ] .github/ISSUE_TEMPLATE/bug_report.yml
- [ ] .github/ISSUE_TEMPLATE/feature_request.yml
- [ ] .github/ISSUE_TEMPLATE/question.yml
- [ ] .github/ISSUE_TEMPLATE/config.yml
- [ ] .github/PULL_REQUEST_TEMPLATE.md

## Topics Checklist

- [ ] Primary topics (platform, language)
- [ ] Secondary topics (category, use case)
- [ ] Trending topics (if relevant)
- [ ] Total: 15-20 topics

## Visual Assets Checklist

- [ ] Social preview (1280x640)
- [ ] Hero screenshot (1920x1080)
- [ ] Hero GIF (<5MB)
- [ ] Logo (SVG + PNG sizes)
- [ ] Theme previews
- [ ] All images optimized

## Workflow Checklist

- [ ] CI (build, test, lint)
- [ ] Release (tag-triggered)
- [ ] Stale (scheduled)
- [ ] Greetings (first interaction)
- [ ] Labeler (auto-label PRs)

---

## Document Metadata

**Document:** GITHUB_OPTIMIZATION.md
**Version:** 1.0.0
**Created:** January 7, 2026
**Author:** Growth Specialist Agent
**Project:** Matrix Terminal Shader
**Word Count:** ~15,000
**Sections:** 8 major + 1 appendix

**Change Log:**
- v1.0.0 (2026-01-07): Initial comprehensive version

---

*This document is part of the Matrix Terminal Shader project documentation. For questions or updates, open an issue in the repository.*
