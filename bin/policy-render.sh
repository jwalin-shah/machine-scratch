#!/usr/bin/env bash
# policy-render.sh — render config/tool-policy.json into per-harness native
# permission blocks. Output is a JSON object whose keys are harness names
# ("claude", "opencode", "cursor", "codex", "antigravity") and whose values are JSON
# fragments the installer merges into each live config file.
#
# Architecture: this is the SOLE place that knows how each harness expresses
# allow/deny/ask. Adding a new harness = adding a new render_<name> function
# and a new key in the final aggregation. Editing tool-policy.json never
# requires touching this file.
#
# Usage:
#   policy-render.sh                    # render all, print aggregated JSON
#   policy-render.sh claude             # render single harness fragment
#   POLICY=/path/to/tool-policy.json policy-render.sh
#
# Output schema:
#   {
#     "claude":   { "permissions": { "allow": [...], "deny": [...], "ask": [...] } },
#     "opencode": { "permission":  { "bash": {...}, "read": "deny", ... } },
#     "cursor":   { "permissions": { "allow": [...], "deny": [...] } },
#     "codex":        { "hooks_json":  { ... } }    # codex native unverified, hook only
#     "antigravity":  { "antigravity_hooks_json": {...}, "antigravity_settings_json": {...} }
#   }

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="${POLICY:-$ROOT/config/tool-policy.json}"

if [ ! -f "$POLICY" ]; then
  echo "policy-render: $POLICY not found" >&2
  exit 1
fi

# ---------- shared jq fragments ----------
# "*" in bash_allow is a sentinel, not an executable — strip it.
allow_keys() { jq -r '.bash_allow | keys[] | select(. != "*")' "$POLICY"; }
deny_keys()  { jq -r '[.bash_deny[][]] | .[]' "$POLICY"; }
# captain_confirm patterns are most-specific so they come first.
ask_keys()   {
  jq -r '(.bash_ask.captain_confirm // []) + (.bash_ask.package_managers // []) | .[]' "$POLICY"
}
# deny_keys_filtered — same as deny_keys but excludes keys that are a
# word-prefix of any allow or ask key (e.g. "du" → "du -s", "git" → "git push").
# Prevents native permission systems from applying a broad deny (e.g. Bash(du:*))
# that overrides a more specific allow/ask (Bash(du -s:*)).
deny_keys_filtered() {
  local allow_ask
  allow_ask="$(allow_keys; ask_keys)"
  deny_keys | while IFS= read -r k; do
    skip=0
    while IFS= read -r a; do
      case "$a" in "$k "*) skip=1; break ;; esac
    done <<< "$allow_ask"
    [ "$skip" -eq 0 ] && printf '%s\n' "$k"
  done
}

# ---------- render_claude ----------
# Claude pattern syntax: Bash(<glob>). The glob matches the whole command line.
# Emit both bare ("rtk") and prefix ("rtk:*") forms for safety across versions.
render_claude() {
  local allow_json deny_json ask_json native_deny_json
  allow_json=$(allow_keys | jq -R . | jq -s 'map("Bash(" + . + ":*)", "Bash(" + . + ")") | unique')
  deny_json=$(deny_keys_filtered | jq -R . | jq -s 'map("Bash(" + . + ":*)", "Bash(" + . + ")") | unique')
  ask_json=$(ask_keys    | jq -R . | jq -s 'map("Bash(" + . + ":*)", "Bash(" + . + ")") | unique')
  # native_opencode_deny -> Claude: Read/Grep/Glob (not List — Claude has no List tool)
  native_deny_json=$(jq '.native_opencode_deny | map(select(. != "list")) | map(. | ascii_upcase[0:1] + .[1:])' "$POLICY")

  jq -n \
    --argjson allow "$allow_json" \
    --argjson deny  "$deny_json" \
    --argjson ask   "$ask_json" \
    --argjson natdeny "$native_deny_json" '
    {
      permissions: {
        allow: $allow,
        deny:  ($natdeny + $deny),
        ask:   $ask
      }
    }'
}

# ---------- render_cursor ----------
# Cursor pattern syntax: Shell(<glob>). approvalMode "allowlist" = ask for
# anything not explicitly allowed.
render_cursor() {
  local allow_json deny_json
  allow_json=$(allow_keys | jq -R . | jq -s 'map("Shell(" + . + " *)", "Shell(" + . + ")") | unique')
  deny_json=$(deny_keys_filtered | jq -R . | jq -s 'map("Shell(" + . + " *)", "Shell(" + . + ")") | unique')

  jq -n \
    --argjson allow "$allow_json" \
    --argjson deny  "$deny_json" '
    {
      permissions: { allow: $allow, deny: $deny },
      approvalMode: "allowlist"
    }'
}

