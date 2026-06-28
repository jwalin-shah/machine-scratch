#!/usr/bin/env bash
# tool-guard-cursor.sh — Cursor hook adapter (v1 hooks.json events).
#
# Cursor uses different stdin shapes and stdout than Claude/Codex:
#   beforeShellExecution  → { command: "..." }
#   beforeReadFile        → { file_path: "..." } (and variants)
#   preToolUse            → { tool_name, tool_input, ... }
#
# This script normalizes to tool-guard.sh (Claude PreToolUse shape) and maps
# deny responses to Cursor's { permission, agent_message, user_message } format.

set -euo pipefail

GUARD="${TOOL_GUARD_PATH:-$HOME/bin/tool-guard.sh}"
INPUT="$(cat)"

emit_cursor_allow() {
  jq -n '{permission: "allow"}'
  exit 0
}

emit_cursor_deny() {
  local reason="$1"
  jq -n --arg msg "$reason" '{
    permission: "deny",
    agent_message: $msg,
    user_message: $msg
  }'
  exit 0
}

PAYLOAD=""

if printf '%s' "$INPUT" | jq -e 'has("command") and (.command | type) == "string"' >/dev/null 2>&1; then
  cmd="$(printf '%s' "$INPUT" | jq -r '.command')"
  PAYLOAD="$(jq -n --arg c "$cmd" '{tool_name: "Shell", tool_input: {command: $c}}')"
elif printf '%s' "$INPUT" | jq -e '.tool_name // .tool // empty' | grep -qv '^$'; then
  tool="$(printf '%s' "$INPUT" | jq -r '.tool_name // .tool // ""')"
  case "$tool" in
    Shell|Bash)
      cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // ""')"
      PAYLOAD="$(jq -n --arg c "$cmd" '{tool_name: "Shell", tool_input: {command: $c}}')"
      ;;
    Read|Grep|Glob|List|Write|StrReplace|Delete|Edit)
      PAYLOAD="$(printf '%s' "$INPUT" | jq '{tool_name: (.tool_name // .tool), tool_input: (.tool_input // {})}')"
      ;;
    *)
      emit_cursor_allow
      ;;
  esac
elif printf '%s' "$INPUT" | jq -e '.file_path // .path // .file // empty' | grep -qv '^$'; then
  fp="$(printf '%s' "$INPUT" | jq -r '.file_path // .path // .file // ""')"
  PAYLOAD="$(jq -n --arg f "$fp" '{tool_name: "Read", tool_input: {file_path: $f}}')"
else
  emit_cursor_allow
fi

[ -z "$PAYLOAD" ] && emit_cursor_allow

OUT="$(printf '%s' "$PAYLOAD" | "$GUARD")"
if [ -z "$OUT" ]; then
  emit_cursor_allow
fi

REASON="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // "denied by tool-policy.json"')"
emit_cursor_deny "$REASON"
