# Bootstrap script for machine-scratch
# One command to go from clean macOS → full agent workstation.
# Run: curl -fsSL https://raw.githubusercontent.com/jwalin-shah/machine-scratch/main/bin/bootstrap.sh | bash

set -euo pipefail

echo "=== New Mac Bootstrap ==="

# ── 1. Xcode CLI tools ──
xcode-select --install 2>/dev/null || true

# ── 2. Homebrew ──
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew update

# ── 3. macOS defaults ──
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.dock autohide -bool true
killall Finder Dock 2>/dev/null || true

# ── 4. Core CLI tools ──
brew install \
  bat eza fd ripgrep git-delta dust \
  gh infisical fswatch \
  uv node pnpm \
  jq yq \
  rtk \
  direnv \
  huggingface-cli

# ── 5. uv tools (Python) ──
uv tool install llm-tldr
uv tool install fastedits
uv tool install cocoindex
uv tool install cognee

# ── 6. npm global tools ──
npm install -g @openrouter/cli
npm install -g @daytonaio/daytona

# ── 7. Git + SSH setup ──
git config --global user.name "Jwalin Shah"
git config --global user.email "jwalinshah@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.autocrlf input

mkdir -p ~/.ssh
[ -f ~/.ssh/config ] || cat > ~/.ssh/config << 'SSHCONFIG'
Host github.com
  IdentityFile ~/.ssh/agent/id_ed25519
Host *
  UseKeychain yes
  AddKeysToAgent yes
SSHCONFIG
chmod 600 ~/.ssh/config

# ── 8. GitHub auth ──
gh auth login --web 2>/dev/null || gh auth login -h github.com -p https

# ── 9. Clone repos ──
mkdir -p ~/projects
gh repo clone jwalin-shah/machine-scratch ~/projects/machine-scratch 2>/dev/null || \
  git clone https://github.com/jwalin-shah/machine-scratch.git ~/projects/machine-scratch
gh repo clone jwalin-shah/firstmate ~/projects/firstmate 2>/dev/null || \
  git clone https://github.com/jwalin-shah/firstmate.git ~/projects/firstmate
gh repo clone jwalin-shah/machine-bootstrap ~/.agent-rules 2>/dev/null || \
  git clone https://github.com/jwalin-shah/machine-bootstrap.git ~/.agent-rules

# Verify clones
for d in ~/projects/machine-scratch ~/projects/firstmate ~/.agent-rules; do
  [ -d "$d/.git" ] || { echo "ERROR: $d clone failed"; exit 1; }
done

# ── 10. Shell config ──
cat > ~/.zshrc << 'ZSHRC'
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
eval "$(direnv hook zsh)"
ZSHRC

# ── 11. Direnv setup ──
mkdir -p ~/.config/direnv/lib
cp ~/projects/machine-scratch/config/direnv-uv.sh ~/.config/direnv/lib/uv.sh

# ── 12. Link machine-scratch bin ──
mkdir -p ~/bin
ln -sf ~/projects/machine-scratch/bin/tool-guard.sh ~/bin/tool-guard.sh

# ── 13. Firstmate setup ──
ln -sf ~/projects/firstmate/bin/* ~/bin/ 2>/dev/null || true
mkdir -p ~/Library/LaunchAgents
for plist in ~/projects/machine-scratch/launchd/*.plist; do
  [ -f "$plist" ] && cp "$plist" ~/Library/LaunchAgents/ && launchctl load ~/Library/LaunchAgents/$(basename "$plist")
done

# ── 14. Wire tool-guard into agent settings ──
# Claude Code
mkdir -p ~/.claude
if [ -f ~/.claude/settings.json ]; then
  jq '. + {"PreToolUse": [{"matcher": "Bash|Read", "hooks": [{"type": "command", "command": "'$HOME'/bin/tool-guard.sh", "timeout": 3, "statusMessage": "Checking tool choice..."}]}]}' ~/.claude/settings.json > /tmp/claude-settings.json && mv /tmp/claude-settings.json ~/.claude/settings.json
else
  echo '{"PreToolUse": [{"matcher": "Bash|Read", "hooks": [{"type": "command", "command": "'$HOME'/bin/tool-guard.sh", "timeout": 3, "statusMessage": "Checking tool choice..."}]}]}' > ~/.claude/settings.json
fi

# Codex
mkdir -p ~/.codex
if [ -f ~/.codex/hooks.json ]; then
  jq '. + {"preToolUse": [{"matcher": "Bash|Read", "hooks": [{"command": "'$HOME'/bin/tool-guard.sh", "timeout": 3}]}]}' ~/.codex/hooks.json > /tmp/codex-hooks.json && mv /tmp/codex-hooks.json ~/.codex/hooks.json
else
  echo '{"preToolUse": [{"matcher": "Bash|Read", "hooks": [{"command": "'$HOME'/bin/tool-guard.sh", "timeout": 3}]}]}' > ~/.codex/hooks.json
fi

# ── 15. LLM-TLDR warm ──
llm-tldr doctor || true
llm-tldr warm --lang python --lang typescript --lang go ~/projects/machine-scratch 2>/dev/null || true

# ── 16. infisical (interactive) ──
echo ""
echo "=== Open https://infisical.app and log in ==="
echo "Then run: infisical init"
echo ""

# ── 17. Apps (casks) ──
brew install --cask claude codex cursor brave-browser zen 2>/dev/null || true

# ── 18. Done ──
echo ""
echo "=== Bootstrap complete ==="
echo "1. Restart terminal (or source ~/.zshrc)"
echo "2. Run: infisical init"
echo "3. Run: gh auth login (if not done)"
echo "4. Verify: rtk --version, llm-tldr --version, fastedit doctor"
echo "5. Open System Settings → Privacy → Automation → check terminal apps"
echo "6. Download AGY from agy.ai → place in /opt/homebrew/bin/agy"
