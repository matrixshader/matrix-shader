# GUI APP - PRODUCT REQUIREMENTS DOCUMENT

**Document Version:** 1.0
**Date:** January 7, 2026
**Author:** Code Architect Agent
**Status:** Ready for Development

---

## Executive Summary

This PRD defines the requirements for the Matrix Terminal Shader GUI application - a premium tier product that replaces the PowerShell TUI with a modern Windows desktop application.

**Technology Decision: WPF with .NET 8** (Score: 9.49/10)

**Why WPF wins:**
- Native Windows performance (critical for real-time shader updates)
- 30-50MB installers (vs 150MB+ for Electron)
- Mature, stable ecosystem (15+ years)
- Rich built-in controls (color picker, sliders)
- Clear path to cross-platform via .NET MAUI in v3

---

## Product Overview

### Vision
A beautiful, intuitive desktop application that gives users complete control over their Matrix Terminal Shader without touching PowerShell.

### Target Users
1. **Primary:** Developers who want visual control (not CLI)
2. **Secondary:** Streamers/content creators needing quick adjustments
3. **Tertiary:** Power users who want preset management

### Pricing
- **v1.0 GUI:** $14.99 one-time purchase
- **Core shader:** FREE forever
- **Updates:** Free for 1 year

---

## Feature Requirements

### MVP Features (v1.0)

#### 1. Shader Parameter Controls
| Parameter | Control Type | Range |
|-----------|-------------|-------|
| Glow | Slider | 0.0 - 10.0 |
| Speed | Slider | 0.1 - 5.0 |
| Width | Slider | 1 - 20 |
| Trail | Slider | 1 - 20 |
| Density | Slider | 0.1 - 1.0 |
| RGB Color | Color Picker | Full spectrum |
| Layers | Toggle buttons | 3 layers (7/8/9) |

#### 2. Preset System
- 8 built-in presets (Classic Green, Cyber Blue, Alert Red, Royal Purple, Gold Rush, Ice Cyan, Sunset Orange, Midnight Purple)
- Save custom presets
- Load presets with one click
- Export/import preset files (JSON)

#### 3. Windows Terminal Integration
- Auto-detect Windows Terminal installation
- One-click shader activation
- Profile selection (apply to specific profile or all)
- Automatic settings.json backup before modification

#### 4. Live Preview (Stretch Goal)
- Real-time preview of changes
- Before/after comparison
- Performance metrics display

### Premium Features (v2.0)
- Effect marketplace (CRT, Holographic, Neon effects)
- Cloud preset sync
- Advanced animation timeline
- Multiple effect layers

---

## Technical Architecture

### Technology Stack
- **Framework:** WPF (.NET 8)
- **Language:** C#
- **Build:** MSIX packaging
- **Distribution:** GitHub Releases, Microsoft Store (future)

### File Structure
```
MatrixShaderGUI/
├── MatrixShaderGUI.csproj
├── App.xaml
├── MainWindow.xaml
├── Views/
│   ├── ControlPanel.xaml
│   ├── PresetManager.xaml
│   └── Settings.xaml
├── ViewModels/
│   ├── MainViewModel.cs
│   ├── ControlPanelViewModel.cs
│   └── PresetViewModel.cs
├── Services/
│   ├── ShaderService.cs        # File I/O, hot-reload
│   ├── TerminalService.cs      # settings.json management
│   └── PresetService.cs        # Preset save/load
├── Models/
│   ├── ShaderSettings.cs
│   └── Preset.cs
└── Resources/
    ├── Presets/
    └── Templates/
```

### Key Services

#### ShaderService
- Generate HLSL from template + parameters
- Write to Documents folder
- Trigger hot-reload via timestamp
- Validate parameter bounds

#### TerminalService
- Read/write Windows Terminal settings.json
- Backup before modification
- Handle multi-profile scenarios
- Detect Terminal installation

#### PresetService
- JSON serialization for presets
- File-based storage in Documents\MatrixShader\presets\
- Import/export functionality

---

## Development Timeline

### Week 1-2: Foundation
- Project setup with WPF + .NET 8
- Basic MVVM architecture
- ShaderService implementation
- Basic parameter sliders working

### Week 3-4: Core Features
- Color picker integration
- Preset system (save/load)
- Windows Terminal integration
- Settings persistence

### Week 5-6: Polish
- UI/UX refinement
- Error handling and logging
- Installer creation (MSIX)
- User documentation

### Week 7-8: Launch
- Beta testing with community
- Bug fixes
- Release preparation
- Marketing launch

**Total: 8 weeks to public release**

---

## Revenue Projections (Year 1 - Moderate)

| Metric | Conservative | Moderate | Optimistic |
|--------|-------------|----------|------------|
| Free Users | 5,000 | 10,000 | 25,000 |
| Conversion Rate | 3% | 5% | 8% |
| Paid Users | 150 | 500 | 2,000 |
| ARPU | $15 | $15 | $15 |
| **Revenue** | $2,250 | $7,500 | $30,000 |

---

## Success Metrics

### Launch Metrics (Week 1)
- 50+ beta users
- < 5 critical bugs
- 4+ star average rating

### Growth Metrics (Month 1)
- 200+ paid users
- 95%+ activation success rate
- < 3% refund rate

### Retention Metrics (Month 3)
- 70%+ still using after 30 days
- 50+ user reviews
- 3+ preset packs requested

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| WPF learning curve | Medium | Medium | Extensive MS documentation, AI assistance |
| Windows Terminal API changes | Low | High | Abstract Terminal interactions, version checking |
| Performance issues | Low | High | Profile early, optimize hot paths |
| Low conversion rate | Medium | Medium | Strong free tier, community building first |

---

## Dependencies

### External
- Windows Terminal installed
- .NET 8 Desktop Runtime
- Windows 10 1903+ or Windows 11

### Internal
- Core shader must be stable (5 critical bugs fixed)
- Free PowerShell version must have 500+ stars
- Community feedback collected

---

## Next Steps

1. **Week 1:** Set up WPF project structure
2. **Week 1:** Implement ShaderService with hot-reload
3. **Week 2:** Build basic parameter controls
4. **Week 2:** Implement TerminalService
5. **Week 3:** Add preset system
6. **Week 4:** Polish UI, add color picker
7. **Week 5:** Create installer
8. **Week 6:** Beta testing
9. **Week 7-8:** Launch prep and release

---

*Document prepared by Code Architect Agent*
*Technology decision: WPF with .NET 8 (score 9.49/10)*
