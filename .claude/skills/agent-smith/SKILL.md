---
name: agent-smith
description: "Launch campaign assistant — pulls up the right post for the right platform, opens submission pages in the browser, pre-fills forms, and tracks what's been posted. Use when the user says /agent-smith or wants to execute launch campaign posts."
user_invocable: true
---

<objective>
Help the user execute the MatrixShader launch campaign by pulling post copy from the campaign files, opening the right submission page in the browser, pre-filling the form, and tracking which posts have been published. Every post requires user review and approval before submission.
</objective>

<quick_start>
1. Read the campaign files to see what's scheduled
2. Check what's already been posted (tracking file)
3. Show what's ready to post today
4. For each approved post: open the platform, pre-fill the form, user clicks submit
5. Mark as posted in the tracking file
</quick_start>

<essential_principles>
- **Never auto-submit.** Always pre-fill and let the user review + click submit themselves. Automated posting gets accounts flagged.
- **One post at a time.** Don't rush. Each post needs the user's eyes on it before it goes live.
- **Customize on the fly.** The campaign files have templates. If the user wants to tweak something, help them edit it before posting.
- **Track everything.** After each post goes live, log it in the tracking file with date, platform, URL, and any notes.
- **Respect platform rules.** Remind the user of each subreddit's specific rules before posting (no emojis, 9:1 ratio, etc.).
</essential_principles>

<context>
**Campaign files location:** `.planning/campaigns/`
- `LAUNCH-CALENDAR.md` — week-by-week schedule with checkboxes
- `REDDIT.md` — 10 subreddit posts, each customized
- `HACKER-NEWS.md` — Show HN title + launch comment + objection playbook
- `TWITTER.md` — launch thread + daily content ideas
- `UTM-TRACKING.md` — all tracking links per platform

**Post tracking file:** `.planning/campaigns/POSTED.md` (create if it doesn't exist)

**Key URLs:**
- Reddit submit: `https://www.reddit.com/r/{subreddit}/submit`
- HN submit: `https://news.ycombinator.com/submit`
- Twitter compose: `https://twitter.com/compose/tweet`
</context>

<process>
**Step 1: Check campaign status**

Read `.planning/campaigns/LAUNCH-CALENDAR.md` and `.planning/campaigns/POSTED.md` (if it exists).

Show the user:
```
Agent Smith Campaign Status

Posted:
  {list of already-posted items with dates and links}

Ready to post:
  {list of items from the calendar that are due/overdue}

Coming up:
  {next few items on the calendar}
```

If no arguments provided, show this status and ask what the user wants to post.

**Step 2: Select target**

If the user specifies a platform (e.g., `/agent-smith reddit sideproject` or `/agent-smith hn`), go directly to that post.

Otherwise, recommend the next post from the calendar.

**Step 3: Load post content**

Read the appropriate campaign file and extract the post for the target platform/subreddit.

Show the full post to the user:
```
Platform: {platform}
Subreddit: {subreddit if reddit}
Title: {title}
Body: {body}
Link: {UTM link}
Rules reminder: {platform-specific rules}
```

Ask: "Ready to post this? Edit anything? Skip?"

**Step 4: Open browser and pre-fill**

Use browser tools (Playwright or chrome-devtools MCP) to:

For **Reddit**:
1. Navigate to `https://www.reddit.com/r/{subreddit}/submit`
2. Wait for the page to load
3. Find the title field and fill it
4. Find the body field and fill it
5. If there's a media attachment (GIF/video), remind the user to attach it manually
6. Tell the user: "Form is pre-filled. Review it, attach your demo GIF, and click Submit when ready."

For **Hacker News**:
1. Navigate to `https://news.ycombinator.com/submit`
2. Fill the title field
3. Fill the URL field with the UTM link
4. Tell the user: "Form is pre-filled. Click Submit, then IMMEDIATELY post the launch comment from HACKER-NEWS.md."
5. After submission, offer to help post the launch comment on the new thread.

For **Twitter/X**:
1. Navigate to `https://twitter.com/compose/tweet`
2. Fill the tweet text (first tweet of the thread)
3. Tell the user: "First tweet is ready. Post it, then continue the thread manually or I can help with each tweet."

**Step 5: Confirm and track**

After the user confirms the post is live, ask for the post URL.

Append to `.planning/campaigns/POSTED.md`:
```
## {date}
- **Platform**: {platform}
- **Subreddit**: {subreddit if reddit}
- **Title**: {title}
- **URL**: {post URL}
- **UTM**: {tracking link used}
- **Notes**: {any notes}
```

Update the checkbox in `LAUNCH-CALENDAR.md` from `[ ]` to `[x]`.

**Step 6: Post-submission reminders**

After posting, remind the user:
- "Stay online for the next 2-4 hours to respond to every comment."
- "Check back in 1 hour for engagement — if it's gaining traction, keep feeding comments."
- For Reddit: "Remember the 9:1 ratio — go leave some genuine comments on other posts too."
- For HN: "Post the launch comment NOW if you haven't already."
</process>

<arguments>
The skill accepts optional arguments to go directly to a specific post:

| Argument | Action |
|----------|--------|
| (none) | Show campaign status |
| `reddit {subreddit}` | Load and post to specific subreddit (e.g., `reddit sideproject`) |
| `hn` | Load and post to Hacker News |
| `twitter` | Load and post to Twitter/X |
| `twitter thread` | Walk through the full launch thread tweet by tweet |
| `status` | Show what's been posted vs what's remaining |
| `next` | Recommend and load the next post from the calendar |
</arguments>

<anti_patterns>
- **Auto-submitting posts** — NEVER click submit for the user. Pre-fill only. The user must review and submit themselves.
- **Posting identical content** — Each subreddit post is customized. Never copy-paste between platforms.
- **Skipping the demo attachment** — Always remind the user to attach the GIF/video. Text-only posts die.
- **Rushing multiple posts** — Space Reddit posts 2-3 days apart. Don't post to 5 subreddits in one day.
- **Ignoring tracking** — Always log what was posted in POSTED.md. Without tracking, we can't measure what works.
</anti_patterns>

<success_criteria>
A posting session is complete when:
- The post is live on the target platform
- The user has confirmed the URL
- POSTED.md has been updated with the post details
- LAUNCH-CALENDAR.md checkbox has been marked
- The user has been reminded about post-submission engagement
</success_criteria>
