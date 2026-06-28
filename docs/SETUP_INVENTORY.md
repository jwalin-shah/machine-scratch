# Setup Inventory

This file tracks what is **active on this machine**. A tool or config is not
active unless listed here or in `ACTIVE_MACHINE_SETUP.md`.

Last aligned with live machine via `bin/verify-active-config.sh` + PATH check.

## Active And Reviewed

### Control repo and policy

| Item | Source | Active path | Notes |
|---|---|---|---|
| machine-scratch | GitHub | `~/projects/machine-scratch` | Control repo |
| tool policy JSON | machine-scratch | `config/tool-policy.json` | Single source of truth for allow/deny |
| policy renderer | machine-scratch | `bin/policy-render.sh` | Claude / OpenCode / Cursor / Codex fragments |
| installer | machine-scratch | `bin/install-active-config.sh` | Pushes policy to all harnesses |
| verify (all harnesses) | machine-scratch | `bin/verify-active-config.sh` | Structural drift check |
| verify (OpenCode) | machine-scratch | `bin/verify-opencode-config.sh` | OpenCode-specific |
| test suite | machine-scratch | `bin/test-all-policy.sh` | Tier-1 automated policy tests |

### Agent rules and skills

| Item | Source | Active path | Notes |
|---|---|---|---|
| agent rules | machine-scratch | `agent-rules/` → `~/.agent-rules` | GLOBAL.md, TOOL_REGISTRY.md, KNOWN_ISSUES.md |
| find-docs skill | ctx7 | `~/.agents/skills/find-docs` | Context7 library docs |
| tool-policy skill | machine-scratch | `skills/tool-policy/` → `~/.agents/skills/tool-policy` | House policy architecture |
| pioneer-api skill | machine-scratch | `skills/pioneer-api/` → `~/.agents/skills/pioneer-api` | Pioneer API workflows |
| inference-net skill | machine-scratch | `skills/inference-net/` → `~/.agents/skills/inference-net` | Catalyst / `inf` CLI |

### Tool guard (cross-harness)

| Item | Source | Active path | Notes |
|---|---|---|---|
| core hook | machine-scratch | `~/bin/tool-guard.sh` | Claude + Codex PreToolUse |
| Cursor adapter | machine-scratch | `~/bin/tool-guard-cursor.sh` | Cursor v1 hooks I/O |
| OpenCode plugin | machine-scratch | `~/.config/opencode/plugins/tool-guard/` | Bash + native tool deny |

### Harness configs

| Item | Source | Active path | Notes |
|---|---|---|---|
| OpenCode config | machine-scratch | `~/.config/opencode/opencode.json` | TokenRouter, Pioneer, Inference.net |
| Claude settings | machine-scratch | `~/.claude/settings.json` (+ per-account dirs) | Native perms + PreToolUse hook |
| Codex hooks | machine-scratch | `~/.codex/hooks.json` | `{ "hooks": { "PreToolUse": [...] } }` |
| Cursor cli-config | machine-scratch | `~/.cursor/cli-config.json` | Shell allowlist + deny |
| Cursor hooks | machine-scratch | `~/.cursor/hooks.json` | v1: beforeShellExecution, beforeReadFile, preToolUse |

### Secrets and daemons

| Item | Source | Active path | Notes |
|---|---|---|---|
| secret-cache | quota-core (reference) | `~/.local/bin/secret-cache` | Infisical-backed cache |
| secret-cache refresh | machine-scratch | `~/Library/LaunchAgents/com.jwalinshah.secret-cache-refresh.plist` | RunAtLoad + daily |

### Launchers

| Cmd | Binary | Secrets | Notes |
|---|---|---|---|
| `ca` | Claude Code | OAuth (account A) | `~/bin/ca` → claude-launch |
| `cb` | Claude Code | OAuth (account B) | `~/bin/cb` |
| `ct` | Claude Code | TokenRouter key | `~/bin/ct` |
| `ccp` | Claude Code | Pioneer key | `~/bin/ccp` |
| `oo` | OpenCode | ChatGPT Plus OAuth | `~/.local/bin/oo` — no secret-cache |
| `ot` | OpenCode | TokenRouter key | `~/.local/bin/ot` — via secret-cache exec |
| `op` | OpenCode | Pioneer key | `~/.local/bin/op` — via secret-cache exec |
| `cx` | Codex CLI | None (ChatGPT/Codex auth) | `~/.local/bin/cx` — bare `codex` |
| `cu` | cursor-agent | Cursor account | `~/bin/cu` — curl install, not Homebrew cask |
| `agy` | Antigravity CLI | Own auth | `~/bin/agy` |

