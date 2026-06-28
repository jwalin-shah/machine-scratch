# Completion Checklist

Definition of done for machine-scratch active setup. Run `rtk test bin/test-all-policy.sh`
after any change. Update status here when a row moves to DONE.

## Tier 1 — Automated (must be green)

| Check | Command | Status |
|---|---|---|
| Hook logic (47 cases) | `bin/test-tool-guard.sh` | DONE |
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
| `fastedit edit` / `rename` | **BLOCKED** — needs `tldr references` subcommand |

Root cause: `fastedit` expects [parcadei/tldr-code](https://github.com/parcadei/tldr-code)
Rust `tldr` with a `references` command. This machine has `llm-tldr` 1.5.2 (Python),
which does not expose `references`. Until the correct `tldr` binary is on PATH,
agents should use normal patch/edit tools for writes.

Fix path (requires captain approval for package install):

```bash
# Option A: build/install parcadei tldr-code Rust binary as `tldr` on PATH
# Option B: wait for llm-tldr release that adds `references`
# Verify: tldr references --help  &&  fastedit edit --replace …
```

## Tier 3 — Live harness behavior (manual)

One deny + one allow prompt per harness. Copy-paste:

```
Run exactly this bash command and show me the output: cat README.md
Run exactly this bash command: rtk read README.md
```

| Harness | Restart needed | Deny cat | Allow rtk read | Status |
|---|---|---|---|---|
| OpenCode (`ot`) | no | optional auto via `test-opencode-live.sh` | optional | NOT RUN |
| Claude (`ca`) | no | manual | manual | NOT RUN |
| Codex (`cx`) | no | manual (Bash hook only) | manual | NOT RUN |
| Cursor IDE | **yes — restart after install** | manual | manual | NOT RUN |

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
| Antigravity / Daytona workflows | installed, docs pending |
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
| fastedit edit | ~70% | MLX+model done; tldr `references` missing |
| Live harness proof | 0% | Needs your 4 manual prompts |
| Auth/OAuth | unknown | Check Tier 4 yourself |

**Honest bottom line:** Tier 1 is perfect and committed. We are not at 100% overall until
Tier 3 live prompts pass and fastedit edit works (tldr-code binary).
