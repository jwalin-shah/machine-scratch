# Completion Checklist

Definition of done for machine-scratch active setup. Run `rtk test bin/test-all-policy.sh`
after any change. Update status here when a row moves to DONE.

## Tier 1 — Automated (must be green)

| Check | Command | Status |
|---|---|---|
| Hook logic (54+ cases) | `bin/test-tool-guard.sh` | DONE |
| rtk stack smoke | `bin/verify-rtk-stack.sh` | DONE |
| Codex hooks schema | `bin/test-codex-hooks.sh` | DONE |
| Cursor hooks + adapter | `bin/test-cursor-hooks.sh` | DONE |
| All harness structural drift | `bin/verify-active-config.sh` | DONE |
| OpenCode deep verify | `bin/verify-opencode-config.sh` | DONE |
| Docs match live setup | `docs/SETUP_INVENTORY.md` | DONE |
| Policy renders all harnesses | `bin/policy-render.sh all` | DONE |

## Tier 2 — Toolchain on PATH

| Tool | Registered in policy | On PATH | Fully working |
|---|---|---|---|
| `rtk` | yes | yes | yes |
| `gh-axi`, `lavish-axi`, `chrome-devtools-axi` | yes | yes | yes |
| `githits`, `ctx7`, `llm-tldr` | yes | yes | yes |
| `cognee-cli`, `cocoindex-code`, `treehouse` | yes | yes | yes |
| `inf`, `pioneer` | yes | yes | yes |
| `fastedit` | yes | yes | **partial** — see below |
| `fm-tasks` | planned only | no | n/a |

### fastedit status (2026-06-28)

| Component | Status |
|---|---|
| MLX backend | DONE (`fastedits[mlx]` installed) |
| Model cache (mlx-8bit) | DONE (~1.7 GB at `~/.cache/fastedit/models/mlx-8bit`) |
| `fastedit read` / `doctor` | DONE |
| `fastedit edit` / `rename` | **DONE** after `bin/install-tldr-code.sh` (structure→tldr-code) |

Fix: `bin/install-tldr-code.sh` installs parcadei [tldr-code](https://github.com/parcadei/tldr-code) v0.4.0
as `~/.local/bin/tldr-code` and replaces `~/.local/bin/tldr` with a dispatcher (llm-tldr for `tree`/`structure`/…,
tldr-code for `references`/`definition`/`search`).

```bash
bin/install-tldr-code.sh
tldr references --help
fastedit edit --replace hello --snippet 'world' /tmp/test.py
rtk test bin/verify-rtk-stack.sh
```

## Tier 3 — Live harness behavior (manual)

One deny + one allow prompt per harness. Copy-paste:

```
Run exactly this bash command and show me the output: cat README.md
Run exactly this bash command: rtk read README.md
```

| Harness | Restart needed | Deny cat | Allow rtk read | Status |
|---|---|---|---|---|
| OpenCode (`ot`) | no | optional auto via `test-opencode-live.sh` | optional | DONE |
| Claude (`ca`) | no | manual | manual | DONE |
| Codex (`cx`) | no | manual (Bash hook only) | manual | DONE |
| Cursor IDE | **yes — restart after install** | manual | manual | DONE |

Tier 1 proves config is correct. Tier 3 proves the harness actually invokes hooks.

## Tier 4 — Auth and secrets (manual)

| Item | Status |
|---|---|
| Claude OAuth account A (`ca`) | verify `/login` in `~/.claude-a` |
| OpenCode `oo` (ChatGPT OAuth) | `opencode providers login` if needed |
| `ot` / `op` secret-cache keys | `secret-cache refresh` |
| Codex (`cx`) | uses Codex/ChatGPT account auth |

Do not print secret values in docs or commits.

## Tier 5 — Not in scope yet

| Item | Notes |
|---|---|
| Antigravity (`agy`) | installed, **WIRED** (`~/.gemini/config/hooks.json` + adapter) |
| GNU `tree` for `rtk tree` | `brew install tree` |
| Daytona workflows | installed, docs pending |
| `fm-tasks` | in `planned_or_unverified` |
| Secret-scoped `cx` variant | launcher is bare codex today |
| Live OpenCode token probes | `bin/test-opencode-live.sh ot --quick` |

## What more will come out of this setup

As agents use these harnesses daily, expect:

1. **Policy tweaks** — new tools added to `bash_allow`, new denies, rerender + `test-all-policy.sh`
2. **Harness upstream changes** — Cursor/Codex hook schema updates → update `policy-render.sh`, check ctx7
3. **New skills** — symlink into `skills/` + `install-active-config.sh`
4. **Live probe failures** — usually hook not loaded (Cursor restart) or OAuth drift
5. **fastedit unblock** — once correct `tldr` is on PATH, add edit smoke test to Tier 1

## Current overall score

| Area | Score | Notes |
|---|---|---|
| Policy registration | 100% | All real tools in tool-policy.json + rendered |
| Automated verify | 100% | All Tier 1 scripts green |
| Documentation | 100% | SETUP_INVENTORY aligned with live state |
| fastedit edit | **DONE** | `install-tldr-code.sh` + `verify-rtk-stack.sh` |
| Live harness proof | ot/ca/cx/cu DONE | agy: `rtk test bin/test-antigravity-hooks.sh` + live list_dir deny |
| Auth/OAuth | unknown | Check Tier 4 yourself |

**Honest bottom line:** Tier 1 is perfect and committed. We are not at 100% overall until
Tier 3 live prompts pass and fastedit edit works (tldr-code binary).
