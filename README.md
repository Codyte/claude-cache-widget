# Claude Cache / Cost Widget

A small always-on-top desktop widget (Windows / PowerShell + WinForms) that shows, in real time,
the **prompt-cache "heat"** and the **token / cost usage** of your active [Claude Code](https://claude.com/claude-code)
session. It reads the real `message.usage` numbers from the most recent transcript in
`~/.claude/projects`, so the tokens and USD figures are actual, not estimated from text length.

> It exists because the VS Code Claude extension does not run the `statusLine` (only the CLI does),
> so there is no built-in place to watch your cache window and spend.

## What it shows

- **Cache clock** — counts from the **end** of the turn (a `Stop` hook writes `~/.claude/.turn_state`).
  While Claude is answering → `respondendo` (clock paused). Idle: green `quente` (cache hot, ~90% off)
  → yellow `esfriando` → red `frio` once the 5-minute cache TTL expires.
- **Context window** — last turn's input tokens / limit + model + conversation id + a bar.
- **ATUAL DA MENSAGEM** — in / cache / out tokens of the last turn + a cost-weighted stacked bar +
  cache-hit %.
- **TOTAL DA CONVERSA** — accumulated tokens and USD for the whole conversation, how much the cache
  saved you, and a burn rate ($/min).
- **PLANO / ORÇAMENTO** *(optional, needs Python)* — 5h / 7d plan utilization (Claude OAuth usage
  endpoint) + estimated API-equivalent USD over those windows.

Draggable. Double-click to close. Right-click for a menu (copy a full plain-text summary, open the
active transcript / project folder). Single-instance (named mutex). Auto-closes after an idle session.

> **UI language is Brazilian Portuguese.** An English translation is a welcome contribution
> (see *Known limitations*).

## Requirements

- **Windows** with PowerShell 5.1+ (PowerShell 7 / `pwsh` preferred — the launcher uses it if present).
- **Claude Code** writing transcripts under `~/.claude/projects/**/*.jsonl`.
- **Python 3** *(optional)* — only for the PLANO / ORÇAMENTO section. Without it the rest works.

## Install

```powershell
git clone https://github.com/Codyte/claude-cache-widget.git
cd claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer:
1. **stops any running instance** (releases the single-instance mutex),
2. copies the files to `~/.claude/cache-widget` (override with `-InstallDir <path>`),
3. detects your Python interpreter,
4. registers three hooks in `~/.claude/settings.json` (with a timestamped backup, idempotent):
   - `SessionStart` → launches the widget hidden,
   - `UserPromptSubmit` → marks the turn **busy**,
   - `Stop` → marks the turn **idle** (starts the cache cooldown clock),
5. **launches the new instance** right away — so **re-running `install.ps1` = restart the widget**
   with your latest code/config. No need to reboot the session.

Flags: `-InstallDir <path>` · `-NoHooks` (copy + print snippet, don't touch `settings.json`) ·
`-NoLaunch` (install without opening the widget).

On **Windows PowerShell 5.1** (which lacks `ConvertFrom-Json -AsHashtable`) the installer does **not**
edit `settings.json`; it prints the JSON block for you to paste (it still stops/launches the widget).

### For AI agents (one-shot install)

If a user points you at this repo and says *"install this"*, run:

```powershell
git clone https://github.com/Codyte/claude-cache-widget.git claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\claude-cache-widget\install.ps1
```

`install.ps1` is idempotent and self-contained: it stops any old instance, installs, wires the hooks,
and launches the widget immediately (no session restart needed). Use `-NoLaunch` to skip the launch.

## Configuration

Two JSON files next to the script — a **single source of truth**, read by both the widget (PS) and
the usage fetcher (Python):

- **`prices.json`** — USD per 1M tokens per model (`in` / `cr` cache-read / `cw` cache-write / `out`).
  Update here when Anthropic changes the price table.
- **`config.json`** — `context_limit`, `context_limit_by_model`, `idle_close_minutes`, `cache_ttl_seconds`.

## Privacy & security

- The widget only **reads** your local transcripts; it sends nothing anywhere.
- `usage_fetch.py` (the optional plan section) reads the OAuth `accessToken` from
  `~/.claude/.credentials.json` and calls Anthropic's **non-public** `oauth/usage` endpoint. This is
  the same token the CLI already uses; nothing leaves your machine except that one authenticated
  request to Anthropic. If you don't want it, simply don't install Python — everything else still works.
- `.credentials.json` and all runtime state files are in `.gitignore`. **Never commit them.**

## Known limitations / good first issues

- UI strings are Portuguese — an English (or i18n) pass is welcome.
- The plan endpoint is undocumented and may change or rate-limit (the fetcher already backs off and
  preserves the last good values).
- Windows-only (WinForms). A cross-platform port (e.g. a tray app) would be a larger effort.
- Cost label columns can jitter on the very first tick before the auto-size labels render.

## License

MIT — see [LICENSE](LICENSE).

*Not affiliated with Anthropic. "Claude" is a trademark of Anthropic.*