# ---------- render_opencode ----------
# OpenCode bash pattern: {"<cmd>": "allow"|"deny"|"ask"} with glob support.
# native_opencode_deny maps to top-level read/grep/glob/list keys.
render_opencode() {
  local bash_map_json native_block
  bash_map_json=$(
    {
      # "*" first so explicit allow/deny patterns override it (last match wins)
      printf '{"*":"ask"}\n'
      allow_keys | while IFS= read -r k; do
        printf '{"%s":"allow","%s *":"allow"}\n' "$k" "$k"
      done
      # Pipe-deny patterns: override allow-tier tools like rtk/jq that would
      # otherwise pipe to head/tail/less/more without reaching the plugin.
      printf '{"* | head":"deny","* | head *":"deny","* | tail":"deny","* | tail *":"deny","* | less":"deny","* | more":"deny"}\n'
      ask_keys | while IFS= read -r k; do
        printf '{"%s":"ask","%s *":"ask"}\n' "$k" "$k"
      done
      deny_keys_filtered | while IFS= read -r k; do
        printf '{"%s":"deny","%s *":"deny"}\n' "$k" "$k"
      done
    } | jq -s 'add'
  )
  native_block=$(jq '
    (.native_opencode_deny | map({(.): "deny"}) | add // {}) +
    (if (.native_write_deny | index("edit")) then {"edit": "deny"} else {} end)
  ' "$POLICY")

  jq -n \
    --argjson bash "$bash_map_json" \
    --argjson native "$native_block" '
    {
      permission: ($native + {bash: $bash, webfetch: "ask", websearch: "ask"})
    }'
}


# ---------- render_cursor_hooks ----------
# Cursor v1 hooks.json — see create-hook skill. Uses tool-guard-cursor.sh adapter.
render_cursor_hooks() {
  local guard="${TOOL_GUARD_CURSOR_PATH:-$HOME/bin/tool-guard-cursor.sh}"
  jq -n --arg g "$guard" '
    {
      cursor_hooks_json: {
        version: 1,
        hooks: {
          beforeShellExecution: [
            { command: $g, timeout: 5 }
          ],
          beforeReadFile: [
            { matcher: "Read", command: $g, timeout: 5 }
          ],
          preToolUse: [
            { matcher: "Shell|Read|Grep|Glob|List|Write|StrReplace|Delete", command: $g, timeout: 5 }
          ]
        }
      }
    }'
}


# ---------- render_antigravity ----------
# Antigravity (agy) ~/.gemini/config/hooks.json — named top-level blocks.
# PreToolUse stdin: { toolCall: { name, args }, ... }
# stdout: {"decision":"allow"} | {"decision":"deny","reason":"..."}
render_antigravity() {
  local guard="${TOOL_GUARD_ANTIGRAVITY_PATH:-$HOME/bin/tool-guard-antigravity.sh}"
  local allow_json deny_json ask_json
  allow_json=$(allow_keys | jq -R . | jq -s 'map("command(" + . + ")")')
  deny_json=$(deny_keys_filtered | jq -R . | jq -s 'map("command(" + . + ")")')
  ask_json=$(ask_keys    | jq -R . | jq -s 'map("command(" + . + ")")')
  jq -n     --arg g "$guard"     --argjson allow "$allow_json"     --argjson deny "$deny_json"     --argjson ask "$ask_json" '
    {
      antigravity_hooks_json: {
        "tool-guard": {
          enabled: true,
          PreToolUse: [
            {
              matcher: ".*",
              hooks: [
                {
                  type: "command",
                  command: $g,
                  timeout: 5
                }
              ]
            }
          ]
        }
      },
      antigravity_settings_json: {
        toolPermission: "request-review",
        permissions: {
          allow: $allow,
          deny:  $deny,
          ask:   $ask
        }
      }
    }'
}

# ---------- render_codex ----------
# Codex hooks.json schema (v0.114+): top-level "hooks" object with PascalCase
# event keys. See https://developers.openai.com/codex/hooks
# Native config.toml perms unverified — hook-only for now.
render_codex() {
  local guard="${TOOL_GUARD_PATH:-$HOME/bin/tool-guard.sh}"
  jq -n --arg guard "$guard" '
    {
      hooks_json: {
        hooks: {
          PreToolUse: [
            {
              matcher: "Bash|Read|Grep|Glob",
              hooks: [
                {
                  type: "command",
                  command: $guard,
                  timeout: 5,
                  statusMessage: "Checking tool choice..."
                }
              ]
            }
          ]
        }
      }
    }'
}

# ---------- main ----------
case "${1:-all}" in
  claude)   render_claude ;;
  cursor)   render_cursor ;;
  cursor-hooks) render_cursor_hooks | jq -c '.cursor_hooks_json' ;;
  opencode) render_opencode ;;
  codex)    render_codex ;;
  antigravity) render_antigravity ;;
  cursor-hooks) render_cursor_hooks | jq -c '.cursor_hooks_json' ;;
  all)
    jq -n \
      --argjson claude   "$(render_claude)" \
      --argjson cursor   "$(render_cursor)" \
      --argjson opencode "$(render_opencode)" \
      --argjson codex    "$(render_codex)" \
      --argjson cursor_hooks "$(render_cursor_hooks | jq -c '.cursor_hooks_json')" \
      --argjson antigravity "$(render_antigravity)" '
      {
        claude:   $claude,
        cursor:   $cursor,
        opencode: $opencode,
        codex:    $codex,
        cursor_hooks_json: $cursor_hooks,
        antigravity_hooks_json: $antigravity.antigravity_hooks_json,
        antigravity_settings_json: $antigravity.antigravity_settings_json
      }'
    ;;
  *)
    echo "Usage: policy-render.sh [claude|cursor|cursor-hooks|opencode|codex|antigravity|all]" >&2
    exit 2
    ;;
esac
