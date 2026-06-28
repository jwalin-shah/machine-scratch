# machine-scratch

> One command to bootstrap a new Mac. Everything has a reason.

## What's here

```
bin/            — tools (tool-guard.sh, bootstrap, etc.)
config/         — templates for direnv, git, ssh, zsh, claude, codex, cursor
design/         — design docs (Issue #1 tool set, Issue #2 bootstrap)
launchd/        — LaunchAgent plists
scripts/        — helper scripts
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
| `llm-tldr` | Code analysis (AST, call graph, semantic search) |
| `rtk` | Token-efficient wrappers (ls, read, grep, find, diff, etc.) |
| `fastedit` | AST-aware editing (edit, rename, delete, move) |
| `coco-axi` + `cognee-axi` | Code index + session memory |
| `gh-axi` | GitHub interaction |
| `tool-guard.sh` | PreToolUse hook — redirects bad tools, gates dangerous ones |
