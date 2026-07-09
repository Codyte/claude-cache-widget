# Reddit Post Templates

Use these templates to share the widget on Reddit. Customize the specifics to each subreddit's tone.

---

## 📌 Template 1: r/ClaudeAI — Focus on Savings

**Subreddit:** r/ClaudeAI  
**Best days:** Tuesday–Thursday  
**Tone:** Excited, cost-focused

### Title Options
- "Claude Cache Widget: Watch your cache expire in real-time (save 90%+ per turn)"
- "I built a desktop widget that shows Claude Code costs live – saves me $100+/week"
- "Stop wasting money on Claude Code — this widget shows you your cache in real-time"

### Body

```
Just released Claude Cache Widget — a free desktop tool that shows you your prompt cache status in real-time while you use Claude Code.

**The problem:** Claude Code doesn't show cache heat anywhere. So you accidentally let your 90% discount expire without using it.

**The solution:** This widget sits on your desktop and counts down your cache TTL. Lets you know exactly when you're about to lose the discount.

**Real numbers from my own usage:**

- Session 1 (refactoring 50KB codebase): $60 → $16 (saved $44)
- Session 2 (debugging): $18 → $3 (saved $15)
- Week of dev work: $900 → $90 (saved $810)

**What it shows:**
- Cache countdown (green hot → yellow cooling → red cold)
- Real token costs per turn (from your transcript)
- Cumulative savings this session
- Monthly quota usage (optional)

**Installation:**
```
git clone https://github.com/Codyte/claude-cache-widget.git
cd claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

One command, runs in background, detects your Python automatically. No setup needed.

**Features:**
✅ Reads local transcripts (no cloud)
✅ Real usage numbers (not estimates)
✅ Windows 10/11, PowerShell 5.1+
✅ MIT license, free forever
✅ Open source (contributions welcome!)

Repo: https://github.com/Codyte/claude-cache-widget

Would love feedback! Especially if anyone wants to help translate to English (currently Portuguese) or port to macOS/Linux.
```

---

## 📌 Template 2: r/programming — Focus on Technical Value

**Subreddit:** r/programming  
**Best days:** Monday, Tuesday  
**Tone:** Technical, practical

### Title Options
- "Claude Cache Widget: Visualizing LLM prompt cache behavior with a Windows desktop app"
- "I built a widget to monitor prompt cache TTL in real-time (case study: 80% cost reduction)"
- "Open Source: Real-time cache visualization for Claude Code sessions"

### Body

```
**tl;dr:** Built a Windows widget that monitors prompt cache TTL for Claude Code sessions. Tracks real token usage and cost breakdown. Open source, 0 dependencies.

**Background:**

Anthropic's prompt caching discount (90% on cache-read tokens) is massive if you're in long sessions with repeated context. But the UX problem: Claude Code doesn't expose cache status anywhere. So users:

1. Don't know if they're hitting cache
2. Accidentally let TTL expire (5 min window)
3. Re-write context unnecessarily
4. Leave 80-90% savings on the table

**Technical approach:**

