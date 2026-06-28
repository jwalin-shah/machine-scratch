#!/usr/bin/env bash
# test-opencode-permissions.sh — permission enforcement without an OpenCode TUI session.
# Tests config denies, build-agent inheritance, OpenCode plugin, Claude/Codex hook, and approved tools.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PASS=0

ok() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

section "OpenCode config denies"
RESOLVED="$(opencode debug config 2>/dev/null)" || { bad "opencode debug config failed"; RESOLVED=""; }

for cmd in cat ls grep find rg eza fd bat dust du git gh rm sudo security export gcat gls ggrep gfind gdu gsed gawk; do
  action="$(echo "$RESOLVED" | jq -r ".permission.bash[\"$cmd\"] // \"missing\"")"
  if [ "$action" = "deny" ]; then
    ok "permission.bash.$cmd = deny"
  else
    bad "permission.bash.$cmd expected deny, got $action"
  fi
done

for allowed in "rtk *" "fastedit *" "llm-tldr *" "gtimeout *" "timeout *"; do
  if echo "$RESOLVED" | jq -e --arg a "$allowed" '.permission.bash[$a] == "allow"' >/dev/null 2>&1; then
    ok "permission.bash.$allowed = allow"
  else
    bad "permission.bash.$allowed expected allow"
  fi
done

if echo "$RESOLVED" | jq -e '.permission.bash["*"] == "ask"' >/dev/null 2>&1; then
  ok "permission.bash.* = ask"
else
  bad "permission.bash.* expected ask"
fi

for tool in read grep glob list; do
  action="$(echo "$RESOLVED" | jq -r ".permission[\"$tool\"] // \"missing\"")"
  if [ "$action" = "deny" ]; then
    ok "permission.$tool = deny (native tool blocked)"
  else
    bad "permission.$tool expected deny, got $action"
  fi
done

section "Build agent inherits global denies"
AGENT="$(opencode debug agent build 2>/dev/null)" || { bad "opencode debug agent build failed"; AGENT=""; }

for cmd in cat rg git gh; do
  if echo "$AGENT" | jq -e --arg c "$cmd" '.permission[] | select(.permission=="bash" and .pattern==$c and .action=="deny")' >/dev/null 2>&1; then
    ok "build agent denies bash $cmd"
  else
    bad "build agent missing bash $cmd deny"
  fi
done

if echo "$AGENT" | jq -e '.permission[] | select(.permission=="bash" and .pattern=="rtk *" and .action=="allow")' >/dev/null 2>&1; then
  ok "build agent allows rtk *"
else
  bad "build agent missing rtk * allow"
fi

for tool in read grep glob list; do
  if echo "$AGENT" | jq -e --arg t "$tool" '.permission[] | select(.permission==$t and .action=="deny")' >/dev/null 2>&1; then
    ok "build agent denies native $tool"
  else
    bad "build agent missing native $tool deny"
  fi
done

section "OpenCode tool-guard plugin"
PLUGIN_LIVE="$HOME/.config/opencode/plugins/tool-guard/index.js"
if [ ! -f "$PLUGIN_LIVE" ]; then
  bad "missing plugin: $PLUGIN_LIVE"
else
PLUGIN_LIVE="$PLUGIN_LIVE" node --input-type=module <<'NODE' || bad "tool-guard plugin test crashed"
import { pathToFileURL } from 'node:url';
const pluginFactory = (await import(pathToFileURL(process.env.PLUGIN_LIVE).href)).default;
const plugin = await pluginFactory();
async function expect(pattern, want) {
  const input = { type: 'bash', pattern, metadata: {} };
  const output = { status: 'allow' };
  await plugin['permission.ask'](input, output);
  if (output.status !== want) {
    console.error(`FAIL plugin ${pattern}: got ${output.status}, want ${want}`);
    process.exit(1);
  }
  console.log(`PASS plugin ${pattern} => ${output.status}`);
}
await expect('cat README.md', 'deny');
await expect('ls -la', 'deny');
await expect('grep -r x .', 'deny');
await expect('find . -name x', 'deny');
await expect('export FOO=bar', 'deny');
await expect('rg launcher', 'deny');
await expect('eza -la', 'deny');
await expect('git status', 'deny');
await expect('gcat README.md', 'deny');
await expect('gls -la', 'deny');
await expect('ggrep launcher', 'deny');
await expect('gfind . -name x', 'deny');
await expect('rtk grep launcher', 'allow');
await expect('du -s .', 'allow');
await expect('du .', 'deny');
async function expectNative(type, want) {
  const input = { type, pattern: '*', metadata: {} };
  const output = { status: 'allow' };
  await plugin['permission.ask'](input, output);
  if (output.status !== want) {
    console.error(`FAIL plugin native ${type}: got ${output.status}, want ${want}`);
    process.exit(1);
  }
  console.log(`PASS plugin native ${type} => ${output.status}`);
}
await expectNative('read', 'deny');
await expectNative('grep', 'deny');
await expectNative('glob', 'deny');
await expectNative('list', 'deny');
NODE
fi

section "Claude/Codex tool-guard.sh hook"
GUARD="${HOME}/bin/tool-guard.sh"
if [ ! -x "$GUARD" ]; then
  bad "missing or not executable: $GUARD"
else
  hook_expect() {
    local label="$1"
    local cmd="$2"
    local want_block="$3"
    local input out
    input="$(jq -nc --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}')"
    out="$(echo "$input" | "$GUARD" 2>/dev/null || true)"
    if [ "$want_block" = "block" ]; then
      if echo "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
        ok "hook blocks: $label"
      else
        bad "hook should block: $label (got: $out)"
      fi
    else
      if [ -z "$out" ]; then
        ok "hook allows: $label"
      else
        bad "hook should allow: $label (got: $out)"
      fi
    fi
  }

  hook_expect "cat" "cat README.md" block
  hook_expect "ls" "ls -la" block
  hook_expect "grep" "grep -r launcher ." block
  hook_expect "find" "find . -name '*.json'" block
  hook_expect "export" "export FOO=bar && echo ok" block
  hook_expect "rg" "rg -l launcher $ROOT" block
  hook_expect "git status" "git status" block
  hook_expect "rtk" "rtk grep launcher $ROOT/bin" allow
  hook_expect "du -s" "du -s $ROOT" allow
  hook_expect "gh-axi" "gh-axi --help" allow
  hook_expect "ctx7" "ctx7 --version" allow
fi

section "Approved tools execute"
REPO="$ROOT"
run_ok() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    bad "$label (command failed: $*)"
  fi
}

run_ok "rtk grep finds launcher refs" rtk grep launcher "$REPO/bin"
run_ok "rtk ls lists repo root" rtk ls "$REPO"
run_ok "du -s reports repo size" du -s "$REPO"

section "Summary"
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '\nFix failures, then re-run: %s/bin/test-opencode-permissions.sh\n' "$ROOT"
  exit 1
fi
printf '\nConfig/plugin/hook layers OK. For live agent behavior: %s/bin/test-opencode-live.sh\n' "$ROOT"
exit 0
