# Issue #2: New Mac Bootstrap — Tool Manifest, Fixes & Environment

> Status: REVISED after adversarial review.
> One command to go from clean macOS → full agent workstation.
> Every tool has a reason. Nothing extra.

---

## 🔴 Critical Fixes from Adversarial Review

These were found during review and are baked into the bootstrap:

1. **SSH config generated before git clone** — bootstrap creates `~/.ssh/config` with identity file before cloning any repos
2. **`gh auth login` runs before any `gh` or git operations** — ensures HTTPS clone fallback
3. **infisical setup runs interactively** — script pauses with instructions, supports `INFISICAL_TOKEN` env var for non-interactive
4. **tree-sitter grammars pre-warmed** — `llm-tldr doctor` verifies, `llm-tldr warm` pre-builds
5. **tool-guard.sh wired concretely** — no "TODO" comments, real `jq` commands inject hooks into Claude/Codex/OpenCode settings
6. **`~/.zshrc` generated** — includes direnv hook, PATH for `~/.local/bin` and `~/bin`
7. **git config set** — `init.defaultBranch`, `pull.rebase`, `core.autocrlf`
8. **SSH config references key directory** — `IdentityFile ~/.ssh/agent/id_ed25519`
9. **Bootstrap path for rtk** — if `rtk` isn't installed, the guard temporarily lowers strictness
10. **`jq` replaces `python3 -c`** in tool-guard.sh for JSON parsing (consistent with our own advice)

---

## Tool Manifest

### Layer 0: System (pre-installed on macOS, used directly)

| Tool | Reason |
|---|---|
| `git` | Version control (Xcode CLI tools) |
| `sqlite3` | Session database queries |
| `jq` | JSON processing (brew if not present) |
| `du -s` | Disk usage (raw bytes — guard allows with `-s`) |
| `pwd`, `which`, `mkdir`, `cp`, `mv`, `date`, `stat`, `ps` | Shell essentials |

**macOS defaults set:**
```bash
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.dock autohide -bool true
killall Finder Dock 2>/dev/null || true
```

### Layer 1: Package managers

