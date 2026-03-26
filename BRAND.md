# MatrixShader Brand Guidelines

Any agent writing copy, UI text, marketing, emails, or product descriptions MUST follow these rules. No exceptions.

---

## Voice & Tone

We live inside the Matrix universe. Everything is written like it belongs in that world — not a corporate SaaS landing page.

**We are:** Operators running a simulation. The product gives you control.
**We are NOT:** A startup pitching enterprise middleware.

**Good:** "Initializes the Redpill Protocol."
**Bad:** "Unlock premium features with our control panel solution."

**Good:** "The path of the ONE:"
**Bad:** "Key Features:"

**Good:** "Limited to the first 500 operators."
**Bad:** "Limited availability — act now!"

**Good:** "Walk the path."
**Bad:** "Get started today!"

### Matrix vocabulary to USE:
- **Operators** (not "users" or "customers")
- **The simulation** (not "your desktop" or "your environment")
- **The path of the ONE** (feature headers)
- **Redpill Protocol** (the paid upgrade)
- **Bluepill** (the free/quick-launch path)
- **Enter the Matrix** (getting started)
- **Walk the path** (call to action)
- **Wake up, Neo...** (intro/onboarding)
- **Mr. Anderson...** (Agent Smith emails)
- **Free your mind** (when appropriate)
- **The rabbit hole** (going deeper)
- **Deja vu** (updates/releases — that's our /dejavu skill)
- **Glitch in the Matrix** (bugs, or the Glitch Snap feature)
- **There is no spoon** (advanced/zen moments)
- **I know kung fu** (mastery, support — it's our BuyMeACoffee handle)

### Words to NEVER use in copy:
- "Premium" — say **Redpill**
- "Free tier" — say **Bluepill** or just "free"
- "Upgrade" — say **take the Redpill** or **initialize the Redpill Protocol**
- "Dashboard" — say **Operator Console** or **control panel**
- "Subscribe" — Agent Smith **recruits** you
- "Users" — **operators**
- "Admin panel" / "Control panel" as a header — always use a Matrix phrase instead

---

## Product Names & Casing

These are EXACT. Never deviate.

| Correct | Wrong |
|---------|-------|
| **MatrixShader** | Matrix Shader, matrixshader, matrix shader, Matrix shader |
| **Redpill** | Red Pill, RedPill, red pill, REDPILL (except in license keys) |
| **Bluepill** | Blue Pill, BluePill, blue pill |
| **WakeupNeo** | Wakeup Neo, wakeupneo (CLI is lowercase `wakeupneo`) |
| **MatrixLite** | Matrix Lite, matrixlite (CLI is lowercase `matrixlite`) |
| **Glitch Snap** | GlitchSnap, glitch snap (two words, both capitalized) |

**Exception:** CLI command names are all lowercase (`wakeupneo`, `bluepill`, `redpill`, `matrixlite`) because that's how you type them in a terminal. In prose, use CamelCase.

**Exception:** License keys use `REDPILL-XXXX-XXXX-XXXX-XXXX` (all caps is fine in key format).

**"Red Pill" as a concept** (two words) is OK when referencing the Matrix movie choice: "Ready for the Red Pill?" But the product/protocol/feature is **Redpill** (one word).

---

## Colors

### Website (dark theme)
| Name | Hex | Usage |
|------|-----|-------|
| Matrix Green | `#6EDCAA` | Primary accent, success states, headings, code text (matches Ghostty foreground) |
| Matrix Red | `#ff0040` | Redpill elements, buy buttons, price cards |
| Matrix Cyan | `#00ffff` | Secondary accent, Bluepill/free labels |
| Matrix Gold | `#ffd700` | Prices, special callouts |
| Matrix Purple | `#ff00ff` | Rare accent |
| Dark Green | `#008f11` | Subtle green tints |
| Background Dark | `#0a0a0a` | Page background |
| Background Darker | `#050505` | Body background |
| Card Background | `rgba(0, 20, 0, 0.8)` | Card/panel backgrounds |
| Text Primary | `#ffffff` | Main text |
| Text Secondary | `#cccccc` | Supporting text |
| Text Muted | `#888888` | Fine print, subtle text |
| Border Green | `rgba(0, 255, 65, 0.3)` | Card borders, dividers |
| Border Red | `rgba(255, 0, 64, 0.3)` | Redpill card borders |

### LemonSqueezy Store
| Name | Hex | Usage |
|------|-----|-------|
| Store Green | `#03A062` | Primary / Matrix green equivalent |
| Link Blue | `#338FFF` | Hyperlinks |
| Otherwise | blacks and greys | Background, text |

### Glow Effects
- Green glow: `0 0 30px rgba(0, 255, 77, 0.7)`
- Red glow: `0 0 30px rgba(255, 0, 64, 0.5)`

---

## Typography

| Context | Font | Platform |
|---------|------|----------|
| Terminal / CLI output | **Nimbus Mono PS Bold** 16pt | Linux (Ghostty) |
| Terminal / CLI output | **Cascadia Mono** (WT default) | Windows |
| Website headings, code, prices, buttons | `'Courier New', 'Consolas', 'Monaco', monospace` | Web |
| Website body text, descriptions | `-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif` | Web |

**Brand font:** Nimbus Mono PS Bold is the canonical brand font (used in Linux wakeupneo). Cascadia Mono is the Windows equivalent. Anything that feels "inside the Matrix" uses monospace. Anything that's just normal reading uses sans-serif.

---

## Pricing Copy

- Always show the strikethrough: ~~$10~~ **$5**
- Always mention: **Founder's Edition**
- Always mention: **first 500 operators**
- Discount code: **ORACLE1**
- End with: **One key. 3 machines. Yours forever.**
- Never say "subscription" — this is a one-time purchase

---

## Email (Agent Smith)

Agent Smith writes the emails. Third person. Menacing but helpful.

**Greeting:** "Mr. Anderson..." or "Ah, Mr. Anderson..."
**Tone:** Dry, knowing, slightly threatening, ultimately helpful
**Sign-off:** Never signs off warmly. Just stops. Or "— Agent Smith"

**Good:** "I see you're still here, enjoying another day inside the Matrix. Predictable. But perhaps you'd like to know when something... *changes*."
**Bad:** "Hey! Thanks for subscribing to our newsletter!"

---

## CLI Output Voice

Terminal output should feel like you're inside the simulation.

**Good:**
```
Wake up, Neo...
The Matrix has you.
Follow the white rabbit.
```

**Bad:**
```
Welcome to MatrixShader Setup!
Let's get you configured.
```

Status messages use Matrix flavor:
- "Starting hotkeys & Glitch... OK"
- "Entering the Matrix..."
- "The Redpill Protocol is active."

---

## GitHub / README

- Hero should SHOW the product, not describe it (GIF/video)
- One-liner install command front and center
- Sell the Redpill — don't just list features
- Stars and downloads badges are fine
- Keep it visual, not wall-of-text

---

## Things That Are Always True

1. MatrixShader is one word, CamelCase
2. Redpill and Bluepill are one word each
3. Operators, not users
4. The simulation, not your desktop
5. Matrix-green on black, always
6. Monospace for anything that feels "in-world"
7. No corporate buzzwords, ever
8. If Agent Smith wouldn't say it, don't write it
