# Release Checklist

Use this checklist when preparing a new release of Claude Cache Widget.

## Pre-Release (1 day before)

- [ ] Update version number in `config.json`
- [ ] Update `prices.json` if Anthropic changed rates (check [pricing page](https://claude.ai/pricing))
- [ ] Test on Windows 10 and Windows 11
- [ ] Test on PowerShell 5.1 and PowerShell 7
- [ ] Verify install script works: `.\install.ps1`
- [ ] Verify uninstall works: `.\install.ps1 -Uninstall`
- [ ] Check for any hardcoded paths or secrets
- [ ] Run full widget lifecycle: install → use → clear → restart

## Release Day

### 1. Update Documentation
- [ ] Update `README.md` if UI changed
- [ ] Update `CHANGELOG.md` with new features/fixes
- [ ] Update version in all docs

### 2. Create GitHub Release
```bash
git tag v1.2.3
git push origin v1.2.3
```

Then on GitHub:
1. Go to Releases → "Create a new release"
2. Select the tag you just created
3. Title: `Claude Cache Widget v1.2.3`
4. Description: Use `CHANGELOG.md` entry
5. **Upload assets:**
   - Zip the entire folder as `claude-cache-widget-v1.2.3.zip`
   - Include: `install.ps1`, `widget-ui.ps1`, `prices.json`, `config.json`, `README.md`, `LICENSE`
6. Click "Publish release"

### 3. Announce (Optional but Recommended)

#### Reddit
Post on r/ClaudeAI and r/windows:
```
Title: Claude Cache Widget v1.2.3 - [Feature summary]

Hi! Just released v1.2.3 with [feature]. You can install with:

git clone https://github.com/Codyte/claude-cache-widget.git
cd claude-cache-widget
powershell -ExecutionPolicy Bypass -File .\install.ps1

What's new: [changelog]
```

#### Twitter/X
```
🚀 Just released Claude Cache Widget v1.2.3!

[Feature description with impact]

Watch your cache expire in real-time. Save 90%+ with prompt caching.

📥 Install: github.com/Codyte/claude-cache-widget

#ClaudeAI #DevTools
```

#### Dev.to (if major update)
Write a short post: "What's new in Claude Cache Widget v1.2.3"

---

## Post-Release

- [ ] Monitor GitHub issues for bugs
- [ ] Respond to questions on Reddit/Twitter
- [ ] Update version in docs site (if you have one)
- [ ] Close related issues with link to release

---

## Versioning

Use semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** — Breaking changes (e.g., config format change)
- **MINOR** — New features (e.g., dark mode, new LLM pricing)
- **PATCH** — Bug fixes (e.g., cache time not updating)

Current version: Check `config.json` → `version` field
