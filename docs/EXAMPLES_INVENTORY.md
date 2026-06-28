# Examples Inventory

Reference repos live under `~/projects/examples/`. They are **not active machine
state**. Read them for patterns, import scripts, and architecture — promote pieces
into `machine-scratch` (or a future active repo) only after review.

Last updated: 2026-06-28 (cloned from `jwalin-shah/*`).

## Active vs reference

| Path | Role | Active? |
|---|---|---|
| `~/projects/machine-scratch/` | Control repo — policy, hooks, agent-rules, install | **Yes** |
| `~/projects/examples/*` | Reference clones — learn, mine, do not wire directly | **No** |
| `~/.agent-rules` | Symlink/copy from `machine-scratch/agent-rules/` | **Yes** |

## Cloned reference repos

| Repo | Path | Why it is here |
|---|---|---|
| **machine-bootstrap** | `examples/machine-bootstrap/` | Previous bootstrap; harness log paths, `backfill-tool-calls.py`, architecture docs |
| **quota-core** | `examples/quota-core/` | `secret-cache` source; Infisical → cached secrets model |
| **firstmate** | `examples/firstmate/` | Fleet orchestration — `fm-*` scripts, transcript import, task queue |
| **fm-sessiond** | `examples/fm-sessiond/` | Session analytics daemon (ChooChoo successor); cross-harness ingest target |
| **mintmux** | `examples/mintmux/` | tmux wrapper — `mm-ctl`, pane spawn, transcript enforcer |
| **memjuice** | `examples/memjuice/` | Cross-harness deterministic memory (Rust) |
| **go-utils** | `examples/go-utils/` | Shared Go libs; `agent-doctor` health checks |
| **treehouse** | `examples/treehouse/` | Git worktree pool |
| **agent-flight-recorder** | `examples/agent-flight-recorder/` | Session black-box recorder — read before building fm-sessiond v2 |

### Not cloned (optional later)

| Repo | Reason |
|---|---|
| `speech-to-text` | Voice stack; separate concern. Symlink in `machine-bootstrap/tools/` still points at `~/speech-to-text` if present. |
| `context-gateway`, `harness`, `agent-stack` | Overlap with machine-scratch — review on GitHub before cloning |
| Hackathon / career / scratch repos | Not needed for machine operating model |

## Harness log locations (for fm-sessiond ingest)

Canonical paths used by `machine-bootstrap/agent-rules/scripts/backfill-tool-calls.py`
and firstmate import scripts:

| Harness | Log location | Ingest status |
|---|---|---|
| Claude Code | `~/.claude-{a,b,token,pioneer}/projects/**/*.jsonl` | Spec exists |
| Codex | `~/.codex/sessions/**/rollout-*.jsonl` | Spec exists |
| OpenCode | `~/.local/share/opencode/opencode.db` | **Gap — add in fm-sessiond v2** |
| Cursor | `~/.cursor/projects/**/agent-transcripts/` | **Gap — add in fm-sessiond v2** |
| Pi | `~/.pi/agent/sessions/**/*.jsonl` | Spec exists |
| ChooChoo (legacy) | `~/.choochoo/sessions.db` | Deprecated; use fm-sessiond |

firstmate scripts to read when building ingest:

- `examples/firstmate/bin/fm-claude-main-import.py`
- `examples/firstmate/bin/fm-cursor-import.py`
- `examples/firstmate/bin/fm-transcripts-ingest.py`

## Symlinks in machine-bootstrap

`examples/machine-bootstrap/tools/` uses **relative** symlinks into sibling clones:

```
tools/firstmate  -> ../firstmate
tools/memjuice   -> ../memjuice
tools/mintmux    -> ../mintmux
```

## Clone / refresh

```bash
mkdir -p ~/projects/examples
cd ~/projects/examples

for repo in machine-bootstrap quota-core firstmate fm-sessiond mintmux memjuice go-utils treehouse agent-flight-recorder; do
  if [ -d "$repo/.git" ]; then
    git -C "$repo" pull --ff-only
  else
    rtk gh-axi repo clone jwalin-shah/$repo "$repo"
  fi
done
```

## Promotion checklist

Before moving anything from `examples/` to active:

1. Challenge: do we use this daily, or is it aspirational?
2. Copy the smallest useful fragment into `machine-scratch` (or install via `bin/`).
3. Document in `SETUP_INVENTORY.md` and `ACTIVE_MACHINE_SETUP.md`.
4. Verify with `bin/verify-active-config.sh` (or harness-specific test).
5. Never point `~/.config` or LaunchAgents at `examples/` paths directly.
