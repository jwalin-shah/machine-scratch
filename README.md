# machine-scratch

> One command to bootstrap a new Mac. Everything has a reason.

## What's here

```
bin/            — tool-guard, policy-render, install, verify, test scripts
config/         — tool-policy.json, opencode, claude, launchers, launchd
agent-rules/    — GLOBAL.md, TOOL_REGISTRY.md (→ ~/.agent-rules)
docs/           — TOOL_POLICY.md, SETUP_INVENTORY.md, vendor ctx7 indexes
skills/         — tool-policy, pioneer-api, inference-net (→ ~/.agents/skills)
design/         — design docs
PHILOSOPHY.md   — principles we operate by
```

## Source of truth

`machine-scratch` is the control repo for the active machine setup. Every
config, launcher, repo, provider, and daemon must be reviewed here before it is
promoted into the live machine.

`bin/bootstrap.sh` is reference-only historical material. Do not run it as the
source of truth on an existing machine. Use it to mine ideas, then promote only
reviewed pieces through small scripts like `bin/install-active-config.sh`.

## Quick start (reference only)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jwalin-shah/machine-scratch/main/bin/bootstrap.sh)"
```

Do not use this command on an already configured machine unless the script has
been freshly reviewed for the target machine.

## Core tools

| Tool | Purpose |
|------|---------|
| `rtk` | Token-efficient wrappers (read, grep, ls, find, git, gh, diff, test) |
| `llm-tldr` | Repo structure, architecture, semantic search |
| `fastedit` | AST-aware editing (read/search; edit needs MLX model) |
| `gh-axi` | Token-efficient GitHub CLI |
| `githits` | Indexed search across open-source code |
| `ctx7` | Context7 docs lookup (+ `find-docs` skill) |
| `cognee-cli` / `cocoindex-code` | Session memory + code indexing |
| `inf` / `pioneer` | Inference.net Catalyst + Pioneer SLM platform |
| `tool-guard.sh` | Cross-harness policy hook |

Policy architecture: `docs/TOOL_POLICY.md`. Install: `bin/install-active-config.sh`. Verify: `bin/test-all-policy.sh`.
