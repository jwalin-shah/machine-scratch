# Active Machine Setup

`machine-scratch` is the design/control repo. Active machine config is installed
incrementally from this repo; do not run `bin/bootstrap.sh` wholesale on an
existing machine.

## Active Repos

- `~/projects/machine-scratch` — design/control, agent rules, installer, tests
- `~/projects/examples/machine-bootstrap` — reference only
- `~/projects/examples/quota-core` — reference for `secret-cache` source

## Agent Rules and Skills

Policy lives in `~/projects/machine-scratch/agent-rules/` → symlinked to
`~/.agent-rules/`. Skills in `~/projects/machine-scratch/skills/` →
`~/.agents/skills/` (find-docs, tool-policy, pioneer-api, inference-net).

## Secrets

Infisical → `secret-cache refresh` → `secret-cache exec -- <command>`.

Do not export provider keys in shell startup files.

LaunchAgent refreshes at login + daily: `com.jwalinshah.secret-cache-refresh.plist`.

## Providers (OpenCode)

Configured in `config/opencode/opencode.json`:

- TokenRouter: `TOKENROUTER_API_KEY` (via `ot`, `ct` launchers)
- Pioneer: `PIONEER_API_KEY` (via `op`, `ccp`)
- Inference.net: `INFERENCE_NET_API_KEY`
- OpenAI OAuth: ChatGPT Plus (via `oo` — no secret-cache)

## Launchers

| Cmd | Tool | Auth |
|---|---|---|
| `ca` / `cb` / `ct` / `ccp` | Claude Code | OAuth / TokenRouter / Pioneer |
| `oo` / `ot` / `op` | OpenCode | OAuth / TokenRouter / Pioneer |
| `cx` | Codex CLI | Codex/ChatGPT account (no secret-cache) |
| `cu` | cursor-agent | Cursor account |
| `agy` | Antigravity | Own auth |

OAuth once per Claude account: `/login` in `~/.claude-a`, `~/.claude-b`.

## Tool Policy (all harnesses)

Source: `config/tool-policy.json` → `bin/policy-render.sh` → per-harness install.

| Harness | Native permissions | Hook / plugin |
|---|---|---|
| OpenCode | `permission.bash` + deny native read/grep/glob/list | tool-guard plugin |
| Claude | `permissions.allow/deny` incl. Read | `tool-guard.sh` PreToolUse |
| Codex | hook-only | `~/.codex/hooks.json` → tool-guard |
| Cursor | `cli-config.json` Shell allowlist | v1 hooks → tool-guard-cursor |

Docs: `docs/TOOL_POLICY.md`. Vendor schemas: ctx7 via `docs/vendor/agent-harnesses/llms.txt`.

## Install and verify

```bash
~/projects/machine-scratch/bin/install-active-config.sh
rtk test ~/projects/machine-scratch/bin/test-all-policy.sh
```

Restart Cursor IDE after install if hooks changed.

Does **not** install Homebrew packages — only configs, hooks, launchers, symlinks.
