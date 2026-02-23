---
name: oracle
description: "Process pending FAQ questions — drafts answers from codebase knowledge, flags unknowns for human review, and publishes approved answers. Use when the user says /oracle or asks to process the FAQ inbox."
user_invocable: true
---

<objective>
Process all pending FAQ questions submitted via the MatrixShader support page. Reads the codebase to draft accurate answers for questions Claude can handle, flags business/roadmap questions for the human, and identifies spam for cleanup. Every action requires user approval before executing.
</objective>

<quick_start>
1. Fetch pending questions: `GET /api/faq?status=pending` with Bearer auth
2. Read codebase files to build answer context
3. Classify each question into CAN ANSWER, NEEDS HUMAN, or JUNK
4. Present all results grouped by bucket with draft answers
5. User approves/edits/skips each — then execute API calls
</quick_start>

<essential_principles>
- **Never fabricate answers.** Only answer from codebase knowledge, README, and docs. If unsure, classify as NEEDS HUMAN.
- **Never publish without approval.** Always show the draft and wait for the user to confirm.
- **Keep answers concise.** 1-3 sentences. Helpful and direct, matching the Matrix operator voice (but not over-the-top).
- **Batch efficiently.** Show all CAN ANSWER questions together so the user can approve in bulk or review individually.
</essential_principles>

<context>
**API base:** `https://matrixshader.com/api/faq`

**Auth:** `Authorization: Bearer $DASHBOARD_PASSWORD` header (env var). If not set, ask the user for it.

**Endpoints:**
- `GET /api/faq?status=pending` — fetch pending questions (auth required)
- `PATCH /api/faq` — update a question (auth required). Body: `{ "id", "action", ... }`
  - `action: "publish"` — requires `answer` field, optional `category`
  - `action: "dismiss"` — marks as dismissed
  - `action: "reopen"` — returns to pending
  - `action: "update"` — partial update (answer, category, tags)
- `DELETE /api/faq?id=xxx` — permanently delete (auth required)

**Valid categories:** `general`, `installation`, `usage`, `licensing`, `compatibility`, `troubleshooting`
</context>

<process>
**Step 1: Authenticate and fetch**

Run `scripts/fetch-pending.sh` to get all pending questions. If DASHBOARD_PASSWORD is not in environment, ask the user for it.

If zero pending questions, say "The Oracle sees no unanswered questions." and stop.

**Step 2: Display summary**

Show a numbered overview:
```
The Oracle: {N} pending questions

#1 [{category}] "{question}" — {email} ({date})
#2 [{category}] "{question}" — {email} ({date})
...
```

**Step 3: Build answer context**

Read these codebase files to prepare for drafting answers:
- `CLAUDE.md` — architecture overview, key mechanisms
- `README.md` — user-facing feature list, install instructions
- `Website/index.html` — product page feature descriptions
- `Website/redpill/index.html` — Red Pill purchase page details
- `matrix_control.ps1` — control panel features and hotkeys
- `matrix_setup.ps1` — setup wizard flow
- `Website/privacy/index.html` and `Website/terms/index.html` — policy questions

Search additional files as needed for specific questions (shader files, C# source, etc.).

**Step 4: Classify each question**

For each pending question:
1. Check if the category is correct — note any corrections needed
2. Determine which bucket it belongs in:

| Bucket | Criteria | Examples |
|--------|----------|---------|
| **CAN ANSWER** | Answerable from codebase/docs | "How do I change colors?", "Does it work on Windows 10?" |
| **NEEDS HUMAN** | Requires business judgment, account info, or roadmap commitment | "Can I get a discount?", "When will you support macOS?", "I want a refund" |
| **JUNK** | Gibberish, test data, spam, not a real question | "asdfasdf", "test123" |

**Step 5: Present results**

Group by bucket and show:

For **CAN ANSWER** — show question, category correction (if any), and draft answer
For **NEEDS HUMAN** — show question and explain why only the human can answer it
For **JUNK** — show question and recommend dismiss or delete

Ask the user how to proceed. Accept bulk commands ("publish all", "looks good") or individual review.

**Step 6: Execute approved actions**

For each approved action, run the appropriate API call using `scripts/faq-action.sh`:

- **Publish**: `scripts/faq-action.sh publish <id> "<answer>" [category]`
- **Dismiss**: `scripts/faq-action.sh dismiss <id>`
- **Delete**: `scripts/faq-action.sh delete <id>`
- **Update category**: `scripts/faq-action.sh update <id> [category]`

**Step 7: Summary**

Show final tally:
```
Oracle Complete:
  Published: {N}
  Dismissed: {N}
  Deleted:   {N}
  Skipped:   {N} (still pending)
```
</process>

<anti_patterns>
- **Guessing answers** — If you're not confident from codebase sources, mark NEEDS HUMAN. Wrong answers on a public FAQ are worse than no answer.
- **Publishing without approval** — Every publish must be explicitly confirmed by the user.
- **Over-theming answers** — Answers should be helpful and clear. Don't force Matrix references into every response.
- **Skipping category correction** — If a question is miscategorized, fix it as part of the publish/update call.
</anti_patterns>

<success_criteria>
Triage is complete when:
- All pending questions have been classified into buckets
- User has reviewed and decided on each question (publish, dismiss, delete, or skip)
- All approved API calls have been executed successfully
- Final summary shows the tally of actions taken
</success_criteria>
