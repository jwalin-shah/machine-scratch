#!/usr/bin/env bash
# test-opencode-profiles.sh — profile merge, default models, and model catalog counts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PASS=0

ok() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

section "Model catalogs (global config)"
RESOLVED="$(opencode debug config 2>/dev/null)" || { bad "opencode debug config failed"; exit 1; }

tr_count="$(echo "$RESOLVED" | jq '.provider.tokenrouter.models | keys | length')"
pi_count="$(echo "$RESOLVED" | jq '.provider.pioneer.models | keys | length')"

if [ "$tr_count" -ge 50 ]; then
  ok "tokenrouter catalog: $tr_count models"
else
  bad "tokenrouter catalog too small: $tr_count (expected >= 50)"
fi

if [ "$pi_count" -ge 50 ]; then
  ok "pioneer catalog: $pi_count models"
else
  bad "pioneer catalog too small: $pi_count (expected >= 50)"
fi

section "Profile defaults"
profile_check() {
  local name="$1"
  local profile="$2"
  local want_model="$3"
  local want_provider="$4"
  local want_model_id="$5"

  if [ ! -f "$profile" ]; then
    bad "missing profile: $profile"
    return
  fi

  local model
  model="$(jq -r '.model' "$profile")"
  if [ "$model" = "$want_model" ]; then
    ok "$name profile model = $want_model"
  else
    bad "$name profile model is $model, expected $want_model"
  fi

  if OPENCODE_CONFIG="$profile" opencode debug config 2>/dev/null \
    | jq -e --arg m "$want_model" '.model == $m' >/dev/null 2>&1; then
    ok "$name profile merges (debug config)"
  else
    bad "$name profile merge failed (debug config)"
  fi

  if OPENCODE_CONFIG="$profile" opencode debug agent build 2>/dev/null \
    | jq -e --arg p "$want_provider" --arg id "$want_model_id" \
      '.model.providerID == $p and .model.modelID == $id' >/dev/null 2>&1; then
    ok "$name build agent = $want_provider/$want_model_id"
  else
    bad "$name build agent model wrong (check agent.build.model in profile)"
  fi
}

profile_check "oo" "$HOME/.config/opencode/profiles/oo.json" \
  "openai/gpt-5.5" "openai" "gpt-5.5"
profile_check "ot" "$HOME/.config/opencode/profiles/ot.json" \
  "tokenrouter/deepseek/deepseek-v4-flash" "tokenrouter" "deepseek/deepseek-v4-flash"
profile_check "op" "$HOME/.config/opencode/profiles/op.json" \
  "pioneer/pioneer/auto" "pioneer" "pioneer/auto"

section "CLI model lists"
if opencode models tokenrouter 2>/dev/null | rg -q 'tokenrouter/deepseek/deepseek-v4-flash'; then
  ok "opencode models tokenrouter lists deepseek-v4-flash"
else
  bad "opencode models tokenrouter missing deepseek-v4-flash"
fi

if opencode models pioneer 2>/dev/null | rg -q 'pioneer/pioneer/auto'; then
  ok "opencode models pioneer lists pioneer/auto"
else
  bad "opencode models pioneer missing pioneer/auto"
fi

section "Summary"
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