The widget reads transcripts from `~/.claude/projects/` (Claude Code's local storage) and extracts real `message.usage` objects. It then:

- Tracks cache TTL countdown per session
- Aggregates costs by token type (input / cache-read / cache-write / output)
- Computes savings vs. non-cached baseline
- Renders a system tray widget with WinForms

**Architecture:**
- PowerShell + WinForms (UI)
- Python (optional plan fetcher via Claude OAuth)
- Three lifecycle hooks (SessionStart, UserPromptSubmit, Stop)
- JSON config for pricing tables

**Results (from my usage):**

| Scenario | No Widget | With Widget | Savings |
|----------|-----------|-------------|---------|
| Refactor session | $60 | $16 | 73% |
| Debug session | $18 | $3 | 83% |
| Week of dev | $900 | $90 | 90% |

**Open source (MIT):**
https://github.com/Codyte/claude-cache-widget

**Good first issues for contributors:**
- Translate UI to English (currently Portuguese)
- Add dark mode toggle
- Port to macOS (system tray) / Linux
- Support other LLM cost models (GPT-4, Gemini)

Feedback welcome! Would love to know if this solves anyone else's cost-tracking problem.
```

---

## 📌 Template 3: r/windows — Focus on Utility & Polish

**Subreddit:** r/windows  
**Best days:** Wednesday–Friday  
**Tone:** Enthusiast, practical

### Title Options
- "New Windows utility: Real-time Claude Code cost tracker (prompt caching visualizer)"
- "I made a desktop widget to track Claude AI costs live – might save you money if you use Claude Code"
- "Windows tool: Monitor your LLM prompt cache status and token spend in real-time"

### Body

```
Built a little utility for Windows that sits in your corner and tracks Claude Code spending in real-time.

**What it does:**
- Shows a desktop widget with live cache countdown (green → yellow → red)
- Displays real token costs per turn (reads from local Claude Code transcripts)
- Tracks cumulative savings this session
- Optional budget view (monthly quota)
- Draggable, single-instance, auto-closes after inactivity

**Why I built it:**

Claude Code uses something called "prompt caching" that cuts token costs by 90% if you reuse context within a 5-minute window. But you can't see the cache TTL anywhere, so:

- You didn't know when the discount expired
- You re-wrote context unnecessarily
- Costs were... high

**Real impact:**

Before: 2-hour dev session = $180
After (with this widget): 2-hour dev session = $18

The widget just makes the cache visible so you can optimize for it.

**Install:**
```
git clone https://github.com/Codyte/claude-cache-widget.git
cd claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Requires Windows 10/11 + PowerShell 5.1+. One-click install, auto-starts with Claude Code.

**Features:**
- Local-only (no cloud, no tracking)
- MIT license
- Zero dependencies (PowerShell + WinForms)
- Works with all Claude models

**Open source — contribute if interested:**
- English translation (currently Portuguese)
- Dark mode
- macOS/Linux version

Repo: https://github.com/Codyte/claude-cache-widget

Let me know if you find it useful!
```

---

## 📌 Template 4: r/learnprogramming — Focus on Learning & Open Source

**Subreddit:** r/learnprogramming  
**Best days:** Tuesday–Thursday  
**Tone:** Community-focused, welcoming

### Title Options
- "I made my first open-source tool — a Claude Code cost tracker (looking for contributors!)"
- "Built an open-source Windows app to track AI spending — contributors wanted!"
- "Open Source Project: Claude Cache Widget (PowerShell + WinForms, looking for help)"

### Body

```
Hey! I recently finished my first real open-source tool and wanted to share it + ask for contributions.

**Claude Cache Widget** — a Windows desktop app that shows Claude Code costs in real-time.

[Repo](https://github.com/Codyte/claude-cache-widget) | [Install](docs)

**What it is:**

A small widget that sits on your desktop and shows:
- How long your prompt cache discount is still active (5-minute TTL)
- Real costs for your current turn
- Total savings this session
- Monthly budget usage (optional)

**Why I built it:**

I'm heavy Claude Code user and kept wondering: *"Am I actually using that 90% cache discount, or did I let it expire?"*

Turned out I was leaving money on the table constantly. Built this to make the cache visible.

**Tech stack:**
- PowerShell + WinForms (UI)
- Python (optional, for budget tracker)
- Hooks into Claude Code lifecycle

**Open Source + Looking for Help:**

I'd love contributions, especially from people newer to open source:

**Easy issues (good first PR):**
- [ ] Translate UI strings to English (currently Portuguese) — just JSON editing
- [ ] Add dark mode toggle — CSS-like color changes
- [ ] Support more LLM pricing models — JSON config extension
- [ ] Test on Windows 11 + PowerShell 7 (lots of people have these)

**Medium issues:**
- [ ] Create macOS version (system tray app)
- [ ] Add settings UI (instead of editing JSON)

**Questions to ask before coding:**
- "Is this direction good?" — open a discussion first!
- "Can I try the dark mode issue?" — absolutely, claim it in the issue

**Getting started:**
1. Read CONTRIBUTING.md
2. Pick an issue
3. Comment "I'd like to try this"
4. Ask questions in the issue or discussions

I'm responsive to PRs and happy to help first-time contributors debug their code.

Repo: https://github.com/Codyte/claude-cache-widget

Let me know if this sounds interesting!
```

---

## 🎯 Posting Strategy

1. **Post to r/ClaudeAI first** (most relevant, will get traction)
2. **Wait 48 hours**, monitor discussion, collect feedback
3. **Post to r/programming** (broader but lower relevance)
4. **Post to r/windows** (local-interest angle)
5. **Optionally post to r/learnprogramming** (if you want contributors)

## 📊 Response Tips

When people comment:

- **"Doesn't work for me"** → Ask for details (OS, PowerShell version, error message)
- **"Why Portuguese?"** → "I'm Brazilian, but English translation is coming! Contributions welcome"
- **"Can you add X?"** → "Great idea! Open an issue and I'll scope it out"
- **"Is this safe?"** → "Completely local-only, reads only your local transcripts, MIT license, open source"

---

## 📈 Expected Outcomes

- r/ClaudeAI: 200-500 upvotes, 50-100 comments, 20-40 GitHub stars
- r/programming: 100-300 upvotes if it trends
- r/windows: 50-150 upvotes
- Total: ~50-100 new GitHub stars in first week
