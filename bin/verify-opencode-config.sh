#!/usr/bin/env bash
# verify-opencode-config.sh — prove OpenCode config is wired as machine-scratch expects.
# No secrets printed. Exit 0 only if all checks pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PASS=0

ok() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

section() { printf '\n== %s ==\n' "$1"; }

section "Source vs live"
SRC="$ROOT/config/opencode/opencode.json"
LIVE="$HOME/.config/opencode/opencode.json"
EXPECTED="$(mktemp)"
trap 'rm -f "$EXPECTED"' EXIT
# The live OpenCode config is source config plus the generated permission block
# from config/tool-policy.json. Compare against that rendered expectation rather
# than raw source, because permissions are intentionally generated at install time.
jq --argjson p "$($ROOT/bin/policy-render.sh opencode)" '. * $p' "$SRC" > "$EXPECTED"
if cmp -s "$EXPECTED" "$LIVE"; then
  ok "opencode.json live copy matches source + rendered tool policy"
else
  bad "opencode.json drift — run bin/install-active-config.sh"
fi

if [ "$(readlink "$HOME/.agent-rules")" = "$ROOT/agent-rules" ]; then
  ok "~/.agent-rules symlink points at machine-scratch/agent-rules"
else
  bad "~/.agent-rules symlink wrong or missing"
fi

for f in GLOBAL.md TOOL_REGISTRY.md; do
  [ -f "$HOME/.agent-rules/$f" ] && ok "instruction file exists: $f" || bad "missing: ~/.agent-rules/$f"
done

PLUGIN_SRC="$ROOT/config/opencode/plugins/tool-guard/index.js"
PLUGIN_LIVE="$HOME/.config/opencode/plugins/tool-guard/index.js"
if cmp -s "$PLUGIN_SRC" "$PLUGIN_LIVE"; then
  ok "tool-guard plugin matches source"
else
  bad "tool-guard plugin drift"
fi

section "Resolved config (opencode debug config)"
RESOLVED="$(opencode debug config 2>/dev/null)" || { bad "opencode debug config failed"; RESOLVED=""; }

if echo "$RESOLVED" | jq -e '.instructions[] | select(. == "~/.agent-rules/GLOBAL.md")' >/dev/null 2>&1; then
  ok "instructions include GLOBAL.md"
else
  bad "instructions missing GLOBAL.md"
fi

if echo "$RESOLVED" | jq -e '.instructions[] | select(. == "~/.agent-rules/TOOL_REGISTRY.md")' >/dev/null 2>&1; then
  ok "instructions include TOOL_REGISTRY.md"
else
  bad "instructions missing TOOL_REGISTRY.md"
fi

if echo "$RESOLVED" | jq -e '.plugin[] | contains("tool-guard")' >/dev/null 2>&1; then
  ok "tool-guard plugin registered"
else
  bad "tool-guard plugin not in resolved config"
fi

for cmd in cat ls grep find rg eza fd bat dust du git gh rm sudo security export gcat gls ggrep gfind gdu gsed gawk; do
  action="$(echo "$RESOLVED" | jq -r ".permission.bash[\"$cmd\"] // \"missing\"")"
  if [ "$action" = "deny" ]; then
    ok "permission.bash.$cmd = deny"
  else
    bad "permission.bash.$cmd expected deny, got $action"
  fi
done

if echo "$RESOLVED" | jq -e '.permission.bash["*"] == "ask"' >/dev/null 2>&1; then
  ok "permission.bash.* = ask (default allowlist gate)"
else
  bad "permission.bash.* expected ask"
fi

for allowed in "rtk *" "fastedit *" "llm-tldr *" "gtimeout *" "timeout *"; do
  if echo "$RESOLVED" | jq -e --arg a "$allowed" '.permission.bash[$a] == "allow"' >/dev/null 2>&1; then
    ok "permission.bash.$allowed = allow"
  else
    bad "permission.bash.$allowed expected allow"
  fi
done

if echo "$RESOLVED" | jq -e '.permission.bash["du -s *"] == "allow"' >/dev/null 2>&1; then
  ok "permission.bash.du -s * = allow"
else
  bad "permission.bash.du -s * expected allow"
fi

if echo "$RESOLVED" | jq -e '.permission.webfetch == "ask"' >/dev/null 2>&1; then
  ok "permission.webfetch = ask"
else
  bad "permission.webfetch expected ask, got $(echo "$RESOLVED" | jq -r '.permission.webfetch // "missing"')"
fi

for tool in read grep glob list; do
  action="$(echo "$RESOLVED" | jq -r ".permission[\"$tool\"] // \"missing\"")"
  if [ "$action" = "deny" ]; then
    ok "permission.$tool = deny (native tool blocked)"
  else
    bad "permission.$tool expected deny, got $action"
  fi
done

section "Build agent (no permission override)"
AGENT="$(opencode debug agent build 2>/dev/null)" || { bad "opencode debug agent build failed"; AGENT=""; }

if echo "$AGENT" | jq -e '.permission[] | select(.permission=="bash" and .pattern=="cat" and .action=="deny")' >/dev/null 2>&1; then
  ok "build agent inherits bash cat deny"
else
  bad "build agent missing bash cat deny"
fi

if echo "$AGENT" | jq -e '.prompt | contains("GLOBAL.md")' >/dev/null 2>&1; then
  ok "build agent prompt references GLOBAL.md"
