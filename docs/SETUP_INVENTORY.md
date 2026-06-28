# Setup Inventory

This file tracks what has been reviewed and what is still pending. A tool or
repo is not active unless it is listed as active here or in
`ACTIVE_MACHINE_SETUP.md`.

## Active And Reviewed

| Item | Source | Active Path | Notes |
|---|---|---|---|
| machine-scratch | GitHub | `~/projects/machine-scratch` | Control repo |
| agent rules | machine-scratch | `~/projects/machine-scratch/agent-rules` → `~/.agent-rules` | GLOBAL.md, TOOL_REGISTRY.md, KNOWN_ISSUES.md |
| secret-cache | quota-core (example) | `~/.local/bin/secret-cache` | Infisical-backed local cache |
| OpenCode config | machine-scratch | `~/.config/opencode/opencode.json` | TokenRouter, Pioneer, Inference.net |
| OpenCode tool guard | machine-scratch | `~/.config/opencode/plugins/tool-guard/index.js` | Denies suboptimal/destructive bash commands |
| Claude tool guard | machine-scratch | `~/.claude/settings.json` | PreToolUse hook to `~/bin/tool-guard.sh` |
| Codex tool guard | machine-scratch | `~/.codex/hooks.json` | PreToolUse hook to `~/bin/tool-guard.sh` |
| claude-launch stack | machine-scratch | `~/bin/claude-launch`, `agentlib.py`, `claude-endpoints.toml` | Multi-account Claude launcher |
| secret-cache refresh | machine-scratch | `~/Library/LaunchAgents/com.jwalinshah.secret-cache-refresh.plist` | RunAtLoad + daily |
| `oo` launcher | machine-scratch | `~/.local/bin/oo` | OpenCode GPT 5.5 via TokenRouter |
| `ot` launcher | machine-scratch | `~/.local/bin/ot` | OpenCode default cheap TokenRouter |
| `op` launcher | machine-scratch | `~/.local/bin/op` | OpenCode via Pioneer |
| `cx` launcher | machine-scratch | `~/.local/bin/cx` | Codex through `secret-cache exec` |
| `ca` launcher | machine-scratch | `~/bin/ca` | Claude Code account A (OAuth) |
| `cb` launcher | machine-scratch | `~/bin/cb` | Claude Code account B (OAuth) |
| `ct` launcher | machine-scratch | `~/bin/ct` | Claude Code via TokenRouter |
| `ccp` launcher | machine-scratch | `~/bin/ccp` | Claude Code via Pioneer |
| `cu` launcher | machine-scratch | `~/bin/cu` | Cursor Agent CLI |
| `agy` launcher | machine-scratch | `~/bin/agy` | Antigravity CLI |

## Reference Only

| Item | Path | Notes |
|---|---|---|
| machine-bootstrap | `~/projects/examples/machine-bootstrap` | Historical agent rules, skills, bootstrap scripts |
| quota-core | `~/projects/examples/quota-core` | secret-cache source; runtime already installed |

## Installed Tools To Keep Reviewing

| Item | Status | Notes |
|---|---|---|
| Claude / Claude Code | Installed | OAuth login needed per account (ca/cb) |
| Codex | Installed | Needs config review beyond hook file |
| OpenCode | Installed | Active config controlled here |
| cursor-agent / Cursor IDE | Installed | Policy via `cli-config.json` Shell allowlist + v1 hooks (`beforeShellExecution`, `beforeReadFile`, `preToolUse`). Restart Cursor IDE after `install-active-config.sh`. |
| Antigravity CLI / IDE | Installed | Needs workflow docs |
| Daytona | Installed | Needs login/API-key workflow docs |

## Planned Tools (approved, not installed)

| Tool | Fallback |
|---|---|
| `llm-tldr` | `fd`, `rg`, targeted reads |
| `fastedit` | normal editor / patch |
| `gh-axi` | `gh --json` |
| `githits-axi` | web search |
| `coco-axi`, `cognee-axi` | manual workflow |
| `context7` / `c7` | web search |

## Pending Decisions

- Codex live bash enforcement (PreToolUse fires for Bash only — no native Read hook).
- Whether to expand OpenCode provider model lists from examples.
- How Antigravity, Daytona, and Pioneer fit into the normal agent workflow.
