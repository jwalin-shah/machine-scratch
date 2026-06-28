#!/usr/bin/env bash
# test-tool-guard-pipes.sh — edge-case matrix for pipeline pager denies.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/bin/tool-guard.sh"
export TOOL_POLICY_FILE="$ROOT/config/tool-policy.json"
pass=0; fail=0
run() { jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' | "$GUARD"; }
check() {
  local label="$1" cmd="$2" want="$3" needle="$4"
  local out decision reason
  out="$(run "$label" "$cmd")"
  if [ -z "$out" ]; then decision=allow; reason=""; else decision=deny; reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"; fi
  if [ "$decision" = "$want" ] && { [ -z "$needle" ] || [[ "$reason" == *"$needle"* ]]; }; then
    echo "  ok   $label ($decision)"; pass=$((pass+1))
  else
    echo "  FAIL $label (got $decision reason=$reason want=$want needle=$needle)"; fail=$((fail+1))
  fi
}
check "rtk allow + pager" "rtk read README.md | head -5" "deny" "Re-run without the pipe"
check "jq allow + pager" "jq . file.json | head" "deny" "Re-run without the pipe"
check "basic pipe head" "pmset -g | head -30" "deny" "Re-run without the pipe"
check "redirect before pipe" "pmset -g 2>/dev/null | head -30" "deny" "Re-run without the pipe"
check "multi pipe" "cmd1 | cmd2 | head -5" "deny" "Re-run without the pipe"
check "subshell" "(pmset -g | head -5)" "deny" "Re-run without the pipe"
check "secret-cache wrapper" "secret-cache exec -- pmset -g | head -5" "deny" "Re-run without the pipe"
check "absolute head path" "pmset | /usr/bin/head -5" "allow" ""
check "command head" "pmset | command head -5" "allow" ""
check "uppercase HEAD" "pmset | HEAD -5" "allow" ""
check "ghead gnu" "pmset | ghead -5" "allow" ""
check "head in arg not pipe" "grep head README.md" "deny" "is denied by tool-policy"
check "first token head" "head -n 5 README.md" "deny" "rtk read"
check "tail pipe" "pmset -g | tail -20" "deny" "Re-run without the pipe"
check "less pipe" "pmset -g | less" "deny" "Re-run without the pipe"
check "clean ask-tier" "pmset -g" "allow" ""
echo "Passed: $pass Failed: $fail"
[ "$fail" -eq 0 ]