else
  bad "build agent prompt missing GLOBAL.md reference"
fi

# agent-level bash:* allow would override global ask/deny — reject that
if echo "$AGENT" | jq -e '.permission[] | select(.permission=="bash" and .pattern=="*" and .action=="allow")' >/dev/null 2>&1; then
  bad "build agent has bash:* allow override (should not)"
else
  ok "build agent has no bash:* allow override"
fi

if echo "$AGENT" | jq -e '.permission[] | select(.permission=="bash" and .pattern=="*" and .action=="ask")' >/dev/null 2>&1; then
  ok "build agent inherits bash * ask"
else
  bad "build agent missing bash * ask"
fi

if echo "$AGENT" | jq -e '.permission[] | select(.permission=="bash" and .pattern=="rtk *" and .action=="allow")' >/dev/null 2>&1; then
  ok "build agent allows rtk *"
else
  bad "build agent missing rtk * allow"
fi

section "Tool-guard plugin behavior"
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
  console.log(`PASS plugin ${pattern} => ${output.status}${input.metadata?.toolGuardReason ? ' (' + input.metadata.toolGuardReason + ')' : ''}`);
}
await expect('cat file', 'deny');
await expect('ls -la', 'deny');
await expect('rg x', 'deny');
await expect('eza -la', 'deny');
await expect('git status', 'deny');
await expect('gcat file', 'deny');
await expect('gls -la', 'deny');
await expect('ggrep x', 'deny');
await expect('gfind . -name x', 'deny');
await expect('rtk grep x', 'allow');
await expect('du -s .', 'allow');
await expect('du .', 'deny');
NODE

if [ -f "$HOME/.config/opencode/profiles/oo.json" ]; then
  oo_model="$(jq -r '.model' "$HOME/.config/opencode/profiles/oo.json")"
  if [ "$oo_model" = "openai/gpt-5.5" ]; then
    ok "oo profile model is openai/gpt-5.5"
  else
    bad "oo profile model is $oo_model, expected openai/gpt-5.5"
  fi
  if OPENCODE_CONFIG="$HOME/.config/opencode/profiles/oo.json" opencode debug config 2>/dev/null \
    | jq -e '.model == "openai/gpt-5.5"' >/dev/null 2>&1; then
    ok "oo profile merges cleanly (opencode debug config)"
  else
    bad "oo profile fails opencode debug config merge"
  fi
  if OPENCODE_CONFIG="$HOME/.config/opencode/profiles/oo.json" opencode debug agent build 2>/dev/null \
    | jq -e '.model.modelID == "gpt-5.5" and .model.providerID == "openai"' >/dev/null 2>&1; then
    ok "oo build agent uses openai/gpt-5.5"
  else
    bad "oo build agent still on wrong model (check agent.build.model in profile)"
  fi
else
  bad "missing ~/.config/opencode/profiles/oo.json"
fi

if [ -f "$HOME/.config/opencode/profiles/ot.json" ]; then
  ot_model="$(jq -r '.model' "$HOME/.config/opencode/profiles/ot.json")"
  if [ "$ot_model" = "tokenrouter/deepseek/deepseek-v4-flash" ]; then
    ok "ot profile model is tokenrouter/deepseek/deepseek-v4-flash"
  else
    bad "ot profile model is $ot_model, expected tokenrouter/deepseek/deepseek-v4-flash"
  fi
  if OPENCODE_CONFIG="$HOME/.config/opencode/profiles/ot.json" opencode debug config 2>/dev/null \
    | jq -e '.model == "tokenrouter/deepseek/deepseek-v4-flash"' >/dev/null 2>&1; then
    ok "ot profile merges cleanly (opencode debug config)"
  else
    bad "ot profile fails opencode debug config merge"
  fi
  if OPENCODE_CONFIG="$HOME/.config/opencode/profiles/ot.json" opencode debug agent build 2>/dev/null \
    | jq -e '.model.modelID == "deepseek/deepseek-v4-flash" and .model.providerID == "tokenrouter"' >/dev/null 2>&1; then
    ok "ot build agent uses tokenrouter/deepseek-v4-flash"
  else
    bad "ot build agent still on wrong model"
  fi
else
  bad "missing ~/.config/opencode/profiles/ot.json"
fi

if secret-cache status 2>/dev/null | jq -e '.TOKENROUTER_API_KEY.cached == true' >/dev/null 2>&1; then
  ok "secret-cache has TOKENROUTER_API_KEY (for ot/op)"
else
  bad "TOKENROUTER_API_KEY not cached — run: secret-cache refresh"
fi

if opencode providers list 2>/dev/null | rg -q 'OpenAI.*oauth'; then
  ok "OpenAI OAuth credential present (for oo)"
else
  bad "OpenAI OAuth not logged in — run: opencode providers login"
fi

section "Approved tools on PATH"
for t in rg fd eza bat jq yq rtk gh; do
  command -v "$t" >/dev/null && ok "$t on PATH" || bad "$t missing from PATH"
done

section "Summary"
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '\nFix failures, then re-run: %s/bin/verify-opencode-config.sh\n' "$ROOT"
  exit 1
fi
printf '\nStructural checks passed. For live agent behavior: %s/bin/test-opencode-live.sh\n' "$ROOT"
exit 0
