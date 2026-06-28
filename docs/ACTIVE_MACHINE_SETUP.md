# Active Machine Setup

`machine-scratch` is the design/control repo. Active machine config is installed
incrementally from this repo; do not run `bin/bootstrap.sh` wholesale on an
existing machine.

## Active Repos

- `~/projects/machine-scratch` — design/control, agent rules, and incremental installer
- `~/projects/examples/machine-bootstrap` — reference only; mine for ideas, do not point active config here
- `~/projects/examples/quota-core` — reference for `secret-cache` source; runtime installed to `~/.local/bin/secret-cache`

## Agent Rules

Policy lives in `~/projects/machine-scratch/agent-rules/` and is symlinked to
`~/.agent-rules/` by the install script. OpenCode, Claude, and Codex all read
from there.

## Secrets

Infisical is the source of truth. `secret-cache` caches provider keys in
`~/.cache/quota-core/secrets.json` with `0600` file permissions under a `0700`
directory.

Agents get secrets through command-scoped injection:

```bash
secret-cache exec -- opencode
```

Do not export provider keys in shell startup files. Do not commit secrets.

The refresh LaunchAgent runs at login and once daily:

```bash
secret-cache refresh
```

## Providers

OpenCode providers are configured in `config/opencode/opencode.json`:

- TokenRouter: `TOKENROUTER_API_KEY`
- Pioneer AI: `PIONEER_API_KEY`
- Inference.net: `INFERENCE_NET_API_KEY`

These env vars are expected only when launched through `secret-cache exec`.

## Launchers

### Claude Code (`~/bin`)

- `ca` — Account A (OAuth, primary)
- `cb` — Account B (OAuth, secondary)
- `ct` — TokenRouter gateway
- `ccp` — Pioneer gateway

Each OAuth account needs `/login` once in `~/.claude-a` or `~/.claude-b`.

### OpenCode (`~/.local/bin`)

Global config: permissions, instructions, tool-guard (`~/.config/opencode/opencode.json`).

Per-profile overlays (`~/.config/opencode/profiles/`):

- `oo` — ChatGPT Plus OAuth → `openai/gpt-5.5` (not TokenRouter)
- `ot` — TokenRouter → `deepseek/deepseek-v4-flash` (default, via secret-cache)
- `op` — Pioneer (via secret-cache)

### Other

- `cx` — Codex with secrets (`~/.local/bin`)
- `cu` — Cursor Agent CLI (`~/bin`, Cursor auth)
- `agy` — Antigravity CLI (`~/bin`, own auth)

## Tool Policy

Three enforcement layers:

1. **Instructions** — `~/.agent-rules/GLOBAL.md` and `TOOL_REGISTRY.md`
2. **OpenCode permissions** — `config/opencode/opencode.json` denies bash
   `cat`/`ls`/… and native `read`/`grep`/`glob`/`list`
3. **Plugin/hooks** — OpenCode tool-guard plugin + Claude/Codex `~/bin/tool-guard.sh`

Do not add agent-level permission blocks that set `bash: allow`; those override global deny policy.

## Install Incrementally

```bash
~/projects/machine-scratch/bin/install-active-config.sh
```

This installs agent rules symlink, OpenCode config, launchers, claude-launch
stack, tool guard, and the secret-cache refresh LaunchAgent. It does not install
packages or overwrite unrelated shell/application config.
