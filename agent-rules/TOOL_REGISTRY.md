# Tool Registry

Source of truth: `~/projects/machine-scratch/agent-rules/`.
Policy file: `~/projects/machine-scratch/config/tool-policy.json`.
Architecture + testing: `~/projects/machine-scratch/docs/TOOL_POLICY.md`.
Vendor harness schemas: `ctx7 docs` — see `docs/vendor/agent-harnesses/llms.txt`.

## Status Key

- **ACTIVE** — installed and on PATH; use by default.
- **PLANNED** — approved after review; use fallback until installed.

## The Stack (use in order)

| Tool | Status | What it does | Agent-facing use |
|---|---|---|---|
| `rtk` | ACTIVE | Token-optimized read/grep/ls/find/git/gh/diff/test | **Default for all file/git/github ops** |
| `llm-tldr` | ACTIVE | Structure/arch/search on local code | Before opening many files |
| `fastedit` | ACTIVE | AST-aware file edits | read/search OK; edit needs MLX model (see KNOWN_ISSUES) |
| `jq` / `yq` | ACTIVE | Structured data | Direct bash OK |
| `du -s` / `du -sh` | ACTIVE | Parseable disk usage | Direct bash OK — not `dust` |
| `gh-axi` | ACTIVE | Token-efficient GitHub CLI | Preferred over `rtk gh` for GitHub-heavy work |
| `lavish-axi` | ACTIVE | Human review surface for HTML artifacts | When agent ships review artifacts |
| `chrome-devtools-axi` | ACTIVE | Browser automation | UI testing / scraping |
| `ctx7` | ACTIVE | Context7 library docs lookup + `find-docs` skill | Library docs / API references |
| `cognee-cli` | ACTIVE | Graph-based session memory | Cross-session memory |
| `cocoindex-code` / `ccc` | ACTIVE | Incremental code indexing | Build code indexes |
| `treehouse` | ACTIVE | Pool of reusable git worktrees | Parallel agents on one repo |
| `githits` | ACTIVE | Indexed search/grep/read across open-source code (CLI, no MCP) | Real-world code examples, dependency source |
| `inf` (inference.net) | ACTIVE | Catalyst gateway/tracing/evals/training | Observability + fine-tuning workflow |
| `pioneer` (fastino) | ACTIVE | Pioneer datasets/training/inference | SLM fine-tuning, NER, GLiNER |
| `bun` | INFRA | Runtime for Pioneer CLI | Don't call directly |
| `gtimeout` / `timeout` | ACTIVE | Bound long-running live smoke tests | Use only around tests/agent probes |
| `rg`, `fd`, `eza`, `bat`, `git`, `gh` | INFRA | Backends for rtk / human terminal | **Denied in agent bash — use rtk** |
| `githits-axi`, `coco-axi`, `cognee-axi` | UNVERIFIED | Not found in public registries | Use base tools |

## Skills installed (`~/.agents/skills/`)

| Skill | Source | When it triggers |
|---|---|---|
| `find-docs` | `ctx7 setup --cli --opencode` (Context7) | Any library/framework/SDK/cloud-service docs question |
| `tool-policy` | House skill, `skills/tool-policy/` | Tool policy edits, hook debugging, harness verify |
| `pioneer-api` | House skill, symlinked from `skills/pioneer-api/` (content copied from Pioneer's official `guides/agent-skills.md`) | Pioneer dataset/training/eval/inference work |
| `inference-net` | House skill, symlinked from `skills/inference-net/` | Catalyst gateway/tracing, HALO, `inf` CLI work |

## Launchers

| Command | Tool | Secrets | Purpose |
|---|---|---|---|
| `ca` | Claude Code | Profile key only | Account A (OAuth) |
| `ct` | Claude Code | TokenRouter key | Claude via TokenRouter |
| `ccp` | Claude Code | Pioneer key | Claude via Pioneer |
| `oo` | OpenCode | ChatGPT Plus OAuth | GPT 5.5 fast via OpenAI provider |
| `ot` | OpenCode | TokenRouter key | Default cheap TokenRouter |
| `op` | OpenCode | Pioneer key | Pioneer provider |
| `cx` | Codex | None (yet) | Codex CLI |
| `cu` | Cursor Agent | None (Cursor auth) | Cursor agent CLI |
| `agy` | Antigravity | None (own auth) | Antigravity CLI |

## File Ops Cheatsheet (agent — via rtk)

```bash
# rtk — use instead of cat/rg/eza/fd/bat/git/gh/grep/find/ls
rtk read path/to/file.py
rtk grep 'pattern'
rtk ls .
rtk tree --level=2 .
rtk find -name '*.json'
rtk git status
rtk gh pr list

# du — parseable disk usage (dust is for humans, denied for agents)
du -s path
du -sh path

# jq / yq — direct OK for structured mutation; use rtk json/read for display
jq '.key' file.json
yq '.key' file.yaml

# gtimeout / timeout — direct OK only to bound live tests or agent probes
gtimeout 120 rtk test bin/test-opencode-live.sh ot --quick
```

## Writes and Confirmations

Always confirm before:
- Destructive git ops (force-push, branch delete, PR close)
- Paid or external compute runs
- Bulk writes to Drive, Linear, Notion, or similar

## Redirects (enforced by OpenCode + tool-guard)

| Blocked | Use instead |
|---|---|
| `cat`, native Read | `rtk read` |
| `ls`, native List | `rtk ls` or `rtk tree` |
| `grep`, `rg`, native Grep | `rtk grep` |
| `find`, `fd`, native Glob | `rtk find` |
| `bat` | `rtk read` |
| `eza` | `rtk ls` or `rtk tree` |
| `dust`, bare `du` | `du -s` or `du -sh` |
| `git`, `gh` | `rtk git …`, `rtk gh …` |
| `export` | `secret-cache exec -- <command>` |
| `rm`, `sudo`, `security` | ask the captain |

GNU coreutils are installed for `gtimeout`; do not use GNU aliases like `gcat`, `gls`, `ggrep`, or `gfind` to bypass policy. The allowed GNU tool is `gtimeout` for bounding tests.
