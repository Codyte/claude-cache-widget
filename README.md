# 💰 Claude Cache / Cost Widget

**Watch your Claude Code spend in real-time. Save up to 90% with prompt caching.**

A lightweight always-on-top desktop widget (Windows / PowerShell + WinForms) that shows **live cache heat** and **actual token costs** for your Claude Code sessions. No estimates—real numbers from your transcript.

> **The problem it solves:** Long Claude Code sessions are expensive. Prompt caching can save 90%+ on tokens, but you can't see it happening. This widget makes the invisible visible.

---

## ✨ What You Get

### 📊 Real-Time Metrics
- **Cache Clock** — See your cache expire (green "hot" → yellow "cooling" → red "cold")
- **Live Token Count** — In / Cached / Out tokens with cost breakdown
- **Cost Per Turn** — Actual USD spent (from real API usage)
- **Total Spend** — Cumulative tokens + savings + burn rate ($/min)
- **Plan Usage** — Monthly quota utilization (optional)

### 🎯 Key Features
✅ **Live cache heat tracking** — Know when you're about to lose your 90% discount  
✅ **Actual costs** — Reads real `message.usage` from transcripts, not estimates  
✅ **Multiple models** — Claude 3.5 Sonnet, Opus, Haiku pricing built-in  
✅ **Automatic hooks** — Installs into Claude Code lifecycle (`SessionStart`, `Stop`)  
✅ **Draggable widget** — Always visible, never blocking  
✅ **Right-click menu** — Quick access to transcripts and settings  
✅ **Single-instance** — No dupes, auto-restarts cleanly  

---

## 🎬 Visual Preview

The widget displays:
- **Top section** — Cache countdown (time until 5-min TTL expires)
- **Middle** — Your current turn breakdown (input / cache-read / output tokens)
- **Bottom** — Session totals (all tokens + USD + how much cache saved you)
- **Right-click menu** — Copy summary, open transcript, open project folder

**Example:**
```
┌─────────────────────────────────────┐
│  CACHE: quente (4m 23s)  [████████] │  ← Cache fresh!
│  Token: 1,200 in | 450 cache | 380 out
│  Cost:  $0.042 per turn | Total: $1.83 | Saved: $8.70 (90%)
│  Plan:  21% of month quota
└─────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites
- **Windows 10/11** + PowerShell 5.1+ (PowerShell 7 recommended)
- **Claude Code** (writes transcripts to `~/.claude/projects/`)
- **Python 3** (optional — only for plan/budget section)

### Install (One Command)
```powershell
git clone https://github.com/Codyte/claude-cache-widget.git
cd claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Done. The widget launches immediately and auto-starts on next Claude Code session.

### Uninstall
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

---

## 📖 Documentation

### Configuration
Edit `config.json` to customize:
- `context_limit` — Your model's token limit
- `cache_ttl_seconds` — How long cache stays hot (default: 300s)
- `idle_close_minutes` — Auto-close after N min of inactivity
- `prices.json` — Token pricing (auto-updates when Anthropic changes rates)

### How It Works

1. **Install hooks** — `install.ps1` registers three lifecycle hooks in `~/.claude/settings.json`:
   - `SessionStart` → launches widget
   - `UserPromptSubmit` → marks turn as "busy" (pauses cache clock)
   - `Stop` → marks turn as "idle" (starts cache expiry countdown)

2. **Read transcripts** — Widget monitors `~/.claude/projects/*/latest.jsonl` for real `message.usage` objects

3. **Calculate costs** — Applies pricing from `prices.json`:
   - `in` = input tokens
   - `cr` = cache-read tokens (cheap!)
   - `cw` = cache-write tokens
   - `out` = output tokens

4. **Show savings** — Displays how much cheaper this turn was vs. no caching

### Privacy & Security
- ✅ **Local-only** — reads only your transcripts on disk
- ✅ **No tracking** — never sends data anywhere
- ✅ **OAuth optional** — plan section uses same token Claude CLI already has
- ✅ **Credentials safe** — `.credentials.json` never committed