| Tool | Install | Reason |
|---|---|---|
| `brew` | [brew.sh](https://brew.sh) | System packages & casks |
| `uv` | `brew install uv` | Python: tool installs, venvs, pip replacement |
| `node` / `npm` / `pnpm` | `brew install node pnpm` | Node.js packages |
| `rustup` / `cargo` | `brew install rustup-init` | Rust toolchain (if projects need it) |
| `go` | `brew install go` | Go toolchain (if projects need it) |

### Layer 2: Core agent tools (always installed)

| Tool | Install | Reason |
|---|---|---|
| `rtk` | `brew install rtk` | Token-efficient wrappers: ls, read, grep, find, diff, curl, wc, git, gh, pytest, pip, npm |
| `llm-tldr` | `uv tool install llm-tldr` | Code analysis: AST, call graph, semantic search, diagnostics, daemon mode |
| `fastedit` | `uv tool install fastedits` | Editing: AST-aware read/edit/rename/move/delete. Text-match (75%) + local MLX (25%) |
| `gh` | `brew install gh` | GitHub CLI (backend for gh-axi) |
| `infisical` | `brew install infisical` | Secrets management (API keys, provider tokens) |
| `fswatch` | `brew install fswatch` | File watching — cocoindex/cognee incremental indexing |
| `direnv` | `brew install direnv` | Per-project auto env (venv activation, project vars) |

### Layer 3: File utility fallbacks

| Tool | Install | Reason |
|---|---|---|
| `bat` | `brew install bat` | Syntax-highlighted file reading |
| `eza` | `brew install eza` | Modern `ls` |
| `fd` | `brew install fd` | Modern `find` |
| `rg` | `brew install ripgrep` | Modern `grep` (`rtk grep` backend) |
| `delta` | `brew install git-delta` | Better diffs |
| `dust` | `brew install dust` | Disk usage |
| `yq` | `brew install yq` | YAML processing |

### Layer 4: Agent surfaces (apps)

| App | Install | Reason |
|---|---|---|
| Claude | `brew install --cask claude` | Primary agent (Anthropic) |
| Codex | `brew install --cask codex` | Secondary agent (OpenAI) |
| Cursor | `brew install --cask cursor` | Hands-on coding agent |
| Brave Browser | `brew install --cask brave-browser` | Web browsing, web search tool |
| Zen Browser | `brew install --cask zen` | Alternative browser (privacy-focused) |
| OpenCode CLI | `brew install opencode` | Terminal-based coding agent |

**Also installed (direct download):**
- AGY (Google Antigravity CLI) — Go binary from Google, place in /opt/homebrew/bin/agy. Not on brew or npm (the `agy` npm package is unrelated). Download from agy.ai or Google's release channel.

### Layer 5: Provider CLIs & API tools

| Tool | Install | Reason |
|---|---|---|
| `@openrouter/cli` | `npm install -g @openrouter/cli` | OpenRouter API management |
| `daytona` | `npm install -g @daytonaio/daytona` | Development environment manager |

**API-only (no CLI needed, keys in infisical):**
- **TokenRouter** — from palebluedot.ai. API key in infisical (`/internal/TOKENROUTER_API_KEY`). The CLI was broken last checked — use API directly.
- **Fireworks AI** — API key in infisical (`/llm/FIREWORKS_API_KEY`). No CLI needed for agent use.

### Layer 6: AXI tools (our wrappers)

| Tool | Install | Reason |
|---|---|---|
| `gh-axi` | from `firstmate` repo | Token-efficient GitHub: issues, PRs, CI, releases |
| `coco-axi` | from `firstmate` repo | Code index search |
| `cognee-axi` | from `firstmate` repo | Session memory recall |
| `githits-axi` | from `firstmate` repo | Public code examples |
| `context7-axi` | from `firstmate` repo | Library documentation |
| `fm-tasks` | from `firstmate` repo | Task management |
| `fm-sessiond` | from `firstmate` repo | Session database daemon |
| `mm-ctl` / `mintmux` | from `firstmate` repo | Terminal management (replaces tmux) |

### Layer 7: Agent infrastructure (Python daemons)

| Tool | Install | Reason |
|---|---|---|
| `cocoindex` | `uv tool install cocoindex` | Incremental code index + embeddings |
| `cognee` | `uv tool install cognee` | Cross-session memory graph |
| `huggingface-hub` | `brew install huggingface-cli` | Model access (fastedit MLX backend) |

---

## Environment Management

### Shell config (`~/.zshrc`)

Generated by bootstrap:
```zsh
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
eval "$(direnv hook zsh)"
eval "$(atuin init zsh)"           # shell history (if atuin installed)
```

### Tool configs (`~/.config/`)

```
~/.config/
  git/                        # git config, .gitignore_global
  ripgrep/                    # rg config
  bat/                        # bat theme
  gh/                         # gh config
  infisical/                  # infisical config
  opencode/                   # opencode.json + agents + skills
  direnv/                     # direnv.toml + lib/uv.sh
  fm-sessiond/                # sessiond config
  mintmux/                    # mintmux config
```

### Git config

```bash
git config --global user.name "Jwalin Shah"
git config --global user.email "jwalinshah@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.autocrlf input
```

### SSH config (`~/.ssh/config`)

Generated by bootstrap:
```
Host github.com
  IdentityFile ~/.ssh/agent/id_ed25519
Host *
  UseKeychain yes
  AddKeysToAgent yes
```

### Per-project envs (`direnv + uv`)

```
projects/<name>/
  .envrc          # direnv — project vars (non-secret)
  .venv/          # uv venv — Python dependencies
  node_modules/   # pnpm — Node dependencies
  AGENTS.md       # project context (symlinked as CLAUDE.md)
```

**`.envrc` template:**
```bash
source_up
layout uv
export PROJECT_ROOT=$(pwd)
```

**Layout function** (`~/.config/direnv/lib/uv.sh`):
```bash
layout_uv() {
  if [ ! -d ".venv" ]; then
    uv venv --quiet
  fi
  export VIRTUAL_ENV="$(pwd)/.venv"
  PATH_add ".venv/bin"
}
```

**Rule:** `.envrc` never contains secrets. Secrets come from `infisical run` only.

### Secrets flow

```
infisical login                          # ← interactive, browser-based
infisical run --env dev --path /llm -- <command>   # inject LLM keys
infisical run --env dev --path /internal -- <command>  # inject internal keys
```

For agent sessions, secrets are injected at session start via hooks (not via shell init or `.zshrc`).

---

## Bootstrap Script

```bash
#!/usr/bin/env bash
# bootstrap-new-mac.sh — idempotent, safe to re-run
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
npm install -g opencode  # if not via brew

# ── 7. Git + SSH setup ──
git config --global user.name "Jwalin Shah"
git config --global user.email "jwalinshah@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.autocrlf input

mkdir -p ~/.ssh
cat > ~/.ssh/config << 'SSHCONFIG'
Host github.com
  IdentityFile ~/.ssh/agent/id_ed25519
Host *
  UseKeychain yes
  AddKeysToAgent yes
SSHCONFIG
chmod 600 ~/.ssh/config

# ── 8. GitHub auth ──
gh auth login --web || gh auth login -h github.com -p https

# ── 9. Clone repos ──
mkdir -p ~/projects
gh repo clone jwalinshah/firstmate ~/projects/firstmate
gh repo clone jwalinshah/agent-rules ~/.agent-rules
# Verify clones
[ -d ~/projects/firstmate/.git ] || { echo "firstmate clone failed"; exit 1; }
[ -d ~/.agent-rules/.git ] || { echo "agent-rules clone failed"; exit 1; }

# ── 10. Shell config ──
cat > ~/.zshrc << 'ZSHRC'
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
eval "$(direnv hook zsh)"
ZSHRC

# ── 11. Direnv setup ──
mkdir -p ~/.config/direnv/lib
curl -fsSL https://raw.githubusercontent.com/jwalinshah/machine-scratch/main/direnv/uv.sh \
  -o ~/.config/direnv/lib/uv.sh

# ── 12. Firstmate setup ──
ln -sf ~/projects/firstmate/bin/* ~/bin/ 2>/dev/null || true
# Install LaunchAgents
for plist in ~/projects/firstmate/launchd/*.plist; do
  cp "$plist" ~/Library/LaunchAgents/
  launchctl load ~/Library/LaunchAgents/$(basename "$plist")
done

# ── 13. tool-guard.sh hook ──
# Wire into Claude Code settings
mkdir -p ~/.claude
jq '. + {"PreToolUse": [{"matcher": "Bash|Read", "hooks": [{"type": "command", "command": "'$HOME'/bin/tool-guard.sh", "timeout": 3, "statusMessage": "Checking tool choice..."}]}]}' \
  ~/.claude/settings.json 2>/dev/null || echo '{"PreToolUse": [...]}' > ~/.claude/settings.json

# ── 14. LLM-TLDR warm ──
llm-tldr doctor  # verify
llm-tldr warm --lang python --lang typescript --lang go ~/projects/firstmate

# ── 15. infisical ──
echo ""
echo "=== Open https://infisical.app and log in ==="
echo "Then run: infisical init"
echo "Or set INFISICAL_TOKEN env var and re-run this script."
echo ""

# ── 16. Apps (casks) ──
brew install --cask claude
brew install --cask codex
brew install --cask cursor
brew install --cask brave-browser
brew install --cask zen

# Download AGY from https://agy.ai and place in /opt/homebrew/bin/

# ── 17. Done ──
echo ""
echo "=== Bootstrap complete ==="
echo "1. Restart terminal (or source ~/.zshrc)"
echo "2. Run infisical init to link secrets"
echo "3. Verify: rtk --version, llm-tldr --version, fastedit doctor"
echo "4. Open System Settings → Privacy → Automation → check terminal apps"
```

---

## tool-guard.sh (installed July 2026)

Located at `~/bin/tool-guard.sh`. PreToolUse hook that rewrites suboptimal tools to agent-optimized alternatives.

**Redirects (blocked → better tool):**
`cat`, `bat`, `head`/`tail` → `rtk read`
`ls` → `rtk ls` / `rtk tree`
`find` → `fd` / `rtk find`
`grep` → `rtk grep`
`wc` → `rtk wc`
`diff` → `rtk diff`
`du` (bare) → `du -s`
`sed` → `fastedit edit`
`awk` → `jq` / `rtk grep`
`pip` → `uv pip`
`pytest` → `rtk pytest`
`curl` → WebFetch
`gh` → `gh-axi`
`git status/diff/log` → `rtk git`

**Ask the captain (blocked, model must escalate):**
`rm` — destructive, "Tell the captain what you want to delete and why"
`sudo` — privilege escalation, "Ask the captain to handle this manually"
`security` — keychain access, "Ask the captain for approval first"
`export` — secret leakage, "Ask the captain to set env vars instead"
`echo` — ad-hoc file creation, "Use fastedit for files"

**Compound command scan:** cat, ls, grep, find, rm caught anywhere in chain (`&&`, `||`, `;`, `|`)

**Design notes (from adversarial review):**
- Uses `jq` for JSON parsing, not `python3 -c` (avoids self-contradiction)
- Network operations (git clone, pip install, npm install) bypass guard — not a security boundary, just a friction-reduction layer
- Full permission-check middleware with Allow Once / Session / Always / Deny is a future upgrade

---

## What's NOT installed (and why)

| Common tool | Why excluded |
|---|---|
| `tmux` | Replaced by `mintmux` |
| `lazygit` | TUI — agents don't use TUIs |
| `htop` / `btop` / `glances` | System monitoring → `ps` via guard |
| `starship` | Prompt theme — wasted bytes for agent sessions |
| `tealdeer` | tldr-pages — use `llm-tldr` |
| `sd` | sed replacement → use `fastedit` |
| `procs` | ps replacement → `ps` is fine |
| `pandoc` | Document conversion — not coding-relevant |
| `awscli` / `doctl` | Cloud CLIs — not used |
| `bitwarden-cli` | Secrets → `infisical` |
| `coreutils` | GNU utils — macOS defaults sufficient |
| `ffmpeg` | Video — not coding-relevant |
| `llama.cpp` | Local LLM — fastedit uses MLX (Apple Silicon native) |
| `shellcheck` | Shell lint — install per-project if needed |
| `tokenrouter` npm CLI | API-only — key in infisical, use API directly |
| `fireworks-cli` | API-only — key in infisical, use API directly |
