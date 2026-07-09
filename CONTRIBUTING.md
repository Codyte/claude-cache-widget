# Contributing to Claude Cache Widget

Thanks for considering a contribution! This guide will help you get started.

## 🎯 Good First Issues

These are perfect for new contributors:

### 🌐 **Internationalization (i18n)**
**The widget UI is currently in Portuguese. Help translate it to English!**

- [ ] Translate `widget-ui.ps1` string labels to English
- [ ] Create `i18n.json` config structure:
  ```json
  {
    "language": "en",
    "strings": {
      "cache_hot": "hot",
      "cache_cooling": "cooling",
      "cache_cold": "cold",
      "current_turn": "Current Turn",
      "total_session": "Session Total"
    }
  }
  ```
- [ ] Update UI to read from `i18n.json`
- **Effort:** 2-3 hours | **Skill:** PowerShell + JSON

### 🎨 **Dark Mode**
Add a dark mode theme toggle to the widget.

- [ ] Add `theme` setting to `config.json` (`"light"` or `"dark"`)
- [ ] Update WinForms colors in `widget-ui.ps1` based on theme
- [ ] Add right-click menu option to toggle theme
- **Effort:** 1-2 hours | **Skill:** PowerShell + WinForms

### 💱 **Additional LLM Pricing**
Support GPT-4, Gemini, Mixtral, or other models.

- [ ] Add pricing to `prices.json` for new models
- [ ] Update `config.json` to support `model_pricing` override
- [ ] Test with different models
- **Effort:** 30 minutes | **Skill:** JSON editing

### 🔔 **Cache Expiry Alert**
Show a notification when cache is about to expire.

- [ ] Trigger alert at 1 minute before TTL expires
- [ ] Use Windows toast notification API
- [ ] Option to disable in `config.json`
- **Effort:** 1-2 hours | **Skill:** PowerShell + Windows API

### 📈 **Cost History CSV Export**
Export session costs to CSV for analysis.

- [ ] Create `export-costs.ps1` to extract data from transcripts
- [ ] Generate CSV: Date | Tokens | Cost | Cache-Hit %
- [ ] Add menu option in widget
- **Effort:** 2 hours | **Skill:** PowerShell + CSV

### 🚀 **macOS/Linux Port**
Port the widget to cross-platform (system tray app).

- [ ] Research tray icon frameworks (.NET, Qt, Electron)
- [ ] Prototype on macOS/Linux
- [ ] Maintain feature parity with Windows version
- **Effort:** 5-10 hours | **Skill:** PowerShell/C# or Electron

---

## 🔧 Development Setup

### Prerequisites
- Windows 10/11 + PowerShell 5.1+ (PowerShell 7 preferred)
- Git
- A text editor (VS Code recommended)
- Claude Code installed (for testing)

### Clone & Install for Development
```powershell
git clone https://github.com/Codyte/claude-cache-widget.git
cd claude-cache-widget

# Install with development flags
.\install.ps1 -NoHooks  # Install without auto-hooks (you'll restart manually)
```

### Test Your Changes
Edit `widget-ui.ps1` or other files, then restart:
```powershell
.\install.ps1  # Re-installs and restarts widget immediately
```

Or kill the running widget and restart manually:
```powershell
Stop-Process -Name "PowerShell" -Force -ErrorAction SilentlyContinue
# Then run .\install.ps1
```

---

## 📋 Development Workflow

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a branch** for your feature:
   ```powershell
   git checkout -b feature/my-feature
   ```
4. **Make changes** and test locally
5. **Commit** with a clear message:
   ```powershell
   git commit -m "feat: add dark mode toggle"
   ```
6. **Push** to your fork:
   ```powershell
   git push origin feature/my-feature
   ```
7. **Create a Pull Request** on the main repo

---

## 💡 Code Guidelines

### PowerShell Style
- Use **PascalCase** for functions and variables
- Add comment blocks for complex logic
- Use **`-ErrorAction SilentlyContinue`** carefully (test error cases)
- Keep functions under 100 lines when possible

### Comments & Documentation
```powershell
<#
.DESCRIPTION
    Reads the latest Claude Code transcript and extracts token usage.

.PARAMETER ProjectPath
    Path to the Claude project folder.

.OUTPUTS
    PSCustomObject with usage data (inputTokens, cacheReadTokens, outputTokens).
#>
function Get-TokenUsage {
    param([string]$ProjectPath)
    # implementation
}
```

### Testing
- Test on **both PowerShell 5.1 and PowerShell 7**
- Test on **Windows 10 and Windows 11**
- Verify hooks register correctly in `~/.claude/settings.json`
- Check that `prices.json` loads correctly with your changes

---

## 🐛 Bug Reports

Found a bug? Please create an issue with:
1. **Title:** Clear, one-line description
2. **Steps to reproduce:** What you did
3. **Expected behavior:** What should happen
4. **Actual behavior:** What happened instead
5. **Environment:** Windows version, PowerShell version, Claude Code version

Example:
```
Title: Widget doesn't update cache time on Claude 3.5 Sonnet

Steps:
1. Open Claude Code with Claude 3.5 Sonnet
2. Make a prompt that hits cache
3. Widget shows cache time as frozen

Expected: Cache countdown updates every second
Actual: Cache time locked at 5:00, doesn't decrement

Environment: Windows 11 22H2, PowerShell 7.4, Claude Code v0.14
```

---

## 💬 Discussions & Questions

**Questions about contributing?** Open a discussion before diving into code:
- "Should I tackle the dark mode feature?"
- "How would you prioritize these issues?"
- "Is there a design pattern I should follow?"

---

## 📝 Commit Message Format

Use conventional commits:
- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation
- `refactor:` — code reorganization
- `test:` — tests
- `chore:` — maintenance

Examples:
```
feat: add dark mode toggle
fix: cache time doesn't decrement on PS 5.1
docs: add internationalization guide
refactor: extract widget-ui into separate functions
```

---

## 🎯 PR Checklist

Before submitting a PR, verify:
- [ ] Code is tested on Windows 10/11
- [ ] PowerShell 5.1 and 7+ both work (if applicable)
- [ ] No credentials or secrets committed
- [ ] Documentation updated (README, CONTRIBUTING, etc.)
- [ ] Commit messages follow conventional format
- [ ] No unrelated changes in the PR

---

## 📚 Resources

- [Claude Code Documentation](https://claude.com/claude-code)
- [PowerShell Docs](https://docs.microsoft.com/en-us/powershell/)
- [WinForms Reference](https://docs.microsoft.com/en-us/dotnet/desktop/winforms/)
- [JSON Configuration Format](https://www.json.org/)

---

## 🤝 Community

- **Discord/Community?** Help us set one up! (Suggestions welcome)
- **Questions?** Open a GitHub discussion
- **Feature ideas?** Create an issue with the `enhancement` label

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing! 🎉**

Every contribution — big or small — helps make Claude Code cheaper for everyone.
