---
title: I built GPU-powered Matrix rain for Windows Terminal (and you can color-code your AI agents with it)
published: false
description: How I solved the "which terminal is which agent" problem with HLSL pixel shaders, bit-packed glyph rendering, and a $0 budget.
tags: terminal, devtools, ai, showdev
canonical_url: https://matrixshader.com/blog/color-code-your-ai-agents
---

## The problem: 6 terminals, 6 AI agents, zero clue which is which

I run multiple AI coding agents simultaneously. Claude in one terminal, Gemini in another, Codex in a third. Sometimes six at once. They all look identical — black rectangles with white text.

I'd switch to a terminal, start reading the output, realize it's the wrong agent, switch again. Context-switching overhead was eating my actual productive time.

I tried naming my tabs. I tried colored prompts. I tried splitting my monitor into quadrants and memorizing positions. None of it stuck. My brain doesn't read tab labels under pressure — it reads *color*.

So I built a thing.

## The solution: GPU shaders that make each terminal visually distinct

![Four MatrixShader windows in different colors running AI agents side-by-side](placeholder-gif-pillars-layout.gif)

*Four AI agents. Four colors. One simulation.*

MatrixShader renders real-time Matrix rain effects directly in Windows Terminal using HLSL pixel shaders. Each window gets its own color — green for the auth agent, cyan for frontend, red for tests, gold for database work. Your brain maps the color instantly. No reading required.

Install in one line:

```powershell
irm matrixshader.com/install.ps1 | iex
```

Then:

```
wakeupneo
```

That's it. Setup wizard walks you through choosing colors and layout.

## How it actually works (the interesting part)

### Bit-packed glyph rendering

The Matrix rain needs characters — Katakana-inspired glyphs falling down the screen. Each glyph is 5 pixels wide by 7 pixels tall. That's 35 pixels per character.

35 bits fits in a single `uint`.

```hlsl
// Each glyph: 5 wide × 7 tall, encoded as 35 bits in a uint
// Bit layout: row-major, bottom-to-top, left-to-right
// Bit 0 = bottom-left, Bit 34 = top-right

// Glyph 0: ア (A) - Katakana style
// ░█░█░  = 01010
// ░░█░░  = 00100
// ░░█░░  = 00100
// ░█░█░  = 01010
// █░░░█  = 10001
// █░░░█  = 10001
// ░███░  = 01110
```

16 characters, 16 `uint` constants. No texture sampling. No font rendering. The GPU extracts each pixel with a bit shift and a mask:

```hlsl
float getGlyphPixel(int glyph_idx, float2 local_uv) {
    glyph_idx = glyph_idx & 15;  // Modulo 16
    int col = int(local_uv.x * 5.0);
    int row = int(local_uv.y * 7.0);
    int bit_idx = row * 5 + col;
    uint glyph_data = GLYPHS[glyph_idx];
    return float((glyph_data >> bit_idx) & 1u);
}
```

Zero external dependencies. Pure math on the GPU. This runs at whatever framerate your terminal supports.

### HLSL `#define` injection for live color control

The color system works through `#define` constants at the top of the shader file:

```hlsl
#define RAIN_R 0.0
#define RAIN_G 1.0
#define RAIN_B 0.25
#define RAIN_SPEED 0.8
#define GLOW_STRENGTH 0.8
#define CHAR_WIDTH 32.0
#define TRAIL_POWER 1.2
#define RAIN_DENSITY 0.7
```

When you change a color preset or adjust a parameter in the TUI control panel, the C# backend reads the shader file, regex-replaces the `#define` values, writes it back, and touches the file to trigger Windows Terminal's shader hot-reload.

No restart. No recompile. The shader updates live while you're looking at it.

### Multi-window architecture

Each window gets its own Windows Terminal profile with its own shader file copy. When you run `bluepill`, it creates up to 8 independent terminal windows, each pointing to a different shader file with different `#define` color values.

The `Ctrl+Shift+Left/Right` hotkey rotates which color is in which position. `Ctrl+Shift+L` cycles between Pillars (side-by-side) and Quads (2×2 grid) layouts. Global hotkeys are registered system-wide so they work regardless of which window has focus.

## What you get

**Bluepill (free):**
- Setup wizard, quick-launch, 6 color presets (Green, Blue, Red, Purple, Gold, Teal)
- Global hotkeys — rotate windows, toggle transparency, swap layouts
- Glitch Snap auto-positioning across monitors
- MatrixLite text fallback for machines without a GPU

**Redpill ($5 — Founder's Edition):**
- Full interactive TUI control panel
- Live parameter tuning — speed, glow, width, trail, density
- Custom RGB color picker (any color, not just presets)
- Per-window depth layer toggles (Far/Mid/Near)
- Multi-tab management, layout modes

The free version is the real thing — not a demo, not a trial. The Redpill adds granular control for operators who want to tune every parameter.

## Why this exists

I didn't set out to build a product. I was running multiple AI agents and kept losing track of which terminal was doing what. The color-coding started as a personal hack. Then it got more features. Then I spent months getting the glyph rendering right, the hot-reload system working, the multi-window orchestration stable.

At some point it became a real tool. So here it is.

**[GitHub](https://github.com/matrixshader/matrix-shader)** | **[matrixshader.com](https://matrixshader.com)**

Install:

```powershell
# Windows
irm matrixshader.com/install.ps1 | iex

# Linux (Ghostty)
curl -sL matrixshader.com/linux | bash
```

Free to use. Source available on GitHub. $5 Founder's Edition if you want full control over the simulation.

---

*MatrixShader runs on Windows 10/11 (Windows Terminal + HLSL) and Linux (patched Ghostty + GLSL). macOS port in progress. Built solo with C#, .NET 9, HLSL, and GLSL.*
