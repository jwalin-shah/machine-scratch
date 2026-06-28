# Permissions And Tool Policy

Full architecture, ctx7 vs house docs, and testing tiers:
**docs/TOOL_POLICY.md**. Vendor harness schema lookup: **docs/vendor/agent-harnesses/llms.txt**.


The permission model is reviewed and incremental. We do not require tools that
are not installed yet, and we do not allow broad agent-level overrides.

## Current Active Policy (All Harnesses)

**Default:** generated native permissions plus hook fallback. OpenCode uses bash `"*": "ask"`; Cursor uses `approvalMode: allowlist`; Claude uses native `permissions.allow/deny/ask`; Codex currently uses hook fallback.

**Always allow (no prompt):**

- `rtk *` — all rtk subcommands (read, grep, ls, find, git, gh, diff, test, …)
- `du -s` / `du -sh` — parseable disk usage (not `dust`)
- `jq *`, `yq *`
- `fastedit *`, `llm-tldr *`, `uv *`
- AXI: `gh-axi *`, `lavish-axi *`, `chrome-devtools-axi *`
- Docs/memory/index: `ctx7 *`, `cognee-cli *`, `cocoindex-code *`, `ccc *`
- `secret-cache exec *`
- `gtimeout *` / `timeout *` — bound live smoke tests only

**Hard deny (no prompt, no override):**

- Shell shortcuts: `cat`, `ls`, `grep`, `find`
- Direct CLIs (use rtk instead): `rg`, `eza`, `fd`, `bat`, `dust`
- VCS (use rtk instead): `git`, `gh`
- Bare `du` (use `du -s` only)
- Sensitive/destructive: `rm`, `sudo`, `security`, `export`
- GNU coreutils bypasses: `gcat`, `gls`, `ggrep`, `gfind`, `gdu`, `gsed`, `gawk`
- Native read/search/list tools where harnesses expose them: `read`, `grep`, `glob`, `list`

**Ask before running:**

- `webfetch`, `websearch`
- Any other bash not on the allow/deny lists (`"*": "ask"`)

Source of truth: `config/tool-policy.json`. `bin/policy-render.sh` renders native permission blocks for Claude, OpenCode, Cursor, and Codex hook config; `bin/install-active-config.sh` installs them live.

## Redirects

Agents should not use low-signal shell tools when rtk exists:

- `cat` → `rtk read`
- `grep` / `rg` → `rtk grep`
- `ls` / `eza` → `rtk ls` or `rtk tree`
- `find` / `fd` → `rtk find`
- `bat` → `rtk read`
- `dust` / bare `du` → `du -s`
- `git` / `gh` → `rtk git …` / `rtk gh …`
- `gcat`, `gls`, `ggrep`, `gfind` → same rtk redirects as their BSD/GNU-free equivalents

## Ask The Captain

The agent must stop and ask before:

- deleting files or directories
- using `sudo`
- reading or changing Keychain entries with `security`
- exporting secrets globally
- changing ownership or world-writable permissions
- loading/unloading LaunchAgents unless the user asked for setup work
- pushing, force-pushing, resetting, cleaning, or deleting branches
- uninstalling packages

## Harness Rule

Harness configs are generated from `config/tool-policy.json`. Do not hand-edit live permission blocks except for emergency debugging; update the policy and rerun `bin/install-active-config.sh`. OpenCode must use global permissions only. Do not add agent-level permission blocks that set `bash: allow`, because they can override global deny rules.

Native OpenCode tools are denied so agents must use bash with rtk:

- `read` → `rtk read`
- `grep` → `rtk grep`
- `glob` → `rtk find`
- `list` → `rtk ls`

## Secrets

Provider keys are never global shell state. They flow like this:

```text
Infisical -> secret-cache refresh -> secret-cache exec -- command
```

If a key changes in Infisical, refresh explicitly:

```bash
secret-cache refresh
```

## Testing Policy Changes

Three tiers — run in order:

**Tier 1 — all harnesses, no tokens (run after every policy edit):**

```bash
rtk test bin/test-all-policy.sh
```

This installs config, then runs: `test-tool-guard.sh` (hook logic), `test-codex-hooks.sh`, `test-cursor-hooks.sh` (adapter + schema), and `verify-active-config.sh` (Claude/Codex/Cursor/OpenCode structural drift).

**Tier 2 — OpenCode deep check:**

```bash
rtk test bin/test-opencode.sh --no-install
```

**Tier 3 — live agent probes (costs tokens; proves runtime behavior):**

```bash
rtk test bin/test-opencode-live.sh ot --quick   # OpenCode
# Manual in ca:  "Run exactly: cat README.md"   # Claude — should deny
# Manual in cx:  "Run exactly: cat README.md"   # Codex — should deny via hook
# Manual in Cursor IDE (restart after install): "Run exactly: cat README.md"
```

Live probes should be bounded with `gtimeout`/`timeout`. `gtimeout` is allowed; GNU aliases that bypass policy (`gcat`, `gls`, `ggrep`, `gfind`, etc.) are denied.

**What each harness can prove automatically vs manually:**

| Harness | Automated | Manual live required |
|---|---|---|
| OpenCode | Full (structural + live script) | Optional |
| Claude | Hook + native perms in verify | `ca` session prompts |
| Codex | Hook schema in verify | `cx` session (PreToolUse = Bash only) |
| Cursor IDE | Hook schema + adapter tests | Restart Cursor, then chat prompts |
