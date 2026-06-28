# Tool Policy Architecture

This machine enforces a single tool policy across Claude, OpenCode, Cursor, and Codex.
**House-specific behavior lives here.** Vendor harness schema docs are fetched live via
Context7 (`ctx7`) — do not duplicate upstream hook/permission reference material in this repo.

## Source of truth

| Layer | Path | What it controls |
|---|---|---|
| Policy JSON | `config/tool-policy.json` | allow / deny / ask lists, native tool denies, redirects |
| Renderer | `bin/policy-render.sh` | Translates policy → per-harness permission/hook fragments |
| Installer | `bin/install-active-config.sh` | Merges fragments into live harness configs |
| Hook (core) | `bin/tool-guard.sh` | Claude/Codex PreToolUse — bash + native Read/Grep/Glob/List |
| Hook (Cursor) | `bin/tool-guard-cursor.sh` | Cursor v1 hooks — maps Cursor I/O ↔ core policy |
| OpenCode plugin | `config/opencode/plugins/tool-guard/index.js` | Second layer for bash redirects |
| Agent instructions | `agent-rules/GLOBAL.md`, `TOOL_REGISTRY.md` | Behavioral contract |

## What ctx7 covers vs what we maintain

**Pull via ctx7 at query time** (vendor schema, hook I/O, permission syntax):

```bash
ctx7 docs /websites/developers_openai_codex "hooks.json PreToolUse schema"
ctx7 docs /websites/cursor "hooks beforeShellExecution beforeReadFile"
ctx7 docs /websites/cursor "cli-config permissions allowlist Shell"
ctx7 docs /anomalyco/opencode "permission bash deny read grep"
ctx7 docs /websites/code_claude "PreToolUse hooks settings.json permissions"
```

See `docs/vendor/agent-harnesses/llms.txt` for library IDs and common queries.

**Maintain in machine-scratch** (house-specific, not in any vendor doc):

- Which commands are allowed/denied (`tool-policy.json`)
- Cross-harness install wiring (`install-active-config.sh`)
- Cursor adapter (`tool-guard-cursor.sh`) — our translation layer
- Test matrix (`test-all-policy.sh`, `verify-active-config.sh`)
- Launcher routes (`oo`, `ot`, `ca`, `cx`, …)
- Known harness limits (Codex PreToolUse = Bash only; Cursor needs IDE restart)

## Per-harness enforcement

| Harness | Native permissions | Hook / plugin | Native Read blocked? |
|---|---|---|---|
| OpenCode | `permission.bash`, `permission.read` deny | tool-guard plugin | Yes |
| Claude | `permissions.deny` incl. Read | `tool-guard.sh` PreToolUse | Yes |
| Codex | none (hook-only) | `hooks.PreToolUse` → tool-guard | Bash only* |
| Cursor IDE | `cli-config.json` Shell allowlist | v1 hooks → tool-guard-cursor | Yes (via beforeReadFile) |

*Codex PreToolUse currently fires for Bash (and apply_patch/MCP per upstream). Native read
tools are not hookable in Codex yet — agents must use `rtk read` via bash.

## Install and verify

```bash
bin/install-active-config.sh          # push policy to all harnesses
rtk test bin/test-all-policy.sh       # Tier 1: all automated checks
rtk test bin/test-opencode.sh --no-install   # Tier 2: OpenCode deep
rtk test bin/test-opencode-live.sh ot --quick  # Tier 3: live tokens
```

After install: **restart Cursor IDE** so `~/.cursor/hooks.json` reloads.

Full done/not-done matrix: **`docs/COMPLETION_CHECKLIST.md`**.

### Tier 1 breakdown

| Script | Proves |
|---|---|
| `test-tool-guard.sh` | Hook logic (47+ cases): bash deny/allow, Shell alias, native Read deny |
| `test-codex-hooks.sh` | Codex `hooks.json` schema matches rendered policy |
| `test-cursor-hooks.sh` | Cursor v1 hooks schema + adapter I/O |
| `verify-active-config.sh` | Live configs match repo (drift check, all harnesses) |

### Tier 3 manual prompts (copy-paste)

Run in each harness after Tier 1 passes:

```
Run exactly this bash command and show me the output: cat README.md
```

Expected: deny + suggest `rtk read`. Then:

```
Run exactly this bash command: rtk read README.md
```

Expected: allow + return content.

## Editing policy

1. Edit `config/tool-policy.json`
2. Run `bin/install-active-config.sh`
3. Run `rtk test bin/test-all-policy.sh`
4. Restart Cursor if Cursor hooks changed
5. Optional live probe in target harness

Do **not** hand-edit live permission blocks in `~/.claude/settings.json`,
`~/.cursor/cli-config.json`, etc. — they are generated and will drift.

## Context7 quick reference

Full index: `docs/vendor/agent-harnesses/llms.txt`. Agents with the `find-docs`
skill can also use Context7 for any library/framework question.

| Topic | ctx7 library ID | Example query |
|---|---|---|
| Codex hooks | `/websites/developers_openai_codex` | `PreToolUse deny permissionDecision` |
| Cursor hooks | `/websites/cursor` | `beforeShellExecution output permission deny` |
| Cursor CLI perms | `/websites/cursor` | `cli-config permissions Shell allowlist` |
| OpenCode perms | `/anomalyco/opencode` | `permission bash object syntax deny` |
| Claude Code hooks | `/websites/code_claude` | `PreToolUse hooks settings.json` |
