---
name: tool-policy
description: >-
  Understand and modify this machine's cross-harness tool policy (rtk redirects,
  bash allow/deny, native Read blocking). Use when editing tool-policy.json,
  debugging hook failures, verifying policy across Claude/OpenCode/Cursor/Codex,
  or asking how tool-guard works. For vendor harness schema details, use ctx7
  (find-docs skill) — do not guess hook JSON shapes.
---

# Tool Policy (machine-scratch)

## Read order

1. **House policy** (what THIS machine enforces): `docs/TOOL_POLICY.md`
2. **Live JSON**: `config/tool-policy.json`
3. **Vendor schema** (how each harness expresses hooks/perms): ctx7 — see below

## Vendor docs via Context7

Do **not** duplicate upstream hook schemas in commits. Query live:

```bash
ctx7 docs /websites/developers_openai_codex "<hooks question>"
ctx7 docs /websites/cursor "<hooks or permissions question>"
ctx7 docs /anomalyco/opencode "<permission question>"
ctx7 docs /websites/code_claude "<PreToolUse question>"
```

Index of library IDs: `docs/vendor/agent-harnesses/llms.txt`

## Common tasks

### Verify policy after edits

```bash
bin/install-active-config.sh
rtk test bin/test-all-policy.sh
```

Restart Cursor IDE after hook changes.

### Debug a deny that should allow (or vice versa)

```bash
rtk test bin/test-tool-guard.sh
echo '{"tool_name":"Bash","tool_input":{"command":"cat foo"}}' | bin/tool-guard.sh
echo '{"command":"cat foo"}' | bin/tool-guard-cursor.sh
```

### Add a new allowed bash command

1. Add to `config/tool-policy.json` → `bash_allow`
2. `bin/install-active-config.sh`
3. `rtk test bin/test-all-policy.sh`

Never hand-edit `~/.claude/settings.json` permission arrays or `~/.cursor/cli-config.json`.

## Harness-specific notes

| Harness | Config path | Hook script |
|---|---|---|
| Claude | `~/.claude/settings.json` | `~/bin/tool-guard.sh` |
| Codex | `~/.codex/hooks.json` | `~/bin/tool-guard.sh` |
| Cursor | `~/.cursor/hooks.json` + `cli-config.json` | `~/bin/tool-guard-cursor.sh` |
| OpenCode | `~/.config/opencode/opencode.json` + plugin | `plugins/tool-guard/index.js` |

Codex: PreToolUse matches Bash only (upstream limitation).
Cursor: restart IDE after install; uses v1 hooks schema.
