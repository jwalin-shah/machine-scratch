#!/usr/bin/env bash
# test-cursor-hooks.sh — schema + adapter behavior for Cursor policy enforcement.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER="$ROOT/bin/tool-guard-cursor.sh"
export TOOL_POLICY_FILE="$ROOT/config/tool-policy.json"
export TOOL_GUARD_PATH="$ROOT/bin/tool-guard.sh"

pass=0
fail=0

run_cursor() {
  printf '%s' "$1" | "$ADAPTER"
}

expect_cursor_deny() {
  local label="$1" needle="$2" payload="$3"
  local out perm msg
  out="$(run_cursor "$payload")"
  perm="$(printf '%s' "$out" | jq -r '.permission // ""')"
  msg="$(printf '%s' "$out" | jq -r '.agent_message // ""')"
  if [ "$perm" = "deny" ] && [[ "$msg" == *"$needle"* ]]; then
    echo "  ok   DENY   $label"
    pass=$((pass+1))
  else
    echo "  FAIL DENY   $label  (permission=$perm msg=$msg)"
    fail=$((fail+1))
  fi
}

expect_cursor_allow() {
  local label="$1" payload="$2"
  local out perm
  out="$(run_cursor "$payload")"
  perm="$(printf '%s' "$out" | jq -r '.permission // ""')"
  if [ "$perm" = "allow" ]; then
    echo "  ok   ALLOW  $label"
    pass=$((pass+1))
  else
    echo "  FAIL ALLOW  $label  (got: $out)"
    fail=$((fail+1))
  fi
}

echo "== Cursor hooks schema =="
RENDERED="$ROOT/.cursor-hooks-rendered.json"
"$ROOT/bin/policy-render.sh" cursor-hooks > "$RENDERED"
for key in beforeShellExecution beforeReadFile preToolUse; do
  if jq -e ".hooks.$key | length > 0" "$RENDERED" >/dev/null; then
    echo "  ok   hooks.$key present"
    pass=$((pass+1))
  else
    echo "  FAIL hooks.$key missing"
    fail=$((fail+1))
  fi
done
rm -f "$RENDERED"

echo "== Cursor adapter: beforeShellExecution =="
expect_cursor_deny "cat via command field" "rtk read" '{"command":"cat README.md"}'
expect_cursor_allow "rtk read" '{"command":"rtk read README.md"}'

echo "== Cursor adapter: beforeReadFile =="
expect_cursor_deny "native read path" "Native Read tool is disabled" '{"file_path":"/tmp/foo.txt"}'

echo "== Cursor adapter: preToolUse Shell =="
expect_cursor_deny "Shell cat" "rtk read" '{"tool_name":"Shell","tool_input":{"command":"cat foo"}}'
expect_cursor_allow "Shell rtk" '{"tool_name":"Shell","tool_input":{"command":"rtk ls ."}}'

echo "== Cursor adapter: preToolUse Write =="
expect_cursor_deny "preToolUse Write" "native_write_deny" '{"tool_name":"Write","tool_input":{"path":"x"}}'

echo "== Cursor adapter: preToolUse Shell python3 =="
expect_cursor_deny "Shell python3" "fastedit edit" '{"tool_name":"Shell","tool_input":{"command":"python3 -c \"print(1)\""}}'

echo
echo "Passed: $pass   Failed: $fail"
[ "$fail" -eq 0 ]