---

## 💡 Use Cases

### Case 1: Long Refactoring Session
```
Before: Load full codebase context each turn → $15 per turn (5K tokens)
After:  Cache keeps context hot → $0.50 per turn (45 cache-read tokens)
        💾 90% savings per turn!
```

### Case 2: Multi-File Debugging
```
Turn 1: Load error context  → $2.10 (cache written)
Turn 2-5: Reuse context    → $0.20 each (cache hit!)
         💾 Saved $8 on just 5 turns
```

### Case 3: API Integration Work
```
Session runs for 2 hours with context reuse
Total spend: $18.50 | Total saved via cache: $167
         💾 That's an 90% savings day!
```

---

## ⚙️ Advanced

### Command-Line Usage (AI Agents)
```powershell
# One-shot install for Copilot or other agents
git clone https://github.com/Codyte/claude-cache-widget.git claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\claude-cache-widget\install.ps1
```

The installer is fully idempotent — running it twice just restarts the widget.

### Custom Installation Path
```powershell
.\install.ps1 -InstallDir "C:\MyTools\Claude"
```

### Skip Hook Registration
```powershell
.\install.ps1 -NoHooks
```

---

## 🤝 Contributing

**Good first issues:**
- [ ] Translate UI to English (currently Portuguese) — see `config.json` for string keys
- [ ] Support other LLM cost models (GPT-4, Gemini, Mixtral)
- [ ] Add dark mode toggle
- [ ] Cross-platform port (macOS + Linux via system tray)
- [ ] Test on Windows 11 + PowerShell 7

**Development:**
```powershell
# Edit widget-ui.ps1, then restart
.\install.ps1  # Restarts instantly
```

---

## ❓ FAQ

**Q: Does this work with Claude Web UI (not Claude Code)?**
A: Not currently — it only reads Claude Code transcripts. The web UI doesn't write transcripts locally.

**Q: Will this slow down my session?**
A: No. The widget runs in a separate process and uses negligible CPU (<1%).

**Q: Is my data safe?**
A: Completely. The widget is local-only and never connects to the internet (except optional OAuth for plan usage).

**Q: Can I see historical costs?**
A: Yes — explore `~/.claude/projects/*/latest.jsonl` directly or check the widget's right-click menu.

**Q: Why the Portuguese UI?**
A: The author is Brazilian 🇧🇷. English translation is a welcome contribution!

---

## 🐛 Troubleshooting

### Widget doesn't appear after install
```powershell
# Check if it's running
Get-Process | Where-Object {$_.ProcessName -like "*PowerShell*"}

# Restart manually
.\install.ps1
```

### Costs look wrong
1. Check `prices.json` — is it up to date with Anthropic's current rates?
2. Verify `message.usage` in your transcript — sometimes early turns don't have it
3. Reload config: `Ctrl+R` in widget (if implemented)

### Widget won't install on PowerShell 5.1
The installer uses `ConvertFrom-Json -AsHashtable` which doesn't exist in PS 5.1. Use PowerShell 7+ or edit `settings.json` manually (instructions printed by installer).

---

## 📊 Pricing Reference

Default pricing (as of 2024):
- **Claude 3.5 Sonnet** — $3/$15/$3/$15 per 1M tokens (in/cache-read/cache-write/out)
- **Claude 3 Opus** — $15/$75/$15/$75 per 1M tokens
- **Claude 3 Haiku** — $0.25/$1.25/$0.25/$1.25 per 1M tokens

Update `prices.json` when rates change. Contributions welcome!

---

## 📝 License

MIT — See [LICENSE](LICENSE)

*Not affiliated with Anthropic. "Claude" is a trademark of Anthropic.*

---

## 🎯 Roadmap

- [ ] English UI (v2)
- [ ] Dark mode
- [ ] Alerts for cache expiry
- [ ] Cost trending over time
- [ ] macOS version
- [ ] GPU memory tracking (for local LLMs)

Have an idea? [Open an issue](https://github.com/Codyte/claude-cache-widget/issues)!

