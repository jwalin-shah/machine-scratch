#!/usr/bin/env bash
# test-antigravity-hooks.sh — schema + adapter behavior for Antigravity (agy) hooks.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER="$ROOT/bin/tool-guard-antigravity.sh"
export TOOL_POLICY_FILE="$ROOT/config/tool-policy.json"
export TOOL_GUARD_PATH="$ROOT/bin/tool-guard.sh"

pass=0
fail=0

run_agy() {
  printf '%s' "$1" | "$ADAPTER"
}

expect_agy_deny() {
  local label="$1" needle="$2" payload="$3"
  local out decision reason
  out="$(run_agy "$payload")"
  decision="$(printf '%s' "$out" | jq -r '.decision // ""')"
  reason="$(printf '%s' "$out" | jq -r '.reason // ""')"
  if [ "$decision" = "deny" ] && [[ "$reason" == *"$needle"* ]]; then
    echo "  ok   DENY   $label"
    pass=$((pass+1))
  else
    echo "  FAIL DENY   $label  (decision=$decision reason=$reason)"
    fail=$((fail+1))
  fi
}

expect_agy_allow() {
  local label="$1" payload="$2"
  local out decision
  out="$(run_agy "$payload")"
  decision="$(printf '%s' "$out" | jq -r '.decision // ""')"
  if [ "$decision" = "allow" ]; then
    echo "  ok   ALLOW  $label"
    pass=$((pass+1))
  else
    echo "  FAIL ALLOW  $label  (got: $out)"
    fail=$((fail+1))
  fi
}

echo "== Antigravity hooks schema =="
RENDERED="$(mktemp)"
"$ROOT/bin/policy-render.sh" antigravity | jq -c '.antigravity_hooks_json' > "$RENDERED"
if jq -e '."tool-guard".enabled == true' "$RENDERED" >/dev/null; then
  echo "  ok   tool-guard.enabled"
  pass=$((pass+1))
else
  echo "  FAIL tool-guard.enabled"
  fail=$((fail+1))
fi
if jq -e '."tool-guard".PreToolUse[0].matcher == ".*"' "$RENDERED" >/dev/null; then
  echo "  ok   PreToolUse matcher"
  pass=$((pass+1))
else
  echo "  FAIL PreToolUse matcher"
  fail=$((fail+1))
fi
if jq -e '."tool-guard".PreToolUse[0].hooks[0].command | test("tool-guard-antigravity")' "$RENDERED" >/dev/null; then
  echo "  ok   hook command path"
  pass=$((pass+1))
else
  echo "  FAIL hook command path"
  fail=$((fail+1))
fi
RENDERED_SETTINGS="$(mktemp)"
"$ROOT/bin/policy-render.sh" antigravity | jq -c '.antigravity_settings_json' > "$RENDERED_SETTINGS"
if jq -e '.toolPermission == "request-review"' "$RENDERED_SETTINGS" >/dev/null; then
  echo "  ok   toolPermission request-review"
  pass=$((pass+1))
else
  echo "  FAIL toolPermission"
  fail=$((fail+1))
fi
if jq -e '.permissions.allow | index("command(rtk)")' "$RENDERED_SETTINGS" >/dev/null; then
  echo "  ok   permissions.allow command(rtk)"
  pass=$((pass+1))
else
  echo "  FAIL permissions.allow command(rtk)"
  fail=$((fail+1))
fi
if jq -e '.permissions.deny | index("command(rm)")' "$RENDERED_SETTINGS" >/dev/null; then
  echo "  ok   permissions.deny command(rm)"
  pass=$((pass+1))
else
  echo "  FAIL permissions.deny command(rm)"
  fail=$((fail+1))
fi
rm -f "$RENDERED_SETTINGS"

echo "== Antigravity adapter: native tools =="
expect_agy_deny "list_dir" "rtk ls" '{"toolCall":{"name":"list_dir","args":{"path":"."}},"conversationId":"test"}'

echo "== Antigravity adapter: run_command =="
expect_agy_deny "cat via CommandLine" "rtk read" '{"toolCall":{"name":"run_command","args":{"CommandLine":"cat README.md"}},"conversationId":"test"}'
expect_agy_allow "rtk read" '{"toolCall":{"name":"run_command","args":{"CommandLine":"rtk read README.md"}},"conversationId":"test"}'

echo
echo "Passed: $pass   Failed: $fail"
[ "$fail" -eq 0 ]
