#!/usr/bin/env bash
# test-tool-guard.sh — smoke test for bin/tool-guard.sh against tool-policy.json.
# Asserts allow (empty stdout) or deny (permissionDecision: deny + reason substring).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/bin/tool-guard.sh"
export TOOL_POLICY_FILE="$ROOT/config/tool-policy.json"

pass=0
fail=0

# run TOOL CMD -> echoes stdout
run() {
  local tool="$1" cmd="$2" file_path="${3:-}"
  jq -n --arg t "$tool" --arg c "$cmd" --arg f "$file_path" '{
    hook_event_name: "PreToolUse",
    tool_name: $t,
    tool_input: (if $t == "Bash" or $t == "Shell" then {command: $c}
                 elif $t == "Read" then {file_path: $f}
                 elif $t == "List" then {path: $c}
                 else {pattern: $c} end)
  }' | "$GUARD"
}

expect_allow() {
  local label="$1"; shift
  local out
  out="$(run "$@")"
  if [ -z "$out" ]; then
    echo "  ok   ALLOW  $label"
    pass=$((pass+1))
  else
    echo "  FAIL ALLOW  $label  (expected empty stdout, got: $out)"
    fail=$((fail+1))
  fi
}

expect_deny() {
  local label="$1" needle="$2"; shift 2
  local out decision reason
  out="$(run "$@")"
  decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // ""' 2>/dev/null)"
  reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null)"
  if [ "$decision" = "deny" ] && [[ "$reason" == *"$needle"* ]]; then
    echo "  ok   DENY   $label   ($reason)"
    pass=$((pass+1))
  else
    echo "  FAIL DENY   $label   (decision='$decision', reason='$reason', expected substring: '$needle')"
    fail=$((fail+1))
  fi
}

echo "== Bash allow tier =="
expect_allow "rtk read"                      Bash "rtk read foo.md"
expect_allow "rtk grep"                      Bash "rtk grep pattern src/"
expect_allow "du -s"                         Bash "du -s /tmp"
expect_allow "du -sh path"                   Bash "du -sh /tmp"
expect_allow "jq"                            Bash "jq '.foo' file.json"
expect_allow "uv pip install"                Bash "uv pip install ruff"
expect_allow "secret-cache exec passthrough" Bash "secret-cache exec -- rtk grep foo src/"
expect_allow "gtimeout bounded test"          Bash "gtimeout 120 rtk test bin/test-opencode-live.sh ot --quick"
expect_allow "timeout bounded test"           Bash "timeout 120 rtk test bin/test-opencode-live.sh ot --quick"

echo "== Bash deny tier =="
expect_deny "cat"  "rtk read"            Bash "cat foo.md"
expect_deny "ls"   "rtk ls"              Bash "ls /tmp"
expect_deny "grep" "rtk grep"            Bash "grep -r foo ."
expect_deny "find" "rtk find"            Bash "find . -name '*.md'"
expect_deny "rg"   "rtk grep"            Bash "rg pattern"
expect_deny "bat"  "rtk read"            Bash "bat foo.md"
expect_deny "fd"   "rtk find"            Bash "fd pattern"
expect_deny "eza"  "rtk ls (default)"  Bash "eza -la"
expect_deny "dust" "du -s"               Bash "dust /tmp"
expect_deny "git"  "rtk git"             Bash "git status"
expect_deny "gh"   "rtk gh"              Bash "gh pr list"
expect_deny "du (bare)" "du -s or du -sh only"  Bash "du -h /tmp"
expect_deny "rm"   "denied"              Bash "rm -rf /tmp/foo"
expect_deny "sudo" "denied"              Bash "sudo systemctl restart foo"
expect_deny "security" "denied"          Bash "security find-generic-password -s x"
expect_deny "export" "denied"            Bash "export FOO=bar"
expect_deny "gcat"  "rtk read"           Bash "gcat README.md"
expect_deny "gls"   "rtk ls"             Bash "gls -la"
expect_deny "ggrep" "rtk grep"           Bash "ggrep -r foo ."
expect_deny "gfind" "rtk find"           Bash "gfind . -name '*.md'"
expect_deny "gdu"   "du -s"              Bash "gdu -h ."
expect_deny "head" "rtk read"            Bash "head -n 5 README.md"
expect_deny "tail" "rtk read"            Bash "tail -n 5 README.md"
expect_deny "less" "rtk read"            Bash "less README.md"
expect_deny "more" "rtk read"            Bash "more README.md"
expect_deny "rtk head" "not a valid rtk" Bash "rtk head README.md"
expect_deny "rtk tail" "not a valid rtk" Bash "rtk tail README.md"
expect_deny "rtk cat"  "not a valid rtk" Bash "rtk cat README.md"

echo "== Bash ask tier (captain confirm) =="
expect_deny "git push"  "captain's confirmation"  Bash "git push origin main"
expect_deny "git clean" "captain's confirmation"  Bash "git clean -fd"
expect_deny "git reset" "captain's confirmation"  Bash "git reset --hard"
expect_deny "launchctl" "captain's confirmation"  Bash "launchctl bootstrap gui/501 foo"
expect_deny "brew uninstall" "captain's confirmation"  Bash "brew uninstall jq"

echo "== Bash ask tier (package managers) =="
expect_deny "brew"  "ask tier" Bash "brew install jq"
expect_deny "npm"   "ask tier" Bash "npm install"
expect_deny "pnpm"  "ask tier" Bash "pnpm add foo"

echo "== Bash unknown (default allow) =="
expect_allow "echo"  Bash "echo hello"
expect_allow "mkdir" Bash "mkdir -p /tmp/foo"


echo "== Shell alias (Cursor harness) =="
expect_deny "Shell cat"  "rtk read"            Shell "cat foo.md"
expect_deny "Shell rg"   "rtk grep"            Shell "rg pattern"
expect_allow "Shell rtk" Shell "rtk read foo.md"

echo "== Native tool deny tier =="
expect_deny "Read"  "Native Read tool is disabled"  Read  "/tmp/foo" "/tmp/foo"
expect_deny "Grep"  "Native Grep tool is disabled"  Grep  "pattern"
expect_deny "Glob"  "Native Glob tool is disabled"  Glob  "**/*.md"
expect_deny "List"  "Native List tool is disabled"  List  "."

echo
echo "Passed: $pass   Failed: $fail"
[ "$fail" -eq 0 ]
