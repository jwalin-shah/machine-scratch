#!/usr/bin/env bash
# tool-guard-antigravity.sh — Antigravity (agy) PreToolUse hook adapter.
#
# Antigravity stdin (named hook blocks in ~/.gemini/config/hooks.json):
#   { toolCall: { name, args }, conversationId, ... }
#
# stdout MUST be {"decision":"allow"} or {"decision":"deny","reason":"..."}
# (empty stdout = deny all upstream — never emit empty).

set -euo pipefail

GUARD="${TOOL_GUARD_PATH:-$HOME/bin/tool-guard.sh}"
INPUT="$(cat)"

emit_agy_allow() {
  jq -n '{decision: "allow"}'
  exit 0
}

emit_agy_deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{decision: "deny", reason: $reason}'
  exit 0
}

if ! printf '%s' "$INPUT" | jq -e 'has("toolCall")' >/dev/null 2>&1; then
  emit_agy_allow
fi

RAW_NAME="$(printf '%s' "$INPUT" | jq -r '.toolCall.name // ""')"
NAME="$(printf '%s' "$RAW_NAME" | tr '[:upper:]' '[:lower:]')"
ARGS="$(printf '%s' "$INPUT" | jq -c '.toolCall.args // {}')"

PAYLOAD=""

case "$NAME" in
  run_command)
    cmd="$(printf '%s' "$ARGS" | jq -r '.CommandLine // .commandLine // .command // ""')"
    PAYLOAD="$(jq -n --arg c "$cmd" '{tool_name: "Shell", tool_input: {command: $c}}')"
    ;;
  list_dir|listdir)
    PAYLOAD="$(jq -n '{tool_name: "List", tool_input: {}}')"
    ;;
  find_by_name|findbyname)
    PAYLOAD="$(jq -n '{tool_name: "Glob", tool_input: {}}')"
    ;;
  read_file|view_file|readfile|viewfile)
    fp="$(printf '%s' "$ARGS" | jq -r '.file_path // .path // .filepath // .FilePath // .file // ""')"
    PAYLOAD="$(jq -n --arg f "$fp" '{tool_name: "Read", tool_input: {file_path: $f}}')"
    ;;
  *)
    emit_agy_allow
    ;;
esac

[ -z "$PAYLOAD" ] && emit_agy_allow

OUT="$(printf '%s' "$PAYLOAD" | "$GUARD")"
if [ -z "$OUT" ]; then
  emit_agy_allow
fi

REASON="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // "denied by tool-policy.json"')"
emit_agy_deny "$REASON"