### CLI tools on PATH (in tool-policy bash_allow)

All registered in `config/tool-policy.json` and rendered into Claude, Cursor,
and OpenCode native allow lists. Codex allows via `tool-guard.sh` hook.

| Tool | PATH | Policy status | Caveat |
|---|---|---|---|
| `rtk` | `/opt/homebrew/bin/rtk` | ACTIVE | Default for read/grep/git/gh |
| `gh-axi` | `/opt/homebrew/bin/gh-axi` | ACTIVE | Preferred over raw `gh` |
| `lavish-axi` | `/opt/homebrew/bin/lavish-axi` | ACTIVE | HTML review artifacts |
| `chrome-devtools-axi` | `/opt/homebrew/bin/chrome-devtools-axi` | ACTIVE | Browser automation |
| `githits` | `/opt/homebrew/bin/githits` | ACTIVE | Public code search (CLI, not MCP) |
| `ctx7` | `/opt/homebrew/bin/ctx7` | ACTIVE | Context7 docs (`find-docs` skill) |
| `llm-tldr` | `~/.local/bin/llm-tldr` | ACTIVE | Repo structure / arch |
| `fastedit` | `~/.local/bin/fastedit` | ACTIVE | read/search OK; **edit needs MLX + model** |
| `cognee-cli` | `~/.local/bin/cognee-cli` | ACTIVE | Session memory |
| `cocoindex-code` / `ccc` | `~/.local/bin/` | ACTIVE | Code indexing |
| `treehouse` | `~/.local/bin/treehouse` | ACTIVE | Git worktree pool |
| `inf` | `/opt/homebrew/bin/inf` | ACTIVE | Inference.net Catalyst |
| `pioneer` | `/opt/homebrew/bin/pioneer` | ACTIVE | Pioneer SLM platform |
| `jq`, `yq`, `uv`, `du -s` | various | ACTIVE | Direct bash OK |
| `gtimeout` / `timeout` | coreutils | ACTIVE | Bound smoke tests only |

**Infra (installed, denied in agent bash — use rtk):** `rg`, `fd`, `eza`, `bat`, `git`, `gh`, `bun`.

## Reference Only

| Item | Path | Notes |
|---|---|---|
| machine-bootstrap | `~/projects/examples/machine-bootstrap` | Historical; do not point active config here |
| quota-core | `~/projects/examples/quota-core` | secret-cache source reference |

## Not installed / not used

These names appear in older docs or as `-axi` variants. We use the base CLI instead.

| Name | We use instead | Notes |
|---|---|---|
| `githits-axi` | `githits` | No separate binary found |
| `coco-axi` | `cocoindex-code` / `ccc` | No separate binary found |
| `cognee-axi` | `cognee-cli` | No separate binary found |
| `context7` / `c7` | `ctx7` | Context7 CLI binary name |
| `fm-tasks` | — | In `planned_or_unverified`; not on PATH |

## Harnesses — review status

| Harness | Policy wired | Automated verify | Manual live check |
|---|---|---|---|
| OpenCode | Yes | `verify-opencode-config.sh` | Optional: `test-opencode-live.sh ot --quick` |
| Claude (`ca`) | Yes | `verify-active-config.sh` | Prompt: deny `cat README.md` |
| Codex (`cx`) | Yes | `test-codex-hooks.sh` | Prompt: deny `cat README.md` (Bash hook only) |
| Cursor IDE | Yes | `test-cursor-hooks.sh` | Restart IDE, then same prompt |
| cursor-agent (`cu`) | Same as Cursor | Same | Same |

## Still needs work (not blocking policy)

| Item | Status | Notes |
|---|---|---|
| Claude OAuth | Per-account | `/login` once in `~/.claude-a`, `~/.claude-b` |
| OpenAI OAuth (`oo`) | May need login | `opencode providers login` |
| `fastedit edit` | Broken | Run `fastedit pull --model mlx-8bit` + install `[mlx]` extra |
| Antigravity / Daytona | Installed | Workflow docs pending |
| Live agent confirmation | Manual | One deny/allow prompt per harness after install |

## Pending decisions

- Whether to add secret-scoped `cx` variant (currently bare Codex auth).
- How Antigravity and Daytona fit daily agent workflow.
- Whether to expand OpenCode provider model lists further.
