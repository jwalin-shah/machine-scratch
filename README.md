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

## Quick start (new Mac)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jwalin-shah/machine-scratch/main/bin/bootstrap.sh)"
```

## Core tools

| Tool | Purpose |
|------|---------|
| `llm-tldr` | Code analysis (AST, call graph, semantic search) |
| `rtk` | Token-efficient wrappers (ls, read, grep, find, diff, etc.) |
| `fastedit` | AST-aware editing (edit, rename, delete, move) |
| `coco-axi` + `cognee-axi` | Code index + session memory |
| `gh-axi` | GitHub interaction |
| `tool-guard.sh` | PreToolUse hook — redirects bad tools, gates dangerous ones |
