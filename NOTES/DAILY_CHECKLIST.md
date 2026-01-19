# DAILY CHECKLIST - ACCELERATED DEVELOPMENT PLAN

**Created:** January 7, 2026
**Goal:** Release MVP in 1 week, GUI beta in 4 weeks

---

## DAY 1 - Foundation Day (TODAY)

### Morning Block (1.5 hours)
- [ ] **[CRITICAL]** Fix division-by-zero in Matrix.hlsl:33 - Add `max()` guard
- [ ] **[CRITICAL]** Add try-catch error handling in matrix_tool.ps1 file operations
- [ ] **[CRITICAL]** Fix regex parsing failures with fallback defaults
- [ ] **[CRITICAL]** Fix cursor visibility with try-finally block

### Afternoon Block (1 hour)
- [ ] **[CRITICAL]** Add input bounds checking: GLOW max 10.0, TRAIL max 20.0, Speed max 5.0
- [ ] **[HIGH]** Create Buy Me a Coffee account at buymeacoffee.com
- [ ] **[HIGH]** Configure BMC page: project name, description, profile pic

### Evening Block (30 min)
- [ ] **[HIGH]** Test all bug fixes - run through each parameter
- [ ] **[MEDIUM]** Set BMC goal: "First 10 supporters"

**Day 1 Total:** ~3 hours

---

## DAY 2 - Documentation Foundation

### Morning Block (1.5 hours)
- [ ] **[CRITICAL]** Create README.md with sections: Hero, Description, Features, Install, Usage
- [ ] **[CRITICAL]** Capture screenshots of all 6 presets
- [ ] **[CRITICAL]** Create 5-second hero GIF showing color change animation
- [ ] **[HIGH]** Add screenshots and GIF to README.md

### Afternoon Block (1.5 hours)
- [ ] **[CRITICAL]** Write detailed installation instructions
- [ ] **[CRITICAL]** Write usage guide with key bindings table
- [ ] **[CRITICAL]** Add MIT LICENSE file
- [ ] **[HIGH]** Add Buy Me a Coffee button to README
- [ ] **[HIGH]** Apply for GitHub Sponsors

**Day 2 Total:** ~3.5 hours

---

## DAY 3 - Community Infrastructure

### Morning Block (1 hour)
- [ ] **[HIGH]** Create CONTRIBUTING.md
- [ ] **[HIGH]** Create .github/ISSUE_TEMPLATE/bug_report.md
- [ ] **[HIGH]** Create .github/ISSUE_TEMPLATE/feature_request.md

### Afternoon Block (1.5 hours)
- [ ] **[HIGH]** Create .github/PULL_REQUEST_TEMPLATE.md
- [ ] **[HIGH]** Enable GitHub Discussions
- [ ] **[MEDIUM]** Create CODE_OF_CONDUCT.md
- [ ] **[HIGH]** Write Troubleshooting FAQ section

**Day 3 Total:** ~3 hours

---

## DAY 4 - Pre-Release Polish

### Morning Block (1 hour)
- [ ] **[HIGH]** Add version info header to both files: "v1.0.0 - January 2026"
- [ ] **[HIGH]** Create CHANGELOG.md
- [ ] **[MEDIUM]** Add help screen to PowerShell (H key)
- [ ] **[HIGH]** Document preset keys 1-6 in help and README

### Afternoon Block (1.5 hours)
- [ ] **[HIGH]** Create Install-MatrixShader.ps1 script
- [ ] **[CRITICAL]** Test on Intel GPU
- [ ] **[HIGH]** Test on AMD GPU if available
- [ ] **[HIGH]** Test on NVIDIA GPU

**Day 4 Total:** ~3.5 hours

---

## DAY 5 - Soft Launch

### Morning Block (1 hour)
- [ ] **[CRITICAL]** Final code review
- [ ] **[CRITICAL]** Push to GitHub repository
- [ ] **[CRITICAL]** Create v1.0.0 release with release notes

### Afternoon Block (1.5 hours)
- [ ] **[HIGH]** Add GitHub topics: windows-terminal, hlsl, matrix, shader, powershell
- [ ] **[HIGH]** Share with 3-5 trusted contacts for feedback
- [ ] **[MEDIUM]** Draft Reddit posts for r/PowerShell, r/commandline
- [ ] **[MEDIUM]** Draft HackerNews "Show HN" post

**Day 5 Total:** ~3 hours

---

## DAY 6 - Feedback Integration

### Morning Block (2 hours)
- [ ] **[CRITICAL]** Respond to soft launch feedback
- [ ] **[CRITICAL]** Fix any issues discovered

### Afternoon Block (1.5 hours)
- [ ] **[HIGH]** Update README based on confusion points
- [ ] **[HIGH]** Finalize r/PowerShell post
- [ ] **[MEDIUM]** Research GUI frameworks: WPF vs Electron vs Web

**Day 6 Total:** ~4.5 hours

---

## DAY 7 - Community Launch Phase 1

### Morning Block (30 min)
- [ ] **[CRITICAL]** Post to r/PowerShell
- [ ] **[HIGH]** Post to r/commandline

### Afternoon Block (3 hours)
- [ ] **[CRITICAL]** Monitor and respond to Reddit comments
- [ ] **[HIGH]** Document all feature requests
- [ ] **[MEDIUM]** Create "Roadmap" issue on GitHub

### Evening Block (2 hours)
- [ ] **[MEDIUM]** Begin GUI prototype if feedback positive

**Day 7 Total:** ~5.5 hours

---

## WEEK 2-4 OVERVIEW

### Week 2: Community Growth
- **Mon:** r/unixporn + HackerNews posts
- **Tue:** Full engagement - respond to all communities
- **Wed:** v1.1.0 release with quick fixes
- **Thu:** GUI architecture finalized
- **Fri:** GUI MVP development begins

### Week 3: Feature Enhancement
- Preset system (JSON config)
- CLI interface (--preset, --color flags)
- GUI alpha with basic controls
- v1.2.0 release

### Week 4: GUI Focus Sprint
- GUI beta (color picker, live preview)
- Integration testing
- v1.3.0 release with GUI beta

---

## SUCCESS METRICS

| Timeframe | Stars | Downloads | Support |
|-----------|-------|-----------|---------|
| Day 7 | 50+ | 20+ | $10+ |
| Week 2 | 200+ | 100+ | $30+ |
| Week 3 | 400+ | 200+ | $50+ |
| Week 4 | 600+ | 300+ | $75+ |
| Month 2 | 1500+ | 800+ | $150+ |
| Month 3 | 3000+ | 2000+ | $250+ |

---

## IMMEDIATE PRIORITY (DO FIRST)

1. **Fix 5 Critical Bugs** (~90 minutes total)
   - Division-by-zero guard in HLSL
   - Try-catch for file operations
   - Regex fallback defaults
   - Parameter bounds checking
   - Cursor restoration

2. **Set up Buy Me a Coffee** (~20 minutes)
   - Create account
   - Configure page
   - Get shareable link

3. **Create README with GIF** (~2 hours)
   - Hero GIF showing color changes
   - Installation instructions
   - Key bindings table

---

*Created by Planning Lead Agent*
*Total estimated time to MVP: 6-10 hours*
*Total estimated time to GUI beta: 4 weeks*
