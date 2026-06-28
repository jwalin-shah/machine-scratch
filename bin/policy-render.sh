#!/usr/bin/env bash
# policy-render.sh — render config/tool-policy.json into per-harness native
# permission blocks. Output is a JSON object whose keys are harness names
# ("claude", "opencode", "cursor", "codex") and whose values are JSON
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
#     "codex":    { "hooks_json":  { ... } }    # codex native unverified, hook only
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

# ---------- render_claude ----------
# Claude pattern syntax: Bash(<glob>). The glob matches the whole command line.
# Emit both bare ("rtk") and prefix ("rtk:*") forms for safety across versions.
render_claude() {
  local allow_json deny_json ask_json native_deny_json
  allow_json=$(allow_keys | jq -R . | jq -s 'map("Bash(" + . + ":*)", "Bash(" + . + ")") | unique')
  deny_json=$(deny_keys  | jq -R . | jq -s 'map("Bash(" + . + ":*)", "Bash(" + . + ")") | unique')
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
  deny_json=$(deny_keys  | jq -R . | jq -s 'map("Shell(" + . + " *)", "Shell(" + . + ")") | unique')

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
      echo '{}'
      allow_keys | while IFS= read -r k; do
        printf '{"%s":"allow","%s *":"allow"}\n' "$k" "$k"
      done
      ask_keys | while IFS= read -r k; do
        printf '{"%s":"ask","%s *":"ask"}\n' "$k" "$k"
      done
      deny_keys | while IFS= read -r k; do
        printf '{"%s":"deny","%s *":"deny"}\n' "$k" "$k"
      done
      printf '{"*":"ask"}\n'
    } | jq -s 'add'
  )
  native_block=$(jq '.native_opencode_deny | map({(.): "deny"}) | add // {}' "$POLICY")

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
            { matcher: "Shell|Read|Grep|Glob|List", command: $g, timeout: 5 }
          ]
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
  cursor-hooks) render_cursor_hooks | jq -c '.cursor_hooks_json' ;;
  all)
    jq -n \
      --argjson claude   "$(render_claude)" \
      --argjson cursor   "$(render_cursor)" \
      --argjson opencode "$(render_opencode)" \
      --argjson codex    "$(render_codex)" \
      --argjson cursor_hooks "$(render_cursor_hooks | jq -c '.cursor_hooks_json')" '
      {
        claude:   $claude,
        cursor:   $cursor,
        opencode: $opencode,
        codex:    $codex,
        cursor_hooks_json: $cursor_hooks
      }'
    ;;
  *)
    echo "Usage: policy-render.sh [claude|cursor|cursor-hooks|opencode|codex|all]" >&2
    exit 2
    ;;
esac
