# MatrixShader Email Campaign Templates

All emails use inline CSS for maximum email client compatibility. Paste directly into LemonSqueezy email editor or any HTML email sender.

## Folder Structure

```
emails/
├── onboarding/          # First-touch emails
│   ├── welcome-operator.html       # After free email signup → download link + quick start
│   └── zion-mainframe-codes.html   # Red Pill license key delivery ("Codes for Zion's Mainframe")
│
├── nurture/             # Blue Pill → Red Pill upsell drip sequence
│   ├── bluepill-nag-day3.html      # Day 3: Friendly Operator, hotkey tips, soft Red Pill mention
│   ├── bluepill-nag-day7.html      # Day 7: Agent Smith enters, feature comparison, $5 pitch
│   └── bluepill-nag-day14.html     # Day 14: Full Smith, final push, scarcity (founder pricing)
│
├── retention/           # Keeping customers / handling refunds
│   ├── smith-farewell.html         # Refund confirmation (Agent Smith persona)
│   └── retention-save.html         # User reconsidered refund, staying
│
├── transactional/       # Triggered by specific actions
│   ├── purchase-receipt.html       # Order confirmation with details
│   └── operator-support.html       # Support ticket acknowledgment
│
└── engagement/          # Ongoing relationship
    ├── product-update.html         # New version announcement
    └── milestone.html              # Community milestone (100, 500, 1K, 5K operators)
```

## Template Variables

These placeholders should be replaced before sending:

| Variable | Used In | Example |
|----------|---------|---------|
| `{{customer_name}}` | zion-mainframe-codes, purchase-receipt | "Neo" |
| `{{license_key}}` | zion-mainframe-codes | "REDPILL-A1B2-C3D4-E5F6-G7H8" |
| `{{order_id}}` | purchase-receipt | "LS-123456" |
| `{{amount}}` | purchase-receipt | "$5.00" |
| `{{date}}` | purchase-receipt | "February 19, 2026" |
| `{{version}}` | product-update | "v1.1.0" |
| `{{milestone_count}}` | milestone | "1,000" |
| `{{milestone_word}}` | milestone | "one thousand" |
| `{{unsubscribe_url}}` | all marketing emails | LemonSqueezy provides this |

## Drip Sequence Timing

```
Day 0  → welcome-operator.html (immediate, after email gate signup)
Day 3  → bluepill-nag-day3.html (if NOT purchased)
Day 7  → bluepill-nag-day7.html (if NOT purchased)
Day 14 → bluepill-nag-day14.html (if NOT purchased, final email)
```

## Persona Guide

- **Operator** (green themed): Friendly, helpful crew member. Used for welcome, support, updates.
- **Agent Smith** (red themed): Theatrical, dry, slightly menacing. Used for refunds, final nag emails.
- **Morpheus** (neutral/epic): Wise, dignified. Used for key delivery, purchase confirmation.

## Design Constants

- Background: `#0a0a0a`
- Green card: `bg #0d1a0d`, border `#1a3a1a`
- Red card: `bg #1a0d0d`, border `#3a1a1a`
- Matrix green: `#00ff41`
- Matrix red: `#ff0040`
- Gold (prices): `#ffd700`
- Font: `'Courier New', Courier, monospace`
- Max width: 600px
